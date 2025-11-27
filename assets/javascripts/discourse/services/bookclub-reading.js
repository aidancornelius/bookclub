import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";
import ReadingProgressSync from "../lib/reading-progress-sync";
import SwipeNavigation from "../lib/swipe-navigation";

const STORE_NAMESPACE = "bookclub";

/**
 * Service for managing bookclub reading state and preferences
 * @class BookclubReadingService
 */
export default class BookclubReadingService extends Service {
  @service siteSettings;
  @service currentUser;
  @service capabilities;

  @tracked isReadingMode = false;
  @tracked isTocOpen = false;
  @tracked isSettingsOpen = false;
  @tracked isShortcutsOpen = false;
  @tracked scrollProgress = 0;
  @tracked currentPublication = null;
  @tracked currentContent = null;
  @tracked completedContentIds = [];
  @tracked chaptersProgress = {};
  @tracked readingStreak = null;

  store = new KeyValueStore(STORE_NAMESPACE);
  progressSync = null;
  swipeNavigation = null;

  /**
   * Get the user's preferred font size
   * @returns {string} Font size preference (small, medium, large, x-large)
   */
  get fontSize() {
    return (
      this.store.get("fontSize") ||
      this.siteSettings.bookclub_default_font_size ||
      "medium"
    );
  }

  /**
   * Set the user's preferred font size
   * @param {string} size - The font size to set
   */
  set fontSize(size) {
    this.store.set("fontSize", size);
    this._applyFontSize(size);
  }

  /**
   * Get the user's dark mode preference
   * @returns {boolean} Whether dark mode is enabled
   */
  get isDarkMode() {
    const stored = this.store.get("darkMode");
    if (stored !== null && stored !== undefined) {
      return stored === "true" || stored === true;
    }
    // Default to system preference
    return (
      window.matchMedia &&
      window.matchMedia("(prefers-color-scheme: dark)").matches
    );
  }

  /**
   * Set the user's dark mode preference
   * @param {boolean} enabled - Whether dark mode should be enabled
   */
  set isDarkMode(enabled) {
    this.store.set("darkMode", enabled);
    this._applyDarkMode(enabled);
  }

  /**
   * Initialise reading mode for a publication topic
   * @param {Object} publication - The publication category data
   * @param {Object} content - The current content/chapter data
   */
  async enterReadingMode(publication, content) {
    this.isReadingMode = true;
    this.currentPublication = publication;
    this.currentContent = content;

    // Initialise progress sync
    this.progressSync = new ReadingProgressSync(
      publication.slug,
      content.id,
      content.number,
      this.currentUser
    );

    // Load and restore reading progress
    await this._loadAndRestoreProgress();

    // Auto-bookmark the current reading position (logged in users only)
    this._autoBookmarkReadingPosition(content);

    document.body.classList.add("bookclub-reading-mode");
    this._applyFontSize(this.fontSize);
    this._applyDarkMode(this.isDarkMode);
    this._setupScrollTracking();
    this._setupKeyboardShortcuts();
    this._setupSwipeNavigation();
  }

  /**
   * Exit reading mode
   */
  exitReadingMode() {
    this.isReadingMode = false;
    this.currentPublication = null;
    this.currentContent = null;
    this.progressSync = null;

    document.body.classList.remove(
      "bookclub-reading-mode",
      "bookclub-font-small",
      "bookclub-font-medium",
      "bookclub-font-large",
      "bookclub-font-x-large"
    );

    this._teardownScrollTracking();
    this._teardownKeyboardShortcuts();
    this._teardownSwipeNavigation();
  }

  /**
   * Toggle the table of contents sidebar
   */
  toggleToc() {
    this.isTocOpen = !this.isTocOpen;
    if (this.isTocOpen) {
      this.isSettingsOpen = false;
    }
  }

  /**
   * Toggle the settings panel
   */
  toggleSettings() {
    this.isSettingsOpen = !this.isSettingsOpen;
    if (this.isSettingsOpen) {
      this.isTocOpen = false;
    }
  }

  /**
   * Toggle the keyboard shortcuts help
   */
  toggleShortcuts() {
    this.isShortcutsOpen = !this.isShortcutsOpen;
  }

