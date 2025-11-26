import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import LoadingSpinner from "discourse/components/loading-spinner";
import icon from "discourse/helpers/d-icon";
import { and, not, or } from "discourse/truth-helpers";

/**
 * Component that displays user's access status for a publication
 * Shows current tier, upgrade options, or login prompt
 * @component BookclubAccessStatus
 * @param {string} @publicationSlug - The publication slug
 * @param {boolean} @compact - Show compact version (default: false)
 */
export default class BookclubAccessStatus extends Component {
  @service bookclubSubscriptions;
  @service currentUser;
  @service router;

  @tracked subscriptionData = null;
  @tracked pricingData = null;
  @tracked isLoadingData = true;
  @tracked error = null;

  constructor() {
    super(...arguments);
    this.loadData();
  }

  /**
   * Load subscription and pricing data
   */
  @action
  async loadData() {
    this.isLoadingData = true;
    this.error = null;

    try {
      const [subscription, pricing] = await Promise.all([
        this.currentUser
          ? this.bookclubSubscriptions.getSubscriptionStatus(
              this.args.publicationSlug
            )
          : Promise.resolve(null),
        this.bookclubSubscriptions.getPricingTiers(this.args.publicationSlug),
      ]);

      this.subscriptionData = subscription;
      this.pricingData = pricing;
    } catch (err) {
      this.error = err.message || "Failed to load access information";
    } finally {
      this.isLoadingData = false;
    }
  }

  /**
   * Check if user has any access
   * @returns {boolean}
   */
  get hasAccess() {
    return this.subscriptionData?.has_access || false;
  }

  /**
   * Get current tier name
   * @returns {string|null}
   */
  get currentTierName() {
    return this.subscriptionData?.tier_name || null;
  }

  /**
   * Get current tier ID
   * @returns {string|null}
   */
  get currentTierId() {
    return this.subscriptionData?.tier_id || null;
  }

  /**
   * Get subscription status
   * @returns {string|null}
   */
  get subscriptionStatus() {
    return this.subscriptionData?.status || null;
  }

  /**
   * Check if subscription is active
   * @returns {boolean}
   */
  get isActive() {
    return this.subscriptionStatus === "active";
  }

  /**
   * Check if subscription is trialing
   * @returns {boolean}
   */
  get isTrialing() {
    return this.subscriptionStatus === "trialing";
  }

  /**
   * Check if subscription is past due
   * @returns {boolean}
   */
  get isPastDue() {
    return this.subscriptionStatus === "past_due";
  }

  /**
   * Check if subscription is cancelled
   * @returns {boolean}
   */
  get isCancelled() {
    return this.subscriptionStatus === "canceled";
  }

  /**
   * Get available upgrade tiers
   * @returns {Array}
   */
  get upgradeTiers() {
    if (!this.pricingData?.tiers || !this.currentTierId) {
      return [];
    }

    const currentTierIndex = this.pricingData.tiers.findIndex(
      (tier) => tier.id === this.currentTierId
    );

    if (currentTierIndex === -1) {
      return this.pricingData.tiers;
    }

    return this.pricingData.tiers.slice(currentTierIndex + 1);
  }

  /**
   * Check if upgrades are available
   * @returns {boolean}
   */
  get hasUpgrades() {
    return this.upgradeTiers.length > 0;
  }

  /**
   * Get status badge class
   * @returns {string}
   */
  get statusBadgeClass() {
    if (this.isActive) {
      return "bookclub-access-status__badge--active";
    } else if (this.isTrialing) {
      return "bookclub-access-status__badge--trial";
    } else if (this.isPastDue) {
      return "bookclub-access-status__badge--warning";
    } else if (this.isCancelled) {
      return "bookclub-access-status__badge--cancelled";
    }
    return "";
  }

  /**
   * Get status badge text
   * @returns {string}
   */
  get statusBadgeText() {
    if (this.isActive) {
      return "Active";
    } else if (this.isTrialing) {
      return "Trial";
    } else if (this.isPastDue) {
      return "Past due";
    } else if (this.isCancelled) {
      return "Cancelled";
    }
    return "";
  }

  /**
   * Navigate to login
   */
  @action
  handleLogin() {
    this.router.transitionTo("login");
  }

  /**
   * Navigate to pricing page
   */
  @action
  viewPricing() {
    if (this.args.onViewPricing) {
      this.args.onViewPricing();
    }
  }

