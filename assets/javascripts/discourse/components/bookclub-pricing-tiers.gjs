import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { and, not } from "discourse/truth-helpers";

/**
 * Component that displays available pricing tiers for a publication
 * Shows pricing from Stripe, indicates current tier, and provides purchase buttons
 * @component BookclubPricingTiers
 * @param {string} @publicationSlug - The publication slug
 */
export default class BookclubPricingTiers extends Component {
  @service bookclubSubscriptions;
  @service currentUser;

  @tracked pricingData = null;
  @tracked subscriptionData = null;
  @tracked isLoadingData = true;
  @tracked error = null;

  constructor() {
    super(...arguments);
    this.loadData();
  }

  /**
   * Load pricing and subscription data
   */
  @action
  async loadData() {
    this.isLoadingData = true;
    this.error = null;

    try {
      const [pricing, subscription] = await Promise.all([
        this.bookclubSubscriptions.getPricingTiers(this.args.publicationSlug),
        this.currentUser
          ? this.bookclubSubscriptions.getSubscriptionStatus(
              this.args.publicationSlug
            )
          : Promise.resolve(null),
      ]);

      this.pricingData = pricing;
      this.subscriptionData = subscription;
    } catch (err) {
      this.error = err.message || "Failed to load pricing information";
    } finally {
      this.isLoadingData = false;
    }
  }

  /**
   * Get the user's current tier ID
   * @returns {string|null}
   */
  get currentTierId() {
    return this.subscriptionData?.tier_id || null;
  }

  /**
   * Check if a tier is the user's current tier
   * @param {string} tierId - The tier ID to check
   * @returns {boolean}
   */
  isCurrentTier(tierId) {
    return this.currentTierId === tierId;
  }

  /**
   * Handle purchase button click
   * @param {string} priceId - The Stripe price ID
   */
  @action
  async handlePurchase(priceId) {
    await this.bookclubSubscriptions.initiateCheckout(
      this.args.publicationSlug,
      priceId
    );
  }

  /**
   * Handle manage subscription click
   */
  @action
  async handleManageSubscription() {
    await this.bookclubSubscriptions.openCustomerPortal(
      this.args.publicationSlug
    );
  }

  /**
   * Format currency amount
   * @param {number} amount - Amount in cents
   * @param {string} currency - Currency code
   * @returns {string}
   */
  formatPrice(amount, currency) {
    const value = amount / 100;
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency.toUpperCase(),
    }).format(value);
  }

  /**
   * Format billing interval
   * @param {string} interval - The billing interval (month, year, etc.)
   * @param {number} intervalCount - The interval count
   * @returns {string}
   */
  formatInterval(interval, intervalCount = 1) {
    if (intervalCount === 1) {
      return `per ${interval}`;
    }
    return `every ${intervalCount} ${interval}s`;
  }

  <template>
    <div class="bookclub-pricing-tiers">
      {{#if this.isLoadingData}}
        <div class="bookclub-pricing-tiers__loading">
          {{loadingSpinner}}
        </div>
      {{else if this.error}}
        <div class="bookclub-pricing-tiers__error">
          {{icon "triangle-exclamation"}}
          <span>{{this.error}}</span>
        </div>
      {{else if this.pricingData.tiers}}
        <div class="bookclub-pricing-tiers__list">
          {{#each this.pricingData.tiers as |tier|}}
            <div
              class="bookclub-pricing-tier
                {{if
                  (this.isCurrentTier tier.id)
                  'bookclub-pricing-tier--current'
                }}"
            >
              <div class="bookclub-pricing-tier__header">
                <h3 class="bookclub-pricing-tier__name">{{tier.name}}</h3>
                {{#if (this.isCurrentTier tier.id)}}
                  <span class="bookclub-pricing-tier__badge">
                    {{icon "check-circle"}}
                    Current
                  </span>
                {{/if}}
              </div>

              {{#if tier.description}}
                <p class="bookclub-pricing-tier__description">
                  {{tier.description}}
                </p>
              {{/if}}

              <div class="bookclub-pricing-tier__price">
                <span class="bookclub-pricing-tier__amount">
                  {{this.formatPrice tier.price tier.currency}}
                </span>
                <span class="bookclub-pricing-tier__interval">
                  {{this.formatInterval tier.interval tier.interval_count}}
                </span>
              </div>

              {{#if tier.features}}
                <ul class="bookclub-pricing-tier__features">
                  {{#each tier.features as |feature|}}
                    <li class="bookclub-pricing-tier__feature">
                      {{icon "check"}}
                      <span>{{feature}}</span>
                    </li>
                  {{/each}}
                </ul>
              {{/if}}

              <div class="bookclub-pricing-tier__actions">
                {{#if (this.isCurrentTier tier.id)}}
                  <DButton
                    @action={{this.handleManageSubscription}}
                    @label="bookclub.pricing.manage_subscription"
                    @icon="gear"
                    class="btn-default bookclub-pricing-tier__btn"
                  />
                {{else if
                  (and this.currentUser (not (this.isCurrentTier tier.id)))
                }}
                  <DButton
                    @action={{fn this.handlePurchase tier.price_id}}
                    @label={{if
                      this.currentTierId
                      "bookclub.pricing.change_tier"
                      "bookclub.pricing.subscribe"
                    }}
                    class="btn-primary bookclub-pricing-tier__btn"
                    @disabled={{this.bookclubSubscriptions.isLoading}}
                  />
                {{else}}
                  <DButton
                    @action={{fn this.handlePurchase tier.price_id}}
                    @label="bookclub.pricing.get_access"
                    class="btn-primary bookclub-pricing-tier__btn"
                  />
                {{/if}}
              </div>
            </div>
          {{/each}}
        </div>

        {{#if this.currentTierId}}
          <div class="bookclub-pricing-tiers__footer">
            <p class="bookclub-pricing-tiers__note">
              {{icon "circle-info"}}
              You can manage your subscription or update payment details by
              clicking "Manage subscription"
            </p>
          </div>
        {{/if}}
      {{else}}
        <div class="bookclub-pricing-tiers__empty">
          <p>No pricing tiers available for this publication.</p>
        </div>
      {{/if}}
    </div>
  </template>
}
