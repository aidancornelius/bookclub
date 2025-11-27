import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

/**
 * Service for managing bookclub author dashboard operations
 * @class BookclubAuthorService
 */
export default class BookclubAuthorService extends Service {
  /**
   * Fetch all publications the current user can author or edit
   * @returns {Promise<Object>} Promise resolving to publications list
   */
  async fetchAuthorPublications() {
    try {
      return await ajax("/bookclub/author/publications.json", {
        type: "GET",
      });
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Create a new publication (admin only)
   * @param {Object} data - Publication data
   * @param {string} data.name - Publication name
   * @param {string} data.type - Publication type (book, journal)
   * @param {string} data.slug - URL slug (optional, auto-generated from name)
   * @param {string} data.description - Description (optional)
   * @returns {Promise<Object>} Promise resolving to created publication
   */
  async createPublication(data) {
    try {
      return await ajax("/bookclub/author/publications.json", {
        type: "POST",
        data,
      });
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Fetch detailed publication data including contents
   * @param {string} publicationSlug - The publication slug
   * @returns {Promise<Object>} Promise resolving to publication details
   */
  async fetchPublication(publicationSlug) {
    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}.json`,
        {
          type: "GET",
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Update publication metadata
   * @param {string} publicationSlug - The publication slug
   * @param {Object} data - Updated publication data
   * @param {string} data.name - Publication name
   * @param {string} data.type - Publication type (book, journal)
   * @param {string} data.description - Description
   * @param {string} data.cover_url - Cover image URL
   * @param {string} data.new_slug - New URL slug (optional)
   * @returns {Promise<Object>} Promise resolving to updated publication
   */
  async updatePublication(publicationSlug, data) {
    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}.json`,
        {
          type: "PUT",
          data,
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Fetch analytics data for a publication
   * @param {string} publicationSlug - The publication slug
   * @returns {Promise<Object>} Promise resolving to analytics data
   */
  async fetchAnalytics(publicationSlug) {
    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}/analytics.json`,
        {
          type: "GET",
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Create a new content item (chapter/article)
   * @param {string} publicationSlug - The publication slug
   * @param {Object} data - Content data
   * @param {string} data.title - Content title
   * @param {string} data.body - Content body text
   * @param {string} data.content_type - Type (chapter, article, etc.)
   * @param {string} data.access_level - Access level (free, member, etc.)
   * @param {string} data.summary - Optional summary
   * @returns {Promise<Object>} Promise resolving to created content
   */
  async createContent(publicationSlug, data) {
    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}/chapters.json`,
        {
          type: "POST",
          data,
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Update content item metadata
   * @param {string} publicationSlug - The publication slug
   * @param {number} contentNumber - The content number
   * @param {Object} data - Updated data
   * @param {boolean} data.published - Published status
   * @param {string} data.access_level - Access level
   * @param {string} data.summary - Summary text
   * @param {string} data.review_status - Review status
   * @returns {Promise<Object>} Promise resolving to updated content
   */
  async updateContent(publicationSlug, contentNumber, data) {
    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}/chapters/${contentNumber}.json`,
        {
          type: "PUT",
          data,
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Delete a content item
   * @param {string} publicationSlug - The publication slug
   * @param {number} contentNumber - The content number
   * @returns {Promise<Object>} Promise resolving to success response
   */
  async deleteContent(publicationSlug, contentNumber) {
    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}/chapters/${contentNumber}.json`,
        {
          type: "DELETE",
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Reorder content items in a publication
   * @param {string} publicationSlug - The publication slug
   * @param {Array<Object>} order - Array of {id, number} objects
   * @returns {Promise<Object>} Promise resolving to success response
   */
  async reorderContents(publicationSlug, order) {
    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}/chapters/reorder.json`,
        {
          type: "PUT",
          data: { order },
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Toggle published status of a content item
   * @param {string} publicationSlug - The publication slug
   * @param {number} contentNumber - The content number
   * @param {boolean} published - New published status
   * @returns {Promise<Object>} Promise resolving to updated content
   */
  async togglePublished(publicationSlug, contentNumber, published) {
    return this.updateContent(publicationSlug, contentNumber, { published });
  }

  /**
   * Import a book from an uploaded file (creates new publication)
   * @param {File} file - The file to import
   * @param {Object} options - Import options
   * @param {string} options.slug - Custom slug for the publication
   * @param {boolean} options.publish - Whether to publish chapters immediately
   * @param {string} options.accessLevel - Default access level for chapters
   * @returns {Promise<Object>} Promise resolving to import result
   */
  async importBook(file, options = {}) {
    const formData = new FormData();
    formData.append("file", file);

    if (options.slug) {
      formData.append("slug", options.slug);
    }
    if (options.publish) {
      formData.append("publish", "true");
    }
    if (options.accessLevel) {
      formData.append("access_level", options.accessLevel);
    }

    try {
      return await ajax("/bookclub/author/import.json", {
        type: "POST",
        data: formData,
        processData: false,
        contentType: false,
      });
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  /**
   * Re-import/update an existing publication from an uploaded file
   * @param {string} publicationSlug - The publication slug
   * @param {File} file - The file to import
   * @param {Object} options - Import options
   * @param {boolean} options.replaceExisting - Replace existing chapters vs skip
   * @param {boolean} options.publish - Whether to publish new chapters immediately
   * @param {string} options.accessLevel - Default access level for new chapters
   * @returns {Promise<Object>} Promise resolving to import result
   */
  async reimportBook(publicationSlug, file, options = {}) {
    const formData = new FormData();
    formData.append("file", file);

    if (options.replaceExisting) {
      formData.append("replace_existing", "true");
    }
    if (options.publish) {
      formData.append("publish", "true");
    }
    if (options.accessLevel) {
      formData.append("access_level", options.accessLevel);
    }

    try {
      return await ajax(
        `/bookclub/author/publications/${publicationSlug}/import.json`,
        {
          type: "POST",
          data: formData,
          processData: false,
          contentType: false,
        }
      );
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }
}
