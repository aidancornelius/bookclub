import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class BookclubPageRoute extends Route {
  @service bookclubPages;

  async model(params) {
    const result = await this.bookclubPages.fetchPage(params.slug);
    return result.page;
  }
}
