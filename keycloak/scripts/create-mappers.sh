#!/bin/bash

################################################################################
# Create Custom JWT Mappers for HRMS SaaS
#
# This script creates 7 custom protocol mappers for multi-tenant JWT claims
#
# Usage: ./create-mappers.sh
################################################################################

set -e

# Colors
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
    KEYCLOAK_URL="http://localhost:8090"
    KEYCLOAK_REALM="hrms-saas"
    KEYCLOAK_ADMIN_USERNAME="admin"
    KEYCLOAK_ADMIN_PASSWORD="secret"
    KEYCLOAK_CLIENT_ID="hrms-web-app"
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
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

# Get client UUID
get_client_uuid() {
    print_info "Getting client UUID..."
    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${KEYCLOAK_CLIENT_ID}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

    if [ "$CLIENT_UUID" == "null" ] || [ -z "$CLIENT_UUID" ]; then
        print_error "Failed to get client UUID"
        exit 1
    fi
    print_success "Client UUID: ${CLIENT_UUID}"
}

# Create a single mapper
create_mapper() {
    local mapper_name=$1
    local claim_name=$2

    print_info "Creating mapper: ${mapper_name}"

    MAPPER_CONFIG='{
        "name": "'${mapper_name}'",
        "protocol": "openid-connect",
        "protocolMapper": "oidc-usermodel-attribute-mapper",
        "config": {
            "user.attribute": "'${claim_name}'",
            "claim.name": "'${claim_name}'",
            "jsonType.label": "String",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "userinfo.token.claim": "true"
        }
    }'

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_UUID}/protocol-mappers/models" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${MAPPER_CONFIG}")

    if [ "$HTTP_CODE" == "201" ]; then
        print_success "Mapper '${mapper_name}' created"
        return 0
    elif [ "$HTTP_CODE" == "409" ]; then
        print_warning "Mapper '${mapper_name}' already exists"
        return 0
    else
        print_error "Failed to create mapper '${mapper_name}'. HTTP Code: ${HTTP_CODE}"
        return 1
    fi
}

# Main
main() {
    echo ""
    echo "=================================="
    echo "  Create Custom JWT Mappers"
    echo "=================================="
    echo ""

    get_admin_token
    get_client_uuid

    echo ""
    print_info "Creating 7 custom mappers..."
    echo ""

    # Create all mappers
    create_mapper "company_id" "company_id"
    create_mapper "tenant_id" "tenant_id"
    create_mapper "employee_id" "employee_id"
    create_mapper "user_type" "user_type"
    create_mapper "company_code" "company_code"
    create_mapper "company_name" "company_name"
    create_mapper "phone" "phone"

    echo ""
    echo "=================================="
    echo "  Mappers Created Successfully!"
    echo "=================================="
    echo ""
    print_success "All 7 custom JWT mappers have been configured"
    echo ""
}

main
