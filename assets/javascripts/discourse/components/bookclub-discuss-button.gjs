import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";

/**
 * Button to scroll smoothly to chapter discussions
 * @component BookclubDiscussButton
 */
export default class BookclubDiscussButton extends Component {
  @action
  handleClick(event) {
    event.preventDefault();
    const discussionsEl = document.querySelector(
      ".bookclub-chapter-discussions"
    );
    if (discussionsEl) {
      discussionsEl.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  <template>
    <button
      type="button"
      class="bookclub-discuss-button"
      {{on "click" this.handleClick}}
    >
      {{icon "comments"}}
      <span>Discuss this chapter</span>
    </button>
  </template>
}
