/**
 * Swipe navigation handler for mobile chapter navigation
 * Detects horizontal swipes and triggers chapter navigation
 * Shows hint on first use
 */
export default class SwipeNavigation {
  /**
   * @param {Object} options - Configuration options
   * @param {Function} options.onSwipeLeft - Callback when swiping left (next)
   * @param {Function} options.onSwipeRight - Callback when swiping right (previous)
   * @param {number} options.threshold - Minimum swipe distance in pixels (default: 50)
   * @param {number} options.maxVertical - Maximum vertical movement for horizontal swipe (default: 100)
   */
  constructor(options = {}) {
    this.onSwipeLeft = options.onSwipeLeft || (() => {});
    this.onSwipeRight = options.onSwipeRight || (() => {});
    this.threshold = options.threshold || 50;
    this.maxVertical = options.maxVertical || 100;

    this.touchStartX = 0;
    this.touchStartY = 0;
    this.touchEndX = 0;
    this.touchEndY = 0;

    this.hintElement = null;
    this.hintTimeout = null;

    this._handleTouchStart = this._handleTouchStart.bind(this);
    this._handleTouchMove = this._handleTouchMove.bind(this);
    this._handleTouchEnd = this._handleTouchEnd.bind(this);
  }

  /**
   * Enable swipe detection
   */
  enable() {
    document.addEventListener("touchstart", this._handleTouchStart, {
      passive: true,
    });
    document.addEventListener("touchmove", this._handleTouchMove, {
      passive: true,
    });
    document.addEventListener("touchend", this._handleTouchEnd, {
      passive: true,
    });

    // Show hint on first use
    this._showHintIfFirstTime();
  }

  /**
   * Disable swipe detection
   */
  disable() {
    document.removeEventListener("touchstart", this._handleTouchStart);
    document.removeEventListener("touchmove", this._handleTouchMove);
    document.removeEventListener("touchend", this._handleTouchEnd);

    // Clean up hint
    this._hideHint();
  }

  /**
   * Handle touch start event
   * @private
   * @param {TouchEvent} event - Touch event
   */
  _handleTouchStart(event) {
    // Ignore if touching interactive elements
    if (this._isInteractiveElement(event.target)) {
      return;
    }

    this.touchStartX = event.changedTouches[0].screenX;
    this.touchStartY = event.changedTouches[0].screenY;
  }

  /**
   * Handle touch move event
   * @private
   * @param {TouchEvent} event - Touch event
   */
  _handleTouchMove(event) {
    this.touchEndX = event.changedTouches[0].screenX;
    this.touchEndY = event.changedTouches[0].screenY;
  }

  /**
   * Handle touch end event
   * @private
   * @param {TouchEvent} event - Touch event
   */
  _handleTouchEnd(event) {
    // Ignore if touching interactive elements
    if (this._isInteractiveElement(event.target)) {
      return;
    }

    this._detectSwipe();
  }

  /**
   * Detect and handle swipe gesture
   * @private
   */
  _detectSwipe() {
    const deltaX = this.touchEndX - this.touchStartX;
    const deltaY = Math.abs(this.touchEndY - this.touchStartY);

    // Check if horizontal swipe
    if (
      Math.abs(deltaX) > this.threshold &&
      deltaY < this.maxVertical
    ) {
      if (deltaX > 0) {
        // Swipe right (previous)
        this.onSwipeRight();
      } else {
        // Swipe left (next)
        this.onSwipeLeft();
      }

      // Mark that user has used swipe
      this._markSwipeUsed();
    }
  }

  /**
   * Check if element is interactive (button, link, input, etc.)
   * @private
   * @param {Element} element - Element to check
   * @returns {boolean} Whether element is interactive
   */
  _isInteractiveElement(element) {
    if (!element) {
      return false;
    }

    const tagName = element.tagName.toLowerCase();
    const interactiveTags = ["a", "button", "input", "textarea", "select"];

    if (interactiveTags.includes(tagName)) {
      return true;
    }

    // Check if element or parent has click handler
    if (
      element.onclick ||
      element.getAttribute("role") === "button" ||
      element.closest("button, a, [role='button']")
    ) {
      return true;
    }

    return false;
  }

  /**
   * Show swipe hint if this is the first time user is reading
   * @private
   */
  _showHintIfFirstTime() {
    const hasSeenHint = localStorage.getItem("bookclub_swipe_hint_seen");

    if (!hasSeenHint) {
      this.hintTimeout = setTimeout(() => {
        this._showHint();
      }, 2000); // Show hint after 2 seconds
    }
  }

  /**
   * Show swipe hint
   * @private
   */
  _showHint() {
    // Create hint element if it doesn't exist
    if (!this.hintElement) {
      this.hintElement = document.createElement("div");
      this.hintElement.className = "bookclub-swipe-hint";
      this.hintElement.textContent = "Swipe left or right to navigate chapters";
      document.body.appendChild(this.hintElement);
    }

    // Show hint
    setTimeout(() => {
      this.hintElement.classList.add("bookclub-swipe-hint--visible");
    }, 10);

    // Hide hint after 4 seconds
    setTimeout(() => {
      this._hideHint();
    }, 4000);
  }

  /**
   * Hide swipe hint
   * @private
   */
  _hideHint() {
    if (this.hintTimeout) {
      clearTimeout(this.hintTimeout);
      this.hintTimeout = null;
    }

    if (this.hintElement) {
      this.hintElement.classList.remove("bookclub-swipe-hint--visible");
      setTimeout(() => {
        if (this.hintElement) {
          this.hintElement.remove();
          this.hintElement = null;
        }
      }, 300); // Match CSS transition duration
    }
  }

  /**
   * Mark that user has used swipe navigation
   * @private
   */
  _markSwipeUsed() {
    localStorage.setItem("bookclub_swipe_hint_seen", "true");
    this._hideHint();
  }
}
