import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import ComboBox from "select-kit/components/combo-box";
import icon from "discourse/helpers/d-icon";

/**
 * Publication pricing settings component for configuring monetisation
 * @component BookclubPublicationPricing
 * @param {Object} args.publication - Publication data
 */
export default class BookclubPublicationPricing extends Component {
  @service siteSettings;
  @tracked loading = true;
  @tracked saving = false;
  @tracked syncing = false;
  @tracked pricingConfig = {};
  @tracked stripeConfigured = false;
  @tracked availableGroups = [];
  @tracked stripePrices = [];
  @tracked stripeProductId = "";
  @tracked error = null;
  @tracked success = null;

  constructor() {
    super(...arguments);
    this.loadPricingConfig();
  }

  get intervalOptions() {
    return [
      { id: "month", name: I18n.t("bookclub.admin.pricing.interval_month") },
      { id: "year", name: I18n.t("bookclub.admin.pricing.interval_year") },
    ];
  }

  get groupOptions() {
    return this.availableGroups.map((g) => ({ id: g, name: g }));
  }

  get hasStripeProduct() {
    return !!this.stripeProductId;
  }

  @action
  updateStripeProductId(event) {
    this.stripeProductId = event.target?.value ?? event;
  }

  @action
  async loadPricingConfig() {
    this.loading = true;
    this.error = null;

    try {
      const response = await ajax(
        `/bookclub/admin/publications/${this.args.publication.slug}/pricing`
      );

      this.pricingConfig = response.pricing_config || {
        enabled: false,
        preview_chapters: this.siteSettings.bookclub_default_preview_chapters || 2,
        one_time_price_id: "",
        one_time_amount: "",
        subscription_price_id: "",
        subscription_amount: "",
        subscription_interval: "month",
        access_group: `${this.args.publication.slug}_readers`,
      };
      this.stripeConfigured = response.stripe_configured;
      this.stripeProductId = response.publication?.stripe_product_id || "";
      this.availableGroups = response.available_groups || [];
    } catch (e) {
      this.error = I18n.t("bookclub.errors.loading_failed");
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  updateField(field, event) {
    const value = event.target?.value ?? event;
    this.pricingConfig = { ...this.pricingConfig, [field]: value };
  }

  @action
  updateEnabled(event) {
    this.pricingConfig = {
      ...this.pricingConfig,
      enabled: event.target.checked
    };
  }

  @action
  updatePreviewChapters(event) {
    const value = parseInt(event.target.value, 10) || 0;
    this.pricingConfig = { ...this.pricingConfig, preview_chapters: value };
  }

  @action
  updateInterval(value) {
    this.pricingConfig = { ...this.pricingConfig, subscription_interval: value };
  }

  @action
  updateAccessGroup(value) {
    this.pricingConfig = { ...this.pricingConfig, access_group: value };
  }

  @action
  async savePricingConfig() {
    this.saving = true;
    this.error = null;
    this.success = null;

    try {
      await ajax(
        `/bookclub/admin/publications/${this.args.publication.slug}/pricing`,
        {
          type: "PUT",
          data: { pricing_config: this.pricingConfig },
        }
      );
      this.success = I18n.t("bookclub.admin.pricing.save_success");
    } catch (e) {
      this.error = I18n.t("bookclub.admin.pricing.save_error");
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  @tracked creatingProduct = false;

  @action
  async createStripeProduct() {
    this.creatingProduct = true;
    this.error = null;
    this.success = null;

    try {
      const response = await ajax(
        `/bookclub/admin/publications/${this.args.publication.slug}/pricing/create-stripe-product`,
        { type: "POST" }
      );
      this.stripeProductId = response.stripe_product_id;
      this.stripePrices = response.prices || [];

      // Auto-fill the pricing config with the created prices
      const oneTimePrice = response.prices?.find(p => p.type === 'one_time');
      const subscriptionPrice = response.prices?.find(p => p.type === 'recurring');

      if (oneTimePrice) {
        this.pricingConfig = {
          ...this.pricingConfig,
          one_time_price_id: oneTimePrice.id,
          one_time_amount: oneTimePrice.amount,
        };
      }
      if (subscriptionPrice) {
        this.pricingConfig = {
          ...this.pricingConfig,
          subscription_price_id: subscriptionPrice.id,
          subscription_amount: subscriptionPrice.amount,
          subscription_interval: subscriptionPrice.interval || 'month',
        };
      }

      this.success = "Stripe product created with default prices";
    } catch (e) {
      this.error = "Failed to create Stripe product";
      popupAjaxError(e);
    } finally {
      this.creatingProduct = false;
    }
  }

  @action
  async syncStripe() {
    this.syncing = true;
    this.error = null;

    try {
      const response = await ajax(
        `/bookclub/admin/publications/${this.args.publication.slug}/pricing/sync-stripe`,
        { type: "POST" }
      );
      this.stripePrices = response.prices || [];
      this.success = I18n.t("bookclub.admin.pricing.sync_success");
    } catch (e) {
      this.error = I18n.t("bookclub.admin.pricing.sync_error");
      popupAjaxError(e);
    } finally {
      this.syncing = false;
    }
  }

  @action
  selectStripePrice(type, priceId) {
    const price = this.stripePrices.find((p) => p.id === priceId);
    if (!price) return;

    if (type === "one_time") {
      this.pricingConfig = {
        ...this.pricingConfig,
        one_time_price_id: price.id,
        one_time_amount: price.amount,
      };
    } else {
      this.pricingConfig = {
        ...this.pricingConfig,
        subscription_price_id: price.id,
        subscription_amount: price.amount,
        subscription_interval: price.interval || "month",
      };
    }
  }

  <template>
    <div class="bookclub-publication-pricing">
      <div class="bookclub-settings-section">
        <h3 class="bookclub-settings-section__title">
          {{icon "credit-card"}}
          {{I18n.t "bookclub.admin.pricing.title"}}
        </h3>
        <p class="bookclub-settings-section__description">
          {{I18n.t "bookclub.admin.pricing.description"}}
        </p>

        {{#if this.loading}}
          <div class="bookclub-settings-loading">
            {{icon "spinner" class="spinner"}}
            <span>Loading...</span>
          </div>
        {{else}}
          {{#if this.error}}
            <div class="bookclub-settings-error">
              {{icon "triangle-exclamation"}}
              {{this.error}}
            </div>
          {{/if}}

          {{#if this.success}}
            <div class="bookclub-settings-success">
              {{icon "check"}}
              {{this.success}}
            </div>
          {{/if}}

          <div class="bookclub-form">
            <div class="bookclub-form-group">
              <label class="bookclub-checkbox">
                <input
                  type="checkbox"
                  checked={{this.pricingConfig.enabled}}
                  {{on "change" this.updateEnabled}}
                />
                {{I18n.t "bookclub.admin.pricing.enabled"}}
              </label>
              <p class="bookclub-form-hint">
                {{I18n.t "bookclub.admin.pricing.enabled_help"}}
              </p>
            </div>

            {{#if this.pricingConfig.enabled}}
              <div class="bookclub-form-group">
                <label for="preview-chapters">
                  {{I18n.t "bookclub.admin.pricing.preview_chapters"}}
                </label>
                <input
                  type="number"
                  id="preview-chapters"
                  min="0"
                  max="20"
                  value={{this.pricingConfig.preview_chapters}}
                  {{on "input" this.updatePreviewChapters}}
                  class="bookclub-input bookclub-input--small"
                />
                <p class="bookclub-form-hint">
                  {{I18n.t "bookclub.admin.pricing.preview_chapters_help"}}
                </p>
              </div>

              <div class="bookclub-form-group">
                <label for="access-group">
                  {{I18n.t "bookclub.admin.pricing.access_group"}}
                </label>
                <ComboBox
                  @value={{this.pricingConfig.access_group}}
                  @content={{this.groupOptions}}
                  @onChange={{this.updateAccessGroup}}
                  @options={{hash allowAny=true}}
                />
                <p class="bookclub-form-hint">
                  {{I18n.t "bookclub.admin.pricing.access_group_help"}}
                </p>
              </div>

              {{#if this.stripeConfigured}}
                <div class="bookclub-pricing-stripe-section">
                  <h4>Stripe integration</h4>

                  {{#if this.hasStripeProduct}}
                    <div class="bookclub-stripe-product-info">
                      <p>Product ID: <code>{{this.stripeProductId}}</code></p>
                      <DButton
                        @action={{this.syncStripe}}
                        @translatedLabel="Sync prices from Stripe"
                        @icon="arrows-rotate"
                        @disabled={{this.syncing}}
                        @isLoading={{this.syncing}}
                        class="btn-default"
                      />
                    </div>
                  {{else}}
                    <div class="bookclub-stripe-no-product">
                      <p>No Stripe product linked to this publication yet.</p>
                      <DButton
                        @action={{this.createStripeProduct}}
                        @translatedLabel="Create Stripe product"
                        @icon="plus"
                        @disabled={{this.creatingProduct}}
                        @isLoading={{this.creatingProduct}}
                        class="btn-primary"
                      />
                      <p class="bookclub-form-hint">
                        Creates a Stripe product with default one-time ($24.99) and monthly ($4.99) prices.
                      </p>
                    </div>
                  {{/if}}

                  {{#if this.stripePrices.length}}
                    <div class="bookclub-pricing-stripe-prices">
                      <h5>Available Stripe prices</h5>
                      <ul class="bookclub-pricing-price-list">
                        {{#each this.stripePrices as |price|}}
                          <li class="bookclub-pricing-price-item">
                            <div class="bookclub-pricing-price-info">
                              <strong>{{price.nickname}}</strong>
                              <span class="bookclub-pricing-price-amount">
                                {{price.amount}} {{price.currency}}
                                {{#if price.interval}}
                                  ({{price.interval}})
                                {{/if}}
                              </span>
                            </div>
                            <button
                              type="button"
                              class="btn-small"
                              {{on "click" (fn this.selectStripePrice (if price.interval "subscription" "one_time") price.id)}}
                            >
                              Use this
                            </button>
                          </li>
                        {{/each}}
                      </ul>
                    </div>
                  {{/if}}
                </div>

                <fieldset class="bookclub-pricing-option">
                  <legend>{{I18n.t "bookclub.admin.pricing.one_time_title"}}</legend>
                  <div class="bookclub-form-group">
                    <label for="one-time-price">
                      {{I18n.t "bookclub.admin.pricing.one_time_price"}}
                    </label>
                    <TextField
                      @value={{this.pricingConfig.one_time_price_id}}
                      @onChange={{fn this.updateField "one_time_price_id"}}
                      @placeholderKey="bookclub.admin.pricing.price_id_placeholder"
                    />
                  </div>
                  <div class="bookclub-form-group">
                    <label for="one-time-amount">
                      {{I18n.t "bookclub.admin.pricing.one_time_amount"}}
                    </label>
                    <input
                      type="number"
                      id="one-time-amount"
                      value={{this.pricingConfig.one_time_amount}}
                      {{on "input" (fn this.updateField "one_time_amount")}}
                      placeholder="2599"
                      class="bookclub-input bookclub-input--small"
                    />
                    <p class="bookclub-form-hint">Amount in cents (e.g., 2599 = $25.99)</p>
                  </div>
                </fieldset>

                <fieldset class="bookclub-pricing-option">
                  <legend>{{I18n.t "bookclub.admin.pricing.subscription_title"}}</legend>
                  <div class="bookclub-form-group">
                    <label for="subscription-price">
                      {{I18n.t "bookclub.admin.pricing.subscription_price"}}
                    </label>
                    <TextField
                      @value={{this.pricingConfig.subscription_price_id}}
                      @onChange={{fn this.updateField "subscription_price_id"}}
                      @placeholderKey="bookclub.admin.pricing.price_id_placeholder"
                    />
                  </div>
                  <div class="bookclub-form-group">
                    <label for="subscription-amount">
                      {{I18n.t "bookclub.admin.pricing.subscription_amount"}}
                    </label>
                    <input
                      type="number"
                      id="subscription-amount"
                      value={{this.pricingConfig.subscription_amount}}
                      {{on "input" (fn this.updateField "subscription_amount")}}
                      placeholder="495"
                      class="bookclub-input bookclub-input--small"
                    />
                    <p class="bookclub-form-hint">Amount in cents (e.g., 495 = $4.95)</p>
                  </div>
                  <div class="bookclub-form-group">
                    <label for="subscription-interval">
                      {{I18n.t "bookclub.admin.pricing.subscription_interval"}}
                    </label>
                    <ComboBox
                      @value={{this.pricingConfig.subscription_interval}}
                      @content={{this.intervalOptions}}
                      @onChange={{this.updateInterval}}
                    />
                  </div>
                </fieldset>
              {{else}}
                <div class="bookclub-settings-warning">
                  {{icon "triangle-exclamation"}}
                  {{I18n.t "bookclub.admin.pricing.stripe_not_configured"}}
                </div>
              {{/if}}

              <div class="bookclub-form-actions">
                <DButton
                  @action={{this.savePricingConfig}}
                  @label="bookclub.author.save_settings"
                  @icon={{if this.saving "spinner" "check"}}
                  @disabled={{this.saving}}
                  class="btn-primary"
                />
              </div>
            {{/if}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
