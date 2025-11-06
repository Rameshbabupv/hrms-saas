#!/bin/bash

################################################################################
# Change PostgreSQL Password from 'admin' to 'secret'
#
# This script:
# 1. Starts PostgreSQL if not running
# 2. Changes the PostgreSQL admin user password
# 3. Recreates Keycloak container with new password
# 4. Verifies the connection
#
# Usage: ./change-postgres-password.sh
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
echo "========================================================"
echo "  Change PostgreSQL Password: admin → secret"
echo "========================================================"
echo ""

# Configuration
OLD_PASSWORD="admin"
NEW_PASSWORD="secret"

# Step 1: Check Podman machine
print_info "Checking Podman machine status..."
MACHINE_RUNNING=$(podman machine list --format "{{.Running}}" | head -1)

if [ "$MACHINE_RUNNING" != "true" ]; then
    print_warning "Podman machine is not running. Starting..."
    podman machine start podman-machine-default
    print_success "Podman machine started"
    sleep 5
else
    print_success "Podman machine is running"
fi

# Step 2: Start PostgreSQL if not running
print_info "Checking PostgreSQL container..."
PG_RUNNING=$(podman ps --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

if [ "$PG_RUNNING" -eq 0 ]; then
    print_info "Starting PostgreSQL..."
    podman start nexus-postgres-dev
    sleep 5

    # Wait for PostgreSQL to be ready
    MAX_RETRIES=15
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if podman exec nexus-postgres-dev pg_isready -U postgres >/dev/null 2>&1; then
            print_success "PostgreSQL is ready"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -n "."
        sleep 2
    done
    echo ""

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "PostgreSQL did not become ready"
        exit 1
    fi
else
    print_success "PostgreSQL is already running"
fi

# Step 3: Change PostgreSQL password
print_info "Changing PostgreSQL admin password to 'secret'..."

podman exec nexus-postgres-dev psql -U admin -d postgres -c "ALTER USER admin WITH PASSWORD '${NEW_PASSWORD}';" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "PostgreSQL password changed successfully"
else
    print_error "Failed to change PostgreSQL password"
    print_warning "Trying with postgres superuser..."
    podman exec nexus-postgres-dev psql -U postgres -d postgres -c "ALTER USER admin WITH PASSWORD '${NEW_PASSWORD}';" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        print_success "PostgreSQL password changed successfully (via postgres user)"
    else
        print_error "Failed to change password. Manual intervention required."
        exit 1
    fi
fi

# Step 4: Stop and remove Keycloak container
print_info "Stopping Keycloak container..."
KC_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$KC_RUNNING" -gt 0 ]; then
    podman stop nexus-keycloak-dev
    print_success "Keycloak stopped"
fi

print_info "Removing Keycloak container (will recreate with new password)..."
podman rm nexus-keycloak-dev 2>/dev/null || print_warning "Container already removed"

# Step 5: Get PostgreSQL IP
print_info "Getting PostgreSQL IP address..."
PG_IP=$(podman inspect nexus-postgres-dev | jq -r '.[0].NetworkSettings.Networks.podman.IPAddress')
print_info "PostgreSQL IP: $PG_IP"

# Step 6: Recreate Keycloak with new password
print_info "Creating new Keycloak container with updated password..."

podman run -d \
  --name nexus-keycloak-dev \
  -p 8090:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=secret \
  -e KC_DB=postgres \
  -e KC_DB_URL="jdbc:postgresql://${PG_IP}:5432/keycloak_db" \
  -e KC_DB_USERNAME=admin \
  -e KC_DB_PASSWORD="${NEW_PASSWORD}" \
  -e KC_HOSTNAME_STRICT=false \
  -e KC_HTTP_ENABLED=true \
  quay.io/keycloak/keycloak:latest \
  start-dev

print_success "Keycloak container created with new password configuration"

# Step 7: Wait for Keycloak to start
print_info "Waiting for Keycloak to initialize (this may take 30-60 seconds)..."
sleep 10

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
    print_info "Check logs with: podman logs nexus-keycloak-dev"
    exit 1
fi

# Step 8: Verify database connection
print_info "Verifying Keycloak database connection..."
sleep 5

# Check if Keycloak is responding
REALM_CHECK=$(curl -s http://localhost:8090/realms/hrms-saas 2>/dev/null | jq -r '.realm' 2>/dev/null || echo "error")

if [ "$REALM_CHECK" == "hrms-saas" ]; then
    print_success "Keycloak realm is accessible - database connection confirmed!"
else
    print_warning "Realm check failed - Keycloak may still be initializing"
fi

# Display summary
echo ""
echo "========================================================"
echo "  Password Change Summary"
echo "========================================================"
echo ""
print_success "PostgreSQL admin password: admin → secret"
print_success "Keycloak container recreated with new credentials"
echo ""
echo "Connection Details:"
echo "  • PostgreSQL Host: ${PG_IP}:5432"
echo "  • PostgreSQL User: admin"
echo "  • PostgreSQL Password: secret"
echo "  • Database: keycloak_db"
echo ""
echo "  • Keycloak URL: http://localhost:8090"
echo "  • Keycloak Admin: admin"
echo "  • Keycloak Admin Password: secret"
echo "  • Realm: hrms-saas"
echo ""
echo "Access Points:"
echo "  • Admin Console: http://localhost:8090/admin"
echo "  • Credentials: admin/secret"
echo ""
print_success "Password change completed successfully!"
echo ""