  /**
   * Toggle dark mode
   */
  toggleDarkMode() {
    this.isDarkMode = !this.isDarkMode;
  }

  /**
   * Update scroll progress
   * @param {number} progress - Progress value between 0 and 100
   */
  updateScrollProgress(progress) {
    this.scrollProgress = progress;

    // Save progress via sync (debounced)
    if (this.progressSync) {
      const scrollOffset = window.scrollY;
      this.progressSync.saveProgress(progress, scrollOffset);
    }
  }

  /**
   * Check if content is completed
   * @param {number} contentId - Content ID to check
   * @returns {boolean} Whether content is completed
   */
  isContentCompleted(contentId) {
    return this.completedContentIds.includes(contentId);
  }

  /**
   * Get progress status for content (unread, in-progress, completed)
   * @param {number} contentId - Content ID to check
   * @param {number} contentNumber - Content number
   * @returns {string} Status: 'completed', 'in-progress', or 'unread'
   */
  getContentStatus(contentId, contentNumber) {
    // Check per-chapter progress first
    const chapterProgress = this.chaptersProgress[contentId];
    if (chapterProgress) {
      if (chapterProgress.completed) {
        return "completed";
      }
      if (chapterProgress.scrollPosition > 0) {
        return "in-progress";
      }
    }

    // Fallback to legacy completed array
    if (this.isContentCompleted(contentId)) {
      return "completed";
    }

    // Check if this is the current/last read content
    if (
      this.currentContent &&
      (this.currentContent.id === contentId ||
        this.currentContent.number === contentNumber)
    ) {
      return "in-progress";
    }

    return "unread";
  }

  /**
   * Navigate to the previous chapter
   */
  navigatePrevious() {
    const prevLink = document.querySelector(
      ".bookclub-chapter-nav__link--prev"
    );
    if (prevLink) {
      prevLink.click();
    }
  }

  /**
   * Navigate to the next chapter
   */
  navigateNext() {
    const nextLink = document.querySelector(
      ".bookclub-chapter-nav__link--next"
    );
    if (nextLink) {
      nextLink.click();
    }
  }

  /**
   * Scroll to the discussion section
   */
  scrollToDiscussion() {
    const discussionSection = document.querySelector(
      ".bookclub-chapter-discussions"
    );
    if (discussionSection) {
      discussionSection.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    }
  }

  /**
   * Apply font size class to body
   * @private
   * @param {string} size - The font size to apply
   */
  _applyFontSize(size) {
    document.body.classList.remove(
      "bookclub-font-small",
      "bookclub-font-medium",
      "bookclub-font-large",
      "bookclub-font-x-large"
    );
    document.body.classList.add(`bookclub-font-${size}`);
  }

  /**
   * Apply dark mode
   * @private
   * @param {boolean} enabled - Whether dark mode should be enabled
   */
  _applyDarkMode(enabled) {
    if (enabled) {
      document.documentElement.setAttribute("data-theme", "dark");
      document.body.classList.add("dark-mode");
    } else {
      document.documentElement.removeAttribute("data-theme");
      document.body.classList.remove("dark-mode");
    }
  }

