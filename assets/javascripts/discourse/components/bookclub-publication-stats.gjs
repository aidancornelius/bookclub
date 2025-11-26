import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { formatDate } from "discourse/lib/formatter";
import BookclubActivityMetrics from "./bookclub-activity-metrics";
import BookclubReaderProgress from "./bookclub-reader-progress";

/**
 * Publication statistics component showing engagement metrics
 * @component BookclubPublicationStats
 * @param {string} this.args.publicationSlug - Publication slug
 * @param {Object} this.args.analytics - Pre-loaded analytics data (optional)
 */
export default class BookclubPublicationStats extends Component {
  @service bookclubAuthor;

  @tracked analytics = this.args.analytics || null;
  @tracked loading = !this.args.analytics;
  @tracked error = null;

  constructor() {
    super(...arguments);
    if (!this.args.analytics) {
      this.loadAnalytics();
    }
  }

  /**
   * Load analytics data
   */
  async loadAnalytics() {
    this.loading = true;
    this.error = null;

    try {
      this.analytics = await this.bookclubAuthor.fetchAnalytics(
        this.args.publicationSlug
      );
    } catch {
      this.error = "Failed to load analytics";
    } finally {
      this.loading = false;
    }
  }

  /**
   * Reload analytics data
   */
  @action
  async reload() {
    await this.loadAnalytics();
  }

  /**
   * Format a date for display
   * @param {string} date - ISO date string
   * @returns {string} Formatted date
   */
  formatDate(date) {
    return formatDate(date, { format: "tiny" });
  }

  /**
   * Format number with commas
   * @param {number} num - Number to format
   * @returns {string} Formatted number
   */
  formatNumber(num) {
    return num?.toLocaleString() || "0";
  }

  /**
   * Get avatar URL for a user
   * @param {Object} user - User object with avatar_url
   * @returns {string} Avatar URL
   */
  getAvatarUrl(user) {
    return user.avatar_url;
  }

  <template>
    <div class="bookclub-publication-stats">
      {{#if this.loading}}
        <div class="bookclub-publication-stats__loading">
          {{icon "spinner" class="spinner"}}
          Loading analytics...
        </div>
      {{else if this.error}}
        <div class="bookclub-publication-stats__error">
          {{icon "triangle-exclamation"}}
          {{this.error}}
        </div>
      {{else if this.analytics}}
        <div class="bookclub-publication-stats__sections">
          {{! Overview Stats }}
          <div class="bookclub-stats-section">
            <h3 class="bookclub-stats-section__title">
              {{icon "chart-line"}}
              Overview
            </h3>

            <div class="bookclub-stats-grid">
              <div class="bookclub-stat-card">
                <div class="bookclub-stat-card__icon">
                  {{icon "eye"}}
                </div>
                <div class="bookclub-stat-card__content">
                  <div class="bookclub-stat-card__value">
                    {{this.formatNumber this.analytics.views.total}}
                  </div>
                  <div class="bookclub-stat-card__label">
                    Total views
                  </div>
                </div>
              </div>

              <div class="bookclub-stat-card">
                <div class="bookclub-stat-card__icon">
                  {{icon "comment"}}
                </div>
                <div class="bookclub-stat-card__content">
                  <div class="bookclub-stat-card__value">
                    {{this.formatNumber this.analytics.engagement.total_posts}}
                  </div>
                  <div class="bookclub-stat-card__label">
                    Comments
                  </div>
                </div>
              </div>

              <div class="bookclub-stat-card">
                <div class="bookclub-stat-card__icon">
                  {{icon "users"}}
                </div>
                <div class="bookclub-stat-card__content">
                  <div class="bookclub-stat-card__value">
                    {{this.formatNumber
                      this.analytics.engagement.unique_participants
                    }}
                  </div>
                  <div class="bookclub-stat-card__label">
                    Unique participants
                  </div>
                </div>
              </div>

              <div class="bookclub-stat-card">
                <div class="bookclub-stat-card__icon">
                  {{icon "book-open-reader"}}
                </div>
                <div class="bookclub-stat-card__content">
                  <div class="bookclub-stat-card__value">
                    {{this.formatNumber
                      this.analytics.reader_progress.total_readers
                    }}
                  </div>
                  <div class="bookclub-stat-card__label">
                    Active readers
                  </div>
                </div>
              </div>
            </div>
          </div>

          {{! Activity Metrics }}
          <div class="bookclub-stats-section">
            <BookclubActivityMetrics @analytics={{this.analytics}} />
          </div>

          {{! Reader Progress }}
          <div class="bookclub-stats-section">
            <BookclubReaderProgress @analytics={{this.analytics}} />
          </div>

          {{! Views by Chapter }}
          {{#if this.analytics.views.by_chapter.length}}
            <div class="bookclub-stats-section">
              <h3 class="bookclub-stats-section__title">
                {{icon "chart-bar"}}
                Views by chapter
              </h3>

              <div class="bookclub-content-views">
                {{#each this.analytics.views.by_chapter as |chapter|}}
                  <div class="bookclub-content-views__item">
                    <div class="bookclub-content-views__title">
                      {{chapter.title}}
                    </div>
                    <div class="bookclub-content-views__bar">
                      <div
                        class="bookclub-content-views__bar-fill"
                        style="width: 100%"
                      ></div>
                    </div>
                    <div class="bookclub-content-views__value">
                      {{this.formatNumber chapter.views}}
                      views
                    </div>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
