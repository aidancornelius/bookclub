#!/bin/bash

# Bookclub Health Check Script
# Monitors the health of all production services
#
# Usage:
#   ./healthcheck.sh [options]
#
# Options:
#   --slack-webhook URL   Send alerts to Slack webhook
#   --email ADDRESS       Send alerts to email address
#   --quiet               Only output on errors
#   --json                Output in JSON format
#   --help                Show this help message
#
# Exit codes:
#   0 - All services healthy
#   1 - One or more services unhealthy
#   2 - Script error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.prod.yml"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Options
SLACK_WEBHOOK=""
EMAIL_ADDRESS=""
QUIET_MODE=false
JSON_OUTPUT=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --slack-webhook)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        --email)
            EMAIL_ADDRESS="$2"
            shift 2
            ;;
        --quiet)
            QUIET_MODE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help)
            echo "Bookclub Health Check Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --slack-webhook URL   Send alerts to Slack webhook"
            echo "  --email ADDRESS       Send alerts to email address"
            echo "  --quiet               Only output on errors"
            echo "  --json                Output in JSON format"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

# Logging functions
log_info() {
    if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    fi
}

log_warning() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
}

# Health check results
declare -A health_results
declare -A health_messages
overall_health="healthy"

# Check Docker daemon
check_docker() {
    if docker info > /dev/null 2>&1; then
        health_results["docker"]="healthy"
        health_messages["docker"]="Docker daemon is running"
        log_success "Docker daemon is running"
    else
        health_results["docker"]="unhealthy"
        health_messages["docker"]="Docker daemon is not responding"
        log_error "Docker daemon is not responding"
        overall_health="unhealthy"
    fi
}

# Check PostgreSQL
check_postgres() {
    if docker exec bookclub_postgres pg_isready -U discourse > /dev/null 2>&1; then
        health_results["postgres"]="healthy"
        health_messages["postgres"]="PostgreSQL is accepting connections"
        log_success "PostgreSQL is healthy"
    else
        health_results["postgres"]="unhealthy"
        health_messages["postgres"]="PostgreSQL is not accepting connections"
        log_error "PostgreSQL is unhealthy"
        overall_health="unhealthy"
    fi
}

# Check Redis
check_redis() {
    if docker exec bookclub_redis redis-cli ping > /dev/null 2>&1; then
        health_results["redis"]="healthy"
        health_messages["redis"]="Redis is responding to PING"
        log_success "Redis is healthy"
    else
        health_results["redis"]="unhealthy"
        health_messages["redis"]="Redis is not responding"
        log_error "Redis is unhealthy"
        overall_health="unhealthy"
    fi
}

# Check Discourse
check_discourse() {
    if docker exec bookclub_discourse curl -f http://localhost:3000/srv/status > /dev/null 2>&1; then
        health_results["discourse"]="healthy"
        health_messages["discourse"]="Discourse is responding to health checks"
        log_success "Discourse is healthy"
    else
        health_results["discourse"]="unhealthy"
        health_messages["discourse"]="Discourse health check failed"
        log_error "Discourse is unhealthy"
        overall_health="unhealthy"
    fi
}

# Check Nginx
check_nginx() {
    if docker exec bookclub_nginx wget --quiet --tries=1 --spider http://localhost/health 2>&1; then
        health_results["nginx"]="healthy"
        health_messages["nginx"]="Nginx is responding"
        log_success "Nginx is healthy"
    else
        health_results["nginx"]="unhealthy"
        health_messages["nginx"]="Nginx health check failed"
        log_error "Nginx is unhealthy"
        overall_health="unhealthy"
    fi
}

# Check disk space
check_disk_space() {
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -lt 80 ]; then
        health_results["disk"]="healthy"
        health_messages["disk"]="Disk usage: ${DISK_USAGE}%"
        log_success "Disk space is adequate (${DISK_USAGE}%)"
    elif [ "$DISK_USAGE" -lt 90 ]; then
        health_results["disk"]="warning"
        health_messages["disk"]="Disk usage: ${DISK_USAGE}% (warning threshold)"
        log_warning "Disk space is getting low (${DISK_USAGE}%)"
    else
        health_results["disk"]="unhealthy"
        health_messages["disk"]="Disk usage: ${DISK_USAGE}% (critical)"
        log_error "Disk space is critically low (${DISK_USAGE}%)"
        overall_health="unhealthy"
    fi
}

# Check memory usage
check_memory() {
    if command -v free > /dev/null 2>&1; then
        MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')
        if [ "$MEMORY_USAGE" -lt 80 ]; then
            health_results["memory"]="healthy"
            health_messages["memory"]="Memory usage: ${MEMORY_USAGE}%"
            log_success "Memory usage is normal (${MEMORY_USAGE}%)"
        elif [ "$MEMORY_USAGE" -lt 90 ]; then
            health_results["memory"]="warning"
            health_messages["memory"]="Memory usage: ${MEMORY_USAGE}% (warning threshold)"
            log_warning "Memory usage is high (${MEMORY_USAGE}%)"
        else
            health_results["memory"]="unhealthy"
            health_messages["memory"]="Memory usage: ${MEMORY_USAGE}% (critical)"
            log_error "Memory usage is critically high (${MEMORY_USAGE}%)"
            overall_health="unhealthy"
        fi
    else
        health_results["memory"]="unknown"
        health_messages["memory"]="Memory check not available"
    fi
}

