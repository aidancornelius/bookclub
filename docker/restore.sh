#!/bin/bash
set -e

# Bookclub Restore Script
# Restores PostgreSQL database and uploaded files from backup
#
# Usage:
#   ./restore.sh --db <backup-file> [--uploads <backup-file>]
#
# Options:
#   --db FILE       Database backup file to restore (required)
#   --uploads FILE  Uploads backup file to restore (optional)
#   --help          Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.prod.yml"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Parse command line arguments
DB_BACKUP_FILE=""
UPLOADS_BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --db)
            DB_BACKUP_FILE="$2"
            shift 2
            ;;
        --uploads)
            UPLOADS_BACKUP_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Bookclub Restore Script"
            echo ""
            echo "Usage: $0 --db <backup-file> [--uploads <backup-file>]"
            echo ""
            echo "Options:"
            echo "  --db FILE       Database backup file to restore (required)"
            echo "  --uploads FILE  Uploads backup file to restore (optional)"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$DB_BACKUP_FILE" ]; then
    log_error "Database backup file is required (--db option)"
    exit 1
fi

if [ ! -f "$DB_BACKUP_FILE" ]; then
    log_error "Database backup file not found: $DB_BACKUP_FILE"
    exit 1
fi

if [ -n "$UPLOADS_BACKUP_FILE" ] && [ ! -f "$UPLOADS_BACKUP_FILE" ]; then
    log_error "Uploads backup file not found: $UPLOADS_BACKUP_FILE"
    exit 1
fi

# Check if containers are running
if ! docker ps | grep -q bookclub_postgres; then
    log_error "PostgreSQL container is not running"
    log_error "Start it with: docker compose -f $COMPOSE_FILE up -d postgres"
    exit 1
fi

# Warning and confirmation
log_warning "=========================================="
log_warning "WARNING: This will DESTROY all current data"
log_warning "=========================================="
echo ""
log_info "Database backup: $DB_BACKUP_FILE"
if [ -n "$UPLOADS_BACKUP_FILE" ]; then
    log_info "Uploads backup: $UPLOADS_BACKUP_FILE"
fi
echo ""
read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
if [ "$REPLY" != "yes" ]; then
    log_info "Restore cancelled"
    exit 0
fi

# Stop Discourse to prevent database connections
log_info "Stopping Discourse container..."
docker compose -f "$COMPOSE_FILE" stop discourse

# Wait for connections to close
sleep 5

# Drop and recreate database
log_info "Dropping and recreating database..."
docker exec bookclub_postgres psql -U discourse -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'discourse' AND pid <> pg_backend_pid();" || true
docker exec bookclub_postgres psql -U discourse -c "DROP DATABASE IF EXISTS discourse;"
docker exec bookclub_postgres psql -U discourse -c "CREATE DATABASE discourse;"

# Restore database
log_info "Restoring database from $DB_BACKUP_FILE..."
if [[ "$DB_BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$DB_BACKUP_FILE" | docker exec -i bookclub_postgres psql -U discourse discourse
else
    cat "$DB_BACKUP_FILE" | docker exec -i bookclub_postgres psql -U discourse discourse
fi

log_success "Database restored successfully"

# Restore uploads if provided
if [ -n "$UPLOADS_BACKUP_FILE" ]; then
    log_info "Restoring uploads from $UPLOADS_BACKUP_FILE..."

    docker run --rm \
        -v bookclub_discourse_shared:/data \
        -v "$BACKUP_DIR":/backup:ro \
        alpine sh -c "cd /data && tar xzf /backup/$(basename "$UPLOADS_BACKUP_FILE")"

    log_success "Uploads restored successfully"
fi

# Start Discourse
log_info "Starting Discourse container..."
docker compose -f "$COMPOSE_FILE" start discourse

# Wait for Discourse to be healthy
log_info "Waiting for Discourse to start..."
for i in {1..60}; do
    if docker exec bookclub_discourse curl -f http://localhost:3000/srv/status > /dev/null 2>&1; then
        log_success "Discourse is running"
        break
    fi
    if [ $i -eq 60 ]; then
        log_error "Discourse failed to start"
        log_warning "Check logs: docker logs bookclub_discourse"
        exit 1
    fi
    sleep 2
done

log_success "Restore completed successfully"
log_info "Your Discourse instance has been restored from backup"
