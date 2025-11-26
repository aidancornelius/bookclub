import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

/**
 * Route for viewing a bookclub publication
 * @class BookclubPublicationRoute
 */
export default class BookclubPublicationRoute extends DiscourseRoute {
  /**
   * Load publication data
   * @param {Object} params - Route parameters
   * @returns {Promise<Object>} Publication data
   */
  async model(params) {
    return ajax(`/bookclub/publications/${params.slug}.json`);
  }

  /**
   * Set up the controller with the model data
   * @param {Object} controller - The controller instance
   * @param {Object} model - The route model
   */
  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setProperties({
      publication: model,
      toc: model.toc || [],
      hasAccess: model.has_access,
      isAuthor: model.is_author,
      isEditor: model.is_editor,
    });
  }
}