# Check SSL certificate expiry
check_ssl_cert() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
    fi

    if [ -n "$DISCOURSE_HOSTNAME" ]; then
        CERT_FILE="/etc/letsencrypt/live/${DISCOURSE_HOSTNAME}/cert.pem"
        CERT_DAYS=$(docker exec bookclub_certbot openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2 | xargs -I{} date -d "{}" +%s || echo "")

        if [ -n "$CERT_DAYS" ]; then
            CURRENT_DAYS=$(date +%s)
            DAYS_LEFT=$(( (CERT_DAYS - CURRENT_DAYS) / 86400 ))

            if [ "$DAYS_LEFT" -gt 30 ]; then
                health_results["ssl"]="healthy"
                health_messages["ssl"]="SSL certificate expires in $DAYS_LEFT days"
                log_success "SSL certificate is valid ($DAYS_LEFT days remaining)"
            elif [ "$DAYS_LEFT" -gt 7 ]; then
                health_results["ssl"]="warning"
                health_messages["ssl"]="SSL certificate expires in $DAYS_LEFT days (renewal recommended)"
                log_warning "SSL certificate expires soon ($DAYS_LEFT days)"
            else
                health_results["ssl"]="unhealthy"
                health_messages["ssl"]="SSL certificate expires in $DAYS_LEFT days (critical)"
                log_error "SSL certificate expires very soon ($DAYS_LEFT days)"
                overall_health="unhealthy"
            fi
        else
            health_results["ssl"]="unknown"
            health_messages["ssl"]="Could not check SSL certificate"
        fi
    fi
}

# Run all health checks
log_info "Running health checks..."

check_docker
if [ "${health_results["docker"]}" = "healthy" ]; then
    check_postgres
    check_redis
    check_discourse
    check_nginx
fi

check_disk_space
check_memory
check_ssl_cert

# Output results
if [ "$JSON_OUTPUT" = true ]; then
    # JSON output
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"overall_status\": \"$overall_health\","
    echo "  \"checks\": {"
    first=true
    for service in "${!health_results[@]}"; do
        if [ "$first" = false ]; then
            echo ","
        fi
        echo -n "    \"$service\": {\"status\": \"${health_results[$service]}\", \"message\": \"${health_messages[$service]}\"}"
        first=false
    done
    echo ""
    echo "  }"
    echo "}"
else
    # Human-readable summary
    if [ "$QUIET_MODE" = false ]; then
        echo ""
        echo "=========================================="
        echo "Health Check Summary"
        echo "=========================================="
        echo "Timestamp: $(date)"
        echo "Overall Status: $overall_health"
        echo ""
        echo "Service Details:"
        for service in "${!health_results[@]}"; do
            status="${health_results[$service]}"
            message="${health_messages[$service]}"
            case $status in
                healthy)
                    echo -e "  ${GREEN}✓${NC} $service: $message"
                    ;;
                warning)
                    echo -e "  ${YELLOW}⚠${NC} $service: $message"
                    ;;
                unhealthy)
                    echo -e "  ${RED}✗${NC} $service: $message"
                    ;;
                *)
                    echo -e "  ${BLUE}?${NC} $service: $message"
                    ;;
            esac
        done
        echo "=========================================="
    fi
fi

# Send alerts if configured and there are issues
if [ "$overall_health" != "healthy" ]; then
    # Slack alert
    if [ -n "$SLACK_WEBHOOK" ]; then
        MESSAGE="Bookclub Health Check Alert\nOverall Status: $overall_health\n\n"
        for service in "${!health_results[@]}"; do
            if [ "${health_results[$service]}" != "healthy" ]; then
                MESSAGE="$MESSAGE$service: ${health_messages[$service]}\n"
            fi
        done

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$MESSAGE\"}" \
            "$SLACK_WEBHOOK" > /dev/null 2>&1
    fi

    # Email alert (requires mail command)
    if [ -n "$EMAIL_ADDRESS" ] && command -v mail > /dev/null 2>&1; then
        MESSAGE="Bookclub Health Check Alert\n\nOverall Status: $overall_health\n\n"
        for service in "${!health_results[@]}"; do
            if [ "${health_results[$service]}" != "healthy" ]; then
                MESSAGE="$MESSAGE$service: ${health_messages[$service]}\n"
            fi
        done

        echo -e "$MESSAGE" | mail -s "Bookclub Health Check Alert" "$EMAIL_ADDRESS"
    fi
fi

# Exit with appropriate code
if [ "$overall_health" = "healthy" ]; then
    exit 0
else
    exit 1
fi
