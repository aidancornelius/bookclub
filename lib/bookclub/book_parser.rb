# frozen_string_literal: true

module Bookclub
  # Parses book content from various formats (TextBundle, Markdown, plain text)
  # into a standardised structure for import
  class BookParser
    class ParseError < StandardError
    end

    # Result structure returned by parse methods
    ParsedBook =
      Struct.new(
        :title,
        :author,
        :description,
        :type,
        :chapters,
        :cover_image,
        :assets,
        keyword_init: true,
      )
    ParsedChapter = Struct.new(:number, :title, :content, :word_count, keyword_init: true)

    class << self
      # Main entry point - detects format and parses accordingly
      # @param file_path [String] Path to file or directory
      # @param content [String] Raw content (alternative to file_path)
      # @param filename [String] Original filename (for format detection when using content)
      # @return [ParsedBook]
      def parse(file_path: nil, content: nil, filename: nil)
        if file_path
          parse_file(file_path)
        elsif content && filename
          parse_content(content, filename)
        else
          raise ParseError, "Must provide either file_path or content with filename"
        end
      end

      # Parse from file path - auto-detects format
      def parse_file(path)
        raise ParseError, "File not found: #{path}" unless File.exist?(path)

        if File.directory?(path)
          if path.end_with?(".textbundle")
            parse_textbundle_dir(path)
          else
            parse_folder(path)
          end
        elsif path.end_with?(".textpack", ".zip")
          parse_compressed(path)
        elsif path.end_with?(".md", ".markdown")
          parse_markdown_file(path)
        elsif path.end_with?(".txt")
          parse_plaintext_file(path)
        else
          raise ParseError, "Unsupported file format: #{File.extname(path)}"
        end
      end

      # Parse from raw content string
      def parse_content(content, filename)
        ext = File.extname(filename).downcase
        case ext
        when ".md", ".markdown"
          parse_markdown(content)
        when ".txt"
          parse_plaintext(content)
        else
          # Try markdown first, fall back to plaintext
          begin
            parse_markdown(content)
          rescue ParseError
            parse_plaintext(content)
          end
        end
      end

      private

      # =======================================================================
      # TextBundle parsing
      # =======================================================================

      def parse_textbundle_dir(path)
        info_path = File.join(path, "info.json")
        raise ParseError, "Invalid TextBundle: missing info.json" unless File.exist?(info_path)

        info = JSON.parse(File.read(info_path))

        # Find the text file (text.md, text.txt, text.markdown, etc.)
        text_file = Dir.glob(File.join(path, "text.*")).first
        raise ParseError, "Invalid TextBundle: missing text file" unless text_file

        content = File.read(text_file)

        # Parse the content as markdown
        book = parse_markdown(content)

        # Override with info.json metadata if present
        if info["net.daringfireball.markdown"]
          # Some apps store metadata in type-specific keys
        end

        # Load assets
        assets_dir = File.join(path, "assets")
        if File.directory?(assets_dir)
          book.assets = load_assets(assets_dir)

          # Look for cover image
          cover = Dir.glob(File.join(assets_dir, "cover.*")).first
          book.cover_image = File.read(cover) if cover
        end

        book
      end

      def parse_compressed(path)
        require "zip"

        Dir.mktmpdir do |tmpdir|
          Zip::File.open(path) do |zip_file|
            zip_file.each do |entry|
              dest_path = File.join(tmpdir, entry.name)
              FileUtils.mkdir_p(File.dirname(dest_path))
              entry.extract(dest_path)
            end
          end

          # Find the textbundle or root
          textbundle = Dir.glob(File.join(tmpdir, "*.textbundle")).first
          if textbundle
            parse_textbundle_dir(textbundle)
          else
            parse_folder(tmpdir)
          end
        end
      end

      # =======================================================================
      # Folder parsing (multiple .md files)
      # =======================================================================

      def parse_folder(path)
        # Look for index file
        index_file =
          %w[book.md index.md README.md].map { |f| File.join(path, f) }.find { |f| File.exist?(f) }

        if index_file
          parse_folder_with_index(path, index_file)
        else
          parse_folder_by_files(path)
        end
      end

      def parse_folder_with_index(path, index_file)
        content = File.read(index_file)
        metadata = extract_yaml_frontmatter(content)

        # Check for content block includes (/filename.md syntax)
        chapters = []
        chapter_num = 0

        content.each_line do |line|
          # iA Writer content block syntax: /filename.md or /path/to/file.md
          if line.strip =~ %r{^/(.+\.(?:md|markdown|txt))(?:\s+["'(](.+)["')])?$}
            include_path = File.join(path, $1)
            title_override = $2

            if File.exist?(include_path)
              chapter_num += 1
              chapter_content = File.read(include_path)
              chapter_metadata = extract_yaml_frontmatter(chapter_content)
              chapter_body = strip_yaml_frontmatter(chapter_content)

              title =
                title_override || chapter_metadata[:title] || extract_first_heading(chapter_body) ||
                  "Chapter #{chapter_num}"

              chapters << ParsedChapter.new(
                number: chapter_num,
                title: title,
                content: chapter_body.strip,
                word_count: chapter_body.split.size,
              )
            end
          end
        end

        # If no content blocks found, fall back to parsing the index itself
        return parse_markdown(content) if chapters.empty?

        ParsedBook.new(
          title: metadata[:title] || File.basename(path),
          author: metadata[:author],
          description: metadata[:description],
          type: metadata[:type] || "book",
          chapters: chapters,
          assets: load_assets(File.join(path, "assets")) || load_assets(File.join(path, "images")),
        )
      end

      def parse_folder_by_files(path)
        # Find all markdown files, sorted by name
        md_files = Dir.glob(File.join(path, "*.{md,markdown}")).sort

        raise ParseError, "No markdown files found in folder" if md_files.empty?

        chapters = []
        metadata = {}

        md_files.each_with_index do |file, index|
          content = File.read(file)
          file_metadata = extract_yaml_frontmatter(content)
          body = strip_yaml_frontmatter(content)

          # First file might be metadata-only
          if index == 0 && file_metadata[:title] && body.strip.empty?
            metadata = file_metadata
            next
          end

          # Merge any book-level metadata from first file
          metadata = file_metadata.slice(:title, :author, :description, :type) if index == 0

          chapter_num = chapters.size + 1
          title =
            file_metadata[:title] || extract_first_heading(body) ||
              File.basename(file, ".*").gsub(/^\d+[-_]?/, "").tr("-_", " ").strip.capitalize

          chapters << ParsedChapter.new(
            number: chapter_num,
            title: title,
            content: strip_first_heading(body).strip,
            word_count: body.split.size,
          )
        end

        ParsedBook.new(
          title: metadata[:title] || File.basename(path),
          author: metadata[:author],
          description: metadata[:description],
          type: metadata[:type] || "book",
          chapters: chapters,
          assets: load_assets(File.join(path, "assets")) || load_assets(File.join(path, "images")),
        )
      end

      # =======================================================================
      # Markdown parsing
      # =======================================================================

      def parse_markdown_file(path)
        parse_markdown(File.read(path))
      end

      def parse_markdown(content)
        metadata = extract_yaml_frontmatter(content)
        body = strip_yaml_frontmatter(content)

        chapters = split_into_chapters_markdown(body)

        if chapters.empty?
          raise ParseError, "No chapters found. Use '# Chapter Title' headers to separate chapters."
        end

        ParsedBook.new(
          title: metadata[:title],
          author: metadata[:author],
          description: metadata[:description],
          type: metadata[:type] || "book",
          chapters: chapters,
          assets: nil,
        )
      end

      def split_into_chapters_markdown(content)
        chapters = []

        # Split by H1 headers (# Title)
        # Regex matches # at start of line, captures title, and content until next # or end
        parts = content.split(/^#\s+(?=[^\n])/)

        # First part might be preamble (before first chapter)
        preamble = parts.shift&.strip

        parts.each_with_index do |part, index|
          next if part.strip.empty?

          lines = part.split("\n", 2)
          title_line = lines[0]&.strip || ""
          body = lines[1]&.strip || ""

          # Parse title - might be "Chapter 1: Title" or just "Title"
          title =
            if title_line =~ /^chapter\s+(\d+)[:\.\s]*(.*)$/i
              $2.present? ? $2.strip : "Chapter #{$1}"
            else
              title_line
            end

          chapters << ParsedChapter.new(
            number: index + 1,
            title: title,
            content: body,
            word_count: body.split.size,
          )
        end

        chapters
      end

      # =======================================================================
      # Plain text parsing
      # =======================================================================

      def parse_plaintext_file(path)
        parse_plaintext(File.read(path))
      end

      def parse_plaintext(content)
        metadata = extract_plaintext_metadata(content)
        body = strip_plaintext_metadata(content)

        chapters = split_into_chapters_plaintext(body)

        if chapters.empty?
          raise ParseError,
                "No chapters found. Use 'CHAPTER 1' or 'CHAPTER I' markers to separate chapters."
        end

        ParsedBook.new(
          title: metadata[:title],
          author: metadata[:author],
          description: metadata[:description],
          type: metadata[:type] || "book",
          chapters: chapters,
          assets: nil,
        )
      end

      def extract_plaintext_metadata(content)
        metadata = {}

        # Look for metadata at the start: TITLE:, AUTHOR:, etc.
        content.each_line do |line|
          case line
          when /^TITLE:\s*(.+)$/i
            metadata[:title] = $1.strip
          when /^AUTHOR:\s*(.+)$/i
            metadata[:author] = $1.strip
          when /^DESCRIPTION:\s*(.+)$/i
            metadata[:description] = $1.strip
          when /^TYPE:\s*(.+)$/i
            metadata[:type] = $1.strip.downcase
          when /^(CHAPTER|#|\*{3,})/i, /^\s*$/
            # Stop at first chapter marker, header, or blank line after content
            break if metadata.any?
          end
        end

        metadata
      end

      def strip_plaintext_metadata(content)
        lines = content.lines

        # Skip metadata lines at the start
        start_index = 0
        lines.each_with_index do |line, index|
          if line =~ /^(TITLE|AUTHOR|DESCRIPTION|TYPE):/i
            start_index = index + 1
          elsif line.strip.empty?
            next
          else
            break
          end
        end

        lines[start_index..].join
      end

      def split_into_chapters_plaintext(content)
        chapters = []

        # Split by CHAPTER markers (CHAPTER 1, CHAPTER I, CHAPTER I., etc.)
        parts = content.split(/^CHAPTER\s+([IVXLCDM\d]+)\.?\s*\n/i)

        # First part is preamble, then alternating: chapter_num, content, chapter_num, content...
        parts.shift # discard preamble

        parts
          .each_slice(2)
          .with_index do |(chapter_id, chapter_content), index|
            next unless chapter_content

            lines = chapter_content.strip.split("\n", 2)
            title_line = lines[0]&.strip || ""
            body = lines[1]&.strip || chapter_content.strip

            # First line after CHAPTER X might be the title
            title =
              if title_line.present? && title_line.length < 100 && !title_line.include?(".")
                body = lines[1]&.strip || ""
                title_line
              else
                body = chapter_content.strip
                "Chapter #{index + 1}"
              end

            chapters << ParsedChapter.new(
              number: index + 1,
              title: title,
              content: body,
              word_count: body.split.size,
            )
          end

        chapters
      end

      # =======================================================================
      # Helper methods
      # =======================================================================

      def extract_yaml_frontmatter(content)
        return {} unless content.start_with?("---")

        if content =~ /\A---\s*\n(.+?)\n---\s*\n/m
          begin
            yaml = YAML.safe_load($1, permitted_classes: [Symbol, Date, Time])
            return {} unless yaml.is_a?(Hash)
            yaml.symbolize_keys
          rescue Psych::SyntaxError
            {}
          end
        else
          {}
        end
      end

      def strip_yaml_frontmatter(content)
        content.sub(/\A---\s*\n.+?\n---\s*\n/m, "")
      end

      def extract_first_heading(content)
        $1.strip if content =~ /^#\s+(.+)$/
      end

      def strip_first_heading(content)
        content.sub(/^#\s+.+\n*/, "")
      end

      def load_assets(dir)
        return nil unless dir && File.directory?(dir)

        assets = {}
        Dir
          .glob(File.join(dir, "*"))
          .each do |file|
            next if File.directory?(file)
            assets[File.basename(file)] = File.read(file)
          end
        assets.presence
      end
    end
  end
end
