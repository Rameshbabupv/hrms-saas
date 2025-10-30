#!/bin/bash

# Quick fix script to add attributes to existing users

source ../config/keycloak-config.env

ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=${KEYCLOAK_ADMIN_USERNAME}&password=${KEYCLOAK_ADMIN_PASSWORD}" | jq -r '.access_token')

# Get user ID for employee
USER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?username=john.doe@testcompany.com&exact=true" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

echo "Employee User ID: $USER_ID"

# Get current user and update with attributes
curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | \
    jq '. + {attributes: {"company_id": ["550e8400-e29b-41d4-a716-446655440000"], "tenant_id": ["550e8400-e29b-41d4-a716-446655440000"], "employee_id": ["660e8400-e29b-41d4-a716-446655440001"], "user_type": ["employee"], "company_code": ["TEST001"], "company_name": ["Test Company Ltd"], "phone": ["+91-9876543210"]}}' > /tmp/employee_update.json

curl -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/employee_update.json

echo "Employee attributes updated"

# Get user ID for admin
ADMIN_USER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?username=admin@testcompany.com&exact=true" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

echo "Admin User ID: $ADMIN_USER_ID"

# Get current user and update with attributes
curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${ADMIN_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | \
    jq '. + {attributes: {"company_id": ["550e8400-e29b-41d4-a716-446655440000"], "tenant_id": ["550e8400-e29b-41d4-a716-446655440000"], "user_type": ["company_admin"], "company_code": ["TEST001"], "company_name": ["Test Company Ltd"]}}' > /tmp/admin_update.json

curl -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${ADMIN_USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/admin_update.json

echo "Admin attributes updated"

echo ""
echo "Verifying employee attributes..."
curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq '{username, email, attributes}'
