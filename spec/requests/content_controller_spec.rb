# frozen_string_literal: true

RSpec.describe Bookclub::ContentController do
  fab!(:user)
  fab!(:admin, :admin)

  before { SiteSetting.bookclub_enabled = true }

  fab!(:publication_category) do
    cat = Fabricate(:category, name: "My Test Book")
    cat.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
    cat.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
    cat.custom_fields[Bookclub::PUBLICATION_SLUG] = "test-book"
    cat.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS] = [admin.id]
    cat.save_custom_fields
    cat
  end

  fab!(:free_chapter) do
    topic = Fabricate(:topic, category: publication_category, title: "Free Chapter")
    post = Fabricate(:post, topic: topic, raw: "This is the free chapter content.")
    topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
    topic.custom_fields[Bookclub::CONTENT_NUMBER] = 1
    topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = true
    topic.custom_fields[Bookclub::CONTENT_ACCESS_LEVEL] = "free"
    topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = 500
    topic.save_custom_fields
    topic
  end

  fab!(:premium_chapter) do
    topic = Fabricate(:topic, category: publication_category, title: "Premium Chapter")
    post = Fabricate(:post, topic: topic, raw: "This is the premium chapter content.")
    topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
    topic.custom_fields[Bookclub::CONTENT_NUMBER] = 2
    topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = true
    topic.custom_fields[Bookclub::CONTENT_ACCESS_LEVEL] = "member"
    topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = 750
    topic.save_custom_fields
    topic
  end

  describe "#show" do
    context "with free content" do
      it "allows anyone to access free chapters" do
        get "/book/test-book/1"
        expect(response.status).to eq(200)
      end

      it "returns content details in JSON" do
        get "/bookclub/publications/test-book/contents/1.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["content"]).to be_present
        expect(json["content"]["title"]).to eq("Free Chapter")
        expect(json["content"]["number"]).to eq(1)
        expect(json["content"]["type"]).to eq("chapter")
        expect(json["content"]["word_count"]).to eq(500)
        expect(json["content"]["body_html"]).to be_present
      end

      it "includes navigation information" do
        get "/bookclub/publications/test-book/contents/1.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["navigation"]).to be_present
        expect(json["navigation"]["current"]["number"]).to eq(1)
        expect(json["navigation"]["next"]).to be_present
        expect(json["navigation"]["next"]["number"]).to eq(2)
      end
    end

    context "with premium content" do
      it "shows paywall for non-members" do
        get "/book/test-book/2"
        expect(response.status).to eq(200)
      end

      it "returns 403 for JSON requests without access" do
        get "/bookclub/publications/test-book/contents/2.json"
        expect(response.status).to eq(403)

        json = response.parsed_body
        expect(json["error"]).to eq("access_denied")
        expect(json["paywall"]).to eq(true)
      end

      it "allows access for members with correct tier" do
        member_group = Fabricate(:group, name: "members")
        member_user = Fabricate(:user)
        member_group.add(member_user)

        publication_category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
          "members" => "member"
        }
        publication_category.save_custom_fields

        sign_in(member_user)

        get "/bookclub/publications/test-book/contents/2.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["content"]["title"]).to eq("Premium Chapter")
      end
    end

    it "returns 404 for non-existent content" do
      get "/book/test-book/999"
      expect(response.status).to eq(404)
    end

    it "includes raw content for publication authors" do
      sign_in(admin)

      get "/bookclub/publications/test-book/contents/1.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["content"]["body_raw"]).to be_present
      expect(json["content"]["body_raw"]).to eq("This is the free chapter content.")
    end

    it "does not include raw content for regular readers" do
      sign_in(user)

      get "/bookclub/publications/test-book/contents/1.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["content"]["body_raw"]).to be_nil
    end
  end

  describe "#discuss" do
    fab!(:discussion_post) do
      Fabricate(:post, topic: free_chapter, post_number: 2, raw: "Great chapter!")
    end

    it "returns discussion posts for accessible content" do
      get "/book/test-book/1/discuss.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["topic_id"]).to eq(free_chapter.id)
      expect(json["posts_count"]).to eq(1)
      expect(json["posts"]).to be_present
      expect(json["posts"][0]["cooked"]).to include("Great chapter")
    end

    it "requires access to view discussion" do
      get "/book/test-book/2/discuss.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#update_progress" do
    it "requires authentication" do
      put "/bookclub/publications/test-book/contents/1/progress.json"
      expect(response.status).to eq(401)
    end

    it "updates reading progress for logged in users" do
      sign_in(user)

      put "/bookclub/publications/test-book/contents/1/progress.json", params: {
        scroll_position: 0.5,
        completed: true
      }

      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["success"]).to eq(true)
      expect(json["progress"]).to be_present

      user.reload
      progress = user.custom_fields[Bookclub::READING_PROGRESS]
      expect(progress["test-book"]["current_content_id"]).to eq(free_chapter.id)
      expect(progress["test-book"]["completed"]).to include(free_chapter.id)
    end

    it "tracks scroll position" do
      sign_in(user)

      put "/bookclub/publications/test-book/contents/1/progress.json", params: {
        scroll_position: 0.75
      }

      expect(response.status).to eq(200)

      user.reload
      progress = user.custom_fields[Bookclub::READING_PROGRESS]
      expect(progress["test-book"]["scroll_position"]).to eq("0.75")
    end
  end

  describe "#navigation" do
    it "returns navigation data for a chapter" do
      get "/bookclub/publications/test-book/contents/1/navigation.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["current"]["number"]).to eq(1)
      expect(json["next"]["number"]).to eq(2)
      expect(json["previous"]).to be_nil
      expect(json["total_count"]).to eq(2)
      expect(json["current_index"]).to eq(1)
    end

    it "returns navigation for middle chapters" do
      third_chapter = Fabricate(:topic, category: publication_category, title: "Chapter 3")
      third_chapter.custom_fields[Bookclub::CONTENT_NUMBER] = 3
      third_chapter.save_custom_fields

      get "/bookclub/publications/test-book/contents/2/navigation.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["previous"]["number"]).to eq(1)
      expect(json["next"]["number"]).to eq(3)
      expect(json["current_index"]).to eq(2)
    end
  end
end
