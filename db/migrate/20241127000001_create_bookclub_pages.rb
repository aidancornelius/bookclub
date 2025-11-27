# frozen_string_literal: true

class CreateBookclubPages < ActiveRecord::Migration[7.0]
  def change
    create_table :bookclub_pages do |t|
      t.string :title, null: false, limit: 255
      t.string :slug, null: false, limit: 255
      t.text :raw # Raw markdown content
      t.text :cooked # Cooked HTML content
      t.integer :parent_id # For dropdown grouping (self-referential)
      t.integer :position, default: 0, null: false
      t.string :nav_position, default: 'header', limit: 50 # header, footer, none
      t.boolean :visible, default: true, null: false
      t.boolean :show_in_nav, default: true, null: false # Whether to show in navigation
      t.string :icon, limit: 50 # Optional FontAwesome icon name
      t.timestamps
    end

    add_index :bookclub_pages, :slug, unique: true
    add_index :bookclub_pages, :parent_id
    add_index :bookclub_pages, %i[nav_position position]
    add_index :bookclub_pages, :visible
  end
end
