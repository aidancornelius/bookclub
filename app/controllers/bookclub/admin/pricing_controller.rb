# frozen_string_literal: true

module Bookclub
  module Admin
    class PricingController < ::Admin::AdminController
      requires_plugin 'bookclub'

      before_action :find_publication

      def show
        pricing_config = @publication.custom_fields[Bookclub::PRICING_CONFIG] || {}

        render json: {
          publication: serialize_publication(@publication),
          pricing_config: pricing_config,
          stripe_configured: stripe_configured?,
          available_groups: available_groups
        }
      end

      def update
        pricing_params = params.require(:pricing_config).permit(
          :enabled,
          :preview_chapters,
          :one_time_price_id,
          :one_time_amount,
          :subscription_price_id,
          :subscription_amount,
          :subscription_interval,
          :access_group
        )

        # Validate access group exists or create it
        if pricing_params[:access_group].present?
          ensure_access_group(pricing_params[:access_group])
        end

        # Convert to hash and ensure enabled is a proper boolean
        config = pricing_params.to_h
        config['enabled'] = ActiveModel::Type::Boolean.new.cast(config['enabled'])
        config['preview_chapters'] = config['preview_chapters'].to_i if config['preview_chapters'].present?

        # Store pricing config
        @publication.custom_fields[Bookclub::PRICING_CONFIG] = config
        @publication.save_custom_fields

        render json: {
          success: true,
          pricing_config: @publication.custom_fields[Bookclub::PRICING_CONFIG]
        }
      end

      def create_stripe_product
        return render json: { error: 'stripe_not_configured' }, status: :service_unavailable unless stripe_configured?

        # Check if product already exists
        existing_product_id = @publication.custom_fields[Bookclub::STRIPE_PRODUCT_ID]
        if existing_product_id.present?
          return render json: { error: 'product_exists', stripe_product_id: existing_product_id }, status: :bad_request
        end

        set_stripe_api_key

        begin
          # Create Stripe product
          product = ::Stripe::Product.create({
            name: @publication.name,
            description: @publication.custom_fields[Bookclub::PUBLICATION_DESCRIPTION] || "Access to #{@publication.name}",
            metadata: {
              bookclub_publication_id: @publication.id,
              bookclub_publication_slug: @publication.custom_fields[Bookclub::PUBLICATION_SLUG]
            }
          })

          # Store product ID on publication
          @publication.custom_fields[Bookclub::STRIPE_PRODUCT_ID] = product.id
          @publication.save_custom_fields

          # Create default prices
          currency = SiteSetting.discourse_subscriptions_currency.downcase rescue 'usd'
          access_group = "#{@publication.custom_fields[Bookclub::PUBLICATION_SLUG]}_readers"

          # One-time price ($24.99 default)
          one_time_price = ::Stripe::Price.create({
            product: product.id,
            unit_amount: 2499,
            currency: currency,
            nickname: "One-time purchase",
            metadata: { group_name: access_group, type: 'one_time' }
          })

          # Monthly subscription ($4.99 default)
          subscription_price = ::Stripe::Price.create({
            product: product.id,
            unit_amount: 499,
            currency: currency,
            recurring: { interval: 'month' },
            nickname: "Monthly subscription",
            metadata: { group_name: access_group, type: 'subscription' }
          })

          render json: {
            success: true,
            stripe_product_id: product.id,
            prices: [
              { id: one_time_price.id, nickname: one_time_price.nickname, amount: one_time_price.unit_amount, type: 'one_time' },
              { id: subscription_price.id, nickname: subscription_price.nickname, amount: subscription_price.unit_amount, interval: 'month', type: 'recurring' }
            ]
          }
        rescue ::Stripe::StripeError => e
          Rails.logger.error("[Bookclub] Error creating Stripe product: #{e.message}")
          render json: { error: 'stripe_error', message: e.message }, status: :unprocessable_entity
        end
      end

      def sync_stripe
        return render json: { error: 'stripe_not_configured' }, status: :service_unavailable unless stripe_configured?

        stripe_product_id = @publication.custom_fields[Bookclub::STRIPE_PRODUCT_ID]
        return render json: { error: 'no_stripe_product' }, status: :bad_request if stripe_product_id.blank?

        set_stripe_api_key

        begin
          prices = ::Stripe::Price.list({ product: stripe_product_id, active: true })

          stripe_prices = prices.data.map do |price|
            {
              id: price.id,
              nickname: price.nickname,
              amount: price.unit_amount,
              currency: price.currency,
              type: price.type,
              interval: price.recurring&.interval,
              metadata: price.metadata.to_h
            }
          end

          render json: {
            success: true,
            stripe_product_id: stripe_product_id,
            prices: stripe_prices
          }
        rescue ::Stripe::StripeError => e
          render json: { error: 'stripe_error', message: e.message }, status: :unprocessable_entity
        end
      end

      private

      def find_publication
        slug = params[:publication_slug] || params[:slug]
        @publication = Category.joins(
          "LEFT JOIN category_custom_fields ccf ON ccf.category_id = categories.id AND ccf.name = '#{Bookclub::PUBLICATION_SLUG}'"
        ).where("ccf.value = ?", slug).first

        raise Discourse::NotFound unless @publication
      end

      def serialize_publication(publication)
        {
          id: publication.id,
          name: publication.name,
          slug: publication.custom_fields[Bookclub::PUBLICATION_SLUG],
          stripe_product_id: publication.custom_fields[Bookclub::STRIPE_PRODUCT_ID]
        }
      end

      def stripe_configured?
        return false unless SiteSetting.bookclub_stripe_integration
        return false unless defined?(DiscourseSubscriptions)

        SiteSetting.respond_to?(:discourse_subscriptions_secret_key) &&
          SiteSetting.discourse_subscriptions_secret_key.present?
      end

      def set_stripe_api_key
        ::Stripe.api_key = SiteSetting.discourse_subscriptions_secret_key
      end

      def available_groups
        Group.where(automatic: false).order(:name).pluck(:name)
      end

      def ensure_access_group(group_name)
        return if Group.exists?(name: group_name)

        # Auto-create the access group if it doesn't exist
        Group.create!(
          name: group_name,
          visibility_level: Group.visibility_levels[:members],
          primary_group: false,
          title: "#{@publication.name} Readers",
          automatic: false
        )
      end
    end
  end
end
