import { ajax } from "discourse/lib/ajax";
import { debounce } from "discourse/lib/decorators";

const DEBOUNCE_MS = 30000; // 30 seconds as per requirements
const COMPLETION_THRESHOLD = 0.95; // 95% scrolled = completed

/**
 * Manages synchronisation of reading progress to localStorage and server
 * Handles offline gracefully by queueing updates
 */
export default class ReadingProgressSync {
  /**
   * @param {string} publicationSlug - Publication identifier
   * @param {number} contentId - Content/chapter ID
   * @param {number} contentNumber - Content/chapter number
   * @param {Object} currentUser - Current user object (null if anonymous)
   */
  constructor(publicationSlug, contentId, contentNumber, currentUser) {
    this.publicationSlug = publicationSlug;
    this.contentId = contentId;
    this.contentNumber = contentNumber;
    this.currentUser = currentUser;
    this.localStorageKey = `bookclub_progress_${publicationSlug}`;
  }

  /**
   * Load reading progress from localStorage or server
   * @returns {Promise<Object>} Progress data including scroll position and completed chapters
   */
  async loadProgress() {
    // Always load from localStorage first for instant restore
    const localProgress = this._loadFromLocalStorage();

    // If logged in, fetch from server and merge
    if (this.currentUser) {
      try {
        const serverProgress = await this._loadFromServer();
        return this._mergeProgress(localProgress, serverProgress);
      } catch (error) {
        // Gracefully handle offline/errors, use local data
        // eslint-disable-next-line no-console
        console.warn("Failed to load progress from server, using local:", error);
        return localProgress;
      }
    }

    return localProgress;
  }

  /**
   * Save reading progress (debounced)
   * @param {number} scrollPosition - Scroll position as percentage (0-100)
   * @param {number} scrollOffset - Actual scroll pixel offset
   */
  @debounce(DEBOUNCE_MS)
  saveProgress(scrollPosition, scrollOffset) {
    this._doSaveProgress(scrollPosition, scrollOffset);
  }

  /**
   * Save reading progress immediately (bypasses debounce)
   * Call this when exiting reading mode to ensure progress is saved
   * @param {number} scrollPosition - Scroll position as percentage (0-100)
   * @param {number} scrollOffset - Actual scroll pixel offset
   */
  saveProgressNow(scrollPosition, scrollOffset) {
    this._doSaveProgress(scrollPosition, scrollOffset);
  }

  /**
   * Internal save progress implementation
   * @private
   */
  _doSaveProgress(scrollPosition, scrollOffset) {
    const progress = {
      publicationSlug: this.publicationSlug,
      contentId: this.contentId,
      contentNumber: this.contentNumber,
      scrollPosition,
      scrollOffset,
      lastReadAt: new Date().toISOString(),
    };

    // Determine if chapter is completed based on scroll percentage
    const isCompleted = scrollPosition >= COMPLETION_THRESHOLD * 100;

    // Save to localStorage immediately
    this._saveToLocalStorage(progress, isCompleted);

    // Save to server if logged in
    if (this.currentUser) {
      this._saveToServer(progress, isCompleted).catch((error) => {
        // Gracefully handle offline/errors
        // eslint-disable-next-line no-console
        console.warn("Failed to save progress to server:", error);
      });
    }
  }

  /**
   * Get progress for specific chapter from stored data
   * @param {number} chapterId - Chapter ID to get progress for
   * @returns {Object|null} Chapter progress or null
   */
  getChapterProgress(chapterId) {
    const progress = this._loadFromLocalStorage();
    const chapters = progress.chapters || {};
    return chapters[chapterId] || null;
  }

  /**
   * Check if chapter is in-progress (has scroll position but not completed)
   * @param {number} chapterId - Chapter ID to check
   * @returns {boolean} Whether chapter is in-progress
   */
  isChapterInProgress(chapterId) {
    const chapterProgress = this.getChapterProgress(chapterId);
    if (!chapterProgress) {
      return false;
    }
    return (
      chapterProgress.scrollPosition > 0 &&
      chapterProgress.scrollPosition < COMPLETION_THRESHOLD * 100 &&
      !chapterProgress.completed
    );
  }

