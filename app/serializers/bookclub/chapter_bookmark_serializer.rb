# frozen_string_literal: true

module Bookclub
  class ChapterBookmarkSerializer < UserBookmarkBaseSerializer
    def title
      reading_position&.chapter_title || "Continue reading"
    end

    def fancy_title
      reading_position&.chapter_title || "Continue reading"
    end

    def cooked
      reading_position&.topic&.first_post&.cooked
    end

    def bookmarkable_url
      reading_position&.bookclub_url || reading_position&.topic&.url || "/"
    end

    def excerpt
      return nil unless cooked

      @excerpt ||= PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
    end

    def bookmarkable_user
      reading_position&.topic&.user
    end

    private

    def reading_position
      object.bookmarkable
    end
  end
end
