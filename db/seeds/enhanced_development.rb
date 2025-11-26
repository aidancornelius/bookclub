# frozen_string_literal: true

# Enhanced Bookclub Plugin Development Seed Data
# This file creates comprehensive sample data including:
# - Multiple publications (books, journals)
# - Users with different roles and access levels
# - Access tier groups
# - Sample discussions
# - Reading progress data

puts "=========================================="
puts "Loading Enhanced Bookclub Development Seed Data"
puts "=========================================="
puts ""

# Ensure the plugin is enabled
unless SiteSetting.bookclub_enabled
  puts "Enabling Bookclub plugin..."
  SiteSetting.bookclub_enabled = true
end

# =============================================================================
# Create test users with different roles
# =============================================================================

puts "Creating test users..."

# Admin user (will have all permissions)
admin_user =
  User.find_or_create_by!(username: "bookclub_admin") do |u|
    u.email = "admin@bookclub.test"
    u.name = "Bookclub Administrator"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.admin = true
    u.trust_level = TrustLevel[4]
  end
admin_user.activate
admin_user.update!(admin: true) unless admin_user.admin?
puts "  ✓ Created admin user: #{admin_user.username}"

# Author users
author1 =
  User.find_or_create_by!(username: "alice_author") do |u|
    u.email = "alice@bookclub.test"
    u.name = "Alice Author"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[2]
  end
author1.activate
puts "  ✓ Created author user: #{author1.username}"

author2 =
  User.find_or_create_by!(username: "bob_writer") do |u|
    u.email = "bob@bookclub.test"
    u.name = "Bob Writer"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[2]
  end
author2.activate
puts "  ✓ Created author user: #{author2.username}"

# Editor user
editor_user =
  User.find_or_create_by!(username: "carol_editor") do |u|
    u.email = "carol@bookclub.test"
    u.name = "Carol Editor"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[3]
  end
editor_user.activate
puts "  ✓ Created editor user: #{editor_user.username}"

# Reader users with different access tiers
community_reader =
  User.find_or_create_by!(username: "dave_community") do |u|
    u.email = "dave@bookclub.test"
    u.name = "Dave Community Member"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[1]
  end
community_reader.activate
puts "  ✓ Created community reader: #{community_reader.username}"

member_reader =
  User.find_or_create_by!(username: "eve_member") do |u|
    u.email = "eve@bookclub.test"
    u.name = "Eve Member"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[2]
  end
member_reader.activate
puts "  ✓ Created member reader: #{member_reader.username}"

supporter_reader =
  User.find_or_create_by!(username: "frank_supporter") do |u|
    u.email = "frank@bookclub.test"
    u.name = "Frank Supporter"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[2]
  end
supporter_reader.activate
puts "  ✓ Created supporter reader: #{supporter_reader.username}"

patron_reader =
  User.find_or_create_by!(username: "grace_patron") do |u|
    u.email = "grace@bookclub.test"
    u.name = "Grace Patron"
    u.password = "password123"
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[3]
  end
patron_reader.activate
puts "  ✓ Created patron reader: #{patron_reader.username}"

puts ""

# =============================================================================
# Create access tier groups
# =============================================================================

puts "Creating access tier groups..."

community_group =
  Group.find_or_create_by!(name: "bookclub_community") do |g|
    g.visibility_level = Group.visibility_levels[:public]
    g.title = "Community Members"
    g.bio_raw = "Free community tier with access to free content"
  end
community_group.add(community_reader)
community_group.add(member_reader)
community_group.add(supporter_reader)
community_group.add(patron_reader)
puts "  ✓ Created community tier group: #{community_group.name}"

member_group =
  Group.find_or_create_by!(name: "bookclub_members") do |g|
    g.visibility_level = Group.visibility_levels[:public]
    g.title = "Members"
    g.bio_raw = "Basic paid tier with access to member content"
  end
member_group.add(member_reader)
member_group.add(supporter_reader)
member_group.add(patron_reader)
puts "  ✓ Created member tier group: #{member_group.name}"

supporter_group =
  Group.find_or_create_by!(name: "bookclub_supporters") do |g|
    g.visibility_level = Group.visibility_levels[:public]
    g.title = "Supporters"
    g.bio_raw = "Supporter tier with access to most content"
  end
