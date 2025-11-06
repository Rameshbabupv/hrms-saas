#!/bin/bash

# Fix attributes for ramesh.babu@systech.com user specifically

# Keycloak configuration
KEYCLOAK_URL="http://localhost:8090"
KEYCLOAK_REALM="hrms-saas"
KEYCLOAK_ADMIN_USERNAME="admin"
KEYCLOAK_ADMIN_PASSWORD="secret"

# User details
USER_ID="1519cc02-5c46-441b-8962-8189992c1725"  # From previous listing
TENANT_ID="a1lrqfv7lj7h"
USER_TYPE="company_admin"
COMPANY_NAME="Systech"
COMPANY_CODE="SYST001"

echo "=========================================="
echo "Fixing Attributes for ramesh.babu@systech.com"
echo "=========================================="
echo "User ID: $USER_ID"
echo "Tenant ID: $TENANT_ID"
echo ""

echo "Step 1: Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN_USERNAME}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" | jq -r '.access_token')

echo "✅ Token obtained"
echo ""

echo "Step 2: Getting complete user object..."
curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" > /tmp/ramesh_user.json

echo "✅ User object retrieved"
cat /tmp/ramesh_user.json | jq '{username, email, firstName, lastName}'
echo ""

echo "Step 3: Adding attributes..."
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
   }' /tmp/ramesh_user.json > /tmp/ramesh_updated.json

echo "✅ Attributes prepared"
echo ""
echo "Attributes to add:"
cat /tmp/ramesh_updated.json | jq '.attributes'
echo ""

echo "Step 4: Updating user in Keycloak..."
HTTP_CODE=$(curl -s -o /tmp/update_response.txt -w "%{http_code}" -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/ramesh_updated.json)

echo "HTTP Response Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "204" ]; then
    echo "✅ User updated successfully"
elif [ "$HTTP_CODE" = "200" ]; then
    echo "✅ User updated successfully"
else
    echo "❌ Failed to update (HTTP $HTTP_CODE)"
    echo "Response:"
    cat /tmp/update_response.txt
    exit 1
fi

echo ""

echo "Step 5: Verifying attributes..."
sleep 2

echo ""
echo "=========================================="
echo "FINAL VERIFICATION"
echo "=========================================="

curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq '{
    username,
    email,
    attributes
}'

echo ""
echo "=========================================="
echo "✅ DONE!"
echo "=========================================="
echo "If attributes appear above, the user is ready."
echo ""
echo "Test with:"
echo "  cd ../keycloak/scripts"
echo "  ./test-token.sh ramesh.babu@systech.com <password>"
echo "=========================================="
