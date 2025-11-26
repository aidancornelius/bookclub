# frozen_string_literal: true

RSpec.describe "Bookclub plugin" do
  before { SiteSetting.bookclub_enabled = true }

  it "is loaded correctly" do
    expect(Bookclub::PLUGIN_NAME).to eq("bookclub")
  end

  describe "constants" do
    it "defines publication types" do
      expect(Bookclub::PUBLICATION_TYPES).to eq(%w[book journal anthology series])
    end

    it "defines container types" do
      expect(Bookclub::CONTAINER_TYPES).to eq(%w[issue volume part section])
    end

    it "defines content types" do
      expect(Bookclub::CONTENT_TYPES).to eq(%w[chapter article essay review])
    end

    it "defines feedback types" do
      expect(Bookclub::FEEDBACK_TYPES).to eq(%w[comment suggestion review endorsement])
    end

    it "defines review statuses" do
      expect(Bookclub::REVIEW_STATUSES).to eq(%w[draft under_review accepted published])
    end
  end

  describe "custom field registration" do
    it "registers category custom fields for publications" do
      category = Fabricate(:category)

      category.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
      category.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
      category.custom_fields[Bookclub::PUBLICATION_SLUG] = "test-book"
      category.save_custom_fields

      category.reload
      expect(category.custom_fields[Bookclub::PUBLICATION_ENABLED]).to eq(true)
      expect(category.custom_fields[Bookclub::PUBLICATION_TYPE]).to eq("book")
      expect(category.custom_fields[Bookclub::PUBLICATION_SLUG]).to eq("test-book")
    end

    it "registers topic custom fields for content items" do
      topic = Fabricate(:topic)

      topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
      topic.custom_fields[Bookclub::CONTENT_NUMBER] = 1
      topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = true
      topic.save_custom_fields

      topic.reload
      expect(topic.custom_fields[Bookclub::CONTENT_TYPE]).to eq("chapter")
      expect(topic.custom_fields[Bookclub::CONTENT_NUMBER]).to eq(1)
      expect(topic.custom_fields[Bookclub::CONTENT_PUBLISHED]).to eq(true)
    end

    it "registers user custom fields for reading progress" do
      user = Fabricate(:user)

      progress_data = {
        "test-book" => {
          "current_content_id" => 123,
          "current_content_number" => 5,
          "completed" => [100, 101, 102]
        }
      }

      user.custom_fields[Bookclub::READING_PROGRESS] = progress_data
      user.save_custom_fields

      user.reload
      expect(user.custom_fields[Bookclub::READING_PROGRESS]).to eq(progress_data)
    end
  end

  describe "event hooks" do
    fab!(:category) do
      cat = Fabricate(:category)
      cat.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
      cat.save_custom_fields
      cat
    end

    it "calculates word count on post creation" do
      topic = Fabricate(:topic, category: category)
      post = Fabricate(:post, topic: topic, raw: "This is a test post with ten words here today")

      topic.reload
      expect(topic.custom_fields[Bookclub::CONTENT_WORD_COUNT]).to eq(10)
    end

    it "updates word count on post edit" do
      topic = Fabricate(:topic, category: category)
      post = Fabricate(:post, topic: topic, raw: "Short post")

      topic.reload
      expect(topic.custom_fields[Bookclub::CONTENT_WORD_COUNT]).to eq(2)

      post.revise(post.user, raw: "This is a much longer post with more words")
      topic.reload
      expect(topic.custom_fields[Bookclub::CONTENT_WORD_COUNT]).to eq(9)
    end

    it "does not calculate word count for non-publication categories" do
      normal_category = Fabricate(:category)
      topic = Fabricate(:topic, category: normal_category)
      post = Fabricate(:post, topic: topic, raw: "This is a test post")

      topic.reload
      expect(topic.custom_fields[Bookclub::CONTENT_WORD_COUNT]).to be_nil
    end
  end

  describe "serializer extensions" do
    fab!(:category) do
      cat = Fabricate(:category)
      cat.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
      cat.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
      cat.custom_fields[Bookclub::PUBLICATION_SLUG] = "my-book"
      cat.save_custom_fields
      cat
    end

    it "includes publication fields in category serializer" do
      json = BasicCategorySerializer.new(category, scope: Guardian.new, root: false).as_json

      expect(json[:publication_enabled]).to eq(true)
      expect(json[:publication_type]).to eq("book")
      expect(json[:publication_slug]).to eq("my-book")
    end

    it "includes content fields in topic serializer" do
      topic = Fabricate(:topic, category: category)
      topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
      topic.custom_fields[Bookclub::CONTENT_NUMBER] = 1
      topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = true
      topic.save_custom_fields

      topic_view = TopicView.new(topic.id, Fabricate(:user))
      json = TopicViewSerializer.new(topic_view, scope: Guardian.new, root: false).as_json

      expect(json[:bookclub_content_type]).to eq("chapter")
      expect(json[:bookclub_content_number]).to eq(1)
      expect(json[:bookclub_content_published]).to eq(true)
    end
  end
end
