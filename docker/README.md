# Bookclub Plugin Docker Development Environment

This directory contains Docker configuration for developing and testing the Bookclub plugin with Discourse.

## Overview

The Bookclub plugin development environment leverages Discourse's existing `discourse_dev` Docker image and infrastructure. Rather than creating a separate setup, we provide convenience scripts and configurations that work with Discourse's battle-tested Docker development workflow.

## Prerequisites

- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later (comes with Docker Desktop)
- **Disk Space**: At least 10GB free for images and volumes
- **Memory**: At least 4GB RAM allocated to Docker
- **macOS Users**: If using symlinked plugins, install coreutils: `brew install coreutils`

## Quick Start

### Option 1: Using the Setup Script (Recommended)

The setup script provides an interactive way to initialise your environment:

**Helper Script Available:** After setup, use `plugins/bookclub/docker/dev-commands.sh` for common tasks like `console`, `test`, `logs`, etc. Run `./plugins/bookclub/docker/dev-commands.sh help` for all commands.

```bash
# From the Discourse root directory
cd /path/to/discourse

# Run the setup script
./plugins/bookclub/docker/setup.sh
```

The script will:
1. Detect existing containers and offer to start fresh if needed
2. Let you choose between Discourse's `bin/docker/boot_dev` or docker-compose
3. Install dependencies (gems and npm packages)
4. Set up the database if needed
5. Create an admin user (first run only)
6. Enable the Bookclub plugin
7. Optionally load seed data with sample publications

### Option 2: Using Discourse's Native Docker Scripts

Discourse has built-in Docker development support via `bin/docker/`:

```bash
# From Discourse root
cd /path/to/discourse

# First time setup
bin/docker/boot_dev --init

# Subsequent runs
bin/docker/boot_dev
```

Then enable the plugin:

```bash
bin/docker/exec bundle exec rails runner "SiteSetting.bookclub_enabled = true"
```

### Option 3: Using Docker Compose Directly

```bash
# From Discourse root
cd /path/to/discourse

# Start the environment
docker compose -f plugins/bookclub/docker/docker-compose.dev.yml up -d

# Install dependencies
docker exec -u discourse discourse_dev_bookclub bash -c "cd /src && bundle install && pnpm install"

# Set up database (first time only)
docker exec -u discourse discourse_dev_bookclub bash -c "cd /src && bundle exec rake db:create db:migrate"
docker exec -u discourse discourse_dev_bookclub bash -c "cd /src && RAILS_ENV=test bundle exec rake db:migrate"

# Create admin user (first time only)
docker exec -it -u discourse discourse_dev_bookclub bash -c "cd /src && bundle exec rake admin:create"

# Enable plugin
docker exec -u discourse discourse_dev_bookclub bash -c "cd /src && bundle exec rails runner 'SiteSetting.bookclub_enabled = true'"
```

## Accessing the Application

Once running, access your Discourse instance at:

- **Ember CLI (Development UI)**: http://localhost:4200
- **Rails Server**: http://localhost:3000
- **Unicorn**: http://localhost:9292
- **Mailhog (Email Testing)**: http://localhost:8025

The Ember CLI interface (port 4200) is the primary development interface and includes live reloading.

## Loading Test Data

The plugin includes seed data that creates:
- Sample book publication with 5 chapters
- Sample journal with 1 issue and 1 article
- Test users (author, editor, readers with different access levels)
- Access tier groups (basic and premium)

### Load Seeds via Setup Script

The setup script will prompt you to load seeds. You can also load them manually:

```bash
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rails runner \"load 'plugins/bookclub/db/seeds/development.rb'\""
```

### Test Users Created by Seeds

| Username | Password | Role | Description |
|----------|----------|------|-------------|
| bookclub_author | password123 | Author | Creates publications and content |
| bookclub_editor | password123 | Editor | Manages publications |
| basic_reader | password123 | Reader | Basic tier subscriber |
| premium_reader | password123 | Reader | Premium tier subscriber |

## Common Development Tasks

### Running the Rails Server

```bash
# Start Rails server (accessible at localhost:3000)
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rails server -b 0.0.0.0"
```

### Running Ember CLI (Frontend Development)

```bash
# Start Ember CLI (accessible at localhost:4200, includes live reload)
docker exec -u discourse discourse_dev bash -c "cd /src && bin/ember-cli"
```

### Running Migrations