  /**
   * Load and restore reading progress
   * @private
   */
  async _loadAndRestoreProgress() {
    if (!this.progressSync) {
      return;
    }

    try {
      const progress = await this.progressSync.loadProgress();

      // Update completed content IDs
      this.completedContentIds = progress.completed || [];

      // Update per-chapter progress
      this.chaptersProgress = progress.chapters || {};

      // Load reading streak if user is logged in
      if (this.currentUser) {
        await this._loadReadingStreak();
      }

      // Restore scroll position if returning to the same chapter
      if (
        this.currentContent &&
        (progress.contentId === this.currentContent.id ||
          progress.contentNumber === this.currentContent.number)
      ) {
        // Use requestAnimationFrame to ensure DOM is ready
        requestAnimationFrame(() => {
          if (progress.scrollOffset > 0) {
            window.scrollTo(0, progress.scrollOffset);
          }
        });
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to load reading progress:", error);
    }
  }

  /**
   * Load reading streak data from server
   * @private
   */
  async _loadReadingStreak() {
    if (!this.currentUser) {
      return;
    }

    try {
      const { ajax } = await import("discourse/lib/ajax");
      const response = await ajax("/bookclub/reading-streak");
      this.readingStreak = response.streak;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to load reading streak:", error);
    }
  }

  /**
   * Auto-bookmark the reading position (replaces any existing reading bookmark)
   * @private
   * @param {Object} content - The current content/chapter data
   */
  async _autoBookmarkReadingPosition(content) {
    if (!this.currentUser) {
      return;
    }

    // Need the content_topic_id to create the bookmark
    const topicId = content.content_topic_id;
    if (!topicId) {
      return;
    }

    try {
      const { ajax } = await import("discourse/lib/ajax");
      await ajax("/bookclub/reading-bookmark.json", {
        method: "POST",
        data: { topic_id: topicId },
      });
    } catch (error) {
      // Silently fail - auto-bookmarking is not critical
      // eslint-disable-next-line no-console
      console.log("Failed to auto-bookmark reading position:", error);
    }
  }

  /**
   * Set up scroll tracking for progress bar
   * @private
   */
  _setupScrollTracking() {
    this._scrollHandler = () => {
      const windowHeight = window.innerHeight;
      const documentHeight = document.documentElement.scrollHeight;
      const scrollTop = window.scrollY;
      const scrollable = documentHeight - windowHeight;

      if (scrollable > 0) {
        const progress = Math.min(
          100,
          Math.max(0, (scrollTop / scrollable) * 100)
        );
        this.updateScrollProgress(progress);
      }
    };

    window.addEventListener("scroll", this._scrollHandler, { passive: true });

    // Trigger initial scroll calculation
    this._scrollHandler();
  }

  /**
   * Tear down scroll tracking
   * @private
   */
  _teardownScrollTracking() {
    if (this._scrollHandler) {
      window.removeEventListener("scroll", this._scrollHandler);
      this._scrollHandler = null;
    }
  }

  /**
   * Set up keyboard shortcuts
   * @private
   */
  _setupKeyboardShortcuts() {
    this._keyHandler = (event) => {
      // Ignore if typing in an input
      if (
        event.target.tagName === "INPUT" ||
        event.target.tagName === "TEXTAREA" ||
        event.target.isContentEditable
      ) {
        return;
      }

      switch (event.key) {
        case "?":
          event.preventDefault();
          this.toggleShortcuts();
          break;
        case "t":
          event.preventDefault();
          this.toggleToc();
          break;
        case "s":
          event.preventDefault();
          this.toggleSettings();
          break;
        case "d":
          event.preventDefault();
          this.scrollToDiscussion();
          break;
        case "n":
        case "ArrowRight":
          if (!event.metaKey && !event.ctrlKey) {
            event.preventDefault();
            this.navigateNext();
          }
          break;
        case "p":
        case "ArrowLeft":
          if (!event.metaKey && !event.ctrlKey) {
            event.preventDefault();
            this.navigatePrevious();
          }
          break;
        case "Escape":
          if (this.isTocOpen || this.isSettingsOpen || this.isShortcutsOpen) {
            event.preventDefault();
            this.isTocOpen = false;
            this.isSettingsOpen = false;
            this.isShortcutsOpen = false;
          }
          break;
      }
    };

    document.addEventListener("keydown", this._keyHandler);
  }

  /**
   * Tear down keyboard shortcuts
   * @private
   */
  _teardownKeyboardShortcuts() {
    if (this._keyHandler) {
      document.removeEventListener("keydown", this._keyHandler);
      this._keyHandler = null;
    }
  }

  /**
   * Set up swipe navigation for mobile
   * @private
   */
  _setupSwipeNavigation() {
    // Only enable on touch devices
    if (!this.capabilities.touch) {
      return;
    }

    this.swipeNavigation = new SwipeNavigation({
      onSwipeLeft: () => {
        this.navigateNext();
      },
      onSwipeRight: () => {
        this.navigatePrevious();
      },
      threshold: 75, // Require 75px swipe to trigger
    });

    this.swipeNavigation.enable();
  }

  /**
   * Tear down swipe navigation
   * @private
   */
  _teardownSwipeNavigation() {
    if (this.swipeNavigation) {
      this.swipeNavigation.disable();
      this.swipeNavigation = null;
    }
  }
}
