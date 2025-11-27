import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

/**
 * Route for viewing bookclub content (chapter/article)
 * @class BookclubContentRoute
 */
export default class BookclubContentRoute extends DiscourseRoute {
  @service bookclubReading;

  /**
   * Load chapter data
   * @param {Object} params - Route parameters (chapter_id can be number or slug)
   * @returns {Promise<Object>} Chapter data
   */
  async model(params) {
    try {
      return await ajax(
        `/bookclub/publications/${params.slug}/chapters/${params.chapter_id}.json`
      );
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log("Bookclub content route error:", error);

      const status = error.jqXHR?.status || error.status;
      const responseJSON = error.jqXHR?.responseJSON || error.responseJSON;

      if (status === 403 && responseJSON?.paywall) {
        return {
          paywall: true,
          slug: params.slug,
          chapter_id: params.chapter_id,
          access_tiers: responseJSON.access_tiers,
        };
      }
      throw error;
    }
  }

  /**
   * Set up the controller and enter reading mode
   * @param {Object} controller - The controller instance
   * @param {Object} model - The route model
   */
  setupController(controller, model) {
    super.setupController(controller, model);

    if (model.paywall) {
      controller.setProperties({
        paywall: true,
        accessTiers: model.access_tiers,
        slug: model.slug,
        chapterId: model.chapter_id,
      });
      return;
    }

    controller.setProperties({
      paywall: false,
      publication: model.publication,
      chapter: model.chapter,
      navigation: model.navigation,
      readingProgress: model.reading_progress,
      discussions: model.discussions,
      feedbackSettings: model.feedback_settings,
    });

    // Enter reading mode
    if (model.publication && model.chapter) {
      this.bookclubReading.enterReadingMode(model.publication, model.chapter);
    }
  }

  /**
   * Exit reading mode when leaving the route
   */
  deactivate() {
    this.bookclubReading.exitReadingMode();
  }
}
