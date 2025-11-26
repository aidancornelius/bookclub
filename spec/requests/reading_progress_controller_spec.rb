# frozen_string_literal: true

RSpec.describe Bookclub::ReadingProgressController do
  fab!(:user)
  fab!(:admin, :admin)

  before { SiteSetting.bookclub_enabled = true }

  fab!(:publication_category) do
    cat = Fabricate(:category, name: "My Test Book")
    cat.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
    cat.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
    cat.custom_fields[Bookclub::PUBLICATION_SLUG] = "test-book"
    cat.custom_fields[Bookclub::PUBLICATION_COVER_URL] = "https://example.com/cover.jpg"
    cat.save_custom_fields
    cat
  end

  fab!(:chapter1) do
    topic = Fabricate(:topic, category: publication_category, title: "Chapter 1")
    topic.custom_fields[Bookclub::CONTENT_NUMBER] = 1
    topic.save_custom_fields
    topic
  end

  fab!(:chapter2) do
    topic = Fabricate(:topic, category: publication_category, title: "Chapter 2")
    topic.custom_fields[Bookclub::CONTENT_NUMBER] = 2
    topic.save_custom_fields
    topic
  end

  describe "#index" do
    it "requires authentication" do
      get "/bookclub/reading-progress.json"
      expect(response.status).to eq(403)
    end

    it "returns empty progress for new users" do
      sign_in(user)

      get "/bookclub/reading-progress.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["reading_progress"]).to eq([])
    end

    it "returns progress for all publications" do
      sign_in(user)

      user.custom_fields[Bookclub::READING_PROGRESS] = {
        "test-book" => {
          "current_content_id" => chapter1.id,
          "current_content_number" => 1,
          "completed" => [chapter1.id],
          "last_read_at" => Time.current.iso8601
        }
      }
      user.save_custom_fields

      get "/bookclub/reading-progress.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["reading_progress"]).to be_present
      expect(json["reading_progress"].length).to eq(1)

      progress = json["reading_progress"][0]
      expect(progress["publication"]["slug"]).to eq("test-book")
      expect(progress["progress"]["current_content_id"]).to eq(chapter1.id)
      expect(progress["progress"]["completed_count"]).to eq(1)
      expect(progress["progress"]["total_count"]).to eq(2)
      expect(progress["progress"]["percentage"]).to eq(50.0)
    end

    it "enriches progress with publication details" do
      sign_in(user)

      user.custom_fields[Bookclub::READING_PROGRESS] = {
        "test-book" => {
          "current_content_id" => chapter1.id
        }
      }
      user.save_custom_fields

      get "/bookclub/reading-progress.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      progress = json["reading_progress"][0]
      expect(progress["publication"]["name"]).to eq("My Test Book")
      expect(progress["publication"]["type"]).to eq("book")
      expect(progress["publication"]["cover_url"]).to eq("https://example.com/cover.jpg")
    end
  end

  describe "#show" do
    it "requires authentication" do
      get "/bookclub/reading-progress/test-book.json"
      expect(response.status).to eq(403)
    end

    it "returns progress for specific publication" do
      sign_in(user)

      user.custom_fields[Bookclub::READING_PROGRESS] = {
        "test-book" => {
          "current_content_id" => chapter2.id,
          "current_content_number" => 2,
          "scroll_position" => 0.5,
          "completed" => [chapter1.id],
          "last_read_at" => Time.current.iso8601
        }
      }
      user.save_custom_fields

      get "/bookclub/reading-progress/test-book.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["publication"]["slug"]).to eq("test-book")
      expect(json["progress"]["current_content_id"]).to eq(chapter2.id)
      expect(json["progress"]["current_content_number"]).to eq(2)
      expect(json["progress"]["scroll_position"]).to eq(0.5)
      expect(json["progress"]["completed"]).to eq([chapter1.id])
    end

    it "returns empty progress for new publication" do
      sign_in(user)

      get "/bookclub/reading-progress/test-book.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["progress"]["completed"]).to eq([])
      expect(json["progress"]["percentage"]).to eq(0)
    end

    it "returns 404 for non-existent publication" do
      sign_in(user)

      get "/bookclub/reading-progress/nonexistent.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    it "requires authentication" do
      put "/bookclub/reading-progress/test-book.json"
      expect(response.status).to eq(403)
    end

    it "updates current content position" do
      sign_in(user)

      put "/bookclub/reading-progress/test-book.json", params: {
        current_content_id: chapter2.id,
        current_content_number: 2
      }

      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["success"]).to eq(true)
      expect(json["progress"]["current_content_id"]).to eq(chapter2.id)
      expect(json["progress"]["current_content_number"]).to eq(2)

      user.reload
      progress = user.custom_fields[Bookclub::READING_PROGRESS]
      expect(progress["test-book"]["current_content_id"]).to eq(chapter2.id)
      expect(progress["test-book"]["last_read_at"]).to be_present
    end

    it "updates scroll position" do
      sign_in(user)

      put "/bookclub/reading-progress/test-book.json", params: {
        scroll_position: 0.75
      }

      expect(response.status).to eq(200)

      user.reload
      progress = user.custom_fields[Bookclub::READING_PROGRESS]
      expect(progress["test-book"]["scroll_position"]).to eq(0.75)
    end

    it "marks content as completed" do
      sign_in(user)

      put "/bookclub/reading-progress/test-book.json", params: {
        mark_completed: chapter1.id
      }

      expect(response.status).to eq(200)

      user.reload
      progress = user.custom_fields[Bookclub::READING_PROGRESS]
      expect(progress["test-book"]["completed"]).to include(chapter1.id)

      json = response.parsed_body
      expect(json["progress"]["completed_count"]).to eq(1)
      expect(json["progress"]["percentage"]).to eq(50.0)
    end

    it "does not duplicate completed items" do
      sign_in(user)

      put "/bookclub/reading-progress/test-book.json", params: {
        mark_completed: chapter1.id
      }

      put "/bookclub/reading-progress/test-book.json", params: {
        mark_completed: chapter1.id
      }

      user.reload
      progress = user.custom_fields[Bookclub::READING_PROGRESS]
      expect(progress["test-book"]["completed"].count(chapter1.id)).to eq(1)
    end

    it "marks content as uncompleted" do
      sign_in(user)

      user.custom_fields[Bookclub::READING_PROGRESS] = {
        "test-book" => {
          "completed" => [chapter1.id, chapter2.id]
        }
      }
      user.save_custom_fields

      put "/bookclub/reading-progress/test-book.json", params: {
        mark_uncompleted: chapter1.id
      }

      expect(response.status).to eq(200)

      user.reload
      progress = user.custom_fields[Bookclub::READING_PROGRESS]
      expect(progress["test-book"]["completed"]).not_to include(chapter1.id)
      expect(progress["test-book"]["completed"]).to include(chapter2.id)
    end

    it "returns enriched progress data" do
      sign_in(user)

      put "/bookclub/reading-progress/test-book.json", params: {
        current_content_id: chapter1.id,
        mark_completed: chapter1.id
      }

      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["progress"]["total_count"]).to eq(2)
      expect(json["progress"]["completed_count"]).to eq(1)
      expect(json["progress"]["percentage"]).to eq(50.0)
    end

    it "returns 404 for non-existent publication" do
      sign_in(user)

      put "/bookclub/reading-progress/nonexistent.json", params: {
        current_content_id: 123
      }

      expect(response.status).to eq(404)
    end
  end
end
