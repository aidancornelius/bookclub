import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";

/**
 * Author dashboard component showing all publications the user can manage
 * @component BookclubAuthorDashboard
 */
export default class BookclubAuthorDashboard extends Component {
  @service bookclubAuthor;
  @service router;

  @tracked publications = this.args.publications || [];
  @tracked loading = false;
  @tracked error = null;

  /**
   * Navigate to publication detail page
   * @param {Object} publication - Publication object
   */
  @action
  viewPublication(publication) {
    this.router.transitionTo("bookclub-author-publication", publication.slug);
  }

  /**
   * Navigate to the publication's public page
   * @param {Object} publication - Publication object
   */
  @action
  viewPublicPage(publication) {
    window.location.href = `/book/${publication.slug}`;
  }

  /**
   * Get status badge class based on publication stats
   * @param {Object} publication - Publication object
   * @returns {string} CSS class name
   */
  getStatusClass(publication) {
    if (publication.published_count === 0) {
      return "status-draft";
    } else if (publication.draft_count > 0) {
      return "status-mixed";
    }
    return "status-published";
  }

  /**
   * Format word count for display
   * @param {number} count - Word count
   * @returns {string} Formatted count
   */
  formatWordCount(count) {
    if (count >= 1000000) {
      return `${(count / 1000000).toFixed(1)}M`;
    } else if (count >= 1000) {
      return `${(count / 1000).toFixed(1)}K`;
    }
    return count.toString();
  }

  <template>
    <div class="bookclub-author-dashboard">
      <div class="bookclub-author-dashboard__header">
        <h1 class="bookclub-author-dashboard__title">
          {{icon "book-open"}}
          Author dashboard
        </h1>
        <p class="bookclub-author-dashboard__description">
          Manage your publications, chapters, and reader engagement
        </p>
      </div>

      {{#if this.loading}}
        <div class="bookclub-author-dashboard__loading">
          {{icon "spinner" class="spinner"}}
          Loading publications...
        </div>
      {{else if this.error}}
        <div class="bookclub-author-dashboard__error">
          {{icon "triangle-exclamation"}}
          {{this.error}}
        </div>
      {{else if this.publications.length}}
        <div class="bookclub-author-dashboard__publications">
          {{#each this.publications as |publication|}}
            <div
              class="bookclub-publication-card
                {{this.getStatusClass publication}}"
            >
              {{#if publication.cover_url}}
                <div class="bookclub-publication-card__cover">
                  <img src={{publication.cover_url}} alt={{publication.name}} />
                </div>
              {{/if}}

              <div class="bookclub-publication-card__content">
                <div class="bookclub-publication-card__header">
                  <h3 class="bookclub-publication-card__title">
                    {{publication.name}}
                  </h3>
                  <span class="bookclub-publication-card__type">
                    {{publication.type}}
                  </span>
                </div>

                <div class="bookclub-publication-card__stats">
                  <div class="bookclub-stat">
                    <span class="bookclub-stat__label">
                      {{#if (eq publication.type "journal")}}
                        articles
                      {{else}}
                        chapters
                      {{/if}}
                    </span>
                    <span class="bookclub-stat__value">
                      {{publication.chapter_count}}
                    </span>
                  </div>

                  <div class="bookclub-stat">
                    <span class="bookclub-stat__label">published</span>
                    <span class="bookclub-stat__value">
                      {{publication.published_count}}
                    </span>
                  </div>

                  <div class="bookclub-stat">
                    <span class="bookclub-stat__label">drafts</span>
                    <span class="bookclub-stat__value">
                      {{publication.draft_count}}
                    </span>
                  </div>

                  <div class="bookclub-stat">
                    <span class="bookclub-stat__label">words</span>
                    <span class="bookclub-stat__value">
                      {{this.formatWordCount publication.total_word_count}}
                    </span>
                  </div>
                </div>

                <div class="bookclub-publication-card__badges">
                  {{#if publication.is_author}}
                    <span class="bookclub-badge bookclub-badge--author">
                      {{icon "pen"}}
                      Author
                    </span>
                  {{/if}}
                  {{#if publication.is_editor}}
                    <span class="bookclub-badge bookclub-badge--editor">
                      {{icon "user-pen"}}
                      Editor
                    </span>
                  {{/if}}
                </div>

                <div class="bookclub-publication-card__actions">
                  <DButton
                    @action={{fn this.viewPublication publication}}
                    @label="bookclub.author.manage"
                    @icon="gear"
                    class="btn-primary"
                  />
                  <DButton
                    @action={{fn this.viewPublicPage publication}}
                    @label="bookclub.author.view_public"
                    @icon="link"
                    class="btn-default"
                  />
                </div>
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="bookclub-author-dashboard__empty">
          {{icon "book"}}
          <h3>No publications yet</h3>
          <p>You don't have any publications to manage. Contact an administrator
            to get started.</p>
        </div>
      {{/if}}
    </div>
  </template>
}
