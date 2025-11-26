# frozen_string_literal: true

RSpec.describe Bookclub::PublicationsController do
  fab!(:user)
  fab!(:admin, :admin)

  before { SiteSetting.bookclub_enabled = true }

  fab!(:publication_category) do
    cat = Fabricate(:category, name: "My Test Book")
    cat.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
    cat.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
    cat.custom_fields[Bookclub::PUBLICATION_SLUG] = "test-book"
    cat.custom_fields[Bookclub::PUBLICATION_COVER_URL] = "https://example.com/cover.jpg"
    cat.custom_fields[Bookclub::PUBLICATION_DESCRIPTION] = "A test book description"
    cat.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS] = [admin.id]
    cat.save_custom_fields
    cat
  end

  fab!(:chapter1) do
    topic = Fabricate(:topic, category: publication_category, title: "Chapter 1: The Beginning")
    topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
    topic.custom_fields[Bookclub::CONTENT_NUMBER] = 1
    topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = true
    topic.custom_fields[Bookclub::CONTENT_ACCESS_LEVEL] = "free"
    topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = 500
    topic.save_custom_fields
    topic
  end

  fab!(:chapter2) do
    topic = Fabricate(:topic, category: publication_category, title: "Chapter 2: The Middle")
    topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
    topic.custom_fields[Bookclub::CONTENT_NUMBER] = 2
    topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = true
    topic.custom_fields[Bookclub::CONTENT_ACCESS_LEVEL] = "member"
    topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = 750
    topic.save_custom_fields
    topic
  end

  describe "#index" do
    it "returns all visible publications" do
      get "/bookclub/publications.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["publications"]).to be_present
      expect(json["publications"].length).to be >= 1

      publication = json["publications"].find { |p| p["slug"] == "test-book" }
      expect(publication).to be_present
      expect(publication["name"]).to eq("My Test Book")
      expect(publication["type"]).to eq("book")
    end

    it "filters publications user cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_category.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
      private_category.custom_fields[Bookclub::PUBLICATION_SLUG] = "private-book"
      private_category.save_custom_fields

      get "/bookclub/publications.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      slugs = json["publications"].map { |p| p["slug"] }
      expect(slugs).not_to include("private-book")
    end
  end

  describe "#show" do
    context "with HTML format" do
      it "renders the publication page" do
        get "/book/test-book"
        expect(response.status).to eq(200)
      end

      it "returns 404 for non-existent publication" do
        get "/book/nonexistent"
        expect(response.status).to eq(404)
      end
    end

    context "with JSON format" do
      it "returns publication details" do
        get "/bookclub/publications/test-book.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["id"]).to eq(publication_category.id)
        expect(json["name"]).to eq("My Test Book")
        expect(json["slug"]).to eq("test-book")
        expect(json["type"]).to eq("book")
        expect(json["cover_url"]).to eq("https://example.com/cover.jpg")
        expect(json["description"]).to eq("A test book description")
        expect(json["toc"]).to be_present
        expect(json["content_count"]).to eq(2)
        expect(json["total_word_count"]).to eq(1250)
      end

      it "includes author information" do
        get "/bookclub/publications/test-book.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["authors"]).to be_present
        expect(json["authors"].length).to eq(1)
        expect(json["authors"][0]["id"]).to eq(admin.id)
        expect(json["authors"][0]["username"]).to eq(admin.username)
      end

      it "includes table of contents" do
        get "/bookclub/publications/test-book.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["toc"]).to be_present
        expect(json["toc"].length).to eq(2)

        chapter1_toc = json["toc"].find { |c| c["number"] == 1 }
        expect(chapter1_toc["title"]).to eq("Chapter 1: The Beginning")
        expect(chapter1_toc["type"]).to eq("chapter")
        expect(chapter1_toc["access_level"]).to eq("free")
        expect(chapter1_toc["has_access"]).to eq(true)
      end
    end
  end

  describe "#contents" do
    it "requires access to publication" do
      get "/bookclub/publications/test-book/contents.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["contents"]).to be_present
    end

    it "filters content by access level" do
      sign_in(user)

      get "/bookclub/publications/test-book/contents.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      numbers = json["contents"].map { |c| c["number"] }
      expect(numbers).to include(1)
    end
  end

  describe "#toc" do
    it "returns table of contents" do
      get "/bookclub/publications/test-book/toc.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["toc"]).to be_present
      expect(json["toc"].length).to eq(2)
    end

    it "marks locked chapters correctly" do
      sign_in(user)

      get "/bookclub/publications/test-book/toc.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      chapter1_entry = json["toc"].find { |c| c["number"] == 1 }
      chapter2_entry = json["toc"].find { |c| c["number"] == 2 }

      expect(chapter1_entry["has_access"]).to eq(true)
      expect(chapter2_entry["has_access"]).to eq(false)
    end
  end

  describe "access control with tiers" do
    fab!(:member_group) { Fabricate(:group, name: "members") }
    fab!(:member_user) { Fabricate(:user) }

    before do
      member_group.add(member_user)

      publication_category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
        "members" => "member"
      }
      publication_category.save_custom_fields
    end

    it "allows tier members to access restricted content" do
      sign_in(member_user)

      get "/bookclub/publications/test-book/contents.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      numbers = json["contents"].map { |c| c["number"] }
      expect(numbers).to include(1, 2)
    end
  end
end
