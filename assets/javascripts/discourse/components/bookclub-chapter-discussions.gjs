import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";

/**
 * Component to display discussion topics for a chapter
 * @component BookclubChapterDiscussions
 */
export default class BookclubChapterDiscussions extends Component {
  formatRelativeTime = (dateString) => {
    if (!dateString) {
      return "";
    }
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) {
      return "just now";
    }
    if (diffMins < 60) {
      return `${diffMins}m ago`;
    }
    if (diffHours < 24) {
      return `${diffHours}h ago`;
    }
    if (diffDays < 30) {
      return `${diffDays}d ago`;
    }
    return date.toLocaleDateString();
  };

  getTopicUrl = (topic) => {
    return `/t/${topic.slug}/${topic.id}`;
  };

  get hasDiscussions() {
    return this.args.discussions?.topics?.length > 0;
  }

  get discussionTopics() {
    return this.args.discussions?.topics || [];
  }

  get topicCount() {
    return this.args.discussions?.topic_count || 0;
  }

  get chapterId() {
    return this.args.discussions?.chapter_id;
  }

  get categoryUrl() {
    return `/c/${this.chapterId}`;
  }

  <template>
    <section class="bookclub-chapter-discussions">
      <header class="discussions-header">
        <h2>
          {{icon "comments"}}
          Discussions
          {{#if this.topicCount}}
            <span class="discussion-count">({{this.topicCount}})</span>
          {{/if}}
        </h2>
        {{#if this.chapterId}}
          <a href={{this.categoryUrl}} class="view-all-link">
            View all
            {{icon "arrow-right"}}
          </a>
        {{/if}}
      </header>

      {{#if this.hasDiscussions}}
        <ul class="discussions-list">
          {{#each this.discussionTopics as |topic|}}
            <li class="discussion-item">
              <div class="discussion-avatar">
                <img
                  src={{topic.user.avatar_url}}
                  alt={{topic.user.username}}
                  class="avatar"
                />
              </div>
              <div class="discussion-content">
                <a href={{this.getTopicUrl topic}} class="discussion-title">
                  {{topic.title}}
                </a>
                <div class="discussion-meta">
                  <span class="discussion-author">{{topic.user.name}}</span>
                  <span class="discussion-stats">
                    {{topic.posts_count}}
                    {{if (eq topic.posts_count 1) "reply" "replies"}}
                  </span>
                  <span class="discussion-time">
                    {{this.formatRelativeTime topic.last_posted_at}}
                  </span>
                </div>
              </div>
            </li>
          {{/each}}
        </ul>
      {{else}}
        <div class="discussions-empty">
          <p>No discussions yet. Be the first to start a conversation!</p>
          {{#if this.chapterId}}
            <a href={{this.categoryUrl}} class="btn btn-primary">
              {{icon "plus"}}
              Start a discussion
            </a>
          {{/if}}
        </div>
      {{/if}}
    </section>
  </template>
}
