#!/bin/bash

################################################################################
# Check Keycloak Container Status
#
# This script checks the status of Keycloak and related services
#
# Usage: ./status-keycloak.sh
################################################################################

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo ""
echo "================================================="
echo "  Keycloak & PostgreSQL Service Status"
echo "================================================="
echo ""

# Check Podman Machine
print_header "Podman Machine Status:"
MACHINE_RUNNING=$(podman machine list --format "{{.Running}}" | head -1)

if [ "$MACHINE_RUNNING" == "true" ]; then
    print_success "Podman machine is running"
else
    print_error "Podman machine is not running"
    echo ""
    echo "To start: podman machine start podman-machine-default"
    exit 1
fi

echo ""

# Check PostgreSQL Status
print_header "PostgreSQL Container Status:"
POSTGRES_RUNNING=$(podman ps --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

if [ "$POSTGRES_RUNNING" -gt 0 ]; then
    print_success "PostgreSQL container is running"

    echo ""
    podman ps --filter name=nexus-postgres-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    # Check PostgreSQL readiness
    if podman exec nexus-postgres-dev pg_isready -U postgres >/dev/null 2>&1; then
        print_success "PostgreSQL is accepting connections"
    else
        print_warning "PostgreSQL is running but not yet ready"
    fi
else
    print_warning "PostgreSQL container is not running"

    # Check if container exists
    POSTGRES_EXISTS=$(podman ps -a --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

    if [ "$POSTGRES_EXISTS" -gt 0 ]; then
        echo ""
        podman ps -a --filter name=nexus-postgres-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        print_warning "Keycloak requires PostgreSQL to be running!"
        echo "To start: ./start-keycloak.sh (will start both services)"
    else
        print_error "PostgreSQL container does not exist"
    fi
fi

echo ""

# Check Keycloak Container Status
print_header "Keycloak Container Status:"
CONTAINER_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$CONTAINER_RUNNING" -gt 0 ]; then
    print_success "Keycloak container is running"

    echo ""
    podman ps --filter name=nexus-keycloak-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    print_error "Keycloak container is not running"

    # Check if container exists
    CONTAINER_EXISTS=$(podman ps -a --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

    if [ "$CONTAINER_EXISTS" -gt 0 ]; then
        echo ""
        podman ps -a --filter name=nexus-keycloak-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "To start: ./start-keycloak.sh"
    else
        print_error "Keycloak container does not exist"
    fi
    exit 0
fi

echo ""

# Check Keycloak Health
print_header "Keycloak Health Check:"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/ 2>/dev/null || echo "000")

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
    print_success "Keycloak is responding (HTTP $HTTP_CODE)"
else
    print_error "Keycloak is not responding (HTTP $HTTP_CODE)"
fi

echo ""

# Check Realm
print_header "Realm Configuration:"

REALM_CHECK=$(curl -s http://localhost:8090/realms/hrms-saas 2>/dev/null | jq -r '.realm' 2>/dev/null || echo "error")

if [ "$REALM_CHECK" == "hrms-saas" ]; then
    print_success "Realm 'hrms-saas' is accessible"
else
    print_error "Realm 'hrms-saas' is not accessible"
fi

echo ""

# Display Access Information
print_header "Access Information:"
echo "  • Admin Console: http://localhost:8090/admin"
echo "  • Realm: hrms-saas"
echo "  • Credentials: admin/secret"
echo ""

# Display Realm Endpoints
print_header "Realm Endpoints:"
echo "  • Token: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token"
echo "  • JWKS: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs"
echo "  • Userinfo: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/userinfo"
echo ""

# Display Management Scripts
print_header "Management Scripts:"
echo "  • Start: ./start-keycloak.sh (starts both PostgreSQL and Keycloak)"
echo "  • Stop: ./stop-keycloak.sh [--with-db]"
echo "  • Restart: ./restart-keycloak.sh [--with-db]"
echo "  • Status: ./status-keycloak.sh"
echo "  • Setup: ./setup-keycloak.sh"
echo "  • Test: ./test-token.sh"
echo ""
echo "  Note: Use --with-db flag to also stop/restart PostgreSQL"
echo ""
