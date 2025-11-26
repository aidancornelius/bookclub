# Docker Development Setup - Quick Start

This guide helps you quickly get started with Docker development for the Bookclub plugin.

## TL;DR - Get Started in 3 Steps

```bash
# 1. Navigate to Discourse root
cd /path/to/discourse

# 2. Run the setup script
./plugins/bookclub/docker/setup.sh

# 3. Access your development environment
open http://localhost:4200
```

## What You Get

- **Discourse Development Container**: Full Discourse dev environment using the official `discourse/discourse_dev:release` image
- **Sample Publications**: Pre-configured book and journal with chapters/articles
- **Test Users**: Author, editor, and reader accounts with different permission levels
- **Access Control**: Basic and premium tier groups for testing subscription features
- **Live Reload**: Ember CLI on port 4200 with hot module reloading

## Files Created

```
plugins/bookclub/
├── docker/
│   ├── README.md                  # Comprehensive documentation
│   ├── docker-compose.dev.yml     # Docker Compose configuration
│   └── setup.sh                   # Interactive setup script
├── db/
│   └── seeds/
│       └── development.rb         # Test data (publications, users, chapters)
└── DOCKER_SETUP.md               # This file
```

## Quick Commands

### Starting the Environment

```bash
# Interactive setup (recommended for first time)
./plugins/bookclub/docker/setup.sh

# Or use Discourse's native Docker scripts
bin/docker/boot_dev --init  # First time
bin/docker/boot_dev         # Subsequent runs
```

### Accessing Services

- **Frontend (Ember CLI)**: http://localhost:4200
- **Backend (Rails)**: http://localhost:3000
- **Email Testing (Mailhog)**: http://localhost:8025

### Running Tests

```bash
# Ruby specs
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rspec plugins/bookclub/spec"

# JavaScript tests
docker exec -u discourse discourse_dev bash -c "cd /src && bin/qunit plugins/bookclub"
```

### Rails Console

```bash
docker exec -it -u discourse discourse_dev bash -c "cd /src && bundle exec rails console"
```

### Loading Seed Data

```bash
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rails runner \"load 'plugins/bookclub/db/seeds/development.rb'\""
```

## Test Credentials

All test users have the password: `password123`

| Username | Role | Access Level |
|----------|------|--------------|
| bookclub_author | Author | Can create content |
| bookclub_editor | Editor | Can manage publications |
| basic_reader | Reader | Basic tier access |
| premium_reader | Reader | Premium tier access |

## Need Help?

See the comprehensive guide: `plugins/bookclub/docker/README.md`

## Key Differences from Production

This Docker setup is for **LOCAL DEVELOPMENT ONLY**:

- ✅ Uses SQLite-style PostgreSQL (not production-ready)
- ✅ Includes debugging tools and verbose logging
- ✅ Ember CLI with live reload (slower but better DX)
- ✅ Mailhog captures emails instead of sending
- ✅ Running on localhost, not a real domain

**Production server** (at warpu):
- Uses production-grade PostgreSQL
- Optimised for performance, not development
- Real email delivery
- Proper domain and SSL

## Design Philosophy

Rather than creating a separate Docker Compose setup that duplicates Discourse's infrastructure, we leverage Discourse's battle-tested `discourse_dev` image and provide convenience scripts on top. This means:

1. **Compatibility**: Always up-to-date with Discourse's recommended development setup
2. **Simplicity**: Fewer configuration files to maintain
3. **Flexibility**: Can use `bin/docker/boot_dev` directly or our helper scripts
4. **Best Practices**: Follows Discourse's official development guidelines

## Next Steps

1. Start the environment: `./plugins/bookclub/docker/setup.sh`
2. Load seed data when prompted
3. Visit http://localhost:4200
4. Log in as `bookclub_author` / `password123`
5. Browse to the "The Elements of Ruby Style" publication
6. Start developing!

For detailed documentation, troubleshooting, and advanced usage, see:
**`plugins/bookclub/docker/README.md`**