supporter_group.add(supporter_reader)
supporter_group.add(patron_reader)
puts "  ✓ Created supporter tier group: #{supporter_group.name}"

patron_group =
  Group.find_or_create_by!(name: "bookclub_patrons") do |g|
    g.visibility_level = Group.visibility_levels[:public]
    g.title = "Patrons"
    g.bio_raw = "Top tier with access to all content and exclusive perks"
  end
patron_group.add(patron_reader)
puts "  ✓ Created patron tier group: #{patron_group.name}"

puts ""

# =============================================================================
# Create a comprehensive book publication
# =============================================================================

puts "Creating comprehensive book publication..."

book_category =
  Category.find_or_create_by!(name: "The Ruby Way: Modern Best Practices") do |c|
    c.user_id = author1.id
    c.description =
      "A comprehensive guide to modern Ruby programming, covering everything from fundamentals to advanced metaprogramming techniques."
    c.color = "0088CC"
    c.text_color = "FFFFFF"
  end

# Set publication custom fields
book_category.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
book_category.custom_fields[Bookclub::PUBLICATION_TYPE] = "book"
book_category.custom_fields[Bookclub::PUBLICATION_SLUG] = "the-ruby-way"
book_category.custom_fields[Bookclub::PUBLICATION_COVER_URL] =
  "https://via.placeholder.com/400x600/0088CC/FFFFFF?text=The+Ruby+Way"
book_category.custom_fields[Bookclub::PUBLICATION_DESCRIPTION] =
  "This comprehensive guide takes you through modern Ruby development, from basic syntax to advanced metaprogramming. Perfect for intermediate developers looking to level up their Ruby skills."
book_category.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS] = [author1.id, author2.id].to_json
book_category.custom_fields[Bookclub::PUBLICATION_EDITOR_IDS] = [editor_user.id].to_json
book_category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
  bookclub_community: "community",
  bookclub_members: "member",
  bookclub_supporters: "supporter",
  bookclub_patrons: "patron",
}.to_json
book_category.custom_fields[Bookclub::PUBLICATION_FEEDBACK_SETTINGS] = {
  "enabled" => true,
  "allowed_types" => %w[comment suggestion endorsement],
}.to_json
book_category.custom_fields[Bookclub::PUBLICATION_IDENTIFIER] = "978-0-123456-78-9"
book_category.save!

puts "  ✓ Created book publication: #{book_category.name}"
puts ""

# Create chapters for the book
puts "Creating book chapters..."

