# frozen_string_literal: true

class AddForeignKeyToBookclubPagesParentId < ActiveRecord::Migration[7.0]
  def change
    # Add foreign key constraint for self-referential parent_id
    # This ensures parent_id references a valid bookclub_pages record
    add_foreign_key :bookclub_pages, :bookclub_pages, column: :parent_id, on_delete: :nullify
  end
end
