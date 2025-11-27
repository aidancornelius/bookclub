import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";

/**
 * Book import modal with file upload and usage guide
 * @component BookclubImportModal
 * @param {Function} this.args.closeModal - Function to close the modal
 * @param {string} this.args.publicationSlug - Publication slug (for re-import mode)
 * @param {Function} this.args.onImportComplete - Callback after successful import
 */
export default class BookclubImportModal extends Component {
  @service bookclubAuthor;
  @service router;

  @tracked selectedFile = null;
  @tracked importing = false;
  @tracked error = null;
  @tracked result = null;
  @tracked showGuide = true;

  // Import options
  @tracked customSlug = "";
  @tracked publishImmediately = false;
  @tracked accessLevel = "free";
  @tracked replaceExisting = false;

  /**
   * Check if this is a re-import (updating existing publication)
   * @returns {boolean} True if re-importing
   */
  get isReimport() {
    return !!this.args.publicationSlug;
  }

  /**
   * Check if ready to import
   * @returns {boolean} True if file is selected
   */
  get canImport() {
    return this.selectedFile && !this.importing;
  }

  /**
   * Handle file selection
   * @param {Event} event - File input change event
   */
  @action
  handleFileSelect(event) {
    const file = event.target.files[0];
    if (file) {
      this.selectedFile = file;
      this.error = null;
      this.result = null;
    }
  }

  /**
   * Toggle guide visibility
   */
  @action
  toggleGuide() {
    this.showGuide = !this.showGuide;
  }

  /**
   * Update custom slug
   * @param {Event} event - Input event
   */
  @action
  updateSlug(event) {
    this.customSlug = event.target.value;
  }

  /**
   * Toggle publish immediately option
   */
  @action
  togglePublish() {
    this.publishImmediately = !this.publishImmediately;
  }

  /**
   * Toggle replace existing option
   */
  @action
  toggleReplace() {
    this.replaceExisting = !this.replaceExisting;
  }

  /**
   * Update access level
   * @param {Event} event - Select change event
   */
  @action
  updateAccessLevel(event) {
    this.accessLevel = event.target.value;
  }

  /**
   * Perform the import
   */
  @action
  async performImport() {
    if (!this.selectedFile) {
      return;
    }

    this.importing = true;
    this.error = null;
    this.result = null;

    try {
      let importResult;

      if (this.isReimport) {
        importResult = await this.bookclubAuthor.reimportBook(
          this.args.publicationSlug,
          this.selectedFile,
          {
            replaceExisting: this.replaceExisting,
            publish: this.publishImmediately,
            accessLevel: this.accessLevel,
          }
        );
      } else {
        importResult = await this.bookclubAuthor.importBook(this.selectedFile, {
          slug: this.customSlug || null,
          publish: this.publishImmediately,
          accessLevel: this.accessLevel,
        });
      }

      this.result = importResult;

      if (importResult.success && this.args.onImportComplete) {
        this.args.onImportComplete(importResult);
      }
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.errors?.join(", ") || "Import failed";
    } finally {
      this.importing = false;
    }
  }

  /**
   * Navigate to imported publication
   */
  @action
  viewPublication() {
    if (this.result?.publication?.slug) {
      this.args.closeModal();
      this.router.transitionTo(
        "bookclub-author-publication",
        this.result.publication.slug
      );
    }
  }

