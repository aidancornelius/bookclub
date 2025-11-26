# frozen_string_literal: true

RSpec.describe Bookclub::PricingController do
  fab!(:user)
  fab!(:admin, :admin)

  before do
    SiteSetting.bookclub_enabled = true
    SiteSetting.bookclub_stripe_integration = true
  end

  fab!(:publication_category) do
    cat = Fabricate(:category, name: "Test Publication")
    cat.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
    cat.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
    cat.custom_fields[Bookclub::PUBLICATION_SLUG] = "test-pub"
    cat.custom_fields["bookclub_stripe_product_id"] = "prod_test123"
    cat.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
      "readers" => "reader",
      "members" => "member"
    }
    cat.save_custom_fields
    cat
  end

  fab!(:reader_group) { Fabricate(:group, name: "readers") }
  fab!(:member_group) { Fabricate(:group, name: "members") }

  describe "#tiers" do
    context "when Stripe is not configured" do
      before do
        allow(SiteSetting).to receive(:discourse_subscriptions_secret_key).and_return(nil)
      end

      it "returns 503 with stripe_not_configured error" do
        get "/bookclub/publications/test-pub/pricing.json"
        expect(response.status).to eq(503)

        json = response.parsed_body
        expect(json["error"]).to eq("stripe_not_configured")
        expect(json["manual_mode"]).to eq(true)
      end
    end

    context "when Stripe is configured" do
      before do
        allow(SiteSetting).to receive(:discourse_subscriptions_secret_key).and_return("sk_test_123")
        allow(SiteSetting).to receive(:discourse_subscriptions_enabled).and_return(true)
        stub_const("DiscourseSubscriptions", Module.new)
      end

      it "returns empty tiers when no Stripe product ID is set" do
        publication_category.custom_fields.delete("bookclub_stripe_product_id")
        publication_category.save_custom_fields

        get "/bookclub/publications/test-pub/pricing.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["tiers"]).to eq([])
        expect(json["message"]).to eq("No pricing available for this publication")
      end

      it "fetches and returns Stripe pricing tiers" do
        price1 = double(
          id: "price_123",
          nickname: "Reader Tier",
          product: double(name: "Test Product", description: "Test description"),
          unit_amount: 999,
          currency: "usd",
          recurring: double(interval: "month", interval_count: 1),
          metadata: {
            "group_name" => "readers",
            "features" => "Feature 1|Feature 2",
            "highlighted" => "true"
          }
        )

        price2 = double(
          id: "price_456",
          nickname: "Member Tier",
          product: double(name: "Test Product", description: "Test description"),
          unit_amount: 1999,
          currency: "usd",
          recurring: double(interval: "month", interval_count: 1),
          metadata: {
            "group_name" => "members",
            "features" => "All features",
            "highlighted" => "false"
          }
        )

        stripe_prices = double(data: [price1, price2])
        allow(Stripe::Price).to receive(:list).and_return(stripe_prices)
        allow(SiteSetting).to receive(:discourse_subscriptions_currency).and_return("usd")

        get "/bookclub/publications/test-pub/pricing.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["publication"]["slug"]).to eq("test-pub")
        expect(json["tiers"].length).to eq(2)
        expect(json["currency"]).to eq("usd")

        tier1 = json["tiers"][0]
        expect(tier1["id"]).to eq("price_123")
        expect(tier1["name"]).to eq("Reader Tier")
        expect(tier1["amount"]).to eq(999)
        expect(tier1["interval"]).to eq("month")
        expect(tier1["group_name"]).to eq("readers")
        expect(tier1["features"]).to eq(["Feature 1", "Feature 2"])
        expect(tier1["highlighted"]).to eq(true)
      end

      it "includes current user tier when logged in" do
        reader_group.add(user)
        sign_in(user)

        price1 = double(
          id: "price_123",
          nickname: "Reader Tier",
          product: double(name: "Test Product", description: "Test description"),
          unit_amount: 999,
          currency: "usd",
          recurring: double(interval: "month", interval_count: 1),
          metadata: { "group_name" => "readers" }
        )

        stripe_prices = double(data: [price1])
        allow(Stripe::Price).to receive(:list).and_return(stripe_prices)

        get "/bookclub/publications/test-pub/pricing.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["user_tier"]).to eq("reader")
      end

      it "returns nil user_tier when not logged in" do
        price1 = double(
          id: "price_123",
          nickname: "Reader Tier",
          product: double(name: "Test Product", description: "Test description"),
          unit_amount: 999,
          currency: "usd",
          recurring: double(interval: "month", interval_count: 1),
          metadata: { "group_name" => "readers" }
        )

        stripe_prices = double(data: [price1])
        allow(Stripe::Price).to receive(:list).and_return(stripe_prices)

        get "/bookclub/publications/test-pub/pricing.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["user_tier"]).to be_nil
      end
    end

    it "returns 404 for non-existent publication" do
      get "/bookclub/publications/nonexistent/pricing.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#subscription_status" do
    it "requires authentication" do
      get "/bookclub/publications/test-pub/subscription.json"
      expect(response.status).to eq(401)

      json = response.parsed_body
      expect(json["error"]).to eq("not_logged_in")
    end

    context "when logged in" do
      before { sign_in(user) }

      it "returns subscription status for user without access" do
        get "/bookclub/publications/test-pub/subscription.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["has_access"]).to eq(false)
        expect(json["current_tier"]).to be_nil
        expect(json["is_author"]).to eq(false)
        expect(json["is_editor"]).to eq(false)
      end

      it "returns subscription status for user with access" do
        reader_group.add(user)

        user.custom_fields[Bookclub::SUBSCRIPTION_METADATA] = {
          "test-pub" => {
            "subscription_id" => "sub_123",
            "status" => "active",
            "granted_at" => "2025-01-01T00:00:00Z"
          }
        }
        user.save_custom_fields

        get "/bookclub/publications/test-pub/subscription.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["has_access"]).to eq(true)
        expect(json["current_tier"]).to eq("reader")
        expect(json["subscription"]).to be_present
        expect(json["subscription"]["subscription_id"]).to eq("sub_123")
      end

      it "returns true for is_author when user is publication author" do
        publication_category.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS] = [user.id]
        publication_category.save_custom_fields

        get "/bookclub/publications/test-pub/subscription.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["is_author"]).to eq(true)
      end

      it "returns true for is_editor when user is publication editor" do
        publication_category.custom_fields[Bookclub::PUBLICATION_EDITOR_IDS] = [user.id]
        publication_category.save_custom_fields

        get "/bookclub/publications/test-pub/subscription.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["is_editor"]).to eq(true)
      end
    end

    it "returns 404 for non-existent publication" do
      sign_in(user)

      get "/bookclub/publications/nonexistent/subscription.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#create_checkout" do
    before do
      allow(SiteSetting).to receive(:discourse_subscriptions_secret_key).and_return("sk_test_123")
      stub_const("DiscourseSubscriptions", Module.new)
    end

    it "requires authentication" do
      post "/bookclub/publications/test-pub/checkout.json", params: { price_id: "price_123" }
      expect(response.status).to eq(401)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "requires price_id parameter" do
        post "/bookclub/publications/test-pub/checkout.json"
        expect(response.status).to eq(400)

        json = response.parsed_body
        expect(json["error"]).to eq("price_id_required")
      end

      it "creates a Stripe checkout session" do
        checkout_session = double(
          url: "https://checkout.stripe.com/session/123",
          id: "cs_test_123"
        )

        expect(Stripe::Checkout::Session).to receive(:create).with(
          hash_including(
            mode: "subscription",
            customer_email: user.email,
            line_items: [{ price: "price_123", quantity: 1 }],
            metadata: hash_including(
              user_id: user.id,
              username: user.username,
              publication_id: publication_category.id,
              publication_slug: "test-pub"
            )
          )
        ).and_return(checkout_session)

        price = double(type: "recurring")
        allow(Stripe::Price).to receive(:retrieve).and_return(price)

        post "/bookclub/publications/test-pub/checkout.json",
             params: {
               price_id: "price_123",
               success_url: "https://example.com/success",
               cancel_url: "https://example.com/cancel"
             }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["checkout_url"]).to eq("https://checkout.stripe.com/session/123")
        expect(json["session_id"]).to eq("cs_test_123")
      end

      it "determines payment mode for one-time prices" do
        checkout_session = double(
          url: "https://checkout.stripe.com/session/456",
          id: "cs_test_456"
        )

        price = double(type: "one_time")
        allow(Stripe::Price).to receive(:retrieve).and_return(price)

        expect(Stripe::Checkout::Session).to receive(:create).with(
          hash_including(mode: "payment")
        ).and_return(checkout_session)

        post "/bookclub/publications/test-pub/checkout.json",
             params: { price_id: "price_456" }

        expect(response.status).to eq(200)
      end

      it "handles Stripe errors gracefully" do
        allow(Stripe::Price).to receive(:retrieve).and_raise(
          Stripe::StripeError.new("Invalid price ID")
        )

        post "/bookclub/publications/test-pub/checkout.json",
             params: { price_id: "price_invalid" }

        expect(response.status).to eq(422)
        json = response.parsed_body
        expect(json["error"]).to eq("checkout_failed")
        expect(json["message"]).to eq("Invalid price ID")
      end

      it "uses default URLs when not provided" do
        checkout_session = double(url: "https://checkout.stripe.com/session/123", id: "cs_123")
        price = double(type: "recurring")
        allow(Stripe::Price).to receive(:retrieve).and_return(price)

        expect(Stripe::Checkout::Session).to receive(:create).with(
          hash_including(
            success_url: "#{Discourse.base_url}/book/test-pub?checkout=success",
            cancel_url: "#{Discourse.base_url}/book/test-pub?checkout=cancelled"
          )
        ).and_return(checkout_session)

        post "/bookclub/publications/test-pub/checkout.json", params: { price_id: "price_123" }
        expect(response.status).to eq(200)
      end
    end

    it "returns 404 for non-existent publication" do
      sign_in(user)

      post "/bookclub/publications/nonexistent/checkout.json", params: { price_id: "price_123" }
      expect(response.status).to eq(404)
    end
  end

  describe "#create_portal_session" do
    before do
      allow(SiteSetting).to receive(:discourse_subscriptions_secret_key).and_return("sk_test_123")
      stub_const("DiscourseSubscriptions", Module.new)
      stub_const("DiscourseSubscriptions::Customer", Class.new)
    end

    it "requires authentication" do
      post "/bookclub/publications/test-pub/customer-portal.json"
      expect(response.status).to eq(401)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "creates a billing portal session for existing customer" do
        customer = double(customer_id: "cus_123", user_id: user.id)
        allow(DiscourseSubscriptions::Customer).to receive(:find_by).with(user_id: user.id).and_return(customer)

        portal_session = double(url: "https://billing.stripe.com/session/123")
        expect(Stripe::BillingPortal::Session).to receive(:create).with(
          hash_including(
            customer: "cus_123",
            return_url: "#{Discourse.base_url}/library"
          )
        ).and_return(portal_session)

        post "/bookclub/publications/test-pub/customer-portal.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["portal_url"]).to eq("https://billing.stripe.com/session/123")
      end

      it "uses custom return_url when provided" do
        customer = double(customer_id: "cus_123", user_id: user.id)
        allow(DiscourseSubscriptions::Customer).to receive(:find_by).and_return(customer)

        portal_session = double(url: "https://billing.stripe.com/session/456")
        expect(Stripe::BillingPortal::Session).to receive(:create).with(
          hash_including(return_url: "https://example.com/return")
        ).and_return(portal_session)

        post "/bookclub/publications/test-pub/customer-portal.json",
             params: { return_url: "https://example.com/return" }

        expect(response.status).to eq(200)
      end

      it "returns 404 when user has no Stripe customer record" do
        allow(DiscourseSubscriptions::Customer).to receive(:find_by).with(user_id: user.id).and_return(nil)

        post "/bookclub/publications/test-pub/customer-portal.json"
        expect(response.status).to eq(404)

        json = response.parsed_body
        expect(json["error"]).to eq("no_subscription")
      end

      it "handles Stripe errors gracefully" do
        customer = double(customer_id: "cus_123", user_id: user.id)
        allow(DiscourseSubscriptions::Customer).to receive(:find_by).and_return(customer)

        allow(Stripe::BillingPortal::Session).to receive(:create).and_raise(
          Stripe::StripeError.new("Invalid customer")
        )

        post "/bookclub/publications/test-pub/customer-portal.json"
        expect(response.status).to eq(422)

        json = response.parsed_body
        expect(json["error"]).to eq("portal_failed")
      end
    end
  end
end
