#!/bin/bash

# Get token
TOKEN=$(curl -s -X POST "http://localhost:8090/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=secret" | jq -r '.access_token')

# Update user with attributes - using ONLY attributes in payload
curl -X PUT "http://localhost:8090/admin/realms/hrms-saas/users/1519cc02-5c46-441b-8962-8189992c1725" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "ramesh.babu@systech.com",
    "email": "ramesh.babu@systech.com",
    "firstName": "Ramesh",
    "lastName": "Babu",
    "enabled": true,
    "emailVerified": true,
    "attributes": {
      "tenant_id": ["a1lrqfv7lj7h"],
      "company_id": ["a1lrqfv7lj7h"],
      "user_type": ["company_admin"],
      "company_name": ["Systech"],
      "company_code": ["SYST001"],
      "phone": ["+91-9876543210"]
    }
  }'

echo ""
echo "Waiting 2 seconds..."
sleep 2

# Verify
echo "Verifying..."
TOKEN2=$(curl -s -X POST "http://localhost:8090/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=secret" | jq -r '.access_token')

curl -s -X GET "http://localhost:8090/admin/realms/hrms-saas/users/1519cc02-5c46-441b-8962-8189992c1725" \
  -H "Authorization: Bearer $TOKEN2" | jq '.attributes'
