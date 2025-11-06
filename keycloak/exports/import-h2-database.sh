#!/bin/bash

################################################################################
# Import H2 Database Backup - Complete Keycloak Restore
#
# This script restores the complete Keycloak H2 database including:
# - All realm configurations
# - All users with passwords (hashed)
# - All custom attributes
# - All roles, clients, and settings
#
# Usage: ./import-h2-database.sh
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
echo "  Keycloak H2 Database Restore"
echo "========================================"
echo ""

# Check if backup file exists
if [ ! -f "keycloakdb-backup.mv.db" ]; then
    print_error "Backup file 'keycloakdb-backup.mv.db' not found!"
    print_info "Make sure you're running this script from the exports directory"
    exit 1
fi

print_info "Found backup file: keycloakdb-backup.mv.db ($(du -h keycloakdb-backup.mv.db | cut -f1))"

# Check if Keycloak container exists
CONTAINER_EXISTS=$(podman ps -a --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)
if [ "$CONTAINER_EXISTS" -eq 0 ]; then
    print_error "Keycloak container 'nexus-keycloak-dev' not found!"
    exit 1
fi

# Check if Keycloak is running
CONTAINER_RUNNING=$(podman ps --filter name=nexus-keycloak-dev --format "{{.Names}}" | wc -l)
if [ "$CONTAINER_RUNNING" -gt 0 ]; then
    print_warning "Keycloak is running. Stopping it now..."
    podman stop nexus-keycloak-dev
    sleep 2
    print_success "Keycloak stopped"
fi

# Backup current database
print_info "Backing up current database..."
BACKUP_NAME="keycloakdb-old-$(date +%Y%m%d-%H%M%S).mv.db"
podman cp nexus-keycloak-dev:/opt/keycloak/data/h2/keycloakdb.mv.db "./${BACKUP_NAME}" 2>/dev/null || {
    print_warning "Could not backup current database (it may not exist)"
}

if [ -f "./${BACKUP_NAME}" ]; then
    print_success "Current database backed up to: ${BACKUP_NAME}"
fi

# Restore from backup
print_info "Restoring database from backup..."
podman cp keycloakdb-backup.mv.db nexus-keycloak-dev:/opt/keycloak/data/h2/keycloakdb.mv.db

if [ $? -eq 0 ]; then
    print_success "Database restored successfully!"
else
    print_error "Failed to restore database"
    exit 1
fi

# Start Keycloak
print_info "Starting Keycloak..."
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
    print_info "Check logs with: podman logs nexus-keycloak-dev"
    exit 1
fi

echo ""
echo "========================================"
echo "  Restore Complete!"
echo "========================================"
echo ""
print_success "H2 database has been restored successfully"
echo ""
echo "Access Information:"
echo "  • Admin Console: http://localhost:8090/admin"
echo "  • Realm: hrms-saas"
echo "  • Credentials: admin/secret"
echo ""
echo "All users, passwords, and configurations have been restored!"
echo ""
