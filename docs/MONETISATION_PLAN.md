# Bookclub monetisation system: comprehensive plan

## Executive summary

This document outlines a plan to implement a clean "buy once / subscribe" monetisation model for the Bookclub plugin. The system will support:

1. **Publication-level pricing** with chapter inheritance
2. **Preview chapters** (first N chapters free, then paywall)
3. **Dual purchase options**: one-time unlock vs subscription
4. **Site-wide subscriptions** for access to all content
5. **Admin UI** for pricing configuration

The design prioritises Discourse compatibility and upgrade safety by using custom fields, extending existing patterns, and building on the proven `discourse-subscriptions` infrastructure.

---

## Current architecture analysis

### What exists and works well

| Component | Status | Location |
|-----------|--------|----------|
| Stripe integration | Complete | `pricing_controller.rb`, `subscription_integration.rb` |
| Group-based access | Complete | Guardian extensions in `plugin.rb` |
| Webhook handling | Complete | `subscription_hooks.rb` |
| Pricing tier display | Complete | `bookclub-access-status.gjs` |
| Checkout flow | Complete | `pricing_controller.rb` |

### What's missing

| Feature | Priority | Complexity |
|---------|----------|------------|
| Admin pricing UI | High | Medium |
| Preview chapter system | High | Low |
| Buy once/subscribe choice UI | High | Medium |
| Site-wide subscription | Medium | Medium |
| Chapter-specific purchases | Low | High |
| Bundle pricing | Low | Medium |

---

## Proposed data model

### Publication custom fields (enhanced)

```ruby
# Existing
bookclub_stripe_product_id: "prod_xxx"
publication_access_tiers: { "reader" => "reader", "patron" => "patron" }

# New fields
bookclub_pricing_config: {
  enabled: true,
  preview_chapters: 3,                    # First N chapters free
  one_time_price_id: "price_xxx",         # Stripe price for one-time purchase
  one_time_amount: 2599,                  # Amount in cents (for display)
  subscription_price_id: "price_yyy",     # Stripe price for subscription
  subscription_amount: 495,               # Amount in cents (for display)
  subscription_interval: "month",         # month/year
  access_group: "publication_slug_readers", # Group to add users to
  inherit_site_subscription: true         # If true, site subscribers get access
}
```

### Chapter custom fields (enhanced)

```ruby
# Existing
chapter_access_level: "free" | "reader" | "patron" | etc.

# New fields
chapter_access_override: "public" | "paid" | "inherit"
# - public: Always free, doesn't count as preview
# - paid: Always requires purchase, regardless of preview count
# - inherit: Uses publication's preview system (default)
```

### Site settings (new)

```yaml
bookclub_site_subscription_enabled:
  default: false
  description: "Enable site-wide subscription for access to all publications"

bookclub_site_subscription_product_id:
  default: ""
  description: "Stripe product ID for site-wide subscription"

bookclub_site_subscription_group:
  default: "bookclub_subscribers"
  description: "Group name for site-wide subscribers"

bookclub_default_preview_chapters:
  default: 2
  description: "Default number of free preview chapters for new publications"
```

### User custom fields (enhanced)

```ruby
bookclub_subscriptions: {
  site: {
    subscription_id: "sub_xxx",
    status: "active",
    type: "subscription",
    granted_at: "2025-11-27T12:00:00Z"
  },
  "publication-slug": {
    subscription_id: "sub_yyy",
    status: "active",
    type: "one_time" | "subscription",
    granted_at: "2025-11-27T12:00:00Z"
  }
}
```

---

## Access control logic (enhanced)

### Guardian method: `can_access_chapter?`

