#!/bin/bash

################################################################################
# Deploy Keycloak to QA using Podman
#
# This script deploys the entire HRMS SaaS Keycloak stack using Podman
# with persistent volumes
#
# Usage: ./deploy-with-podman.sh [start|stop|restart|status]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
POSTGRES_CONTAINER="hrms-postgres-qa"
KEYCLOAK_CONTAINER="hrms-keycloak-qa"
PGADMIN_CONTAINER="hrms-pgadmin-qa"
NETWORK_NAME="hrms-network-qa"

# Volume names
PGDATA_VOLUME="hrms-pgdata-qa"
KEYCLOAK_DATA_VOLUME="hrms-keycloak-data-qa"
PGADMIN_DATA_VOLUME="hrms-pgadmin-data-qa"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Warning: .env file not found, using defaults"
fi

# Environment defaults
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-secret}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-secret}"
PGADMIN_EMAIL="${PGADMIN_EMAIL:-admin@hrms.com}"
PGADMIN_PASSWORD="${PGADMIN_PASSWORD:-secret}"
KEYCLOAK_HOSTNAME="${KEYCLOAK_HOSTNAME:-localhost}"

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

# Check if podman is installed
check_podman() {
    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed"
        exit 1
    fi
    print_success "Podman is available"
}

# Check/start podman machine (for macOS)
check_podman_machine() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Checking Podman machine..."
        MACHINE_STATUS=$(podman machine list --format "{{.Running}}" 2>/dev/null | head -1 || echo "false")

        if [ "$MACHINE_STATUS" != "true" ]; then
            print_warning "Podman machine is not running. Starting..."
            podman machine start
            sleep 5
            print_success "Podman machine started"
        else
            print_success "Podman machine is running"
        fi
    fi
}

# Create network if not exists
create_network() {
    print_info "Creating network..."

    if podman network exists "$NETWORK_NAME" 2>/dev/null; then
        print_warning "Network '$NETWORK_NAME' already exists"
    else
        podman network create "$NETWORK_NAME"
        print_success "Network '$NETWORK_NAME' created"
    fi
}

# Create volumes if not exist
create_volumes() {
    print_info "Creating volumes..."

    for volume in "$PGDATA_VOLUME" "$KEYCLOAK_DATA_VOLUME" "$PGADMIN_DATA_VOLUME"; do
        if podman volume exists "$volume" 2>/dev/null; then
            print_warning "Volume '$volume' already exists"
        else
            podman volume create "$volume"
            print_success "Volume '$volume' created"
        fi
    done
}

