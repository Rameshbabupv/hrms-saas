#!/bin/bash

# Fix user attributes by getting full user object and updating it

USER_EMAIL="ramesh.babu@systech.com"
TENANT_ID="a1lrqfv7lj7h"
USER_TYPE="company_admin"
COMPANY_NAME="Systech"
COMPANY_CODE="SYST001"

# Keycloak configuration
KEYCLOAK_URL="http://localhost:8090"
KEYCLOAK_REALM="hrms-saas"
KEYCLOAK_ADMIN_USERNAME="admin"
KEYCLOAK_ADMIN_PASSWORD="secret"

echo "Step 1: Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN_USERNAME}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" | jq -r '.access_token')

echo "✅ Token obtained"
echo ""

echo "Step 2: Finding user..."
USER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?email=${USER_EMAIL}&exact=true" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

echo "✅ User ID: $USER_ID"
echo ""

echo "Step 3: Getting complete user object..."
curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" > /tmp/user_full.json

echo "✅ User object retrieved"
echo ""

echo "Step 4: Adding attributes to user object..."
jq --arg tenant_id "$TENANT_ID" \
   --arg company_id "$TENANT_ID" \
   --arg user_type "$USER_TYPE" \
   --arg company_name "$COMPANY_NAME" \
   --arg company_code "$COMPANY_CODE" \
   '.attributes = {
     "tenant_id": [$tenant_id],
     "company_id": [$company_id],
     "user_type": [$user_type],
     "company_name": [$company_name],
     "company_code": [$company_code],
     "phone": ["+91-9876543210"]
   }' /tmp/user_full.json > /tmp/user_updated.json

echo "✅ Attributes added to JSON"
echo ""

echo "Step 5: Updating user in Keycloak..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/user_updated.json)

if [ "$HTTP_CODE" = "204" ]; then
    echo "✅ User updated successfully (HTTP $HTTP_CODE)"
else
    echo "❌ Failed to update user (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""

echo "Step 6: Verifying attributes..."
sleep 1

ATTRIBUTES=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq '.attributes')

echo ""
echo "=========================================="
echo "USER ATTRIBUTES"
echo "=========================================="
echo "$ATTRIBUTES" | jq '.'

if [ "$ATTRIBUTES" = "null" ] || [ "$ATTRIBUTES" = "{}" ]; then
    echo ""
    echo "❌ Attributes still missing!"
    echo "Debugging: Check /tmp/user_updated.json"
else
    echo ""
    echo "✅ SUCCESS! Attributes added:"
    echo "  - tenant_id: $TENANT_ID"
    echo "  - company_id: $TENANT_ID"
    echo "  - user_type: $USER_TYPE"
    echo "  - company_name: $COMPANY_NAME"
    echo "  - company_code: $COMPANY_CODE"
    echo ""
    echo "🎉 The user can now get JWT tokens with custom claims!"
fi

echo ""
echo "=========================================="
echo "Next: Test token generation"
echo "./test-token.sh $USER_EMAIL <password>"
echo "=========================================="

# Cleanup
# rm -f /tmp/user_full.json /tmp/user_updated.json