chapters_data = [
  {
    title: "Chapter 1: Introduction to Modern Ruby",
    content:
      "# Welcome to Modern Ruby\n\nRuby has evolved significantly since its creation by Yukihiro Matsumoto in 1995. This chapter explores what makes Ruby special and why it remains relevant in modern software development.\n\n## The Philosophy of Ruby\n\nRuby was designed with developer happiness as a primary goal. Matz (Matsumoto) wanted a language that was both powerful and pleasant to use.\n\n```ruby\n5.times { puts 'Ruby is elegant!' }\n```\n\n## Why Ruby in 2024?\n\nDespite the rise of many new languages, Ruby continues to thrive:\n\n- **Rails**: Still powers major web applications\n- **Simplicity**: Clean, readable syntax\n- **Community**: Welcoming and helpful\n- **Productivity**: Get things done quickly\n\n## What You'll Learn\n\nThis book will take you from Ruby fundamentals to advanced techniques, covering:\n\n1. Core language features\n2. Object-oriented design patterns\n3. Metaprogramming techniques\n4. Performance optimisation\n5. Testing and quality assurance\n\nLet's begin this journey together!",
    number: 1,
    access: "free",
    published: true,
  },
  {
    title: "Chapter 2: Ruby Fundamentals Refresher",
    content:
      "# Ruby Fundamentals\n\nBefore diving into advanced topics, let's ensure we have a solid foundation.\n\n## Variables and Constants\n\nRuby has several types of variables:\n\n```ruby\n# Local variable\nname = 'Alice'\n\n# Instance variable\n@age = 30\n\n# Class variable\n@@count = 0\n\n# Constant\nMAX_SIZE = 100\n```\n\n## Data Types\n\nRuby's core data types are flexible and powerful:\n\n```ruby\n# Numbers\ninteger = 42\nfloat = 3.14\n\n# Strings\ngreeting = 'Hello, World!'\nmultiline = <<~TEXT\n  This is a\n  multiline string\nTEXT\n\n# Symbols\nstatus = :active\n\n# Arrays\ncolours = ['red', 'green', 'blue']\n\n# Hashes\nuser = { name: 'Alice', age: 30 }\n```\n\n## Control Flow\n\nRuby offers elegant control structures:\n\n```ruby\n# Conditionals\nif temperature > 30\n  puts 'Hot!'\nelsif temperature > 20\n  puts 'Nice'\nelse\n  puts 'Cold'\nend\n\n# Loops\n10.times do |i|\n  puts \"Iteration #{i}\"\nend\n\ncolours.each do |colour|\n  puts colour\nend\n```\n\n## Methods\n\nMethods in Ruby are first-class citizens:\n\n```ruby\ndef greet(name, greeting: 'Hello')\n  \"#{greeting}, #{name}!\"\nend\n\nputs greet('Alice')\nputs greet('Bob', greeting: 'Hi')\n```",
    number: 2,
    access: "free",
    published: true,
  },
  {
    title: "Chapter 3: Object-Oriented Ruby",
    content:
      "# Object-Oriented Programming in Ruby\n\nRuby is a pure object-oriented language. Everything is an object, including numbers and booleans.\n\n## Defining Classes\n\n```ruby\nclass Book\n  attr_reader :title, :author\n  attr_accessor :isbn\n\n  def initialize(title, author)\n    @title = title\n    @author = author\n    @published = false\n  end\n\n  def publish!\n    @published = true\n  end\n\n  def published?\n    @published\n  end\nend\n```\n\n## Inheritance\n\nRuby supports single inheritance:\n\n```ruby\nclass EBook < Book\n  attr_accessor :format\n\n  def initialize(title, author, format: :epub)\n    super(title, author)\n    @format = format\n  end\nend\n```\n\n## Modules and Mixins\n\nModules provide multiple inheritance through mixins:\n\n```ruby\nmodule Reviewable\n  def add_review(review)\n    @reviews ||= []\n    @reviews << review\n  end\n\n  def average_rating\n    return 0 if @reviews.nil? || @reviews.empty?\n    @reviews.sum(&:rating) / @reviews.size.to_f\n  end\nend\n\nclass Book\n  include Reviewable\nend\n```\n\n## Encapsulation\n\nRuby provides three levels of visibility:\n\n```ruby\nclass BankAccount\n  def initialize(balance)\n    @balance = balance\n  end\n\n  def deposit(amount)\n    validate_amount!(amount)\n    @balance += amount\n  end\n\n  private\n\n  def validate_amount!(amount)\n    raise ArgumentError, 'Amount must be positive' if amount <= 0\n  end\nend\n```",
    number: 3,
    access: "member",
    published: true,
  },
  {
    title: "Chapter 4: Blocks, Procs, and Lambdas",
    content:
      "# Blocks, Procs, and Lambdas\n\nOne of Ruby's most powerful features is its support for closures through blocks, procs, and lambdas.\n\n## Blocks\n\nBlocks are anonymous pieces of code:\n\n```ruby\n[1, 2, 3].each do |num|\n  puts num * 2\nend\n\n# Single line blocks use braces\n[1, 2, 3].map { |n| n * 2 }\n```\n\n## Yielding to Blocks\n\n```ruby\ndef with_logging\n  puts 'Starting...'\n  yield if block_given?\n  puts 'Finished!'\nend\n\nwith_logging do\n  puts 'Doing work'\nend\n```\n\n## Procs\n\nProcs are objects that encapsulate blocks:\n\n```ruby\ndoubler = Proc.new { |x| x * 2 }\nputs doubler.call(5)  # => 10\n\n# Procs can be passed as arguments\nnumbers = [1, 2, 3]\nresult = numbers.map(&doubler)\n```\n\n## Lambdas\n\nLambdas are similar to procs but with stricter argument checking:\n\n```ruby\nmultiplier = lambda { |x, y| x * y }\n# or\nmultiplier = ->(x, y) { x * y }\n\nputs multiplier.call(3, 4)  # => 12\n```\n\n## Differences Between Procs and Lambdas\n\n```ruby\n# Argument checking\nproc = Proc.new { |x, y| puts \"#{x}, #{y}\" }\nproc.call(1)  # => \"1, \"  (missing arg becomes nil)\n\nlambda = ->(x, y) { puts \"#{x}, #{y}\" }\n# lambda.call(1)  # => ArgumentError\n\n# Return behaviour\ndef proc_return\n  Proc.new { return 'from proc' }.call\n  'from method'\nend\n\ndef lambda_return\n  ->{return 'from lambda'}.call\n  'from method'\nend\n\nputs proc_return    # => 'from proc'\nputs lambda_return  # => 'from method'\n```",
    number: 4,
    access: "member",
    published: true,
  },
  {
    title: "Chapter 5: Metaprogramming Magic",
    content:
      "# Metaprogramming in Ruby\n\nMetaprogramming is writing code that writes code. Ruby's dynamic nature makes it particularly powerful for metaprogramming.\n\n## method_missing\n\nIntercept calls to undefined methods:\n\n```ruby\nclass FlexibleObject\n  def method_missing(method_name, *args)\n    if method_name.to_s.start_with?('find_by_')\n      attribute = method_name.to_s.sub('find_by_', '')\n      find_by_attribute(attribute, args.first)\n    else\n      super\n    end\n  end\n\n  def respond_to_missing?(method_name, include_private = false)\n    method_name.to_s.start_with?('find_by_') || super\n  end\nend\n```\n\n## define_method\n\nDynamically define methods:\n\n```ruby\nclass Calculator\n  %w[add subtract multiply divide].each do |operation|\n    define_method(operation) do |a, b|\n      a.send(operation == 'add' ? :+ : operation == 'subtract' ? :- : operation == 'multiply' ? :* : :/, b)\n    end\n  end\nend\n```\n\n## class_eval and instance_eval\n\n```ruby\nclass MyClass\nend\n\n# Add class methods\nMyClass.class_eval do\n  def instance_method\n    'I am an instance method'\n  end\nend\n\n# Add singleton methods\nobj = MyClass.new\nobj.instance_eval do\n  def singleton_method\n    'I am unique to this instance'\n  end\nend\n```\n\n## const_missing\n\nLazy-load constants:\n\n```ruby\nmodule LazyLoader\n  def const_missing(name)\n    require name.to_s.downcase\n    const_get(name)\n  end\nend\n```\n\n## Practical Example: ActiveRecord-style Associations\n\n```ruby\nmodule Associations\n  def has_many(name)\n    define_method(name) do\n      instance_variable_get(\"@#{name}\") || instance_variable_set(\"@#{name}\", [])\n    end\n\n    define_method(\"add_#{name.to_s.singularize}\") do |item|\n      send(name) << item\n    end\n  end\nend\n\nclass Author\n  extend Associations\n  has_many :books\nend\n\nauthor = Author.new\nauthor.add_book(book1)\nauthor.add_book(book2)\nputs author.books.size  # => 2\n```",
    number: 5,
    access: "supporter",
    published: true,
  },
  {
    title: "Chapter 6: Performance Optimisation",
    content:
      "# Performance Optimisation in Ruby\n\nWhile Ruby prioritises developer happiness over raw speed, there are many ways to optimise performance.\n\n## Profiling\n\nBefore optimising, measure:\n\n```ruby\nrequire 'benchmark'\n\nBenchmark.bm do |x|\n  x.report('approach 1:') { 1000.times { slow_method } }\n  x.report('approach 2:') { 1000.times { fast_method } }\nend\n```\n\n## Common Optimisations\n\n### Use Symbols Instead of Strings for Hash Keys\n\n```ruby\n# Slow\nhash = { 'name' => 'Alice', 'age' => 30 }\n\n# Fast\nhash = { name: 'Alice', age: 30 }\n```\n\n### Avoid Unnecessary Object Creation\n\n```ruby\n# Slow - creates new string each iteration\n1000.times do\n  result = 'Hello'\nend\n\n# Fast - reuses frozen string\nGREETING = 'Hello'.freeze\n1000.times do\n  result = GREETING\nend\n```\n\n### Use each Instead of map When Not Using Result\n\n```ruby\n# Slow - creates unused array\nusers.map { |user| user.notify! }\n\n# Fast - no array created\nusers.each { |user| user.notify! }\n```\n\n## Memory Management\n\n```ruby\n# Use lazy enumerators for large collections\nrange = (1..1_000_000)\n\n# Loads all into memory\nresult = range.select { |n| n.even? }.map { |n| n * 2 }.first(10)\n\n# Lazy evaluation - only processes what's needed\nresult = range.lazy.select { |n| n.even? }.map { |n| n * 2 }.first(10)\n```\n\n## JIT Compilation\n\nRuby 3+ includes YJIT:\n\n```ruby\n# Enable YJIT\nruby --yjit script.rb\n```",
    number: 6,
    access: "supporter",
    published: true,
  },
  {
    title: "Chapter 7: Testing Like a Pro",
    content:
      "# Professional Testing in Ruby\n\nGood tests are essential for maintainable code.\n\n## RSpec Best Practices\n\n```ruby\nRSpec.describe Book do\n  describe '#publish!' do\n    it 'changes published status to true' do\n      book = Book.new('The Ruby Way', 'Alice')\n      expect { book.publish! }.to change(book, :published?).from(false).to(true)\n    end\n\n    it 'sends notification to subscribers' do\n      book = Book.new('The Ruby Way', 'Alice')\n      expect(NotificationService).to receive(:notify).with(book)\n      book.publish!\n    end\n  end\nend\n```\n\n## Factory Patterns\n\n```ruby\n# Using FactoryBot\nFactoryBot.define do\n  factory :book do\n    title { Faker::Book.title }\n    author { Faker::Book.author }\n    isbn { Faker::Code.isbn }\n\n    trait :published do\n      published { true }\n      published_at { 1.week.ago }\n    end\n  end\nend\n\n# Usage\nbook = create(:book)\npublished_book = create(:book, :published)\n```\n\n## Test Doubles and Mocks\n\n```ruby\nRSpec.describe BookPublisher do\n  it 'publishes book and sends notifications' do\n    book = double('book', publish!: true, title: 'Test')\n    notifier = double('notifier')\n\n    expect(notifier).to receive(:send_notification).with(book)\n\n    publisher = BookPublisher.new(book, notifier)\n    publisher.publish\n  end\nend\n```",
    number: 7,
    access: "patron",
    published: true,
  },
  {
    title: "Chapter 8: Conclusion and Next Steps",
    content:
      "# Conclusion: Your Ruby Journey Continues\n\nCongratulations on completing The Ruby Way! You've learned modern Ruby from fundamentals to advanced techniques.\n\n## What You've Achieved\n\nYou can now:\n\n- Write clean, idiomatic Ruby code\n- Design object-oriented systems\n- Use advanced features like metaprogramming\n- Optimise for performance\n- Write comprehensive tests\n\n## Next Steps\n\n1. **Build Something**: Apply what you've learned to a real project\n2. **Contribute**: Join open source Ruby projects\n3. **Learn Rails**: If you haven't already, explore Ruby on Rails\n4. **Stay Current**: Follow Ruby news and community discussions\n\n## Resources\n\n- [Ruby Documentation](https://ruby-doc.org)\n- [RubyGems](https://rubygems.org)\n- [Ruby Weekly Newsletter](https://rubyweekly.com)\n- [Ruby Discord/Slack Communities](https://www.ruby-lang.org/en/community/)\n\n## Thank You\n\nThank you for reading The Ruby Way. Keep coding, keep learning, and most importantly, enjoy Ruby!\n\nHappy coding! 💎",
    number: 8,
    access: "patron",
    published: true,
  },
]

