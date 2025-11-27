import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import BookclubBookmarkButton from "discourse/plugins/bookclub/discourse/components/bookclub-bookmark-button";
import BookclubChapterDiscussions from "discourse/plugins/bookclub/discourse/components/bookclub-chapter-discussions";
import BookclubChapterNav from "discourse/plugins/bookclub/discourse/components/bookclub-chapter-nav";
import BookclubCheckoutVerify from "discourse/plugins/bookclub/discourse/components/bookclub-checkout-verify";
import BookclubDiscussButton from "discourse/plugins/bookclub/discourse/components/bookclub-discuss-button";
import BookclubMobileNav from "discourse/plugins/bookclub/discourse/components/bookclub-mobile-nav";
import BookclubPaywallDisplay from "discourse/plugins/bookclub/discourse/components/bookclub-paywall-display";
import BookclubPaywallModal from "discourse/plugins/bookclub/discourse/components/bookclub-paywall-modal";
import BookclubPricingTiers from "discourse/plugins/bookclub/discourse/components/bookclub-pricing-tiers";
import BookclubProgressBar from "discourse/plugins/bookclub/discourse/components/bookclub-progress-bar";
import BookclubReadingHeader from "discourse/plugins/bookclub/discourse/components/bookclub-reading-header";
import BookclubSettingsPanel from "discourse/plugins/bookclub/discourse/components/bookclub-settings-panel";
import BookclubShortcutsHelp from "discourse/plugins/bookclub/discourse/components/bookclub-shortcuts-help";
import BookclubTocSidebar from "discourse/plugins/bookclub/discourse/components/bookclub-toc-sidebar";
import BookclubTocToggle from "discourse/plugins/bookclub/discourse/components/bookclub-toc-toggle";

export default <template>
  {{bodyClass "bookclub-page"}}
  {{#if @controller.verifyingCheckout}}
    <BookclubCheckoutVerify
      @slug={{@controller.slug}}
      @sessionId={{@controller.checkoutSessionId}}
    />
  {{else if @controller.paywall}}
    {{#if @controller.pricingConfig}}
      <BookclubPaywallDisplay
        @paywall={{hash
          publication_name=@controller.publicationName
          publication_slug=@controller.publicationSlug
          preview_chapters=@controller.previewChapters
          preview_remaining=@controller.previewRemaining
          one_time_price_id=@controller.pricingConfig.one_time_price_id
          one_time_amount=@controller.pricingConfig.one_time_amount
          subscription_price_id=@controller.pricingConfig.subscription_price_id
          subscription_amount=@controller.pricingConfig.subscription_amount
          subscription_interval=@controller.pricingConfig.subscription_interval
        }}
      />
    {{else}}
      <BookclubPricingTiers
        @publicationSlug={{@controller.slug}}
        @accessTiers={{@controller.accessTiers}}
      />
    {{/if}}
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

        <div class="bookclub-content__actions">
          <BookclubBookmarkButton @topicId={{@controller.chapter.content_topic_id}} />
          {{#if @controller.discussions}}
            <BookclubDiscussButton />
          {{/if}}
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
