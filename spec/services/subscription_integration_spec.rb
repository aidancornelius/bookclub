# frozen_string_literal: true

RSpec.describe Bookclub::SubscriptionIntegration do
  fab!(:user)
  fab!(:admin, :admin)

  before do
    SiteSetting.bookclub_enabled = true
    SiteSetting.bookclub_stripe_integration = true
    SiteSetting.discourse_subscriptions_enabled = true
    stub_const("DiscourseSubscriptions", Module.new)
  end

  fab!(:publication_category) do
    cat = Fabricate(:category, name: "Test Publication")
    cat.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
    cat.custom_fields[Bookclub::PUBLICATION_SLUG] = "test-pub"
    cat.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
      "readers" => "reader",
      "members" => "member"
    }
    cat.save_custom_fields
    cat
  end

  fab!(:reader_group) { Fabricate(:group, name: "readers") }
  fab!(:member_group) { Fabricate(:group, name: "members") }

  let(:subscription_data) do
    {
      id: "sub_123",
      status: "active",
      plan: {
        metadata: {
          group_name: "readers"
        }
      }
    }
  end

  describe "validations" do
    it "requires event_type" do
      result = described_class.call(
        event_type: nil,
        user: user,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_failure
      expect(result[:exception]).to be_a(ActiveModel::ValidationError)
    end

    it "requires subscription_data" do
      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_123",
        subscription_data: nil
      )

      expect(result).to be_failure
      expect(result[:exception]).to be_a(ActiveModel::ValidationError)
    end

    it "requires user" do
      result = described_class.call(
        event_type: "subscription.created",
        user: nil,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_failure
      expect(result[:exception]).to be_a(ActiveModel::ValidationError)
    end
  end

  describe "policies" do
    it "fails when Stripe integration is disabled" do
      SiteSetting.bookclub_stripe_integration = false

      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_failure
    end

    it "fails when DiscourseSubscriptions is not available" do
      hide_const("DiscourseSubscriptions")

      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_failure
    end

    it "fails when discourse_subscriptions is disabled" do
      SiteSetting.discourse_subscriptions_enabled = false

      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_failure
    end
  end

  describe "#fetch_publication" do
    it "fetches publication by product ID metadata" do
      stripe_product = double(
        metadata: {
          bookclub_publication_id: publication_category.id.to_s
        }
      )
      allow(Stripe::Product).to receive(:retrieve).with("prod_123").and_return(stripe_product)

      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_success
    end

    it "handles missing product ID gracefully" do
      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: nil,
        subscription_data: subscription_data
      )

      expect(result).to be_success
    end

    it "handles Stripe errors when fetching product" do
      allow(Stripe::Product).to receive(:retrieve).and_raise(Stripe::StripeError.new("Product not found"))

      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_invalid",
        subscription_data: subscription_data
      )

      expect(result).to be_success
    end
  end

  describe "#process_subscription_event" do
    let(:stripe_product) do
      double(metadata: { bookclub_publication_id: publication_category.id.to_s })
    end

    before do
      allow(Stripe::Product).to receive(:retrieve).and_return(stripe_product)
    end

    context "subscription.created event" do
      it "grants access to the publication" do
        result = described_class.call(
          event_type: "subscription.created",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )

        expect(result).to be_success
        expect(reader_group.users.include?(user)).to eq(true)
      end

      it "stores subscription metadata" do
        result = described_class.call(
          event_type: "subscription.created",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )

        expect(result).to be_success
        user.reload

        metadata = user.custom_fields["bookclub_subscriptions"]
        expect(metadata).to be_present
        expect(metadata[publication_category.id.to_s]["subscription_id"]).to eq("sub_123")
        expect(metadata[publication_category.id.to_s]["status"]).to eq("active")
      end

      it "sends access granted notification" do
        expect do
          described_class.call(
            event_type: "subscription.created",
            user: user,
            product_id: "prod_123",
            subscription_data: subscription_data
          )
        end.to change { SystemMessage.count }.by(1)
      end
    end

    context "subscription.updated event" do
      it "grants access to the publication" do
        result = described_class.call(
          event_type: "subscription.updated",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )

        expect(result).to be_success
        expect(reader_group.users.include?(user)).to eq(true)
      end
    end

    context "checkout.completed event" do
      it "grants access to the publication" do
        result = described_class.call(
          event_type: "checkout.completed",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )

        expect(result).to be_success
        expect(reader_group.users.include?(user)).to eq(true)
      end
    end

    context "subscription.deleted event" do
      before do
        reader_group.add(user)

        user.custom_fields["bookclub_subscriptions"] = {
          publication_category.id.to_s => {
            "subscription_id" => "sub_123",
            "status" => "active"
          }
        }
        user.save_custom_fields
      end

      it "revokes access to the publication" do
        result = described_class.call(
          event_type: "subscription.deleted",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )

        expect(result).to be_success
        expect(reader_group.users.include?(user)).to eq(false)
      end

      it "clears subscription metadata" do
        result = described_class.call(
          event_type: "subscription.deleted",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )

        expect(result).to be_success
        user.reload

        metadata = user.custom_fields["bookclub_subscriptions"]
        expect(metadata[publication_category.id.to_s]).to be_nil
      end

      it "sends access revoked notification" do
        expect do
          described_class.call(
            event_type: "subscription.deleted",
            user: user,
            product_id: "prod_123",
            subscription_data: subscription_data
          )
        end.to change { SystemMessage.count }.by(1)
      end
    end

    context "unknown event type" do
      it "logs a warning but succeeds" do
        expect(Rails.logger).to receive(:warn).with(
          /Unknown subscription event type/
        )

        result = described_class.call(
          event_type: "unknown.event",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )

        expect(result).to be_success
      end
    end
  end

  describe "#grant_access" do
    let(:stripe_product) do
      double(metadata: { bookclub_publication_id: publication_category.id.to_s })
    end

    before do
      allow(Stripe::Product).to receive(:retrieve).and_return(stripe_product)
    end

    it "does nothing when publication is nil" do
      allow(Stripe::Product).to receive(:retrieve).and_return(
        double(metadata: { bookclub_publication_id: nil })
      )

      expect do
        described_class.call(
          event_type: "subscription.created",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )
      end.not_to change { reader_group.users.count }
    end

    it "does nothing when tier group is not found" do
      bad_subscription_data = {
        id: "sub_456",
        status: "active",
        plan: {
          metadata: {
            group_name: "nonexistent_group"
          }
        }
      }

      expect do
        described_class.call(
          event_type: "subscription.created",
          user: user,
          product_id: "prod_123",
          subscription_data: bad_subscription_data
        )
      end.not_to change { Group.count }
    end

    it "does nothing when group name is missing from metadata" do
      bad_subscription_data = {
        id: "sub_789",
        status: "active",
        plan: {
          metadata: {}
        }
      }

      expect do
        described_class.call(
          event_type: "subscription.created",
          user: user,
          product_id: "prod_123",
          subscription_data: bad_subscription_data
        )
      end.not_to change { reader_group.users.count }
    end

    it "handles alternative subscription data format" do
      alt_subscription_data = {
        id: "sub_alt",
        status: "active",
        items: {
          data: [
            {
              plan: {
                metadata: {
                  group_name: "readers"
                }
              }
            }
          ]
        }
      }

      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_123",
        subscription_data: alt_subscription_data
      )

      expect(result).to be_success
      expect(reader_group.users.include?(user)).to eq(true)
    end
  end

  describe "#revoke_access" do
    let(:stripe_product) do
      double(metadata: { bookclub_publication_id: publication_category.id.to_s })
    end

    before do
      allow(Stripe::Product).to receive(:retrieve).and_return(stripe_product)
      reader_group.add(user)
    end

    it "does nothing when publication is nil" do
      allow(Stripe::Product).to receive(:retrieve).and_return(
        double(metadata: { bookclub_publication_id: nil })
      )

      expect do
        described_class.call(
          event_type: "subscription.deleted",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )
      end.not_to change { reader_group.users.count }
    end

    it "does nothing when group is not found" do
      bad_subscription_data = {
        id: "sub_456",
        status: "canceled",
        plan: {
          metadata: {
            group_name: "nonexistent_group"
          }
        }
      }

      expect do
        described_class.call(
          event_type: "subscription.deleted",
          user: user,
          product_id: "prod_123",
          subscription_data: bad_subscription_data
        )
      end.not_to change { reader_group.users.count }
    end
  end

  describe "notification error handling" do
    let(:stripe_product) do
      double(metadata: { bookclub_publication_id: publication_category.id.to_s })
    end

    before do
      allow(Stripe::Product).to receive(:retrieve).and_return(stripe_product)
    end

    it "handles notification errors gracefully when granting access" do
      allow(SystemMessage).to receive(:create_from_system_user).and_raise(StandardError.new("SMTP error"))

      expect(Rails.logger).to receive(:error).with(/Error sending access granted notification/)

      result = described_class.call(
        event_type: "subscription.created",
        user: user,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_success
      expect(reader_group.users.include?(user)).to eq(true)
    end

    it "handles notification errors gracefully when revoking access" do
      reader_group.add(user)
      allow(SystemMessage).to receive(:create_from_system_user).and_raise(StandardError.new("SMTP error"))

      expect(Rails.logger).to receive(:error).with(/Error sending access revoked notification/)

      result = described_class.call(
        event_type: "subscription.deleted",
        user: user,
        product_id: "prod_123",
        subscription_data: subscription_data
      )

      expect(result).to be_success
      expect(reader_group.users.include?(user)).to eq(false)
    end
  end

  describe "#publication_url" do
    let(:stripe_product) do
      double(metadata: { bookclub_publication_id: publication_category.id.to_s })
    end

    before do
      allow(Stripe::Product).to receive(:retrieve).and_return(stripe_product)
    end

    it "uses publication slug for URL" do
      publication_category.custom_fields[Bookclub::PUBLICATION_SLUG] = "custom-slug"
      publication_category.save_custom_fields

      expect do
        described_class.call(
          event_type: "subscription.created",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )
      end.to change { SystemMessage.count }.by(1)
    end

    it "falls back to category slug if publication slug is not set" do
      publication_category.custom_fields.delete(Bookclub::PUBLICATION_SLUG)
      publication_category.save_custom_fields

      expect do
        described_class.call(
          event_type: "subscription.created",
          user: user,
          product_id: "prod_123",
          subscription_data: subscription_data
        )
      end.to change { SystemMessage.count }.by(1)
    end
  end
end
