import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";

/**
 * Settings panel component
 * Controls font size and dark mode
 * @component BookclubSettingsPanel
 */
export default class BookclubSettingsPanel extends Component {
  @service bookclubReading;
  @service siteSettings;

  get isOpen() {
    return this.bookclubReading.isSettingsOpen;
  }

  get fontSize() {
    return this.bookclubReading.fontSize;
  }

  get isDarkMode() {
    return this.bookclubReading.isDarkMode;
  }

  get showDarkModeToggle() {
    return this.siteSettings.bookclub_enable_dark_mode;
  }

  get showFontSizeControls() {
    return this.siteSettings.bookclub_enable_font_size_controls;
  }

  @action
  setFontSize(size) {
    this.bookclubReading.fontSize = size;
  }

  @action
  toggleDarkMode() {
    this.bookclubReading.toggleDarkMode();
  }

  <template>
    <div
      class="bookclub-settings-panel
        {{if this.isOpen 'bookclub-settings-panel--open'}}"
    >
      {{#if this.showFontSizeControls}}
        <div class="bookclub-settings-panel__section">
          <div class="bookclub-settings-panel__label">Font size</div>
          <div class="bookclub-settings-panel__font-sizes">
            <button
              type="button"
              class="bookclub-settings-panel__font-btn bookclub-settings-panel__font-btn--small
                {{if
                  (eq this.fontSize 'small')
                  'bookclub-settings-panel__font-btn--active'
                }}"
              {{on "click" (fn this.setFontSize "small")}}
            >
              A
            </button>
            <button
              type="button"
              class="bookclub-settings-panel__font-btn bookclub-settings-panel__font-btn--medium
                {{if
                  (eq this.fontSize 'medium')
                  'bookclub-settings-panel__font-btn--active'
                }}"
              {{on "click" (fn this.setFontSize "medium")}}
            >
              A
            </button>
            <button
              type="button"
              class="bookclub-settings-panel__font-btn bookclub-settings-panel__font-btn--large
                {{if
                  (eq this.fontSize 'large')
                  'bookclub-settings-panel__font-btn--active'
                }}"
              {{on "click" (fn this.setFontSize "large")}}
            >
              A
            </button>
            <button
              type="button"
              class="bookclub-settings-panel__font-btn bookclub-settings-panel__font-btn--x-large
                {{if
                  (eq this.fontSize 'x-large')
                  'bookclub-settings-panel__font-btn--active'
                }}"
              {{on "click" (fn this.setFontSize "x-large")}}
            >
              A
            </button>
          </div>
        </div>
      {{/if}}

      {{#if this.showDarkModeToggle}}
        <div class="bookclub-settings-panel__section">
          <div class="bookclub-settings-panel__label">Theme</div>
          <div class="bookclub-settings-panel__theme-toggle">
            <button
              type="button"
              class="bookclub-settings-panel__theme-btn"
              {{on "click" this.toggleDarkMode}}
            >
              {{#if this.isDarkMode}}
                {{icon "sun"}}
                <span>Light mode</span>
              {{else}}
                {{icon "moon"}}
                <span>Dark mode</span>
              {{/if}}
            </button>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
