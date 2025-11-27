# frozen_string_literal: true

module Bookclub
  # Shared helper methods for finding and working with content topics
  module ContentHelpers
    # Find the content topic within a chapter category
    # The content topic is marked with the CONTENT_TOPIC custom field
    # @param chapter [Category] The chapter category
    # @return [Topic, nil] The content topic or nil if not found
    def find_content_topic(chapter)
      # Note: Discourse stores boolean true as "t" in custom fields
      Topic
        .where(category_id: chapter.id)
        .joins(
          sanitize_sql_array([
            'LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = ?',
            CONTENT_TOPIC,
          ]),
        )
        .where('tcf.value IN (?)', %w[t true])
        .first
    end

    private

    # Safely sanitize SQL for joins
    # @param sql_array [Array] SQL with placeholders and values
    # @return [String] Sanitized SQL
    def sanitize_sql_array(sql_array)
      ActiveRecord::Base.sanitize_sql_array(sql_array)
    end
  end
end