chapters_data.each do |chapter_data|
  topic =
    Topic.find_or_initialize_by(title: chapter_data[:title], category: book_category)

  unless topic.persisted?
    topic.user = author1
    topic.skip_validations = true
    topic.save!

    post =
      Post.create!(
        topic: topic,
        user: author1,
        raw: chapter_data[:content],
        skip_validations: true,
      )
  else
    post = topic.first_post
  end

  # Set content custom fields on topic
  topic.custom_fields[Bookclub::CONTENT_TOPIC] = true
  topic.custom_fields[Bookclub::CONTENT_TYPE] = "chapter"
  topic.custom_fields[Bookclub::CONTENT_NUMBER] = chapter_data[:number]
  topic.custom_fields[Bookclub::CONTENT_ACCESS_LEVEL] = chapter_data[:access]
  topic.custom_fields[Bookclub::CONTENT_PUBLISHED] = chapter_data[:published]
  topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = chapter_data[:content].split.size
  topic.custom_fields[Bookclub::CONTENT_SUMMARY] =
    "Chapter #{chapter_data[:number]} of The Ruby Way"
  topic.custom_fields[Bookclub::CONTENT_CONTRIBUTORS] = [author1.id].to_json
  topic.custom_fields[Bookclub::CONTENT_REVIEW_STATUS] = "published"
  topic.save_custom_fields

  puts "  ✓ Created chapter #{chapter_data[:number]}: #{chapter_data[:title]}"
