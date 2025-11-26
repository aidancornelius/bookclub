import Component from "@glimmer/component";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import icon from "discourse-common/helpers/d-icon";

/**
 * Book-first navigation component for the header
 * Places library and reading links prominently before forum navigation
 */
export default class BookclubHeaderNav extends Component {
  @service router;
  @service currentUser;
  @service siteSettings;

  get showLibrary() {
    return true;
  }

  get showCommunity() {
    return true;
  }

  get currentPath() {
    return this.router.currentURL || "";
  }

  get isLibraryActive() {
    const path = this.currentPath;
    // Library is active on homepage, categories, and book pages
    return path === "/" || path.startsWith("/categories") || path.startsWith("/c/") || path.startsWith("/book/");
  }

  get isBookmarksActive() {
    const path = this.currentPath;
    return path.includes("/bookmarks") || path.includes("/activity/bookmarks");
  }

  get isCommunityActive() {
    const path = this.currentPath;
    // Community is active on latest, top, and similar discussion pages
    return path.startsWith("/latest") || path.startsWith("/top") || path.startsWith("/new") || path.startsWith("/unread");
  }

  <template>
    <nav class="bookclub-header-nav" role="navigation" aria-label="Main navigation">
      {{#if this.showLibrary}}
        <a
          href="/"
          class="nav-link {{if this.isLibraryActive 'active'}}"
          title="Browse the library"
        >
          {{icon "book-open"}}
          <span class="nav-text">Library</span>
        </a>
      {{/if}}

      {{#if this.currentUser}}
        <a
          href="/my/activity/bookmarks"
          class="nav-link {{if this.isBookmarksActive 'active'}}"
          title="Your bookmarks"
        >
          {{icon "bookmark"}}
          <span class="nav-text">Bookmarks</span>
        </a>
      {{/if}}

      {{#if this.showCommunity}}
        <a
          href="/latest"
          class="nav-link {{if this.isCommunityActive 'active'}}"
          title="Community discussions"
        >
          {{icon "comments"}}
          <span class="nav-text">Community</span>
        </a>
      {{/if}}
    </nav>
  </template>
}
