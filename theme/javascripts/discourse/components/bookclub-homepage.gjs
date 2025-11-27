import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";

/**
 * Homepage component that showcases publications prominently
 * Renders above the standard discovery content when on homepage routes
 */
export default class BookclubHomepage extends Component {
  @service site;
  @service siteSettings;
  @service router;

  @tracked publications = [];
  @tracked allCategories = [];
  @tracked topicsByCategory = [];
  @tracked isLoading = true;
  @tracked topicsLoading = true;

  isPublication = (category) => {
    // A category is a "publication" if it has a cover image or is explicitly marked
    // Also check if it matches any loaded publication IDs
    const isInPublications = this.publications.some(
      (pub) => pub.id === category.id
    );
    return !!(
      isInPublications ||
      category.uploaded_logo?.url ||
      category.publication_enabled ||
      category.custom_fields?.publication_enabled
    );
  };

  getPublicationUrl = (publication) => {
    // API returns slug directly, fallback to other sources for category data
    const slug =
      publication.slug ||
      publication.publication_slug ||
      publication.custom_fields?.publication_slug;
    return `/book/${slug}`;
  };

  getCategoryUrl = (category) => {
    // Native Discourse category URL
    return `/c/${category.slug}/${category.id}`;
  };

  getPublicationType = (publication) => {
    // API returns type directly
    const type =
      publication.type ||
      publication.publication_type ||
      publication.custom_fields?.publication_type ||
      "publication";
    return type.charAt(0).toUpperCase() + type.slice(1);
  };

  getCoverStyle = (publication) => {
    // API returns cover_url directly
    const coverUrl =
      publication.cover_url ||
      publication.publication_cover_url ||
      publication.custom_fields?.publication_cover_url ||
      publication.uploaded_logo?.url;
    if (coverUrl) {
      return htmlSafe(`background-image: url(${coverUrl})`);
    }
    return null;
  };

  hasCover = (publication) => {
    return !!(
      publication.cover_url ||
      publication.publication_cover_url ||
      publication.custom_fields?.publication_cover_url ||
      publication.uploaded_logo?.url
    );
  };

  getDescription = (publication) => {
    // Prefer description_text (plain text) over description (which may contain HTML)
    return publication.description_text || publication.description || "";
  };

  getChapterCount = (publication) => {
    return publication.chapter_count || publication.topic_count || 0;
  };

  getCategoryColorStyle = (category) => {
    if (category.color) {
      return htmlSafe(`background-color: #${category.color}`);
    }
    return null;
  };

  getTopicUrl = (topic) => {
    return `/t/${topic.slug}/${topic.id}`;
  };

