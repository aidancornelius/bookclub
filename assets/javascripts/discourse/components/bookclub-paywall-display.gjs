import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import { and, not, eq } from "discourse/truth-helpers";
import I18n from "discourse-i18n";

/**
 * Inline paywall display component shown when users attempt to access paid content
 * Displays preview status, one-time purchase option, and subscription option
 * @component BookclubPaywallDisplay
 * @param {Object} @paywall - Paywall configuration data
 */
export default class BookclubPaywallDisplay extends Component {
  @service currentUser;
  @service siteSettings;
  @service router;
  @tracked checkingOut = false;
  @tracked selectedOption = null;

  get currencySymbol() {
    return this.siteSettings.bookclub_currency_symbol || "$";
  }

  get oneTimePrice() {
    const amount = this.args.paywall?.one_time_amount;
    if (!amount) {
      return null;
    }
    return this.formatPrice(amount);
  }

  get subscriptionPrice() {
    const amount = this.args.paywall?.subscription_amount;
    if (!amount) {
      return null;
    }
    return this.formatPrice(amount);
  }

  get subscriptionInterval() {
    return this.args.paywall?.subscription_interval || "month";
  }

  get hasOneTimeOption() {
    return !!this.args.paywall?.one_time_price_id;
  }

  get hasSubscriptionOption() {
    return !!this.args.paywall?.subscription_price_id;
  }

  get hasBothOptions() {
    return this.hasOneTimeOption && this.hasSubscriptionOption;
  }

  get previewEnded() {
    const paywall = this.args.paywall;
    return paywall?.preview_remaining <= 0;
  }

  get hasPreviewChapters() {
    return this.args.paywall?.preview_chapters > 0;
  }

  get previewMessage() {
    const paywall = this.args.paywall;
    if (!paywall) {
      return "";
    }

    // If no preview chapters configured, show generic premium message
    if (paywall.preview_chapters <= 0) {
      return I18n.t("bookclub.paywall.premium_content");
    }

    if (paywall.preview_remaining <= 0) {
      return I18n.t("bookclub.paywall.preview_ended", {
        count: paywall.preview_chapters,
      });
    }
    return I18n.t("bookclub.paywall.preview_remaining", {
      remaining: paywall.preview_remaining,
    });
  }

  formatPrice(amountInCents) {
    const amount = (amountInCents / 100).toFixed(2);
    return `${this.currencySymbol}${amount}`;
  }

  @action
  async checkout(type) {
    if (!this.currentUser) {
      this.router.transitionTo("login");
      return;
    }

    this.checkingOut = true;
    this.selectedOption = type;

    const paywall = this.args.paywall;
    const priceId =
      type === "one_time"
        ? paywall.one_time_price_id
        : paywall.subscription_price_id;

    try {
      const response = await ajax(
        `/bookclub/publications/${paywall.publication_slug}/checkout.json`,
        {
          type: "POST",
          data: {
            price_id: priceId,
            success_url: window.location.href,
            cancel_url: window.location.href,
          },
        }
      );

      if (response.checkout_url) {
        window.location.href = response.checkout_url;
      }
    } catch (e) {
      popupAjaxError(e);
      this.checkingOut = false;
      this.selectedOption = null;
    }
  }

  @action
  goToLogin() {
    this.router.transitionTo("login");
  }

  <template>
    <div class="bookclub-paywall-display">
      <div class="paywall-content">
        <div class="paywall-header">
          <h2>{{@paywall.publication_name}}</h2>
          <p class="preview-status">{{this.previewMessage}}</p>
        </div>

        <div class="paywall-options">
          {{#if this.hasOneTimeOption}}
            <div
              class="paywall-option
                {{if (not this.hasBothOptions) 'full-width'}}"
            >
              <div class="option-header">
                <h3>{{I18n.t "bookclub.paywall.unlock_title"}}</h3>
                <span class="price">{{this.oneTimePrice}}</span>
              </div>
              <p class="option-description">
                {{I18n.t "bookclub.paywall.unlock_description"}}
              </p>
              <ul class="features">
                <li>{{I18n.t "bookclub.paywall.features.permanent_access"}}</li>
                <li>{{I18n.t "bookclub.paywall.features.all_chapters"}}</li>
                <li>{{I18n.t
                    "bookclub.paywall.features.download_available"
                  }}</li>
              </ul>
              <DButton
                @action={{fn this.checkout "one_time"}}
                @disabled={{this.checkingOut}}
                @translatedLabel={{I18n.t
                  "bookclub.paywall.unlock_button"
                  price=this.oneTimePrice
                }}
                class="btn-primary btn-large"
              />
            </div>
          {{/if}}

          {{#if (and this.hasOneTimeOption this.hasSubscriptionOption)}}
            <div class="option-divider">
              <span>{{I18n.t "bookclub.paywall.or_divider"}}</span>
            </div>
          {{/if}}

          {{#if this.hasSubscriptionOption}}
            <div
              class="paywall-option
                {{if (not this.hasBothOptions) 'full-width'}}"
            >
              <div class="option-header">
                <h3>{{I18n.t "bookclub.paywall.subscribe_title"}}</h3>
                <span class="price">
                  {{this.subscriptionPrice}}/{{this.subscriptionInterval}}
                </span>
              </div>
              <p class="option-description">
                {{I18n.t "bookclub.paywall.subscribe_description"}}
              </p>
              <ul class="features">
                <li>{{I18n.t "bookclub.paywall.features.all_chapters"}}</li>
                <li>{{I18n.t "bookclub.paywall.features.new_content"}}</li>
                <li>{{I18n.t "bookclub.paywall.features.cancel_anytime"}}</li>
              </ul>
              <DButton
                @action={{fn this.checkout "subscription"}}
                @disabled={{this.checkingOut}}
                @translatedLabel={{if
                  (eq this.subscriptionInterval "year")
                  (I18n.t
                    "bookclub.paywall.subscribe_yearly_button"
                    price=this.subscriptionPrice
                  )
                  (I18n.t
                    "bookclub.paywall.subscribe_button"
                    price=this.subscriptionPrice
                  )
                }}
                class="btn-primary btn-large"
              />
            </div>
          {{/if}}
        </div>

        {{#unless this.currentUser}}
          <div class="login-prompt">
            <span>{{I18n.t "bookclub.paywall.login_prompt"}}</span>
            <a href="#" {{on "click" this.goToLogin}}>
              {{I18n.t "bookclub.paywall.login_link"}}
            </a>
          </div>
        {{/unless}}
      </div>
    </div>
  </template>
}
