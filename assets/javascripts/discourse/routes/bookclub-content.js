import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

/**
 * Route for viewing bookclub content (chapter/article)
 * @class BookclubContentRoute
 */
export default class BookclubContentRoute extends DiscourseRoute {
  @service bookclubReading;
  @service router;

  /**
   * Load chapter data
   * @param {Object} params - Route parameters (chapter_id can be number or slug)
   * @returns {Promise<Object>} Chapter data
   */
  async model(params) {
    // Check if returning from Stripe checkout
    const urlParams = new URLSearchParams(window.location.search);
    const checkoutSessionId = urlParams.get("checkout_session_id");

    if (checkoutSessionId) {
      // Return special model to trigger checkout verification
      return {
        verifyingCheckout: true,
        checkoutSessionId,
        slug: params.slug,
        chapter_id: params.chapter_id,
      };
    }

    return await this.loadContent(params);
  }

  async loadContent(params) {
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
          pricing_config: responseJSON.pricing_config,
          publication_slug: responseJSON.publication_slug,
          publication_name: responseJSON.publication_name,
          chapter_number: responseJSON.chapter_number,
          preview_chapters: responseJSON.preview_chapters,
          preview_remaining: responseJSON.preview_remaining,
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

    if (model.verifyingCheckout) {
      controller.setProperties({
        verifyingCheckout: true,
        checkoutSessionId: model.checkoutSessionId,
        slug: model.slug,
        chapterId: model.chapter_id,
        paywall: false,
      });
      // Trigger verification in the controller/template
      return;
    }

    if (model.paywall) {
      controller.setProperties({
        paywall: true,
        verifyingCheckout: false,
        accessTiers: model.access_tiers,
        pricingConfig: model.pricing_config,
        publicationSlug: model.publication_slug,
        publicationName: model.publication_name,
        chapterNumber: model.chapter_number,
        previewChapters: model.preview_chapters,
        previewRemaining: model.preview_remaining,
        slug: model.slug,
        chapterId: model.chapter_id,
      });
      return;
    }

    controller.setProperties({
      paywall: false,
      verifyingCheckout: false,
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
