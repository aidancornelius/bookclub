# frozen_string_literal: true

module Bookclub
  class ChapterBookmarkable < BaseBookmarkable
    def self.model
      BookclubReadingPosition
    end

    def self.serializer
      Bookclub::ChapterBookmarkSerializer
    end

    def self.preload_associations
      [topic: :category]
    end

    def self.list_query(user, guardian)
      user
        .bookmarks_of_type("BookclubReadingPosition")
        .joins(
          "INNER JOIN bookclub_reading_positions ON bookclub_reading_positions.id = bookmarks.bookmarkable_id"
        )
        .joins("INNER JOIN topics ON topics.id = bookclub_reading_positions.topic_id")
        .where("topics.deleted_at IS NULL")
    end

    def self.search_query(bookmarks, query, ts_query, &bookmarkable_search)
      bookmarkable_search.call(bookmarks, "topics.title ILIKE ?")
    end

    def self.reminder_handler(bookmark)
      reading_position = bookmark.bookmarkable
      return unless reading_position

      send_reminder_notification(
        bookmark,
        data: {
          title: "Continue reading: #{reading_position.chapter_title}",
          bookmarkable_url: reading_position.bookclub_url || reading_position.topic&.url
        }
      )
    end

    def self.reminder_conditions(bookmark)
      bookmark.bookmarkable.present? && bookmark.bookmarkable.topic.present?
    end

    def self.can_see?(guardian, bookmark)
      return false unless bookmark&.bookmarkable&.topic
      guardian.can_see_topic?(bookmark.bookmarkable.topic)
    end

    def self.can_see_bookmarkable?(guardian, bookmarkable)
      return false unless bookmarkable&.topic
      guardian.can_see_topic?(bookmarkable.topic)
    end

    def self.cleanup_deleted
      DB.query(<<~SQL)
        DELETE FROM bookmarks b
        USING bookclub_reading_positions brp
        LEFT JOIN topics t ON t.id = brp.topic_id
        WHERE b.bookmarkable_id = brp.id
        AND b.bookmarkable_type = 'BookclubReadingPosition'
        AND (t.id IS NULL OR t.deleted_at IS NOT NULL)
      SQL
    end
  end
end
