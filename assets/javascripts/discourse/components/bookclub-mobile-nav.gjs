import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";

/**
 * Mobile bottom navigation bar component
 * Fixed bottom bar with touch-friendly navigation controls
 * Only visible on mobile devices
 * @component BookclubMobileNav
 * @param {boolean} hasPrevious - Whether there is a previous chapter
 * @param {boolean} hasNext - Whether there is a next chapter
 */
export default class BookclubMobileNav extends Component {
  @service bookclubReading;
  @service capabilities;

  get isVisible() {
    // Only show on mobile/tablet
    return this.capabilities.touch;
  }

  get isTocActive() {
    return this.bookclubReading.isTocOpen;
  }

  get isSettingsActive() {
    return this.bookclubReading.isSettingsOpen;
  }

  @action
  handleTocClick(event) {
    event.preventDefault();
    this.bookclubReading.toggleToc();
  }

  @action
  handleSettingsClick(event) {
    event.preventDefault();
    this.bookclubReading.toggleSettings();
  }

  @action
  handlePreviousClick(event) {
    event.preventDefault();
    this.bookclubReading.navigatePrevious();
  }

  @action
  handleNextClick(event) {
    event.preventDefault();
    this.bookclubReading.navigateNext();
  }

  <template>
    {{#if this.isVisible}}
      <nav class="bookclub-mobile-nav">
        <button
          type="button"
          class="bookclub-mobile-nav__btn
            {{if this.isTocActive 'bookclub-mobile-nav__btn--active'}}"
          {{on "click" this.handleTocClick}}
          aria-label="Table of contents"
        >
          {{icon "list-ul"}}
          <span>Contents</span>
        </button>

        <button
          type="button"
          class="bookclub-mobile-nav__btn
            {{if this.isSettingsActive 'bookclub-mobile-nav__btn--active'}}"
          {{on "click" this.handleSettingsClick}}
          aria-label="Reading settings"
        >
          {{icon "gear"}}
          <span>Settings</span>
        </button>

        <button
          type="button"
          class="bookclub-mobile-nav__btn"
          {{on "click" this.handlePreviousClick}}
          disabled={{unless @hasPrevious "disabled"}}
          aria-label="Previous chapter"
        >
          {{icon "chevron-left"}}
          <span>Previous</span>
        </button>

        <button
          type="button"
          class="bookclub-mobile-nav__btn"
          {{on "click" this.handleNextClick}}
          disabled={{unless @hasNext "disabled"}}
          aria-label="Next chapter"
        >
          {{icon "chevron-right"}}
          <span>Next</span>
        </button>
      </nav>
    {{/if}}
  </template>
}
