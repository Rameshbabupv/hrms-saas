#!/bin/bash

# Fix user attributes - add required attributes to existing users
# Usage: ./fix-user-attributes-manual.sh email@example.com

if [ -z "$1" ]; then
    echo "Usage: $0 <email> [tenant_id] [user_type] [company_name]"
    echo "Example: $0 ramesh.babu@systech.com a1lrqfv7lj7h company_admin Systech"
    echo ""
    echo "If tenant_id not provided, will generate a new 12-char NanoID-like ID"
    echo "If user_type not provided, defaults to 'company_admin'"
    echo "If company_name not provided, extracts from email domain"
    exit 1
fi

USER_EMAIL="$1"
TENANT_ID="${2:-$(echo $RANDOM$RANDOM$RANDOM | md5sum | cut -c1-12)}"  # Generate random 12-char ID if not provided
USER_TYPE="${3:-company_admin}"
COMPANY_NAME="${4:-$(echo $USER_EMAIL | cut -d'@' -f2 | cut -d'.' -f1 | sed 's/\b\(.\)/\u\1/g')}"  # Extract from email

# Keycloak configuration
KEYCLOAK_URL="http://localhost:8090"
KEYCLOAK_REALM="hrms-saas"
KEYCLOAK_ADMIN_USERNAME="admin"
KEYCLOAK_ADMIN_PASSWORD="secret"

echo "=========================================="
echo "Adding Attributes to User"
echo "=========================================="
echo "Email:        $USER_EMAIL"
echo "Tenant ID:    $TENANT_ID"
echo "User Type:    $USER_TYPE"
echo "Company Name: $COMPANY_NAME"
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

echo "✅ User found: $USER_ID"
echo ""

# Get current user data
echo "Step 3: Fetching current user data..."
USER_DATA=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "✅ User data retrieved"
echo ""

# Add attributes
echo "Step 4: Adding attributes..."

UPDATED_USER=$(echo "$USER_DATA" | jq ". + {
    attributes: {
        tenant_id: [\"${TENANT_ID}\"],
        company_id: [\"${TENANT_ID}\"],
        user_type: [\"${USER_TYPE}\"],
        company_name: [\"${COMPANY_NAME}\"],
        company_code: [\"$(echo ${COMPANY_NAME} | tr '[:lower:]' '[:upper:]' | head -c 4)001\"],
        phone: [\"+91-9876543210\"]
    }
}")

# Save to temp file
echo "$UPDATED_USER" > /tmp/user_update_${USER_ID}.json

# Update user
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/user_update_${USER_ID}.json)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Attributes added successfully!"
else
    echo "❌ Failed to update user (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""

# Verify attributes
echo "Step 5: Verifying attributes..."
echo ""

VERIFICATION=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "=========================================="
echo "UPDATED USER ATTRIBUTES"
echo "=========================================="
echo "$VERIFICATION" | jq -r '.attributes'

echo ""
echo "=========================================="
echo "✅ SUCCESS!"
echo "=========================================="
echo ""
echo "The user now has the following attributes:"
echo "  ✅ tenant_id: $TENANT_ID"
echo "  ✅ company_id: $TENANT_ID"
echo "  ✅ user_type: $USER_TYPE"
echo "  ✅ company_name: $COMPANY_NAME"
echo ""
echo "These will now appear in JWT tokens when the user logs in."
echo ""
echo "Next steps:"
echo "1. Test token generation:"
echo "   ./test-token.sh $USER_EMAIL <password>"
echo ""
echo "2. Or decode a new token to verify claims"
echo "=========================================="

# Cleanup
rm -f /tmp/user_update_${USER_ID}.json