# Start PostgreSQL
start_postgres() {
    print_info "Starting PostgreSQL..."

    if podman ps -a --format "{{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        if podman ps --format "{{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
            print_warning "PostgreSQL is already running"
            return 0
        else
            print_info "Starting existing PostgreSQL container..."
            podman start "$POSTGRES_CONTAINER"
            print_success "PostgreSQL started"
            return 0
        fi
    fi

    podman run -d \
        --name "$POSTGRES_CONTAINER" \
        --network "$NETWORK_NAME" \
        -e POSTGRES_USER=admin \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_DB=hrms_keycloak_qa \
        -v "$PGDATA_VOLUME:/var/lib/postgresql/data" \
        -p 5432:5432 \
        --restart unless-stopped \
        postgres:16

    print_success "PostgreSQL container created and started"

    # Wait for PostgreSQL to be ready
    print_info "Waiting for PostgreSQL to be ready..."
    sleep 5

    MAX_RETRIES=30
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if podman exec "$POSTGRES_CONTAINER" pg_isready -U admin > /dev/null 2>&1; then
            print_success "PostgreSQL is ready!"
            break
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -n "."
        sleep 1
    done
    echo ""
}

# Start Keycloak
start_keycloak() {
    print_info "Starting Keycloak..."

    if podman ps -a --format "{{.Names}}" | grep -q "^${KEYCLOAK_CONTAINER}$"; then
        if podman ps --format "{{.Names}}" | grep -q "^${KEYCLOAK_CONTAINER}$"; then
            print_warning "Keycloak is already running"
            return 0
        else
            print_info "Starting existing Keycloak container..."
            podman start "$KEYCLOAK_CONTAINER"
            print_success "Keycloak started"
            return 0
        fi
    fi

    podman run -d \
        --name "$KEYCLOAK_CONTAINER" \
        --network "$NETWORK_NAME" \
        -e KEYCLOAK_ADMIN=admin \
        -e KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD" \
        -e KC_DB=postgres \
        -e KC_DB_URL="jdbc:postgresql://${POSTGRES_CONTAINER}:5432/hrms_keycloak_qa" \
        -e KC_DB_USERNAME=admin \
        -e KC_DB_PASSWORD="$POSTGRES_PASSWORD" \
        -e KC_HOSTNAME="$KEYCLOAK_HOSTNAME" \
        -e KC_HOSTNAME_STRICT=false \
        -e KC_HTTP_ENABLED=true \
        -e KC_PROXY=edge \
        -v "$KEYCLOAK_DATA_VOLUME:/opt/keycloak/data" \
        -p 8090:8080 \
        -p 8443:8443 \
        --restart unless-stopped \
        quay.io/keycloak/keycloak:latest \
        start-dev

    print_success "Keycloak container created and started"

    # Wait for Keycloak to be ready
    print_info "Waiting for Keycloak to be ready (this may take 30-60 seconds)..."
    sleep 10

    MAX_RETRIES=60
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/ 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
            print_success "Keycloak is ready!"
            break
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -n "."
        sleep 2
    done
    echo ""
}

# Start pgAdmin
start_pgadmin() {
    print_info "Starting pgAdmin..."

    if podman ps -a --format "{{.Names}}" | grep -q "^${PGADMIN_CONTAINER}$"; then
        if podman ps --format "{{.Names}}" | grep -q "^${PGADMIN_CONTAINER}$"; then
            print_warning "pgAdmin is already running"
            return 0
        else
            print_info "Starting existing pgAdmin container..."
            podman start "$PGADMIN_CONTAINER"
            print_success "pgAdmin started"
            return 0
        fi
    fi

    podman run -d \
        --name "$PGADMIN_CONTAINER" \
        --network "$NETWORK_NAME" \
        -e PGADMIN_DEFAULT_EMAIL="$PGADMIN_EMAIL" \
        -e PGADMIN_DEFAULT_PASSWORD="$PGADMIN_PASSWORD" \
        -e PGADMIN_CONFIG_SERVER_MODE=False \
        -v "$PGADMIN_DATA_VOLUME:/var/lib/pgadmin" \
        -p 8091:80 \
        --restart unless-stopped \
        dpage/pgadmin4:latest

    print_success "pgAdmin container created and started"
}

# Start all services
start_all() {
    echo ""
    echo "========================================"
    echo "  Starting HRMS Keycloak QA Stack"
    echo "========================================"
    echo ""

    check_podman
    check_podman_machine
    create_network
    create_volumes
    start_postgres
    start_keycloak
    start_pgadmin

    show_status
}

# Stop all services
stop_all() {
    echo ""
    echo "========================================"
    echo "  Stopping HRMS Keycloak QA Stack"
    echo "========================================"
    echo ""

    print_info "Stopping containers..."

    for container in "$KEYCLOAK_CONTAINER" "$PGADMIN_CONTAINER" "$POSTGRES_CONTAINER"; do
        if podman ps --format "{{.Names}}" | grep -q "^${container}$"; then
            podman stop "$container"
            print_success "Stopped: $container"
        else
            print_warning "$container is not running"
        fi
    done
}

# Restart all services
restart_all() {
    echo ""
    echo "========================================"
    echo "  Restarting HRMS Keycloak QA Stack"
    echo "========================================"
    echo ""

    stop_all
    sleep 2
    start_all
}

# Show status
show_status() {
    echo ""
    echo "========================================"
    echo "  Service Status"
    echo "========================================"
    echo ""

    podman ps --filter "name=hrms-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    echo "Access Points:"
    echo "  • Keycloak Admin Console: http://localhost:8090/admin"
    echo "  • Keycloak Realm: http://localhost:8090/realms/hrms-saas"
    echo "  • pgAdmin: http://localhost:8091"
    echo "  • PostgreSQL: localhost:5432"
    echo ""
    echo "Credentials:"
    echo "  • Keycloak Admin: admin / [from .env]"
    echo "  • pgAdmin: [from .env]"
    echo "  • PostgreSQL: admin / [from .env]"
    echo ""

    echo "Volumes:"
    podman volume ls --filter "name=hrms-" --format "table {{.Name}}\t{{.Driver}}"
    echo ""
}

# Show usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo ""
}

# Main execution
main() {
    case "${1:-}" in
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            restart_all
            ;;
        status)
            check_podman
            show_status
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
