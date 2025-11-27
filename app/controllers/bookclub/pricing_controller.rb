# frozen_string_literal: true

module Bookclub
  # Controller for handling pricing tiers, subscription checkout, and payment management
  # Integrates with Stripe via discourse-subscriptions for payment processing
  class PricingController < BaseController
    skip_before_action :check_xhr, only: [:tiers]

    def tiers
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      unless stripe_configured?
        return (
          render json: {
                   error: 'stripe_not_configured',
                   message: 'Payment processing is not configured',
                   manual_mode: SiteSetting.bookclub_manual_access_mode
                 },
                 status: :service_unavailable
        )
      end

      stripe_product_id = publication.custom_fields[STRIPE_PRODUCT_ID]

      if stripe_product_id.blank?
        return render json: { tiers: [], message: 'No pricing available for this publication' }
      end

      tiers = fetch_stripe_prices(stripe_product_id, publication)

      render json: {
        publication: {
          id: publication.id,
          name: publication.name,
          slug: publication.custom_fields[PUBLICATION_SLUG]
        },
        tiers: tiers,
        currency: SiteSetting.discourse_subscriptions_currency,
        user_tier: current_user ? current_user_tier(publication) : nil
      }
    end

    def subscription_status
      return render json: { error: 'not_logged_in' }, status: :unauthorized unless current_user

      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      has_access = guardian.can_access_publication?(publication)
      current_tier = current_user_tier(publication)

      # Get subscription details from user's custom fields
      subscriptions = current_user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] || {}
      pub_slug = publication.custom_fields[Bookclub::PUBLICATION_SLUG] || publication.slug
      subscription_data = subscriptions[pub_slug]

      render json: {
        has_access: has_access,
        current_tier: current_tier,
        subscription: subscription_data,
        is_author: guardian.is_publication_author?(publication),
        is_editor: guardian.is_publication_editor?(publication)
      }
    end

    def create_checkout
      return render json: { error: 'not_logged_in' }, status: :unauthorized unless current_user

      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      return render json: { error: 'stripe_not_configured' }, status: :service_unavailable unless stripe_configured?

      price_id = params[:price_id]
      return render json: { error: 'price_id_required' }, status: :bad_request if price_id.blank?

      # Security: Validate that price_id belongs to this publication's Stripe product
      unless price_belongs_to_publication?(price_id, publication)
        Rails.logger.warn("[Bookclub] Attempted checkout with invalid price_id #{price_id} for publication #{publication.id}")
        return render json: { error: 'invalid_price', message: 'Price does not belong to this publication' }, status: :bad_request
      end

      success_url =
        params[:success_url] || "#{Discourse.base_url}/book/#{params[:slug]}?checkout=success"
      cancel_url =
        params[:cancel_url] || "#{Discourse.base_url}/book/#{params[:slug]}?checkout=cancelled"

      begin
        session =
          create_stripe_checkout_session(
            price_id: price_id,
            publication: publication,
            success_url: success_url,
            cancel_url: cancel_url
          )

        render json: { checkout_url: session.url, session_id: session.id }
      rescue ::Stripe::StripeError => e
        Rails.logger.error("[Bookclub] Stripe checkout error: #{e.message}")
        render json: { error: 'checkout_failed', message: e.message }, status: :unprocessable_entity
      end
    end

    def create_portal_session
      return render json: { error: 'not_logged_in' }, status: :unauthorized unless current_user

      return render json: { error: 'stripe_not_configured' }, status: :service_unavailable unless stripe_configured?

      return_url = params[:return_url] || "#{Discourse.base_url}/library"

      # Find the customer's Stripe customer ID
      customer = find_stripe_customer(current_user)

      return render json: { error: 'no_subscription' }, status: :not_found unless customer

      begin
        portal_session =
          ::Stripe::BillingPortal::Session.create(
            { customer: customer.customer_id, return_url: return_url }
          )

        render json: { portal_url: portal_session.url }
      rescue ::Stripe::StripeError => e
        Rails.logger.error("[Bookclub] Stripe portal error: #{e.message}")
        render json: { error: 'portal_failed', message: e.message }, status: :unprocessable_entity
      end
    end

    def success
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      render json: {
        success: true,
        message: 'subscription_successful',
        publication: {
          id: publication.id,
          name: publication.name,
          slug: publication.custom_fields[PUBLICATION_SLUG]
        }
      }
    end

    # Verify a checkout session and grant access if successful
    # This is a fallback for when webhooks don't arrive (e.g., local development)
    def verify_checkout
      return render json: { error: 'not_logged_in' }, status: :unauthorized unless current_user
      return render json: { error: 'stripe_not_configured' }, status: :service_unavailable unless stripe_configured?

      session_id = params[:session_id]
      return render json: { error: 'session_id_required' }, status: :bad_request if session_id.blank?

      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      set_stripe_api_key

      begin
        session = ::Stripe::Checkout::Session.retrieve(session_id)

        # Verify the session is completed
        unless session.status == 'complete'
          return render json: { error: 'checkout_not_complete', status: session.status }, status: :bad_request
        end

        # Verify this session belongs to the current user
        unless session.customer_email == current_user.email
          Rails.logger.warn("[Bookclub] User #{current_user.id} attempted to verify session belonging to #{session.customer_email}")
          return render json: { error: 'session_mismatch' }, status: :forbidden
        end

        # Verify the session is for this publication
        session_pub_id = session.metadata['publication_id']&.to_i
        unless session_pub_id == publication.id
          return render json: { error: 'publication_mismatch' }, status: :bad_request
        end

        # Check if user already has access (webhook might have already processed this)
        if guardian.can_access_publication?(publication)
          return render json: { success: true, message: 'already_has_access', has_access: true }
        end

        # Grant access directly by adding user to the access group
        pricing_config = publication.custom_fields[PRICING_CONFIG]
        access_group_name = pricing_config&.dig('access_group')

        unless access_group_name.present?
          # Try to use the default group naming convention
          pub_slug = publication.custom_fields[PUBLICATION_SLUG] || publication.slug
          access_group_name = "#{pub_slug}_readers"
        end

        group = Group.find_by(name: access_group_name)
        unless group
          # Auto-create the access group
          Rails.logger.info("[Bookclub] Creating access group '#{access_group_name}' for publication #{publication.id}")
          group = Group.create!(
            name: access_group_name,
            visibility_level: Group.visibility_levels[:members],
            primary_group: false,
            title: "#{publication.name} Readers",
            automatic: false
          )
        end

        # Determine purchase type
        purchase_type = session.subscription.present? ? 'subscription' : 'one_time'

        if group.add(current_user)
          Rails.logger.info("[Bookclub] Granted access to publication #{publication.id} for user #{current_user.id} via group #{group.name} (#{purchase_type})")

          # Store subscription metadata
          metadata = current_user.custom_fields[SUBSCRIPTION_METADATA] || {}
          pub_slug = publication.custom_fields[PUBLICATION_SLUG] || publication.slug
          metadata[pub_slug] = {
            'subscription_id' => session.subscription,
            'status' => 'active',
            'purchase_type' => purchase_type,
            'granted_at' => Time.current.iso8601
          }
          current_user.custom_fields[SUBSCRIPTION_METADATA] = metadata
          current_user.save_custom_fields

          render json: { success: true, message: 'access_granted', has_access: true }
        else
          Rails.logger.error("[Bookclub] Failed to add user #{current_user.id} to group #{group.name}")
          render json: { error: 'grant_failed', message: 'Could not add to access group' }, status: :unprocessable_entity
        end
      rescue ::Stripe::StripeError => e
        Rails.logger.error("[Bookclub] Stripe error verifying checkout: #{e.message}")
        render json: { error: 'stripe_error', message: e.message }, status: :unprocessable_entity
      end
    end

    def cancelled
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      render json: {
        success: false,
        message: 'checkout_cancelled',
        publication: {
          id: publication.id,
          name: publication.name,
          slug: publication.custom_fields[PUBLICATION_SLUG]
        }
      }
    end

    private

    def stripe_configured?
      return false unless SiteSetting.bookclub_stripe_integration
      return false unless defined?(DiscourseSubscriptions)

      SiteSetting.respond_to?(:discourse_subscriptions_secret_key) &&
        SiteSetting.discourse_subscriptions_secret_key.present?
    end

    def fetch_stripe_prices(product_id, publication)
      set_stripe_api_key

      begin
        prices = ::Stripe::Price.list({ product: product_id, active: true, expand: ['data.product'] })
      rescue ::Stripe::StripeError => e
        Rails.logger.error("[Bookclub] Error fetching Stripe prices for product #{product_id}: #{e.message}")
        return []
      end

      access_tiers = publication.custom_fields[PUBLICATION_ACCESS_TIERS] || {}

      prices
        .data
        .map do |price|
          group_name = price.metadata['group_name']
          tier_level = access_tiers[group_name]

          {
            id: price.id,
            name: price.nickname || price.product.name,
            description: price.product.description,
            amount: price.unit_amount,
            currency: price.currency,
            interval: price.recurring&.interval,
            interval_count: price.recurring&.interval_count,
            group_name: group_name,
            tier_level: tier_level,
            features: parse_features(price.metadata['features']),
            highlighted: price.metadata['highlighted'] == 'true'
          }
        end
        .sort_by { |t| tier_hierarchy_index(t[:tier_level]) }
    end

    def parse_features(features_string)
      return [] if features_string.blank?

      features_string.split('|').map(&:strip)
    end

    def tier_hierarchy_index(tier)
      TIER_HIERARCHY.index(tier) || 99
    end

    def current_user_tier(publication)
      return nil unless current_user

      access_tiers = publication.custom_fields[PUBLICATION_ACCESS_TIERS] || {}
      user_group_ids = current_user.group_ids

      user_tiers =
        access_tiers.select do |group_name, _level|
          group = Group.find_by(name: group_name)
          group && user_group_ids.include?(group.id)
        end

      return nil if user_tiers.empty?

      # Return highest tier
      user_tiers.max_by { |_name, level| tier_hierarchy_index(level) }&.last
    end

    # Validates that a price_id belongs to this publication's configured Stripe product
    # Prevents users from purchasing unrelated prices via crafted requests
    def price_belongs_to_publication?(price_id, publication)
      stripe_product_id = publication.custom_fields[STRIPE_PRODUCT_ID]
      return false if stripe_product_id.blank?

      set_stripe_api_key

      begin
        price = ::Stripe::Price.retrieve(price_id)
        price.product == stripe_product_id
      rescue ::Stripe::StripeError => e
        Rails.logger.error("[Bookclub] Error validating price #{price_id}: #{e.message}")
        false
      end
    end

    def create_stripe_checkout_session(price_id:, publication:, success_url:, cancel_url:)
      set_stripe_api_key

      # Append session_id to success URL for verification after checkout
      # Stripe replaces {CHECKOUT_SESSION_ID} with the actual session ID on redirect
      separator = success_url.include?('?') ? '&' : '?'
      success_url_with_session = "#{success_url}#{separator}checkout_session_id={CHECKOUT_SESSION_ID}"

      ::Stripe::Checkout::Session.create(
        {
          mode: determine_checkout_mode(price_id),
          customer_email: current_user.email,
          line_items: [{ price: price_id, quantity: 1 }],
          success_url: success_url_with_session,
          cancel_url: cancel_url,
          metadata: {
            user_id: current_user.id,
            username: current_user.username,
            publication_id: publication.id,
            publication_slug: publication.custom_fields[PUBLICATION_SLUG]
          }
        }
      )
    end

    def determine_checkout_mode(price_id)
      set_stripe_api_key
      price = ::Stripe::Price.retrieve(price_id)
      price.type == 'recurring' ? 'subscription' : 'payment'
    end

    def find_stripe_customer(user)
      return nil unless defined?(DiscourseSubscriptions::Customer)

      DiscourseSubscriptions::Customer.find_by(user_id: user.id)
    end

    def set_stripe_api_key
      ::Stripe.api_key = SiteSetting.discourse_subscriptions_secret_key
    end
  end
end
