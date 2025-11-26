import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";

/**
 * Reader progress component for author dashboard
 * Shows reading completion statistics
 * @component BookclubReaderProgress
 * @param {Object} this.args.analytics - Analytics data from publication
 */
export default class BookclubReaderProgress extends Component {
  /**
   * Calculate progress bar width percentage
   * @param {number} started - Number who started
   * @param {number} completed - Number who completed
   * @returns {number} Percentage for completed
   */
  calculateProgressWidth(started, completed) {
    if (started === 0) {
      return 0;
    }
    return Math.round((completed / started) * 100);
  }

  <template>
    <div class="bookclub-reader-progress">
      <div class="bookclub-reader-progress__header">
        <h3 class="bookclub-reader-progress__title">
          {{icon "users"}}
          Reader progress
        </h3>
      </div>

      <div class="bookclub-reader-progress__summary">
        <div class="bookclub-reader-progress__stat">
          <div class="bookclub-reader-progress__stat-value">
            {{@analytics.reader_progress.total_readers}}
          </div>
          <div class="bookclub-reader-progress__stat-label">
            Total readers
          </div>
        </div>

        <div class="bookclub-reader-progress__stat">
          <div class="bookclub-reader-progress__stat-value">
            {{@analytics.reader_progress.completed_readers}}
          </div>
          <div class="bookclub-reader-progress__stat-label">
            Completed
          </div>
        </div>

        <div class="bookclub-reader-progress__stat">
          <div class="bookclub-reader-progress__stat-value">
            {{@analytics.reader_progress.average_progress}}%
          </div>
          <div class="bookclub-reader-progress__stat-label">
            Average progress
          </div>
        </div>
      </div>

      {{#if @analytics.reader_progress.by_chapter.length}}
        <div class="bookclub-reader-progress__chapters">
          <h4 class="bookclub-reader-progress__subtitle">
            Progress by chapter
          </h4>

          <div class="bookclub-reader-progress__chapter-list">
            {{#each @analytics.reader_progress.by_chapter as |chapter|}}
              <div class="bookclub-reader-progress__chapter-item">
                <div class="bookclub-reader-progress__chapter-header">
                  <span class="bookclub-reader-progress__chapter-title">
                    Chapter
                    {{chapter.number}}: {{chapter.title}}
                  </span>
                  <span class="bookclub-reader-progress__chapter-stats">
                    {{chapter.completed}}/{{chapter.started}}
                    ({{chapter.completion_rate}}%)
                  </span>
                </div>

                <div class="bookclub-reader-progress__progress-bar">
                  <div
                    class="bookclub-reader-progress__progress-fill"
                    style="width: {{this.calculateProgressWidth
                        chapter.started
                        chapter.completed
                      }}%"
                  ></div>
                </div>
              </div>
            {{/each}}
          </div>
        </div>
      {{else}}
        <div class="bookclub-reader-progress__empty">
          {{icon "book-open"}}
          <p>No reader data yet. Progress will appear as readers engage with
            your content.</p>
        </div>
      {{/if}}
    </div>
  </template>
}