  /**
   * Mark a chapter as completed
   * @param {number} contentId - Content ID to mark complete
   */
  async markCompleted(contentId) {
    const localProgress = this._loadFromLocalStorage();
    if (!localProgress.completed) {
      localProgress.completed = [];
    }
    if (!localProgress.completed.includes(contentId)) {
      localProgress.completed.push(contentId);
      this._saveToLocalStorage(localProgress, false);
    }

    if (this.currentUser) {
      try {
        await ajax(`/bookclub/reading-progress/${this.publicationSlug}`, {
          type: "PUT",
          data: { mark_completed: contentId },
        });
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn("Failed to mark completed on server:", error);
      }
    }
  }

  /**
   * Get progress for a specific content item
   * @param {number} contentId - Content ID to get progress for
   * @returns {Object|null} Progress data or null if none
   */
  getContentProgress(contentId) {
    const progress = this._loadFromLocalStorage();
    if (
      progress.contentId === contentId ||
      progress.contentNumber === contentId
    ) {
      return {
        scrollOffset: progress.scrollOffset || 0,
        scrollPosition: progress.scrollPosition || 0,
        isCompleted: (progress.completed || []).includes(contentId),
      };
    }
    return null;
  }

  /**
   * Check if content is completed
   * @param {number} contentId - Content ID to check
   * @returns {boolean} Whether content is completed
   */
  isContentCompleted(contentId) {
    const progress = this._loadFromLocalStorage();
    return (progress.completed || []).includes(contentId);
  }

  /**
   * Get list of completed content IDs
   * @returns {Array<number>} Array of completed content IDs
   */
  getCompletedContentIds() {
    const progress = this._loadFromLocalStorage();
    return progress.completed || [];
  }

