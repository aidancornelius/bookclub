import { getOwner } from "@ember/owner";
import { apiInitializer } from "discourse/lib/api";
import BookclubHeaderNav from "../components/bookclub-header-nav";
import BookclubHomepage from "../components/bookclub-homepage";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();

  // Add book-first navigation to header
  api.renderInOutlet("header-contents__after", BookclubHeaderNav);

  // Show BookclubHomepage on discovery pages (above the topic list)
  api.renderInOutlet("discovery-list-controls-above", BookclubHomepage);

  // Add/remove body classes based on route
  api.onPageChange((url) => {
    // Homepage class - hide default topic list
    const isHomepage = url === "/" || url === "";
    if (isHomepage) {
      document.body.classList.add("bookclub-homepage");
    } else {
      document.body.classList.remove("bookclub-homepage");
    }

    // Book reading pages - hide footer and adjust layout
    const isBookPage = url.startsWith("/book/");
    if (isBookPage) {
      document.body.classList.add("bookclub-reading-view");
    } else {
      document.body.classList.remove("bookclub-reading-view");
    }
  });

  // Add Library section to sidebar using proper API
  api.addSidebarSection(
    (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
      return class LibrarySidebarSection extends BaseCustomSidebarSection {
        name = "library";
        text = "Library";
        collapsedByDefault = false;

        get links() {
          const links = [];

          // Get site categories to list publications
          const container = getOwner(this);
          const site = container?.lookup("service:site");
          const categories = site?.categories || [];

          // Filter to only show actual publications (categories with publication_enabled)
          const publications = categories.filter((cat) => {
            // Check for publication_enabled flag (set by bookclub plugin)
            const isPublication =
              cat.publication_enabled === true ||
              cat.publication_enabled === "true" ||
              cat.custom_fields?.publication_enabled === true ||
              cat.custom_fields?.publication_enabled === "true";
            return isPublication;
          });

          // Add each publication as a link
          publications.slice(0, 8).forEach((category) => {
            const cat = category;
            // Use the book URL if available, otherwise category URL
            const bookSlug =
              cat.publication_slug ||
              cat.custom_fields?.publication_slug ||
              cat.slug;

            links.push(
              new (class extends BaseCustomSidebarSectionLink {
                get name() {
                  return `publication-${cat.id}`;
                }

                get href() {
                  return `/book/${bookSlug}`;
                }

                get title() {
                  return cat.description_excerpt || cat.name;
                }

                get text() {
                  return cat.name;
                }

                get prefixType() {
                  return "icon";
                }

                get prefixValue() {
                  return "book";
                }
              })()
            );
          });

          // Bookmarks link (only for logged in users)
          if (currentUser) {
            links.push(
              new (class extends BaseCustomSidebarSectionLink {
                name = "bookmarks";
                href = "/my/activity/bookmarks";
                title = "Your bookmarks";
                text = "Bookmarks";
                prefixType = "icon";
                prefixValue = "bookmark";
              })()
            );
          }

          return links;
        }
      };
    },
    "main"
  );

  // Add Creator section for users with book creation/editing capabilities
  // Show for admins, moderators, and trust level 4 (Leaders)
  const canManageBooks =
    currentUser?.admin ||
    currentUser?.moderator ||
    currentUser?.trust_level >= 4;

  if (canManageBooks) {
    api.addSidebarSection(
      (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
        return class CreatorSidebarSection extends BaseCustomSidebarSection {
          name = "creator";
          text = "Creator";
          collapsedByDefault = false;

          get links() {
            return [
              new (class extends BaseCustomSidebarSectionLink {
                name = "author-dashboard";
                href = "/bookclub/author";
                title = "Manage your publications";
                text = "Author dashboard";
                prefixType = "icon";
                prefixValue = "pen";
              })(),
            ];
          }
        };
      },
      "main"
    );
  }

  // Add body class for bookclub styling
  // Temporarily simplified to debug /latest issue
  document.body.classList.add("bookclub-theme");
});
