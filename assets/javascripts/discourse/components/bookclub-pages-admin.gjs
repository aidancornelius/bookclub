import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DEditor from "discourse/components/d-editor";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";

/**
 * Admin interface for managing static pages
 */
export default class BookclubPagesAdmin extends Component {
  @service router;
  @service bookclubPages;
  @service dialog;

  @tracked pages = this.args.pages || [];
  @tracked showEditModal = false;
  @tracked editingPage = null;
  @tracked saving = false;

  // Form fields
  @tracked formTitle = "";
  @tracked formSlug = "";
  @tracked formRaw = "";
  @tracked formParentId = null;
  @tracked formNavPosition = "header";
  @tracked formVisible = true;
  @tracked formShowInNav = true;
  @tracked formIcon = "";
  @tracked formPosition = 0;
  markdownOptions = { lookup_topic: false };

  get topLevelPages() {
    return this.pages.filter((p) => !p.parent_id).sort((a, b) => a.position - b.position);
  }

  getChildPages = (parentId) => {
    return this.pages
      .filter((p) => p.parent_id === parentId)
      .sort((a, b) => a.position - b.position);
  };

  get availableParents() {
    // Only top-level pages can be parents (no nested dropdowns)
    return this.pages.filter((p) => !p.parent_id && p.id !== this.editingPage?.id);
  }

  @action
  openCreateModal() {
    this.editingPage = null;
    this.formTitle = "";
    this.formSlug = "";
    this.formRaw = "";
    this.formParentId = null;
    this.formNavPosition = "header";
    this.formVisible = true;
    this.formShowInNav = true;
    this.formIcon = "";
    this.formPosition = this.pages.length;
    this.showEditModal = true;
  }

  @action
  openEditModal(page) {
    this.editingPage = page;
    this.formTitle = page.title;
    this.formSlug = page.slug;
    this.formRaw = page.raw || "";
    this.formParentId = page.parent_id;
    this.formNavPosition = page.nav_position;
    this.formVisible = page.visible;
    this.formShowInNav = page.show_in_nav;
    this.formIcon = page.icon || "";
    this.formPosition = page.position;
    this.showEditModal = true;
  }

  @action
  closeEditModal() {
    this.showEditModal = false;
    this.editingPage = null;
  }

  @action
  updateFormField(field, event) {
    this[field] = event.target.value;
  }

  @action
  updateFormCheckbox(field, event) {
    this[field] = event.target.checked;
  }

  @action
  updateFormSelect(field, event) {
    const value = event.target.value;
    this[field] = value === "" ? null : value;
  }