  /**
   * Load progress from localStorage
   * @private
   * @returns {Object} Progress object
   */
  _loadFromLocalStorage() {
    try {
      const stored = localStorage.getItem(this.localStorageKey);
      if (stored) {
        return JSON.parse(stored);
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to parse localStorage progress:", error);
    }
    return {
      completed: [],
      contentId: null,
      contentNumber: null,
      scrollPosition: 0,
      scrollOffset: 0,
      chapters: {},
    };
  }

  /**
   * Save progress to localStorage
   * @private
   * @param {Object} progress - Progress data to save
   * @param {boolean} markCompleted - Whether to mark current content as completed
   */
  _saveToLocalStorage(progress, markCompleted) {
    const existing = this._loadFromLocalStorage();

    // Initialise chapters object if it doesn't exist
    if (!existing.chapters) {
      existing.chapters = {};
    }

    // Update per-chapter progress
    const chapterId = this.contentId.toString();
    existing.chapters[chapterId] = {
      scrollPosition: progress.scrollPosition,
      scrollOffset: progress.scrollOffset,
      readAt: progress.lastReadAt,
      completed: markCompleted || existing.chapters[chapterId]?.completed || false,
      completedAt:
        markCompleted ? progress.lastReadAt : existing.chapters[chapterId]?.completedAt,
    };

    const updated = {
      ...existing,
      contentId: progress.contentId,
      contentNumber: progress.contentNumber,
      scrollPosition: progress.scrollPosition,
      scrollOffset: progress.scrollOffset,
      lastReadAt: progress.lastReadAt,
    };

    if (markCompleted && !updated.completed.includes(this.contentId)) {
      updated.completed.push(this.contentId);
    }

    try {
      localStorage.setItem(this.localStorageKey, JSON.stringify(updated));
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to save to localStorage:", error);
    }
  }

  /**
   * Load progress from server
   * @private
   * @returns {Promise<Object>} Server progress data
   */
  async _loadFromServer() {
    const response = await ajax(
      `/bookclub/reading-progress/${this.publicationSlug}`,
      {
        type: "GET",
      }
    );

    // Transform per-chapter progress from server format
    const chapters = {};
    if (response.progress?.chapters) {
      Object.keys(response.progress.chapters).forEach((chapterId) => {
        const chapterData = response.progress.chapters[chapterId];
        chapters[chapterId] = {
          scrollPosition: chapterData.scroll_position || 0,
          scrollOffset: 0, // Server doesn't store pixel offset
          readAt: chapterData.read_at,
          completed: chapterData.completed || false,
          completedAt: chapterData.completed_at,
        };
      });
    }

    return {
      contentId: response.progress?.current_content_id,
      contentNumber: response.progress?.current_content_number,
      scrollPosition: response.progress?.scroll_position || 0,
      scrollOffset: 0, // Server doesn't store pixel offset
      completed: response.progress?.completed || [],
      lastReadAt: response.progress?.last_read_at,
      chapters,
    };
  }

  /**
   * Save progress to server
   * @private
   * @param {Object} progress - Progress data
   * @param {boolean} markCompleted - Whether to mark current content as completed
   * @returns {Promise<void>}
   */
  async _saveToServer(progress, markCompleted) {
    const data = {
      current_content_id: progress.contentId,
      current_content_number: progress.contentNumber,
      scroll_position: progress.scrollPosition,
      content_id: this.contentId, // For per-chapter tracking
    };

    if (markCompleted) {
      data.mark_completed = this.contentId;
    }

    await ajax(`/bookclub/reading-progress/${this.publicationSlug}`, {
      type: "PUT",
      data,
    });
  }

  /**
   * Merge local and server progress, preferring most recent
   * @private
   * @param {Object} localProgress - Local progress data
   * @param {Object} serverProgress - Server progress data
   * @returns {Object} Merged progress
   */
  _mergeProgress(localProgress, serverProgress) {
    const localDate = localProgress.lastReadAt
      ? new Date(localProgress.lastReadAt)
      : new Date(0);
    const serverDate = serverProgress.lastReadAt
      ? new Date(serverProgress.lastReadAt)
      : new Date(0);

    // Use whichever has the most recent read time
    const useServer = serverDate > localDate;

    // Merge per-chapter progress
    const mergedChapters = this._mergeChapters(
      localProgress.chapters || {},
      serverProgress.chapters || {}
    );

    return {
      contentId: useServer
        ? serverProgress.contentId
        : localProgress.contentId,
      contentNumber: useServer
        ? serverProgress.contentNumber
        : localProgress.contentNumber,
      scrollPosition: useServer
        ? serverProgress.scrollPosition
        : localProgress.scrollPosition,
      scrollOffset: localProgress.scrollOffset, // Only stored locally
      completed: this._mergeCompleted(
        localProgress.completed || [],
        serverProgress.completed || []
      ),
      lastReadAt: useServer ? serverProgress.lastReadAt : localProgress.lastReadAt,
      chapters: mergedChapters,
    };
  }

  /**
   * Merge completed arrays from local and server
   * @private
   * @param {Array<number>} localCompleted - Local completed IDs
   * @param {Array<number>} serverCompleted - Server completed IDs
   * @returns {Array<number>} Merged unique completed IDs
   */
  _mergeCompleted(localCompleted, serverCompleted) {
    const merged = new Set([...localCompleted, ...serverCompleted]);
    return Array.from(merged);
  }

  /**
   * Merge per-chapter progress from local and server
   * @private
   * @param {Object} localChapters - Local chapters progress
   * @param {Object} serverChapters - Server chapters progress
   * @returns {Object} Merged chapters progress
   */
  _mergeChapters(localChapters, serverChapters) {
    const merged = { ...localChapters };

    // Merge server chapters, preferring most recent
    Object.keys(serverChapters).forEach((chapterId) => {
      const serverChapter = serverChapters[chapterId];
      const localChapter = localChapters[chapterId];

      if (!localChapter) {
        merged[chapterId] = serverChapter;
        return;
      }

      const localDate = localChapter.readAt
        ? new Date(localChapter.readAt)
        : new Date(0);
      const serverDate = serverChapter.readAt
        ? new Date(serverChapter.readAt)
        : new Date(0);

      // Use most recent chapter progress
      if (serverDate > localDate) {
        merged[chapterId] = {
          ...serverChapter,
          scrollOffset: localChapter.scrollOffset, // Preserve local scroll offset
        };
      } else {
        // Keep local but merge completed status (once completed, always completed)
        merged[chapterId] = {
          ...localChapter,
          completed: localChapter.completed || serverChapter.completed,
          completedAt: localChapter.completedAt || serverChapter.completedAt,
        };
      }
    });

    return merged;
  }
}
