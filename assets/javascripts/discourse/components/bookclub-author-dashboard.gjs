import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import BookclubImportModal from "./bookclub-import-modal";

/**
 * Author dashboard component showing all publications the user can manage
 * @component BookclubAuthorDashboard
 */
export default class BookclubAuthorDashboard extends Component {
  @service router;
  @service bookclubAuthor;

  @tracked publications = this.args.publications || [];
  @tracked canCreate = this.args.canCreate || false;
  @tracked loading = false;
  @tracked error = null;
  @tracked showCreateModal = false;
  @tracked newPublicationName = "";
  @tracked newPublicationType = "book";
  @tracked creating = false;
  @tracked showImportModal = false;

  /**
   * Check if publication has any published content
   * @param {Object} publication - Publication object
   * @returns {boolean} True if publication has published content
   */
  hasPublishedContent = (publication) => {
    return publication.published_count > 0;
  };

  /**
   * Get content label (chapters/articles)
   * @param {Object} publication - Publication object
   * @returns {string} Label
   */
  getContentLabel = (publication) => {
    return publication.type === "journal" ? "articles" : "chapters";
  };

  /**
   * Navigate to publication detail page
   * @param {Object} publication - Publication object
   */
  @action
  viewPublication(publication) {
    this.router.transitionTo("bookclub-author-publication", publication.slug);
  }

  /**
   * Navigate to the publication's public page
   * @param {Object} publication - Publication object
   */
  @action
  viewPublicPage(publication) {
    window.location.href = `/book/${publication.slug}`;
  }

  /**
   * Open the create publication modal
   */
  @action
  openCreateModal() {
    this.showCreateModal = true;
    this.newPublicationName = "";
    this.newPublicationType = "book";
  }

  /**
   * Close the create publication modal
   */
  @action
  closeCreateModal() {
    this.showCreateModal = false;
  }

  /**
   * Update new publication name
   * @param {Event} event - Input event
   */
  @action
  updateName(event) {
    this.newPublicationName = event.target.value;
  }

  /**
   * Update new publication type
   * @param {Event} event - Select event
   */
  @action
  updateType(event) {
    this.newPublicationType = event.target.value;
  }

  /**
   * Create a new publication
   */
  @action
  async createPublication() {
    if (!this.newPublicationName.trim()) {
      return;
    }

    this.creating = true;
    try {
      const result = await this.bookclubAuthor.createPublication({
        name: this.newPublicationName,
        type: this.newPublicationType,
      });

      if (result.success) {
        this.publications = [...this.publications, result.publication];
        this.showCreateModal = false;
        this.router.transitionTo(
          "bookclub-author-publication",
          result.publication.slug
        );
      }
    } finally {
      this.creating = false;
    }
  }

  /**
   * Open the import modal
   */
  @action
  openImportModal() {
    this.showImportModal = true;
  }

  /**
   * Close the import modal
   */
  @action
  closeImportModal() {
    this.showImportModal = false;
  }

  /**
   * Handle import completion
   * @param {Object} result - Import result
   */
  @action
  handleImportComplete(result) {
    if (result.success && result.publication) {
      this.publications = [...this.publications, result.publication];
    }
  }