```ruby
def can_access_chapter?(chapter, publication)
  # Always allow admins, authors, editors
  return true if is_admin?
  return true if is_publication_author?(publication) || is_publication_editor?(publication)

  pricing_config = publication.custom_fields['bookclub_pricing_config']

  # If pricing not enabled, use legacy tier-based access
  return legacy_tier_access?(chapter, publication) unless pricing_config&.dig('enabled')

  chapter_override = chapter.custom_fields['chapter_access_override'] || 'inherit'

  # Public chapters always accessible
  return true if chapter_override == 'public'

  # Check if user has any form of access
  return true if has_publication_access?(publication)
  return true if has_site_subscription?

  # For 'inherit' chapters, check preview count
  if chapter_override == 'inherit'
    preview_count = pricing_config['preview_chapters'] || 0
    chapter_position = get_chapter_position(chapter, publication)
    return true if chapter_position <= preview_count
  end

  false
end

def has_publication_access?(publication)
  return false unless @user.is_a?(User)

  pricing_config = publication.custom_fields['bookclub_pricing_config']
  access_group = pricing_config&.dig('access_group')
  return false unless access_group

  group = Group.find_by(name: access_group)
  group && @user.group_ids.include?(group.id)
end

def has_site_subscription?
  return false unless @user.is_a?(User)
  return false unless SiteSetting.bookclub_site_subscription_enabled

  group = Group.find_by(name: SiteSetting.bookclub_site_subscription_group)
  group && @user.group_ids.include?(group.id)
end
```

### Chapter position calculation

```ruby
def get_chapter_position(chapter, publication)
  chapters = publication.topics
    .joins("LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id AND tcf.name = 'bookclub_chapter_order'")
    .where("topic_custom_fields.name = 'bookclub_is_chapter' AND topic_custom_fields.value = 'true'")
    .order("COALESCE(tcf.value::int, topics.created_at::date) ASC")

  chapters.find_index { |c| c.id == chapter.id }.to_i + 1
end
```

---

## User experience flow

### Reader journey

```
1. User discovers publication
   └── Sees publication landing page with description

2. User starts reading
   └── Chapters 1-3 are free (preview)
   └── Progress tracked automatically

3. User reaches chapter 4 (first paid chapter)
   └── Sees paywall modal:

   ┌─────────────────────────────────────────────────┐
   │  Continue reading "The Great Novel"             │
   │                                                 │
   │  You've read 3 free chapters. Unlock the rest: │
   │                                                 │
   │  ┌─────────────────┐  ┌──────────────────────┐ │
   │  │  Unlock once    │  │  Subscribe           │ │
   │  │  $25.99         │  │  $4.95/month         │ │
   │  │                 │  │                      │ │
   │  │  • Full access  │  │  • This publication  │ │
   │  │    forever      │  │  • All publications  │ │
   │  │  • Download     │  │  • Cancel anytime    │ │
   │  │    available    │  │                      │ │
   │  └─────────────────┘  └──────────────────────┘ │
   │                                                 │
   │  [Already a subscriber? Log in]                │
   └─────────────────────────────────────────────────┘

4. User completes purchase
   └── Redirected to chapter 4
   └── All remaining chapters unlocked
```

### Author/admin journey

```
1. Create publication
   └── Standard publication creation flow

2. Configure pricing (new admin UI)
   └── Navigate to Publication Settings > Monetisation

   ┌─────────────────────────────────────────────────┐
   │  Monetisation settings                          │
   │                                                 │
   │  ☑ Enable paid access                          │
   │                                                 │
   │  Preview chapters: [3] ▼                       │
   │  (First N chapters free for all readers)       │
   │                                                 │
   │  One-time purchase                              │
   │  Stripe price: [price_xxx] (linked)            │
   │  Display price: $25.99                         │
   │                                                 │
   │  Subscription                                   │
   │  Stripe price: [price_yyy] (linked)            │
   │  Display price: $4.95/month                    │
   │                                                 │
   │  ☑ Include in site-wide subscription           │
   │                                                 │
   │  Access group: publication_slug_readers        │
   │  (Auto-created, users added on purchase)       │
   │                                                 │
   │  [Save changes]                                │
   └─────────────────────────────────────────────────┘

3. Configure individual chapters (optional)
   └── Per-chapter override in chapter settings

   ┌─────────────────────────────────────────────────┐
   │  Chapter access                                 │
   │                                                 │
   │  ○ Inherit from publication                    │
   │    (Uses preview count)                        │
   │                                                 │
   │  ○ Always public                               │
   │    (Free for everyone)                         │
   │                                                 │
   │  ○ Always paid                                 │
   │    (Requires purchase, even within preview)    │
   └─────────────────────────────────────────────────┘
```

---

## Implementation phases

### Phase 1: Foundation (week 1-2)

**Goal**: Establish data model and basic admin configuration

