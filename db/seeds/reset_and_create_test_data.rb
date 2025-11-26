# frozen_string_literal: true

# Reset and create comprehensive test data for the bookclub plugin
# Run with: bin/rails runner plugins/bookclub/db/seeds/reset_and_create_test_data.rb

puts "=" * 60
puts "Bookclub Plugin - Reset and Create Test Data"
puts "=" * 60

# Find admin user
admin = User.find_by(admin: true) || User.first
puts "\nUsing admin: #{admin.username}"

# Create some test users for discussions
test_users = []
3.times do |i|
  user =
    User.find_by(username: "reader#{i + 1}") ||
      User.create!(
        username: "reader#{i + 1}",
        email: "reader#{i + 1}@example.com",
        password: "password123456",
        active: true,
        approved: true,
      )
  test_users << user
  puts "Created/found user: #{user.username}"
end

# Delete existing test publication and all its data
puts "\n--- Cleaning up existing test data ---"

existing_pub = Category.find_by(slug: "test-book")
if existing_pub
  # Delete all subcategories (chapters) first
  Category
    .where(parent_category_id: existing_pub.id)
    .find_each do |chapter|
      puts "Deleting chapter: #{chapter.name}"
      Topic
        .where(category_id: chapter.id)
        .find_each do |topic|
          topic.posts.destroy_all
          topic.destroy
        end
      chapter.destroy
    end

  # Delete topics in the publication itself
  Topic
    .where(category_id: existing_pub.id)
    .find_each do |topic|
      topic.posts.destroy_all
      topic.destroy
    end

  existing_pub.destroy
  puts "Deleted existing publication: test-book"
end

# Also clean up the journal if it exists
existing_journal = Category.find_by(slug: "software-engineering-journal")
if existing_journal
  Category
    .where(parent_category_id: existing_journal.id)
    .find_each do |chapter|
      puts "Deleting journal article: #{chapter.name}"
      Topic
        .where(category_id: chapter.id)
        .find_each do |topic|
          topic.posts.destroy_all
          topic.destroy
        end
      chapter.destroy
    end

  Topic
    .where(category_id: existing_journal.id)
    .find_each do |topic|
      topic.posts.destroy_all
      topic.destroy
    end

  existing_journal.destroy
  puts "Deleted existing publication: software-engineering-journal"
end

puts "\n--- Creating fresh publication ---"

# Create the book category (publication)
publication =
  Category.create!(
    name: "The Art of Programming",
    slug: "test-book",
    user: admin,
    color: "0088CC",
    text_color: "FFFFFF",
  )

puts "Created publication: #{publication.name} (ID: #{publication.id})"

# Set publication custom fields
publication.custom_fields["publication_enabled"] = true
publication.custom_fields["publication_slug"] = "art-of-programming"
publication.custom_fields["publication_type"] = "book"
publication.custom_fields["publication_cover_url"] = nil
publication.custom_fields["publication_description"] = <<~DESC
  A comprehensive guide to the art and craft of software development.

  This book explores the fundamental principles, patterns, and practices that separate good code from great code. Whether you're a beginner learning to program or an experienced developer looking to refine your craft, this book will help you write cleaner, more maintainable, and more elegant software.

  Topics covered include clean code principles, design patterns, testing strategies, performance optimisation, and much more.
DESC
publication.custom_fields["publication_author_ids"] = [admin.id]
publication.custom_fields["publication_access_tiers"] = { "everyone" => "community" }
publication.custom_fields["publication_feedback_settings"] = {
  "comments_enabled" => true,
  "suggestions_enabled" => true,
}
publication.save_custom_fields

puts "Set publication custom fields"

