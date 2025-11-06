#!/bin/bash

# Direct approach to add attributes to user

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

echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN_USERNAME}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" | jq -r '.access_token')

echo "Finding user..."
USER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?email=${USER_EMAIL}&exact=true" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

echo "User ID: $USER_ID"

# Create the update payload
cat > /tmp/user_attributes.json <<EOF
{
  "attributes": {
    "tenant_id": ["${TENANT_ID}"],
    "company_id": ["${TENANT_ID}"],
    "user_type": ["${USER_TYPE}"],
    "company_name": ["${COMPANY_NAME}"],
    "company_code": ["${COMPANY_CODE}"],
    "phone": ["+91-9876543210"]
  }
}
EOF

echo ""
echo "Payload to send:"
cat /tmp/user_attributes.json
echo ""

echo "Updating user attributes..."
curl -v -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/user_attributes.json

echo ""
echo ""
echo "Verifying..."
sleep 1
curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq '.attributes'
