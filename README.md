# Bookclub

A publishing platform built on Discourse for books, journals, and public scholarship.

Bookclub transforms Discourse into a reading-first platform where publications are the primary content, with community discussion integrated naturally around chapters and articles.

## Features

### Reading experience
- **Clean reading mode** with typography optimised for long-form content
- **Chapter navigation** with keyboard shortcuts (n/p for next/previous, t for table of contents)
- **Reading progress tracking** with scroll position memory and completion status
- **Reading streaks** to encourage consistent engagement
- **Dark mode support** with configurable font sizes
- **Mobile-optimised** with bottom navigation and swipe gestures

### Publications
- **Book and journal support** with chapters/articles as subcategories
- **Table of contents** with progress indicators
- **Access tiers** (free, member, supporter, patron) via group membership
- **Author and editor roles** with dedicated dashboards
- **Word count tracking** and reading time estimates

### Monetisation
- **Stripe integration** via discourse-subscriptions plugin
- **Tiered access control** mapping subscription levels to content
- **Paywall prompts** for restricted content
- **Subscription lifecycle handling** (renewals, cancellations, refunds)

### Author tools
- **Publication dashboard** with chapter management
- **Drag-and-drop chapter reordering**
- **Activity metrics** showing recent comments and unanswered questions
- **Reader progress summaries** with completion rates
- **One-click chapter creation** with auto-numbering

### Community integration
- **Inline discussions** below chapter content
- **Native Discourse topics** for chapter discussions
- **Sidebar integration** with Library section
- **Homepage publications grid**

## Installation

### Requirements
- Discourse 3.2+
- Ruby 3.2+
- PostgreSQL 15+

### Plugin installation

Add the plugin to your Discourse installation:

```bash
cd /var/discourse
./launcher enter app
cd /var/www/discourse/plugins
git clone https://github.com/your-org/bookclub.git
cd /var/www/discourse
RAILS_ENV=production bundle exec rake assets:precompile
```

Or add to your `app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/your-org/bookclub.git
```

### Theme installation

The theme component is included in the `theme/` directory. Install it via the Discourse admin panel:

1. Go to Admin → Customize → Themes
2. Click "Install" → "From a git repository"
3. Enter the repository URL with `/theme` suffix

Or create a symlink for development:

```bash
ln -s /path/to/bookclub/theme /var/www/discourse/themes/bookclub
```

## Configuration

### Site settings

Enable the plugin in Admin → Settings → Plugins:

- `bookclub_enabled` - Enable the Bookclub plugin
- `bookclub_stripe_integration` - Enable Stripe payment integration (requires discourse-subscriptions)
- `bookclub_manual_access_mode` - Show contact form instead of payment buttons

### Creating a publication

1. Create a category to serve as the publication container
2. Set custom fields via the Rails console or admin UI:
   ```ruby
   category = Category.find_by(slug: "my-book")
   category.custom_fields["publication_enabled"] = true
   category.custom_fields["publication_type"] = "book"  # or "journal"
   category.custom_fields["publication_slug"] = "my-book"
   category.custom_fields["publication_author_ids"] = [user.id]
   category.save_custom_fields
   ```

3. Create subcategories for chapters, setting:
   ```ruby
   chapter.custom_fields["bookclub_chapter_enabled"] = true
   chapter.custom_fields["bookclub_chapter_number"] = 1
   chapter.custom_fields["bookclub_chapter_type"] = "chapter"
   chapter.save_custom_fields
   ```

4. Create a pinned topic in each chapter subcategory for the chapter content, marking it:
   ```ruby
   topic.custom_fields["bookclub_content_topic"] = true
   topic.save_custom_fields
   ```

### Access tiers

Configure access tiers by setting the `publication_access_tiers` custom field as JSON:

```ruby
category.custom_fields["publication_access_tiers"] = {
  "everyone" => "community",      # Free tier for all users
  "members-group" => "member",    # Member tier
  "supporters-group" => "supporter"  # Supporter tier
}
```

Chapter access levels (`bookclub_chapter_access_level`) can be: `free`, `community`, `member`, `supporter`, or `patron`.

## Development

### Local setup

```bash
# Clone into Discourse plugins directory
cd /path/to/discourse/plugins
git clone https://github.com/your-org/bookclub.git

# Symlink theme
ln -s ../bookclub/theme ../themes/bookclub

# Run Discourse
bin/rails server
```

### Running tests

```bash
# Ruby specs
LOAD_PLUGINS=1 bin/rspec plugins/bookclub/spec/

# JavaScript tests (requires Chrome)
bin/qunit plugins/bookclub
```

### Linting

```bash
bin/rubocop plugins/bookclub
npx eslint plugins/bookclub/assets/javascripts
```

## Architecture

### Data model

- **Publications** are Discourse categories with `publication_enabled = true`
- **Chapters** are subcategories of publications with `bookclub_chapter_enabled = true`
- **Content** is a pinned topic within a chapter marked with `bookclub_content_topic = true`
- **Discussions** are regular topics within the chapter subcategory

### Routes

| Route | Description |
|-------|-------------|
| `/book/:slug` | Publication landing page |
| `/book/:slug/:number` | Chapter content view |
| `/bookclub/publications` | Publications API |
| `/bookclub/author` | Author dashboard |
| `/bookclub/reading-progress` | Reading progress API |

### Services

- `Bookclub::SubscriptionIntegration` - Handles subscription lifecycle events
- `bookclub-reading` (JS) - Manages reading mode state and progress
- `bookclub-author` (JS) - Author dashboard data fetching

## Stripe integration

Bookclub integrates with the official `discourse-subscriptions` plugin for payment processing. It does not duplicate Stripe functionality but extends it with publication-specific logic.

### Setup

1. Install and configure discourse-subscriptions
2. Enable `bookclub_stripe_integration` in site settings
3. Create Stripe products with metadata:
   - `bookclub_publication_id` - The category ID of the publication
   - `group_name` - The Discourse group to add users to on subscription

### Webhook events handled

- `checkout.session.completed` - Grant access
- `customer.subscription.updated` - Handle plan changes
- `customer.subscription.deleted` - Revoke access
- `invoice.payment_failed` - Notify user
- `charge.refunded` - Revoke access

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Ensure linting passes
5. Submit a pull request

## Licence

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE](LICENSE) file for details.

This is the same licence as Discourse itself, ensuring compatibility and the freedom to use, modify, and distribute this software.

## Acknowledgements

- Built on [Discourse](https://discourse.org), the civilised discussion platform
- Payment integration via [discourse-subscriptions](https://github.com/discourse/discourse-subscriptions)
