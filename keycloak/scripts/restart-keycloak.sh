#!/bin/bash

################################################################################
# Restart Keycloak Container (and optionally PostgreSQL)
#
# This script restarts Keycloak and optionally PostgreSQL
#
# Usage:
#   ./restart-keycloak.sh           # Restart only Keycloak
#   ./restart-keycloak.sh --with-db # Restart both PostgreSQL and Keycloak
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

# Parse arguments
RESTART_DB=false
if [ "$1" == "--with-db" ] || [ "$1" == "--with-postgres" ]; then
    RESTART_DB=true
fi

echo ""
if [ "$RESTART_DB" = true ]; then
    echo "================================================"
    echo "  Restarting Keycloak and PostgreSQL Services"
    echo "================================================"
else
    echo "========================================"
    echo "  Restarting Keycloak Service"
    echo "========================================"
fi
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
# Step 1: Stop Keycloak
# ======================================
print_info "Stopping Keycloak container..."
KEYCLOAK_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$KEYCLOAK_RUNNING" -gt 0 ]; then
    podman stop nexus-keycloak-dev
    print_success "Keycloak container stopped"
else
    print_warning "Keycloak container was not running"
fi

# ======================================
# Step 2: Optionally stop PostgreSQL
# ======================================
if [ "$RESTART_DB" = true ]; then
    print_info "Stopping PostgreSQL container..."
    POSTGRES_RUNNING=$(podman ps --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

    if [ "$POSTGRES_RUNNING" -gt 0 ]; then
        podman stop nexus-postgres-dev
        print_success "PostgreSQL container stopped"
    else
        print_warning "PostgreSQL container was not running"
    fi

    # Wait a moment before restarting
    sleep 2

    # ======================================
    # Step 3: Start PostgreSQL
    # ======================================
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
else
    # Ensure PostgreSQL is running before starting Keycloak
    print_info "Checking PostgreSQL status..."
    POSTGRES_RUNNING=$(podman ps --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

    if [ "$POSTGRES_RUNNING" -eq 0 ]; then
        print_warning "PostgreSQL is not running. Starting it first..."
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
    else
        print_success "PostgreSQL is already running"
    fi
fi

# Wait a moment before starting Keycloak
sleep 2

# ======================================
# Step 4: Start Keycloak
# ======================================
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
if [ "$RESTART_DB" = true ]; then
    print_success "Both PostgreSQL and Keycloak have been restarted!"
else
    print_success "Keycloak has been restarted!"
fi
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
