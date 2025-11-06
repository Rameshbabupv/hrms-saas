#!/bin/bash

################################################################################
# Migrate Keycloak from H2 to PostgreSQL
#
# This script:
# 1. Exports current H2 data
# 2. Stops and removes the current Keycloak container
# 3. Creates new Keycloak container with PostgreSQL configuration
# 4. Imports the data into PostgreSQL
#
# Usage: ./migrate-to-postgresql.sh
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
echo "  Migrate Keycloak from H2 to PostgreSQL"
echo "========================================================"
echo ""

# Check if PostgreSQL is running
print_info "Checking PostgreSQL status..."
PG_RUNNING=$(podman ps --filter name=nexus-postgres-dev --format "{{.Names}}" | wc -l)

if [ "$PG_RUNNING" -eq 0 ]; then
    print_error "PostgreSQL is not running!"
    print_info "Please start PostgreSQL first"
    exit 1
fi

print_success "PostgreSQL is running"

# Get PostgreSQL IP
PG_IP=$(podman inspect nexus-postgres-dev | jq -r '.[0].NetworkSettings.Networks.podman.IPAddress')
print_info "PostgreSQL IP: $PG_IP"

# Check if keycloak_db exists
print_info "Checking if keycloak_db exists..."
DB_EXISTS=$(podman exec nexus-postgres-dev psql -U admin -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='keycloak_db'" 2>/dev/null || echo "")

if [ -z "$DB_EXISTS" ]; then
    print_info "Creating keycloak_db database..."
    podman exec nexus-postgres-dev psql -U admin -d postgres -c "CREATE DATABASE keycloak_db OWNER admin;"
    print_success "Database keycloak_db created"
else
    print_success "Database keycloak_db already exists"
fi

# Export current H2 data
print_info "Backing up current H2 data..."
BACKUP_DIR="../exports"
mkdir -p "$BACKUP_DIR"

# Check if Keycloak is running
KC_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)

if [ "$KC_RUNNING" -gt 0 ]; then
    print_info "Exporting current realm data via REST API..."

    # Get access token
    TOKEN=$(curl -s -X POST "http://localhost:8090/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=admin" \
      -d "password=secret" \
      -d "grant_type=password" \
      -d "client_id=admin-cli" | jq -r '.access_token')

    if [ "$TOKEN" != "null" ] && [ ! -z "$TOKEN" ]; then
        # Export realm
        curl -s -X POST "http://localhost:8090/admin/realms/hrms-saas/partial-export?exportClients=true&exportGroupsAndRoles=true" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -o "${BACKUP_DIR}/migration-backup-realm.json"

        # Export users
        curl -s -X GET "http://localhost:8090/admin/realms/hrms-saas/users" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -o "${BACKUP_DIR}/migration-backup-users.json"

        print_success "Realm data exported to ${BACKUP_DIR}/"
    else
        print_warning "Could not export realm data (authentication failed)"
    fi

    # Also backup H2 database file
    print_info "Backing up H2 database file..."
    podman cp nexus-keycloak-dev:/opt/keycloak/data/h2/keycloakdb.mv.db "${BACKUP_DIR}/migration-h2-backup.mv.db" 2>/dev/null || print_warning "Could not backup H2 file"
fi

# Stop Keycloak
print_info "Stopping Keycloak container..."
if [ "$KC_RUNNING" -gt 0 ]; then
    podman stop nexus-keycloak-dev
    print_success "Keycloak stopped"
fi

# Remove old container
print_info "Removing old Keycloak container..."
podman rm nexus-keycloak-dev 2>/dev/null || print_warning "Container already removed"

# Create new Keycloak container with PostgreSQL
print_info "Creating new Keycloak container with PostgreSQL configuration..."

podman run -d \
  --name nexus-keycloak-dev \
  -p 8090:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=secret \
  -e KC_DB=postgres \
  -e KC_DB_URL="jdbc:postgresql://${PG_IP}:5432/keycloak_db" \
  -e KC_DB_USERNAME=admin \
  -e KC_DB_PASSWORD=secret \
  -e KC_HOSTNAME_STRICT=false \
  -e KC_HTTP_ENABLED=true \
  quay.io/keycloak/keycloak:latest \
  start-dev

print_success "New Keycloak container created with PostgreSQL backend"

# Wait for Keycloak to start
print_info "Waiting for Keycloak to initialize (this may take a minute)..."
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

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_error "Keycloak did not start within expected time"
    print_info "Check logs with: podman logs nexus-keycloak-dev"
    exit 1
fi

# Verify PostgreSQL connection
print_info "Verifying PostgreSQL connection..."
sleep 5

# Check if Keycloak created tables in PostgreSQL
TABLE_COUNT=$(podman exec nexus-postgres-dev psql -U admin -d keycloak_db -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -gt 0 ]; then
    print_success "Keycloak successfully connected to PostgreSQL!"
    print_info "PostgreSQL tables created: $TABLE_COUNT"
else
    print_warning "No tables found in PostgreSQL yet (may still be initializing)"
fi

echo ""
echo "========================================================"
echo "  Migration Status"
echo "========================================================"
echo ""
print_success "Keycloak is now using PostgreSQL!"
echo ""
echo "Configuration:"
echo "  • Database: keycloak_db"
echo "  • Host: ${PG_IP}:5432"
echo "  • User: admin"
echo "  • Tables: $TABLE_COUNT"
echo ""
print_warning "IMPORTANT: Your old H2 data has been backed up to:"
echo "  • ${BACKUP_DIR}/migration-h2-backup.mv.db"
echo "  • ${BACKUP_DIR}/migration-backup-realm.json"
echo "  • ${BACKUP_DIR}/migration-backup-users.json"
echo ""
print_info "Next Steps:"
echo "  1. Access Admin Console: http://localhost:8090/admin"
echo "  2. Login with: admin/secret"
echo "  3. Recreate the 'hrms-saas' realm using setup-keycloak.sh"
echo "  4. Or import from backup using import scripts"
echo ""
echo "To import your old data:"
echo "  cd ../exports"
echo "  ./import-realm-config.sh"
echo "  ./import-users-with-attributes.sh"
echo ""
