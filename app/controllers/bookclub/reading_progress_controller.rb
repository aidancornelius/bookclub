# frozen_string_literal: true

module Bookclub
  class ReadingProgressController < BaseController
    before_action :ensure_logged_in

    def index
      progress = current_user.custom_fields[READING_PROGRESS] || {}

      # Enrich with publication details
      enriched =
        progress
        .map do |pub_slug, pub_progress|
          publication = find_publication_category(pub_slug)
          next nil unless publication

          {
            publication: {
              id: publication.id,
              name: publication.name,
              slug: pub_slug,
              type: publication.custom_fields[PUBLICATION_TYPE],
              cover_url: publication.custom_fields[PUBLICATION_COVER_URL]
            },
            progress: enrich_progress(publication, pub_progress)
          }
        end
          .compact

      render json: { reading_progress: enriched, streak: get_reading_streak(current_user) }
    end

    def show
      publication = find_publication_category(params[:publication_slug])
      raise Discourse::NotFound unless publication

      progress = current_user.custom_fields[READING_PROGRESS] || {}
      pub_progress = progress[params[:publication_slug]] || {}

      render json: {
        publication: {
          id: publication.id,
          name: publication.name,
          slug: params[:publication_slug]
        },
        progress: enrich_progress(publication, pub_progress),
        streak: get_reading_streak(current_user)
      }
    end

    def streak
      render json: { streak: get_reading_streak(current_user) }
    end

    def update
      publication = find_publication_category(params[:publication_slug])
      raise Discourse::NotFound unless publication

      progress = current_user.custom_fields[READING_PROGRESS] || {}
      pub_slug = params[:publication_slug]

      progress[pub_slug] ||= {}
      progress[pub_slug]['chapters'] ||= {}

      # Update allowed fields
      progress[pub_slug]['current_content_id'] = params[:current_content_id].to_i if params[
        :current_content_id
      ]

      if params[:current_content_number]
        progress[pub_slug]['current_content_number'] = params[:current_content_number].to_i
      end

      # Track per-chapter progress
      if params[:content_id] && (params[:scroll_position] || params[:mark_completed])
        content_id = params[:content_id].to_i
        progress[pub_slug]['chapters'][content_id.to_s] ||= {}

        if params[:scroll_position]
          progress[pub_slug]['chapters'][content_id.to_s]['scroll_position'] = params[
            :scroll_position
          ].to_f
          progress[pub_slug]['chapters'][content_id.to_s]['read_at'] = Time.current.iso8601
        end

        if params[:mark_completed]
          progress[pub_slug]['chapters'][content_id.to_s]['completed'] = true
          progress[pub_slug]['chapters'][content_id.to_s]['completed_at'] = Time.current.iso8601
        end
      end

      # Legacy support: track at publication level
      progress[pub_slug]['scroll_position'] = params[:scroll_position].to_f if params[
        :scroll_position
      ]

      # Legacy completed array
      if params[:mark_completed]
        content_id = params[:mark_completed].to_i
        progress[pub_slug]['completed'] ||= []
        progress[pub_slug]['completed'] << content_id if progress[pub_slug]['completed'].exclude?(content_id)
      end

      if params[:mark_uncompleted]
        content_id = params[:mark_uncompleted].to_i
        progress[pub_slug]['completed'] ||= []
        progress[pub_slug]['completed'].delete(content_id)

        # Also update per-chapter tracking
        if progress[pub_slug]['chapters'][content_id.to_s]
          progress[pub_slug]['chapters'][content_id.to_s]['completed'] = false
        end
      end

      progress[pub_slug]['last_read_at'] = Time.current.iso8601

      # Update reading streak
      update_reading_streak(current_user)

      current_user.custom_fields[READING_PROGRESS] = progress
      current_user.save_custom_fields

      render json: {
        success: true,
        progress: enrich_progress(publication, progress[pub_slug]),
        streak: get_reading_streak(current_user)
      }
    end

    private

    def enrich_progress(publication, pub_progress)
      # Get all chapters (subcategories) for this publication
      chapters = find_chapters(publication)
      chapter_ids = chapters.map(&:id)

      # Count content topics across all chapter subcategories
      # Content topics are marked with CONTENT_TOPIC custom field
      total_contents = Topic
        .where(category_id: chapter_ids, visible: true)
        .joins("INNER JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = '#{CONTENT_TOPIC}'")
        .where('tcf.value IN (?)', %w[t true])
        .count

      completed_count = (pub_progress['completed'] || []).length

      # Build per-chapter progress details
      chapters_progress = {}
      pub_progress['chapters']&.each do |content_id, chapter_data|
        chapters_progress[content_id] = {
          scroll_position: chapter_data['scroll_position'] || 0,
          read_at: chapter_data['read_at'],
          completed: chapter_data['completed'] || false,
          completed_at: chapter_data['completed_at']
        }
      end

      {
        current_content_id: pub_progress['current_content_id'],
        current_content_number: pub_progress['current_content_number'],
        scroll_position: pub_progress['scroll_position'],
        last_read_at: pub_progress['last_read_at'],
        completed: pub_progress['completed'] || [],
        completed_count: completed_count,
        total_count: total_contents,
        percentage:
          total_contents.positive? ? ((completed_count.to_f / total_contents) * 100).round(1) : 0,
        chapters: chapters_progress
      }
    end

    def update_reading_streak(user)
      streak_data = PluginStore.get(PLUGIN_NAME, "reading_streak_#{user.id}") || {}

      today = Date.current.to_s
      last_read_date = streak_data['last_read_date']

      # If no previous read or reading today for first time
      if last_read_date.nil?
        streak_data['current_streak'] = 1
        streak_data['longest_streak'] = [streak_data['longest_streak'] || 0, 1].max
        streak_data['last_read_date'] = today
        streak_data['streak_start_date'] = today
      elsif last_read_date == today
        # Already read today, no change
        return
      elsif last_read_date == (Date.current - 1.day).to_s
        # Consecutive day
        streak_data['current_streak'] = (streak_data['current_streak'] || 0) + 1
        streak_data['longest_streak'] = [
          streak_data['longest_streak'] || 0,
          streak_data['current_streak']
        ].max
        streak_data['last_read_date'] = today
      else
        # Streak broken
        streak_data['current_streak'] = 1
        streak_data['longest_streak'] ||= 0
        streak_data['last_read_date'] = today
        streak_data['streak_start_date'] = today
      end

      PluginStore.set(PLUGIN_NAME, "reading_streak_#{user.id}", streak_data)
    end

    def get_reading_streak(user)
      streak_data = PluginStore.get(PLUGIN_NAME, "reading_streak_#{user.id}") || {}

      # Check if streak is still valid (read today or yesterday)
      last_read_date = streak_data['last_read_date']
      current_streak = 0

      if last_read_date
        days_since = (Date.current - Date.parse(last_read_date)).to_i
        current_streak = streak_data['current_streak'] || 0 if days_since <= 1
      end

      {
        current_streak: current_streak,
        longest_streak: streak_data['longest_streak'] || 0,
        last_read_date: streak_data['last_read_date'],
        streak_start_date: streak_data['streak_start_date']
      }
    end
  end
end
