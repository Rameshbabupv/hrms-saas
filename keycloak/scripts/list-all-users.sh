#!/bin/bash

# List all users in Keycloak realm

# Keycloak configuration
KEYCLOAK_URL="http://localhost:8090"
KEYCLOAK_REALM="hrms-saas"
KEYCLOAK_ADMIN_USERNAME="admin"
KEYCLOAK_ADMIN_PASSWORD="secret"

echo "=========================================="
echo "Listing All Users in Keycloak"
echo "=========================================="
echo "Realm: $KEYCLOAK_REALM"
echo ""

# Get admin token
echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN_USERNAME}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    echo "❌ Failed to get admin token"
    exit 1
fi

echo "✅ Admin token retrieved"
echo ""

# Get all users
echo "Fetching all users..."
echo ""

curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[] | "User: \(.username)\n  Email: \(.email)\n  Enabled: \(.enabled)\n  Email Verified: \(.emailVerified)\n  User ID: \(.id)\n"'

echo ""
echo "=========================================="
echo "To check specific user attributes, run:"
echo "./check-user-attributes.sh <email>"
echo "=========================================="
