import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { eq, gt } from "discourse/truth-helpers";
import BookclubReadingStreak from "./bookclub-reading-streak";

/**
 * Table of contents sidebar component
 * Slides in from the left with chapter list and progress indicators
 * @component BookclubTocSidebar
 * @param {Array} toc - Table of contents items
 * @param {number} currentNumber - Current chapter number
 */
export default class BookclubTocSidebar extends Component {
  @service bookclubReading;
  @service router;

  get isOpen() {
    return this.bookclubReading.isTocOpen;
  }

  get publicationSlug() {
    return this.bookclubReading.currentPublication?.slug || "";
  }

  get enrichedToc() {
    return (this.args.toc || []).map((item) => {
      const status = this.bookclubReading.getContentStatus(
        item.id,
        item.number
      );
      return {
        ...item,
        status,
      };
    });
  }

  get completionPercentage() {
    const total = this.args.toc?.length || 0;
    if (total === 0) {
      return 0;
    }
    const completed = this.enrichedToc.filter(
      (item) => item.status === "completed"
    ).length;
    return Math.round((completed / total) * 100);
  }

  get progressBarStyle() {
    return htmlSafe(`width: ${this.completionPercentage}%`);
  }

  @action
  close() {
    this.bookclubReading.toggleToc();
  }

  @action
  goToChapter(item) {
    if (item.has_access && this.publicationSlug) {
      this.router.transitionTo(
        "bookclub-content",
        this.publicationSlug,
        item.number
      );
      this.close();
    }
  }

  @action
  handleOverlayClick() {
    this.close();
  }

  /**
   * Get icon for progress status
   * @param {string} status - Status: 'completed', 'in-progress', or 'unread'
   * @returns {string} Icon name
   */
  getStatusIcon(status) {
    switch (status) {
      case "completed":
        return "check-circle";
      case "in-progress":
        return "circle-half-stroke";
      default:
        return null; // No icon for unread
    }
  }

  /**
   * Get CSS class for status
   * @param {string} status - Status: 'completed', 'in-progress', or 'unread'
   * @returns {string} CSS class name
   */
  getStatusClass(status) {
    return `bookclub-toc__link--${status}`;
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class="bookclub-toc-overlay
        {{if this.isOpen 'bookclub-toc-overlay--visible'}}"
      role="button"
      {{on "click" this.handleOverlayClick}}
    ></div>
    <aside
      class="bookclub-toc-sidebar
        {{if this.isOpen 'bookclub-toc-sidebar--open'}}"
    >
      <header class="bookclub-toc-sidebar__header">
        <h2 class="bookclub-toc-sidebar__title">Contents</h2>
        <button
          type="button"
          class="bookclub-toc-sidebar__close"
          {{on "click" this.close}}
        >
          {{icon "xmark"}}
        </button>
      </header>
      <BookclubReadingStreak />
      {{#if (gt this.completionPercentage 0)}}
        <div class="bookclub-toc-sidebar__progress">
          <div class="bookclub-toc-sidebar__progress-bar">
            <div
              class="bookclub-toc-sidebar__progress-fill"
              style={{this.progressBarStyle}}
            ></div>
          </div>
          <span class="bookclub-toc-sidebar__progress-text">
            {{this.completionPercentage}}% complete
          </span>
        </div>
      {{/if}}
      <div class="bookclub-toc-sidebar__content">
        <ol class="bookclub-toc__list">
          {{#each this.enrichedToc as |item|}}
            <li class="bookclub-toc__item">
              <a
                href="/book/{{this.publicationSlug}}/{{item.number}}"
                class="bookclub-toc__link
                  {{this.getStatusClass item.status}}
                  {{unless item.has_access 'bookclub-toc__link--locked'}}
                  {{if
                    (eq item.number @currentNumber)
                    'bookclub-toc__link--current'
                  }}"
                {{on "click" (fn this.goToChapter item)}}
              >
                {{#if (this.getStatusIcon item.status)}}
                  <span
                    class="bookclub-toc__status-icon bookclub-toc__status-icon--{{item.status}}"
                  >
                    {{icon (this.getStatusIcon item.status)}}
                  </span>
                {{/if}}
                <span class="bookclub-toc__number">{{item.number}}.</span>
                <span class="bookclub-toc__content-title">{{item.title}}</span>
                {{#unless item.has_access}}
                  <span class="bookclub-toc__lock-icon">{{icon "lock"}}</span>
                {{/unless}}
              </a>
            </li>
          {{/each}}
        </ol>
      </div>
    </aside>
  </template>
}
