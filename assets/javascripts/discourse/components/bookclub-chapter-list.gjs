import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import BookclubChapterEditor from "./bookclub-chapter-editor";

/**
 * Chapter list component with drag-and-drop reordering
 * @component BookclubChapterList
 */
export default class BookclubChapterList extends Component {
  @service bookclubAuthor;
  @service dialog;

  @tracked contents = this.args.chapters || [];
  @tracked isDragging = false;
  @tracked draggedItem = null;
  @tracked hasOrderChanged = false;
  @tracked showChapterEditor = false;
  @tracked editingChapter = null;

  /**
   * Set up drag-and-drop handlers for a chapter item
   * @param {HTMLElement} element - The chapter list item element
   * @param {Array} positional - Positional arguments [content]
   */
  setupDraggable = modifier((element, [content]) => {
    element.draggable = true;

    const handleDragStart = (event) => {
      this.draggedItem = content;
      this.isDragging = true;
      element.classList.add("dragging");
      event.dataTransfer.effectAllowed = "move";
      event.dataTransfer.setData("text/html", element.innerHTML);
    };

    const handleDragEnd = () => {
      this.isDragging = false;
      this.draggedItem = null;
      element.classList.remove("dragging");
      // Mark order as changed so save button stays visible
      this.hasOrderChanged = true;
    };

    const handleDragOver = (event) => {
      if (!this.isDragging) {
        return;
      }
      event.preventDefault();
      event.dataTransfer.dropEffect = "move";

      const afterElement = this.getDragAfterElement(
        element.parentElement,
        event.clientY
      );
      const draggingElement = document.querySelector(".dragging");

      if (afterElement == null) {
        element.parentElement.appendChild(draggingElement);
      } else {
        element.parentElement.insertBefore(draggingElement, afterElement);
      }
    };

    element.addEventListener("dragstart", handleDragStart);
    element.addEventListener("dragend", handleDragEnd);
    element.addEventListener("dragover", handleDragOver);

    return () => {
      element.removeEventListener("dragstart", handleDragStart);
      element.removeEventListener("dragend", handleDragEnd);
      element.removeEventListener("dragover", handleDragOver);
    };
  });

  /**
   * Get the element after which the dragged element should be placed
   * @param {HTMLElement} container - Container element
   * @param {number} y - Y coordinate
   * @returns {HTMLElement|null} Element to insert before, or null for end
   */
  getDragAfterElement(container, y) {
    const draggableElements = [
      ...container.querySelectorAll(".bookclub-chapter-item:not(.dragging)"),
    ];

    return draggableElements.reduce(
      (closest, child) => {
        const box = child.getBoundingClientRect();
        const offset = y - box.top - box.height / 2;

        if (offset < 0 && offset > closest.offset) {
          return { offset, element: child };
        } else {
          return closest;
        }
      },
      { offset: Number.NEGATIVE_INFINITY }
    ).element;
  }

  /**
   * Save the new order after drag-and-drop
   */
  @action
  async saveOrder() {
    const items = document.querySelectorAll(".bookclub-chapter-item");
    const order = Array.from(items).map((item, index) => ({
      id: parseInt(item.dataset.contentId, 10),
      number: index + 1,
    }));

    try {
      await this.bookclubAuthor.reorderContents(
        this.args.publicationSlug,
        order
      );
      // Update local state
      this.contents = this.contents
        .map((content) => {
          const newOrder = order.find((o) => o.id === content.id);
          return { ...content, number: newOrder.number };
        })
        .sort((a, b) => a.number - b.number);
      // Reset the changed flag after successful save
      this.hasOrderChanged = false;
    } catch {
      // Error already shown by service
    }
  }

  /**
   * Edit a chapter
   * @param {Object} content - Content object
   */
  @action
  editChapter(content) {
    // Navigate to topic page for editing
    if (content.content_topic_id) {
      window.location.href = `/t/${content.content_topic_id}`;
    }
  }

  /**
   * Toggle published status
   * @param {Object} content - Content object
   */
  @action
  async togglePublished(content) {
    try {
      const result = await this.bookclubAuthor.togglePublished(
        this.args.publicationSlug,
        content.number,
        !content.published
      );

      // Update local state
      if (result.success && result.chapter) {
        const index = this.contents.findIndex((c) => c.id === content.id);
        if (index !== -1) {
          this.contents[index] = result.chapter;
          // Force re-render
          this.contents = [...this.contents];
        }
      }
    } catch {
      // Error already shown by service
    }
  }

  /**
   * Delete a chapter
   * @param {Object} content - Content object
   */
  @action
  async deleteChapter(content) {
    const result = await this.dialog.confirm({
      message: `Are you sure you want to delete "${content.title}"? This cannot be undone.`,
      confirmButtonLabel: "bookclub.author.delete_chapter",
      cancelButtonLabel: "cancel",
      confirmButtonClass: "btn-danger",
    });

    if (result) {
      try {
        await this.bookclubAuthor.deleteContent(
          this.args.publicationSlug,
          content.number
        );

        // Remove from local state
        this.contents = this.contents.filter((c) => c.id !== content.id);
      } catch {
        // Error already shown by service
      }
    }
  }

