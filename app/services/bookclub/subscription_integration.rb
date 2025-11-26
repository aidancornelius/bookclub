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

      product = fetch_stripe_product(params.product_id)
      return nil unless product

      publication_id = product[:metadata][:bookclub_publication_id]
      return nil unless publication_id

      Category.find_by(id: publication_id)
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

      publication.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] || {}
      tier_group_name = extract_tier_from_subscription(subscription_data)

      return unless tier_group_name

      group = Group.find_by(name: tier_group_name)
      return unless group

      if group.add(user)
        Rails.logger.info(
          "[Bookclub] Granted access to publication #{publication.id} for user #{user.id} via group #{group.name}"
        )

        notify_user_access_granted(user, publication, group)

        store_subscription_metadata(user, publication, subscription_data)
      else
        Rails.logger.warn("[Bookclub] Failed to add user #{user.id} to group #{group.name}")
      end
    end

    def revoke_access(user, publication, subscription_data)
      return unless publication

      publication.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] || {}
      tier_group_name = extract_tier_from_subscription(subscription_data)

      return unless tier_group_name

      group = Group.find_by(name: tier_group_name)
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

    def notify_user_access_granted(user, publication, group)
      SystemMessage.create_from_system_user(
        user,
        :bookclub_subscription_access_granted,
        publication_name: publication.name,
        publication_url: publication_url(publication),
        tier_name: group.name
      )
    rescue StandardError => e
      Rails.logger.error("[Bookclub] Error sending access granted notification: #{e.message}")
    end

    def notify_user_access_revoked(user, publication, group)
      SystemMessage.create_from_system_user(
        user,
        :bookclub_subscription_access_revoked,
        publication_name: publication.name,
        tier_name: group.name
      )
    rescue StandardError => e
      Rails.logger.error("[Bookclub] Error sending access revoked notification: #{e.message}")
    end

    def store_subscription_metadata(user, publication, subscription_data)
      metadata = user.custom_fields['bookclub_subscriptions'] || {}
      metadata[publication.id.to_s] = {
        subscription_id: subscription_data[:id],
        status: subscription_data[:status],
        granted_at: Time.current.iso8601
      }
      user.custom_fields['bookclub_subscriptions'] = metadata
      user.save_custom_fields
    end

    def clear_subscription_metadata(user, publication)
      metadata = user.custom_fields['bookclub_subscriptions'] || {}
      metadata.delete(publication.id.to_s)
      user.custom_fields['bookclub_subscriptions'] = metadata
      user.save_custom_fields
    end

    def handle_payment_failed(user, publication, subscription_data)
      return unless publication

      publication.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] || {}
      tier_group_name = extract_tier_from_subscription(subscription_data)

      return unless tier_group_name

      group = Group.find_by(name: tier_group_name)
      return unless group

      # Update subscription metadata to reflect payment failure
      metadata = user.custom_fields['bookclub_subscriptions'] || {}
      pub_data = metadata[publication.id.to_s] || {}
      pub_data[:status] = 'past_due'
      pub_data[:payment_failed_at] = Time.current.iso8601
      pub_data[:attempt_count] = subscription_data[:attempt_count]
      metadata[publication.id.to_s] = pub_data
      user.custom_fields['bookclub_subscriptions'] = metadata
      user.save_custom_fields

      # Notify user of payment failure
      notify_user_payment_failed(user, publication, group, subscription_data)

      Rails.logger.info(
        "[Bookclub] Payment failed for user #{user.id}, publication #{publication.id}, subscription #{subscription_data[:id]}"
      )
    end

    def handle_refund(user, publication, subscription_data)
      return unless publication

      publication.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] || {}
      tier_group_name = extract_tier_from_subscription(subscription_data)

      return unless tier_group_name

      group = Group.find_by(name: tier_group_name)
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
    rescue StandardError => e
      Rails.logger.error("[Bookclub] Error sending payment failed notification: #{e.message}")
    end

    def notify_user_refund_processed(user, publication, group, subscription_data)
      SystemMessage.create_from_system_user(
        user,
        :bookclub_subscription_refund_processed,
        publication_name: publication.name,
        tier_name: group.name,
        amount_refunded: format_amount(subscription_data[:amount_refunded])
      )
    rescue StandardError => e
      Rails.logger.error("[Bookclub] Error sending refund notification: #{e.message}")
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
