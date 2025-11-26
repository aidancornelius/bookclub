/**
 * Route map for Bookclub author dashboard
 */
export default function () {
  this.route("bookclub-author", { path: "/bookclub/author" });
  this.route("bookclub-author-publication", { path: "/bookclub/author/:slug" });
}
