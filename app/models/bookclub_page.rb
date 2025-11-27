# frozen_string_literal: true

class BookclubPage < ActiveRecord::Base
  self.table_name = 'bookclub_pages'

  # Associations
  belongs_to :parent, class_name: 'BookclubPage', optional: true
  has_many :children, class_name: 'BookclubPage', foreign_key: 'parent_id', dependent: :nullify

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :slug, format: { with: /\A[a-z0-9\-]+\z/, message: 'must be lowercase with hyphens only' }
  validates :nav_position, inclusion: { in: %w[header footer none] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :visible, -> { where(visible: true) }
  scope :in_nav, -> { where(show_in_nav: true) }
  scope :header_nav, -> { where(nav_position: 'header').in_nav.visible }
  scope :footer_nav, -> { where(nav_position: 'footer').in_nav.visible }
  scope :top_level, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :title) }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_save :cook_content, if: :will_save_change_to_raw?

  # Class methods
  def self.nav_tree(position = 'header')
    pages = where(nav_position: position).in_nav.visible.ordered.to_a

    top_level = pages.select { |p| p.parent_id.nil? }
    children_by_parent = pages.select { |p| p.parent_id.present? }.group_by(&:parent_id)

    top_level.map do |page|
      {
        page: page,
        children: (children_by_parent[page.id] || []).sort_by(&:position)
      }
    end
  end

  # Instance methods
  def has_children?
    children.in_nav.visible.exists?
  end

  def is_dropdown?
    parent_id.nil? && has_children?
  end

  def url
    "/pages/#{slug}"
  end

  private

  def generate_slug
    base_slug = title.parameterize
    self.slug = base_slug

    counter = 1
    while BookclubPage.where(slug: slug).where.not(id: id).exists?
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end

  def cook_content
    return if raw.blank?

    # Use Discourse's cooking pipeline
    self.cooked = PrettyText.cook(raw, {})
  end
end
