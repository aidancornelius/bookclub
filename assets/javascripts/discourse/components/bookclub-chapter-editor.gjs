import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import { i18n } from "discourse-i18n";
import ComboBox from "discourse/select-kit/components/combo-box";

/**
 * Chapter editor modal for creating and editing chapters
 * @component BookclubChapterEditor
 * @param {string} this.args.publicationSlug - Publication slug
 * @param {Object} this.args.chapter - Existing chapter to edit (optional)
 * @param {number} this.args.nextNumber - Next chapter number for new chapters
 * @param {Function} this.args.onSave - Callback when chapter is saved
 * @param {Function} this.args.onCancel - Callback when editing is cancelled
 */
export default class BookclubChapterEditor extends Component {
  @service bookclubAuthor;

  @tracked title = this.args.chapter?.title || "";
  @tracked body = this.args.chapter?.body || "";
  @tracked contentType = this.args.chapter?.type || "chapter";
  @tracked accessLevel = this.args.chapter?.access_level || "free";
  @tracked summary = this.args.chapter?.summary || "";
  @tracked saving = false;
  @tracked errors = [];
  markdownOptions = { lookup_topic: false };

  contentTypeOptions = [
    { id: "chapter", name: "Chapter" },
    { id: "article", name: "Article" },
    { id: "essay", name: "Essay" },
    { id: "review", name: "Review" },
  ];

accessLevelOptions = [
    { id: "free", name: "Free" },
    { id: "community", name: "Community" },
    { id: "reader", name: "Reader" },
    { id: "member", name: "Member" },
    { id: "supporter", name: "Supporter" },
    { id: "patron", name: "Patron" },
  ];

/**
   * Get placeholder title based on content type and number
   * @returns {string} Placeholder title
   */
  get placeholderTitle() {
    const number = this.args.nextNumber || "";
    const type = this.contentType === "article" ? "Article" : "Chapter";
    return `${type} ${number}`;
  }

  

  

  /**
   * Update title
   * @param {Event} event - Input event
   */
  @action
  updateTitle(event) {
    this.title = event.target.value;
  }

  /**
   * Update body
   * @param {Event} event - Input event
   */
  @action
  updateBody(value) {
    this.body = value || "";
  }

  /**
   * Update summary
   * @param {Event} event - Input event
   */
  @action
  updateSummary(event) {
    this.summary = event.target.value;
  }

  /**
   * Update content type
   * @param {string} value - Selected content type
   */
  @action
  updateContentType(value) {
    this.contentType = value;
  }

  /**
   * Update access level
   * @param {string} value - Selected access level
   */
  @action
  updateAccessLevel(value) {
    this.accessLevel = value;
  }

  /**
   * Validate form data
   * @returns {boolean} True if valid
   */
  validate() {
    this.errors = [];

    // Title is optional for new chapters (server will generate default)
    // but required when editing existing chapters
    if (this.args.chapter && (!this.title || this.title.trim().length === 0)) {
      this.errors.push("Title is required");
    }

    if (!this.body || this.body.trim().length === 0) {
      this.errors.push("Content is required");
    }

    return this.errors.length === 0;
  }

  /**
   * Save the chapter
   */
  @action
  async save() {
    if (!this.validate()) {
      return;
    }

    this.saving = true;
    this.errors = [];

    try {
      const data = {
        title: this.title.trim() || undefined, // Server will generate default if undefined
        body: this.body.trim(),
        content_type: this.contentType,
        access_level: this.accessLevel,
        summary: this.summary.trim(),
      };

      const result = await this.bookclubAuthor.createContent(
        this.args.publicationSlug,
        data
      );

      if (result.success && result.chapter) {
        this.args.onSave?.(result.chapter);
      } else if (result.errors) {
        this.errors = result.errors;
      }
    } catch (error) {
      console.error("Failed to save chapter:", error);
      // Error already shown by service
    } finally {
      this.saving = false;
    }
  }

  /**
   * Cancel editing
   */
  @action
  cancel() {
    this.args.onCancel?.();
  }

  <template>
    <div class="bookclub-chapter-editor">
      {{#if this.errors.length}}
        <div class="bookclub-chapter-editor__errors">
          {{#each this.errors as |error|}}
            <div class="alert alert-error">{{error}}</div>
          {{/each}}
        </div>
      {{/if}}

      <div class="bookclub-chapter-editor__form">
        <div class="bookclub-chapter-editor__field">
          <label class="bookclub-chapter-editor__label">
            Title
            {{#unless this.args.chapter}}
              <span class="bookclub-chapter-editor__hint">
                (Leave blank for default: "{{this.placeholderTitle}}")
              </span>
            {{/unless}}
          </label>
          <input
            type="text"
            value={{this.title}}
            {{on "input" this.updateTitle}}
            placeholder={{this.placeholderTitle}}
            class="bookclub-chapter-editor__input"
          />
        </div>

        <div class="bookclub-chapter-editor__field">
          <label class="bookclub-chapter-editor__label">
            Content type
          </label>
          <ComboBox
            @value={{this.contentType}}
            @content={{this.contentTypeOptions}}
            @onChange={{this.updateContentType}}
            class="bookclub-chapter-editor__select"
          />
        </div>

        <div class="bookclub-chapter-editor__field">
          <label class="bookclub-chapter-editor__label">
            Access level
          </label>
          <ComboBox
            @value={{this.accessLevel}}
            @content={{this.accessLevelOptions}}
            @onChange={{this.updateAccessLevel}}
            class="bookclub-chapter-editor__select"
          />
        </div>

        <div class="bookclub-chapter-editor__field">
          <label class="bookclub-chapter-editor__label">
            Summary
          </label>
          <textarea
            value={{this.summary}}
            {{on "input" this.updateSummary}}
            placeholder="Brief summary or excerpt (optional)"
            rows="3"
            class="bookclub-chapter-editor__textarea"
          />
        </div>

        <div class="bookclub-chapter-editor__field">
          <label class="bookclub-chapter-editor__label">
            {{i18n "bookclub.author.content_label"}}
            <span class="required">*</span>
          </label>
          <DEditor
            @value={{this.body}}
            @change={{this.updateBody}}
            @placeholder={{i18n "bookclub.author.content_placeholder"}}
            @markdownOptions={{this.markdownOptions}}
          />
        </div>
      </div>

      <div class="bookclub-chapter-editor__actions">
        <DButton
          @action={{this.cancel}}
          @label="bookclub.actions.cancel"
          @disabled={{this.saving}}
          class="btn-default"
        />
        <DButton
          @action={{this.save}}
          @label={{if
            this.saving
            "bookclub.author.saving"
            "bookclub.author.create_chapter"
          }}
          @disabled={{this.saving}}
          @icon="floppy-disk"
          class="btn-primary"
        />
      </div>
    </div>
  </template>
}
