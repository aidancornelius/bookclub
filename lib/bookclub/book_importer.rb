# frozen_string_literal: true

module Bookclub
  # Imports a parsed book into Discourse as a Bookclub publication
  class BookImporter
    include Bookclub::ContentHelpers

    class ImportError < StandardError
    end

    ImportResult =
      Struct.new(
        :success,
        :publication,
        :chapters_created,
        :chapters_updated,
        :errors,
        keyword_init: true,
      )

    attr_reader :user, :parsed_book, :options

    # @param user [User] The user performing the import (will be set as author)
    # @param parsed_book [BookParser::ParsedBook] The parsed book data
    # @param options [Hash] Import options
    # @option options [String] :slug Custom slug for the publication
    # @option options [Integer] :publication_id Existing publication ID to update
    # @option options [Boolean] :publish Whether to publish chapters immediately (default: false)
    # @option options [String] :access_level Default access level for chapters (default: "free")
    # @option options [Boolean] :replace_existing Replace existing chapters vs. skip (default: false)
    def initialize(user:, parsed_book:, **options)
      @user = user
      @parsed_book = parsed_book
      @options = { publish: false, access_level: "free", replace_existing: false }.merge(options)
    end

    def import!
      errors = []
      chapters_created = []
      chapters_updated = []

      ActiveRecord::Base.transaction do
        # Create or find publication
        publication =
          if options[:publication_id]
            find_existing_publication(options[:publication_id])
          else
            create_publication
          end

        raise ImportError, "Could not create or find publication" unless publication

        # Import each chapter
        existing_chapters = find_existing_chapters(publication)

        parsed_book.chapters.each do |chapter_data|
          begin
            existing = find_matching_chapter(existing_chapters, chapter_data)

            if existing
              if options[:replace_existing]
                update_chapter(existing, chapter_data)
                chapters_updated << chapter_data.title
              else
                # Skip - chapter already exists
                errors << "Skipped '#{chapter_data.title}' - already exists"
              end
            else
              create_chapter(publication, chapter_data)
              chapters_created << chapter_data.title
            end
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ImportError => e
            error_message = "Error with chapter '#{chapter_data.title}': #{e.message}"
            errors << error_message
            Rails.logger.error("[Bookclub::BookImporter] #{error_message}")
            Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
          rescue StandardError => e
            # Catch any unexpected errors but log them with full details
            error_message = "Unexpected error with chapter '#{chapter_data.title}': #{e.class.name} - #{e.message}"
            errors << error_message
            Rails.logger.error("[Bookclub::BookImporter] #{error_message}")
            Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
          end
        end

        # Upload cover image if present
        upload_cover(publication, parsed_book.cover_image) if parsed_book.cover_image && publication

        return(
          ImportResult.new(
            success: errors.empty? || chapters_created.any? || chapters_updated.any?,
            publication: publication,
            chapters_created: chapters_created,
            chapters_updated: chapters_updated,
            errors: errors,
          )
        )
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ImportError => e
      error_message = "Import failed: #{e.message}"
      Rails.logger.error("[Bookclub::BookImporter] #{error_message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      ImportResult.new(
        success: false,
        publication: nil,
        chapters_created: [],
        chapters_updated: [],
        errors: [error_message],
      )
    rescue StandardError => e
      # Catch any unexpected errors but log them with full details
      error_message = "Unexpected import error: #{e.class.name} - #{e.message}"
      Rails.logger.error("[Bookclub::BookImporter] #{error_message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      ImportResult.new(
        success: false,
        publication: nil,
        chapters_created: [],
        chapters_updated: [],
        errors: [error_message],
      )
    end

    private

    def find_existing_publication(publication_id)
      cat = Category.find_by(id: publication_id)
      return nil unless cat
      return nil unless cat.custom_fields[PUBLICATION_ENABLED]
      cat
    end

    def create_publication
      slug = options[:slug] || generate_slug(parsed_book.title)

      # Check for existing publication with same slug
      existing = CategoryCustomField.find_by(name: PUBLICATION_SLUG, value: slug)&.category
      raise ImportError, "A publication with slug '#{slug}' already exists" if existing

      publication =
        Category.new(
          name: parsed_book.title || "Untitled Book",
          user: user,
          color: "B25A27",
          text_color: "FFFFFF",
        )

      unless publication.save
        raise ImportError,
              "Could not create publication: #{publication.errors.full_messages.join(", ")}"
      end

      # Set custom fields
      publication.custom_fields[PUBLICATION_ENABLED] = true
      publication.custom_fields[PUBLICATION_SLUG] = slug
      publication.custom_fields[PUBLICATION_TYPE] = parsed_book.type || "book"
      publication.custom_fields[
        PUBLICATION_DESCRIPTION
      ] = parsed_book.description if parsed_book.description
      publication.custom_fields[PUBLICATION_AUTHOR_IDS] = [user.id]
      publication.save_custom_fields

      publication
    end

    def find_existing_chapters(publication)
      Category
        .where(parent_category_id: publication.id)
        .to_a
        .tap { |cats| Category.preload_custom_fields(cats, [CHAPTER_ENABLED, CHAPTER_NUMBER]) }
        .select { |c| c.custom_fields[CHAPTER_ENABLED] }
    end

    def find_matching_chapter(existing_chapters, chapter_data)
      # Match by number first, then by title
      existing_chapters.find do |ch|
        ch.custom_fields[CHAPTER_NUMBER]&.to_i == chapter_data.number ||
          ch.name.downcase.strip == chapter_data.title.downcase.strip
      end
    end

    def create_chapter(publication, chapter_data)
      chapter =
        Category.new(
          name: chapter_data.title,
          user: user,
          parent_category_id: publication.id,
          color: publication.color,
          text_color: publication.text_color,
        )

      unless chapter.save
        raise ImportError, "Could not create chapter: #{chapter.errors.full_messages.join(", ")}"
      end

      # Set custom fields
      chapter.custom_fields[CHAPTER_ENABLED] = true
      chapter.custom_fields[CHAPTER_TYPE] = "chapter"
      chapter.custom_fields[CHAPTER_NUMBER] = chapter_data.number
      chapter.custom_fields[CHAPTER_PUBLISHED] = options[:publish]
      chapter.custom_fields[CHAPTER_ACCESS_LEVEL] = options[:access_level]
      chapter.custom_fields[CHAPTER_WORD_COUNT] = chapter_data.word_count
      chapter.custom_fields[CHAPTER_REVIEW_STATUS] = options[:publish] ? "approved" : "draft"
      chapter.save_custom_fields

      # Create content topic
      create_content_topic(chapter, chapter_data)

      chapter
    end

    def update_chapter(chapter, chapter_data)
      # Update word count
      chapter.custom_fields[CHAPTER_WORD_COUNT] = chapter_data.word_count
      chapter.save_custom_fields

      # Find and update the content topic
      content_topic = find_content_topic(chapter)
      if content_topic
        update_content_topic(content_topic, chapter_data)
      else
        create_content_topic(chapter, chapter_data)
      end
    end

    # find_content_topic method is provided by Bookclub::ContentHelpers

    def create_content_topic(chapter, chapter_data)
      topic =
        Topic.new(
          title: chapter_data.title,
          user: user,
          category: chapter,
          pinned_at: Time.current,
          pinned_globally: false,
        )

      unless topic.save
        raise ImportError, "Could not create topic: #{topic.errors.full_messages.join(", ")}"
      end

      # Create the post with content
      PostCreator.new(
        user,
        topic_id: topic.id,
        raw: chapter_data.content,
        skip_validations: true,
      ).create

      # Mark as content topic
      topic.custom_fields[CONTENT_TOPIC] = true
      topic.save_custom_fields

      topic
    end

    def update_content_topic(topic, chapter_data)
      # Update the first post
      first_post = topic.posts.order(:post_number).first
      if first_post
        revisor = PostRevisor.new(first_post)
        revisor.revise!(user, { raw: chapter_data.content }, skip_validations: true)
      end
    end

    def upload_cover(publication, image_data)
      # TODO: Implement cover image upload functionality
      # This would require:
      # 1. Decoding the image_data (likely base64 or file path)
      # 2. Creating a Discourse Upload object via UploadCreator
      # 3. Setting publication.custom_fields[PUBLICATION_COVER_URL] to upload.url
      # 4. Handling validation and error cases
      Rails.logger.warn(
        "[Bookclub::BookImporter] Cover image upload not yet implemented for publication #{publication.id}"
      )
    end

    def generate_slug(title)
      return "untitled-#{SecureRandom.hex(4)}" unless title

      slug =
        title.downcase.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")

      slug.presence || "untitled-#{SecureRandom.hex(4)}"
    end
  end
end
