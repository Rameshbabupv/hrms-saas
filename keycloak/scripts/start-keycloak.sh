#!/bin/bash

################################################################################
# Start Keycloak Container with PostgreSQL Dependency
#
# This script starts PostgreSQL first (Keycloak dependency), then starts Keycloak
#
# Usage: ./start-keycloak.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

echo ""
echo "========================================"
echo "  Starting Keycloak Service (with DB)"
echo "========================================"
echo ""

# Check if Podman machine is running
print_info "Checking Podman machine status..."
MACHINE_STATUS=$(podman machine list --format "{{.Running}}" | head -1)

if [ "$MACHINE_STATUS" != "true" ]; then
    print_warning "Podman machine is not running. Starting..."
    podman machine start podman-machine-default
    print_success "Podman machine started"
    sleep 5
else
    print_success "Podman machine is already running"
fi

# ======================================
# Step 1: Start PostgreSQL
# ======================================
print_info "Checking PostgreSQL container..."
POSTGRES_EXISTS=$(podman ps -a --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

if [ "$POSTGRES_EXISTS" -eq 0 ]; then
    print_error "PostgreSQL container 'nexus-postgres-dev' not found!"
    print_info "Keycloak requires PostgreSQL to run. Please create the PostgreSQL container first."
    exit 1
fi

# Check if PostgreSQL is already running
POSTGRES_RUNNING=$(podman ps --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

if [ "$POSTGRES_RUNNING" -gt 0 ]; then
    print_success "PostgreSQL is already running"
else
    print_info "Starting PostgreSQL container..."
    podman start nexus-postgres-dev
    print_success "PostgreSQL container started"

    # Wait for PostgreSQL to be ready
    print_info "Waiting for PostgreSQL to be ready..."
    sleep 3

    MAX_PG_RETRIES=15
    PG_RETRY_COUNT=0

    while [ $PG_RETRY_COUNT -lt $MAX_PG_RETRIES ]; do
        if podman exec nexus-postgres-dev pg_isready -U postgres >/dev/null 2>&1; then
            print_success "PostgreSQL is ready!"
            break
        fi

        PG_RETRY_COUNT=$((PG_RETRY_COUNT + 1))
        echo -n "."
        sleep 2
    done
    echo ""

    if [ $PG_RETRY_COUNT -eq $MAX_PG_RETRIES ]; then
        print_error "PostgreSQL did not become ready within expected time"
        exit 1
    fi
fi

# ======================================
# Step 2: Start Keycloak
# ======================================
print_info "Checking Keycloak container..."
CONTAINER_EXISTS=$(podman ps -a --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$CONTAINER_EXISTS" -eq 0 ]; then
    print_error "Keycloak container 'nexus-keycloak-dev' not found!"
    print_info "Please create the container first or check the container name"
    exit 1
fi

# Check if container is already running
CONTAINER_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$CONTAINER_RUNNING" -gt 0 ]; then
    print_warning "Keycloak container is already running"
else
    print_info "Starting Keycloak container..."
    podman start nexus-keycloak-dev
    print_success "Keycloak container started"

    # Wait for Keycloak to be ready
    print_info "Waiting for Keycloak to be ready..."
    sleep 5

    MAX_RETRIES=30
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

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "Keycloak did not start within expected time"
        exit 1
    fi
fi

# Display status
echo ""
echo "========================================"
echo "  Services Status"
echo "========================================"
echo ""

print_info "PostgreSQL Status:"
podman ps --filter name=nexus-postgres-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
print_info "Keycloak Status:"
podman ps --filter name=nexus-keycloak-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
print_success "All services are running!"
echo ""
echo "Access Points:"
echo "  • Keycloak Admin: http://localhost:8090/admin"
echo "  • Keycloak Realm: hrms-saas"
echo "  • Admin Credentials: admin/secret"
echo "  • PostgreSQL: localhost:5432"
echo ""
echo "Management:"
echo "  • Stop: ./stop-keycloak.sh [--with-db]"
echo "  • Restart: ./restart-keycloak.sh [--with-db]"
echo "  • Status: ./status-keycloak.sh"
echo ""
