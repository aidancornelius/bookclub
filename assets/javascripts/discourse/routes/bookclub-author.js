import DiscourseRoute from "discourse/routes/discourse";
import { service } from "@ember/service";

/**
 * Route for the bookclub author dashboard
 * @class BookclubAuthorRoute
 */
export default class BookclubAuthorRoute extends DiscourseRoute {
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
   * Load author's publications
   * @returns {Promise<Object>} Publications data
   */
  async model() {
    return this.bookclubAuthor.fetchAuthorPublications();
  }

  /**
   * Set up the controller with the model data
   * @param {Object} controller - The controller instance
   * @param {Object} model - The route model
   */
  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("publications", model.publications);
  }
}