  <template>
    <DModal
      @title={{if this.isReimport "Update publication from file" "Import book"}}
      @closeModal={{@closeModal}}
      class="bookclub-import-modal"
    >
      <:body>
        {{#if this.result}}
          <div
            class="bookclub-import-result
              {{if
                this.result.success
                'bookclub-import-result--success'
                'bookclub-import-result--error'
              }}"
          >
            {{#if this.result.success}}
              {{icon "circle-check"}}
              <div class="bookclub-import-result__content">
                <h3>Import successful</h3>
                <p>
                  <strong>{{this.result.publication.name}}</strong>
                </p>
                {{#if this.result.chapters_created.length}}
                  <p>Created
                    {{this.result.chapters_created.length}}
                    chapters</p>
                {{/if}}
                {{#if this.result.chapters_updated.length}}
                  <p>Updated
                    {{this.result.chapters_updated.length}}
                    chapters</p>
                {{/if}}
                {{#if this.result.errors.length}}
                  <details class="bookclub-import-warnings">
                    <summary>{{this.result.errors.length}} warnings</summary>
                    <ul>
                      {{#each this.result.errors as |err|}}
                        <li>{{err}}</li>
                      {{/each}}
                    </ul>
                  </details>
                {{/if}}
              </div>
            {{else}}
              {{icon "triangle-exclamation"}}
              <div class="bookclub-import-result__content">
                <h3>Import failed</h3>
                {{#each this.result.errors as |err|}}
                  <p>{{err}}</p>
                {{/each}}
              </div>
            {{/if}}
          </div>
        {{else}}
          <div class="bookclub-import-guide-toggle">
            <button
              type="button"
              class="btn-flat"
              {{on "click" this.toggleGuide}}
            >
              {{icon (if this.showGuide "chevron-up" "chevron-down")}}
              {{if this.showGuide "Hide" "Show"}}
              formatting guide
            </button>
          </div>

          {{#if this.showGuide}}
            <div class="bookclub-import-guide">
              <h3>Supported formats</h3>

              <div class="bookclub-import-format">
                <h4>{{icon "file-lines"}} Markdown (.md)</h4>
                <p>Use
                  <code># Chapter title</code>
                  headers to separate chapters.</p>
                <pre
                  class="bookclub-import-example"
                >---
title: My Book
author: Your Name
description: A great story
---

# Chapter 1: The Beginning

Your chapter content here...

# Chapter 2: The Middle

More content...</pre>
              </div>

              <div class="bookclub-import-format">
                <h4>{{icon "file-lines"}} Plain text (.txt)</h4>
                <p>Use
                  <code>CHAPTER I</code>
                  or
                  <code>CHAPTER 1</code>
                  markers.</p>
                <pre
                  class="bookclub-import-example"
                >TITLE: My Book
AUTHOR: Your Name

CHAPTER I.
The Beginning

Your chapter content here...

CHAPTER II.
The Middle

More content...</pre>
              </div>

              <div class="bookclub-import-format">
                <h4>{{icon "file-zipper"}}
                  TextBundle / TextPack (.textbundle, .textpack)</h4>
                <p>Used by writing apps like Ulysses, iA Writer, and Bear.
                  Upload the exported package directly.</p>
              </div>

              <div class="bookclub-import-format">
                <h4>{{icon "folder"}}
                  iA Writer style (folder with .md files)</h4>
                <p>Export as TextPack, or create an index file with content
                  blocks:</p>
                <pre
                  class="bookclub-import-example"
                >---
title: My Book
author: Your Name
---

/chapter-01.md
/chapter-02.md
/chapter-03.md</pre>
              </div>
            </div>
          {{/if}}

          <div class="bookclub-import-upload">
            <label for="book-file" class="bookclub-import-dropzone">
              {{#if this.selectedFile}}
                {{icon "file-check"}}
                <span
                  class="bookclub-import-filename"
                >{{this.selectedFile.name}}</span>
                <span class="bookclub-import-filesize">
                  ({{this.formatFileSize this.selectedFile.size}})
                </span>
              {{else}}
                {{icon "upload"}}
                <span>Click to select a file or drag and drop</span>
                <span class="bookclub-import-filetypes">.md, .txt, .textpack,
                  .zip</span>
              {{/if}}
            </label>
            <input
              type="file"
              id="book-file"
              accept=".md,.markdown,.txt,.textpack,.zip"
              {{on "change" this.handleFileSelect}}
              class="bookclub-import-input"
            />
          </div>

          {{#if this.selectedFile}}
            <div class="bookclub-import-options">
              <h4>Import options</h4>

              {{#unless this.isReimport}}
                <div class="bookclub-form-group">
                  <label for="import-slug">Custom URL slug (optional)</label>
                  <input
                    type="text"
                    id="import-slug"
                    value={{this.customSlug}}
                    {{on "input" this.updateSlug}}
                    placeholder="my-book"
                    class="bookclub-input"
                  />
                  <span class="bookclub-form-hint">
                    Leave blank to auto-generate from title
                  </span>
                </div>
              {{/unless}}

              {{#if this.isReimport}}
                <div class="bookclub-form-group bookclub-form-group--checkbox">
                  <label>
                    <input
                      type="checkbox"
                      checked={{this.replaceExisting}}
                      {{on "change" this.toggleReplace}}
                    />
                    Replace existing chapters with matching titles/numbers
                  </label>
                  <span class="bookclub-form-hint">
                    If unchecked, existing chapters will be skipped
                  </span>
                </div>
              {{/if}}

              <div class="bookclub-form-group bookclub-form-group--checkbox">
                <label>
                  <input
                    type="checkbox"
                    checked={{this.publishImmediately}}
                    {{on "change" this.togglePublish}}
                  />
                  Publish chapters immediately
                </label>
                <span class="bookclub-form-hint">
                  If unchecked, chapters will be imported as drafts
                </span>
              </div>

              <div class="bookclub-form-group">
                <label for="import-access">Default access level</label>
                <select
                  id="import-access"
                  {{on "change" this.updateAccessLevel}}
                  class="bookclub-select"
                >
                  <option value="free" selected>Free</option>
                  <option value="member">Members only</option>
                  <option value="supporter">Supporters</option>
                  <option value="patron">Patrons</option>
                </select>
              </div>
            </div>
          {{/if}}

          {{#if this.error}}
            <div class="bookclub-import-error">
              {{icon "triangle-exclamation"}}
              {{this.error}}
            </div>
          {{/if}}
        {{/if}}
      </:body>
      <:footer>
        {{#if this.result.success}}
          <DButton @action={{@closeModal}} @label="close" class="btn-flat" />
          <DButton
            @action={{this.viewPublication}}
            @label="bookclub.import.view_publication"
            @icon="book-open"
            class="btn-primary"
          />
        {{else}}
          <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
          <DButton
            @action={{this.performImport}}
            @label={{if
              this.isReimport
              "bookclub.import.update"
              "bookclub.import.import"
            }}
            @icon={{if this.importing "spinner" "upload"}}
            @disabled={{if this.canImport false true}}
            class="btn-primary"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>

  formatFileSize(bytes) {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }
}