# Chapter definitions with rich content
chapters = [
  {
    title: "Introduction: Why programming matters",
    number: 1,
    type: "chapter",
    summary:
      "An exploration of why programming is both an art and a science, and why it matters in the modern world.",
    content: <<~CONTENT,
      # Introduction: Why programming matters

      Programming is one of the most transformative skills of the 21st century. It's not just about writing code—it's about solving problems, automating tedious tasks, and creating tools that can change the world.

      ## The power of abstraction

      At its core, programming is about abstraction. We take complex real-world problems and break them down into smaller, manageable pieces. Each piece becomes a function, a class, or a module that we can reason about independently.

      > "The art of programming is the art of organising complexity, of mastering multitude and avoiding its bastard chaos as effectively as possible." — Edsger W. Dijkstra

      ## Why learn to program?

      There are many reasons to learn programming:

      1. **Problem solving** - Programming teaches you to think logically and break down complex problems
      2. **Automation** - Free yourself from repetitive tasks
      3. **Creation** - Build tools, apps, and systems that help others
      4. **Career opportunities** - Software development is one of the fastest-growing fields
      5. **Understanding technology** - Know how the digital world around you works

      ## What makes a great programmer?

      Great programmers share certain qualities:

      - **Curiosity** - Always wanting to understand how things work
      - **Patience** - Debugging can take hours, sometimes days
      - **Attention to detail** - A single typo can break everything
      - **Communication** - Code is read more than it's written
      - **Humility** - There's always more to learn

      ## Summary

      This chapter has introduced the fundamental reasons why programming matters. In the following chapters, we'll dive deeper into the practical skills and knowledge you need to become an effective programmer.
    CONTENT
    discussions: [
      {
        title: "What motivated you to learn programming?",
        body:
          "I'd love to hear everyone's stories about what first got them interested in programming. For me, it was wanting to build my own video games when I was 12!",
        replies: [
          "I started because I wanted to automate some boring spreadsheet work. Now I can't stop learning!",
          "My university required it, but I ended up loving it. Now I code for fun on weekends.",
          "I was fascinated by how websites worked and wanted to build my own.",
        ],
      },
      {
        title: "Best resources for beginners?",
        body:
          "Can anyone recommend good resources for someone just starting out? Books, courses, websites?",
        replies: [
          "I really liked 'Automate the Boring Stuff with Python' - it's free online!",
          "freeCodeCamp is excellent and completely free. Very hands-on approach.",
        ],
      },
    ],
  },
  {
    title: "The fundamentals of clean code",
    number: 2,
    type: "chapter",
    summary:
      "Understanding the principles that make code readable, maintainable, and a joy to work with.",
    content: <<~CONTENT,
      # The fundamentals of clean code

      Clean code is code that is easy to read, easy to understand, and easy to modify. It's not about being clever—it's about being clear.

      ## Naming things

      One of the hardest problems in programming is naming things. Good names make code self-documenting.

      ```ruby
      # Bad
      def calc(a, b)
        a * b * 0.1
      end

      # Good
      def calculate_tax(price, quantity)
        price * quantity * TAX_RATE
      end
      ```

      ### Rules for good names

      - Use intention-revealing names
      - Avoid abbreviations (except universally known ones like `id`, `url`)
      - Use pronounceable names
      - Use searchable names
      - Avoid mental mapping (don't make readers translate your code)

      ## Functions should do one thing

      A function should do one thing, do it well, and do it only. If a function is doing multiple things, break it apart.

      ```ruby
      # Bad - doing too much
      def process_order(order)
        validate_order(order)
        calculate_total(order)
        apply_discount(order)
        charge_payment(order)
        send_confirmation(order)
        update_inventory(order)
      end

      # Better - orchestrating single-purpose functions
      def process_order(order)
        validated_order = validate(order)
        priced_order = calculate_pricing(validated_order)
        charged_order = process_payment(priced_order)
        fulfil(charged_order)
      end
      ```

      ## Comments are a last resort

      Comments should explain *why*, not *what*. If you need a comment to explain what code does, the code should be rewritten to be clearer.

      > "A comment is a failure to express yourself in code." — Robert C. Martin

      ## The Boy Scout Rule

      Leave the code cleaner than you found it. Every time you touch a file, make one small improvement.

      ## Summary

      Clean code isn't about perfection—it's about communication. Code is read far more often than it's written, so optimise for readability.
    CONTENT
    discussions: [
      {
        title: "How do you handle legacy code that's a mess?",
        body:
          "I've inherited a codebase with zero tests, no documentation, and functions that are 500+ lines long. Where do I even start?",
        replies: [
          "Start by adding tests around the parts you need to change. Don't try to fix everything at once.",
          "I use the 'strangler fig' pattern - gradually replace old code with new clean code.",
          "Document what you learn as you go. Future you will thank present you.",
          "Focus on the pain points first. What breaks most often?",
        ],
      },
    ],
  },
  {
    title: "Design patterns in practice",
    number: 3,
    type: "chapter",
    summary: "Practical applications of common design patterns and when to use them.",
    content: <<~CONTENT,
      # Design patterns in practice

      Design patterns are reusable solutions to common problems in software design. They're not code you can copy-paste, but templates for how to solve problems.

      ## The Strategy Pattern

      Use strategy when you have multiple ways to do something and want to switch between them easily.

      ```ruby
      class PaymentProcessor
        def initialize(strategy)
          @strategy = strategy
        end

        def process(amount)
          @strategy.charge(amount)
        end
      end

      class CreditCardStrategy
        def charge(amount)
          # Credit card specific logic
        end
      end

      class PayPalStrategy
        def charge(amount)
          # PayPal specific logic
        end
      end

      # Usage
      processor = PaymentProcessor.new(CreditCardStrategy.new)
      processor.process(100)
      ```

      ## The Observer Pattern

      When one object needs to notify multiple objects about changes, use the observer pattern.

      ```ruby
      class EventEmitter
        def initialize
          @listeners = Hash.new { |h, k| h[k] = [] }
        end

        def on(event, &block)
          @listeners[event] << block
        end

        def emit(event, *args)
          @listeners[event].each { |listener| listener.call(*args) }
        end
      end
      ```

      ## The Repository Pattern

      Separate your domain logic from data access concerns.

      ## When NOT to use patterns

      Don't use a pattern just because you can. Patterns add complexity. Use them when:

      - The problem they solve actually exists in your code
      - The added complexity is worth the flexibility
      - Your team understands the pattern

      > "Patterns are a starting point, not a destination." — Martin Fowler

      ## Summary

      Patterns are tools, not rules. Learn them, understand when they're useful, and apply them judiciously.
    CONTENT
    discussions: [
      {
        title: "Favourite design pattern?",
        body:
          "What's everyone's favourite pattern and why? I find myself using the Repository pattern constantly.",
        replies: [
          "Dependency injection! It makes testing so much easier.",
          "I love the Decorator pattern for adding behaviour without modifying existing code.",
        ],
      },
      {
        title: "Patterns that are overused?",
        body:
          "Are there patterns you think people overuse? I see Singleton everywhere and it often causes problems.",
        replies: [
          "Agreed on Singleton. It's basically a global variable with extra steps.",
          "Factory everything! Sometimes just using 'new' is fine.",
          "The Abstract Factory pattern - I've rarely seen it used appropriately.",
        ],
      },
    ],
  },
  {
    title: "Testing strategies",
    number: 4,
    type: "chapter",
    summary: "How to write tests that provide confidence without slowing you down.",
    content: <<~CONTENT,
      # Testing strategies

      Tests are your safety net. They give you confidence to refactor, add features, and fix bugs without breaking existing functionality.

      ## The testing pyramid

      ```
              /\\
             /  \\
            / E2E\\
           /------\\
          /  Integ \\
         /----------\\
        /    Unit    \\
       /--------------\\
      ```

      - **Unit tests** - Fast, isolated, test one thing
      - **Integration tests** - Test components working together
      - **E2E tests** - Test the whole system, slow but comprehensive

      ## What to test

      Test behaviour, not implementation. Ask: "What should this code do?" not "How does this code work?"

      ```ruby
      # Bad - testing implementation
      it "calls the database" do
        expect(database).to receive(:query)
        user_service.find(1)
      end

      # Good - testing behaviour
      it "returns the user with matching id" do
        user = user_service.find(1)
        expect(user.id).to eq(1)
        expect(user.name).to eq("Alice")
      end
      ```

      ## Test-driven development (TDD)

      1. Write a failing test
      2. Write the minimum code to pass
      3. Refactor
      4. Repeat

      TDD forces you to think about design before implementation.

      ## When tests slow you down

      - Tests that are too coupled to implementation
      - Tests that require complex setup
      - Flaky tests that sometimes pass, sometimes fail

      Fix these immediately. Bad tests are worse than no tests.

      ## Summary

      Good tests are an investment. They take time to write but save time in the long run through faster debugging and safer refactoring.
    CONTENT
    discussions: [
      {
        title: "How much test coverage is enough?",
        body:
          "My team is debating test coverage targets. Some want 100%, others say 80% is fine. What do you think?",
        replies: [
          "Coverage percentage is a vanity metric. Focus on testing critical paths and edge cases.",
          "I aim for 100% on business logic, less on glue code.",
          "The goal isn't coverage, it's confidence. Can you refactor without fear?",
        ],
      },
    ],
  },
  {
    title: "Performance optimisation",
    number: 5,
    type: "chapter",
    summary: "Identifying and fixing performance bottlenecks without premature optimisation.",
    content: <<~CONTENT,
      # Performance optimisation

      > "Premature optimisation is the root of all evil." — Donald Knuth

      ## Measure first

      Never optimise without measuring. Your intuition about what's slow is often wrong.

      ### Profiling tools

      - **Ruby**: rack-mini-profiler, stackprof, memory_profiler
      - **JavaScript**: Chrome DevTools, Lighthouse
      - **Database**: EXPLAIN ANALYZE, pg_stat_statements

      ## Common performance issues

      ### N+1 queries

      ```ruby
      # Bad - N+1 queries
      posts = Post.all
      posts.each do |post|
        puts post.author.name  # Queries author for each post!
      end

      # Good - eager loading
      posts = Post.includes(:author).all
      posts.each do |post|
        puts post.author.name  # No additional queries
      end
      ```

      ### Memory bloat

      - Load data in batches with `find_each`
      - Avoid loading entire tables into memory
      - Watch for memory leaks in long-running processes

      ### Unnecessary computation

      - Cache expensive calculations
      - Use memoisation for repeated calls
      - Consider background jobs for heavy processing

      ## When to optimise

      1. You have evidence of a performance problem
      2. You've measured and identified the bottleneck
      3. The optimisation is worth the complexity cost

      ## Summary

      Make it work, make it right, make it fast—in that order. Optimise based on data, not hunches.
    CONTENT
    discussions: [
      {
        title: "Worst performance bug you've encountered?",
        body: "Share your horror stories! What's the worst performance issue you've debugged?",
        replies: [
          "A single missing database index was causing 30-second page loads. Added the index, dropped to 30ms.",
          "Someone was serialising and deserialising JSON in a loop. 10,000 times per request.",
          "A 'temporary' sleep(5) someone added for debugging and forgot to remove. In production. For 3 months.",
        ],
      },
    ],
  },
  {
    title: "Working with legacy systems",
    number: 6,
    type: "chapter",
    summary: "Strategies for maintaining, improving, and eventually replacing legacy code.",
    content: <<~CONTENT,
      # Working with legacy systems

      All code becomes legacy eventually. Learning to work with legacy systems is an essential skill.

      ## What is legacy code?

      Michael Feathers defines legacy code as "code without tests." More broadly, it's code that:

      - Is difficult to understand
      - Is risky to change
      - Has unclear ownership
      - Uses outdated practices or technologies

      ## The strangler fig pattern

      Gradually replace old functionality with new code:

      1. Build new functionality alongside the old
      2. Route some traffic to the new code
      3. Gradually increase traffic to the new code
      4. Remove the old code when it's no longer needed

      ## Adding tests to legacy code

      You can't refactor safely without tests. But how do you add tests to code that wasn't designed to be tested?

      ### Characterisation tests

      These tests document existing behaviour, bugs and all:

      ```ruby
      it "returns the weird calculated value" do
        # We don't know why it's 42, but that's what it does
        expect(legacy_calculator.compute(10)).to eq(42)
      end
      ```

      ### Seam testing

      Find places where you can inject test doubles without changing the code structure.

      ## When to rewrite

      Rewriting from scratch is almost always a mistake. Instead:

      - Improve incrementally
      - Replace one component at a time
      - Keep the old system running until the new one is proven

      ## Summary

      Legacy code is job security. Learn to love it, or at least tolerate it.
    CONTENT
    discussions: [],
  },
]

puts "\n--- Creating chapters and discussions ---"

chapters.each do |ch|
  puts "\nCreating chapter #{ch[:number]}: #{ch[:title]}"

  # Create chapter subcategory
  chapter_slug = "chapter-#{ch[:number]}"
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
  chapter.custom_fields["bookclub_chapter_type"] = ch[:type]
  chapter.custom_fields["bookclub_chapter_number"] = ch[:number]
  chapter.custom_fields["bookclub_chapter_access_level"] = "free"
  chapter.custom_fields["bookclub_chapter_published"] = true
  chapter.custom_fields["bookclub_chapter_summary"] = ch[:summary]
  chapter.custom_fields["bookclub_chapter_word_count"] = ch[:content].split.size
  chapter.save_custom_fields

  puts "  Created chapter category (ID: #{chapter.id})"

  # Create the content topic (pinned)
  post_creator =
    PostCreator.new(
      admin,
      title: ch[:title],
      raw: ch[:content],
      category: chapter.id,
      skip_validations: true,
    )

  result = post_creator.create
  if result
    content_topic = result.topic
    content_topic.update!(pinned_at: Time.current, pinned_globally: false)
    content_topic.custom_fields["bookclub_content_topic"] = true
    content_topic.save_custom_fields
    puts "  Created content topic (ID: #{content_topic.id})"
  else
    puts "  ERROR: #{post_creator.errors.full_messages.join(", ")}"
    next
  end

  # Create discussion topics with replies
  ch[:discussions].each_with_index do |discussion, idx|
    discussion_user = test_users[idx % test_users.length]

    discussion_creator =
      PostCreator.new(
        discussion_user,
        title: discussion[:title],
        raw: discussion[:body],
        category: chapter.id,
        skip_validations: true,
      )

    discussion_result = discussion_creator.create
    if discussion_result
      discussion_topic = discussion_result.topic
      puts "  Created discussion: #{discussion[:title]} (ID: #{discussion_topic.id})"

      # Add replies
      discussion[:replies].each_with_index do |reply_text, reply_idx|
        reply_user = test_users[(idx + reply_idx + 1) % test_users.length]

        reply_creator =
          PostCreator.new(
            reply_user,
            topic_id: discussion_topic.id,
            raw: reply_text,
            skip_validations: true,
          )

        reply_result = reply_creator.create
        puts "    Added reply from #{reply_user.username}" if reply_result
      end
    end
  end
end

# Create a second publication (a journal) for variety
puts "\n--- Creating second publication (journal) ---"

journal =
  Category.create!(
    name: "Journal of Software Engineering",
    slug: "jse",
    user: admin,
    color: "8B0000",
    text_color: "FFFFFF",
  )

journal.custom_fields["publication_enabled"] = true
journal.custom_fields["publication_slug"] = "software-engineering-journal"
journal.custom_fields["publication_type"] = "journal"
journal.custom_fields[
  "publication_description"
] = "A peer-reviewed journal covering advances in software engineering research and practice."
journal.custom_fields["publication_author_ids"] = [admin.id]
journal.custom_fields["publication_access_tiers"] = { "everyone" => "community" }
journal.save_custom_fields

puts "Created journal: #{journal.name}"

# Create an article in the journal
article_chapter =
  Category.create!(
    name: "Microservices: A decade in review",
    slug: "article-1",
    user: admin,
    parent_category_id: journal.id,
    color: journal.color,
    text_color: journal.text_color,
  )

article_chapter.custom_fields["bookclub_chapter_enabled"] = true
article_chapter.custom_fields["bookclub_chapter_type"] = "article"
article_chapter.custom_fields["bookclub_chapter_number"] = 1
article_chapter.custom_fields["bookclub_chapter_access_level"] = "free"
article_chapter.custom_fields["bookclub_chapter_published"] = true
article_chapter.custom_fields[
  "bookclub_chapter_summary"
] = "A retrospective on microservices architecture after ten years of industry adoption."
article_chapter.save_custom_fields

article_content = <<~CONTENT
  # Microservices: A decade in review

  It has been over a decade since microservices architecture emerged as a dominant paradigm in software development. This article examines the promises, the reality, and the lessons learned.

  ## Abstract

  Microservices architecture promised scalability, team autonomy, and technological flexibility. After ten years of industry adoption, we have enough data to evaluate these claims critically.

  ## Introduction

  The term "microservices" was coined around 2011-2012, but the ideas behind it are older. This article traces the evolution of the architectural style and evaluates its real-world impact.

  ## Key findings

  1. **Operational complexity increased dramatically** - Most organisations underestimated the operational burden
  2. **Team autonomy improved** - But at the cost of system-wide coherence
  3. **Scaling benefits were real** - But only for organisations at sufficient scale
  4. **Technology diversity became a liability** - Polyglot persistence sounds good until you need to hire

  ## Conclusion

  Microservices are a tool, not a goal. Choose your architecture based on your actual needs, not industry trends.
CONTENT

article_post =
  PostCreator.new(
    admin,
    title: "Microservices: A decade in review",
    raw: article_content,
    category: article_chapter.id,
    skip_validations: true,
  )

article_result = article_post.create
if article_result
  article_topic = article_result.topic
  article_topic.update!(pinned_at: Time.current, pinned_globally: false)
  article_topic.custom_fields["bookclub_content_topic"] = true
  article_topic.save_custom_fields
  puts "Created article content"
end

puts "\n" + "=" * 60
puts "Done! Created:"
puts "  - 1 book with 6 chapters"
puts "  - 1 journal with 1 article"
puts "  - Multiple discussion topics with replies"
puts "=" * 60
puts "\nTo test:"
puts "  1. Restart your Rails server"
puts "  2. Visit http://localhost:4200/book/art-of-programming"
puts "  3. Visit http://localhost:4200/book/art-of-programming/1"
puts "  4. Visit http://localhost:4200/latest"
puts ""