  formatRelativeTime = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) {
      return "just now";
    }
    if (diffMins < 60) {
      return `${diffMins}m`;
    }
    if (diffHours < 24) {
      return `${diffHours}h`;
    }
    if (diffDays < 30) {
      return `${diffDays}d`;
    }
    return date.toLocaleDateString();
  };

  constructor() {
    super(...arguments);
    this.loadPublications();
    this.loadCategories();
    this.loadTopicsGroupedByCategory();
  }

  get shouldShow() {
    // Only show on the actual homepage ("/"), not on /latest or other discovery routes
    // We check the URL path because route names like discovery.index get resolved
    // to discovery.latest when latest is the default homepage
    const currentUrl = this.router.currentURL;
    // Match exactly "/" or "/?" with optional query params
    const isHomepage = currentUrl === "/" || currentUrl.startsWith("/?");
    return isHomepage;
  }

  // Forums are non-publication categories (like General, Meta, etc.)
  get forums() {
    return this.allCategories.filter((cat) => !this.isPublication(cat));
  }

  get hasPublications() {
    return this.publications.length > 0;
  }

  get hasForums() {
    return this.forums.length > 0;
  }

  get siteName() {
    return this.siteSettings.title || "Library";
  }

  get siteDescription() {
    return this.siteSettings.short_site_description || "";
  }

  async loadPublications() {
    try {
      const response = await ajax("/bookclub/publications.json");
      this.publications = response.publications || [];
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to load publications:", error);
      this.publications = [];
    } finally {
      this.isLoading = false;
    }
  }

  async loadCategories() {
    try {
      const categories = this.site.categories || [];
      // Get all top-level categories that are NOT publications
      const topLevel = categories.filter((cat) => !cat.parent_category_id);

      this.allCategories = topLevel.sort(
        (a, b) => (b.topic_count || 0) - (a.topic_count || 0)
      );
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to load categories:", error);
    }
  }

  async loadTopicsGroupedByCategory() {
    try {
      const response = await ajax("/latest.json?order=activity");
      const topics = response.topic_list?.topics || [];
      const categories = this.site.categories || [];

      // Create a map of category id to category
      const categoryMap = {};
      categories.forEach((cat) => {
        categoryMap[cat.id] = cat;
      });

      // Group topics by category
      const grouped = {};
      topics.forEach((topic) => {
        const catId = topic.category_id;
        if (!catId) {
          return;
        }

        const category = categoryMap[catId];
        if (!category) {
          return;
        }

        // Get top-level category (for subcategories)
        const topCat = category.parent_category_id
          ? categoryMap[category.parent_category_id]
          : category;

        if (!topCat) {
          return;
        }

        if (!grouped[topCat.id]) {
          grouped[topCat.id] = {
            category: topCat,
            topics: [],
          };
        }
        grouped[topCat.id].topics.push(topic);
      });

      // Convert to array and sort by category name
      this.topicsByCategory = Object.values(grouped).sort((a, b) =>
        a.category.name.localeCompare(b.category.name)
      );
    } catch {
      // Failed to load topics
    } finally {
      this.topicsLoading = false;
    }
  }

  get hasGroupedTopics() {
    return this.topicsByCategory.length > 0;
  }

  <template>
    {{#if this.shouldShow}}
      <div class="bookclub-homepage">
        {{#if this.hasPublications}}
          <div class="bookclub-section">
            <div class="section-header">
              <h2>Publications</h2>
            </div>

            <div class="bookclub-publications-grid">
              {{#each this.publications as |publication|}}
                <a
                  href={{this.getPublicationUrl publication}}
                  class="bookclub-publication-card"
                >
                  <div
                    class="publication-cover"
                    style={{this.getCoverStyle publication}}
                  >
                    {{#unless (this.hasCover publication)}}
                      <div class="publication-cover-placeholder">
                        {{icon "book"}}
                      </div>
                    {{/unless}}
                  </div>

                  <div class="publication-info">
                    <span class="publication-type">
                      {{this.getPublicationType publication}}
                    </span>
                    <h3 class="publication-title">
                      {{publication.name}}
                    </h3>
                    {{#if (this.getDescription publication)}}
                      <p class="publication-description">
                        {{this.getDescription publication}}
                      </p>
                    {{/if}}
                    <div class="publication-meta">
                      <span class="chapter-count">
                        {{icon "list-ul"}}
                        {{this.getChapterCount publication}}
                        chapters
                      </span>
                    </div>
                  </div>
                </a>
              {{/each}}
            </div>
          </div>
        {{/if}}

        {{#if this.hasForums}}
          <div class="bookclub-section bookclub-section--forums">
            <div class="section-header">
              <h2>Community</h2>
            </div>

            <div class="bookclub-forums-list">
              {{#each this.forums as |forum|}}
                <a
                  href={{this.getCategoryUrl forum}}
                  class="bookclub-forum-item"
                >
                  <span
                    class="forum-icon"
                    style={{this.getCategoryColorStyle forum}}
                  >
                    {{icon "comments"}}
                  </span>
                  <div class="forum-info">
                    <span class="forum-name">{{forum.name}}</span>
                    {{#if (this.getDescription forum)}}
                      <span class="forum-description">{{this.getDescription
                          forum
                        }}</span>
                    {{/if}}
                  </div>
                  <span class="forum-count">
                    {{forum.topic_count}}
                    topics
                  </span>
                </a>
              {{/each}}
            </div>
          </div>
        {{/if}}

        {{#if this.hasGroupedTopics}}
          <div class="bookclub-section bookclub-section--recent">
            <div class="section-header">
              <h2>Recent activity</h2>
            </div>

            <div class="bookclub-grouped-topics">
              {{#each this.topicsByCategory as |group|}}
                <div class="bookclub-topic-group">
                  <div class="topic-group-header">
                    <span
                      class="group-color"
                      style={{this.getCategoryColorStyle group.category}}
                    ></span>
                    <a
                      href={{this.getCategoryUrl group.category}}
                      class="group-name"
                    >
                      {{group.category.name}}
                    </a>
                  </div>
                  <ul class="topic-group-list">
                    {{#each group.topics as |topic|}}
                      <li class="topic-group-item">
                        <a href={{this.getTopicUrl topic}} class="topic-link">
                          {{topic.title}}
                        </a>
                        <span class="topic-meta">
                          {{this.formatRelativeTime topic.last_posted_at}}
                        </span>
                      </li>
                    {{/each}}
                  </ul>
                </div>
              {{/each}}
            </div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
