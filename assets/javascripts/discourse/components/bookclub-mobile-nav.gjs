import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";

/**
 * Mobile bottom navigation bar component
 * Fixed bottom bar with touch-friendly navigation controls
 * Only visible on mobile devices
 * Hides when scrolling down, shows when scrolling up
 * @component BookclubMobileNav
 * @param {Object} navigation - Navigation data with previous and next
 */
export default class BookclubMobileNav extends Component {
  @service bookclubReading;
  @service capabilities;

  @tracked isHidden = false;

  lastScrollY = 0;
  scrollThreshold = 50;
  scrollHandler = null;

  get isVisible() {
    return this.capabilities.touch;
  }

  get isTocActive() {
    return this.bookclubReading.isTocOpen;
  }

  get isSettingsActive() {
    return this.bookclubReading.isSettingsOpen;
  }

  get hasPrevious() {
    return this.args.navigation?.previous != null;
  }

  get hasNext() {
    return this.args.navigation?.next != null;
  }

  @action
  setupScrollBehaviour() {
    this.scrollHandler = () => {
      const currentScrollY = window.scrollY;

      if (Math.abs(currentScrollY - this.lastScrollY) < this.scrollThreshold) {
        return;
      }

      if (currentScrollY > this.lastScrollY && currentScrollY > 100) {
        this.isHidden = true;
      } else {
        this.isHidden = false;
      }

      this.lastScrollY = currentScrollY;
    };

    window.addEventListener("scroll", this.scrollHandler, { passive: true });
  }

  @action
  teardownScrollBehaviour() {
    if (this.scrollHandler) {
      window.removeEventListener("scroll", this.scrollHandler);
      this.scrollHandler = null;
    }
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

  @action
  handleDiscussClick(event) {
    event.preventDefault();
    const discussionsEl = document.querySelector(
      ".bookclub-chapter-discussions"
    );
    if (discussionsEl) {
      discussionsEl.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  <template>
    {{#if this.isVisible}}
      <nav
        class="bookclub-mobile-nav
          {{if this.isHidden 'bookclub-mobile-nav--hidden'}}"
        {{didInsert this.setupScrollBehaviour}}
        {{willDestroy this.teardownScrollBehaviour}}
      >
        <button
          type="button"
          class="bookclub-mobile-nav__btn
            {{if this.isTocActive 'bookclub-mobile-nav__btn--active'}}"
          {{on "click" this.handleTocClick}}
          aria-label="Table of contents"
        >
          {{icon "list-ul"}}
          <span>TOC</span>
        </button>

        <button
          type="button"
          class="bookclub-mobile-nav__btn"
          {{on "click" this.handlePreviousClick}}
          disabled={{unless this.hasPrevious "disabled"}}
          aria-label="Previous chapter"
        >
          {{icon "chevron-left"}}
          <span>Prev</span>
        </button>

        <button
          type="button"
          class="bookclub-mobile-nav__btn"
          {{on "click" this.handleNextClick}}
          disabled={{unless this.hasNext "disabled"}}
          aria-label="Next chapter"
        >
          {{icon "chevron-right"}}
          <span>Next</span>
        </button>

        <button
          type="button"
          class="bookclub-mobile-nav__btn"
          {{on "click" this.handleDiscussClick}}
          aria-label="Jump to discussions"
        >
          {{icon "comments"}}
          <span>Discuss</span>
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
      </nav>
    {{/if}}
  </template>
}