  <template>
    <div class="bookclub-author-dashboard">
      <header class="bookclub-dashboard-header">
        <div class="bookclub-dashboard-header__content">
          <h1 class="bookclub-dashboard-header__title">
            Your publications
          </h1>
          {{#if this.canCreate}}
            <div class="bookclub-dashboard-header__actions">
              <DButton
                @action={{this.openImportModal}}
                @label="bookclub.author.import_book"
                @icon="upload"
                class="btn-default"
              />
              <DButton
                @action={{this.openCreateModal}}
                @label="bookclub.author.new_publication"
                @icon="plus"
                class="btn-primary"
              />
            </div>
          {{/if}}
        </div>
      </header>

      {{#if this.loading}}
        <div class="bookclub-dashboard-loading">
          {{icon "spinner" class="spinner"}}
          <span>Loading...</span>
        </div>
      {{else if this.error}}
        <div class="bookclub-dashboard-error">
          {{icon "triangle-exclamation"}}
          {{this.error}}
        </div>
      {{else if this.publications.length}}
        <div class="bookclub-dashboard-grid">
          {{#each this.publications as |publication|}}
            <article
              class="bookclub-pub-card
                {{unless
                  (this.hasPublishedContent publication)
                  'bookclub-pub-card--draft'
                }}"
              role="button"
              {{on "click" (fn this.viewPublication publication)}}
            >
              <div class="bookclub-pub-card__main">
                <div class="bookclub-pub-card__header">
                  <h2 class="bookclub-pub-card__title">
                    {{publication.name}}
                  </h2>
                  <span class="bookclub-pub-card__type">
                    {{publication.type}}
                  </span>
                </div>

                <div class="bookclub-pub-card__summary">
                  <span class="bookclub-pub-card__count">
                    {{publication.published_count}}
                    <span
                      class="bookclub-pub-card__count-label"
                    >published</span>
                  </span>
                  {{#if publication.draft_count}}
                    <span
                      class="bookclub-pub-card__count bookclub-pub-card__count--muted"
                    >
                      {{publication.draft_count}}
                      <span class="bookclub-pub-card__count-label">drafts</span>
                    </span>
                  {{/if}}
                </div>

                {{#unless (this.hasPublishedContent publication)}}
                  <div class="bookclub-pub-card__status">
                    {{icon "far-eye-slash"}}
                    <span>Not visible to readers</span>
                  </div>
                {{/unless}}
              </div>

              <div class="bookclub-pub-card__footer">
                <DButton
                  @action={{fn this.viewPublication publication}}
                  @label="bookclub.author.manage"
                  @icon="gear"
                  class="btn-primary btn-small"
                />
                {{#if (this.hasPublishedContent publication)}}
                  <DButton
                    @action={{fn this.viewPublicPage publication}}
                    @icon="link"
                    @title="View public page"
                    class="btn-flat btn-icon-text"
                  />
                {{/if}}
              </div>
            </article>
          {{/each}}
        </div>
      {{else}}
        <div class="bookclub-dashboard-empty">
          {{icon "book"}}
          <h2>No publications yet</h2>
          {{#if this.canCreate}}
            <p>Create your first publication to get started.</p>
            <DButton
              @action={{this.openCreateModal}}
              @label="bookclub.author.new_publication"
              @icon="plus"
              class="btn-primary"
            />
          {{else}}
            <p>Contact an administrator to create a publication.</p>
          {{/if}}
        </div>
      {{/if}}

      {{#if this.showCreateModal}}
        <DModal
          @title="New publication"
          @closeModal={{this.closeCreateModal}}
          class="bookclub-create-modal"
        >
          <:body>
            <div class="bookclub-form-group">
              <label for="publication-name">Name</label>
              <input
                type="text"
                id="publication-name"
                value={{this.newPublicationName}}
                {{on "input" this.updateName}}
                placeholder="Enter publication name"
                class="bookclub-input"
              />
            </div>
            <div class="bookclub-form-group">
              <label for="publication-type">Type</label>
              <select
                id="publication-type"
                {{on "change" this.updateType}}
                class="bookclub-select"
              >
                <option
                  value="book"
                  selected={{eq this.newPublicationType "book"}}
                >
                  Book
                </option>
                <option
                  value="journal"
                  selected={{eq this.newPublicationType "journal"}}
                >
                  Journal
                </option>
              </select>
            </div>
          </:body>
          <:footer>
            <DButton
              @action={{this.closeCreateModal}}
              @label="cancel"
              class="btn-flat"
            />
            <DButton
              @action={{this.createPublication}}
              @label="bookclub.author.create"
              @icon="plus"
              @disabled={{this.creating}}
              class="btn-primary"
            />
          </:footer>
        </DModal>
      {{/if}}

      {{#if this.showImportModal}}
        <BookclubImportModal
          @closeModal={{this.closeImportModal}}
          @onImportComplete={{this.handleImportComplete}}
        />
      {{/if}}
    </div>
  </template>
}
