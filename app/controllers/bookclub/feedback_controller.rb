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

      topic = find_content_topic(publication, params[:number])
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
            guardian.is_publication_author?(publication) ||
              guardian.is_publication_editor?(publication) || post.user_id == current_user&.id
          when 'reviewers_only'
            guardian.is_publication_author?(publication) ||
              guardian.is_publication_editor?(publication) || is_reviewer?(topic, current_user)
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

      topic = find_content_topic(publication, params[:number])
      raise Discourse::NotFound unless topic

      ensure_content_access!(topic)

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
      unless post.user_id == current_user.id || guardian.is_publication_author?(publication) ||
             guardian.is_publication_editor?(publication) || guardian.is_admin?
        raise Discourse::InvalidAccess
      end

      # Update allowed fields
      if params.key?(:visibility) &&
         (
           guardian.is_publication_author?(publication) ||
             guardian.is_publication_editor?(publication) || post.user_id == current_user.id
         )
        post.custom_fields[FEEDBACK_VISIBILITY_FIELD] = params[:visibility]
      end

      if params.key?(:status) &&
         (
           guardian.is_publication_author?(publication) ||
             guardian.is_publication_editor?(publication)
         )
        post.custom_fields[FEEDBACK_STATUS_FIELD] = params[:status]
      end

      post.save_custom_fields

      render json: { success: true, feedback: serialize_feedback(post, publication) }
    end

    def destroy
      post = Post.find(params[:id])
      raise Discourse::NotFound unless post

      topic = post.topic
      topic.category

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

      # Optionally notify the suggester
      # TODO: Implement notification

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

      render json: { success: true, feedback: serialize_feedback(post, publication) }
    end

    private

    def serialize_feedback(post, publication)
      anchor = post.custom_fields[FEEDBACK_ANCHOR_FIELD]

      {
        id: post.id,
        post_number: post.post_number,
        feedback_type: post.custom_fields[FEEDBACK_TYPE_FIELD],
        visibility: post.custom_fields[FEEDBACK_VISIBILITY_FIELD] || 'public',
        status: post.custom_fields[FEEDBACK_STATUS_FIELD] || 'pending',
        attribution: post.custom_fields[FEEDBACK_ATTRIBUTION_FIELD] != false,
        anchor: anchor.present? ? JSON.parse(anchor) : nil,
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
          post.user_id == current_user&.id || guardian.is_publication_author?(publication) ||
            guardian.is_publication_editor?(publication),
        can_moderate:
          guardian.is_publication_author?(publication) ||
            guardian.is_publication_editor?(publication) || guardian.is_admin?
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
