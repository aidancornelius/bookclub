import DiscourseRoute from "discourse/routes/discourse";
import { service } from "@ember/service";

/**
 * Route for viewing a specific publication in the author dashboard
 * @class BookclubAuthorPublicationRoute
 */
export default class BookclubAuthorPublicationRoute extends DiscourseRoute {
  @service bookclubAuthor;
  @service router;
  @service currentUser;

  /**
   * Redirect to login if user is not logged in
   */
  beforeModel() {
    if (!this.currentUser) {
      this.router.transitionTo("login");
    }
  }

  /**
   * Load publication details
   * @param {Object} params - Route parameters
   * @param {string} params.slug - Publication slug
   * @returns {Promise<Object>} Publication details
   */
  async model(params) {
    return this.bookclubAuthor.fetchPublication(params.slug);
  }
}
