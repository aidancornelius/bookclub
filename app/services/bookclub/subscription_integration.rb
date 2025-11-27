# frozen_string_literal: true

module Bookclub
  class SubscriptionIntegration
    include Service::Base

    params do
      attribute :event_type, :string
      attribute :subscription_data
      attribute :user
      attribute :product_id, :string

      validates :event_type, presence: true
      validates :subscription_data, presence: true
      validates :user, presence: true
    end

    policy :stripe_integration_enabled
    policy :discourse_subscriptions_available
    model :publication, optional: true
    step :process_subscription_event

    private

    def stripe_integration_enabled
      SiteSetting.bookclub_stripe_integration
    end

    def discourse_subscriptions_available
      defined?(DiscourseSubscriptions) && SiteSetting.discourse_subscriptions_enabled
    end

    def fetch_publication(params:)
      return nil unless params.product_id

      # First try to find publication via Stripe product metadata
      product = fetch_stripe_product(params.product_id)

      if product
        publication_id = product.dig(:metadata, :bookclub_publication_id)
        if publication_id
          publication = Category.find_by(id: publication_id)
          return publication if publication
        end
      end

      # Fallback: Find publication by looking up which one has this product_id in its custom fields
      # This handles the case where bookclub_stripe_product_id is set on the publication but
      # bookclub_publication_id is not set in Stripe product metadata
      publication_field = CategoryCustomField.find_by(
        name: Bookclub::STRIPE_PRODUCT_ID,
        value: params.product_id
      )

      if publication_field
        publication = Category.find_by(id: publication_field.category_id)
        if publication&.custom_fields&.[](Bookclub::PUBLICATION_ENABLED)
          return publication
        end
      end

      Rails.logger.warn(
        "[Bookclub] No publication found for product #{params.product_id}. " \
        "Ensure either bookclub_publication_id is set in Stripe product metadata, " \
        "or bookclub_stripe_product_id is set on the publication."
      )
      nil
    end

    def process_subscription_event(params:, publication:, context:)
      case params.event_type
      when 'subscription.created', 'subscription.updated', 'checkout.completed'
        grant_access(params.user, publication, params.subscription_data)
      when 'subscription.deleted'
        revoke_access(params.user, publication, params.subscription_data)
      when 'payment.failed'
        handle_payment_failed(params.user, publication, params.subscription_data)
      when 'charge.refunded'
        handle_refund(params.user, publication, params.subscription_data)
      else
        Rails.logger.warn("[Bookclub] Unknown subscription event type: #{params.event_type}")
      end
    end

    def grant_access(user, publication, subscription_data)
      return unless publication

      group = find_access_group(publication, subscription_data)
      return unless group

      # Determine purchase type from subscription data
      purchase_type = determine_purchase_type(subscription_data)

      if group.add(user)
        Rails.logger.info(
          "[Bookclub] Granted access to publication #{publication.id} for user #{user.id} via group #{group.name} (#{purchase_type})"
        )

        notify_user_access_granted(user, publication, group)

        store_subscription_metadata(user, publication, subscription_data, purchase_type)
      else
        Rails.logger.warn("[Bookclub] Failed to add user #{user.id} to group #{group.name}")
      end
    end

    def revoke_access(user, publication, subscription_data)
      return unless publication

      # Check if this was a one-time purchase - don't revoke those
      pub_slug = publication.custom_fields[Bookclub::PUBLICATION_SLUG] || publication.slug
      metadata = user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] || {}
      pub_metadata = metadata[pub_slug]

      if pub_metadata && pub_metadata['purchase_type'] == 'one_time'
        Rails.logger.info(
          "[Bookclub] Skipping access revocation for one-time purchase: publication #{publication.id}, user #{user.id}"
        )
        return
      end

      group = find_access_group(publication, subscription_data)
      return unless group

      if group.remove(user)
        Rails.logger.info(
          "[Bookclub] Revoked access to publication #{publication.id} for user #{user.id} from group #{group.name}"
        )

        notify_user_access_revoked(user, publication, group)

        clear_subscription_metadata(user, publication)
      else
        Rails.logger.warn("[Bookclub] Failed to remove user #{user.id} from group #{group.name}")
      end
    end

    def extract_tier_from_subscription(subscription_data)
      plan = subscription_data[:plan] || subscription_data.dig(:items, :data, 0, :plan)
      return nil unless plan

      plan.dig(:metadata, :group_name)
    end

    def find_access_group(publication, subscription_data)
      # First, check the new pricing config for access_group
      pricing_config = publication.custom_fields[Bookclub::PRICING_CONFIG]
      # Handle both boolean and string values for 'enabled' (form data sends strings)
      pricing_enabled = pricing_config.is_a?(Hash) &&
        [true, 'true', 't'].include?(pricing_config['enabled'])
      if pricing_enabled && pricing_config['access_group'].present?
        group = Group.find_by(name: pricing_config['access_group'])
        return group if group
      end

      # Fall back to legacy tier-based access
      tier_group_name = extract_tier_from_subscription(subscription_data)
      return nil unless tier_group_name

      Group.find_by(name: tier_group_name)
    end

    def determine_purchase_type(subscription_data)
      # If there's no subscription ID or it's from a one-time checkout, it's a one-time purchase
      # Stripe subscriptions have IDs starting with "sub_", one-time checkouts don't have subscription IDs
      subscription_id = subscription_data[:id]

      if subscription_id.blank? || !subscription_id.to_s.start_with?('sub_')
        'one_time'
      else
        'subscription'
      end
    end

    def notify_user_access_granted(user, publication, group)
      SystemMessage.create_from_system_user(
        user,
        :bookclub_subscription_access_granted,
        publication_name: publication.name,
        publication_url: publication_url(publication),
        tier_name: group.name
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error("[Bookclub] Database error sending access granted notification: #{e.message}")
    rescue ArgumentError, NoMethodError => e
      Rails.logger.error("[Bookclub] Invalid data in access granted notification: #{e.message}")
    rescue => e
      # Catch any unexpected errors but log them with full details
      Rails.logger.error("[Bookclub] Unexpected error sending access granted notification: #{e.class.name} - #{e.message}")
    end

    def notify_user_access_revoked(user, publication, group)
      SystemMessage.create_from_system_user(
        user,
        :bookclub_subscription_access_revoked,
        publication_name: publication.name,
        tier_name: group.name
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error("[Bookclub] Database error sending access revoked notification: #{e.message}")
    rescue ArgumentError, NoMethodError => e
      Rails.logger.error("[Bookclub] Invalid data in access revoked notification: #{e.message}")
    rescue => e
      # Catch any unexpected errors but log them with full details
      Rails.logger.error("[Bookclub] Unexpected error sending access revoked notification: #{e.class.name} - #{e.message}")
    end

    def store_subscription_metadata(user, publication, subscription_data, purchase_type = 'subscription')
      metadata = user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] || {}
      # Use publication slug as the key for consistency with pricing_controller
      pub_slug = publication.custom_fields[Bookclub::PUBLICATION_SLUG] || publication.slug
      metadata[pub_slug] = {
        'subscription_id' => subscription_data[:id],
        'status' => subscription_data[:status],
        'purchase_type' => purchase_type,
        'granted_at' => Time.current.iso8601
      }
      user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] = metadata
      user.save_custom_fields
    end

    def clear_subscription_metadata(user, publication)
      metadata = user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] || {}
      # Use publication slug as the key for consistency with pricing_controller
      pub_slug = publication.custom_fields[Bookclub::PUBLICATION_SLUG] || publication.slug
      metadata.delete(pub_slug)
      user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] = metadata
      user.save_custom_fields
    end

    def handle_payment_failed(user, publication, subscription_data)
      return unless publication

      group = find_access_group(publication, subscription_data)
      return unless group

      # Update subscription metadata to reflect payment failure
      # Use publication slug as the key for consistency with pricing_controller
      metadata = user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] || {}
      pub_slug = publication.custom_fields[Bookclub::PUBLICATION_SLUG] || publication.slug
      pub_data = metadata[pub_slug] || {}
      pub_data[:status] = 'past_due'
      pub_data[:payment_failed_at] = Time.current.iso8601
      pub_data[:attempt_count] = subscription_data[:attempt_count]
      metadata[pub_slug] = pub_data
      user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] = metadata
      user.save_custom_fields

      # Notify user of payment failure
      notify_user_payment_failed(user, publication, group, subscription_data)

      Rails.logger.info(
        "[Bookclub] Payment failed for user #{user.id}, publication #{publication.id}, subscription #{subscription_data[:id]}"
      )
    end

    def handle_refund(user, publication, subscription_data)
      return unless publication

      group = find_access_group(publication, subscription_data)
      return unless group

      # Revoke access for full refunds
      return unless group.remove(user)

      Rails.logger.info(
        "[Bookclub] Revoked access due to refund for publication #{publication.id}, user #{user.id}"
      )

      notify_user_refund_processed(user, publication, group, subscription_data)
      clear_subscription_metadata(user, publication)
    end

    def notify_user_payment_failed(user, publication, group, subscription_data)
      SystemMessage.create_from_system_user(
        user,
        :bookclub_subscription_payment_failed,
        publication_name: publication.name,
        publication_url: publication_url(publication),
        tier_name: group.name,
        amount_due: format_amount(subscription_data[:amount_due])
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error("[Bookclub] Database error sending payment failed notification: #{e.message}")
    rescue ArgumentError, NoMethodError => e
      Rails.logger.error("[Bookclub] Invalid data in payment failed notification: #{e.message}")
    rescue => e
      # Catch any unexpected errors but log them with full details
      Rails.logger.error("[Bookclub] Unexpected error sending payment failed notification: #{e.class.name} - #{e.message}")
    end

    def notify_user_refund_processed(user, publication, group, subscription_data)
      SystemMessage.create_from_system_user(
        user,
        :bookclub_subscription_refund_processed,
        publication_name: publication.name,
        tier_name: group.name,
        amount_refunded: format_amount(subscription_data[:amount_refunded])
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error("[Bookclub] Database error sending refund notification: #{e.message}")
    rescue ArgumentError, NoMethodError => e
      Rails.logger.error("[Bookclub] Invalid data in refund notification: #{e.message}")
    rescue => e
      # Catch any unexpected errors but log them with full details
      Rails.logger.error("[Bookclub] Unexpected error sending refund notification: #{e.class.name} - #{e.message}")
    end

    def format_amount(amount_cents)
      return '0.00' unless amount_cents

      format('%.2f', amount_cents / 100.0)
    end

    def publication_url(publication)
      slug = publication.custom_fields[Bookclub::PUBLICATION_SLUG] || publication.slug
      "/book/#{slug}"
    end

    def fetch_stripe_product(product_id)
      return nil unless defined?(Stripe)

      Stripe::Product.retrieve(product_id)
    rescue Stripe::StripeError => e
      Rails.logger.error("[Bookclub] Error fetching Stripe product #{product_id}: #{e.message}")
      nil
    end
  end
end
