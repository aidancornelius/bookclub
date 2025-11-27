# frozen_string_literal: true

desc "Import a book into Bookclub from a file"
task "bookclub:import" => :environment do
  file_path = ENV["FILE"]
  slug = ENV["SLUG"]
  publish = ENV["PUBLISH"] == "true"
  access_level = ENV["ACCESS_LEVEL"] || "free"
  replace = ENV["REPLACE"] == "true"

  if file_path.blank?
    puts "Usage: rake bookclub:import FILE=/path/to/book.md [SLUG=custom-slug] [PUBLISH=true] [ACCESS_LEVEL=free] [REPLACE=true]"
    puts ""
    puts "Supported formats:"
    puts "  - Markdown (.md, .markdown) - Use # headers for chapter titles"
    puts "  - Plain text (.txt) - Use CHAPTER I markers"
    puts "  - TextPack/ZIP (.textpack, .zip) - iA Writer/Ulysses export"
    puts ""
    puts "Options:"
    puts "  FILE         - Path to the book file (required)"
    puts "  SLUG         - Custom URL slug (auto-generated from title if not provided)"
    puts "  PUBLISH      - Set to 'true' to publish chapters immediately (default: false)"
    puts "  ACCESS_LEVEL - Default access level: free, member, supporter, patron (default: free)"
    puts "  REPLACE      - Set to 'true' to update existing publication (default: false)"
    exit 1
  end

  unless File.exist?(file_path)
    puts "Error: File not found at #{file_path}"
    exit 1
  end

  # Get admin user
  admin = User.find_by(admin: true)
  unless admin
    puts "Error: No admin user found"
    exit 1
  end

  puts "Importing: #{file_path}"
  puts "Using admin user: #{admin.username}"
  puts ""

  begin
    # Parse the book
    parsed_book = Bookclub::BookParser.parse(file_path: file_path)

    puts "Parsed book: #{parsed_book.title || "Untitled"}"
    puts "Found #{parsed_book.chapters.length} chapters:"
    parsed_book.chapters.each do |chapter|
      puts "  #{chapter.number}. #{chapter.title} (#{chapter.word_count} words)"
    end
    puts ""

    # Check for existing publication if slug provided
    if slug.present?
      existing =
        CategoryCustomField.find_by(name: Bookclub::PUBLICATION_SLUG, value: slug)&.category
      if existing && !replace
        puts "Error: Publication with slug '#{slug}' already exists (category ID: #{existing.id})"
        puts "Use REPLACE=true to update it, or choose a different slug"
        exit 1
      end
    end

    # Import the book
    importer =
      Bookclub::BookImporter.new(
        user: admin,
        parsed_book: parsed_book,
        slug: slug,
        publish: publish,
        access_level: access_level,
        replace_existing: replace,
        publication_id: existing&.id,
      )

    result = importer.import!

    if result.success
      puts "Import successful!"
      puts "Publication: #{result.publication.name} (ID: #{result.publication.id})"

      if result.chapters_created.any?
        puts "Created #{result.chapters_created.length} chapters:"
        result.chapters_created.each { |title| puts "  + #{title}" }
      end

      if result.chapters_updated.any?
        puts "Updated #{result.chapters_updated.length} chapters:"
        result.chapters_updated.each { |title| puts "  ~ #{title}" }
      end

      if result.errors.any?
        puts "Warnings:"
        result.errors.each { |err| puts "  ! #{err}" }
      end

      pub_slug = result.publication.custom_fields[Bookclub::PUBLICATION_SLUG]
      puts ""
      puts "Visit /book/#{pub_slug} to view the book"
    else
      puts "Import failed!"
      result.errors.each { |err| puts "  Error: #{err}" }
      exit 1
    end
  rescue Bookclub::BookParser::ParseError => e
    puts "Parse error: #{e.message}"
    exit 1
  rescue Bookclub::BookImporter::ImportError => e
    puts "Import error: #{e.message}"
    exit 1
  end
end

desc "Import Alice in Wonderland sample book"
task "bookclub:import_alice" => :environment do
  file_path = ENV["FILE"] || "/Users/acb/Code/Web-Rails/bookclub/test_text/11-0.txt"
  ENV["FILE"] = file_path
  ENV["SLUG"] ||= "alice-in-wonderland"
  ENV["PUBLISH"] ||= "true"

  Rake::Task["bookclub:import"].invoke
end
