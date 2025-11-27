# frozen_string_literal: true

# Lightweight serialiser for nav items (doesn't include content)
class BookclubNavPageSerializer < ApplicationSerializer
  attributes :id,
             :title,
             :slug,
             :parent_id,
             :position,
             :icon,
             :url,
             :has_children

  def url
    object.url
  end

  def has_children
    object.has_children?
  end
end
