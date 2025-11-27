# frozen_string_literal: true

class CreateBookclubReadingPositions < ActiveRecord::Migration[7.0]
  def change
    create_table :bookclub_reading_positions do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false

      t.timestamps
    end

    add_index :bookclub_reading_positions, :user_id
    add_index :bookclub_reading_positions, :topic_id
    add_index :bookclub_reading_positions, %i[user_id topic_id], unique: true
  end
end
