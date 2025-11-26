import Service, { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import {
  fetchPricingTiers,
  fetchSubscriptionStatus,
  createCheckoutSession,
  createPortalSession,
} from "../lib/bookclub-api";

/**
 * Service for managing Bookclub subscriptions and pricing
 * Fetches and caches subscription data, handles Stripe integration
 * @class BookclubSubscriptionsService
 */
export default class BookclubSubscriptionsService extends Service {
  @service currentUser;
  @service router;

  @tracked pricingCache = {};
  @tracked subscriptionCache = {};
  @tracked isLoading = false;

  /**
   * Fetch pricing tiers for a publication
   * @param {string} publicationSlug - The publication slug
   * @param {boolean} forceRefresh - Force refresh the cache
   * @returns {Promise<Object>} Promise resolving to pricing data
   */
  async getPricingTiers(publicationSlug, forceRefresh = false) {
    if (!forceRefresh && this.pricingCache[publicationSlug]) {
      return this.pricingCache[publicationSlug];
    }

    this.isLoading = true;
    try {
      const data = await fetchPricingTiers(publicationSlug);
      this.pricingCache[publicationSlug] = data;
      return data;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Fetch user's subscription status for a publication
   * @param {string} publicationSlug - The publication slug
   * @param {boolean} forceRefresh - Force refresh the cache
   * @returns {Promise<Object>} Promise resolving to subscription data
   */
  async getSubscriptionStatus(publicationSlug, forceRefresh = false) {
    if (!this.currentUser) {
      return null;
    }

    if (!forceRefresh && this.subscriptionCache[publicationSlug]) {
      return this.subscriptionCache[publicationSlug];
    }

    this.isLoading = true;
    try {
      const data = await fetchSubscriptionStatus(publicationSlug);
      this.subscriptionCache[publicationSlug] = data;
      return data;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Initiate Stripe Checkout for a pricing tier
   * @param {string} publicationSlug - The publication slug
   * @param {string} priceId - The Stripe price ID
   * @returns {Promise<void>}
   */
  async initiateCheckout(publicationSlug, priceId) {
    if (!this.currentUser) {
      this.router.transitionTo("login");
      return;
    }

    const currentUrl = window.location.href;
    const successUrl = `${window.location.origin}/bookclub/publications/${publicationSlug}/subscription-success`;
    const cancelUrl = currentUrl;

    this.isLoading = true;
    try {
      const response = await createCheckoutSession(
        publicationSlug,
        priceId,
        successUrl,
        cancelUrl
      );

      if (response.checkout_url) {
        window.location.href = response.checkout_url;
      }
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Open Stripe Customer Portal
   * @param {string} publicationSlug - The publication slug
   * @returns {Promise<void>}
   */
  async openCustomerPortal(publicationSlug) {
    if (!this.currentUser) {
      return;
    }

    const returnUrl = window.location.href;

    this.isLoading = true;
    try {
      const response = await createPortalSession(publicationSlug, returnUrl);

      if (response.portal_url) {
        window.location.href = response.portal_url;
      }
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Clear cache for a publication
   * @param {string} publicationSlug - The publication slug
   */
  clearCache(publicationSlug) {
    delete this.pricingCache[publicationSlug];
    delete this.subscriptionCache[publicationSlug];
  }

  /**
   * Clear all caches
   */
  clearAllCaches() {
    this.pricingCache = {};
    this.subscriptionCache = {};
  }

  /**
   * Check if user has access to a publication
   * @param {string} publicationSlug - The publication slug
   * @returns {Promise<boolean>}
   */
  async hasAccess(publicationSlug) {
    const subscription = await this.getSubscriptionStatus(publicationSlug);
    return subscription?.has_access || false;
  }

  /**
   * Get the user's current tier for a publication
   * @param {string} publicationSlug - The publication slug
   * @returns {Promise<string|null>} The tier name or null
   */
  async getCurrentTier(publicationSlug) {
    const subscription = await this.getSubscriptionStatus(publicationSlug);
    return subscription?.tier || null;
  }
}
