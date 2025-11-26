import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { formatDate } from "discourse/lib/formatter";

/**
 * Activity metrics component for author dashboard
 * Shows recent comments and unanswered questions
 * @component BookclubActivityMetrics
 * @param {Object} this.args.analytics - Analytics data from publication
 */
export default class BookclubActivityMetrics extends Component {
  @service router;

  @tracked showingRecent = true;

  /**
   * Toggle between recent activity and unanswered questions
   */
  @action
  toggleView() {
    this.showingRecent = !this.showingRecent;
  }

  /**
   * Navigate to topic
   * @param {number} topicId - Topic ID
   */
  @action
  viewTopic(topicId) {
    this.router.transitionTo("topic", { id: topicId });
  }

  /**
   * Get formatted date
   * @param {string} dateString - ISO date string
   * @returns {string} Formatted date
   */
  formatActivityDate(dateString) {
    return formatDate(new Date(dateString), { format: "tiny" });
  }

  <template>
    <div class="bookclub-activity-metrics">
      <div class="bookclub-activity-metrics__header">
        <h3 class="bookclub-activity-metrics__title">
          {{icon "comment"}}
          Activity
        </h3>
        <div class="bookclub-activity-metrics__tabs">
          <button
            type="button"
            class="bookclub-activity-metrics__tab
              {{if this.showingRecent 'active' ''}}"
            {{on "click" (fn this.toggleView)}}
          >
            Recent comments
          </button>
          <button
            type="button"
            class="bookclub-activity-metrics__tab
              {{unless this.showingRecent 'active' ''}}"
            {{on "click" (fn this.toggleView)}}
          >
            Unanswered questions
            {{#if @analytics.engagement.unanswered_questions_count}}
              <span class="bookclub-badge bookclub-badge--count">
                {{@analytics.engagement.unanswered_questions_count}}
              </span>
            {{/if}}
          </button>
        </div>
      </div>

      <div class="bookclub-activity-metrics__content">
        {{#if this.showingRecent}}
          {{#if @analytics.engagement.recent_activity.length}}
            <div class="bookclub-activity-list">
              {{#each @analytics.engagement.recent_activity as |activity|}}
                <div
                  class="bookclub-activity-item"
                  role="button"
                  {{on "click" (fn this.viewTopic activity.topic_id)}}
                >
                  <div class="bookclub-activity-item__avatar">
                    <img
                      src={{activity.user.avatar_url}}
                      alt={{activity.user.username}}
                      class="avatar"
                    />
                  </div>
                  <div class="bookclub-activity-item__content">
                    <div class="bookclub-activity-item__header">
                      <span class="bookclub-activity-item__username">
                        {{activity.user.username}}
                      </span>
                      <span class="bookclub-activity-item__topic">
                        in
                        {{activity.topic_title}}
                      </span>
                    </div>
                    {{#if activity.chapter}}
                      <div class="bookclub-activity-item__chapter">
                        Chapter
                        {{activity.chapter.number}}:
                        {{activity.chapter.title}}
                      </div>
                    {{/if}}
                    <div class="bookclub-activity-item__excerpt">
                      {{activity.excerpt}}
                    </div>
                    <div class="bookclub-activity-item__meta">
                      {{this.formatActivityDate activity.created_at}}
                    </div>
                  </div>
                </div>
              {{/each}}
            </div>
          {{else}}
            <div class="bookclub-activity-metrics__empty">
              {{icon "comment"}}
              <p>No recent activity yet.</p>
            </div>
          {{/if}}
        {{else}}
          {{#if @analytics.engagement.unanswered_questions.length}}
            <div class="bookclub-activity-list">
              {{#each @analytics.engagement.unanswered_questions as |question|}}
                <div
                  class="bookclub-activity-item bookclub-activity-item--unanswered"
                  role="button"
                  {{on "click" (fn this.viewTopic question.id)}}
                >
                  <div class="bookclub-activity-item__icon">
                    {{icon "circle-question"}}
                  </div>
                  <div class="bookclub-activity-item__content">
                    <div class="bookclub-activity-item__title">
                      {{question.title}}
                    </div>
                    {{#if question.chapter}}
                      <div class="bookclub-activity-item__chapter">
                        Chapter
                        {{question.chapter.number}}:
                        {{question.chapter.title}}
                      </div>
                    {{/if}}
                    <div class="bookclub-activity-item__meta">
                      {{question.posts_count}}
                      replies •
                      {{this.formatActivityDate question.last_posted_at}}
                    </div>
                  </div>
                </div>
              {{/each}}
            </div>
          {{else}}
            <div class="bookclub-activity-metrics__empty">
              {{icon "check-circle"}}
              <p>All questions answered! Great work.</p>
            </div>
          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
