#!/bin/bash

################################################################################
# Deploy Keycloak to QA using Docker Compose
#
# This script deploys the entire HRMS SaaS Keycloak stack to QA environment
#
# Usage: ./deploy-with-docker-compose.sh [start|stop|restart|status|logs]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/../docker-compose.yml"
ENV_FILE="${SCRIPT_DIR}/../.env"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check for docker-compose or docker compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose is not installed"
        print_info "Install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi

    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "docker-compose.yml not found at: $COMPOSE_FILE"
        exit 1
    fi

    if [ ! -f "$ENV_FILE" ]; then
        print_warning ".env file not found. Creating from example..."
        if [ -f "${SCRIPT_DIR}/../.env.example" ]; then
            cp "${SCRIPT_DIR}/../.env.example" "$ENV_FILE"
            print_warning "Please edit $ENV_FILE with your configuration"
            exit 1
        else
            print_error ".env.example not found"
            exit 1
        fi
    fi

    print_success "Prerequisites check passed"
}

# Start services
start_services() {
    echo ""
    echo "========================================"
    echo "  Starting HRMS Keycloak QA Services"
    echo "========================================"
    echo ""

    print_info "Starting services with Docker Compose..."

    cd "$(dirname "$COMPOSE_FILE")"

    $COMPOSE_CMD up -d

    print_success "Services started"

    echo ""
    print_info "Waiting for services to be healthy..."
    sleep 5

    # Wait for Keycloak to be ready
    MAX_RETRIES=60
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if $COMPOSE_CMD ps | grep -q "hrms-keycloak-qa.*Up"; then
            # Check if Keycloak is responding
            if curl -sf http://localhost:8090/ > /dev/null 2>&1; then
                print_success "Keycloak is ready!"
                break
            fi
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -n "."
        sleep 2
    done
    echo ""

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_warning "Keycloak is taking longer than expected to start"
        print_info "Check logs with: ./deploy-with-docker-compose.sh logs"
    fi

    show_status
}

# Stop services
stop_services() {
    echo ""
    echo "========================================"
    echo "  Stopping HRMS Keycloak QA Services"
    echo "========================================"
    echo ""

    print_info "Stopping services..."

    cd "$(dirname "$COMPOSE_FILE")"

    $COMPOSE_CMD down

    print_success "Services stopped"
}

# Restart services
restart_services() {
    echo ""
    echo "========================================"
    echo "  Restarting HRMS Keycloak QA Services"
    echo "========================================"
    echo ""

    print_info "Restarting services..."

    cd "$(dirname "$COMPOSE_FILE")"

    $COMPOSE_CMD restart

    print_success "Services restarted"

    show_status
}

# Show status
show_status() {
    echo ""
    echo "========================================"
    echo "  Service Status"
    echo "========================================"
    echo ""

    cd "$(dirname "$COMPOSE_FILE")"

    $COMPOSE_CMD ps

    echo ""
    echo "Access Points:"
    echo "  • Keycloak Admin Console: http://localhost:8090/admin"
    echo "  • Keycloak Realm: http://localhost:8090/realms/hrms-saas"
    echo "  • pgAdmin: http://localhost:8091"
    echo "  • PostgreSQL: localhost:5432"
    echo ""

    # Show volume usage
    echo "Data Volumes:"
    docker volume ls | grep hrms | awk '{print "  • " $2}'
    echo ""
}

# Show logs
show_logs() {
    cd "$(dirname "$COMPOSE_FILE")"

    if [ -n "$1" ]; then
        print_info "Showing logs for: $1"
        $COMPOSE_CMD logs -f --tail=100 "$1"
    else
        print_info "Showing all logs (press Ctrl+C to exit)"
        $COMPOSE_CMD logs -f --tail=100
    fi
}

# Backup data
backup_data() {
    echo ""
    echo "========================================"
    echo "  Backing Up Keycloak Data"
    echo "========================================"
    echo ""

    BACKUP_DIR="${SCRIPT_DIR}/../backups"
    mkdir -p "$BACKUP_DIR"

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/keycloak-qa-backup-${TIMESTAMP}.tar.gz"

    print_info "Creating backup..."

    cd "$(dirname "$COMPOSE_FILE")"

    # Backup database
    print_info "Backing up PostgreSQL database..."
    $COMPOSE_CMD exec -T postgres pg_dump -U admin hrms_keycloak_qa > "${BACKUP_DIR}/db-backup-${TIMESTAMP}.sql"

    # Backup volumes
    print_info "Backing up Keycloak data volume..."
    docker run --rm \
        -v hrms-keycloak-data-qa:/data \
        -v "${BACKUP_DIR}:/backup" \
        alpine tar czf "/backup/keycloak-data-${TIMESTAMP}.tar.gz" -C /data .

    # Create combined archive
    print_info "Creating combined backup archive..."
    tar czf "${BACKUP_FILE}" -C "${BACKUP_DIR}" \
        "db-backup-${TIMESTAMP}.sql" \
        "keycloak-data-${TIMESTAMP}.tar.gz"

    # Cleanup individual backups
    rm "${BACKUP_DIR}/db-backup-${TIMESTAMP}.sql"
    rm "${BACKUP_DIR}/keycloak-data-${TIMESTAMP}.tar.gz"

    print_success "Backup created: ${BACKUP_FILE}"
}

# Update services
update_services() {
    echo ""
    echo "========================================"
    echo "  Updating HRMS Keycloak QA Services"
    echo "========================================"
    echo ""

    print_info "Pulling latest images..."

    cd "$(dirname "$COMPOSE_FILE")"

    $COMPOSE_CMD pull

    print_info "Recreating services with new images..."

    $COMPOSE_CMD up -d --force-recreate

    print_success "Services updated"

    show_status
}

# Clean up
cleanup() {
    echo ""
    echo "========================================"
    echo "  Cleanup"
    echo "========================================"
    echo ""

    print_warning "This will remove all stopped containers and unused images"
    read -p "Are you sure? (yes/no): " -r
    echo

    if [[ $REPLY =~ ^[Yy]es$ ]]; then
        print_info "Cleaning up..."

        docker container prune -f
        docker image prune -a -f
        docker network prune -f

        print_success "Cleanup complete"
    else
        print_info "Cleanup cancelled"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs        Show logs (optionally specify service: keycloak, postgres, pgadmin)"
    echo "  backup      Create backup of all data"
    echo "  update      Update services to latest images"
    echo "  cleanup     Remove unused containers and images"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs keycloak"
    echo "  $0 backup"
    echo ""
}

# Main execution
main() {
    case "${1:-}" in
        start)
            check_prerequisites
            start_services
            ;;
        stop)
            check_prerequisites
            stop_services
            ;;
        restart)
            check_prerequisites
            restart_services
            ;;
        status)
            check_prerequisites
            show_status
            ;;
        logs)
            check_prerequisites
            show_logs "$2"
            ;;
        backup)
            check_prerequisites
            backup_data
            ;;
        update)
            check_prerequisites
            update_services
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: ${1:-}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main
main "$@"
