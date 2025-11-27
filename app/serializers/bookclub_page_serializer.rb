# frozen_string_literal: true

class BookclubPageSerializer < ApplicationSerializer
  attributes :id,
             :title,
             :slug,
             :raw,
             :cooked,
             :parent_id,
             :position,
             :nav_position,
             :visible,
             :show_in_nav,
             :icon,
             :url,
             :has_children,
             :created_at,
             :updated_at

  def url
    object.url
  end

  def has_children
    object.has_children?
  end

  # Only include raw content for admin users
  def include_raw?
    scope&.is_admin?
  end
end
