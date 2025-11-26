# frozen_string_literal: true

# Create a test publication with chapters as subcategories
puts "Creating test publication..."

# Find or create admin user
admin = User.find_by(admin: true) || User.first
puts "Using user: #{admin.username}"

# Create the book category (publication)
publication = Category.find_by(slug: "test-book")
unless publication
  publication =
    Category.create!(
      name: "The Art of Programming",
      slug: "test-book",
      user: admin,
      color: "0088CC",
      text_color: "FFFFFF",
    )
end

puts "Publication category ID: #{publication.id}"

# Set publication custom fields
publication.custom_fields["publication_enabled"] = true
publication.custom_fields["publication_slug"] = "art-of-programming"
publication.custom_fields["publication_type"] = "book"
publication.custom_fields[
  "publication_description"
] = "A comprehensive guide to the art and craft of software development. This book explores the fundamental principles, patterns, and practices that separate good code from great code."
publication.custom_fields["publication_author_ids"] = [admin.id]
publication.custom_fields["publication_access_tiers"] = { "everyone" => "community" }
publication.save_custom_fields

puts "Publication enabled: #{publication.custom_fields["publication_enabled"]}"

# Chapter definitions
chapters = [
  {
    title: "Introduction: Why programming matters",
    number: 1,
    summary: "An exploration of why programming is both an art and a science.",
  },
  {
    title: "The fundamentals of clean code",
    number: 2,
    summary: "Understanding the principles that make code readable and maintainable.",
  },
  {
    title: "Design patterns in practice",
    number: 3,
    summary: "Practical applications of common design patterns.",
  },
  {
    title: "Testing strategies",
    number: 4,
    summary: "How to write tests that provide confidence without slowing you down.",
  },
  {
    title: "Performance optimisation",
    number: 5,
    summary: "Identifying and fixing performance bottlenecks.",
  },
]

chapters.each do |ch|
  # Create chapter subcategory
  chapter_slug = "chapter-#{ch[:number]}"
  chapter = Category.find_by(slug: chapter_slug, parent_category_id: publication.id)

  if chapter
    puts "Chapter #{ch[:number]} already exists: #{ch[:title]}"
  else
    puts "Creating chapter #{ch[:number]}: #{ch[:title]}"

    chapter =
      Category.create!(
        name: ch[:title],
        slug: chapter_slug,
        user: admin,
        parent_category_id: publication.id,
        color: publication.color,
        text_color: publication.text_color,
      )

    # Set chapter custom fields
    chapter.custom_fields["bookclub_chapter_enabled"] = true
    chapter.custom_fields["bookclub_chapter_type"] = "chapter"
    chapter.custom_fields["bookclub_chapter_number"] = ch[:number]
    chapter.custom_fields["bookclub_chapter_access_level"] = "free"
    chapter.custom_fields["bookclub_chapter_published"] = true
    chapter.custom_fields["bookclub_chapter_summary"] = ch[:summary]
    chapter.save_custom_fields

    puts "  Created chapter category ID: #{chapter.id}"

    # Create the content topic (pinned)
    content_raw = <<~CONTENT
      # #{ch[:title]}

      This is the content for chapter #{ch[:number]}. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

      ## Key concepts

      - First important point about #{ch[:title].downcase}
      - Second important point with practical examples
      - Third important point for real-world application

      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

      > A great programmer is not someone who writes clever code, but someone who writes code that others can understand.

      ## Summary

      #{ch[:summary]}

      Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. This chapter covered the essential concepts you need to understand before moving on to the next section.
    CONTENT

    post_creator =
      PostCreator.new(
        admin,
        title: ch[:title],
        raw: content_raw,
        category: chapter.id,
        skip_validations: true,
      )

    result = post_creator.create
    if result
      content_topic = result.topic

      # Pin the content topic
      content_topic.update!(pinned_at: Time.current, pinned_globally: false)

      # Mark as content topic
      content_topic.custom_fields["bookclub_content_topic"] = true
      content_topic.save_custom_fields

      # Update word count on chapter
      chapter.custom_fields["bookclub_chapter_word_count"] = content_raw.split.size
      chapter.save_custom_fields

      puts "  Created content topic ID: #{content_topic.id}"

      # Create a sample discussion topic
      discussion_creator =
        PostCreator.new(
          admin,
          title: "Discussion: #{ch[:title]}",
          raw: "What are your thoughts on this chapter? Share your questions and insights here!",
          category: chapter.id,
          skip_validations: true,
        )

      discussion_result = discussion_creator.create
      puts "  Created discussion topic ID: #{discussion_result.topic.id}" if discussion_result
    else
      puts "  ERROR creating content: #{post_creator.errors.full_messages.join(", ")}"
    end
  end
end

puts "\nDone! Publication created with #{chapters.size} chapters."
puts "Each chapter is a subcategory with:"
puts "  - A pinned content topic (the chapter text)"
puts "  - Discussion topics for reader conversations"
puts "\nVisit /book/art-of-programming to view"
