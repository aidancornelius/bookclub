import bodyClass from "discourse/helpers/body-class";
import BookclubPublicationView from "discourse/plugins/bookclub/discourse/components/bookclub-publication-view";

export default <template>
  {{bodyClass "bookclub-page"}}
  <BookclubPublicationView
    @publication={{@controller.publication}}
    @toc={{@controller.toc}}
    @hasAccess={{@controller.hasAccess}}
    @isAuthor={{@controller.isAuthor}}
    @isEditor={{@controller.isEditor}}
  />
</template>
