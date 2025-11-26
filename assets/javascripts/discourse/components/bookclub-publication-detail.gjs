import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import BookclubChapterList from "./bookclub-chapter-list";
import BookclubPublicationStats from "./bookclub-publication-stats";

/**
 * Publication detail view for author dashboard
 * @component BookclubPublicationDetail
 */
export default class BookclubPublicationDetail extends Component {
  @service router;

  @tracked activeTab = "chapters";

  /**
   * Switch to chapters tab
   */
  @action
  showChapters() {
    this.activeTab = "chapters";
  }

  /**
   * Switch to stats tab
   */
  @action
  showStats() {
    this.activeTab = "stats";
  }

  /**
   * Navigate back to dashboard
   */
  @action
  backToDashboard() {
    this.router.transitionTo("bookclub-author");
  }

  /**
   * View publication public page
   */
  @action
  viewPublicPage() {
    window.location.href = `/book/${this.args.publication.slug}`;
  }

  <template>
    <div class="bookclub-publication-detail">
      <div class="bookclub-publication-detail__header">
        <div class="bookclub-publication-detail__header-top">
          <DButton
            @action={{this.backToDashboard}}
            @icon="arrow-left"
            @label="bookclub.author.back_to_dashboard"
            class="btn-flat"
          />
        </div>

        <div class="bookclub-publication-detail__header-content">
          {{#if @publication.cover_url}}
            <div class="bookclub-publication-detail__cover">
              <img src={{@publication.cover_url}} alt={{@publication.name}} />
            </div>
          {{/if}}

          <div class="bookclub-publication-detail__info">
            <h1 class="bookclub-publication-detail__title">
              {{@publication.name}}
            </h1>

            {{#if @publication.description}}
              <p class="bookclub-publication-detail__description">
                {{@publication.description}}
              </p>
            {{/if}}

            <div class="bookclub-publication-detail__meta">
              <span class="bookclub-publication-detail__type">
                {{icon "book"}}
                {{@publication.type}}
              </span>
            </div>

            <div class="bookclub-publication-detail__actions">
              <DButton
                @action={{this.viewPublicPage}}
                @label="bookclub.author.view_public"
                @icon="link"
                class="btn-default"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="bookclub-publication-detail__tabs">
        <button
          type="button"
          class="bookclub-publication-detail__tab
            {{if (eq this.activeTab 'chapters') 'active'}}"
          {{on "click" this.showChapters}}
        >
          {{icon "list-ul"}}
          Chapters
        </button>
        <button
          type="button"
          class="bookclub-publication-detail__tab
            {{if (eq this.activeTab 'stats') 'active'}}"
          {{on "click" this.showStats}}
        >
          {{icon "chart-line"}}
          Statistics
        </button>
      </div>

      <div class="bookclub-publication-detail__content">
        {{#if (eq this.activeTab "chapters")}}
          <BookclubChapterList
            @publicationSlug={{@publication.slug}}
            @chapters={{@publication.chapters}}
          />
        {{else if (eq this.activeTab "stats")}}
          <BookclubPublicationStats @publicationSlug={{@publication.slug}} />
        {{/if}}
      </div>
    </div>
  </template>
}
