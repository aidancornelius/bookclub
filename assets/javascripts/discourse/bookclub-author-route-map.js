/**
 * Route map for Bookclub author dashboard and pages
 */
export default function () {
  this.route("bookclub-author", { path: "/bookclub/author" });
  this.route("bookclub-author-publication", { path: "/bookclub/author/:slug" });
  this.route("bookclub-pages-admin", { path: "/bookclub/pages" });
  this.route("bookclub-page", { path: "/pages/:slug" });
}
