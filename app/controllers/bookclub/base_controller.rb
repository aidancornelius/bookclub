# frozen_string_literal: true

module Bookclub
  class BaseController < ::ApplicationController
    requires_plugin PLUGIN_NAME

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

    # Load all categories with custom fields preloaded to avoid N+1 queries
    def categories_with_custom_fields
      @categories_with_custom_fields ||=
        begin
          cats = Category.all.to_a
          Category.preload_custom_fields(cats, PUBLICATION_CUSTOM_FIELDS + CHAPTER_CUSTOM_FIELDS)
          cats
        end
    end

    def find_publication_category(slug)
      categories_with_custom_fields.find do |cat|
        cat.custom_fields[PUBLICATION_ENABLED] && cat.custom_fields[PUBLICATION_SLUG] == slug
      end
    end

    def find_chapter(publication, chapter_number)
      # Chapters are subcategories of the publication with CHAPTER_ENABLED
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

    def find_content_topic(chapter)
      # The content topic is the one marked with CONTENT_TOPIC within the chapter
      # Note: Discourse stores boolean true as "t" in custom fields
      Topic
        .where(category_id: chapter.id)
        .joins(
          "LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = '#{CONTENT_TOPIC}'"
        )
        .where('tcf.value IN (?)', %w[t true])
        .first
    end

    def find_discussion_topics(chapter)
      # Discussion topics are all topics in the chapter that aren't the content topic
      # Note: Discourse stores boolean true as "t" in custom fields
      Topic
        .where(category_id: chapter.id, visible: true)
        .joins(
          "LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = '#{CONTENT_TOPIC}'"
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
      unless guardian.is_publication_author?(publication) ||
             guardian.is_publication_editor?(publication) || guardian.is_admin?
        raise Discourse::InvalidAccess.new(
          'You must be an author or editor to perform this action',
          nil,
          custom_message: 'bookclub.errors.not_author_or_editor'
        )
      end
    end
  end
end
