import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import icon from "discourse/helpers/d-icon";

/**
 * Publication statistics component showing engagement metrics
 * @component BookclubPublicationStats
 * @param {string} this.args.publicationSlug - Publication slug
 * @param {Object} this.args.analytics - Pre-loaded analytics data (optional)
 */
export default class BookclubPublicationStats extends Component {
  @service bookclubAuthor;
  @service router;

  @tracked analytics = this.args.analytics || null;
  @tracked loading = !this.args.analytics;
  @tracked error = null;
  @tracked activityTab = "recent";

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
    } catch (error) {
      console.error("Failed to load analytics:", error);
      this.error = "Failed to load analytics";
    } finally {
      this.loading = false;
    }
  }

  /**
   * Show recent activity tab
   */
  @action
  showRecent() {
    this.activityTab = "recent";
  }

  /**
   * Show unanswered questions tab
   */
  @action
  showUnanswered() {
    this.activityTab = "unanswered";
  }

  /**
   * Navigate to topic
   * @param {number} topicId - Topic ID
   */
  @action
  viewTopic(topicId) {
    window.location.href = `/t/${topicId}`;
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
   * Check if there's any engagement data
   * @returns {boolean} True if there's engagement
   */
  get hasEngagement() {
    if (!this.analytics) return false;
    return (
      this.analytics.views?.total > 0 ||
      this.analytics.engagement?.total_posts > 0 ||
      this.analytics.reader_progress?.total_readers > 0
    );
  }

  /**
   * Get unanswered count
   * @returns {number} Unanswered questions count
   */
  get unansweredCount() {
    return this.analytics?.engagement?.unanswered_questions_count || 0;
  }

  /**
   * Check if showing recent tab
   * @returns {boolean} True if recent tab is active
   */
  get isRecentTab() {
    return this.activityTab === "recent";
  }

  /**
   * Check if showing unanswered tab
   * @returns {boolean} True if unanswered tab is active
   */
  get isUnansweredTab() {
    return this.activityTab === "unanswered";
  }

  <template>
    <div class="bookclub-stats">
      {{#if this.loading}}
        <div class="bookclub-stats__loading">
          {{icon "spinner" class="spinner"}}
          <span>Loading analytics...</span>
        </div>
      {{else if this.error}}
        <div class="bookclub-stats__error">
          {{icon "triangle-exclamation"}}
          {{this.error}}
        </div>
      {{else if this.analytics}}
        {{#if this.hasEngagement}}
          <div class="bookclub-stats__overview">
            <div class="bookclub-stats__metric">
              <span class="bookclub-stats__metric-value">
                {{this.formatNumber this.analytics.views.total}}
              </span>
              <span class="bookclub-stats__metric-label">views</span>
            </div>

            <div class="bookclub-stats__metric">
              <span class="bookclub-stats__metric-value">
                {{this.formatNumber this.analytics.engagement.total_posts}}
              </span>
              <span class="bookclub-stats__metric-label">comments</span>
            </div>

            <div class="bookclub-stats__metric">
              <span class="bookclub-stats__metric-value">
                {{this.formatNumber this.analytics.engagement.unique_participants}}
              </span>
              <span class="bookclub-stats__metric-label">participants</span>
            </div>

            <div class="bookclub-stats__metric">
              <span class="bookclub-stats__metric-value">
                {{this.formatNumber this.analytics.reader_progress.total_readers}}
              </span>
              <span class="bookclub-stats__metric-label">readers</span>
            </div>
          </div>

          <div class="bookclub-stats__section">
            <div class="bookclub-stats__section-header">
              <h3 class="bookclub-stats__section-title">Activity</h3>
              <div class="bookclub-stats__tabs">
                <button
                  type="button"
                  class="bookclub-stats__tab {{if this.isRecentTab 'bookclub-stats__tab--active'}}"
                  {{on "click" this.showRecent}}
                >
                  Recent
                </button>
                <button
                  type="button"
                  class="bookclub-stats__tab {{if this.isUnansweredTab 'bookclub-stats__tab--active'}}"
                  {{on "click" this.showUnanswered}}
                >
                  Needs reply
                  {{#if this.unansweredCount}}
                    <span class="bookclub-stats__tab-badge">{{this.unansweredCount}}</span>
                  {{/if}}
                </button>
              </div>
            </div>

            {{#if this.isRecentTab}}
              {{#if this.analytics.engagement.recent_activity.length}}
                <div class="bookclub-stats__activity-list">
                  {{#each this.analytics.engagement.recent_activity as |activity|}}
                    <div
                      class="bookclub-stats__activity-item"
                      role="button"
                      {{on "click" (fn this.viewTopic activity.topic_id)}}
                    >
                      <img
                        src={{activity.user.avatar_url}}
                        alt={{activity.user.username}}
                        class="bookclub-stats__activity-avatar"
                      />
                      <div class="bookclub-stats__activity-content">
                        <div class="bookclub-stats__activity-header">
                          <span class="bookclub-stats__activity-user">{{activity.user.username}}</span>
                          <span class="bookclub-stats__activity-time">{{ageWithTooltip activity.created_at}}</span>
                        </div>
                        <div class="bookclub-stats__activity-excerpt">
                          {{activity.excerpt}}
                        </div>
                      </div>
                    </div>
                  {{/each}}
                </div>
              {{else}}
                <div class="bookclub-stats__empty">
                  <p>No recent activity yet.</p>
                </div>
              {{/if}}
            {{else}}
              {{#if this.analytics.engagement.unanswered_questions.length}}
                <div class="bookclub-stats__activity-list">
                  {{#each this.analytics.engagement.unanswered_questions as |question|}}
                    <div
                      class="bookclub-stats__activity-item bookclub-stats__activity-item--unanswered"
                      role="button"
                      {{on "click" (fn this.viewTopic question.id)}}
                    >
                      <div class="bookclub-stats__activity-icon">
                        {{icon "circle-question"}}
                      </div>
                      <div class="bookclub-stats__activity-content">
                        <div class="bookclub-stats__activity-title">
                          {{question.title}}
                        </div>
                        <div class="bookclub-stats__activity-meta">
                          {{question.posts_count}} replies
                          · {{ageWithTooltip question.last_posted_at}}
                        </div>
                      </div>
                    </div>
                  {{/each}}
                </div>
              {{else}}
                <div class="bookclub-stats__empty bookclub-stats__empty--success">
                  {{icon "circle-check"}}
                  <p>All questions answered!</p>
                </div>
              {{/if}}
            {{/if}}
          </div>

          {{#if this.analytics.reader_progress.by_chapter.length}}
            <div class="bookclub-stats__section">
              <h3 class="bookclub-stats__section-title">Reader progress</h3>
              <div class="bookclub-stats__progress-summary">
                <span>{{this.analytics.reader_progress.completed_readers}} completed</span>
                <span class="bookclub-stats__progress-avg">
                  {{this.analytics.reader_progress.average_progress}}% average
                </span>
              </div>
              <div class="bookclub-stats__progress-list">
                {{#each this.analytics.reader_progress.by_chapter as |chapter|}}
                  <div class="bookclub-stats__progress-item">
                    <div class="bookclub-stats__progress-header">
                      <span class="bookclub-stats__progress-title">
                        Ch. {{chapter.number}}
                      </span>
                      <span class="bookclub-stats__progress-rate">
                        {{chapter.completion_rate}}%
                      </span>
                    </div>
                    <div class="bookclub-stats__progress-bar">
                      <div
                        class="bookclub-stats__progress-fill"
                        style="width: {{chapter.completion_rate}}%"
                      ></div>
                    </div>
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}
        {{else}}
          <div class="bookclub-stats__empty-state">
            {{icon "chart-bar"}}
            <h3>No activity yet</h3>
            <p>Statistics will appear as readers engage with your content.</p>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
