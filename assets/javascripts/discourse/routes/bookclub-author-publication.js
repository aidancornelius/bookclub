import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

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
   * Load publication details and analytics
   * @param {Object} params - Route parameters
   * @param {string} params.slug - Publication slug
   * @returns {Promise<Object>} Publication details with analytics
   */
  async model(params) {
    const [publication, analytics] = await Promise.all([
      this.bookclubAuthor.fetchPublication(params.slug),
      this.bookclubAuthor.fetchAnalytics(params.slug),
    ]);

    return {
      ...publication,
      analytics,
    };
  }
}
