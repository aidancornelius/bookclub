import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";

/**
 * Reading mode header component
 * Shows publication/chapter title and control buttons
 * @component BookclubReadingHeader
 */
export default class BookclubReadingHeader extends Component {
  @service bookclubReading;
  @service router;

  @tracked isVisible = false;

  get publicationName() {
    return this.bookclubReading.currentPublication?.name || "";
  }

  get contentTitle() {
    return this.bookclubReading.currentContent?.title || "";
  }

  get publicationSlug() {
    return this.bookclubReading.currentPublication?.slug || "";
  }

  @action
  toggleToc() {
    this.bookclubReading.toggleToc();
  }

  @action
  toggleSettings() {
    this.bookclubReading.toggleSettings();
  }

  @action
  goToPublication() {
    if (this.publicationSlug) {
      this.router.transitionTo("bookclub-publication", this.publicationSlug);
    }
  }

  <template>
    <header
      class="bookclub-reading-header
        {{if this.isVisible 'bookclub-reading-header--visible'}}"
    >
      <div class="bookclub-reading-header__inner">
        <div class="bookclub-reading-header__title">
          <a
            href="/book/{{this.publicationSlug}}"
            {{on "click" this.goToPublication}}
          >
            {{this.publicationName}}
          </a>
          {{#if this.contentTitle}}
            <span class="bookclub-reading-header__separator"> / </span>
            {{this.contentTitle}}
          {{/if}}
        </div>
        <div class="bookclub-reading-header__controls">
          <button
            type="button"
            class="bookclub-reading-header__btn"
            title="Table of contents (t)"
            {{on "click" this.toggleToc}}
          >
            {{icon "list-ul"}}
          </button>
          <button
            type="button"
            class="bookclub-reading-header__btn"
            title="Settings (s)"
            {{on "click" this.toggleSettings}}
          >
            {{icon "text-height"}}
          </button>
        </div>
      </div>
    </header>
  </template>
}
