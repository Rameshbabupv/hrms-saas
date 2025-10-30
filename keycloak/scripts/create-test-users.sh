#!/bin/bash

################################################################################
# Create Test Users for HRMS SaaS Keycloak
#
# This script creates 2 test users:
# 1. Company Admin User
# 2. Regular Employee User
#
# Usage: ./create-test-users.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load configuration
CONFIG_FILE="../config/keycloak-config.env"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}[ERROR]${NC} Configuration file not found: ${CONFIG_FILE}"
    echo "Please run ./setup-keycloak.sh first"
    exit 1
fi

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get admin token
get_admin_token() {
    print_info "Getting admin access token..."
    ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        -d "username=${KEYCLOAK_ADMIN_USERNAME}" \
        -d "password=${KEYCLOAK_ADMIN_PASSWORD}" | jq -r '.access_token')

    if [ "$ADMIN_TOKEN" == "null" ] || [ -z "$ADMIN_TOKEN" ]; then
        print_error "Failed to get admin token"
        exit 1
    fi
    print_success "Admin token obtained"
}

# Generate UUIDs for test data
generate_test_uuids() {
    print_info "Generating test UUIDs..."
    COMPANY_UUID="550e8400-e29b-41d4-a716-446655440000"
    EMPLOYEE_UUID="660e8400-e29b-41d4-a716-446655440001"
    print_success "Test UUIDs generated"
}

# Delete user if exists
delete_user_if_exists() {
    local USERNAME=$1

    print_info "Checking if user ${USERNAME} exists..."

    USER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?username=${USERNAME}&exact=true" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

    if [ "$USER_ID" != "null" ] && [ -n "$USER_ID" ]; then
        print_info "Deleting existing user: ${USERNAME}"
        curl -s -X DELETE "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}"
        print_success "Existing user deleted"
        sleep 1
    fi
}

# Create user function
create_user() {
    local USERNAME=$1
    local EMAIL=$2
    local FIRST_NAME=$3
    local LAST_NAME=$4
    local PASSWORD=$5
    local USER_TYPE=$6
    local ROLE=$7
    local EMPLOYEE_ID=$8

    # Delete if exists
    delete_user_if_exists "$USERNAME"

    print_info "Creating user: ${USERNAME}"

    # Build attributes JSON
    if [ -z "$EMPLOYEE_ID" ]; then
        ATTRIBUTES='"company_id": ["'${COMPANY_UUID}'"], "tenant_id": ["'${COMPANY_UUID}'"], "user_type": ["'${USER_TYPE}'"], "company_code": ["TEST001"], "company_name": ["Test Company Ltd"]'
    else
        ATTRIBUTES='"company_id": ["'${COMPANY_UUID}'"], "tenant_id": ["'${COMPANY_UUID}'"], "employee_id": ["'${EMPLOYEE_ID}'"], "user_type": ["'${USER_TYPE}'"], "company_code": ["TEST001"], "company_name": ["Test Company Ltd"], "phone": ["+91-9876543210"]'
    fi

    USER_CONFIG='{"username": "'${USERNAME}'", "email": "'${EMAIL}'", "firstName": "'${FIRST_NAME}'", "lastName": "'${LAST_NAME}'", "enabled": true, "emailVerified": true, "attributes": {'${ATTRIBUTES}'}, "credentials": [{"type": "password", "value": "'${PASSWORD}'", "temporary": false}]}'

    RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -w "\n%{http_code}" \
        -d "${USER_CONFIG}")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" == "201" ]; then
        print_success "User '${USERNAME}' created successfully"

        # Get user ID and assign role
        USER_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?username=${USERNAME}&exact=true" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

        # Get role details
        ROLE_OBJ=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/roles/${ROLE}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}")

        # Assign role
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${USER_ID}/role-mappings/realm" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "[${ROLE_OBJ}]"

        print_success "Role '${ROLE}' assigned to user"
        return 0
    else
        print_error "Failed to create user '${USERNAME}'. HTTP Code: ${HTTP_CODE}"
        echo "$RESPONSE" | head -n-1
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "=================================="
    echo "  Create Test Users"
    echo "=================================="
    echo ""

    # Get admin token
    get_admin_token

    # Generate test UUIDs
    generate_test_uuids

    echo ""
    echo "Test Company Information:"
    echo "  Company UUID: ${COMPANY_UUID}"
    echo "  Company Code: TEST001"
    echo "  Company Name: Test Company Ltd"
    echo ""

    # Create Company Admin User
    echo "Creating Company Admin User..."
    create_user \
        "admin@testcompany.com" \
        "admin@testcompany.com" \
        "Admin" \
        "User" \
        "TestAdmin@123" \
        "company_admin" \
        "company_admin" \
        ""

    echo ""

    # Create Regular Employee User
    echo "Creating Regular Employee User..."
    create_user \
        "john.doe@testcompany.com" \
        "john.doe@testcompany.com" \
        "John" \
        "Doe" \
        "TestUser@123" \
        "employee" \
        "employee" \
        "${EMPLOYEE_UUID}"

    echo ""
    echo "=================================="
    echo "  Test Users Created!"
    echo "=================================="
    echo ""
    print_success "All test users created successfully"
    echo ""
    echo "Test User Credentials:"
    echo ""
    echo "1. Company Admin:"
    echo "   Username: admin@testcompany.com"
    echo "   Password: TestAdmin@123"
    echo "   Role: company_admin"
    echo "   Company ID: ${COMPANY_UUID}"
    echo ""
    echo "2. Employee:"
    echo "   Username: john.doe@testcompany.com"
    echo "   Password: TestUser@123"
    echo "   Role: employee"
    echo "   Company ID: ${COMPANY_UUID}"
    echo "   Employee ID: ${EMPLOYEE_UUID}"
    echo ""
    print_info "Next step: Test token generation with ./test-token.sh"
    echo ""

    # Save test user info
    TEST_USERS_FILE="../config/test-users.txt"
    cat > ${TEST_USERS_FILE} << EOF
# Test Users for HRMS SaaS Keycloak
# Generated: $(date)

Company Information:
  Company UUID: ${COMPANY_UUID}
  Company Code: TEST001
  Company Name: Test Company Ltd

Test User 1 - Company Admin:
  Username: admin@testcompany.com
  Password: TestAdmin@123
  Email: admin@testcompany.com
  Role: company_admin
  Company ID: ${COMPANY_UUID}

Test User 2 - Regular Employee:
  Username: john.doe@testcompany.com
  Password: TestUser@123
  Email: john.doe@testcompany.com
  Role: employee
  Company ID: ${COMPANY_UUID}
  Employee ID: ${EMPLOYEE_UUID}

Login Test Command:
curl -X POST "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \\
  -H "Content-Type: application/x-www-form-urlencoded" \\
  -d "grant_type=password" \\
  -d "client_id=${KEYCLOAK_CLIENT_ID}" \\
  -d "client_secret=${KEYCLOAK_CLIENT_SECRET}" \\
  -d "username=john.doe@testcompany.com" \\
  -d "password=TestUser@123"
EOF

    print_success "Test user information saved to: ${TEST_USERS_FILE}"
}

main
