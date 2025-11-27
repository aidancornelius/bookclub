# frozen_string_literal: true

module Bookclub
  class BookmarksController < BaseController
    READING_POSITION_NAME = "Bookclub: Continue reading"

    before_action :ensure_logged_in

    # GET /bookclub/reading-bookmark
    # Returns the user's current reading position bookmark (if any)
    def show
      bookmark = find_reading_position_bookmark

      if bookmark
        render json: {
          bookmark: serialize_bookmark(bookmark),
          publication_slug: get_publication_slug(bookmark),
          chapter_number: get_chapter_number(bookmark)
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

      # Remove any existing reading position bookmarks
      remove_existing_reading_bookmarks

      # Create new bookmark using BookmarkManager
      bookmark_manager = BookmarkManager.new(current_user)
      result = bookmark_manager.create_for(
        bookmarkable_id: topic.id,
        bookmarkable_type: "Topic",
        name: READING_POSITION_NAME,
        options: {
          auto_delete_preference: Bookmark::AUTO_DELETE_PREFERENCES[:never]
        }
      )

      if bookmark_manager.errors.empty?
        bookmark = Bookmark.find_by(id: result[:bookmark_id] || result.try(:id))
        render json: {
          success: true,
          bookmark: bookmark ? serialize_bookmark(bookmark) : nil
        }
      else
        render json: {
          success: false,
          errors: bookmark_manager.errors.full_messages
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

    def find_reading_position_bookmark
      current_user.bookmarks
        .where(name: READING_POSITION_NAME, bookmarkable_type: "Topic")
        .order(created_at: :desc)
        .first
    end

    def remove_existing_reading_bookmarks
      bookmarks = current_user.bookmarks
        .where(name: READING_POSITION_NAME, bookmarkable_type: "Topic")

      count = bookmarks.count
      bookmarks.destroy_all
      count
    end

    def get_publication_slug(bookmark)
      return nil unless bookmark.bookmarkable_type == "Topic"

      topic = Topic.find_by(id: bookmark.bookmarkable_id)
      return nil unless topic

      # Find the chapter (category) and its parent publication
      chapter = topic.category
      return nil unless chapter

      publication = chapter.parent_category
      return nil unless publication

      publication.custom_fields[PUBLICATION_SLUG]
    end

    def get_chapter_number(bookmark)
      return nil unless bookmark.bookmarkable_type == "Topic"

      topic = Topic.find_by(id: bookmark.bookmarkable_id)
      return nil unless topic

      chapter = topic.category
      return nil unless chapter

      chapter.custom_fields[CHAPTER_NUMBER]&.to_i
    end

    def serialize_bookmark(bookmark)
      {
        id: bookmark.id,
        name: bookmark.name,
        bookmarkable_type: bookmark.bookmarkable_type,
        bookmarkable_id: bookmark.bookmarkable_id,
        created_at: bookmark.created_at,
        updated_at: bookmark.updated_at
      }
    end
  end
end
