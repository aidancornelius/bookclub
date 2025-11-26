#!/bin/bash
# Bookclub Plugin Development Helper Commands
# This script provides shortcuts for common development tasks

set -e

CONTAINER_NAME="discourse_dev"
DISCOURSE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

show_help() {
    echo "Bookclub Plugin Development Commands"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  console          Open Rails console"
    echo "  shell            Open bash shell in container"
    echo "  logs [service]   View logs (rails/sidekiq/all)"
    echo "  test [spec]      Run RSpec tests"
    echo "  qunit            Run JavaScript tests"
    echo "  migrate          Run database migrations"
    echo "  rollback         Rollback last migration"
    echo "  seed             Load development seed data"
    echo "  reset-db         Reset database (WARNING: destructive)"
    echo "  lint [--fix]     Lint Ruby and JS files"
    echo "  status           Show container status"
    echo "  start            Start the container"
    echo "  stop             Stop the container"
    echo "  restart          Restart the container"
    echo "  enable-plugin    Enable Bookclub plugin"
    echo "  rails [cmd]      Run rails command"
    echo "  bundle [cmd]     Run bundle command"
    echo ""
    echo "Examples:"
    echo "  $0 console"
    echo "  $0 test spec/models"
    echo "  $0 logs rails"
    echo "  $0 lint --fix"
    echo "  $0 rails routes | grep bookclub"
}

check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Error: Container '${CONTAINER_NAME}' is not running.${NC}"
        echo "Start it with: bin/docker/boot_dev"
        exit 1
    fi
}

exec_in_container() {
    docker exec -u discourse -it "$CONTAINER_NAME" bash -c "cd /src && $*"
}

case "${1:-}" in
    console)
        check_container
        echo -e "${GREEN}Opening Rails console...${NC}"
        exec_in_container "bundle exec rails console"
        ;;

    shell)
        check_container
        echo -e "${GREEN}Opening shell in container...${NC}"
        docker exec -u discourse -it "$CONTAINER_NAME" bash
        ;;

    logs)
        check_container
        case "${2:-all}" in
            rails)
                echo -e "${GREEN}Viewing Rails logs...${NC}"
                exec_in_container "tail -f log/development.log"
                ;;
            sidekiq)
                echo -e "${GREEN}Viewing Sidekiq logs...${NC}"
                exec_in_container "tail -f log/sidekiq.log"
                ;;
            all|*)
                echo -e "${GREEN}Viewing container logs...${NC}"
                docker logs -f "$CONTAINER_NAME"
                ;;
        esac
        ;;

    test)
        check_container
        if [ -z "${2:-}" ]; then
            echo -e "${GREEN}Running all Bookclub specs...${NC}"
            exec_in_container "bundle exec rspec plugins/bookclub/spec"
        else
            echo -e "${GREEN}Running specs: ${2}${NC}"
            exec_in_container "bundle exec rspec $2"
        fi
        ;;

    qunit)
        check_container
        echo -e "${GREEN}Running JavaScript tests...${NC}"
        exec_in_container "bin/qunit plugins/bookclub"
        ;;

    migrate)
        check_container
        echo -e "${GREEN}Running database migrations...${NC}"
        exec_in_container "bundle exec rake db:migrate"
        ;;

    rollback)
        check_container
        echo -e "${YELLOW}Rolling back last migration...${NC}"
        exec_in_container "bundle exec rake db:rollback"
        ;;

    seed)
        check_container
        echo -e "${GREEN}Loading development seed data...${NC}"
        exec_in_container "bundle exec rails runner \"load 'plugins/bookclub/db/seeds/development.rb'\""
        ;;

    reset-db)
        check_container
        echo -e "${RED}WARNING: This will delete all data in the database!${NC}"
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            echo -e "${YELLOW}Resetting database...${NC}"
            exec_in_container "bundle exec rake db:drop db:create db:migrate"
            echo -e "${GREEN}Database reset complete.${NC}"
            echo "Run '$0 seed' to load test data."
        else
            echo "Cancelled."
        fi
        ;;

    lint)
        check_container
        if [ "${2:-}" = "--fix" ]; then
            echo -e "${GREEN}Linting and auto-fixing...${NC}"
            exec_in_container "bin/rubocop -A plugins/bookclub"
            exec_in_container "bin/lint --fix plugins/bookclub"
        else
            echo -e "${GREEN}Linting (no fixes)...${NC}"
            exec_in_container "bin/rubocop plugins/bookclub"
            exec_in_container "bin/lint plugins/bookclub"
        fi
        ;;

    status)
        echo -e "${BLUE}Container Status:${NC}"
        docker ps -a --filter name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "${GREEN}✓ Container is running${NC}"
            echo ""
            echo -e "${BLUE}Memory Usage:${NC}"
            docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        else
            echo -e "${RED}✗ Container is not running${NC}"
        fi
        ;;

    start)
        echo -e "${GREEN}Starting container...${NC}"
        docker start "$CONTAINER_NAME"
        echo "Waiting for services to start..."
        sleep 3
        echo -e "${GREEN}Container started.${NC}"
        ;;

    stop)
        echo -e "${YELLOW}Stopping container...${NC}"
        docker stop "$CONTAINER_NAME"
        echo -e "${GREEN}Container stopped.${NC}"
        ;;

    restart)
        echo -e "${YELLOW}Restarting container...${NC}"
        docker restart "$CONTAINER_NAME"
        echo "Waiting for services to restart..."
        sleep 3
        echo -e "${GREEN}Container restarted.${NC}"
        ;;

    enable-plugin)
        check_container
        echo -e "${GREEN}Enabling Bookclub plugin...${NC}"
        exec_in_container "bundle exec rails runner 'SiteSetting.bookclub_enabled = true; puts \"Plugin enabled!\"'"
        ;;

    rails)
        check_container
        shift
        echo -e "${GREEN}Running Rails command: $*${NC}"
        exec_in_container "bundle exec rails $*"
        ;;

    bundle)
        check_container
        shift
        echo -e "${GREEN}Running Bundle command: $*${NC}"
        exec_in_container "bundle $*"
        ;;

    help|--help|-h|"")
        show_help
        ;;

    *)
        echo -e "${RED}Error: Unknown command '$1'${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
