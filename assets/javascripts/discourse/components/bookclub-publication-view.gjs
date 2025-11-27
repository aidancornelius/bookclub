import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { gt } from "discourse/truth-helpers";
import I18n from "discourse-i18n";

/**
 * Helper to format word count with k suffix for thousands
 * @param {number} count - Word count
 * @returns {string} Formatted word count
 */
function formatWordCount(count) {
  if (!count) {
    return "0";
  }
  if (count >= 1000) {
    return `${Math.round(count / 1000)}k`;
  }
  return count.toString();
}

/**
 * Public view component for displaying a publication to readers
 * @component BookclubPublicationView
 * @param {Object} publication - Publication data
 * @param {Array} toc - Table of contents
 * @param {boolean} hasAccess - Whether user has access
 * @param {boolean} isAuthor - Whether user is author
 * @param {boolean} isEditor - Whether user is editor
 */
export default class BookclubPublicationView extends Component {
  get firstChapter() {
    const toc = this.args.toc || [];
    return toc.find((item) => item.has_access || item.is_free);
  }

  get startReadingUrl() {
    const first = this.firstChapter;
    if (first) {
      return `/book/${this.args.publication.slug}/${first.slug}`;
    }
    return null;
  }

  get canManage() {
    return this.args.isAuthor || this.args.isEditor;
  }

  <template>
    <div class="bookclub-publication-view">
      <div class="bookclub-publication-view__header">
        {{#if @publication.cover_url}}
          <div class="bookclub-publication-view__cover">
            <img src={{@publication.cover_url}} alt={{@publication.name}} />
          </div>
        {{else}}
          <div
            class="bookclub-publication-view__cover bookclub-publication-view__cover--placeholder"
          >
            {{icon "book-open"}}
          </div>
        {{/if}}

        <div class="bookclub-publication-view__info">
          <span class="bookclub-publication-view__type">
            {{@publication.type}}
          </span>
          <h1 class="bookclub-publication-view__title">
            {{@publication.name}}
          </h1>

          {{#if @publication.authors}}
            <div class="bookclub-publication-view__authors">
              {{I18n.t "bookclub.library.by"}}
              {{#each @publication.authors as |author|}}
                <span class="bookclub-publication-view__author">
                  {{author.name}}
                </span>
              {{/each}}
            </div>
          {{/if}}

          {{#if @publication.description}}
            <p class="bookclub-publication-view__description">
              {{@publication.description}}
            </p>
          {{/if}}

          <div class="bookclub-publication-view__meta">
            {{#if (gt @publication.chapter_count 0)}}
              <span>
                {{icon "list-ul"}}
                {{@publication.chapter_count}}
                {{I18n.t "bookclub.library.chapters"}}
              </span>
            {{/if}}
            {{#if (gt @publication.total_word_count 0)}}
              <span>
                {{icon "text-height"}}
                {{formatWordCount @publication.total_word_count}}
                {{I18n.t "bookclub.library.words"}}
              </span>
            {{/if}}
          </div>

          <div class="bookclub-publication-view__actions">
            {{#if this.startReadingUrl}}
              <a
                href={{this.startReadingUrl}}
                class="btn btn-primary bookclub-publication-view__cta"
              >
                {{icon "book-open"}}
                {{I18n.t "bookclub.publication.start_reading"}}
              </a>
            {{/if}}

            {{#if this.canManage}}
              <a
                href="/bookclub/author/{{@publication.slug}}"
                class="btn btn-default"
              >
                {{icon "gear"}}
                {{I18n.t "bookclub.author.manage"}}
              </a>
            {{/if}}
          </div>
        </div>
      </div>

      <div class="bookclub-publication-view__toc">
        <h2>
          {{icon "list-ul"}}
          {{I18n.t "bookclub.publication.toc_title"}}
        </h2>

        {{#if @toc}}
          <ol class="bookclub-publication-view__toc-list">
            {{#each @toc as |item|}}
              <li
                class="bookclub-publication-view__toc-item
                  {{if
                    item.has_access
                    ''
                    'bookclub-publication-view__toc-item--locked'
                  }}"
              >
                {{#if item.has_access}}
                  <a
                    href="/book/{{@publication.slug}}/{{item.slug}}"
                    class="bookclub-publication-view__toc-link"
                  >
                    <span class="bookclub-publication-view__toc-number">
                      {{item.number}}.
                    </span>
                    <span class="bookclub-publication-view__toc-title">
                      {{item.title}}
                    </span>
                    {{#if item.is_free}}
                      <span class="bookclub-publication-view__toc-badge">
                        {{I18n.t "bookclub.content.free"}}
                      </span>
                    {{/if}}
                  </a>
                {{else}}
                  <span class="bookclub-publication-view__toc-link">
                    <span class="bookclub-publication-view__toc-number">
                      {{item.number}}.
                    </span>
                    <span class="bookclub-publication-view__toc-title">
                      {{item.title}}
                    </span>
                    <span class="bookclub-publication-view__toc-badge--locked">
                      {{icon "lock"}}
                      {{I18n.t "bookclub.content.locked"}}
                    </span>
                  </span>
                {{/if}}
              </li>
            {{/each}}
          </ol>
        {{else}}
          <p class="bookclub-publication-view__toc-empty">
            {{I18n.t "bookclub.author.no_chapters"}}
          </p>
        {{/if}}
      </div>
    </div>
  </template>
}
