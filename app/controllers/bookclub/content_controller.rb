# frozen_string_literal: true

module Bookclub
  class ContentController < BaseController
    skip_before_action :check_xhr, only: [:show]

    def show
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          publication = find_publication_category(params[:slug])
          raise Discourse::NotFound unless publication

          # Check if user is author/editor/admin
          is_author_or_editor =
            guardian.is_publication_author?(publication) ||
              guardian.is_publication_editor?(publication) || guardian.is_admin?

          # Support both /book/slug/2 (numeric) and /book/slug/chapter-slug (slug) formats
          chapter_id = params[:chapter_id] || params[:content_number] || params[:number]
          chapter = find_chapter(publication, chapter_id)
          raise Discourse::NotFound unless chapter

          # Check if chapter is published (for non-authors/editors)
          unless is_author_or_editor
            published = chapter.custom_fields[CHAPTER_PUBLISHED]
            is_published = [true, "true", "t"].include?(published)
            raise Discourse::NotFound unless is_published
          end

          unless guardian.can_access_chapter?(chapter)
            render json: {
                     error: "access_denied",
                     paywall: true,
                     access_tiers: publication.custom_fields[PUBLICATION_ACCESS_TIERS],
                   },
                   status: :forbidden
            return
          end

          content_topic = find_content_topic(chapter)
          raise Discourse::NotFound unless content_topic

          render json: serialize_chapter_detail(publication, chapter, content_topic)
        end
      end
    end

    def update_progress
      return render json: { error: "not_logged_in" }, status: :unauthorized unless current_user

      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      chapter_number = params[:content_number] || params[:number]
      chapter = find_chapter(publication, chapter_number)
      raise Discourse::NotFound unless chapter

      progress = current_user.custom_fields[READING_PROGRESS] || {}
      pub_slug = publication.custom_fields[PUBLICATION_SLUG]

      progress[pub_slug] ||= {}
      progress[pub_slug]["current_chapter_id"] = chapter.id
      progress[pub_slug]["current_chapter_number"] = chapter_number.to_i
      progress[pub_slug]["scroll_position"] = params[:scroll_position] if params[:scroll_position]
      progress[pub_slug]["last_read_at"] = Time.current.iso8601

      progress[pub_slug]["completed"] ||= []
      if params[:completed] && !progress[pub_slug]["completed"].include?(chapter.id)
        progress[pub_slug]["completed"] << chapter.id
      end

      current_user.custom_fields[READING_PROGRESS] = progress
      current_user.save_custom_fields

      render json: { success: true, progress: progress[pub_slug] }
    end

    private

    def serialize_chapter_detail(publication, chapter, content_topic)
      first_post = content_topic.first_post
      discussion_topics = find_discussion_topics(chapter).limit(10)

      {
        publication: serialize_publication(publication),
        chapter: serialize_chapter(chapter, content_topic, first_post),
        navigation: build_navigation(publication, chapter),
        reading_progress: current_user ? load_reading_progress(publication) : nil,
        discussions: serialize_discussions(chapter, discussion_topics),
        feedback_settings: publication.custom_fields[PUBLICATION_FEEDBACK_SETTINGS],
      }
    end

    def serialize_publication(publication)
      {
        id: publication.id,
        name: publication.name,
        slug: publication.custom_fields[PUBLICATION_SLUG],
        type: publication.custom_fields[PUBLICATION_TYPE],
        toc: build_toc(publication),
      }
    end

    def serialize_chapter(chapter, content_topic, first_post)
      publication = chapter.parent_category

      {
        id: chapter.id,
        title: chapter.name,
        slug: chapter.slug,
        number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
        type: chapter.custom_fields[CHAPTER_TYPE] || "chapter",
        word_count: chapter.custom_fields[CHAPTER_WORD_COUNT]&.to_i,
        summary: chapter.custom_fields[CHAPTER_SUMMARY],
        contributors: chapter.custom_fields[CHAPTER_CONTRIBUTORS],
        review_status: chapter.custom_fields[CHAPTER_REVIEW_STATUS],
        body_html: strip_leading_title(first_post.cooked, chapter.name),
        body_raw: guardian.is_publication_author?(publication) ? first_post.raw : nil,
        content_topic_id: content_topic.id,
        created_at: chapter.created_at,
        updated_at: first_post.updated_at,
      }
    end

    def serialize_discussions(chapter, discussion_topics)
      {
        chapter_id: chapter.id,
        topic_count: discussion_topics.count,
        topics:
          discussion_topics.map do |topic|
            {
              id: topic.id,
              title: topic.title,
              slug: topic.slug,
              posts_count: topic.posts_count,
              created_at: topic.created_at,
              last_posted_at: topic.last_posted_at,
              user: {
                id: topic.user.id,
                username: topic.user.username,
                name: topic.user.name,
                avatar_url: topic.user.avatar_template_url.gsub("{size}", "45"),
              },
            }
          end,
      }
    end

    def build_navigation(publication, current_chapter)
      chapters = find_published_chapters(publication)
      current_index = chapters.find_index { |ch| ch.id == current_chapter.id }

      prev_chapter = current_index && current_index > 0 ? chapters[current_index - 1] : nil
      next_chapter =
        current_index && current_index < chapters.length - 1 ? chapters[current_index + 1] : nil

      {
        current: {
          number: current_chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
          title: current_chapter.name,
        },
        previous: prev_chapter ? navigation_item(publication, prev_chapter) : nil,
        next: next_chapter ? navigation_item(publication, next_chapter) : nil,
        total_count: chapters.length,
        current_index: current_index ? current_index + 1 : nil,
      }
    end

    def navigation_item(publication, chapter)
      pub_slug = publication.custom_fields[PUBLICATION_SLUG]

      {
        id: chapter.id,
        title: chapter.name,
        slug: chapter.slug,
        number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
        type: chapter.custom_fields[CHAPTER_TYPE] || "chapter",
        url: "/book/#{pub_slug}/#{chapter.slug}",
        has_access: guardian.can_access_chapter?(chapter),
      }
    end

    def build_toc(publication)
      chapters = find_published_chapters(publication)
      has_publication_access = guardian.can_access_publication?(publication)

      chapters.map do |chapter|
        access_level = chapter.custom_fields[CHAPTER_ACCESS_LEVEL]
        is_free = access_level.blank? || access_level == "free"
        has_chapter_access = has_publication_access && guardian.can_access_chapter?(chapter)

        {
          id: chapter.id,
          title: chapter.name,
          slug: chapter.slug,
          number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
          type: chapter.custom_fields[CHAPTER_TYPE] || "chapter",
          has_access: is_free || has_chapter_access,
        }
      end
    end

    def load_reading_progress(publication)
      return nil unless current_user

      progress = current_user.custom_fields[READING_PROGRESS]
      return nil if progress.blank?

      pub_slug = publication.custom_fields[PUBLICATION_SLUG]
      progress[pub_slug]
    end

    def find_published_chapters(publication)
      chapters = find_chapters(publication)
      is_author_or_editor =
        guardian.is_publication_author?(publication) ||
          guardian.is_publication_editor?(publication) || guardian.is_admin?

      return chapters if is_author_or_editor

      # Filter to only published chapters for regular users
      chapters.select do |chapter|
        published = chapter.custom_fields[CHAPTER_PUBLISHED]
        [true, "true", "t"].include?(published)
      end
    end

    def strip_leading_title(html, title)
      return html if html.blank? || title.blank?

      doc = Nokogiri::HTML5.fragment(html)
      first_element = doc.children.find { |node| node.element? }

      return html unless first_element

      if %w[h1 h2].include?(first_element.name.downcase)
        heading_text = first_element.text.strip.downcase
        title_text = title.strip.downcase

        if heading_text == title_text || title_text.start_with?(heading_text)
          first_element.remove
          return doc.to_html
        end
      end

      html
    end
  end
end
