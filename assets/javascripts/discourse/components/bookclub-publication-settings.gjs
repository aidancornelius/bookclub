import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";

/**
 * Publication settings component for editing metadata
 * @component BookclubPublicationSettings
 * @param {Object} args.publication - Publication data
 * @param {Function} args.onUpdate - Callback when publication is updated
 */
export default class BookclubPublicationSettings extends Component {
  @service bookclubAuthor;
  @service router;

  @tracked name = this.args.publication?.name || "";
  @tracked type = this.args.publication?.type || "book";
  @tracked slug = this.args.publication?.slug || "";
  @tracked description = this.args.publication?.description || "";
  @tracked coverUrl = this.args.publication?.cover_url || "";
  @tracked saving = false;
  @tracked saved = false;
  @tracked error = null;

  get hasChanges() {
    const pub = this.args.publication;
    return (
      this.name !== pub?.name ||
      this.type !== pub?.type ||
      this.slug !== pub?.slug ||
      this.description !== (pub?.description || "") ||
      this.coverUrl !== (pub?.cover_url || "")
    );
  }

  @action
  updateName(event) {
    this.name = event.target.value;
    this.saved = false;
  }

  @action
  updateType(event) {
    this.type = event.target.value;
    this.saved = false;
  }

  @action
  updateSlug(event) {
    this.slug = event.target.value;
    this.saved = false;
  }

  @action
  updateDescription(event) {
    this.description = event.target.value;
    this.saved = false;
  }

  @action
  updateCoverUrl(event) {
    this.coverUrl = event.target.value;
    this.saved = false;
  }

  @action
  onCoverUploadDone(upload) {
    this.coverUrl = upload.url;
    this.saved = false;
  }

  @action
  onCoverUploadDeleted() {
    this.coverUrl = "";
    this.saved = false;
  }

  @action
  async saveSettings() {
    this.saving = true;
    this.error = null;

    try {
      const currentSlug = this.args.publication.slug;
      const data = {
        name: this.name,
        type: this.type,
        description: this.description,
        cover_url: this.coverUrl,
      };

      // Only include new_slug if it changed
      if (this.slug !== currentSlug) {
        data.new_slug = this.slug;
      }

      const result = await this.bookclubAuthor.updatePublication(
        currentSlug,
        data
      );

      if (result.success) {
        this.saved = true;
        // If slug changed, redirect to new URL
        if (this.slug !== currentSlug) {
          this.router.transitionTo("bookclub-author-publication", this.slug);
        } else if (this.args.onUpdate) {
          this.args.onUpdate(result.publication);
        }
      }
    } catch (error) {
      console.error("Failed to save settings:", error);
      this.error = "Failed to save settings";
    } finally {
      this.saving = false;
    }
  }

  @action
  resetChanges() {
    const pub = this.args.publication;
    this.name = pub?.name || "";
    this.type = pub?.type || "book";
    this.slug = pub?.slug || "";
    this.description = pub?.description || "";
    this.coverUrl = pub?.cover_url || "";
    this.saved = false;
    this.error = null;
  }

  <template>
    <div class="bookclub-publication-settings">
      <div class="bookclub-settings-section">
        <h3 class="bookclub-settings-section__title">
          {{icon "gear"}}
          Publication settings
        </h3>

        {{#if this.error}}
          <div class="bookclub-settings-error">
            {{icon "triangle-exclamation"}}
            {{this.error}}
          </div>
        {{/if}}

        {{#if this.saved}}
          <div class="bookclub-settings-success">
            {{icon "check"}}
            Settings saved successfully
          </div>
        {{/if}}

        <div class="bookclub-form">
          <div class="bookclub-form-group">
            <label for="pub-name">Name</label>
            <input
              type="text"
              id="pub-name"
              value={{this.name}}
              {{on "input" this.updateName}}
              class="bookclub-input"
            />
          </div>

          <div class="bookclub-form-group">
            <label for="pub-type">Type</label>
            <select
              id="pub-type"
              {{on "change" this.updateType}}
              class="bookclub-select"
            >
              <option value="book" selected={{eq this.type "book"}}>
                Book
              </option>
              <option value="journal" selected={{eq this.type "journal"}}>
                Journal
              </option>
            </select>
          </div>

          <div class="bookclub-form-group">
            <label for="pub-slug">URL slug</label>
            <div class="bookclub-input-with-prefix">
              <span class="bookclub-input-prefix">/book/</span>
              <input
                type="text"
                id="pub-slug"
                value={{this.slug}}
                {{on "input" this.updateSlug}}
                class="bookclub-input"
              />
            </div>
            <p class="bookclub-form-hint">
              Changing the slug will update all URLs for this publication
            </p>
          </div>

          <div class="bookclub-form-group">
            <label for="pub-description">Description</label>
            <textarea
              id="pub-description"
              value={{this.description}}
              {{on "input" this.updateDescription}}
              class="bookclub-textarea"
              rows="3"
              placeholder="Brief description of this publication"
            ></textarea>
          </div>

          <div class="bookclub-form-group">
            <label>Cover image</label>
            <div class="bookclub-cover-uploader">
              <UppyImageUploader
                @id="bookclub-cover-uploader"
                @type="bookclub_cover"
                @imageUrl={{this.coverUrl}}
                @onUploadDone={{this.onCoverUploadDone}}
                @onUploadDeleted={{this.onCoverUploadDeleted}}
                @previewSize="cover"
              />
            </div>
            <p class="bookclub-form-hint">
              Recommended size: 600x900 pixels (2:3 aspect ratio)
            </p>
            <details class="bookclub-cover-url-fallback">
              <summary>Or enter image URL manually</summary>
              <input
                type="text"
                id="pub-cover"
                value={{this.coverUrl}}
                {{on "input" this.updateCoverUrl}}
                class="bookclub-input"
                placeholder="https://example.com/cover.jpg"
              />
            </details>
          </div>

          <div class="bookclub-form-actions">
            {{#if this.hasChanges}}
              <DButton
                @action={{this.resetChanges}}
                @label="cancel"
                class="btn-flat"
                @disabled={{this.saving}}
              />
            {{/if}}
            <DButton
              @action={{this.saveSettings}}
              @label="bookclub.author.save_settings"
              @icon="check"
              class="btn-primary"
              @disabled={{this.saving}}
            />
          </div>
        </div>
      </div>
    </div>
  </template>
}
