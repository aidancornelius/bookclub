#!/bin/bash
set -e

# Bookclub Plugin Docker Development Setup Script
# This script initialises the Discourse development environment with the Bookclub plugin enabled

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCOURSE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "Bookclub Plugin Development Setup"
echo "=========================================="
echo "Discourse root: $DISCOURSE_ROOT"
echo "Plugin directory: $PLUGIN_DIR"
echo ""

# Check if we're in the right directory
if [ ! -f "$DISCOURSE_ROOT/Gemfile" ]; then
    echo "Error: Cannot find Discourse root directory."
    echo "Please run this script from the plugin docker directory or fix paths."
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if discourse_dev container exists
if docker ps -a --format '{{.Names}}' | grep -q "^discourse_dev$\|^discourse_dev_bookclub$"; then
    echo "Found existing Discourse dev container."
    read -p "Do you want to remove it and start fresh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping and removing existing container..."
        docker stop discourse_dev discourse_dev_bookclub 2>/dev/null || true
        docker rm discourse_dev discourse_dev_bookclub 2>/dev/null || true
    fi
fi

# Determine which method to use
echo ""
echo "Choose setup method:"
echo "1. Use existing bin/docker/boot_dev script (recommended)"
echo "2. Use docker-compose from this plugin"
read -p "Enter choice (1 or 2): " -n 1 -r
echo ""

if [[ $REPLY == "1" ]]; then
    # Method 1: Use existing Discourse Docker setup
    echo ""
    echo "Starting Discourse development environment..."
    echo "This will use the existing bin/docker/boot_dev script."
    echo ""

    cd "$DISCOURSE_ROOT"

    # Check if this is first run
    if [ ! -d "data/postgres" ] || [ -z "$(ls -A data/postgres 2>/dev/null)" ]; then
        echo "First time setup detected. Running with --init flag..."
        bin/docker/boot_dev --init
    else
        echo "Starting existing environment..."
        bin/docker/boot_dev
    fi

    CONTAINER_NAME="discourse_dev"

elif [[ $REPLY == "2" ]]; then
    # Method 2: Use docker-compose
    echo ""
    echo "Starting environment with docker-compose..."
    cd "$DISCOURSE_ROOT"

    docker compose -f plugins/bookclub/docker/docker-compose.dev.yml up -d

    CONTAINER_NAME="discourse_dev_bookclub"

    # Wait for container to be ready
    echo "Waiting for container to start..."
    sleep 5

    # Install dependencies
    echo "Installing Ruby gems..."
    docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && bundle install"

    echo "Installing Node packages..."
    docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && pnpm install"

    # Check if database needs initialisation
    DB_EXISTS=$(docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && bundle exec rails runner 'puts ActiveRecord::Base.connection.tables.any?'" 2>/dev/null || echo "false")

    if [[ "$DB_EXISTS" == "false" ]]; then
        echo ""
        echo "Database not initialised. Setting up database..."

        echo "Creating database..."
        docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && bundle exec rake db:create"

        echo "Running migrations..."
        docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && bundle exec rake db:migrate"

        echo "Running test database migrations..."
        docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && RAILS_ENV=test bundle exec rake db:migrate"

        echo ""
        echo "Creating admin user..."
        docker exec -it -u discourse "$CONTAINER_NAME" bash -c "cd /src && bundle exec rake admin:create"
    fi
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Enable the Bookclub plugin
echo ""
echo "Enabling Bookclub plugin..."
docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && bundle exec rails runner \"
  SiteSetting.bookclub_enabled = true
  puts 'Bookclub plugin enabled!'
\""

# Load seed data if available
if [ -f "$PLUGIN_DIR/db/seeds/development.rb" ]; then
    echo ""
    read -p "Load Bookclub seed data (sample publications and chapters)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Loading seed data..."
        docker exec -u discourse "$CONTAINER_NAME" bash -c "cd /src && bundle exec rails runner \"
          load 'plugins/bookclub/db/seeds/development.rb'
        \""
    fi
fi

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Container name: $CONTAINER_NAME"
echo ""
echo "Access your Discourse instance at:"
echo "  - Ember (development): http://localhost:4200"
echo "  - Rails (API): http://localhost:3000"
echo "  - Unicorn: http://localhost:9292"
echo "  - Mailhog (email testing): http://localhost:8025"
echo ""
echo "Useful commands:"
echo "  - Enter container: docker exec -it -u discourse $CONTAINER_NAME bash"
echo "  - View logs: docker logs -f $CONTAINER_NAME"
echo "  - Run migrations: docker exec -u discourse $CONTAINER_NAME bash -c 'cd /src && bundle exec rake db:migrate'"
echo "  - Run tests: docker exec -u discourse $CONTAINER_NAME bash -c 'cd /src && bundle exec rspec plugins/bookclub/spec'"
echo "  - Rails console: docker exec -it -u discourse $CONTAINER_NAME bash -c 'cd /src && bundle exec rails c'"
echo "  - Stop container: docker stop $CONTAINER_NAME"
echo "  - Start container: docker start $CONTAINER_NAME"
echo ""
echo "To start the Rails server inside the container:"
echo "  docker exec -u discourse $CONTAINER_NAME bash -c 'cd /src && bundle exec rails server -b 0.0.0.0'"
echo ""
echo "To start Ember CLI (required for frontend development):"
echo "  docker exec -u discourse $CONTAINER_NAME bash -c 'cd /src && bin/ember-cli'"
echo ""
