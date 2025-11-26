# frozen_string_literal: true

# Bookclub Plugin Development Seed Data
# This file creates sample publications, chapters, and users for testing

puts "=========================================="
puts "Loading Bookclub Development Seed Data"
puts "=========================================="
puts ""

# Ensure the plugin is enabled
unless SiteSetting.bookclub_enabled
  puts "Enabling Bookclub plugin..."
  SiteSetting.bookclub_enabled = true
end

# Create test users with different roles
puts "Creating test users..."

# Author user
author_user =
  User.find_or_create_by!(username: "bookclub_author") do |u|
    u.email = "author@bookclub.test"
    u.name = "Book Author"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[2]
  end
author_user.activate
puts "  ✓ Created author user: #{author_user.username}"

# Editor user
editor_user =
  User.find_or_create_by!(username: "bookclub_editor") do |u|
    u.email = "editor@bookclub.test"
    u.name = "Book Editor"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[3]
  end
editor_user.activate
puts "  ✓ Created editor user: #{editor_user.username}"

# Reader users with different access tiers
basic_reader =
  User.find_or_create_by!(username: "basic_reader") do |u|
    u.email = "basic@bookclub.test"
    u.name = "Basic Reader"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[1]
  end
basic_reader.activate
puts "  ✓ Created basic reader: #{basic_reader.username}"

premium_reader =
  User.find_or_create_by!(username: "premium_reader") do |u|
    u.email = "premium@bookclub.test"
    u.name = "Premium Reader"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[2]
  end
premium_reader.activate
puts "  ✓ Created premium reader: #{premium_reader.username}"

puts ""

# Create access tier groups
puts "Creating access tier groups..."

basic_tier_group =
  Group.find_or_create_by!(name: "bookclub_basic_tier") do |g|
    g.visibility_level = Group.visibility_levels[:public]
    g.title = "Basic Tier Subscribers"
    g.bio_raw = "Users with basic subscription access"
  end
basic_tier_group.add(basic_reader)
basic_tier_group.add(premium_reader) # Premium has access to basic too
puts "  ✓ Created basic tier group: #{basic_tier_group.name}"

premium_tier_group =
  Group.find_or_create_by!(name: "bookclub_premium_tier") do |g|
    g.visibility_level = Group.visibility_levels[:public]
    g.title = "Premium Tier Subscribers"
    g.bio_raw = "Users with premium subscription access"
  end
premium_tier_group.add(premium_reader)
puts "  ✓ Created premium tier group: #{premium_tier_group.name}"

puts ""

# Create a sample publication (book)
puts "Creating sample publication..."

book_category =
  Category.find_or_create_by!(name: "The Elements of Ruby Style") do |c|
    c.user_id = author_user.id
    c.description = "A comprehensive guide to writing beautiful, idiomatic Ruby code"
    c.color = "0088CC"
    c.text_color = "FFFFFF"
  end

# Set publication custom fields
book_category.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
book_category.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
book_category.custom_fields[Bookclub::PUBLICATION_SLUG] = "elements-of-ruby-style"
book_category.custom_fields[Bookclub::PUBLICATION_COVER_URL] =
  "https://via.placeholder.com/400x600/0088CC/FFFFFF?text=The+Elements+of+Ruby+Style"
book_category.custom_fields[Bookclub::PUBLICATION_DESCRIPTION] =
  "This book explores the principles of writing clean, maintainable Ruby code. From basic syntax to advanced patterns, learn how to craft code that is both functional and elegant."
book_category.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS] = [author_user.id].to_json
book_category.custom_fields[Bookclub::PUBLICATION_EDITOR_IDS] = [editor_user.id].to_json
book_category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
  "basic" => basic_tier_group.id,
  "premium" => premium_tier_group.id,
}.to_json
book_category.custom_fields[Bookclub::PUBLICATION_FEEDBACK_SETTINGS] = {
  "enabled" => true,
  "allowed_types" => %w[comment suggestion],
}.to_json
book_category.custom_fields[Bookclub::PUBLICATION_IDENTIFIER] = "978-0-123456-78-9"
book_category.save!

puts "  ✓ Created publication: #{book_category.name}"
puts ""

# Create sample chapters
puts "Creating sample chapters..."

