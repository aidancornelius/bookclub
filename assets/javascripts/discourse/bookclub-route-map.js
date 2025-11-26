/**
 * Route map for Bookclub public routes
 * Book reading routes
 */
export default function () {
  this.route("bookclub-publication", { path: "/book/:slug" });
  this.route("bookclub-content", { path: "/book/:slug/:content_number" });
  this.route("bookclub-discuss", {
    path: "/book/:slug/:content_number/discuss",
  });
}
