# frozen_string_literal: true

module Bookclub
  class AuthorDashboardController < BaseController
    before_action :ensure_logged_in
    skip_before_action :check_xhr, only: %i[index publication]

    def index
      publications =
        categories_with_custom_fields.select do |cat|
          cat.custom_fields[PUBLICATION_ENABLED] && guardian.can_manage_publication?(cat)
        end

      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          render json: {
                   publications: publications.map { |pub| serialize_author_publication(pub) },
                 }
        end
      end
    end

    def publications
      publications =
        categories_with_custom_fields.select do |cat|
          cat.custom_fields[PUBLICATION_ENABLED] && guardian.can_manage_publication?(cat)
        end

      render json: {
               publications: publications.map { |pub| serialize_author_publication(pub) },
               can_create: guardian.is_admin?,
             }
    end

    def create_publication
      raise Discourse::InvalidAccess unless guardian.is_admin?

      name = params[:name]
      publication_type = params[:type] || "book"
      slug = params[:slug].presence || name.parameterize

      # Check slug uniqueness
      existing =
        categories_with_custom_fields.find { |c| c.custom_fields[PUBLICATION_SLUG] == slug }
      if existing
        return(
          render json: {
                   success: false,
                   errors: ["Slug already exists"],
                 },
                 status: :unprocessable_entity
        )
      end

      # Create the category
      publication =
        Category.new(name: name, user: current_user, color: "0088CC", text_color: "FFFFFF")

      if publication.save
        # Set publication custom fields
        publication.custom_fields[PUBLICATION_ENABLED] = true
        publication.custom_fields[PUBLICATION_TYPE] = publication_type
        publication.custom_fields[PUBLICATION_SLUG] = slug
        publication.custom_fields[PUBLICATION_AUTHOR_IDS] = [current_user.id]
        publication.custom_fields[PUBLICATION_DESCRIPTION] = params[:description] if params[
          :description
        ]
        publication.save_custom_fields

        render json: { success: true, publication: serialize_author_publication(publication) }
      else
        render json: {
                 success: false,
                 errors: publication.errors.full_messages,
               },
               status: :unprocessable_entity
      end
    end

    def publication
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      respond_to do |format|
        format.html { render "default/empty" }
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
               reader_progress: calculate_reader_progress(publication),
             }
    end

    def update_publication
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      # Clear preloaded custom fields proxy to allow modification
      # reload alone doesn't clear @preloaded_custom_fields, so we must do it explicitly
      publication.instance_variable_set(:@preloaded_custom_fields, nil)
      publication.instance_variable_set(:@preloaded_proxy, nil)

      # Update category name if provided
      if params[:name].present? && params[:name] != publication.name
        publication.name = params[:name]
        publication.save!
      end

      # Update custom fields
      publication.custom_fields[PUBLICATION_TYPE] = params[:type] if params.key?(:type)
      publication.custom_fields[PUBLICATION_DESCRIPTION] = params[:description] if params.key?(
        :description,
      )
      publication.custom_fields[PUBLICATION_COVER_URL] = params[:cover_url] if params.key?(
        :cover_url,
      )

      # Update slug if provided (and different)
      if params[:new_slug].present? &&
           params[:new_slug] != publication.custom_fields[PUBLICATION_SLUG]
        # Check slug uniqueness
        existing =
          categories_with_custom_fields.find do |c|
            c.id != publication.id && c.custom_fields[PUBLICATION_SLUG] == params[:new_slug]
          end
        if existing
          return(
            render json: {
                     success: false,
                     errors: ["Slug already exists"],
                   },
                   status: :unprocessable_entity
          )
        end
        publication.custom_fields[PUBLICATION_SLUG] = params[:new_slug]
      end

      publication.save_custom_fields

      render json: { success: true, publication: serialize_author_publication_detail(publication) }
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
      chapter_type = params[:content_type] || params[:chapter_type] || "chapter"
      default_title =
        if publication.custom_fields[PUBLICATION_TYPE] == "journal"
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
          text_color: publication.text_color,
        )

      if chapter.save
        # Set chapter custom fields
        chapter.custom_fields[CHAPTER_ENABLED] = true
        chapter.custom_fields[CHAPTER_TYPE] = chapter_type
        chapter.custom_fields[CHAPTER_NUMBER] = next_number
        chapter.custom_fields[CHAPTER_PUBLISHED] = false
        chapter.custom_fields[CHAPTER_ACCESS_LEVEL] = params[:access_level] || "free"
        chapter.custom_fields[CHAPTER_SUMMARY] = params[:summary]
        chapter.custom_fields[CHAPTER_REVIEW_STATUS] = "draft"
        chapter.save_custom_fields

        # Create the pinned content topic
        content_topic =
          Topic.new(
            title: chapter_name,
            user: current_user,
            category: chapter,
            pinned_at: Time.current,
            pinned_globally: false,
          )

        if content_topic.save
          # Create the first post with the content
          default_body = params[:body].presence || "Write your content here..."
          post =
            PostCreator.new(
              current_user,
              topic_id: content_topic.id,
              raw: default_body,
              skip_validations: true,
            ).create

          # Mark this as the content topic
          content_topic.custom_fields[CONTENT_TOPIC] = true
          content_topic.save_custom_fields

          # Calculate initial word count
          word_count = post.raw.split.size
          chapter.custom_fields[CHAPTER_WORD_COUNT] = word_count
          chapter.save_custom_fields

          # Sync category permissions based on access level
          access_level = params[:access_level] || "free"
          sync_chapter_permissions(chapter, access_level, publication)

          render json: { success: true, chapter: serialize_author_chapter(chapter) }
        else
          # Clean up the category if topic creation failed
          chapter.destroy
          render json: {
                   success: false,
                   errors: content_topic.errors.full_messages,
                 },
                 status: :unprocessable_entity
        end
      else
        render json: {
                 success: false,
                 errors: chapter.errors.full_messages,
               },
               status: :unprocessable_entity
      end
    end

    def reorder_chapters
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      order = params[:order]
      return render json: { error: "order_required" }, status: :bad_request if order.blank?

      order.each do |item|
        chapter =
          categories_with_custom_fields.find do |cat|
            cat.id == item[:id].to_i && cat.parent_category_id == publication.id &&
              cat.custom_fields[CHAPTER_ENABLED]
          end
        next unless chapter

        # Clear preloaded custom fields proxy to allow modification
        chapter.instance_variable_set(:@preloaded_custom_fields, nil)
        chapter.instance_variable_set(:@preloaded_proxy, nil)
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

      # Clear preloaded custom fields proxy to allow modification
      chapter.instance_variable_set(:@preloaded_custom_fields, nil)
      chapter.instance_variable_set(:@preloaded_proxy, nil)

      # Track if we need to sync permissions
      needs_permission_sync = false
      new_published = nil
      new_access_level = chapter.custom_fields[CHAPTER_ACCESS_LEVEL]

      # Update allowed fields
      if params.key?(:published)
        chapter.custom_fields[CHAPTER_PUBLISHED] = params[:published]
        new_published = params[:published]
        needs_permission_sync = true
      end

      if params.key?(:access_level)
        chapter.custom_fields[CHAPTER_ACCESS_LEVEL] = params[:access_level]
        new_access_level = params[:access_level]
        needs_permission_sync = true
      end

      # Sync Discourse category permissions when access level or published status changes
      if needs_permission_sync
        sync_chapter_permissions(chapter, new_access_level, publication, published: new_published)
      end

      chapter.custom_fields[CHAPTER_SUMMARY] = params[:summary] if params.key?(:summary)

      chapter.custom_fields[CHAPTER_REVIEW_STATUS] = params[:review_status] if params.key?(
        :review_status,
      )

      chapter.custom_fields[CHAPTER_NUMBER] = params[:chapter_number].to_i if params.key?(
        :chapter_number,
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

      chapter_id = chapter.id
      chapter_name = chapter.name

      # Enqueue background job for deletion to avoid timeouts on large chapters
      # PostDestroyer side effects (uploads, logs) are handled properly in the background
      Jobs.enqueue(
        :delete_bookclub_chapter,
        chapter_id: chapter_id,
        user_id: current_user.id,
        publication_id: publication.id
      )

      Rails.logger.info(
        "[Bookclub] Enqueued deletion of chapter #{chapter_id} '#{chapter_name}' from publication #{publication.id}"
      )

      render json: { success: true, message: "Chapter deletion queued" }
    end

    # Import a book from uploaded file (creates new publication)
    def import_book
      raise Discourse::InvalidAccess unless guardian.is_admin?

      file = params[:file]
      raise Discourse::InvalidParameters.new(:file) unless file

      begin
        parsed_book = parse_uploaded_file(file)

        result =
          BookImporter.new(
            user: current_user,
            parsed_book: parsed_book,
            slug: params[:slug],
            publish: params[:publish] == "true",
            access_level: params[:access_level] || "free",
          ).import!

        if result.success
          render json: {
                   success: true,
                   publication: serialize_author_publication_detail(result.publication),
                   chapters_created: result.chapters_created,
                   chapters_updated: result.chapters_updated,
                   errors: result.errors,
                 }
        else
          render json: { success: false, errors: result.errors }, status: :unprocessable_entity
        end
      rescue BookParser::ParseError => e
        render json: {
                 success: false,
                 errors: ["Parse error: #{e.message}"],
               },
               status: :unprocessable_entity
      rescue BookImporter::ImportError => e
        render json: {
                 success: false,
                 errors: ["Import error: #{e.message}"],
               },
               status: :unprocessable_entity
      end
    end

    # Re-import/update an existing publication
    def reimport_book
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      ensure_author_or_editor!(publication)

      file = params[:file]
      raise Discourse::InvalidParameters.new(:file) unless file

      begin
        parsed_book = parse_uploaded_file(file)

        result =
          BookImporter.new(
            user: current_user,
            parsed_book: parsed_book,
            publication_id: publication.id,
            replace_existing: params[:replace_existing] == "true",
            publish: params[:publish] == "true",
            access_level: params[:access_level] || "free",
          ).import!

        if result.success
          render json: {
                   success: true,
                   publication: serialize_author_publication_detail(result.publication),
                   chapters_created: result.chapters_created,
                   chapters_updated: result.chapters_updated,
                   errors: result.errors,
                 }
        else
          render json: { success: false, errors: result.errors }, status: :unprocessable_entity
        end
      rescue BookParser::ParseError => e
        render json: {
                 success: false,
                 errors: ["Parse error: #{e.message}"],
               },
               status: :unprocessable_entity
      rescue BookImporter::ImportError => e
        render json: {
                 success: false,
                 errors: ["Import error: #{e.message}"],
               },
               status: :unprocessable_entity
      end
    end

    private

    def parse_uploaded_file(file)
      filename = file.original_filename

      if filename.end_with?(".textpack", ".zip")
        # Handle compressed files
        BookParser.parse(file_path: file.tempfile.path)
      elsif filename.end_with?(".textbundle")
        # TextBundle as directory (unlikely via upload, but handle it)
        BookParser.parse(file_path: file.tempfile.path)
      else
        # Read content directly for text/markdown files
        content = file.read
        BookParser.parse(content: content, filename: filename)
      end
    end

    # Sync Discourse category permissions based on chapter access level and published status
    # Wrapped in a transaction to ensure atomic updates - if any step fails, permissions remain unchanged
    def sync_chapter_permissions(chapter, access_level, publication, published: nil)
      # Determine published status
      is_published =
        if published.nil?
          pub_val = chapter.custom_fields[CHAPTER_PUBLISHED]
          boolean_custom_field?(pub_val)
        else
          boolean_custom_field?(published)
        end

      ActiveRecord::Base.transaction do
        # Clear existing category group permissions
        CategoryGroup.where(category_id: chapter.id).delete_all

        # Unpublished chapters: only staff can see
        unless is_published
          CategoryGroup.create!(
            category_id: chapter.id,
            group_id: Group::AUTO_GROUPS[:staff],
            permission_type: CategoryGroup.permission_types[:full],
          )
          return
        end

        if access_level.blank? || access_level == "free"
          # Free published content: everyone can see
          CategoryGroup.create!(
            category_id: chapter.id,
            group_id: Group::AUTO_GROUPS[:everyone],
            permission_type: CategoryGroup.permission_types[:full],
          )
        else
          # Paid/tiered content: restrict to specific groups based on access tiers
          access_tiers = publication.custom_fields[PUBLICATION_ACCESS_TIERS] || {}
          required_tier_index = Bookclub::TIER_HIERARCHY.index(access_level) || 0

          allowed_groups = []

          access_tiers.each do |group_name, tier_level|
            next if group_name == "everyone"

            tier_index = Bookclub::TIER_HIERARCHY.index(tier_level) || 0
            next if tier_index < required_tier_index

            group = Group.find_by(name: group_name)
            allowed_groups << group.id if group
          end

          # Always allow staff full access
          CategoryGroup.create!(
            category_id: chapter.id,
            group_id: Group::AUTO_GROUPS[:staff],
            permission_type: CategoryGroup.permission_types[:full],
          )

          # Add allowed groups
          allowed_groups.each do |group_id|
            CategoryGroup.create!(
              category_id: chapter.id,
              group_id: group_id,
              permission_type: CategoryGroup.permission_types[:full],
            )
          end

          # If no groups have access, only staff can see it
          # This effectively hides paid content from non-subscribers
        end
      end
    end

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
        is_editor: guardian.is_publication_editor?(publication),
      }
    end

    def serialize_author_publication_detail(publication)
      chapters = find_chapters(publication)

      # Batch load content topics to avoid N+1 queries
      content_topics_by_chapter_id = batch_load_content_topics(chapters)

      sorted_chapters =
        chapters
          .map { |ch| serialize_author_chapter(ch, content_topics_by_chapter_id) }
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
        is_editor: guardian.is_publication_editor?(publication),
      }
    end

    def serialize_author_chapter(chapter, content_topics_by_chapter_id = nil)
      discussion_count = Topic.where(category_id: chapter.id).count - 1 # Exclude content topic

      # Use preloaded content topic if available to avoid N+1
      content_topic = if content_topics_by_chapter_id
        content_topics_by_chapter_id[chapter.id]
      else
        find_content_topic(chapter)
      end

      # Calculate posts count from discussion topics
      discussion_topics = find_discussion_topics(chapter)
      posts_count = Post.where(topic_id: discussion_topics.pluck(:id)).count

      {
        id: chapter.id,
        title: chapter.name,
        slug: chapter.slug,
        number: chapter.custom_fields[CHAPTER_NUMBER]&.to_i,
        type: chapter.custom_fields[CHAPTER_TYPE] || "chapter",
        published: chapter.custom_fields[CHAPTER_PUBLISHED] != false,
        access_level: chapter.custom_fields[CHAPTER_ACCESS_LEVEL] || "free",
        word_count: chapter.custom_fields[CHAPTER_WORD_COUNT].to_i,
        summary: chapter.custom_fields[CHAPTER_SUMMARY],
        review_status: chapter.custom_fields[CHAPTER_REVIEW_STATUS],
        created_at: chapter.created_at,
        updated_at: chapter.updated_at,
        discussion_count: [discussion_count, 0].max,
        posts_count: posts_count,
        content_topic_id: content_topic&.id,
        views: content_topic&.views || 0,
      }
    end

    def calculate_views(publication)
      chapters = find_chapters(publication)

      # Batch load content topics to avoid N+1 queries
      content_topics_by_chapter_id = batch_load_content_topics(chapters)
      content_topics = content_topics_by_chapter_id.values.compact

      {
        total: content_topics.sum(&:views),
        # Note: Discourse doesn't track views by time period, so we can't calculate last_7_days
        # This would require custom view tracking or TopicViewItem analysis
        last_7_days: nil,
        by_chapter:
          chapters.map do |ch|
            content_topic = content_topics_by_chapter_id[ch.id]
            { id: ch.id, title: ch.name, views: content_topic&.views || 0 }
          end,
      }
    end

    def calculate_engagement(publication)
      chapters = find_chapters(publication)
      publication_author_ids = publication.custom_fields[PUBLICATION_AUTHOR_IDS] || []
      chapter_ids = chapters.pluck(:id)

      return empty_engagement_stats if chapter_ids.empty?

      # Create hash for O(1) chapter lookups instead of linear search
      chapters_by_id = chapters.index_by(&:id)

      # Build discussion topics query (non-content topics in chapters)
      # NOTE: Discourse stores boolean true as "t" in custom fields
      discussion_topics_sql = Topic
        .where(category_id: chapter_ids)
        .joins(
          "LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = '#{CONTENT_TOPIC}'",
        )
        .where("tcf.value IS NULL OR tcf.value NOT IN (?)", %w[t true])

      # Use SQL COUNT for aggregates instead of loading all records
      total_discussions = discussion_topics_sql.count
      discussion_topic_ids = discussion_topics_sql.limit(10000).pluck(:id) # Cap for safety

      # Use SQL aggregates for post counts
      total_posts = Post.where(topic_id: discussion_topic_ids).count
      unique_participants = Post.where(topic_id: discussion_topic_ids).distinct.count(:user_id)

      # Find unanswered questions using SQL NOT EXISTS instead of N+1 queries
      unanswered_query = discussion_topics_sql.where("topics.posts_count > 1")

      if publication_author_ids.any?
        # Use NOT EXISTS subquery to avoid N+1 queries
        unanswered_query = unanswered_query.where(
          "NOT EXISTS (SELECT 1 FROM posts p WHERE p.topic_id = topics.id AND p.user_id IN (?))",
          publication_author_ids
        )
      end

      unanswered_count = unanswered_query.count

      # Recent unanswered questions (limited query, not loading all into memory)
      recent_unanswered =
        unanswered_query
          .order(created_at: :desc)
          .limit(5)
          .map do |topic|
            chapter = chapters_by_id[topic.category_id]
            {
              id: topic.id,
              title: topic.title,
              chapter: {
                id: chapter&.id,
                title: chapter&.name,
                number: chapter&.custom_fields&.[](CHAPTER_NUMBER)&.to_i,
              },
              posts_count: topic.posts_count,
              created_at: topic.created_at,
              last_posted_at: topic.last_posted_at,
            }
          end

      # Recent activity - only load what we need
      recent_posts = Post
        .where(topic_id: discussion_topic_ids)
        .order(created_at: :desc)
        .limit(10)
        .includes(:user, :topic)

      {
        total_discussions: total_discussions,
        total_posts: total_posts,
        unique_participants: unique_participants,
        unanswered_questions_count: unanswered_count,
        unanswered_questions: recent_unanswered,
        recent_activity:
          recent_posts.map do |post|
            # Skip posts with deleted users
            next unless post.user

            chapter = chapters_by_id[post.topic.category_id]
            {
              id: post.id,
              topic_id: post.topic_id,
              topic_title: post.topic.title,
              chapter: {
                id: chapter&.id,
                title: chapter&.name,
                number: chapter&.custom_fields&.[](CHAPTER_NUMBER)&.to_i,
              },
              excerpt: post.excerpt(200),
              user: {
                id: post.user.id,
                username: post.user.username,
                avatar_url: post.user.avatar_template_url.gsub("{size}", "45"),
              },
              created_at: post.created_at,
            }
          end.compact,
      }
    end

    def empty_engagement_stats
      {
        total_discussions: 0,
        total_posts: 0,
        unique_participants: 0,
        unanswered_questions_count: 0,
        unanswered_questions: [],
        recent_activity: [],
      }
    end

    # Maximum number of user records to process for analytics
    # Beyond this, stats are estimated from the sample
    MAX_ANALYTICS_USERS = 1000

    def calculate_reader_progress(publication)
      chapters = find_chapters(publication)
      publication_slug = publication.custom_fields[PUBLICATION_SLUG]

      # Cache total chapters count outside loop
      total_chapters = chapters.count
      return {
        total_readers: 0,
        completed_readers: 0,
        average_progress: 0,
        by_chapter: [],
        truncated: false,
      } if total_chapters.zero?

      # Pre-compute chapter IDs for faster Set lookups
      chapter_ids = chapters.map(&:id)

      # Find all users who have reading progress for this publication
      # Use LIKE query as a fallback since JSONB ? operator may not work in all cases
      user_progress_query =
        UserCustomField.where(name: READING_PROGRESS).where(
          "value LIKE ?",
          "%\"#{publication_slug}\"%",
        )

      total_readers = user_progress_query.count
      truncated = total_readers > MAX_ANALYTICS_USERS
      sample_size = [total_readers, MAX_ANALYTICS_USERS].min

      completed_readers = 0
      total_completion_percentage = 0.0
      processed_count = 0

      # Build chapter-level progress data
      chapter_progress = {}
      chapter_ids.each { |id| chapter_progress[id] = { started: 0, completed: 0 } }

      # Use find_each for batched processing with a hard limit to prevent unbounded processing
      user_progress_query.limit(MAX_ANALYTICS_USERS).find_each(batch_size: 100) do |user_field|
        begin
          progress = JSON.parse(user_field.value)
        rescue JSON::ParserError
          next
        end

        pub_progress = progress[publication_slug]
        next unless pub_progress

        processed_count += 1

        # Use Set for O(1) membership tests instead of Array#include?
        completed_chapters = Set.new(pub_progress["completed"] || [])

        completion_percentage = (completed_chapters.length.to_f / total_chapters) * 100
        total_completion_percentage += completion_percentage

        completed_readers += 1 if completion_percentage >= 100

        # Track per-chapter progress using Set for fast lookups
        current_content_id = pub_progress["current_content_id"]

        chapter_ids.each do |chapter_id|
          if completed_chapters.include?(chapter_id)
            chapter_progress[chapter_id][:completed] += 1
            chapter_progress[chapter_id][:started] += 1
          elsif current_content_id == chapter_id
            chapter_progress[chapter_id][:started] += 1
          end
        end
      end

      # If truncated, extrapolate to estimate full counts
      if truncated && processed_count > 0
        scale_factor = total_readers.to_f / processed_count
        completed_readers = (completed_readers * scale_factor).round
        chapter_ids.each do |id|
          chapter_progress[id][:started] = (chapter_progress[id][:started] * scale_factor).round
          chapter_progress[id][:completed] = (chapter_progress[id][:completed] * scale_factor).round
        end
      end

      average_progress =
        processed_count.positive? ? (total_completion_percentage / processed_count).round(1) : 0

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
            completion_rate: completion_rate,
          }
        end

      {
        total_readers: total_readers,
        completed_readers: completed_readers,
        average_progress: average_progress,
        by_chapter: by_chapter,
        truncated: truncated,
        sample_size: truncated ? sample_size : nil,
      }
    end

    # Batch load content topics for multiple chapters to avoid N+1 queries
    def batch_load_content_topics(chapters)
      return {} if chapters.empty?

      chapter_ids = chapters.map(&:id)

      # Load all content topics in a single query
      content_topics = Topic
        .where(category_id: chapter_ids)
        .joins(
          "INNER JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = '#{CONTENT_TOPIC}'"
        )
        .where('tcf.value IN (?)', %w[t true])
        .to_a

      # Create a hash mapping chapter_id to content_topic
      content_topics.each_with_object({}) do |topic, hash|
        hash[topic.category_id] = topic
      end
    end
  end
end
