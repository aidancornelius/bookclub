import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

/**
 * API helper for Bookclub endpoints
 * Wraps fetch calls with consistent error handling
 */

/**
 * Fetch pricing tiers for a publication
 * @param {string} publicationSlug - The publication slug
 * @returns {Promise<Object>} Promise resolving to pricing data
 */
export function fetchPricingTiers(publicationSlug) {
  return ajax(`/bookclub/publications/${publicationSlug}/pricing.json`, {
    type: "GET",
  }).catch((error) => {
    // Handle 503 (service unavailable) for Stripe not configured gracefully
    if (error.jqXHR?.status === 503) {
      return error.jqXHR.responseJSON || error;
    }
    return popupAjaxError(error);
  });
}

/**
 * Fetch user's subscription status for a publication
 * @param {string} publicationSlug - The publication slug
 * @returns {Promise<Object>} Promise resolving to subscription data
 */
export function fetchSubscriptionStatus(publicationSlug) {
  return ajax(`/bookclub/publications/${publicationSlug}/subscription.json`, {
    type: "GET",
  }).catch(popupAjaxError);
}

/**
 * Create a Stripe Checkout session
 * @param {string} publicationSlug - The publication slug
 * @param {string} priceId - The Stripe price ID
 * @param {string} successUrl - URL to redirect to on success
 * @param {string} cancelUrl - URL to redirect to on cancel
 * @returns {Promise<Object>} Promise resolving to checkout session data with URL
 */
export function createCheckoutSession(
  publicationSlug,
  priceId,
  successUrl,
  cancelUrl
) {
  return ajax(`/bookclub/publications/${publicationSlug}/checkout.json`, {
    type: "POST",
    data: {
      price_id: priceId,
      success_url: successUrl,
      cancel_url: cancelUrl,
    },
  }).catch(popupAjaxError);
}

/**
 * Create a Stripe Customer Portal session
 * @param {string} publicationSlug - The publication slug
 * @param {string} returnUrl - URL to redirect to after portal session
 * @returns {Promise<Object>} Promise resolving to portal session data with URL
 */
export function createPortalSession(publicationSlug, returnUrl) {
  return ajax(
    `/bookclub/publications/${publicationSlug}/customer-portal.json`,
    {
      type: "POST",
      data: {
        return_url: returnUrl,
      },
    }
  ).catch(popupAjaxError);
}

/**
 * Fetch reading progress for a publication
 * @param {string} publicationSlug - The publication slug
 * @returns {Promise<Object>} Promise resolving to reading progress data
 */
export function fetchReadingProgress(publicationSlug) {
  return ajax(`/bookclub/reading-progress/${publicationSlug}.json`, {
    type: "GET",
  }).catch(popupAjaxError);
}

/**
 * Update reading progress for a publication
 * @param {string} publicationSlug - The publication slug
 * @param {Object} progressData - Progress data to update
 * @returns {Promise<Object>} Promise resolving to updated progress data
 */
export function updateReadingProgress(publicationSlug, progressData) {
  return ajax(`/bookclub/reading-progress/${publicationSlug}.json`, {
    type: "PUT",
    data: progressData,
  }).catch(popupAjaxError);
}