chapters_data = [
  {
    title: "Chapter 1: Introduction to Ruby",
    content:
      "# Welcome to Ruby\n\nRuby is a dynamic, object-oriented programming language that focuses on simplicity and productivity.\n\n## What Makes Ruby Special?\n\nRuby was designed to make programmers happy. Its elegant syntax reads like natural language, making code both easy to write and easy to read.\n\n```ruby\n5.times { puts 'Hello, Ruby!' }\n```\n\nIn this book, we'll explore the idioms and patterns that make Ruby code truly beautiful.",
    number: 1,
    access: "free",
    published: true,
    word_count: 75,
  },
  {
    title: "Chapter 2: Ruby Fundamentals",
    content:
      "# Ruby Fundamentals\n\nBefore diving into style, let's establish a foundation in Ruby basics.\n\n## Variables and Types\n\nRuby is dynamically typed, but that doesn't mean we should ignore types entirely.\n\n```ruby\nname = 'Alice'\nage = 30\nis_developer = true\n```\n\n## Methods and Blocks\n\nMethods are the heart of Ruby code. They should be small, focused, and clearly named.\n\n```ruby\ndef greet(name)\n  \"Hello, #{name}!\"\nend\n\nputs greet('Bob')\n```\n\nBlocks are one of Ruby's most powerful features, enabling elegant iteration and callbacks.",
    number: 2,
    access: "basic",
    published: true,
    word_count: 95,
  },
  {
    title: "Chapter 3: Object-Oriented Design",
    content:
      "# Object-Oriented Design in Ruby\n\nEverything in Ruby is an object. Understanding how to design objects effectively is crucial.\n\n## Classes and Modules\n\n```ruby\nclass Book\n  attr_reader :title, :author\n\n  def initialize(title, author)\n    @title = title\n    @author = author\n  end\n\n  def description\n    \"#{title} by #{author}\"\n  end\nend\n```\n\n## Composition vs Inheritance\n\nWhile Ruby supports inheritance, composition often leads to more flexible designs.\n\n```ruby\nclass Publication\n  attr_reader :metadata, :content\n\n  def initialize\n    @metadata = Metadata.new\n    @content = Content.new\n  end\nend\n```\n\nPrefer composition when objects have 'has-a' relationships rather than 'is-a' relationships.",
    number: 3,
    access: "basic",
    published: true,
    word_count: 112,
  },
  {
    title: "Chapter 4: Advanced Patterns",
    content:
      "# Advanced Ruby Patterns\n\nOnce you've mastered the basics, these patterns will elevate your code.\n\n## Metaprogramming\n\nRuby's metaprogramming capabilities are powerful but should be used judiciously.\n\n```ruby\nclass DynamicAttributes\n  def method_missing(method_name, *args)\n    if method_name.to_s.end_with?('=')\n      attribute = method_name.to_s.chomp('=')\n      instance_variable_set(\"@#{attribute}\", args.first)\n    else\n      instance_variable_get(\"@#{method_name}\")\n    end\n  end\nend\n```\n\n## Service Objects\n\nExtract complex business logic into dedicated service objects.\n\n```ruby\nclass PublishBook\n  def initialize(book)\n    @book = book\n  end\n\n  def call\n    validate!\n    @book.publish!\n    notify_subscribers\n  end\n\n  private\n\n  def validate!\n    raise 'Book has no chapters' if @book.chapters.empty?\n  end\n\n  def notify_subscribers\n    # Send notifications\n  end\nend\n```\n\nThis pattern keeps controllers thin and makes testing easier.",
    number: 4,
    access: "premium",
    published: true,
    word_count: 135,
  },
  {
    title: "Chapter 5: Testing and Quality",
    content:
      "# Testing and Code Quality\n\nGreat Ruby code is well-tested and maintainable.\n\n## RSpec Basics\n\n```ruby\nRSpec.describe Book do\n  describe '#description' do\n    it 'returns a formatted description' do\n      book = Book.new('Ruby Guide', 'Alice')\n      expect(book.description).to eq('Ruby Guide by Alice')\n    end\n  end\nend\n```\n\n## Test-Driven Development\n\nWriting tests first helps clarify requirements and leads to better design.\n\n1. Write a failing test\n2. Write minimal code to pass\n3. Refactor while keeping tests green\n\n## Code Review Principles\n\n- Keep methods under 10 lines when possible\n- One level of indentation per method\n- Clear, descriptive names\n- No comments explaining what code does (the code should be self-explanatory)\n- Comments explaining why decisions were made\n\nThese principles lead to code that's easy to understand and maintain.",
    number: 5,
    access: "premium",
    published: true,
    word_count: 145,
  },
]

chapters_data.each do |chapter_data|
  topic = Topic.find_or_initialize_by(title: chapter_data[:title], category: book_category)

  unless topic.persisted?
    topic.user = author_user
    topic.skip_validations = true
    topic.save!

    post =
      Post.create!(
        topic: topic,
        user: author_user,
        raw: chapter_data[:content],
        skip_validations: true,
      )
  else
    post = topic.first_post
  end

  # Set chapter custom fields
  topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
  topic.custom_fields[Bookclub::CONTENT_NUMBER] = chapter_data[:number]
  topic.custom_fields[Bookclub::CONTENT_ACCESS_LEVEL] = chapter_data[:access]
  topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = chapter_data[:published]
  topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = chapter_data[:word_count]
  topic.custom_fields[Bookclub::CONTENT_SUMMARY] =
    "Chapter #{chapter_data[:number]} of The Elements of Ruby Style"
  topic.custom_fields[Bookclub::CONTENT_CONTRIBUTORS] = [author_user.id].to_json
  topic.custom_fields[Bookclub::CONTENT_REVIEW_STATUS] = "published"
  topic.save_custom_fields

  puts "  ✓ Created chapter #{chapter_data[:number]}: #{chapter_data[:title]}"
