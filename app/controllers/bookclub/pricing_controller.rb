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

      stripe_product_id = publication.custom_fields['bookclub_stripe_product_id']

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
      subscriptions = current_user.custom_fields[SUBSCRIPTION_METADATA] || {}
      pub_slug = publication.custom_fields[PUBLICATION_SLUG]
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

      prices = ::Stripe::Price.list({ product: product_id, active: true, expand: ['data.product'] })

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
      hierarchy = %w[community reader member supporter patron]
      hierarchy.index(tier) || 99
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

    def create_stripe_checkout_session(price_id:, publication:, success_url:, cancel_url:)
      set_stripe_api_key

      ::Stripe::Checkout::Session.create(
        {
          mode: determine_checkout_mode(price_id),
          customer_email: current_user.email,
          line_items: [{ price: price_id, quantity: 1 }],
          success_url: success_url,
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
