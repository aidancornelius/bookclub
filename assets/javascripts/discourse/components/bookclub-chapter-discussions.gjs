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
    <section class="bookclub-chapter-discussions" id="chapter-discussions">
      <header class="bookclub-chapter-discussions__header">
        <div class="bookclub-chapter-discussions__title-group">
          {{icon "comments"}}
          <h2 class="bookclub-chapter-discussions__title">
            Chapter discussion
          </h2>
          {{#if this.topicCount}}
            <span
              class="bookclub-chapter-discussions__count"
            >({{this.topicCount}})</span>
          {{/if}}
        </div>
        {{#if this.chapterId}}
          <a
            href={{this.categoryUrl}}
            class="bookclub-chapter-discussions__view-all"
          >
            View all
            {{icon "arrow-right"}}
          </a>
        {{/if}}
      </header>

      {{#if this.hasDiscussions}}
        <ul class="bookclub-chapter-discussions__list">
          {{#each this.discussionTopics as |topic|}}
            <li class="bookclub-chapter-discussions__item">
              <div class="bookclub-chapter-discussions__avatar">
                <img
                  src={{topic.user.avatar_url}}
                  alt={{topic.user.username}}
                  class="avatar"
                />
              </div>
              <div class="bookclub-chapter-discussions__content">
                <a
                  href={{this.getTopicUrl topic}}
                  class="bookclub-chapter-discussions__topic-title"
                >
                  {{topic.title}}
                </a>
                <div class="bookclub-chapter-discussions__meta">
                  <span
                    class="bookclub-chapter-discussions__author"
                  >{{topic.user.name}}</span>
                  <span class="bookclub-chapter-discussions__separator">•</span>
                  <span class="bookclub-chapter-discussions__stats">
                    {{topic.posts_count}}
                    {{if (eq topic.posts_count 1) "reply" "replies"}}
                  </span>
                  <span class="bookclub-chapter-discussions__separator">•</span>
                  <span class="bookclub-chapter-discussions__time">
                    {{this.formatRelativeTime topic.last_posted_at}}
                  </span>
                </div>
              </div>
            </li>
          {{/each}}
        </ul>
      {{else}}
        <div class="bookclub-chapter-discussions__empty">
          <div class="bookclub-chapter-discussions__empty-icon">
            {{icon "far-comments"}}
          </div>
          <p class="bookclub-chapter-discussions__empty-text">
            No discussions yet. Be the first to start a conversation about this
            chapter!
          </p>
          {{#if this.chapterId}}
            <a
              href={{this.categoryUrl}}
              class="bookclub-chapter-discussions__start-btn"
            >
              {{icon "plus"}}
              Start a discussion
            </a>
          {{/if}}
        </div>
      {{/if}}
    </section>
  </template>
}
