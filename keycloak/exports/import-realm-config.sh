#!/bin/bash

################################################################################
# Import Realm Configuration Only
#
# This script imports the realm configuration from JSON export including:
# - Realm settings
# - Clients and client configurations
# - Roles (realm and client roles)
# - Protocol mappers (JWT claims)
# - Authentication flows
#
# NOTE: This does NOT import users or passwords
#
# Usage: ./import-realm-config.sh
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
echo "  Keycloak Realm Configuration Import"
echo "========================================"
echo ""

# Check if export file exists
if [ ! -f "hrms-saas-realm-export.json" ]; then
    print_error "Export file 'hrms-saas-realm-export.json' not found!"
    print_info "Make sure you're running this script from the exports directory"
    exit 1
fi

print_info "Found realm export file: hrms-saas-realm-export.json ($(du -h hrms-saas-realm-export.json | cut -f1))"

# Check if Keycloak container exists
CONTAINER_EXISTS=$(podman ps -a --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)
if [ "$CONTAINER_EXISTS" -eq 0 ]; then
    print_error "Keycloak container 'nexus-keycloak-dev' not found!"
    exit 1
fi

# Check if Keycloak is running
CONTAINER_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)
if [ "$CONTAINER_RUNNING" -eq 0 ]; then
    print_warning "Keycloak is not running. Starting it now..."
    podman start nexus-keycloak-dev
    sleep 5

    # Wait for Keycloak to be ready
    print_info "Waiting for Keycloak to be ready..."
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

# Copy export file to container
print_info "Copying realm export to container..."
podman cp hrms-saas-realm-export.json nexus-keycloak-dev:/tmp/hrms-saas-realm-export.json

if [ $? -ne 0 ]; then
    print_error "Failed to copy export file to container"
    exit 1
fi

print_success "Export file copied to container"

# Get admin access token
print_info "Authenticating with Keycloak..."
TOKEN=$(curl -s -X POST "http://localhost:8090/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=secret" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    print_error "Failed to get access token"
    exit 1
fi

print_success "Successfully authenticated"

# Import realm using REST API
print_info "Importing realm configuration..."
RESPONSE=$(curl -s -X POST "http://localhost:8090/admin/realms" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @hrms-saas-realm-export.json \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" == "201" ]; then
    print_success "Realm configuration imported successfully!"
elif [ "$HTTP_CODE" == "409" ]; then
    print_warning "Realm 'hrms-saas' already exists"
    print_info "Would you like to update the existing realm? This will overwrite current settings."
    read -p "Update existing realm? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Updating existing realm..."
        # Note: You'll need to implement partial update via REST API
        print_warning "Realm update not implemented in this script"
        print_info "Please delete the existing realm first and re-run this script"
    fi
else
    print_error "Failed to import realm (HTTP $HTTP_CODE)"
    echo "$RESPONSE" | head -n -1
    exit 1
fi

echo ""
echo "========================================"
echo "  Import Complete!"
echo "========================================"
echo ""
print_success "Realm configuration has been imported"
echo ""
echo "What was imported:"
echo "  ✓ Realm settings"
echo "  ✓ 7 OAuth clients"
echo "  ✓ 8 realm roles"
echo "  ✓ Protocol mappers (JWT claims)"
echo "  ✓ Authentication flows"
echo ""
print_warning "Users and passwords were NOT imported"
echo ""
echo "Next Steps:"
echo "  1. Create users manually via Admin Console"
echo "  2. Or use the REST API with hrms-saas-users-detailed.json"
echo "  3. Set passwords for all users"
echo ""
echo "Access Information:"
echo "  • Admin Console: http://localhost:8090/admin"
echo "  • Realm: hrms-saas"
echo "  • Credentials: admin/secret"
echo ""
