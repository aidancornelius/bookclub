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
                cover_url: publication.custom_fields[PUBLICATION_COVER_URL],
              },
              progress: enrich_progress(publication, pub_progress),
            }
          end
          .compact

      render json: { reading_progress: enriched }
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
                 slug: params[:publication_slug],
               },
               progress: enrich_progress(publication, pub_progress),
             }
    end

    def update
      publication = find_publication_category(params[:publication_slug])
      raise Discourse::NotFound unless publication

      progress = current_user.custom_fields[READING_PROGRESS] || {}
      pub_slug = params[:publication_slug]

      progress[pub_slug] ||= {}

      # Update allowed fields
      if params[:current_content_id]
        progress[pub_slug]["current_content_id"] = params[:current_content_id].to_i
      end

      if params[:current_content_number]
        progress[pub_slug]["current_content_number"] = params[:current_content_number].to_i
      end

      if params[:scroll_position]
        progress[pub_slug]["scroll_position"] = params[:scroll_position].to_f
      end

      if params[:mark_completed]
        content_id = params[:mark_completed].to_i
        progress[pub_slug]["completed"] ||= []
        if progress[pub_slug]["completed"].exclude?(content_id)
          progress[pub_slug]["completed"] << content_id
        end
      end

      if params[:mark_uncompleted]
        content_id = params[:mark_uncompleted].to_i
        progress[pub_slug]["completed"] ||= []
        progress[pub_slug]["completed"].delete(content_id)
      end

      progress[pub_slug]["last_read_at"] = Time.current.iso8601

      current_user.custom_fields[READING_PROGRESS] = progress
      current_user.save_custom_fields

      render json: { success: true, progress: enrich_progress(publication, progress[pub_slug]) }
    end

    private

    def enrich_progress(publication, pub_progress)
      total_contents = Topic.where(category_id: publication.id).where(visible: true).count
      completed_count = (pub_progress["completed"] || []).length

      {
        current_content_id: pub_progress["current_content_id"],
        current_content_number: pub_progress["current_content_number"],
        scroll_position: pub_progress["scroll_position"],
        last_read_at: pub_progress["last_read_at"],
        completed: pub_progress["completed"] || [],
        completed_count: completed_count,
        total_count: total_contents,
        percentage:
          total_contents > 0 ? ((completed_count.to_f / total_contents) * 100).round(1) : 0,
      }
    end
  end
end
