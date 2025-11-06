#!/bin/bash

################################################################################
# Export Complete Keycloak Configuration
#
# This script exports:
# - Realm configuration (clients, roles, mappers)
# - Users with attributes
#
# Usage: ./export-keycloak-complete.sh
################################################################################

set -e

KEYCLOAK_URL="http://localhost:8090"
REALM_NAME="hrms-saas"
EXPORT_DIR="../exports"
DATE=$(date +%Y%m%d_%H%M%S)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "================================================"
echo "  Keycloak Configuration Export"
echo "================================================"
echo ""

# Check if Keycloak is running
if ! curl -s http://localhost:8090/ > /dev/null 2>&1; then
    echo -e "${RED}❌ Keycloak is not running!${NC}"
    echo "   Start with: ./start-keycloak.sh"
    exit 1
fi

echo -e "${BLUE}✓ Keycloak is running${NC}"

# Create export directory
mkdir -p $EXPORT_DIR

# Get admin access token
echo "🔑 Getting admin access token..."
TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=secret" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Failed to get access token${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Access token obtained${NC}"

# Export realm configuration
echo "📤 Exporting realm configuration..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/partial-export?exportClients=true&exportGroupsAndRoles=true" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -o "$EXPORT_DIR/${REALM_NAME}-realm-${DATE}.json"

echo -e "${GREEN}✓ Realm exported: ${REALM_NAME}-realm-${DATE}.json${NC}"

# Export all users
echo "📤 Exporting users..."
curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -o "$EXPORT_DIR/${REALM_NAME}-users-${DATE}.json"

echo -e "${GREEN}✓ Users exported: ${REALM_NAME}-users-${DATE}.json${NC}"

# Create latest symlinks
cd $EXPORT_DIR
ln -sf "${REALM_NAME}-realm-${DATE}.json" "${REALM_NAME}-realm-latest.json"
ln -sf "${REALM_NAME}-users-${DATE}.json" "${REALM_NAME}-users-latest.json"
cd - > /dev/null

# Summary
echo ""
echo "================================================"
echo "  Export Summary"
echo "================================================"
echo "  Export Directory: $EXPORT_DIR"
echo ""
echo "  Files Created:"
ls -lh "$EXPORT_DIR/${REALM_NAME}-"*"${DATE}.json" | awk '{print "    " $9 " (" $5 ")"}'
echo ""
echo -e "${GREEN}✅ Export completed successfully!${NC}"
echo ""
