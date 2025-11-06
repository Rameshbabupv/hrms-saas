#!/bin/bash

# Check user attributes in Keycloak
# Usage: ./check-user-attributes.sh email@example.com

if [ -z "$1" ]; then
    echo "Usage: $0 <email>"
    echo "Example: $0 babu@systech.com"
    exit 1
fi

USER_EMAIL="$1"

# Keycloak configuration
KEYCLOAK_URL="http://localhost:8090"
KEYCLOAK_REALM="hrms-saas"
KEYCLOAK_ADMIN_USERNAME="admin"
KEYCLOAK_ADMIN_PASSWORD="secret"

echo "=========================================="
echo "Checking User Attributes in Keycloak"
echo "=========================================="
echo "Email: $USER_EMAIL"
echo ""

# Get admin token
echo "Step 1: Getting admin token..."
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

# Get user ID
echo "Step 2: Finding user..."
USER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?email=${USER_EMAIL}&exact=true" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo "❌ User not found: $USER_EMAIL"
    exit 1
fi

echo "✅ User found"
echo "   User ID: $USER_ID"
echo ""

# Get user details
echo "Step 3: Fetching user details and attributes..."
echo ""

USER_DATA=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "=========================================="
echo "USER DETAILS"
echo "=========================================="
echo "$USER_DATA" | jq '{
    username: .username,
    email: .email,
    firstName: .firstName,
    lastName: .lastName,
    enabled: .enabled,
    emailVerified: .emailVerified
}'

echo ""
echo "=========================================="
echo "CURRENT ATTRIBUTES"
echo "=========================================="
ATTRIBUTES=$(echo "$USER_DATA" | jq -r '.attributes')

if [ "$ATTRIBUTES" = "null" ] || [ "$ATTRIBUTES" = "{}" ]; then
    echo "❌ NO ATTRIBUTES FOUND!"
    echo ""
    echo "This user is missing required attributes:"
    echo "  - tenant_id"
    echo "  - company_id"
    echo "  - user_type"
    echo "  - company_name"
    echo "  - company_code (optional)"
    echo "  - employee_id (optional)"
    echo "  - phone (optional)"
else
    echo "$ATTRIBUTES" | jq '.'
    echo ""

    # Check for required attributes
    echo "=========================================="
    echo "ATTRIBUTE VALIDATION"
    echo "=========================================="

    TENANT_ID=$(echo "$ATTRIBUTES" | jq -r '.tenant_id[0] // empty')
    COMPANY_ID=$(echo "$ATTRIBUTES" | jq -r '.company_id[0] // empty')
    USER_TYPE=$(echo "$ATTRIBUTES" | jq -r '.user_type[0] // empty')
    COMPANY_NAME=$(echo "$ATTRIBUTES" | jq -r '.company_name[0] // empty')

    if [ -z "$TENANT_ID" ]; then
        echo "❌ tenant_id: MISSING"
    else
        echo "✅ tenant_id: $TENANT_ID"
    fi

    if [ -z "$COMPANY_ID" ]; then
        echo "❌ company_id: MISSING"
    else
        echo "✅ company_id: $COMPANY_ID"
    fi

    if [ -z "$USER_TYPE" ]; then
        echo "❌ user_type: MISSING"
    else
        echo "✅ user_type: $USER_TYPE"
    fi

    if [ -z "$COMPANY_NAME" ]; then
        echo "❌ company_name: MISSING"
    else
        echo "✅ company_name: $COMPANY_NAME"
    fi
fi

echo ""
echo "=========================================="
echo "To fix missing attributes, run:"
echo "./fix-user-attributes-manual.sh $USER_EMAIL"
echo "=========================================="
