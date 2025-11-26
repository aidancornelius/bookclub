#!/bin/bash
set -e

# Bookclub Backup Script
# Creates backups of PostgreSQL database and uploaded files
#
# Usage:
#   ./backup.sh [options]
#
# Options:
#   --rotate N      Keep only the last N backups (default: 7)
#   --s3            Upload backup to S3 (requires S3 configuration)
#   --help          Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.prod.yml"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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

# Default options
KEEP_BACKUPS=7
UPLOAD_TO_S3=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rotate)
            KEEP_BACKUPS="$2"
            shift 2
            ;;
        --s3)
            UPLOAD_TO_S3=true
            shift
            ;;
        --help)
            echo "Bookclub Backup Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --rotate N      Keep only the last N backups (default: 7)"
            echo "  --s3            Upload backup to S3 (requires S3 configuration)"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Starting backup at $(date)"

# Check if containers are running
if ! docker ps | grep -q bookclub_postgres; then
    log_error "PostgreSQL container is not running"
    exit 1
fi

# Source environment if available
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Backup PostgreSQL database
log_info "Backing up PostgreSQL database..."
DB_BACKUP_FILE="$BACKUP_DIR/discourse-db-$TIMESTAMP.sql.gz"

docker exec bookclub_postgres pg_dump -U discourse discourse | gzip > "$DB_BACKUP_FILE"

if [ -f "$DB_BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
    log_success "Database backup created: $DB_BACKUP_FILE ($BACKUP_SIZE)"
else
    log_error "Database backup failed"
    exit 1
fi

# Backup uploaded files (if they exist in shared volume)
log_info "Backing up uploaded files..."
UPLOADS_BACKUP_FILE="$BACKUP_DIR/discourse-uploads-$TIMESTAMP.tar.gz"

if docker volume inspect bookclub_discourse_shared > /dev/null 2>&1; then
    docker run --rm \
        -v bookclub_discourse_shared:/data:ro \
        -v "$BACKUP_DIR":/backup \
        alpine tar czf "/backup/discourse-uploads-$TIMESTAMP.tar.gz" -C /data uploads 2>/dev/null || true

    if [ -f "$UPLOADS_BACKUP_FILE" ]; then
        UPLOADS_SIZE=$(du -h "$UPLOADS_BACKUP_FILE" | cut -f1)
        log_success "Uploads backup created: $UPLOADS_BACKUP_FILE ($UPLOADS_SIZE)"
    else
        log_warning "Uploads backup skipped (no uploads directory)"
        UPLOADS_BACKUP_FILE=""
    fi
else
    log_warning "Shared volume not found, skipping uploads backup"
    UPLOADS_BACKUP_FILE=""
fi

# Create a manifest file
MANIFEST_FILE="$BACKUP_DIR/backup-$TIMESTAMP.manifest"
cat > "$MANIFEST_FILE" << EOF
Backup Manifest
===============
Created: $(date)
Hostname: ${DISCOURSE_HOSTNAME:-unknown}
Database: $DB_BACKUP_FILE
Uploads: ${UPLOADS_BACKUP_FILE:-none}
EOF

log_success "Backup manifest created: $MANIFEST_FILE"

# Upload to S3 if requested
if [ "$UPLOAD_TO_S3" = true ]; then
    if [ -z "$S3_BACKUP_BUCKET" ]; then
        log_error "S3_BACKUP_BUCKET not set in environment"
        exit 1
    fi

    log_info "Uploading backups to S3..."

    # Check if AWS CLI is available
    if command -v aws &> /dev/null; then
        S3_PREFIX="s3://$S3_BACKUP_BUCKET/bookclub-backups/$TIMESTAMP"

        aws s3 cp "$DB_BACKUP_FILE" "$S3_PREFIX/" || log_error "Failed to upload database backup to S3"

        if [ -n "$UPLOADS_BACKUP_FILE" ]; then
            aws s3 cp "$UPLOADS_BACKUP_FILE" "$S3_PREFIX/" || log_error "Failed to upload files backup to S3"
        fi

        aws s3 cp "$MANIFEST_FILE" "$S3_PREFIX/" || log_error "Failed to upload manifest to S3"

        log_success "Backups uploaded to $S3_PREFIX"
    else
        log_error "AWS CLI not found, cannot upload to S3"
        exit 1
    fi
fi

# Rotate old backups
log_info "Rotating old backups (keeping last $KEEP_BACKUPS)..."

# Count database backups
DB_BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/discourse-db-*.sql.gz 2>/dev/null | wc -l)
if [ "$DB_BACKUP_COUNT" -gt "$KEEP_BACKUPS" ]; then
    TO_DELETE=$((DB_BACKUP_COUNT - KEEP_BACKUPS))
    ls -1t "$BACKUP_DIR"/discourse-db-*.sql.gz | tail -n "$TO_DELETE" | xargs rm -f
    log_info "Deleted $TO_DELETE old database backup(s)"
fi

# Count uploads backups
UPLOADS_BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/discourse-uploads-*.tar.gz 2>/dev/null | wc -l)
if [ "$UPLOADS_BACKUP_COUNT" -gt "$KEEP_BACKUPS" ]; then
    TO_DELETE=$((UPLOADS_BACKUP_COUNT - KEEP_BACKUPS))
    ls -1t "$BACKUP_DIR"/discourse-uploads-*.tar.gz | tail -n "$TO_DELETE" | xargs rm -f
    log_info "Deleted $TO_DELETE old uploads backup(s)"
fi

# Count manifest files
MANIFEST_COUNT=$(ls -1 "$BACKUP_DIR"/backup-*.manifest 2>/dev/null | wc -l)
if [ "$MANIFEST_COUNT" -gt "$KEEP_BACKUPS" ]; then
    TO_DELETE=$((MANIFEST_COUNT - KEEP_BACKUPS))
    ls -1t "$BACKUP_DIR"/backup-*.manifest | tail -n "$TO_DELETE" | xargs rm -f
    log_info "Deleted $TO_DELETE old manifest file(s)"
fi

log_success "Backup completed successfully at $(date)"

# Show backup summary
log_info "Current backups:"
ls -lh "$BACKUP_DIR"/discourse-db-*.sql.gz 2>/dev/null | tail -n "$KEEP_BACKUPS" || true