**Tasks**:
1. Add new custom field definitions to `plugin.rb`
2. Create `Bookclub::PricingConfig` service for validation and defaults
3. Add admin API endpoints for pricing configuration
4. Create basic admin UI component for pricing settings
5. Extend serializers to include pricing data

**Files to modify/create**:
- `plugin.rb` - Custom field registration
- `app/services/bookclub/pricing_config.rb` - New service
- `app/controllers/bookclub/admin_controller.rb` - New endpoints
- `assets/javascripts/discourse/components/admin/publication-pricing-settings.gjs` - New component

**Database migrations**: None (using custom fields)

### Phase 2: Access control enhancement (week 2-3)

**Goal**: Implement preview chapter system and enhanced access logic

**Tasks**:
1. Enhance Guardian `can_access_chapter?` method
2. Add chapter position calculation
3. Create `chapter_access_override` handling
4. Add site-wide subscription checks
5. Update content controller to return paywall data

**Files to modify**:
- `plugin.rb` - Guardian extensions
- `app/controllers/bookclub/content_controller.rb` - Paywall response

**Tests**:
- Preview chapter access for anonymous users
- Preview chapter access for logged-in users
- Paid chapter blocking
- One-time purchase access
- Subscription access
- Site-wide subscription access

### Phase 3: Paywall UI (week 3-4)

**Goal**: Create compelling purchase prompts

**Tasks**:
1. Design paywall modal component
2. Create pricing option cards
3. Add authentication prompts for anonymous users
4. Implement smooth checkout redirect
5. Add post-purchase redirect to content

**Files to create**:
- `assets/javascripts/discourse/components/bookclub-paywall-modal.gjs`
- `assets/javascripts/discourse/components/bookclub-pricing-option.gjs`
- `assets/stylesheets/bookclub-paywall.scss`

### Phase 4: Webhook enhancements (week 4)

**Goal**: Handle both purchase types correctly

