import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";

/**
 * Public page view component
 */
export default class BookclubPageView extends Component {
  get cookedContent() {
    return htmlSafe(this.args.page?.cooked || "");
  }

  <template>
    <div class="bookclub-page-view">
      <article class="bookclub-page-view__content">
        <header class="bookclub-page-view__header">
          {{#if @page.icon}}
            <span class="bookclub-page-view__icon">
              {{icon @page.icon}}
            </span>
          {{/if}}
          <h1 class="bookclub-page-view__title">{{@page.title}}</h1>
        </header>

        <div class="bookclub-page-view__body cooked">
          {{this.cookedContent}}
        </div>
      </article>
    </div>
  </template>
}
