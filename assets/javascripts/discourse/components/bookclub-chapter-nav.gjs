import Component from "@glimmer/component";
import { service } from "@ember/service";

/**
 * Chapter navigation component
 * Shows previous/next chapter links
 * @component BookclubChapterNav
 * @param {Object} navigation - Navigation data with previous, current, next
 */
export default class BookclubChapterNav extends Component {
  @service bookclubReading;

  get publicationSlug() {
    return this.bookclubReading.currentPublication?.slug || "";
  }

  get hasPrevious() {
    return this.args.navigation?.previous != null;
  }

  get hasNext() {
    return this.args.navigation?.next != null;
  }

  get previous() {
    return this.args.navigation?.previous;
  }

  get next() {
    return this.args.navigation?.next;
  }

  <template>
    <nav class="bookclub-chapter-nav">
      {{#if this.hasPrevious}}
        <a
          href="/book/{{this.publicationSlug}}/{{this.previous.number}}"
          class="bookclub-chapter-nav__link bookclub-chapter-nav__link--prev"
        >
          <span class="bookclub-chapter-nav__label">Previous</span>
          <span
            class="bookclub-chapter-nav__title"
          >{{this.previous.title}}</span>
        </a>
      {{else}}
        <div
          class="bookclub-chapter-nav__link bookclub-chapter-nav__link--prev bookclub-chapter-nav__link--disabled"
        >
          <span class="bookclub-chapter-nav__label">Previous</span>
          <span class="bookclub-chapter-nav__title">No previous chapter</span>
        </div>
      {{/if}}

      {{#if this.hasNext}}
        <a
          href="/book/{{this.publicationSlug}}/{{this.next.number}}"
          class="bookclub-chapter-nav__link bookclub-chapter-nav__link--next"
        >
          <span class="bookclub-chapter-nav__label">Next</span>
          <span class="bookclub-chapter-nav__title">{{this.next.title}}</span>
        </a>
      {{else}}
        <div
          class="bookclub-chapter-nav__link bookclub-chapter-nav__link--next bookclub-chapter-nav__link--disabled"
        >
          <span class="bookclub-chapter-nav__label">Next</span>
          <span class="bookclub-chapter-nav__title">End of publication</span>
        </div>
      {{/if}}
    </nav>
  </template>
}