  /**
   * Open chapter editor modal
   */
  @action
  openChapterEditor() {
    this.editingChapter = null;
    this.showChapterEditor = true;
  }

  /**
   * Close chapter editor modal
   */
  @action
  closeChapterEditor() {
    this.showChapterEditor = false;
    this.editingChapter = null;
  }

  /**
   * Handle chapter created/updated
   * @param {Object} content - New or updated content
   */
  @action
  handleChapterSaved(content) {
    const index = this.contents.findIndex((c) => c.id === content.id);
    if (index !== -1) {
      this.contents[index] = content;
    } else {
      this.contents = [...this.contents, content];
    }
    this.closeChapterEditor();
  }

  /**
   * Get status badge class
   * @param {Object} content - Content object
   * @returns {string} CSS class name
   */
  getStatusBadgeClass(content) {
    if (content.published) {
      return "bookclub-badge--published";
    }
    return "bookclub-badge--draft";
  }

  /**
   * Format word count for display
   * @param {number} count - Word count
   * @returns {string} Formatted count
   */
  formatWordCount(count) {
    if (!count) {
      return "0";
    }
    return count.toLocaleString();
  }

  <template>
    <div class="bookclub-chapter-list">
      <div class="bookclub-chapter-list__header">
        <h2 class="bookclub-chapter-list__title">
          {{icon "list-ul"}}
          Chapters
        </h2>
        <DButton
          @action={{this.openChapterEditor}}
          @label="bookclub.author.new_chapter"
          @icon="plus"
          class="btn-primary"
        />
      </div>

      {{#if this.contents.length}}
        <div class="bookclub-chapter-list__items">
          {{#each this.contents as |content|}}
            <div
              class="bookclub-chapter-item"
              data-content-id={{content.id}}
              {{this.setupDraggable content}}
            >
              <div class="bookclub-chapter-item__drag-handle">
                {{icon "grip-vertical"}}
              </div>

              <div class="bookclub-chapter-item__number">
                {{content.number}}
              </div>

              <div class="bookclub-chapter-item__content">
                <div class="bookclub-chapter-item__title">
                  {{content.title}}
                </div>

                <div class="bookclub-chapter-item__meta">
                  <span class="bookclub-chapter-item__meta-item">
                    {{icon "file-lines"}}
                    {{this.formatWordCount content.word_count}}
                    words
                  </span>
                  <span class="bookclub-chapter-item__meta-item">
                    {{icon "eye"}}
                    {{content.views}}
                    views
                  </span>
                  <span class="bookclub-chapter-item__meta-item">
                    {{icon "comment"}}
                    {{content.posts_count}}
                    comments
                  </span>
                </div>
              </div>

              <div class="bookclub-chapter-item__badges">
                <span
                  class="bookclub-badge {{this.getStatusBadgeClass content}}"
                >
                  {{#if content.published}}
                    {{icon "check-circle"}}
                    Published
                  {{else}}
                    {{icon "file"}}
                    Draft
                  {{/if}}
                </span>

                {{#if content.access_level}}
                  <span class="bookclub-badge bookclub-badge--access">
                    {{icon "lock"}}
                    {{content.access_level}}
                  </span>
                {{/if}}
              </div>

              <div class="bookclub-chapter-item__actions">
                <DButton
                  @action={{fn this.editChapter content}}
                  @icon="pencil"
                  @title="Edit chapter"
                  class="btn-flat btn-icon"
                />

                <DButton
                  @action={{fn this.togglePublished content}}
                  @icon={{if content.published "eye-slash" "eye"}}
                  @title={{if content.published "Unpublish" "Publish"}}
                  class="btn-flat btn-icon"
                />

                <DButton
                  @action={{fn this.deleteChapter content}}
                  @icon="trash-can"
                  @title="Delete chapter"
                  class="btn-flat btn-icon btn-danger"
                />
              </div>
            </div>
          {{/each}}
        </div>

        {{#if this.hasOrderChanged}}
          <div class="bookclub-chapter-list__save-order">
            <DButton
              @action={{this.saveOrder}}
              @label="bookclub.author.save_order"
              @icon="floppy-disk"
              class="btn-primary"
            />
          </div>
        {{/if}}
      {{else}}
        <div class="bookclub-chapter-list__empty">
          {{icon "book"}}
          <p>No chapters yet. Create your first chapter to get started.</p>
        </div>
      {{/if}}
    </div>

    {{#if this.showChapterEditor}}
      <DModal
        @closeModal={{this.closeChapterEditor}}
        @title={{if this.editingChapter "Edit chapter" "New chapter"}}
      >
        <:body>
          <BookclubChapterEditor
            @publicationSlug={{@publicationSlug}}
            @chapter={{this.editingChapter}}
            @onSave={{this.handleChapterSaved}}
            @onCancel={{this.closeChapterEditor}}
          />
        </:body>
      </DModal>
    {{/if}}
  </template>
}
