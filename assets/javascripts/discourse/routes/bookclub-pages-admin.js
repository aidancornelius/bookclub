import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class BookclubPagesAdminRoute extends Route {
  @service currentUser;
  @service router;
  @service bookclubPages;

  beforeModel() {
    if (!this.currentUser?.admin) {
      this.router.transitionTo("discovery.latest");
    }
  }

  async model() {
    const result = await this.bookclubPages.fetchAll();
    return result.pages || [];
  }
}
