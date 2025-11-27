import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import I18n from "discourse-i18n";
import icon from "discourse/helpers/d-icon";
import DButton from "discourse/components/d-button";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";

/**
 * Component to verify a Stripe checkout session and grant access
 * Shown when returning from Stripe checkout with a session_id
 */
export default class BookclubCheckoutVerify extends Component {
  @service router;
  @tracked status = "verifying"; // verifying, success, error
  @tracked errorMessage = null;

  constructor() {
    super(...arguments);
    this.verifyCheckout();
  }

  async verifyCheckout() {
    const { slug, sessionId } = this.args;

    try {
      const response = await ajax(
        `/bookclub/publications/${slug}/verify-checkout.json`,
        {
          type: "POST",
          data: { session_id: sessionId },
        }
      );

      if (response.success || response.has_access) {
        this.status = "success";
        // Remove checkout_session_id from URL and reload content
        setTimeout(() => this.reloadWithoutSession(), 1500);
      } else {
        this.status = "error";
        this.errorMessage = response.error || "verification_failed";
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Checkout verification error:", error);
      this.status = "error";
      this.errorMessage =
        error.jqXHR?.responseJSON?.error ||
        error.jqXHR?.responseJSON?.message ||
        "verification_failed";
    }
  }

  @action
  reloadWithoutSession() {
    // Remove checkout_session_id from URL
    const url = new URL(window.location.href);
    url.searchParams.delete("checkout_session_id");
    window.location.href = url.toString();
  }

  @action
  retry() {
    this.status = "verifying";
    this.errorMessage = null;
    this.verifyCheckout();
  }

  <template>
    <div class="bookclub-checkout-verify">
      {{#if (eq this.status "verifying")}}
        <div class="checkout-verify-processing">
          <div class="spinner-container">
            {{icon "spinner" class="fa-spin"}}
          </div>
          <h2>{{I18n.t "bookclub.checkout.processing_title"}}</h2>
          <p>{{I18n.t "bookclub.checkout.processing_message"}}</p>
        </div>
      {{else if (eq this.status "success")}}
        <div class="checkout-verify-success">
          <div class="success-icon">
            {{icon "check"}}
          </div>
          <h2>{{I18n.t "bookclub.checkout.success_title"}}</h2>
          <p>{{I18n.t "bookclub.checkout.success_message"}}</p>
          <p class="redirecting">{{I18n.t "bookclub.checkout.redirecting"}}</p>
        </div>
      {{else}}
        <div class="checkout-verify-error">
          <div class="error-icon">
            {{icon "triangle-exclamation"}}
          </div>
          <h2>{{I18n.t "bookclub.checkout.error_title"}}</h2>
          <p>{{I18n.t "bookclub.checkout.error_message"}}</p>
          {{#if this.errorMessage}}
            <p class="error-details">{{this.errorMessage}}</p>
          {{/if}}
          <div class="error-actions">
            <DButton
              @action={{this.retry}}
              @label="bookclub.checkout.retry"
              class="btn-primary"
            />
            <DButton
              @action={{this.reloadWithoutSession}}
              @label="bookclub.checkout.continue_anyway"
              class="btn-default"
            />
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