**Tasks**:
1. Distinguish one-time vs subscription in webhook handling
2. Store purchase type in user metadata
3. Handle subscription cancellation (don't revoke one-time purchases)
4. Add purchase confirmation notifications

**Files to modify**:
- `lib/bookclub/subscription_hooks.rb`
- `app/services/bookclub/subscription_integration.rb`

### Phase 5: Site-wide subscription (week 5)

**Goal**: Enable all-access subscription option

**Tasks**:
1. Add site settings for site-wide subscription
2. Create site subscription management UI
3. Handle site subscription in access checks
4. Add site subscription to pricing display

**Files to modify**:
- `config/settings.yml`
- `plugin.rb` - Guardian extensions
- `app/controllers/bookclub/pricing_controller.rb`

### Phase 6: Polish and testing (week 6)

**Goal**: Production readiness

**Tasks**:
1. Comprehensive test coverage
2. Error handling and edge cases
3. Localisation strings
4. Documentation
5. Performance optimisation

---

## Stripe configuration guide

### Product structure

```
Site-wide subscription (if enabled)
├── Product: "Bookclub All Access"
│   ├── Price: $9.95/month (subscription)
│   └── Price: $99/year (subscription)
│   └── Metadata: { group_name: "bookclub_subscribers", type: "site" }

Per-publication
├── Product: "The Great Novel"
│   ├── Price: $25.99 (one-time)
│   │   └── Metadata: { group_name: "the_great_novel_readers", type: "one_time" }
│   └── Price: $4.95/month (subscription)
│       └── Metadata: { group_name: "the_great_novel_readers", type: "subscription" }
```

### Webhook events to handle

| Event | Action |
|-------|--------|
| `checkout.session.completed` | Add user to group, store purchase type |
| `customer.subscription.created` | Add user to group |
| `customer.subscription.updated` | Update status, maintain access |
| `customer.subscription.deleted` | Remove from group (subscriptions only, not one-time) |
| `charge.refunded` | Remove from group (both types) |

---

## Migration path from current system

### For existing publications

1. Publications with existing `publication_access_tiers` continue to work
2. Authors can optionally migrate to new pricing system
3. No forced migration; both systems coexist

### For existing subscribers

1. Users in existing access groups retain access
2. New purchases use new group naming convention
3. Admin can bulk-migrate users between groups

### Backwards compatibility

```ruby
# In Guardian, check both old and new systems
def can_access_chapter?(chapter, publication)
  # Try new pricing system first
  if publication.custom_fields['bookclub_pricing_config']&.dig('enabled')
    return new_pricing_access?(chapter, publication)
  end

  # Fall back to legacy tier system
  legacy_tier_access?(chapter, publication)
end
```

---

## Technical considerations

### Discourse upgrade safety

1. **Custom fields only**: No database migrations that could conflict
2. **Plugin isolation**: All code in plugin namespace
3. **Extend, don't override**: Use `add_to_class` for Guardian extensions
4. **Webhook composition**: Use `include` pattern for hooks
5. **Settings-based features**: All major features behind site settings

### Performance

1. **Preload pricing config**: Include in publication serializer
2. **Cache chapter positions**: Avoid recalculating on each request
3. **Batch group checks**: Single query for all user groups
4. **Stripe caching**: Cache pricing data with TTL

### Security

1. **Price ID validation**: Verify price belongs to publication's product
2. **Webhook verification**: Always validate Stripe signatures
3. **Group name sanitisation**: Prevent injection via group names
4. **Access check consistency**: Guardian as single source of truth

---

## Alternative approaches considered

### Option A: Per-chapter purchases (rejected)

**Concept**: Allow buying individual chapters separately

**Why rejected**:
- Complexity explosion (N products per publication)
- Poor UX (multiple purchase decisions)
- Revenue fragmentation
- Stripe product limit concerns

**Better alternative**: "Unlock all" model with preview chapters

### Option B: Credit-based system (deferred)

**Concept**: Users buy credits, spend on chapters

**Why deferred**:
- Significant additional infrastructure
- Different mental model for users
- Could be added later as enhancement

### Option C: External payment provider (rejected)

**Concept**: Use a different payment provider than Stripe

**Why rejected**:
- `discourse-subscriptions` is Stripe-only
- Would require complete rewrite
- Stripe is well-suited for this use case

---

## Success metrics

### Technical metrics

- Checkout completion rate > 80%
- Webhook processing success rate > 99.9%
- Page load time < 500ms (with pricing data)
- Zero access control failures

### Business metrics

- Preview-to-purchase conversion rate
- Subscription vs one-time purchase ratio
- Site-wide vs per-publication subscription ratio
- Monthly recurring revenue
- Churn rate

---

## Open questions

1. **Should site-wide subscription include one-time purchase benefits?**
   - E.g., download access that one-time purchasers get

2. **How to handle publication price changes?**
   - Grandfather existing subscribers?
   - Stripe handles this, but UX considerations

3. **Should authors see revenue analytics?**
   - Privacy considerations
   - Revenue sharing implications

4. **Bundle pricing for multiple publications?**
   - Defer to future phase?
   - How would this interact with site-wide subscription?

---

## Appendix: File structure

```
bookclub/
├── app/
│   ├── controllers/bookclub/
│   │   ├── admin_controller.rb          # Enhanced for pricing
│   │   ├── pricing_controller.rb        # Existing, minor changes
│   │   └── content_controller.rb        # Paywall response data
│   └── services/bookclub/
│       ├── pricing_config.rb            # New: config validation
│       └── subscription_integration.rb  # Enhanced for purchase types
├── assets/javascripts/discourse/
│   ├── components/
│   │   ├── admin/
│   │   │   └── publication-pricing-settings.gjs  # New
│   │   ├── bookclub-paywall-modal.gjs            # New
│   │   ├── bookclub-pricing-option.gjs           # New
│   │   └── bookclub-access-status.gjs            # Enhanced
│   └── services/
│       └── bookclub-subscriptions.js             # Enhanced
├── assets/stylesheets/
│   └── bookclub-paywall.scss                     # New
├── config/
│   ├── settings.yml                              # New settings
│   └── locales/
│       ├── client.en.yml                         # New strings
│       └── server.en.yml                         # New strings
├── lib/bookclub/
│   └── subscription_hooks.rb                     # Enhanced
├── plugin.rb                                     # Enhanced Guardian
└── spec/
    ├── services/pricing_config_spec.rb           # New
    ├── requests/pricing_spec.rb                  # Enhanced
    └── lib/access_control_spec.rb                # New
```

---

## Next steps

1. Review and approve this plan
2. Create Stripe test products with both price types
3. Begin Phase 1 implementation
4. Weekly progress reviews