end

puts ""

# =============================================================================
# Create sample discussions for chapters
# =============================================================================

puts "Creating sample discussions..."

sample_chapter = Topic.where(title: "Chapter 3: Object-Oriented Ruby").first
if sample_chapter
  discussion1 =
    Topic.find_or_initialize_by(
      title: "Question about inheritance vs composition",
      category: book_category,
    )

  unless discussion1.persisted?
    discussion1.user = member_reader
    discussion1.save!

    Post.create!(
      topic: discussion1,
      user: member_reader,
      raw:
        "Great chapter! I'm wondering when you would choose inheritance over composition. Can you provide more real-world examples?",
    )

    # Author reply
    Post.create!(
      topic: discussion1,
      user: author1,
      raw:
        "Excellent question! In general, prefer composition when you have a 'has-a' relationship and inheritance for 'is-a' relationships.\n\nFor example:\n\n```ruby\n# Inheritance (is-a)\nclass ElectricCar < Car\nend\n\n# Composition (has-a)\nclass Car\n  attr_reader :engine\n  \n  def initialize\n    @engine = Engine.new\n  end\nend\n```\n\nComposition gives you more flexibility to change behaviour at runtime.",
    )
  end

  puts "  ✓ Created discussion: #{discussion1.title}"
end

puts ""

