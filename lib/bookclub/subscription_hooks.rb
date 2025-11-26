# frozen_string_literal: true

module Bookclub
  module SubscriptionHooks
    extend ActiveSupport::Concern

    included do
      after_action :process_bookclub_subscription, only: [:create]
    end

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
      ].include?(event_type)
    end

    def process_bookclub_event(event, event_type)
      case event_type
      when "checkout.session.completed"
        handle_checkout_completed(event)
      when "customer.subscription.created", "customer.subscription.updated"
        handle_subscription_created_or_updated(event)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event)
      end
    end

    def handle_checkout_completed(event)
      checkout_session = event[:data][:object]
      return unless checkout_session[:status] == "complete"

      email = checkout_session[:customer_email]
      return unless email

      user = User.find_by_username_or_email(email)
      return unless user

      subscription_id = checkout_session[:subscription]
      product_id = extract_product_id_from_checkout(checkout_session)

      return unless product_id

      invoke_subscription_integration(
        event_type: "checkout.completed",
        user: user,
        product_id: product_id,
        subscription_data: { id: subscription_id, status: "active" },
      )
    end

    def handle_subscription_created_or_updated(event)
      subscription = event[:data][:object]
      status = subscription[:status]
      return unless %w[complete active].include?(status)

      customer_id = subscription[:customer]
      product_id = subscription.dig(:plan, :product)

      return unless customer_id && product_id

      user = find_user_by_customer_id(customer_id)
      return unless user

      invoke_subscription_integration(
        event_type: "subscription.updated",
        user: user,
        product_id: product_id,
        subscription_data: subscription,
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
        event_type: "subscription.deleted",
        user: user,
        product_id: product_id,
        subscription_data: subscription,
      )
    end

    def invoke_subscription_integration(event_type:, user:, product_id:, subscription_data:)
      result =
        Bookclub::SubscriptionIntegration.call(
          event_type: event_type,
          user: user,
          product_id: product_id,
          subscription_data: subscription_data,
        )

      if result.failure?
        Rails.logger.warn(
          "[Bookclub] Subscription integration failed for user #{user.id}: #{result.inspect_steps}",
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
      Rails.logger.error(
        "[Bookclub] Error fetching line items for checkout session: #{e.message}",
      )
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
  end
end
