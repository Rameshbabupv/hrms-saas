#!/bin/bash

################################################################################
# Stop Keycloak Container
#
# This script stops the Keycloak Podman container
#
# Usage: ./stop-keycloak.sh
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
echo "=================================="
echo "  Stopping Keycloak Service"
echo "=================================="
echo ""

# Check if container is running
print_info "Checking Keycloak container status..."
CONTAINER_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$CONTAINER_RUNNING" -eq 0 ]; then
    print_warning "Keycloak container is not running"
else
    print_info "Stopping Keycloak container..."
    podman stop nexus-keycloak-dev
    print_success "Keycloak container stopped"
fi

echo ""
echo "=================================="
echo "  Keycloak Status"
echo "=================================="
echo ""

podman ps -a --filter name=nexus-keycloak-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
print_success "Keycloak has been stopped"
echo ""
echo "To start Keycloak: ./start-keycloak.sh"
echo "To check status: ./status-keycloak.sh"
echo ""
