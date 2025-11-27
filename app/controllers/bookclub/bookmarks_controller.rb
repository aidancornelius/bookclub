# frozen_string_literal: true

module Bookclub
  class BookmarksController < BaseController
    READING_POSITION_NAME = "Bookclub: Continue reading"

    before_action :ensure_logged_in

    # GET /bookclub/reading-bookmark
    # Returns the user's current reading position bookmark (if any)
    def show
      reading_position = find_current_reading_position
      bookmark = reading_position&.bookmarks&.where(user_id: current_user.id)&.first

      if reading_position && bookmark
        render json: {
          bookmark: serialize_bookmark(bookmark, reading_position),
          publication_slug: reading_position.publication_slug,
          chapter_number: reading_position.chapter_number
        }
      else
        render json: { bookmark: nil }
      end
    end

    # POST /bookclub/reading-bookmark
    # Creates or updates the reading position bookmark
    # Only keeps the latest one (removes any existing reading position bookmarks)
    def create
      topic_id = params.require(:topic_id)
      topic = Topic.find_by(id: topic_id)

      raise Discourse::NotFound unless topic

      # Remove any existing reading position bookmarks for this user
      remove_existing_reading_bookmarks

      # Find or create reading position record
      reading_position = BookclubReadingPosition.find_or_create_by!(
        user_id: current_user.id,
        topic_id: topic.id
      )

      # Create bookmark for this reading position
      bookmark = Bookmark.create(
        user_id: current_user.id,
        bookmarkable: reading_position,
        name: READING_POSITION_NAME,
        auto_delete_preference: 0 # NEVER
      )

      if bookmark.persisted?
        render json: {
          success: true,
          bookmark: serialize_bookmark(bookmark, reading_position)
        }
      else
        render json: {
          success: false,
          errors: bookmark.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    # DELETE /bookclub/reading-bookmark
    # Removes the reading position bookmark
    def destroy
      count = remove_existing_reading_bookmarks
      render json: { success: true, removed_count: count }
    end

    private

    def find_current_reading_position
      # Find the user's most recent reading position with a bookmark
      BookclubReadingPosition
        .joins(:bookmarks)
        .where(user_id: current_user.id)
        .where(bookmarks: { user_id: current_user.id, name: READING_POSITION_NAME })
        .order("bookmarks.created_at DESC")
        .first
    end

    def remove_existing_reading_bookmarks
      # Remove all reading position bookmarks for this user
      bookmarks = current_user.bookmarks
        .where(bookmarkable_type: "BookclubReadingPosition", name: READING_POSITION_NAME)

      count = bookmarks.count

      # Also clean up orphaned reading positions
      reading_position_ids = bookmarks.pluck(:bookmarkable_id)
      bookmarks.destroy_all

      # Remove reading positions that no longer have bookmarks
      if reading_position_ids.any?
        BookclubReadingPosition
          .where(id: reading_position_ids, user_id: current_user.id)
          .left_joins(:bookmarks)
          .where(bookmarks: { id: nil })
          .destroy_all
      end

      count
    end

    def serialize_bookmark(bookmark, reading_position)
      {
        id: bookmark.id,
        name: bookmark.name,
        bookmarkable_type: bookmark.bookmarkable_type,
        bookmarkable_id: bookmark.bookmarkable_id,
        topic_id: reading_position.topic_id,
        publication_slug: reading_position.publication_slug,
        chapter_number: reading_position.chapter_number,
        bookclub_url: reading_position.bookclub_url,
        created_at: bookmark.created_at,
        updated_at: bookmark.updated_at
      }
    end
  end
end