# =============================================================================
# Create a journal publication
# =============================================================================

puts "Creating journal publication..."

journal_category =
  Category.find_or_create_by!(name: "Ruby & Rails Quarterly") do |c|
    c.user_id = editor_user.id
    c.description =
      "A peer-reviewed quarterly journal covering Ruby, Rails, and the broader Ruby ecosystem."
    c.color = "EE5533"
    c.text_color = "FFFFFF"
  end

journal_category.custom_fields[Bookclub::PUBLICATION_ENABLED] = true
journal_category.custom_fields[Bookclub::PUBLICATION_TYPE] = "journal"
journal_category.custom_fields[Bookclub::PUBLICATION_SLUG] = "ruby-rails-quarterly"
journal_category.custom_fields[Bookclub::PUBLICATION_COVER_URL] =
  "https://via.placeholder.com/400x600/EE5533/FFFFFF?text=RRQ"
journal_category.custom_fields[Bookclub::PUBLICATION_DESCRIPTION] =
  "In-depth technical articles, case studies, and research on Ruby and Rails development."
journal_category.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS] = [].to_json
journal_category.custom_fields[Bookclub::PUBLICATION_EDITOR_IDS] = [editor_user.id].to_json
journal_category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] = {
  bookclub_members: "member",
}.to_json
journal_category.custom_fields[Bookclub::PUBLICATION_IDENTIFIER] = "ISSN 2024-0001"
journal_category.save!

puts "  ✓ Created journal: #{journal_category.name}"

puts ""
puts "=========================================="
puts "Enhanced seed data loaded successfully!"
puts "=========================================="
puts ""
puts "Test Users (all use password: password123):"
puts "  Admin: bookclub_admin"
puts "  Authors: alice_author, bob_writer"
puts "  Editor: carol_editor"
puts "  Community: dave_community (community tier)"
puts "  Member: eve_member (member tier)"
puts "  Supporter: frank_supporter (supporter tier)"
puts "  Patron: grace_patron (patron tier - full access)"
puts ""
puts "Publications:"
puts "  Book: The Ruby Way (8 chapters with tiered access)"
puts "  Journal: Ruby & Rails Quarterly"
puts ""
puts "Access Tiers:"
puts "  Community: #{community_group.name} (ID: #{community_group.id})"
puts "  Member: #{member_group.name} (ID: #{member_group.id})"
puts "  Supporter: #{supporter_group.name} (ID: #{supporter_group.id})"
puts "  Patron: #{patron_group.name} (ID: #{patron_group.id})"
puts ""
puts "Try logging in as different users to test access control!"
puts ""