```bash
# Run pending migrations
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rake db:migrate"

# Rollback migration
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rake db:rollback"
```

### Running Tests

```bash
# Run plugin specs
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rspec plugins/bookclub/spec"

# Run specific spec file
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rspec plugins/bookclub/spec/models/bookclub_publication_spec.rb"

# Run with plugin loading enabled (if needed)
docker exec -u discourse discourse_dev bash -c "cd /src && LOAD_PLUGINS=1 bundle exec rspec plugins/bookclub/spec"

# Run JavaScript tests
docker exec -u discourse discourse_dev bash -c "cd /src && bin/qunit plugins/bookclub"
```

### Rails Console

```bash
# Open Rails console
docker exec -it -u discourse discourse_dev bash -c "cd /src && bundle exec rails console"
```

Example console commands:
```ruby
# Check if plugin is enabled
SiteSetting.bookclub_enabled

# Find publications
Category.where("custom_fields @> ?", {publication_enabled: true}.to_json)

# Find a publication by slug
pub = Category.joins(:category_custom_fields)
  .where(category_custom_fields: {name: 'publication_slug', value: 'elements-of-ruby-style'})
  .first
```

### Accessing Container Shell

```bash
# Enter container as discourse user
docker exec -it -u discourse discourse_dev bash

# Enter container as root (for system-level operations)
docker exec -it -u root discourse_dev bash
```

### Viewing Logs

```bash
# View container logs
docker logs -f discourse_dev

# View Rails logs (from within container)
docker exec -u discourse discourse_dev bash -c "tail -f /src/log/development.log"

# View Sidekiq logs
docker exec -u discourse discourse_dev bash -c "tail -f /src/log/sidekiq.log"
```

### Database Access

```bash
# Connect to PostgreSQL
docker exec -it discourse_dev psql -U discourse discourse_development

# Common SQL queries
SELECT * FROM site_settings WHERE name LIKE '%bookclub%';
SELECT id, name FROM categories WHERE id IN (
  SELECT category_id FROM category_custom_fields
  WHERE name = 'publication_enabled' AND value = 'true'
);
```

### Linting and Code Quality

```bash
# Lint Ruby files
docker exec -u discourse discourse_dev bash -c "cd /src && bin/rubocop plugins/bookclub"

# Lint with auto-fix
docker exec -u discourse discourse_dev bash -c "cd /src && bin/rubocop -A plugins/bookclub"

# Lint JavaScript files
docker exec -u discourse discourse_dev bash -c "cd /src && bin/lint plugins/bookclub"
```

## Container Management

### Start/Stop Container

```bash
# Stop container
docker stop discourse_dev

# Start container
docker start discourse_dev

# Restart container
docker restart discourse_dev
```

### Remove Container and Data

```bash
# Stop and remove container
docker stop discourse_dev
docker rm discourse_dev

# Remove volumes (WARNING: deletes all data)
docker volume rm discourse_bookclub_postgres_data

# Using Discourse's cleanup script
bin/docker/cleanup
```

### View Container Status

```bash
# List running containers
docker ps

# View container resource usage
docker stats discourse_dev

# Inspect container configuration
docker inspect discourse_dev
```

## Troubleshooting

### Container Won't Start

1. Check Docker is running: `docker info`
2. Check for port conflicts: `lsof -i :3000,4200,9292`
3. View container logs: `docker logs discourse_dev`
4. Try removing and recreating: `docker rm discourse_dev` then run setup again

### Database Connection Issues

```bash
# Check PostgreSQL is running
docker exec discourse_dev bash -c "pg_isready"

# Reset database (WARNING: deletes all data)
docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rake db:drop db:create db:migrate"
```

### Plugin Not Loading

1. Check plugin is enabled:
   ```bash
   docker exec -u discourse discourse_dev bash -c "cd /src && bundle exec rails runner 'puts SiteSetting.bookclub_enabled'"
   ```

2. Check for syntax errors:
   ```bash
   docker exec -u discourse discourse_dev bash -c "cd /src && ruby -c plugins/bookclub/plugin.rb"
   ```

3. Restart the container:
   ```bash
   docker restart discourse_dev
   ```

### Bundle Install Fails

```bash
# Clear bundle cache and reinstall
docker exec -u discourse discourse_dev bash -c "cd /src && rm -rf vendor/bundle && bundle install"
```

### Ember CLI Won't Start

