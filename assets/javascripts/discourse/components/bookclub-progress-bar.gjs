import Component from "@glimmer/component";
import { service } from "@ember/service";

/**
 * Reading progress bar component
 * Shows scroll progress at the top of the viewport
 * @component BookclubProgressBar
 */
export default class BookclubProgressBar extends Component {
  @service bookclubReading;

  get progressStyle() {
    return `width: ${this.bookclubReading.scrollProgress}%`;
  }

  <template>
    <div class="bookclub-progress-bar">
      <div
        class="bookclub-progress-bar__fill"
        style={{this.progressStyle}}
      ></div>
    </div>
  </template>
}
