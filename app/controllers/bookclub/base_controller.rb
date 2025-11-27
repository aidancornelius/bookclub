# frozen_string_literal: true

module Bookclub
  class BaseController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    include Bookclub::ContentHelpers

    before_action :ensure_bookclub_enabled

    private

    def ensure_bookclub_enabled
      raise Discourse::NotFound unless SiteSetting.bookclub_enabled
    end

    # Custom fields to preload for publications
    PUBLICATION_CUSTOM_FIELDS = [
      PUBLICATION_ENABLED,
      PUBLICATION_TYPE,
      PUBLICATION_SLUG,
      PUBLICATION_COVER_URL,
      PUBLICATION_DESCRIPTION,
      PUBLICATION_AUTHOR_IDS,
      PUBLICATION_EDITOR_IDS,
      PUBLICATION_ACCESS_TIERS,
      PUBLICATION_FEEDBACK_SETTINGS,
      PUBLICATION_IDENTIFIER
    ].freeze

    # Custom fields to preload for chapters
    CHAPTER_CUSTOM_FIELDS = [
      CHAPTER_ENABLED,
      CHAPTER_NUMBER,
      CHAPTER_TYPE,
      CHAPTER_ACCESS_LEVEL,
      CHAPTER_PUBLISHED,
      CHAPTER_SUMMARY,
      CHAPTER_WORD_COUNT,
      CHAPTER_CONTRIBUTORS,
      CHAPTER_REVIEW_STATUS
    ].freeze

    # Load categories with custom fields preloaded to avoid N+1 queries
    # Optimised to only load Bookclub publications and chapters, not all site categories
    def categories_with_custom_fields
      @categories_with_custom_fields ||=
        begin
          # Only load categories that are Bookclub publications (have PUBLICATION_ENABLED) or
          # Bookclub chapters (have CHAPTER_ENABLED). This prevents loading all forum subcategories.
          cats = Category.where(
            "EXISTS (SELECT 1 FROM category_custom_fields ccf WHERE ccf.category_id = categories.id AND ccf.name = ?) OR " \
            "EXISTS (SELECT 1 FROM category_custom_fields ccf2 WHERE ccf2.category_id = categories.id AND ccf2.name = ?)",
            PUBLICATION_ENABLED,
            CHAPTER_ENABLED
          ).to_a

          Category.preload_custom_fields(cats, PUBLICATION_CUSTOM_FIELDS + CHAPTER_CUSTOM_FIELDS)
          cats
        end
    end

    def find_publication_category(slug)
      categories_with_custom_fields.find do |cat|
        cat.custom_fields[PUBLICATION_ENABLED] && cat.custom_fields[PUBLICATION_SLUG] == slug
      end
    end

    def find_chapter(publication, chapter_id)
      # Chapters are subcategories of the publication with CHAPTER_ENABLED
      # chapter_id can be either a number or a slug
      is_numeric = chapter_id.to_s.match?(/\A\d+\z/)

      categories_with_custom_fields.find do |cat|
        next unless cat.parent_category_id == publication.id && cat.custom_fields[CHAPTER_ENABLED]

        if is_numeric
          cat.custom_fields[CHAPTER_NUMBER]&.to_i == chapter_id.to_i
        else
          cat.slug == chapter_id.to_s
        end
      end
    end

    def find_chapter_by_number(publication, chapter_number)
      # Find chapter by number only (for backwards compatibility)
      categories_with_custom_fields.find do |cat|
        cat.parent_category_id == publication.id && cat.custom_fields[CHAPTER_ENABLED] &&
          cat.custom_fields[CHAPTER_NUMBER]&.to_i == chapter_number.to_i
      end
    end

    def find_chapters(publication)
      # Get all chapter subcategories sorted by number
      categories_with_custom_fields
        .select do |cat|
          cat.parent_category_id == publication.id && cat.custom_fields[CHAPTER_ENABLED]
        end
        .sort_by { |cat| cat.custom_fields[CHAPTER_NUMBER]&.to_i || 9999 }
    end

    # find_content_topic method is provided by Bookclub::ContentHelpers

    def find_discussion_topics(chapter)
      # Discussion topics are all topics in the chapter that aren't the content topic
      # Note: Discourse stores boolean true as "t" in custom fields
      Topic
        .where(category_id: chapter.id, visible: true)
        .joins(
          sanitize_sql_array([
            'LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = ?',
            CONTENT_TOPIC,
          ]),
        )
        .where('tcf.value IS NULL OR tcf.value NOT IN (?)', %w[t true])
        .order(created_at: :desc)
    end

    def ensure_publication_access!(publication)
      return if guardian.can_access_publication?(publication)

      raise Discourse::InvalidAccess.new(
        'You do not have access to this publication',
        nil,
        custom_message: 'bookclub.errors.no_publication_access'
      )
    end

    def ensure_chapter_access!(chapter)
      return if guardian.can_access_chapter?(chapter)

      raise Discourse::InvalidAccess.new(
        'You do not have access to this chapter',
        nil,
        custom_message: 'bookclub.errors.no_chapter_access'
      )
    end

    def ensure_author_or_editor!(publication)
      unless guardian.can_manage_publication?(publication)
        raise Discourse::InvalidAccess.new(
          'You must be an author or editor to perform this action',
          nil,
          custom_message: 'bookclub.errors.not_author_or_editor'
        )
      end
    end

    # Helper to check if a custom field value represents a boolean true
    # Discourse stores boolean true in custom fields as "t", "true", or true
    def boolean_custom_field?(value)
      [true, "true", "t"].include?(value)
    end
  end
end
