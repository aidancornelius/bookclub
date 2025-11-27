# frozen_string_literal: true

module Bookclub
  module SubscriptionHooks
    extend ActiveSupport::Concern

    included { after_action :process_bookclub_subscription, only: [:create] }

    private

    def process_bookclub_subscription
      return unless SiteSetting.bookclub_stripe_integration
      return unless defined?(DiscourseSubscriptions)
      return unless response.successful?

      event_type = extract_event_type(@event)
      return unless bookclub_relevant_event?(event_type)

      process_bookclub_event(@event, event_type)
    end

    def bookclub_relevant_event?(event_type)
      %w[
        checkout.session.completed
        customer.subscription.created
        customer.subscription.updated
        customer.subscription.deleted
        invoice.payment_failed
        charge.refunded
      ].include?(event_type)
    end

    def process_bookclub_event(event, event_type)
      case event_type
      when 'checkout.session.completed'
        handle_checkout_completed(event)
      when 'customer.subscription.created', 'customer.subscription.updated'
        handle_subscription_created_or_updated(event)
      when 'customer.subscription.deleted'
        handle_subscription_deleted(event)
      when 'invoice.payment_failed'
        handle_invoice_payment_failed(event)
      when 'charge.refunded'
        handle_charge_refunded(event)
      end
    end

    def handle_checkout_completed(event)
      checkout_session = event[:data][:object]
      unless checkout_session[:status] == 'complete'
        Rails.logger.info("[Bookclub] Skipping checkout - status is #{checkout_session[:status]}")
        return
      end

      email = checkout_session[:customer_email]
      unless email
        Rails.logger.warn("[Bookclub] Checkout completed but no customer email provided")
        return
      end

      user = User.find_by_email(email)
      unless user
        Rails.logger.warn("[Bookclub] No user found for email: #{email}")
        return
      end

      subscription_id = checkout_session[:subscription]
      product_id = extract_product_id_from_checkout(checkout_session)

      unless product_id
        Rails.logger.warn("[Bookclub] Could not extract product_id from checkout session")
        return
      end

      invoke_subscription_integration(
        event_type: 'checkout.completed',
        user: user,
        product_id: product_id,
        subscription_data: {
          id: subscription_id,
          status: 'active'
        }
      )
    end

    def handle_subscription_created_or_updated(event)
      subscription = event[:data][:object]
      status = subscription[:status]

      # Handle active statuses that should grant access: complete, active, trialing
      # Note: past_due is handled separately to preserve access while attempting payment recovery
      unless %w[complete active trialing past_due].include?(status)
        Rails.logger.info("[Bookclub] Skipping subscription with status: #{status}")
        return
      end

      customer_id = subscription[:customer]
      product_id = subscription.dig(:plan, :product)

      unless customer_id && product_id
        Rails.logger.warn("[Bookclub] Missing customer_id or product_id in subscription event")
        return
      end

      user = find_user_by_customer_id(customer_id)
      unless user
        Rails.logger.warn("[Bookclub] No user found for customer_id: #{customer_id}")
        return
      end

      invoke_subscription_integration(
        event_type: 'subscription.updated',
        user: user,
        product_id: product_id,
        subscription_data: subscription
      )
    end

    def handle_subscription_deleted(event)
      subscription = event[:data][:object]
      customer_id = subscription[:customer]
      product_id = subscription.dig(:plan, :product)

      return unless customer_id && product_id

      user = find_user_by_customer_id(customer_id)
      return unless user

      invoke_subscription_integration(
        event_type: 'subscription.deleted',
        user: user,
        product_id: product_id,
        subscription_data: subscription
      )
    end

    def handle_invoice_payment_failed(event)
      invoice = event[:data][:object]
      customer_id = invoice[:customer]
      subscription_id = invoice[:subscription]

      return unless customer_id && subscription_id

      user = find_user_by_customer_id(customer_id)
      return unless user

      # Fetch subscription to get product info
      subscription = fetch_stripe_subscription(subscription_id)
      return unless subscription

      product_id = subscription.dig(:plan, :product)
      return unless product_id

      invoke_subscription_integration(
        event_type: 'payment.failed',
        user: user,
        product_id: product_id,
        subscription_data: {
          id: subscription_id,
          status: subscription[:status],
          invoice_id: invoice[:id],
          amount_due: invoice[:amount_due],
          attempt_count: invoice[:attempt_count]
        }
      )
    end

    def handle_charge_refunded(event)
      charge = event[:data][:object]
      customer_id = charge[:customer]

      return unless customer_id

      user = find_user_by_customer_id(customer_id)
      return unless user

      # Extract product info from charge metadata or invoice
      invoice_id = charge[:invoice]
      return unless invoice_id

      invoice = fetch_stripe_invoice(invoice_id)
      return unless invoice

      subscription_id = invoice[:subscription]
      return unless subscription_id

      subscription = fetch_stripe_subscription(subscription_id)
      return unless subscription

      product_id = subscription.dig(:plan, :product)
      return unless product_id

      invoke_subscription_integration(
        event_type: 'charge.refunded',
        user: user,
        product_id: product_id,
        subscription_data: {
          id: subscription_id,
          status: subscription[:status],
          charge_id: charge[:id],
          amount_refunded: charge[:amount_refunded],
          refund_reason: charge.dig(:refunds, :data, 0, :reason)
        }
      )
    end

    def invoke_subscription_integration(event_type:, user:, product_id:, subscription_data:)
      result =
        Bookclub::SubscriptionIntegration.call(
          event_type: event_type,
          user: user,
          product_id: product_id,
          subscription_data: subscription_data
        )

      if result.failure?
        Rails.logger.warn(
          "[Bookclub] Subscription integration failed for user #{user.id}: #{result.inspect_steps}"
        )
      end
    rescue StandardError => e
      Rails.logger.error("[Bookclub] Error in subscription integration: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    def extract_product_id_from_checkout(checkout_session)
      line_items = Stripe::Checkout::Session.list_line_items(checkout_session[:id], { limit: 1 })
      item = line_items[:data].first
      item&.dig(:price, :product)
    rescue Stripe::StripeError => e
      Rails.logger.error("[Bookclub] Error fetching line items for checkout session: #{e.message}")
      nil
    end

    def find_user_by_customer_id(customer_id)
      return nil unless defined?(DiscourseSubscriptions::Customer)

      customer = DiscourseSubscriptions::Customer.find_by(customer_id: customer_id)
      return nil unless customer

      User.find_by(id: customer.user_id)
    end

    def extract_event_type(event)
      event&.fetch(:type, nil)
    end

    def fetch_stripe_subscription(subscription_id)
      Stripe::Subscription.retrieve(subscription_id)
    rescue Stripe::StripeError => e
      Rails.logger.error(
        "[Bookclub] Error fetching Stripe subscription #{subscription_id}: #{e.message}"
      )
      nil
    end

    def fetch_stripe_invoice(invoice_id)
      Stripe::Invoice.retrieve(invoice_id)
    rescue Stripe::StripeError => e
      Rails.logger.error("[Bookclub] Error fetching Stripe invoice #{invoice_id}: #{e.message}")
      nil
    end
  end
end
