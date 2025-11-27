# frozen_string_literal: true

module Jobs
  class DeleteBookclubChapter < ::Jobs::Base
    def execute(args)
      chapter_id = args[:chapter_id]
      actor = User.find_by(id: args[:user_id]) || Discourse.system_user
      return unless chapter_id

      chapter = Category.find_by(id: chapter_id)
      return unless chapter

      ActiveRecord::Base.transaction do
        topic_ids = Topic.where(category_id: chapter.id).pluck(:id)

        if topic_ids.any?
          # Clean up reading positions and bookmarks
          BookclubReadingPosition.where(topic_id: topic_ids).find_each do |pos|
            pos.bookmarks.destroy_all
            pos.destroy
          end

          TopicCustomField.where(topic_id: topic_ids).delete_all

          Topic.where(id: topic_ids).find_each do |topic|
            topic.posts.order(post_number: :desc).find_each do |post|
              PostDestroyer.new(actor, post, force_destroy: true).destroy
            end
          end
        end

        CategoryGroup.where(category_id: chapter.id).delete_all
        CategoryCustomField.where(category_id: chapter.id).delete_all

        chapter.destroy
      end
    rescue StandardError => e
      Rails.logger.error("[Bookclub] Failed background chapter delete #{chapter_id}: #{e.class.name} - #{e.message}")
    end
  end
end
