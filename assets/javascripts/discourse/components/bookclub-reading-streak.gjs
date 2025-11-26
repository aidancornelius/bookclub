import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { gt } from "discourse/truth-helpers";

/**
 * Reading streak display component
 * Shows current reading streak and longest streak
 * @component BookclubReadingStreak
 */
export default class BookclubReadingStreak extends Component {
  @service bookclubReading;

  get streak() {
    return this.bookclubReading.readingStreak;
  }

  get hasStreak() {
    return this.streak && this.streak.current_streak > 0;
  }

  get currentStreak() {
    return this.streak?.current_streak || 0;
  }

  get longestStreak() {
    return this.streak?.longest_streak || 0;
  }

  get streakLabel() {
    const days = this.currentStreak;
    return days === 1 ? "day" : "days";
  }

  <template>
    {{#if this.hasStreak}}
      <div class="bookclub-reading-streak">
        <div class="bookclub-reading-streak__current">
          <span class="bookclub-reading-streak__icon">
            {{icon "fire"}}
          </span>
          <span class="bookclub-reading-streak__count">
            {{this.currentStreak}}
          </span>
          <span class="bookclub-reading-streak__label">
            {{this.streakLabel}} streak
          </span>
        </div>
        {{#if (gt this.longestStreak this.currentStreak)}}
          <div class="bookclub-reading-streak__longest">
            Best: {{this.longestStreak}} days
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
