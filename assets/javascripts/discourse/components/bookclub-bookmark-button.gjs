import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Bookmark button for chapters
 * Saves/removes a reading position bookmark
 * @component BookclubBookmarkButton
 * @param {number} topicId - The content topic ID for the chapter
 */
export default class BookclubBookmarkButton extends Component {
  @service currentUser;

  @tracked isBookmarked = false;
  @tracked isLoading = false;

  constructor() {
    super(...arguments);
    this.checkBookmarkStatus();
  }

  async checkBookmarkStatus() {
    if (!this.currentUser) {
      return;
    }

    try {
      const response = await ajax("/bookclub/reading-bookmark.json");
      // Check if the current topic is bookmarked
      if (
        response.bookmark &&
        response.bookmark.bookmarkable_id === this.args.topicId
      ) {
        this.isBookmarked = true;
      }
    } catch (error) {
      // Silently fail - bookmark status is not critical
      // eslint-disable-next-line no-console
      console.log("Failed to check bookmark status:", error);
    }
  }

  @action
  async handleClick(event) {
    event.preventDefault();

    if (!this.currentUser) {
      return;
    }

    if (this.isLoading) {
      return;
    }

    this.isLoading = true;

    try {
      if (this.isBookmarked) {
        await ajax("/bookclub/reading-bookmark.json", {
          method: "DELETE",
        });
        this.isBookmarked = false;
      } else {
        await ajax("/bookclub/reading-bookmark.json", {
          method: "POST",
          data: { topic_id: this.args.topicId },
        });
        this.isBookmarked = true;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  get buttonClass() {
    let classes = "bookclub-bookmark-button";
    if (this.isBookmarked) {
      classes += " bookclub-bookmark-button--active";
    }
    if (this.isLoading) {
      classes += " bookclub-bookmark-button--loading";
    }
    return classes;
  }

  get buttonIcon() {
    return this.isBookmarked ? "bookmark" : "far-bookmark";
  }

  get buttonLabel() {
    return this.isBookmarked
      ? i18n("bookclub.bookmark.remove")
      : i18n("bookclub.bookmark.add");
  }

  <template>
    {{#if this.currentUser}}
      <button
        type="button"
        class={{this.buttonClass}}
        disabled={{this.isLoading}}
        {{on "click" this.handleClick}}
      >
        {{icon this.buttonIcon}}
        <span>{{this.buttonLabel}}</span>
      </button>
    {{/if}}
  </template>
}
