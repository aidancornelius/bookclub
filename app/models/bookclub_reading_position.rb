# frozen_string_literal: true

# A thin wrapper model to represent a reading position for bookmarking purposes
# This allows us to have a custom bookmarkable type with custom URL handling
class BookclubReadingPosition < ActiveRecord::Base
  self.table_name = 'bookclub_reading_positions'

  belongs_to :user
  belongs_to :topic
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy

  validates :user_id, presence: true
  validates :topic_id, presence: true
  validates :user_id, uniqueness: { scope: :topic_id }

  # Get the chapter category from the topic
  def chapter
    topic&.category
  end

  # Get the publication category (parent of chapter)
  def publication
    chapter&.parent_category
  end

  # Get the publication slug
  def publication_slug
    publication&.custom_fields&.[](Bookclub::PUBLICATION_SLUG)
  end

  # Get the chapter number
  def chapter_number
    chapter&.custom_fields&.[](Bookclub::CHAPTER_NUMBER)
  end

  # Get the chapter slug
  def chapter_slug
    chapter&.slug
  end

  # Get the bookclub URL for this reading position (uses slug)
  def bookclub_url
    return nil unless publication_slug && chapter_slug

    "/book/#{publication_slug}/#{chapter_slug}"
  end

  # Get the chapter title
  def chapter_title
    chapter&.name || topic&.title
  end
end