  /**
   * Handle manage subscription
   */
  @action
  async handleManageSubscription() {
    await this.bookclubSubscriptions.openCustomerPortal(
      this.args.publicationSlug
    );
  }

  /**
   * Handle upgrade click
   * @param {string} priceId - The Stripe price ID
   */
  @action
  async handleUpgrade(priceId) {
    await this.bookclubSubscriptions.initiateCheckout(
      this.args.publicationSlug,
      priceId
    );
  }

  <template>
    <div
      class="bookclub-access-status
        {{if @compact 'bookclub-access-status--compact'}}"
    >
      {{#if this.isLoadingData}}
        <div class="bookclub-access-status__loading">
          <LoadingSpinner />
        </div>
      {{else if this.error}}
        <div class="bookclub-access-status__error">
          {{icon "triangle-exclamation"}}
          <span>{{this.error}}</span>
        </div>
      {{else}}
        {{#if (not @currentUser)}}
          {{! Not logged in }}
          <div class="bookclub-access-status__guest">
            <div class="bookclub-access-status__message">
              {{icon "lock"}}
              <span>
                {{#if @compact}}
                  Log in to access
                {{else}}
                  Log in to view your access status and subscribe
                {{/if}}
              </span>
            </div>
            <DButton
              @action={{this.handleLogin}}
              @label="bookclub.access.login"
              @icon="arrow-right-to-bracket"
              class="btn-primary bookclub-access-status__btn"
            />
          </div>
        {{else if this.hasAccess}}
          {{! User has access }}
          <div class="bookclub-access-status__active">
            <div class="bookclub-access-status__header">
              <div class="bookclub-access-status__info">
                {{icon "check-circle"}}
                <div class="bookclub-access-status__details">
                  <div class="bookclub-access-status__tier">
                    {{this.currentTierName}}
                  </div>
                  {{#unless @compact}}
                    <div
                      class="bookclub-access-status__badge
                        {{this.statusBadgeClass}}"
                    >
                      {{this.statusBadgeText}}
                    </div>
                  {{/unless}}
                </div>
              </div>

              {{#unless @compact}}
                <DButton
                  @action={{this.handleManageSubscription}}
                  @label="bookclub.access.manage"
                  @icon="gear"
                  class="btn-default btn-small bookclub-access-status__manage-btn"
                />
              {{/unless}}
            </div>

            {{#if (and (not @compact) this.hasUpgrades)}}
              <div class="bookclub-access-status__upgrades">
                <div class="bookclub-access-status__upgrades-title">
                  {{icon "arrow-up"}}
                  Upgrade available
                </div>
                <div class="bookclub-access-status__upgrades-list">
                  {{#each this.upgradeTiers as |tier|}}
                    <div class="bookclub-access-status__upgrade-option">
                      <div class="bookclub-access-status__upgrade-info">
                        <span class="bookclub-access-status__upgrade-name">
                          {{tier.name}}
                        </span>
                        {{#if tier.description}}
                          <span class="bookclub-access-status__upgrade-desc">
                            {{tier.description}}
                          </span>
                        {{/if}}
                      </div>
                      <DButton
                        @action={{fn this.handleUpgrade tier.price_id}}
                        @label="bookclub.access.upgrade"
                        class="btn-primary btn-small"
                        @disabled={{this.bookclubSubscriptions.isLoading}}
                      />
                    </div>
                  {{/each}}
                </div>
              </div>
            {{/if}}

            {{#if (and (not @compact) (or this.isPastDue this.isCancelled))}}
              <div class="bookclub-access-status__warning">
                {{icon "triangle-exclamation"}}
                {{#if this.isPastDue}}
                  <span>
                    Your subscription payment is past due. Please update your
                    payment method.
                  </span>
                {{else if this.isCancelled}}
                  <span>
                    Your subscription has been cancelled. You may lose access at
                    the end of your billing period.
                  </span>
                {{/if}}
              </div>
            {{/if}}
          </div>
        {{else}}
          {{! User has no access }}
          <div class="bookclub-access-status__no-access">
            <div class="bookclub-access-status__message">
              {{icon "lock"}}
              <span>
                {{#if @compact}}
                  No access
                {{else}}
                  You don't have access to this publication
                {{/if}}
              </span>
            </div>
            <DButton
              @action={{this.viewPricing}}
              @label="bookclub.access.get_access"
              @icon="cart-shopping"
              class="btn-primary bookclub-access-status__btn"
            />
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
