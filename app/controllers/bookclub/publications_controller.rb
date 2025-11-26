# frozen_string_literal: true

module Bookclub
  class PublicationsController < BaseController
    skip_before_action :check_xhr, only: [:show]

    def index
      publications =
        categories_with_custom_fields.select do |cat|
          cat.custom_fields[PUBLICATION_ENABLED] && guardian.can_see?(cat)
        end

      render json: { publications: publications.map { |pub| serialize_publication(pub) } }
    end

    def show
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          publication = find_publication_category(params[:slug])
          raise Discourse::NotFound unless publication
          raise Discourse::InvalidAccess unless guardian.can_see?(publication)

          render json: serialize_publication_detail(publication)
        end
      end
    end

    def chapters
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_publication_access!(publication)

      chapters = find_chapters(publication)
      render json: {
               chapters:
                 chapters
                   .select { |ch| guardian.can_access_chapter?(ch) }
                   .map { |ch| serialize_chapter_summary(ch) },
             }
    end

    def toc
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      render json: { toc: build_table_of_contents(publication) }
    end

    private

    def serialize_publication(publication)
      chapters = find_published_chapters_for_list(publication)
      {
        id: publication.id,
        name: publication.name,
        slug: publication.custom_fields[PUBLICATION_SLUG] || publication.slug,
        type: publication.custom_fields[PUBLICATION_TYPE] || "book",
        cover_url: publication.custom_fields[PUBLICATION_COVER_URL],
        description: truncate_description(publication.custom_fields[PUBLICATION_DESCRIPTION]),
        has_access: guardian.can_access_publication?(publication),
        chapter_count: chapters.count,
      }
    end

    def find_published_chapters_for_list(publication)
      chapters = find_chapters(publication)
      # Only show published chapters in count
      chapters.select do |chapter|
        published = chapter.custom_fields[CHAPTER_PUBLISHED]
        published == true || published == "true" || published == "t"
      end
    end

    def serialize_publication_detail(publication)
      has_access = guardian.can_access_publication?(publication)
      is_author = guardian.is_publication_author?(publication)
      chapters = find_chapters(publication)

      {
        id: publication.id,
        name: publication.name,
        slug: publication.custom_fields[PUBLICATION_SLUG] || publication.slug,
        type: publication.custom_fields[PUBLICATION_TYPE] || "book",
        cover_url: publication.custom_fields[PUBLICATION_COVER_URL],
        description: publication.custom_fields[PUBLICATION_DESCRIPTION],
        identifier: publication.custom_fields[PUBLICATION_IDENTIFIER],
        authors: load_authors(publication.custom_fields[PUBLICATION_AUTHOR_IDS]),
        editors: load_authors(publication.custom_fields[PUBLICATION_EDITOR_IDS]),
        access_tiers: publication.custom_fields[PUBLICATION_ACCESS_TIERS],
        feedback_settings: publication.custom_fields[PUBLICATION_FEEDBACK_SETTINGS],
        has_access: has_access,
        is_author: is_author,
        is_editor: guardian.is_publication_editor?(publication),
        toc: build_table_of_contents(publication),
        chapter_count: chapters.count,
        total_word_count: total_word_count(chapters),
      }
    end

    def load_authors(author_ids)
      return [] if author_ids.blank?

      User
        .where(id: author_ids)
        .map do |user|
          {
            id: user.id,
            username: user.username,
            name: user.name,
            avatar_url: user.avatar_template_url.gsub("{size}", "90"),
          }
        end
    end

    def build_table_of_contents(publication)
      chapters = find_chapters(publication)
      has_publication_access = guardian.can_access_publication?(publication)
      is_author_or_editor =
        guardian.is_publication_author?(publication) ||
          guardian.is_publication_editor?(publication) || guardian.is_admin?

      # Filter out unpublished chapters for non-authors/editors
      visible_chapters =
        chapters.select do |chapter|
          published = chapter.custom_fields[CHAPTER_PUBLISHED]
          # Custom fields store booleans as strings, so check for both
          is_published = published == true || published == "true" || published == "t"
          is_author_or_editor || is_published
        end

      visible_chapters.map do |chapter|
        access_level = chapter.custom_fields[CHAPTER_ACCESS_LEVEL]
        is_free = access_level.blank? || access_level == "free"
        has_chapter_access = has_publication_access && guardian.can_access_chapter?(chapter)
        published = chapter.custom_fields[CHAPTER_PUBLISHED]
        is_published = published == true || published == "true" || published == "t"

        {
          id: chapter.id,
          title: chapter.name,
          number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
          type: chapter.custom_fields[CHAPTER_TYPE] || "chapter",
          published: is_published,
          access_level: access_level || "free",
          word_count: chapter.custom_fields[CHAPTER_WORD_COUNT]&.to_i,
          summary: chapter.custom_fields[CHAPTER_SUMMARY],
          has_access: is_free || has_chapter_access,
          is_free: is_free,
          slug: chapter.slug,
        }
      end
    end

    def serialize_chapter_summary(chapter)
      {
        id: chapter.id,
        title: chapter.name,
        slug: chapter.slug,
        number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
        type: chapter.custom_fields[CHAPTER_TYPE] || "chapter",
        published: chapter.custom_fields[CHAPTER_PUBLISHED] != false,
        access_level: chapter.custom_fields[CHAPTER_ACCESS_LEVEL] || "free",
        word_count: chapter.custom_fields[CHAPTER_WORD_COUNT]&.to_i,
        summary: chapter.custom_fields[CHAPTER_SUMMARY],
        contributors: chapter.custom_fields[CHAPTER_CONTRIBUTORS],
        review_status: chapter.custom_fields[CHAPTER_REVIEW_STATUS],
      }
    end

    def total_word_count(chapters)
      chapters.sum { |ch| ch.custom_fields[CHAPTER_WORD_COUNT].to_i }
    end

    def truncate_description(description)
      return nil if description.blank?
      description.length > 300 ? "#{description[0..297]}..." : description
    end
  end
end
