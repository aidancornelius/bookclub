# frozen_string_literal: true

# name: bookclub
# about: A publishing platform built on Discourse for books, journals, and public scholarship
# meta_topic_id: TODO
# version: 0.1.0
# authors: Bookclub Contributors
# url: https://github.com/discourse/discourse/tree/main/plugins/bookclub

enabled_site_setting :bookclub_enabled

register_asset 'stylesheets/common/bookclub.scss'
register_asset 'stylesheets/common/reading-mode.scss'
register_asset 'stylesheets/desktop/reading-mode.scss', :desktop
register_asset 'stylesheets/mobile/reading-mode.scss', :mobile

register_svg_icon 'book-open'
register_svg_icon 'bookmark'
register_svg_icon 'list-ul'
register_svg_icon 'sun'
register_svg_icon 'moon'
register_svg_icon 'text-height'
register_svg_icon 'fire'
register_svg_icon 'circle-half-stroke'
register_svg_icon 'file-lines'
register_svg_icon 'file-zipper'
register_svg_icon 'folder'
register_svg_icon 'file-check'
register_svg_icon 'upload'

module ::Bookclub
  PLUGIN_NAME = 'bookclub'

  # Publication types (extensible for journals, anthologies, etc.)
  PUBLICATION_TYPES = %w[book journal anthology series].freeze

  # Container types (for journal issues, book parts, etc.)
  CONTAINER_TYPES = %w[issue volume part section].freeze

  # Content item types
  CONTENT_TYPES = %w[chapter article essay review].freeze

  # Feedback types for public scholarship
  FEEDBACK_TYPES = %w[comment suggestion review endorsement].freeze

  # Peer review statuses
  REVIEW_STATUSES = %w[draft under_review accepted published].freeze

  # Custom field names - Publications (categories)
  PUBLICATION_ENABLED = 'publication_enabled'
  PUBLICATION_TYPE = 'publication_type'
  PUBLICATION_SLUG = 'publication_slug'
  PUBLICATION_COVER_URL = 'publication_cover_url'
  PUBLICATION_DESCRIPTION = 'publication_description'
  PUBLICATION_AUTHOR_IDS = 'publication_author_ids'
  PUBLICATION_EDITOR_IDS = 'publication_editor_ids'
  PUBLICATION_ACCESS_TIERS = 'publication_access_tiers'
  PUBLICATION_FEEDBACK_SETTINGS = 'publication_feedback_settings'
  PUBLICATION_IDENTIFIER = 'publication_identifier' # ISBN/ISSN

  # Custom field names - Chapters (subcategories of publications)
  # Each chapter is a subcategory containing a pinned content topic + discussion topics
  CHAPTER_ENABLED = 'bookclub_chapter_enabled'
  CHAPTER_NUMBER = 'bookclub_chapter_number'
  CHAPTER_TYPE = 'bookclub_chapter_type' # chapter, article, essay, section
  CHAPTER_ACCESS_LEVEL = 'bookclub_chapter_access_level'
  CHAPTER_PUBLISHED = 'bookclub_chapter_published'
  CHAPTER_SUMMARY = 'bookclub_chapter_summary'
  CHAPTER_WORD_COUNT = 'bookclub_chapter_word_count'
  CHAPTER_CONTRIBUTORS = 'bookclub_chapter_contributors'
  CHAPTER_REVIEW_STATUS = 'bookclub_chapter_review_status'

  # Custom field names - Content topics (the pinned topic containing actual text)
  # The content topic is marked and pinned within a chapter subcategory
  CONTENT_TOPIC = 'bookclub_content_topic'
  CONTENT_TYPE = 'bookclub_content_type'
  CONTENT_NUMBER = 'bookclub_content_number'
  CONTENT_ACCESS_LEVEL = 'bookclub_content_access_level'
  CONTENT_PUBLISHED = 'bookclub_content_published'
  CONTENT_WORD_COUNT = 'bookclub_content_word_count'
  CONTENT_SUMMARY = 'bookclub_content_summary'
  CONTENT_CONTRIBUTORS = 'bookclub_content_contributors'
  CONTENT_REVIEW_STATUS = 'bookclub_content_review_status'

  # Custom field names - Containers (subcategories for issues/volumes in journals)
  CONTAINER_TYPE = 'bookclub_container_type'
  CONTAINER_NUMBER = 'bookclub_container_number'
  CONTAINER_TITLE = 'bookclub_container_title'
  CONTAINER_PUBLICATION_DATE = 'bookclub_container_publication_date'
  CONTAINER_GUEST_EDITOR_IDS = 'bookclub_container_guest_editor_ids'

  # Reading progress (user custom fields)
  READING_PROGRESS = 'bookclub_reading_progress'

  # Subscription metadata (user custom fields)
  SUBSCRIPTION_METADATA = 'bookclub_subscriptions'
