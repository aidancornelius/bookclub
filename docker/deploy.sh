#!/bin/bash
set -e

# Bookclub Production Deployment Script
# This script handles deployment updates, migrations, and service restarts
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   --init          Initial deployment (setup SSL, create admin)
#   --rollback      Rollback to previous deployment
#   --backup-first  Create backup before deploying
#   --skip-build    Skip Docker image rebuild
#   --help          Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.prod.yml"
BACKUP_DIR="$SCRIPT_DIR/backups"
DEPLOYMENT_LOG="$SCRIPT_DIR/deployments.log"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$DEPLOYMENT_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$DEPLOYMENT_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$DEPLOYMENT_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$DEPLOYMENT_LOG"
}

# Parse command line arguments
INIT_MODE=false
ROLLBACK_MODE=false
BACKUP_FIRST=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --init)
            INIT_MODE=true
            shift
            ;;
        --rollback)
            ROLLBACK_MODE=true
            shift
            ;;
        --backup-first)
            BACKUP_FIRST=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help)
            echo "Bookclub Production Deployment Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --init          Initial deployment (setup SSL, create admin)"
            echo "  --rollback      Rollback to previous deployment"
            echo "  --backup-first  Create backup before deploying"
            echo "  --skip-build    Skip Docker image rebuild"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    log_error "Docker Compose is not installed or not in PATH"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log_error ".env file not found at $SCRIPT_DIR/.env"
    log_error "Please create one based on .env.example"
    exit 1
fi

# Source environment variables
source "$SCRIPT_DIR/.env"

# Verify required environment variables
REQUIRED_VARS=(
    "DISCOURSE_HOSTNAME"
    "POSTGRES_PASSWORD"
    "SECRET_KEY_BASE"
    "SMTP_ADDRESS"
    "SMTP_USER_NAME"
    "SMTP_PASSWORD"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

log_success "Prerequisites check passed"

# Rollback function
rollback() {
    log_warning "Starting rollback procedure..."

    if [ ! -f "$BACKUP_DIR/rollback_image_tag.txt" ]; then
        log_error "No rollback information found"
        exit 1
    fi

    PREVIOUS_TAG=$(cat "$BACKUP_DIR/rollback_image_tag.txt")
    log_info "Rolling back to image tag: $PREVIOUS_TAG"

    # Export the previous tag
    export DISCOURSE_VERSION="$PREVIOUS_TAG"

    # Stop current containers
    docker compose -f "$COMPOSE_FILE" down

    # Start with previous version
    docker compose -f "$COMPOSE_FILE" up -d

    # Restore database if backup exists
    LATEST_DB_BACKUP=$(ls -t "$BACKUP_DIR"/discourse-db-*.sql.gz 2>/dev/null | head -n1)
    if [ -n "$LATEST_DB_BACKUP" ]; then
        read -p "Restore database from $LATEST_DB_BACKUP? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Restoring database..."
            gunzip -c "$LATEST_DB_BACKUP" | docker exec -i bookclub_postgres psql -U discourse discourse
            log_success "Database restored"
        fi
    fi

    log_success "Rollback completed"
    exit 0
}

# Handle rollback mode
if [ "$ROLLBACK_MODE" = true ]; then
    rollback
fi

# Initial deployment setup
if [ "$INIT_MODE" = true ]; then
    log_info "Starting initial deployment setup..."

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Pull images
    log_info "Pulling Docker images..."
    docker compose -f "$COMPOSE_FILE" pull

    # Start services
    log_info "Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d

    # Wait for database to be ready
    log_info "Waiting for database to be ready..."
    for i in {1..30}; do
        if docker exec bookclub_postgres pg_isready -U discourse > /dev/null 2>&1; then
            log_success "Database is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Database failed to start"
            exit 1
        fi
        sleep 2
    done

    # Run database migrations
    log_info "Running database migrations..."
    docker exec bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake db:migrate'"

    # Precompile assets
    log_info "Precompiling assets..."
    docker exec bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake assets:precompile'"

    # Setup SSL certificate
    log_info "Setting up SSL certificate with Certbot..."
    docker compose -f "$COMPOSE_FILE" run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$DISCOURSE_DEVELOPER_EMAILS" \
        --agree-tos \
        --no-eff-email \
        -d "$DISCOURSE_HOSTNAME"

    # Reload nginx to use new certificate
    docker exec bookclub_nginx nginx -s reload

    # Create admin user
    log_info "Creating admin user..."
    log_warning "Please follow the prompts to create an admin user"
    docker exec -it bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake admin:create'"

    log_success "Initial deployment completed successfully"
    log_info "Your Discourse instance should now be available at https://$DISCOURSE_HOSTNAME"
    exit 0
fi

# Regular deployment update
log_info "Starting deployment update..."
log_info "Deployment started at $(date)"

# Create backup if requested
if [ "$BACKUP_FIRST" = true ]; then
    log_info "Creating pre-deployment backup..."
    "$SCRIPT_DIR/backup.sh"
fi

# Save current image tag for rollback
CURRENT_TAG=$(docker inspect --format='{{.Config.Image}}' bookclub_discourse 2>/dev/null | cut -d':' -f2 || echo "latest")
echo "$CURRENT_TAG" > "$BACKUP_DIR/rollback_image_tag.txt"
log_info "Saved current version for rollback: $CURRENT_TAG"

# Pull latest code
log_info "Pulling latest code..."
cd "$PROJECT_ROOT"
git fetch origin
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull origin "$CURRENT_BRANCH"

# Pull latest images
if [ "$SKIP_BUILD" = false ]; then
    log_info "Pulling latest Docker images..."
    docker compose -f "$COMPOSE_FILE" pull
fi

# Check if containers are running
if ! docker ps | grep -q bookclub_discourse; then
    log_warning "Containers not running, starting them..."
    docker compose -f "$COMPOSE_FILE" up -d
else
    # Run database migrations (before restarting)
    log_info "Running database migrations..."
    docker exec bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake db:migrate'"

    # Precompile assets
    log_info "Precompiling assets..."
    docker exec bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake assets:precompile'"

    # Recreate containers with new images
    log_info "Recreating containers..."
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-deps discourse

    # Wait for Discourse to be healthy
    log_info "Waiting for Discourse to be healthy..."
    for i in {1..60}; do
        if docker exec bookclub_discourse curl -f http://localhost:3000/srv/status > /dev/null 2>&1; then
            log_success "Discourse is healthy"
            break
        fi
        if [ $i -eq 60 ]; then
            log_error "Discourse failed health check"
            log_warning "You may want to check logs: docker logs bookclub_discourse"
            exit 1
        fi
        sleep 2
    done
fi

# Restart Sidekiq workers
log_info "Restarting Sidekiq workers..."
docker exec bookclub_discourse sv restart sidekiq

# Clean up old Docker images
log_info "Cleaning up old Docker images..."
docker image prune -f

log_success "Deployment completed successfully"
log_info "Deployment finished at $(date)"

# Show container status
log_info "Current container status:"
docker compose -f "$COMPOSE_FILE" ps

# Show recent logs
log_info "Recent Discourse logs:"
docker logs --tail 20 bookclub_discourse
