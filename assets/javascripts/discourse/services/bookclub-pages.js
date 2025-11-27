import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

/**
 * Service for managing bookclub pages
 */
export default class BookclubPagesService extends Service {
  @tracked navPages = null;
  @tracked navLoading = false;

  /**
   * Fetch navigation pages (cached)
   */
  async fetchNav() {
    if (this.navPages) {
      return this.navPages;
    }

    this.navLoading = true;
    try {
      const result = await ajax("/bookclub/pages/nav.json");
      this.navPages = result;
      return result;
    } finally {
      this.navLoading = false;
    }
  }

  /**
   * Invalidate nav cache (call after create/update/delete)
   */
  invalidateNav() {
    this.navPages = null;
  }

  /**
   * Fetch all pages (admin)
   */
  async fetchAll() {
    return await ajax("/bookclub/pages.json");
  }

  /**
   * Fetch a single page by slug
   */
  async fetchPage(slug) {
    return await ajax(`/bookclub/pages/${slug}.json`);
  }

  /**
   * Create a new page
   */
  async createPage(pageData) {
    const result = await ajax("/bookclub/pages.json", {
      type: "POST",
      data: { page: pageData },
    });
    this.invalidateNav();
    return result;
  }

  /**
   * Update a page
   */
  async updatePage(slug, pageData) {
    const result = await ajax(`/bookclub/pages/${slug}.json`, {
      type: "PUT",
      data: { page: pageData },
    });
    this.invalidateNav();
    return result;
  }

  /**
   * Delete a page
   */
  async deletePage(slug) {
    const result = await ajax(`/bookclub/pages/${slug}.json`, {
      type: "DELETE",
    });
    this.invalidateNav();
    return result;
  }

  /**
   * Reorder pages
   */
  async reorderPages(pagesData) {
    const result = await ajax("/bookclub/pages/reorder.json", {
      type: "POST",
      data: { pages: pagesData },
    });
    this.invalidateNav();
    return result;
  }
}