  @action
  async savePage() {
    if (!this.formTitle.trim()) {
      return;
    }

    this.saving = true;
    try {
      const pageData = {
        title: this.formTitle,
        slug: this.formSlug || null,
        raw: this.formRaw,
        parent_id: this.formParentId,
        nav_position: this.formNavPosition,
        visible: this.formVisible,
        show_in_nav: this.formShowInNav,
        icon: this.formIcon || null,
        position: this.formPosition,
      };

      let result;
      if (this.editingPage) {
        result = await this.bookclubPages.updatePage(this.editingPage.slug, pageData);
        // Update in list
        const index = this.pages.findIndex((p) => p.id === this.editingPage.id);
        if (index !== -1) {
          this.pages = [
            ...this.pages.slice(0, index),
            result.page,
            ...this.pages.slice(index + 1),
          ];
        }
      } else {
        result = await this.bookclubPages.createPage(pageData);
        this.pages = [...this.pages, result.page];
      }

      this.closeEditModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async deletePage(page) {
    this.dialog.confirm({
      message: `Are you sure you want to delete "${page.title}"? This cannot be undone.`,
      didConfirm: async () => {
        try {
          await this.bookclubPages.deletePage(page.slug);
          this.pages = this.pages.filter((p) => p.id !== page.id);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  viewPage(page) {
    window.open(page.url, "_blank");
  }

  @action
  handleRawChange(value) {
    this.formRaw = value || "";
  }

  <template>
    <div class="bookclub-pages-admin">
      <header class="bookclub-dashboard-header">
        <div class="bookclub-dashboard-header__content">
          <h1 class="bookclub-dashboard-header__title">
            Pages dashboard
          </h1>
          <div class="bookclub-dashboard-header__actions">
            <DButton
              @action={{this.openCreateModal}}
              @label="bookclub.pages.new_page"
              @icon="plus"
              class="btn-primary"
            />
          </div>
        </div>
      </header>

      {{#if this.pages.length}}
        <div class="bookclub-pages-admin__list">
          {{#each this.topLevelPages as |page|}}
            <div class="bookclub-pages-admin__item {{unless page.visible 'bookclub-pages-admin__item--hidden'}}">
              <div class="bookclub-pages-admin__item-main">
                <div class="bookclub-pages-admin__item-info">
                  <div class="bookclub-pages-admin__item-meta">
                    <span class="bookclub-pages-admin__item-title">{{page.title}}</span>
                    <span class="bookclub-pages-admin__item-slug">/pages/{{page.slug}}</span>
                  </div>
                  {{#if page.has_children}}
                    <span class="bookclub-pages-admin__item-badge">dropdown</span>
                  {{/if}}
                  {{#unless page.visible}}
                    <span class="bookclub-pages-admin__item-badge bookclub-pages-admin__item-badge--hidden">hidden</span>
                  {{/unless}}
                  {{#unless page.show_in_nav}}
                    <span class="bookclub-pages-admin__item-badge">not in nav</span>
                  {{/unless}}
                </div>
                <div class="bookclub-pages-admin__item-actions">
                  <DButton
                    @action={{fn this.viewPage page}}
                    @icon="external-link-alt"
                    @title="View page"
                    class="btn-flat btn-icon"
                  />
                  <DButton
                    @action={{fn this.openEditModal page}}
                    @icon="pencil"
                    @title="Edit page"
                    class="btn-flat btn-icon"
                  />
                  <DButton
                    @action={{fn this.deletePage page}}
                    @icon="trash-can"
                    @title="Delete page"
                    class="btn-flat btn-icon btn-danger"
                  />
                </div>
              </div>

              {{#each (this.getChildPages page.id) as |childPage|}}
                <div class="bookclub-pages-admin__item bookclub-pages-admin__item--child {{unless childPage.visible 'bookclub-pages-admin__item--hidden'}}">
                  <div class="bookclub-pages-admin__item-main">
                    <div class="bookclub-pages-admin__item-info">
                      <div class="bookclub-pages-admin__item-meta">
                        <span class="bookclub-pages-admin__item-title">{{childPage.title}}</span>
                        <span class="bookclub-pages-admin__item-slug">/pages/{{childPage.slug}}</span>
                      </div>
                      {{#unless childPage.visible}}
                        <span class="bookclub-pages-admin__item-badge bookclub-pages-admin__item-badge--hidden">hidden</span>
                      {{/unless}}
                    </div>
                    <div class="bookclub-pages-admin__item-actions">
                      <DButton
                        @action={{fn this.viewPage childPage}}
                        @icon="external-link-alt"
                        @title="View page"
                        class="btn-flat btn-icon"
                      />
                      <DButton
                        @action={{fn this.openEditModal childPage}}
                        @icon="pencil"
                        @title="Edit page"
                        class="btn-flat btn-icon"
                      />
                      <DButton
                        @action={{fn this.deletePage childPage}}
                        @icon="trash-can"
                        @title="Delete page"
                        class="btn-flat btn-icon btn-danger"
                      />
                    </div>
                  </div>
                </div>
              {{/each}}
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="bookclub-pages-admin__empty bookclub-dashboard-empty">
          <h2>No pages yet</h2>
          <p>Create your first page to add content to your site navigation.</p>
        </div>
      {{/if}}

      {{#if this.showEditModal}}
        <DModal
          @title={{if this.editingPage "Edit page" "New page"}}
          @closeModal={{this.closeEditModal}}
          @submitOnEnter={{false}}
          class="bookclub-page-edit-modal"
        >
          <:body>
            <div class="bookclub-form-group">
              <label for="page-title">Title</label>
              <input
                type="text"
                id="page-title"
                value={{this.formTitle}}
                {{on "input" (fn this.updateFormField "formTitle")}}
                placeholder="Page title"
                class="bookclub-input"
              />
            </div>

            <div class="bookclub-form-group">
              <label for="page-slug">URL slug</label>
              <input
                type="text"
                id="page-slug"
                value={{this.formSlug}}
                {{on "input" (fn this.updateFormField "formSlug")}}
                placeholder="url-slug (auto-generated if blank)"
                class="bookclub-input"
              />
              <span class="bookclub-form-hint">Will be accessible at /pages/slug</span>
            </div>

            <div class="bookclub-form-group">
              <label for="page-content">Content</label>
              <DEditor
                @value={{this.formRaw}}
                @change={{this.handleRawChange}}
                @placeholder="Page content (Markdown supported)"
                @markdownOptions={{this.markdownOptions}}
              />
            </div>

            <div class="bookclub-form-row">
              <div class="bookclub-form-group">
                <label for="page-parent">Parent page (for dropdowns)</label>
                <select
                  id="page-parent"
                  {{on "change" (fn this.updateFormSelect "formParentId")}}
                  class="bookclub-select"
                >
                  <option value="" selected={{unless this.formParentId true}}>
                    None (top-level)
                  </option>
                  {{#each this.availableParents as |parent|}}
                    <option value={{parent.id}} selected={{if (this.isSelectedParent parent.id) true}}>
                      {{parent.title}}
                    </option>
                  {{/each}}
                </select>
              </div>

              <div class="bookclub-form-group">
                <label for="page-nav-position">Navigation position</label>
                <select
                  id="page-nav-position"
                  {{on "change" (fn this.updateFormSelect "formNavPosition")}}
                  class="bookclub-select"
                >
                  <option value="header" selected={{if (this.isNavPosition "header") true}}>Header</option>
                  <option value="footer" selected={{if (this.isNavPosition "footer") true}}>Footer</option>
                  <option value="none" selected={{if (this.isNavPosition "none") true}}>None</option>
                </select>
              </div>
            </div>

            <div class="bookclub-form-row">
              <div class="bookclub-form-group">
                <label for="page-icon">Icon (optional)</label>
                <input
                  type="text"
                  id="page-icon"
                  value={{this.formIcon}}
                  {{on "input" (fn this.updateFormField "formIcon")}}
                  placeholder="e.g., pen, book, info"
                  class="bookclub-input"
                />
                <span class="bookclub-form-hint">FontAwesome icon name</span>
              </div>

              <div class="bookclub-form-group">
                <label for="page-position">Position</label>
                <input
                  type="number"
                  id="page-position"
                  value={{this.formPosition}}
                  {{on "input" (fn this.updateFormField "formPosition")}}
                  class="bookclub-input"
                  min="0"
                />
              </div>
            </div>

            <div class="bookclub-form-row bookclub-form-checkboxes">
              <label class="bookclub-checkbox">
                <input
                  type="checkbox"
                  checked={{this.formVisible}}
                  {{on "change" (fn this.updateFormCheckbox "formVisible")}}
                />
                Visible
              </label>
              <label class="bookclub-checkbox">
                <input
                  type="checkbox"
                  checked={{this.formShowInNav}}
                  {{on "change" (fn this.updateFormCheckbox "formShowInNav")}}
                />
                Show in navigation
              </label>
            </div>
          </:body>
          <:footer>
            <DButton
              @action={{this.closeEditModal}}
              @label="cancel"
              class="btn-flat"
            />
            <DButton
              @action={{this.savePage}}
              @label={{if this.editingPage "bookclub.pages.save" "bookclub.pages.create"}}
              @icon={{if this.saving "spinner" "check"}}
              @disabled={{this.saving}}
              class="btn-primary"
            />
          </:footer>
        </DModal>
      {{/if}}
    </div>
  </template>

  isSelectedParent = (parentId) => {
    return String(this.formParentId) === String(parentId);
  };

  isNavPosition = (position) => {
    return this.formNavPosition === position;
  };
}
