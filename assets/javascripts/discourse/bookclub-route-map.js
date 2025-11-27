/**
 * Route map for Bookclub public routes
 * Book reading routes
 * Supports both numeric (/book/slug/2) and slug-based (/book/slug/chapter-slug) URLs
 */
export default function () {
  this.route("bookclub-publication", { path: "/book/:slug" });
  this.route("bookclub-content", { path: "/book/:slug/:chapter_id" });
  this.route("bookclub-discuss", {
    path: "/book/:slug/:chapter_id/discuss",
  });
}
