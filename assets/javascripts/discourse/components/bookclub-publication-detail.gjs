import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import BookclubChapterList from "./bookclub-chapter-list";
import BookclubPublicationSettings from "./bookclub-publication-settings";
import BookclubPublicationStats from "./bookclub-publication-stats";

/**
 * Publication detail view for author dashboard
 * @component BookclubPublicationDetail
 */
export default class BookclubPublicationDetail extends Component {
  @service router;

  @tracked activeTab = "chapters";
  @tracked publication = this.args.publication;

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
   * Switch to settings tab
   */
  @action
  showSettings() {
    this.activeTab = "settings";
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
    window.location.href = `/book/${this.publication.slug}`;
  }

  /**
   * Handle publication update from settings
   * @param {Object} updatedPublication - Updated publication data
   */
  @action
  handlePublicationUpdate(updatedPublication) {
    this.publication = updatedPublication;
  }

  <template>
    <div class="bookclub-pub-detail">
      <header class="bookclub-pub-detail__header">
        <button
          type="button"
          class="bookclub-pub-detail__back"
          {{on "click" this.backToDashboard}}
        >
          {{icon "arrow-left"}}
          Back to dashboard
        </button>

        <div class="bookclub-pub-detail__title-row">
          <h1 class="bookclub-pub-detail__title">
            {{this.publication.name}}
          </h1>
          <DButton
            @action={{this.viewPublicPage}}
            @icon="link"
            @label="bookclub.author.view_public"
            class="btn-flat"
          />
        </div>

        {{#if this.publication.description}}
          <p class="bookclub-pub-detail__description">
            {{this.publication.description}}
          </p>
        {{/if}}
      </header>

      <nav class="bookclub-pub-detail__nav">
        <button
          type="button"
          class="bookclub-pub-detail__nav-item {{if (eq this.activeTab 'chapters') 'bookclub-pub-detail__nav-item--active'}}"
          {{on "click" this.showChapters}}
        >
          {{icon "list-ul"}}
          Chapters
        </button>
        <button
          type="button"
          class="bookclub-pub-detail__nav-item {{if (eq this.activeTab 'stats') 'bookclub-pub-detail__nav-item--active'}}"
          {{on "click" this.showStats}}
        >
          {{icon "chart-bar"}}
          Statistics
        </button>
        <button
          type="button"
          class="bookclub-pub-detail__nav-item {{if (eq this.activeTab 'settings') 'bookclub-pub-detail__nav-item--active'}}"
          {{on "click" this.showSettings}}
        >
          {{icon "gear"}}
          Settings
        </button>
      </nav>

      <div class="bookclub-pub-detail__content">
        {{#if (eq this.activeTab "chapters")}}
          <BookclubChapterList
            @publicationSlug={{this.publication.slug}}
            @chapters={{this.publication.chapters}}
          />
        {{else if (eq this.activeTab "stats")}}
          <BookclubPublicationStats
            @publicationSlug={{this.publication.slug}}
            @analytics={{this.publication.analytics}}
          />
        {{else if (eq this.activeTab "settings")}}
          <BookclubPublicationSettings
            @publication={{this.publication}}
            @onUpdate={{this.handlePublicationUpdate}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