end

puts ""

# Create a journal publication example
puts "Creating sample journal..."

journal_category =
  Category.find_or_create_by!(name: "Discourse Development Quarterly") do |c|
    c.user_id = editor_user.id
    c.description = "A quarterly journal covering the latest in Discourse development"
    c.color = "EE5533"
    c.text_color = "FFFFFF"
  end

journal_category.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
journal_category.custom_fields[Bookclub::PUBLICATION_TYPE] = "journal"
journal_category.custom_fields[Bookclub::PUBLICATION_SLUG] = "discourse-dev-quarterly"
journal_category.custom_fields[Bookclub::PUBLICATION_COVER_URL] =
  "https://via.placeholder.com/400x600/EE5533/FFFFFF?text=DDQ"
journal_category.custom_fields[Bookclub::PUBLICATION_DESCRIPTION] =
  "Peer-reviewed articles on Discourse plugins, architecture, and best practices."
journal_category.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS] = [].to_json
journal_category.custom_fields[Bookclub::PUBLICATION_EDITOR_IDS] = [editor_user.id].to_json
journal_category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
  "basic" => basic_tier_group.id,
}.to_json
journal_category.custom_fields[Bookclub::PUBLICATION_IDENTIFIER] = "ISSN 2024-0001"
journal_category.save!

puts "  ✓ Created journal: #{journal_category.name}"

# Create journal issue (subcategory)
issue_category =
  Category.find_or_create_by!(name: "Vol 1, Issue 1 - Spring 2024") do |c|
    c.user_id = editor_user.id
    c.parent_category_id = journal_category.id
    c.description = "The inaugural issue of Discourse Development Quarterly"
    c.color = "EE5533"
    c.text_color = "FFFFFF"
  end

issue_category.custom_fields[Bookclub::CONTAINER_TYPE] = "issue"
issue_category.custom_fields[Bookclub::CONTAINER_NUMBER] = 1
issue_category.custom_fields[Bookclub::CONTAINER_TITLE] = "Spring 2024 - Plugin Development"
issue_category.custom_fields[Bookclub::CONTAINER_PUBLICATION_DATE] = "2024-03-15"
issue_category.save!

puts "  ✓ Created journal issue: #{issue_category.name}"

# Create sample article
article_topic = Topic.find_or_initialize_by(title: "Building Your First Discourse Plugin", category: issue_category)

unless article_topic.persisted?
  article_topic.user = author_user
  article_topic.skip_validations = true
  article_topic.save!

  Post.create!(
    topic: article_topic,
    user: author_user,
    raw:
      "# Building Your First Discourse Plugin\n\n*by #{author_user.name}*\n\n## Abstract\n\nThis article provides a comprehensive introduction to Discourse plugin development.\n\n## Introduction\n\nDiscourse plugins extend the platform's functionality without modifying core code...\n\n## Plugin Architecture\n\nPlugins in Discourse follow a specific structure...",
    skip_validations: true,
  )
end

article_topic.custom_fields[Bookclub::CONTENT_TYPE] = "article"
article_topic.custom_fields[Bookclub::CONTENT_NUMBER] = 1
article_topic.custom_fields[Bookclub::CONTENT_ACCESS_LEVEL] = "basic"
article_topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = true
article_topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = 2500
article_topic.custom_fields[Bookclub::CONTENT_REVIEW_STATUS] = "published"
article_topic.save_custom_fields

puts "  ✓ Created article: #{article_topic.title}"

puts ""
puts "=========================================="
puts "Seed data loaded successfully!"
puts "=========================================="
puts ""
puts "Test Users:"
puts "  Author: bookclub_author / password123"
puts "  Editor: bookclub_editor / password123"
puts "  Basic Reader: basic_reader / password123"
puts "  Premium Reader: premium_reader / password123"
puts ""
puts "Publications:"
puts "  Book: The Elements of Ruby Style (5 chapters)"
puts "  Journal: Discourse Development Quarterly (1 issue, 1 article)"
puts ""
puts "Access Tiers:"
puts "  Basic Tier: #{basic_tier_group.name} (ID: #{basic_tier_group.id})"
puts "  Premium Tier: #{premium_tier_group.name} (ID: #{premium_tier_group.id})"
puts ""
puts "You can now test the Bookclub plugin with this sample content!"
puts ""
