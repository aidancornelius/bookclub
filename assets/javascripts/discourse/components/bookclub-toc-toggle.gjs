import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";

/**
 * Simple TOC toggle button component
 * @component BookclubTocToggle
 */
export default class BookclubTocToggle extends Component {
  @service bookclubReading;

  @action
  toggle() {
    this.bookclubReading.toggleToc();
  }

  <template>
    <button
      type="button"
      class="bookclub-toc-toggle"
      title="Table of contents"
      {{on "click" this.toggle}}
    >
      {{icon "list"}}
      <span>Contents</span>
    </button>
  </template>
}
