import { withPluginApi } from "discourse/lib/plugin-api";

/**
 * Initialiser for Bookclub reading mode
 * Activates reading mode when viewing topics in publication categories
 */
export default {
  name: "bookclub-reading-mode",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.bookclub_enabled) {
      return;
    }

    withPluginApi((api) => {
      // Add tracked properties to topics for publication data
      api.addTrackedPostProperties(
        "bookclub_content_type",
        "bookclub_content_number",
        "bookclub_content_published"
      );

      // Modify topic model to include publication info
      api.modifyClass(
        "model:topic",
        (Superclass) =>
          class extends Superclass {
            get isPublicationContent() {
              return (
                this.category?.custom_fields?.publication_enabled === true ||
                this.category?.custom_fields?.publication_enabled === "true"
              );
            }

            get publicationSlug() {
              return this.category?.custom_fields?.publication_slug;
            }

            get publicationType() {
              return this.category?.custom_fields?.publication_type || "book";
            }

            get contentNumber() {
              return this.custom_fields?.bookclub_content_number;
            }

            get contentType() {
              return this.custom_fields?.bookclub_content_type || "chapter";
            }
          }
      );

      // Watch for topic changes and activate reading mode
      api.onPageChange((url) => {
        const bookclubReading = container.lookup("service:bookclub-reading");

        // Check if we're on a book URL
        const bookMatch = url.match(/^\/book\/([^/]+)(?:\/(\d+))?/);

        if (bookMatch) {
          // We're on a book page, reading mode will be activated by the route
          return;
        }

        // Check if viewing a topic that might be publication content
        const topicMatch = url.match(/^\/t\/[^/]+\/(\d+)/);

        if (topicMatch && bookclubReading.isReadingMode) {
          // Leaving reading mode
          bookclubReading.exitReadingMode();
        }
      });

      // Activate reading mode when topic route model changes
      api.modifyClass(
        "route:topic",
        (Superclass) =>
          class extends Superclass {
            afterModel(model) {
              super.afterModel?.(...arguments);

              if (
                model?.isPublicationContent &&
                siteSettings.bookclub_enable_reading_mode
              ) {
                const bookclubReading = container.lookup(
                  "service:bookclub-reading"
                );
                bookclubReading.enterReadingMode(
                  {
                    slug: model.publicationSlug,
                    type: model.publicationType,
                    name: model.category?.name,
                  },
                  {
                    id: model.id,
                    title: model.title,
                    number: model.contentNumber,
                    type: model.contentType,
                  }
                );
              }
            }

            deactivate() {
              super.deactivate?.(...arguments);

              const bookclubReading = container.lookup(
                "service:bookclub-reading"
              );
              if (bookclubReading.isReadingMode) {
                bookclubReading.exitReadingMode();
              }
            }
          }
      );
    });
  },
};