```bash
# Clear node_modules and reinstall
docker exec -u discourse discourse_dev bash -c "cd /src && rm -rf node_modules && pnpm install"
```

### Permission Issues (macOS)

If you see permission errors with mounted volumes:

```bash
# Fix ownership inside container
docker exec -u root discourse_dev chown -R discourse:discourse /src
```

### Port Already in Use

If ports are already allocated:

```bash
# Find what's using the port
lsof -i :4200

# Kill the process or change the port mapping in docker-compose.dev.yml
```

## Environment Variables

You can customise the environment by passing environment variables:

```bash
# Via docker-compose
docker compose -f plugins/bookclub/docker/docker-compose.dev.yml up -d \
  -e DISCOURSE_HOSTNAME=mydiscourse.local

# Via boot_dev script
bin/docker/boot_dev -e DISCOURSE_HOSTNAME=mydiscourse.local
```

Common variables:
- `DISCOURSE_HOSTNAME`: Hostname for the Discourse instance (default: localhost)
- `DISCOURSE_DEV_DB`: Database name (default: discourse_development)
- `RAILS_ENV`: Rails environment (default: development)

## Production Server vs Development

**Important:** This Docker setup is for LOCAL DEVELOPMENT ONLY. It is not suitable for production.

The production server at `warpu` (aidancornelius@warpu) runs a different configuration. To deploy to production:

1. Make changes locally using this Docker environment
2. Test thoroughly with `bin/rspec` and manual testing
3. Commit changes to version control
4. Deploy to the production server using your normal deployment process

Do not attempt to run this Docker setup on the production server.

## Advanced Configuration

### Using Symlinked Plugins

If your Bookclub plugin is symlinked from another location:

```bash
# The boot_dev script automatically handles symlinks
# Just ensure readlink works (macOS users need greadlink)
brew install coreutils
ln -s "$(which greadlink)" "$(dirname "$(which greadlink)")/readlink"
```

### Custom Database Configuration

Edit `config/database.yml` or use environment variables:

```bash
docker exec -u discourse discourse_dev bash -c "cd /src && \
  DISCOURSE_DEV_DB=bookclub_development bundle exec rake db:create db:migrate"
```

### Debugging with Pry

Add `binding.pry` to your code, then attach to the container:

```bash
docker attach discourse_dev
```

Or run the server in the foreground:

```bash
docker exec -it -u discourse discourse_dev bash -c "cd /src && bundle exec rails server -b 0.0.0.0"
```

## Additional Resources

- [Discourse Docker Development Guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-for-development-using-docker/102009)
- [Discourse Plugin Development](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins/30515)
- [Discourse Developer Docs](https://docs.discourse.org/)
- [discourse_docker GitHub](https://github.com/discourse/discourse_docker)

## Getting Help

If you encounter issues:

1. Check this README's troubleshooting section
2. View container logs: `docker logs discourse_dev`
3. Check Discourse Meta for similar issues
4. Ask in the Discourse development category on Meta

## Contributing

When contributing to the Bookclub plugin:

1. Use this Docker environment for development
2. Run tests before committing: `bin/rspec plugins/bookclub/spec`
3. Lint your code: `bin/rubocop -A plugins/bookclub`
4. Update this documentation if you change the Docker setup
5. Follow the Discourse plugin development guidelines

## File Structure

```
plugins/bookclub/docker/
├── README.md                    # This file
├── docker-compose.dev.yml       # Docker Compose configuration
├── setup.sh                     # Interactive setup script
└── dev-commands.sh              # Helper commands for common tasks

plugins/bookclub/db/
└── seeds/
    └── development.rb           # Seed data for testing
```

## Helper Commands

The `dev-commands.sh` script provides shortcuts for common tasks:

```bash
# From Discourse root
./plugins/bookclub/docker/dev-commands.sh <command>

# Examples:
./plugins/bookclub/docker/dev-commands.sh console       # Open Rails console
./plugins/bookclub/docker/dev-commands.sh test          # Run all specs
./plugins/bookclub/docker/dev-commands.sh logs rails    # View Rails logs
./plugins/bookclub/docker/dev-commands.sh seed          # Load seed data
./plugins/bookclub/docker/dev-commands.sh lint --fix    # Lint and fix
./plugins/bookclub/docker/dev-commands.sh status        # Container status
./plugins/bookclub/docker/dev-commands.sh help          # Show all commands
```
