# frozen_string_literal: true

module Bookclub
  class FeedbackController < BaseController
    before_action :ensure_logged_in, except: [:index]

    # Feedback is stored as posts with custom fields
    FEEDBACK_TYPE_FIELD = 'bookclub_feedback_type'
    FEEDBACK_ANCHOR_FIELD = 'bookclub_feedback_anchor'
    FEEDBACK_VISIBILITY_FIELD = 'bookclub_feedback_visibility'
    FEEDBACK_STATUS_FIELD = 'bookclub_feedback_status'
    FEEDBACK_ATTRIBUTION_FIELD = 'bookclub_feedback_attribution'

    def index
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      chapter = find_chapter(publication, params[:chapter_id])
      raise Discourse::NotFound unless chapter

      topic = find_content_topic(chapter)
      raise Discourse::NotFound unless topic

      # Get feedback settings
      feedback_settings = publication.custom_fields[PUBLICATION_FEEDBACK_SETTINGS] || {}

      # Get all feedback posts (replies with feedback type set)
      posts =
        Post
        .where(topic_id: topic.id)
        .where.not(post_number: 1)
        .joins(
          "LEFT JOIN post_custom_fields pcf ON pcf.post_id = posts.id AND pcf.name = '#{FEEDBACK_TYPE_FIELD}'"
        )
        .where('pcf.value IS NOT NULL')
        .includes(:user)

      # Filter by visibility based on current user
      visible_feedback =
        posts.select do |post|
          visibility = post.custom_fields[FEEDBACK_VISIBILITY_FIELD] || 'public'
          case visibility
          when 'public'
            true
          when 'author_only'
            guardian.can_manage_publication?(publication) || post.user_id == current_user&.id
          when 'reviewers_only'
            guardian.can_manage_publication?(publication) || is_reviewer?(topic, current_user)
          else
            true
          end
        end

      render json: {
        feedback: visible_feedback.map { |post| serialize_feedback(post, publication) },
        settings: {
          inline_comments: feedback_settings['inline_comments'] != false,
          suggestions: feedback_settings['suggestions'] != false,
          formal_reviews: feedback_settings['formal_reviews'] == true,
          endorsements: feedback_settings['endorsements'] != false
        }
      }
    end

    def create
      publication = find_publication_category(params[:slug])
      raise Discourse::NotFound unless publication

      chapter = find_chapter(publication, params[:chapter_id])
      raise Discourse::NotFound unless chapter

      topic = find_content_topic(chapter)
      raise Discourse::NotFound unless topic

      ensure_chapter_access!(chapter)

      feedback_type = params[:feedback_type]
      feedback_settings = publication.custom_fields[PUBLICATION_FEEDBACK_SETTINGS] || {}

      # Validate feedback type is enabled
      case feedback_type
      when 'comment'
        if feedback_settings['inline_comments'] == false
          return render json: { error: 'inline_comments_disabled' }, status: :forbidden
        end
      when 'suggestion'
        if feedback_settings['suggestions'] == false
          return render json: { error: 'suggestions_disabled' }, status: :forbidden
        end
      when 'review'
        unless feedback_settings['formal_reviews'] == true
          return render json: { error: 'formal_reviews_disabled' }, status: :forbidden
        end
      when 'endorsement'
        if feedback_settings['endorsements'] == false
          return render json: { error: 'endorsements_disabled' }, status: :forbidden
        end
      else
        return render json: { error: 'invalid_feedback_type' }, status: :bad_request
      end

      # Create the post
      post_creator =
        PostCreator.new(
          current_user,
          topic_id: topic.id,
          raw: params[:body],
          skip_validations: false
        )

      post = post_creator.create

      if post.persisted?
        # Set feedback custom fields
        post.custom_fields[FEEDBACK_TYPE_FIELD] = feedback_type
        post.custom_fields[FEEDBACK_VISIBILITY_FIELD] = params[:visibility] || 'public'
        post.custom_fields[FEEDBACK_STATUS_FIELD] = 'pending'
        post.custom_fields[FEEDBACK_ATTRIBUTION_FIELD] = params[:attribution] != false

        # Store anchor for inline feedback
        post.custom_fields[FEEDBACK_ANCHOR_FIELD] = params[:anchor].to_json if params[:anchor].present?

        post.save_custom_fields

        render json: { success: true, feedback: serialize_feedback(post, publication) }
      else
        render json: {
                 success: false,
                 errors: post_creator.errors.full_messages
               },
               status: :unprocessable_entity
      end
    end

    def update
      post = Post.find(params[:id])
      raise Discourse::NotFound unless post

      topic = post.topic
      publication = topic.category
      raise Discourse::NotFound unless publication.custom_fields[PUBLICATION_ENABLED]

      # Only allow update by author, publication author/editor, or admin
      unless post.user_id == current_user.id || guardian.can_manage_publication?(publication)
        raise Discourse::InvalidAccess
      end

      # Update allowed fields
      if params.key?(:visibility) &&
         (guardian.can_manage_publication?(publication) || post.user_id == current_user.id)
        post.custom_fields[FEEDBACK_VISIBILITY_FIELD] = params[:visibility]
      end

      if params.key?(:status) && guardian.can_manage_publication?(publication)
        post.custom_fields[FEEDBACK_STATUS_FIELD] = params[:status]
      end

      post.save_custom_fields

      render json: { success: true, feedback: serialize_feedback(post, publication) }
    end

    def destroy
      post = Post.find(params[:id])
      raise Discourse::NotFound unless post

      topic = post.topic
      publication = topic.category

      # Only allow delete by author or admins
      raise Discourse::InvalidAccess unless post.user_id == current_user.id || guardian.is_admin?

      PostDestroyer.new(current_user, post).destroy

      render json: { success: true }
    end

    def accept_suggestion
      post = Post.find(params[:id])
      raise Discourse::NotFound unless post

      topic = post.topic
      publication = topic.category
      raise Discourse::NotFound unless publication.custom_fields[PUBLICATION_ENABLED]

      ensure_author_or_editor!(publication)

      # Verify this is a suggestion
      unless post.custom_fields[FEEDBACK_TYPE_FIELD] == 'suggestion'
        return render json: { error: 'not_a_suggestion' }, status: :bad_request
      end

      post.custom_fields[FEEDBACK_STATUS_FIELD] = 'accepted'
      post.save_custom_fields

      notify_suggestion_author(post, publication, 'accepted')

      render json: { success: true, feedback: serialize_feedback(post, publication) }
    end

    def decline_suggestion
      post = Post.find(params[:id])
      raise Discourse::NotFound unless post

      topic = post.topic
      publication = topic.category
      raise Discourse::NotFound unless publication.custom_fields[PUBLICATION_ENABLED]

      ensure_author_or_editor!(publication)

      unless post.custom_fields[FEEDBACK_TYPE_FIELD] == 'suggestion'
        return render json: { error: 'not_a_suggestion' }, status: :bad_request
      end

      post.custom_fields[FEEDBACK_STATUS_FIELD] = 'declined'
      post.save_custom_fields

      notify_suggestion_author(post, publication, 'declined')

      render json: { success: true, feedback: serialize_feedback(post, publication) }
    end

    private

    def serialize_feedback(post, publication)
      anchor = post.custom_fields[FEEDBACK_ANCHOR_FIELD]

      # Guard against corrupted JSON in anchor field
      parsed_anchor = nil
      if anchor.present?
        begin
          parsed_anchor = JSON.parse(anchor)
        rescue JSON::ParserError => e
          Rails.logger.warn("[Bookclub] Invalid JSON in feedback anchor for post #{post.id}: #{e.message}")
          parsed_anchor = nil
      end
    end

    def notify_suggestion_author(post, publication, status)
      Notification.create!(
        user_id: post.user_id,
        notification_type: Notification.types[:custom],
        topic_id: post.topic_id,
        post_number: post.post_number,
        data: {
          message: "Suggestion #{status} for #{publication.name}",
          display_username: current_user.username
        }.to_json
      )
    rescue StandardError => e
      Rails.logger.error(
        "[Bookclub] Failed to notify suggestion author for post #{post.id}: #{e.class.name} - #{e.message}"
      )
    end

      {
        id: post.id,
        post_number: post.post_number,
        feedback_type: post.custom_fields[FEEDBACK_TYPE_FIELD],
        visibility: post.custom_fields[FEEDBACK_VISIBILITY_FIELD] || 'public',
        status: post.custom_fields[FEEDBACK_STATUS_FIELD] || 'pending',
        attribution: post.custom_fields[FEEDBACK_ATTRIBUTION_FIELD] != false,
        anchor: parsed_anchor,
        body: post.cooked,
        raw: post.raw,
        created_at: post.created_at,
        updated_at: post.updated_at,
        user: {
          id: post.user.id,
          username: post.user.username,
          name: post.user.name,
          avatar_url: post.user.avatar_template_url.gsub('{size}', '45')
        },
        can_edit:
          post.user_id == current_user&.id || guardian.can_manage_publication?(publication),
        can_moderate:
          guardian.can_manage_publication?(publication)
      }
    end

    def is_reviewer?(topic, user)
      return false unless user

      # Check if user has submitted a formal review
      Post
        .where(topic_id: topic.id, user_id: user.id)
        .joins(
          "LEFT JOIN post_custom_fields pcf ON pcf.post_id = posts.id AND pcf.name = '#{FEEDBACK_TYPE_FIELD}'"
        )
        .where("pcf.value = 'review'")
        .exists?
    end
  end
end
