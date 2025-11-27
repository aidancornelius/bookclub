import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import icon from "discourse-common/helpers/d-icon";

/**
 * Book-first navigation component for the header
 * Places library and reading links prominently before forum navigation
 * Also renders dynamic pages from the bookclub pages system
 */
export default class BookclubHeaderNav extends Component {
  @service router;
  @service currentUser;
  @service siteSettings;

  @tracked navPages = null;
  @tracked navLoaded = false;
  @tracked openDropdown = null;

  constructor() {
    super(...arguments);
    this.loadNavPages();
  }

  async loadNavPages() {
    try {
      const result = await ajax("/bookclub/pages/nav.json");
      this.navPages = result.header || [];
      this.navLoaded = true;
    } catch (error) {
      console.error("Failed to load navigation pages:", error);
      this.navPages = [];
      this.navLoaded = true;
    }
  }

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
    return path === "/" || path.startsWith("/categories") || path.startsWith("/c/") || path.startsWith("/book/");
  }

  get isBookmarksActive() {
    const path = this.currentPath;
    return path.includes("/bookmarks") || path.includes("/activity/bookmarks");
  }

  get isCommunityActive() {
    const path = this.currentPath;
    return path.startsWith("/latest") || path.startsWith("/top") || path.startsWith("/new") || path.startsWith("/unread");
  }

  isPageActive = (page) => {
    const path = this.currentPath;
    return path === page.url || path.startsWith(page.url + "/");
  };

  isDropdownActive = (item) => {
    if (this.isPageActive(item.page)) {
      return true;
    }
    return item.children?.some((child) => this.isPageActive(child));
  };

  @action
  toggleDropdown(itemId, event) {
    event.preventDefault();
    event.stopPropagation();
    if (this.openDropdown === itemId) {
      this.openDropdown = null;
    } else {
      this.openDropdown = itemId;
    }
  }

  @action
  closeDropdowns() {
    this.openDropdown = null;
  }

  @action
  handleDropdownKeydown(itemId, event) {
    if (event.key === "Escape") {
      this.openDropdown = null;
    } else if (event.key === "Enter" || event.key === " ") {
      this.toggleDropdown(itemId, event);
    }
  }

  <template>
    <nav
      class="bookclub-header-nav"
      role="navigation"
      aria-label="Main navigation"
      {{on "mouseleave" this.closeDropdowns}}
    >
      {{! Core navigation items }}
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

      {{! Dynamic pages from bookclub pages system }}
      {{#if this.navLoaded}}
        {{#each this.navPages as |item|}}
          {{#if item.children.length}}
            {{! Dropdown menu }}
            <div
              class="nav-dropdown {{if (this.isDropdownActive item) 'active'}} {{if (this.isDropdownOpen item.page.id) 'open'}}"
            >
              <button
                type="button"
                class="nav-link nav-dropdown__trigger"
                aria-expanded={{if (this.isDropdownOpen item.page.id) "true" "false"}}
                aria-haspopup="true"
                {{on "click" (fn this.toggleDropdown item.page.id)}}
                {{on "keydown" (fn this.handleDropdownKeydown item.page.id)}}
              >
                {{#if item.page.icon}}
                  {{icon item.page.icon}}
                {{/if}}
                <span class="nav-text">{{item.page.title}}</span>
                {{icon "chevron-down" class="nav-dropdown__chevron"}}
              </button>
              <div class="nav-dropdown__menu" role="menu">
                {{! If parent page has content, show it first }}
                {{#if item.page.has_content}}
                  <a
                    href={{item.page.url}}
                    class="nav-dropdown__item {{if (this.isPageActive item.page) 'active'}}"
                    role="menuitem"
                  >
                    {{item.page.title}}
                  </a>
                  <hr class="nav-dropdown__separator" />
                {{/if}}
                {{#each item.children as |child|}}
                  <a
                    href={{child.url}}
                    class="nav-dropdown__item {{if (this.isPageActive child) 'active'}}"
                    role="menuitem"
                  >
                    {{#if child.icon}}
                      {{icon child.icon}}
                    {{/if}}
                    {{child.title}}
                  </a>
                {{/each}}
              </div>
            </div>
          {{else}}
            {{! Simple link }}
            <a
              href={{item.page.url}}
              class="nav-link {{if (this.isPageActive item.page) 'active'}}"
              title={{item.page.title}}
            >
              {{#if item.page.icon}}
                {{icon item.page.icon}}
              {{/if}}
              <span class="nav-text">{{item.page.title}}</span>
            </a>
          {{/if}}
        {{/each}}
      {{/if}}
    </nav>
  </template>

  isDropdownOpen = (itemId) => {
    return this.openDropdown === itemId;
  };
}
