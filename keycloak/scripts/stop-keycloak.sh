#!/bin/bash

################################################################################
# Stop Keycloak Container (and optionally PostgreSQL)
#
# This script stops the Keycloak Podman container and optionally PostgreSQL
#
# Usage:
#   ./stop-keycloak.sh           # Stop only Keycloak
#   ./stop-keycloak.sh --with-db # Stop both Keycloak and PostgreSQL
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
STOP_DB=false
if [ "$1" == "--with-db" ] || [ "$1" == "--with-postgres" ]; then
    STOP_DB=true
fi

echo ""
if [ "$STOP_DB" = true ]; then
    echo "=============================================="
    echo "  Stopping Keycloak and PostgreSQL Services"
    echo "=============================================="
else
    echo "=================================="
    echo "  Stopping Keycloak Service"
    echo "=================================="
fi
echo ""

# ======================================
# Step 1: Stop Keycloak
# ======================================
print_info "Checking Keycloak container status..."
CONTAINER_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$CONTAINER_RUNNING" -eq 0 ]; then
    print_warning "Keycloak container is not running"
else
    print_info "Stopping Keycloak container..."
    podman stop nexus-keycloak-dev
    print_success "Keycloak container stopped"
fi

# ======================================
# Step 2: Optionally stop PostgreSQL
# ======================================
if [ "$STOP_DB" = true ]; then
    print_info "Checking PostgreSQL container status..."
    POSTGRES_RUNNING=$(podman ps --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

    if [ "$POSTGRES_RUNNING" -eq 0 ]; then
        print_warning "PostgreSQL container is not running"
    else
        print_info "Stopping PostgreSQL container..."
        podman stop nexus-postgres-dev
        print_success "PostgreSQL container stopped"
    fi
fi

# Display status
echo ""
echo "=================================="
echo "  Services Status"
echo "=================================="
echo ""

print_info "PostgreSQL Status:"
podman ps -a --filter name=nexus-postgres-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
print_info "Keycloak Status:"
podman ps -a --filter name=nexus-keycloak-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
if [ "$STOP_DB" = true ]; then
    print_success "Both Keycloak and PostgreSQL have been stopped"
else
    print_success "Keycloak has been stopped (PostgreSQL is still running)"
fi
echo ""
echo "Management:"
echo "  • Start: ./start-keycloak.sh"
echo "  • Restart: ./restart-keycloak.sh [--with-db]"
echo "  • Status: ./status-keycloak.sh"
echo ""
