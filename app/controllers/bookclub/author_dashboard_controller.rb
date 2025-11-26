# frozen_string_literal: true

module Bookclub
  class AuthorDashboardController < BaseController
    before_action :ensure_logged_in
    skip_before_action :check_xhr, only: %i[index publication]

    def index
      publications =
        categories_with_custom_fields.select do |cat|
          cat.custom_fields[PUBLICATION_ENABLED] &&
            (
              guardian.is_publication_author?(cat) || guardian.is_publication_editor?(cat) ||
                guardian.is_admin?
            )
        end

      respond_to do |format|
        format.html { render 'default/empty' }
        format.json do
          render json: {
            publications: publications.map { |pub| serialize_author_publication(pub) }
          }
        end
      end
    end

    def publications
      publications =
        categories_with_custom_fields.select do |cat|
          cat.custom_fields[PUBLICATION_ENABLED] &&
            (
              guardian.is_publication_author?(cat) || guardian.is_publication_editor?(cat) ||
                guardian.is_admin?
            )
        end

      render json: { publications: publications.map { |pub| serialize_author_publication(pub) } }
    end

    def publication
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      respond_to do |format|
        format.html { render 'default/empty' }
        format.json { render json: serialize_author_publication_detail(publication) }
      end
    end

    def analytics
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      render json: {
        publication_id: publication.id,
        views: calculate_views(publication),
        engagement: calculate_engagement(publication),
        reader_progress: calculate_reader_progress(publication)
      }
    end

    def create_chapter
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      # Determine next chapter number
      chapters = find_chapters(publication)
      existing_numbers = chapters.map { |ch| ch.custom_fields[CHAPTER_NUMBER].to_i }
      next_number = existing_numbers.empty? ? 1 : existing_numbers.max + 1

      # Generate default title if not provided
      chapter_type = params[:content_type] || params[:chapter_type] || 'chapter'
      default_title =
        if publication.custom_fields[PUBLICATION_TYPE] == 'journal'
          "Article #{next_number}"
        else
          "Chapter #{next_number}"
        end
      chapter_name = params[:title].presence || default_title

      # Create the chapter subcategory
      chapter =
        Category.new(
          name: chapter_name,
          user: current_user,
          parent_category_id: publication.id,
          color: publication.color,
          text_color: publication.text_color
        )

      if chapter.save
        # Set chapter custom fields
        chapter.custom_fields[CHAPTER_ENABLED] = true
        chapter.custom_fields[CHAPTER_TYPE] = chapter_type
        chapter.custom_fields[CHAPTER_NUMBER] = next_number
        chapter.custom_fields[CHAPTER_PUBLISHED] = false
        chapter.custom_fields[CHAPTER_ACCESS_LEVEL] = params[:access_level] || 'free'
        chapter.custom_fields[CHAPTER_SUMMARY] = params[:summary]
        chapter.custom_fields[CHAPTER_REVIEW_STATUS] = 'draft'
        chapter.save_custom_fields

        # Create the pinned content topic
        content_topic =
          Topic.new(
            title: chapter_name,
            user: current_user,
            category: chapter,
            pinned_at: Time.current,
            pinned_globally: false
          )

        if content_topic.save
          # Create the first post with the content
          default_body = params[:body].presence || 'Write your content here...'
          post =
            PostCreator.new(
              current_user,
              topic_id: content_topic.id,
              raw: default_body,
              skip_validations: true
            ).create

          # Mark this as the content topic
          content_topic.custom_fields[CONTENT_TOPIC] = true
          content_topic.save_custom_fields

          # Calculate initial word count
          word_count = post.raw.split.size
          chapter.custom_fields[CHAPTER_WORD_COUNT] = word_count
          chapter.save_custom_fields

          render json: { success: true, chapter: serialize_author_chapter(chapter) }
        else
          # Clean up the category if topic creation failed
          chapter.destroy
          render json: {
                   success: false,
                   errors: content_topic.errors.full_messages
                 },
                 status: :unprocessable_entity
        end
      else
        render json: {
                 success: false,
                 errors: chapter.errors.full_messages
               },
               status: :unprocessable_entity
      end
    end

    def reorder_chapters
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      order = params[:order]
      return render json: { error: 'order_required' }, status: :bad_request if order.blank?

      order.each do |item|
        chapter =
          categories_with_custom_fields.find do |cat|
            cat.id == item[:id].to_i && cat.parent_category_id == publication.id &&
              cat.custom_fields[CHAPTER_ENABLED]
          end
        next unless chapter

        chapter.custom_fields[CHAPTER_NUMBER] = item[:number].to_i
        chapter.save_custom_fields
      end

      render json: { success: true }
    end

    def update_chapter
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      chapter = find_chapter(publication, params[:number])
      raise Discourse::NotFound unless chapter

      # Update allowed fields
      chapter.custom_fields[CHAPTER_PUBLISHED] = params[:published] if params.key?(:published)

      chapter.custom_fields[CHAPTER_ACCESS_LEVEL] = params[:access_level] if params.key?(
        :access_level
      )

      chapter.custom_fields[CHAPTER_SUMMARY] = params[:summary] if params.key?(:summary)

      chapter.custom_fields[CHAPTER_REVIEW_STATUS] = params[:review_status] if params.key?(
        :review_status
      )

      chapter.custom_fields[CHAPTER_NUMBER] = params[:chapter_number].to_i if params.key?(
        :chapter_number
      )

      # Update category name if title changed
      if params.key?(:title) && params[:title].present?
        chapter.name = params[:title]
        chapter.save

        # Also update the content topic title
        content_topic = find_content_topic(chapter)
        if content_topic
          content_topic.title = params[:title]
          content_topic.save
        end
      end

      chapter.save_custom_fields

      render json: { success: true, chapter: serialize_author_chapter(chapter) }
    end

    def delete_chapter
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      chapter = find_chapter(publication, params[:number])
      raise Discourse::NotFound unless chapter

      # Delete all topics in the chapter first
      Topic
        .where(category_id: chapter.id)
        .find_each do |topic|
          PostDestroyer.new(current_user, topic.first_post).destroy if topic.first_post
        end

      # Now delete the category
      chapter.destroy

      render json: { success: true }
    end

    private

    def serialize_author_publication(publication)
      chapters = find_chapters(publication)

      published_count = chapters.count { |ch| ch.custom_fields[CHAPTER_PUBLISHED] != false }
      draft_count = chapters.count { |ch| ch.custom_fields[CHAPTER_PUBLISHED] == false }
      total_words = chapters.sum { |ch| ch.custom_fields[CHAPTER_WORD_COUNT].to_i }

      {
        id: publication.id,
        name: publication.name,
        slug: publication.custom_fields[PUBLICATION_SLUG],
        type: publication.custom_fields[PUBLICATION_TYPE],
        cover_url: publication.custom_fields[PUBLICATION_COVER_URL],
        chapter_count: chapters.count,
        published_count: published_count,
        draft_count: draft_count,
        total_word_count: total_words,
        is_author: guardian.is_publication_author?(publication),
        is_editor: guardian.is_publication_editor?(publication)
      }
    end

    def serialize_author_publication_detail(publication)
      chapters = find_chapters(publication)

      sorted_chapters =
        chapters
        .map { |ch| serialize_author_chapter(ch) }
        .sort_by { |c| [c[:number] || 9999, c[:id]] }

      {
        id: publication.id,
        name: publication.name,
        slug: publication.custom_fields[PUBLICATION_SLUG],
        type: publication.custom_fields[PUBLICATION_TYPE],
        cover_url: publication.custom_fields[PUBLICATION_COVER_URL],
        description: publication.custom_fields[PUBLICATION_DESCRIPTION],
        author_ids: publication.custom_fields[PUBLICATION_AUTHOR_IDS],
        editor_ids: publication.custom_fields[PUBLICATION_EDITOR_IDS],
        access_tiers: publication.custom_fields[PUBLICATION_ACCESS_TIERS],
        feedback_settings: publication.custom_fields[PUBLICATION_FEEDBACK_SETTINGS],
        chapters: sorted_chapters,
        is_author: guardian.is_publication_author?(publication),
        is_editor: guardian.is_publication_editor?(publication)
      }
    end

    def serialize_author_chapter(chapter)
      discussion_count = Topic.where(category_id: chapter.id).count - 1 # Exclude content topic
      content_topic = find_content_topic(chapter)

      # Calculate posts count from discussion topics
      discussion_topics = find_discussion_topics(chapter)
      posts_count = Post.where(topic_id: discussion_topics.pluck(:id)).count

      {
        id: chapter.id,
        title: chapter.name,
        slug: chapter.slug,
        number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
        type: chapter.custom_fields[CHAPTER_TYPE] || 'chapter',
        published: chapter.custom_fields[CHAPTER_PUBLISHED] != false,
        access_level: chapter.custom_fields[CHAPTER_ACCESS_LEVEL] || 'free',
        word_count: chapter.custom_fields[CHAPTER_WORD_COUNT].to_i,
        summary: chapter.custom_fields[CHAPTER_SUMMARY],
        review_status: chapter.custom_fields[CHAPTER_REVIEW_STATUS],
        created_at: chapter.created_at,
        updated_at: chapter.updated_at,
        discussion_count: [discussion_count, 0].max,
        posts_count: posts_count,
        content_topic_id: content_topic&.id,
        views: content_topic&.views || 0
      }
    end

    def calculate_views(publication)
      chapters = find_chapters(publication)
      content_topics = chapters.map { |ch| find_content_topic(ch) }.compact

      {
        total: content_topics.sum(&:views),
        last_7_days: content_topics.sum(&:views),
        by_chapter:
          chapters.map do |ch|
            content_topic = find_content_topic(ch)
            { id: ch.id, title: ch.name, views: content_topic&.views || 0 }
          end
      }
    end

    def calculate_engagement(publication)
      chapters = find_chapters(publication)
      publication_author_ids = publication.custom_fields[PUBLICATION_AUTHOR_IDS] || []

      # NOTE: Discourse stores boolean true as "t" in custom fields
      discussion_topics =
        Topic
        .where(category_id: chapters.pluck(:id))
        .joins(
          "LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = '#{CONTENT_TOPIC}'"
        )
        .where('tcf.value IS NULL OR tcf.value NOT IN (?)', %w[t true])

      posts = Post.where(topic_id: discussion_topics.pluck(:id))

      # Find questions that need author response
      # A question is a topic without any replies from the publication authors
      unanswered_questions =
        discussion_topics
        .where('topics.posts_count > 1') # Has at least one reply (but maybe not from author)
        .select do |topic|
          # Check if any author has replied
          Post.where(topic_id: topic.id).where(user_id: publication_author_ids).none?
        end

      # Recent unanswered questions
      recent_unanswered =
        unanswered_questions
        .sort_by(&:created_at)
        .reverse
        .take(5)
        .map do |topic|
          chapter = chapters.find { |ch| ch.id == topic.category_id }
          {
            id: topic.id,
            title: topic.title,
            chapter: {
              id: chapter&.id,
              title: chapter&.name,
              number: chapter&.custom_fields&.[](CHAPTER_NUMBER)&.to_i
            },
            posts_count: topic.posts_count,
            created_at: topic.created_at,
            last_posted_at: topic.last_posted_at
          }
        end

      {
        total_discussions: discussion_topics.count,
        total_posts: posts.count,
        unique_participants: posts.distinct.count(:user_id),
        unanswered_questions_count: unanswered_questions.count,
        unanswered_questions: recent_unanswered,
        recent_activity:
          posts
            .order(created_at: :desc)
            .limit(10)
            .includes(:user, :topic)
            .map do |post|
              chapter = chapters.find { |ch| ch.id == post.topic.category_id }
              {
                id: post.id,
                topic_id: post.topic_id,
                topic_title: post.topic.title,
                chapter: {
                  id: chapter&.id,
                  title: chapter&.name,
                  number: chapter&.custom_fields&.[](CHAPTER_NUMBER)&.to_i
                },
                excerpt: post.excerpt(200),
                user: {
                  id: post.user.id,
                  username: post.user.username,
                  avatar_url: post.user.avatar_template_url.gsub('{size}', '45')
                },
                created_at: post.created_at
              }
            end
      }
    end

    def calculate_reader_progress(publication)
      chapters = find_chapters(publication)
      publication_slug = publication.custom_fields[PUBLICATION_SLUG]

      # Find all users who have reading progress for this publication
      user_progress_data =
        UserCustomField.where(name: READING_PROGRESS).where('value::jsonb ? ?', publication_slug)

      total_readers = user_progress_data.count
      completed_readers = 0
      total_completion_percentage = 0

      # Build chapter-level progress data
      chapter_progress = {}
      chapters.each { |chapter| chapter_progress[chapter.id] = { started: 0, completed: 0 } }

      user_progress_data.each do |user_field|
        progress = JSON.parse(user_field.value)
        pub_progress = progress[publication_slug]
        next unless pub_progress

        completed_chapters = pub_progress['completed'] || []
        total_chapters = chapters.count

        if total_chapters.positive?
          completion_percentage = (completed_chapters.length.to_f / total_chapters) * 100
          total_completion_percentage += completion_percentage

          completed_readers += 1 if completion_percentage >= 100
        end

        # Track per-chapter progress
        chapters.each do |chapter|
          if completed_chapters.include?(chapter.id)
            chapter_progress[chapter.id][:completed] += 1
            chapter_progress[chapter.id][:started] += 1
          elsif pub_progress['current_content_id'] == chapter.id
            chapter_progress[chapter.id][:started] += 1
          end
        end
      end

      average_progress =
        total_readers.positive? ? (total_completion_percentage / total_readers).round(1) : 0

      by_chapter =
        chapters.map do |chapter|
          stats = chapter_progress[chapter.id]
          completion_rate =
            (
              if stats[:started].positive?
                (stats[:completed].to_f / stats[:started] * 100).round(1)
              else
                0
              end
            )

          {
            id: chapter.id,
            title: chapter.name,
            number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
            started: stats[:started],
            completed: stats[:completed],
            completion_rate: completion_rate
          }
        end

      {
        total_readers: total_readers,
        completed_readers: completed_readers,
        average_progress: average_progress,
        by_chapter: by_chapter
      }
    end
  end
end
