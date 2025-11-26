import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import BookclubChapterDiscussions from "discourse/plugins/bookclub/discourse/components/bookclub-chapter-discussions";
import BookclubChapterNav from "discourse/plugins/bookclub/discourse/components/bookclub-chapter-nav";
import BookclubMobileNav from "discourse/plugins/bookclub/discourse/components/bookclub-mobile-nav";
import BookclubPricingTiers from "discourse/plugins/bookclub/discourse/components/bookclub-pricing-tiers";
import BookclubProgressBar from "discourse/plugins/bookclub/discourse/components/bookclub-progress-bar";
import BookclubReadingHeader from "discourse/plugins/bookclub/discourse/components/bookclub-reading-header";
import BookclubSettingsPanel from "discourse/plugins/bookclub/discourse/components/bookclub-settings-panel";
import BookclubShortcutsHelp from "discourse/plugins/bookclub/discourse/components/bookclub-shortcuts-help";
import BookclubTocSidebar from "discourse/plugins/bookclub/discourse/components/bookclub-toc-sidebar";
import BookclubTocToggle from "discourse/plugins/bookclub/discourse/components/bookclub-toc-toggle";

export default <template>
  {{bodyClass "bookclub-page"}}
  {{#if @controller.paywall}}
    <BookclubPricingTiers
      @publicationSlug={{@controller.slug}}
      @accessTiers={{@controller.accessTiers}}
    />
  {{else}}
    <div class="bookclub-content-view">
      <BookclubReadingHeader
        @publication={{@controller.publication}}
        @chapter={{@controller.chapter}}
        @navigation={{@controller.navigation}}
      />

      <BookclubTocSidebar
        @toc={{@controller.publication.toc}}
        @currentNumber={{@controller.chapter.number}}
      />

      <BookclubSettingsPanel />
      <BookclubShortcutsHelp />

      <nav class="bookclub-breadcrumb">
        <LinkTo
          @route="bookclub-publication"
          @model={{@controller.publication.slug}}
          class="bookclub-breadcrumb__link"
        >
          {{icon "arrow-left"}}
          <span>{{@controller.publication.name}}</span>
        </LinkTo>
        <BookclubTocToggle />
      </nav>

      <article class="bookclub-content">
        <header class="bookclub-content__header">
          <span
            class="bookclub-content__number"
          >{{@controller.chapter.number}}</span>
          <h1 class="bookclub-content__title">{{@controller.chapter.title}}</h1>
        </header>

        <div class="bookclub-content__body">
          {{htmlSafe @controller.chapter.body_html}}
        </div>
      </article>

      {{#if @controller.discussions}}
        <BookclubChapterDiscussions @discussions={{@controller.discussions}} />
      {{/if}}

      <BookclubChapterNav @navigation={{@controller.navigation}} />

      <BookclubProgressBar />
      <BookclubMobileNav @navigation={{@controller.navigation}} />
    </div>
  {{/if}}
</template>