end

require_relative 'lib/bookclub/engine'
require_relative 'lib/bookclub/subscription_hooks'
require_relative 'lib/bookclub/book_parser'
require_relative 'lib/bookclub/book_importer'

after_initialize do
  # -----------------------------------------------------------------
  # Category custom fields (Publications)
  # -----------------------------------------------------------------
  register_category_custom_field_type(Bookclub::PUBLICATION_ENABLED, :boolean)
  register_category_custom_field_type(Bookclub::PUBLICATION_TYPE, :string, max_length: 50)
  register_category_custom_field_type(Bookclub::PUBLICATION_SLUG, :string, max_length: 100)
  register_category_custom_field_type(Bookclub::PUBLICATION_COVER_URL, :string, max_length: 1000)
  register_category_custom_field_type(
    Bookclub::PUBLICATION_DESCRIPTION,
    :string,
    max_length: 10_000
  )
  register_category_custom_field_type(Bookclub::PUBLICATION_AUTHOR_IDS, :json)
  register_category_custom_field_type(Bookclub::PUBLICATION_EDITOR_IDS, :json)
  register_category_custom_field_type(Bookclub::PUBLICATION_ACCESS_TIERS, :json)
  register_category_custom_field_type(Bookclub::PUBLICATION_FEEDBACK_SETTINGS, :json)
  register_category_custom_field_type(Bookclub::PUBLICATION_IDENTIFIER, :string, max_length: 50)

  # Chapter fields (subcategories representing chapters/articles)
  register_category_custom_field_type(Bookclub::CHAPTER_ENABLED, :boolean)
  register_category_custom_field_type(Bookclub::CHAPTER_NUMBER, :integer)
  register_category_custom_field_type(Bookclub::CHAPTER_TYPE, :string, max_length: 50)
  register_category_custom_field_type(Bookclub::CHAPTER_ACCESS_LEVEL, :string, max_length: 100)
  register_category_custom_field_type(Bookclub::CHAPTER_PUBLISHED, :boolean)
  register_category_custom_field_type(Bookclub::CHAPTER_SUMMARY, :string, max_length: 2000)
  register_category_custom_field_type(Bookclub::CHAPTER_WORD_COUNT, :integer)
  register_category_custom_field_type(Bookclub::CHAPTER_CONTRIBUTORS, :json)
  register_category_custom_field_type(Bookclub::CHAPTER_REVIEW_STATUS, :string, max_length: 50)

  # Container fields (for subcategories representing issues/volumes in journals)
  register_category_custom_field_type(Bookclub::CONTAINER_TYPE, :string, max_length: 50)
  register_category_custom_field_type(Bookclub::CONTAINER_NUMBER, :integer)
  register_category_custom_field_type(Bookclub::CONTAINER_TITLE, :string, max_length: 500)
  register_category_custom_field_type(Bookclub::CONTAINER_PUBLICATION_DATE, :string, max_length: 50)
  register_category_custom_field_type(Bookclub::CONTAINER_GUEST_EDITOR_IDS, :json)

  # Preload category custom fields to avoid N+1 queries
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_ENABLED
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_TYPE
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_SLUG
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_COVER_URL
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_DESCRIPTION
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_AUTHOR_IDS
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_EDITOR_IDS
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_ACCESS_TIERS
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_FEEDBACK_SETTINGS
  Site.preloaded_category_custom_fields << Bookclub::PUBLICATION_IDENTIFIER

  # Preload chapter fields
  Site.preloaded_category_custom_fields << Bookclub::CHAPTER_ENABLED
  Site.preloaded_category_custom_fields << Bookclub::CHAPTER_NUMBER
  Site.preloaded_category_custom_fields << Bookclub::CHAPTER_TYPE
  Site.preloaded_category_custom_fields << Bookclub::CHAPTER_ACCESS_LEVEL
  Site.preloaded_category_custom_fields << Bookclub::CHAPTER_PUBLISHED
  Site.preloaded_category_custom_fields << Bookclub::CHAPTER_SUMMARY
  Site.preloaded_category_custom_fields << Bookclub::CHAPTER_WORD_COUNT

  # -----------------------------------------------------------------
  # Topic custom fields
  # -----------------------------------------------------------------
  # Mark a topic as the content topic (vs a discussion topic) within a chapter
  register_topic_custom_field_type(Bookclub::CONTENT_TOPIC, :boolean)
  register_topic_custom_field_type(Bookclub::CONTENT_TYPE, :string)
  register_topic_custom_field_type(Bookclub::CONTENT_NUMBER, :integer)
  register_topic_custom_field_type(Bookclub::CONTENT_ACCESS_LEVEL, :string)
  register_topic_custom_field_type(Bookclub::CONTENT_PUBLISHED, :boolean)
  register_topic_custom_field_type(Bookclub::CONTENT_WORD_COUNT, :integer)
  register_topic_custom_field_type(Bookclub::CONTENT_SUMMARY, :string)
  register_topic_custom_field_type(Bookclub::CONTENT_CONTRIBUTORS, :json)
  register_topic_custom_field_type(Bookclub::CONTENT_REVIEW_STATUS, :string)

  add_preloaded_topic_list_custom_field(Bookclub::CONTENT_TOPIC)
  add_preloaded_topic_list_custom_field(Bookclub::CONTENT_TYPE)
  add_preloaded_topic_list_custom_field(Bookclub::CONTENT_NUMBER)

  # -----------------------------------------------------------------
  # User custom fields (Reading progress and subscriptions)
  # -----------------------------------------------------------------
  register_user_custom_field_type(Bookclub::READING_PROGRESS, :json)
  register_user_custom_field_type(Bookclub::SUBSCRIPTION_METADATA, :json)

  # -----------------------------------------------------------------
  # Serializer extensions - expose publication data to frontend
  # -----------------------------------------------------------------

  # Helper to get custom field value, preferring preloaded but falling back to direct access
  # This ensures fields are available both when Site preloads them and when accessed individually
  add_to_class(:category, :bookclub_custom_field) do |field_name|
    if preloaded_custom_fields
      preloaded_custom_fields[field_name]
    else
      custom_fields[field_name]
    end
  end

  # Add publication fields to category serializer
  add_to_serializer(:basic_category, :publication_enabled) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_ENABLED)
  end

  add_to_serializer(:basic_category, :publication_type) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_TYPE)
  end

  add_to_serializer(:basic_category, :publication_slug) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_SLUG)
  end

  add_to_serializer(:basic_category, :publication_cover_url) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_COVER_URL)
  end

  add_to_serializer(:basic_category, :publication_description) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_DESCRIPTION)
  end

  add_to_serializer(:basic_category, :publication_author_ids) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_AUTHOR_IDS)
  end

  add_to_serializer(:basic_category, :publication_access_tiers) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_ACCESS_TIERS)
  end

  add_to_serializer(:basic_category, :publication_feedback_settings) do
    object.bookclub_custom_field(Bookclub::PUBLICATION_FEEDBACK_SETTINGS)
  end

  # Add chapter fields to category serializer (for chapter subcategories)
  add_to_serializer(:basic_category, :chapter_enabled) do
    object.bookclub_custom_field(Bookclub::CHAPTER_ENABLED)
  end

  add_to_serializer(:basic_category, :chapter_number) do
    object.bookclub_custom_field(Bookclub::CHAPTER_NUMBER)
  end

  add_to_serializer(:basic_category, :chapter_type) do
    object.bookclub_custom_field(Bookclub::CHAPTER_TYPE)
  end

  add_to_serializer(:basic_category, :chapter_access_level) do
    object.bookclub_custom_field(Bookclub::CHAPTER_ACCESS_LEVEL)
  end

  add_to_serializer(:basic_category, :chapter_published) do
    object.bookclub_custom_field(Bookclub::CHAPTER_PUBLISHED)
  end

  add_to_serializer(:basic_category, :chapter_summary) do
    object.bookclub_custom_field(Bookclub::CHAPTER_SUMMARY)
  end

  add_to_serializer(:basic_category, :chapter_word_count) do
    object.bookclub_custom_field(Bookclub::CHAPTER_WORD_COUNT)
  end

  # Add content topic marker to topic serializers
  add_to_serializer(:topic_view, :bookclub_content_topic) do
    object.topic.custom_fields[Bookclub::CONTENT_TOPIC]
  end

  add_to_serializer(:topic_list_item, :bookclub_content_topic) do
    object.custom_fields[Bookclub::CONTENT_TOPIC]
  end

  # -----------------------------------------------------------------
  # Event hooks
  # -----------------------------------------------------------------

  # Calculate word count when content topic's first post is saved
  # Word count is stored on both the topic and the chapter (subcategory)
  on(:post_created) do |post|
    next unless post.is_first_post?

    # Reload topic to ensure custom fields are fresh
    topic = Topic.find_by(id: post.topic_id)
    next unless topic

    chapter = topic.category

    # Check if this is the content topic within a chapter subcategory
    next unless topic.custom_fields[Bookclub::CONTENT_TOPIC]

    word_count = post.raw.split.size

    # Store on topic
    topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = word_count
    topic.save_custom_fields

    # Also store on chapter if it exists
    if chapter&.custom_fields&.[](Bookclub::CHAPTER_ENABLED)
      chapter.custom_fields[Bookclub::CHAPTER_WORD_COUNT] = word_count
      chapter.save_custom_fields
    end
  end

  on(:post_edited) do |post|
    next unless post.is_first_post?

    # Reload topic to ensure custom fields are fresh
    topic = Topic.find_by(id: post.topic_id)
    next unless topic

    chapter = topic.category

    next unless topic.custom_fields[Bookclub::CONTENT_TOPIC]

    word_count = post.raw.split.size

    # Store on topic
    topic.custom_fields[Bookclub::CONTENT_WORD_COUNT] = word_count
    topic.save_custom_fields

    # Also store on chapter if it exists
    if chapter&.custom_fields&.[](Bookclub::CHAPTER_ENABLED)
      chapter.custom_fields[Bookclub::CHAPTER_WORD_COUNT] = word_count
      chapter.save_custom_fields
    end
  end

  # -----------------------------------------------------------------
  # Routes
  # -----------------------------------------------------------------
  Discourse::Application.routes.append { mount Bookclub::Engine, at: '/bookclub' }

  # Public book routes (cleaner URLs)
  # Discussions are native Discourse topics within the chapter subcategory
  Discourse::Application.routes.prepend do
    get '/book/:slug' => 'bookclub/publications#show', :as => :bookclub_publication
    get '/book/:slug/:content_number' => 'bookclub/content#show', :as => :bookclub_content
  end

  # Admin routes
  Discourse::Application.routes.append do
    get '/admin/plugins/bookclub' => 'admin/plugins#index', :constraints => AdminConstraint.new
  end

  add_admin_route 'bookclub.admin.title', 'bookclub'

  # -----------------------------------------------------------------
  # Guardian extensions for access control
  # -----------------------------------------------------------------
  add_to_class(:guardian, :can_access_publication?) do |category|
    # Admins and authors/editors always have access
    return true if is_admin?
    return true if is_publication_author?(category) || is_publication_editor?(category)

    return true unless category.custom_fields[Bookclub::PUBLICATION_ENABLED]

    access_tiers = category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS]
    return true if access_tiers.blank?

    # "everyone" tier means all users (including anonymous) have access
    return true if access_tiers.key?('everyone')

    # Check if user is in any of the access tier groups
    # @user can be nil or AnonymousUser which doesn't have group_ids
    return false unless @user.is_a?(User)

    user_group_ids = @user.group_ids
    access_tiers.each_key do |group_name|
      group = Group.find_by(name: group_name)
      return true if group && user_group_ids.include?(group.id)
    end

    false
  end

  add_to_class(:guardian, :can_access_chapter?) do |chapter|
    # Admins always have access
    return true if is_admin?

    # Chapter is a subcategory - get the parent publication
    publication = chapter.parent_category
    return true unless publication&.custom_fields&.[](Bookclub::PUBLICATION_ENABLED)

    # Authors and editors always have access
    return true if is_publication_author?(publication) || is_publication_editor?(publication)

    # Check publication-level access first
    return false unless can_access_publication?(publication)

    # Check chapter-specific access level
    chapter_access_level = chapter.custom_fields[Bookclub::CHAPTER_ACCESS_LEVEL]
    return true if chapter_access_level.blank? || chapter_access_level == 'free'

    # For tiered content, verify the specific tier
    access_tiers = publication.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] || {}

    # "everyone" tier gives baseline access at that level
    everyone_tier = access_tiers['everyone']
    if everyone_tier
      tier_hierarchy = %w[community reader member supporter patron]
      everyone_tier_index = tier_hierarchy.index(everyone_tier) || 0
      required_tier_index = tier_hierarchy.index(chapter_access_level) || 0
      return true if everyone_tier_index >= required_tier_index
    end

    return false unless @user.is_a?(User)

    user_group_ids = @user.group_ids

    # Find the user's highest access tier
    user_tiers = []
    access_tiers.each do |group_name, level|
      next if group_name == 'everyone' # Already handled above

      group = Group.find_by(name: group_name)
      user_tiers << level if group && user_group_ids.include?(group.id)
    end

    return false if user_tiers.empty?

    # Define tier hierarchy
    tier_hierarchy = %w[community reader member supporter patron]
    user_max_tier = user_tiers.max_by { |t| tier_hierarchy.index(t) || 0 }
    required_tier_index = tier_hierarchy.index(chapter_access_level) || 0
    user_tier_index = tier_hierarchy.index(user_max_tier) || 0

    user_tier_index >= required_tier_index
  end

  add_to_class(:guardian, :is_publication_author?) do |category|
    return false unless @user.respond_to?(:id) && @user.id

    author_ids = category.custom_fields[Bookclub::PUBLICATION_AUTHOR_IDS]
    return false if author_ids.blank?

    author_ids.include?(@user.id)
  end

  add_to_class(:guardian, :is_publication_editor?) do |category|
    return false unless @user.respond_to?(:id) && @user.id

    editor_ids = category.custom_fields[Bookclub::PUBLICATION_EDITOR_IDS]
    return false if editor_ids.blank?

    editor_ids.include?(@user.id)
  end

  # -----------------------------------------------------------------
  # Stripe integration via discourse-subscriptions
  # -----------------------------------------------------------------
  if SiteSetting.bookclub_stripe_integration && defined?(DiscourseSubscriptions)
    DiscourseSubscriptions::HooksController.include(Bookclub::SubscriptionHooks)

    Rails.logger.info('[Bookclub] Stripe integration enabled via discourse-subscriptions')
  end

  # Custom field for mapping Stripe products to publications
  register_category_custom_field_type('bookclub_stripe_product_id', :string, max_length: 100)
  Site.preloaded_category_custom_fields << 'bookclub_stripe_product_id'

  # Add Stripe product ID to category serializer for admin use
  add_to_serializer(
    :basic_category,
    :bookclub_stripe_product_id,
    include_condition: -> { scope&.is_admin? }
  ) { object.preloaded_custom_fields['bookclub_stripe_product_id'] }

  # -----------------------------------------------------------------
  # Event handlers for subscription lifecycle
  # -----------------------------------------------------------------

  on(:user_added_to_group) do |user, group|
    next unless SiteSetting.bookclub_enabled
    next unless SiteSetting.bookclub_stripe_integration

    publications_with_tier =
      Category
      .where('custom_fields @> ?', { Bookclub::PUBLICATION_ENABLED => true }.to_json)
      .select do |category|
        access_tiers = category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] || {}
        access_tiers.key?(group.name)
      end

    if publications_with_tier.any?
      Rails.logger.info(
        "[Bookclub] User #{user.id} added to group #{group.name}, has access to #{publications_with_tier.count} publication(s)"
      )
    end
  end

  on(:user_removed_from_group) do |user, group|
    next unless SiteSetting.bookclub_enabled
    next unless SiteSetting.bookclub_stripe_integration

    publications_with_tier =
      Category
      .where('custom_fields @> ?', { Bookclub::PUBLICATION_ENABLED => true }.to_json)
      .select do |category|
        access_tiers = category.custom_fields[Bookclub::PUBLICATION_ACCESS_TIERS] || {}
        access_tiers.key?(group.name)
      end

    if publications_with_tier.any?
      Rails.logger.info(
        "[Bookclub] User #{user.id} removed from group #{group.name}, lost access to #{publications_with_tier.count} publication(s)"
      )
    end
  end
end
