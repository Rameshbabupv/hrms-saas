#!/bin/bash

################################################################################
# Keycloak Automated Setup Script for HRMS SaaS
#
# This script configures:
# - hrms-saas realm
# - hrms-web-app client
# - Custom JWT mappers for multi-tenancy
# - 5 realm roles
# - Security settings
#
# Usage: ./setup-keycloak.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KEYCLOAK_URL="http://localhost:8090"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="secret"
REALM_NAME="hrms-saas"
CLIENT_ID="hrms-web-app"

# Function to print colored output
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

# Function to get admin access token
get_admin_token() {
    print_info "Getting admin access token..."
    ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        -d "username=${ADMIN_USERNAME}" \
        -d "password=${ADMIN_PASSWORD}" | jq -r '.access_token')

    if [ "$ADMIN_TOKEN" == "null" ] || [ -z "$ADMIN_TOKEN" ]; then
        print_error "Failed to get admin token. Check credentials."
        exit 1
    fi
    print_success "Admin token obtained"
}

# Function to check if realm exists
check_realm_exists() {
    print_info "Checking if realm '${REALM_NAME}' exists..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")

    if [ "$HTTP_CODE" == "200" ]; then
        print_warning "Realm '${REALM_NAME}' already exists"
        return 0
    else
        print_info "Realm '${REALM_NAME}' does not exist"
        return 1
    fi
}

# Function to create realm
create_realm() {
    print_info "Creating realm '${REALM_NAME}'..."

    REALM_CONFIG='{
        "realm": "'${REALM_NAME}'",
        "enabled": true,
        "displayName": "HRMS SaaS Platform",
        "displayNameHtml": "<strong>HRMS</strong> SaaS Platform",
        "registrationAllowed": false,
        "registrationEmailAsUsername": false,
        "editUsernameAllowed": false,
        "resetPasswordAllowed": true,
        "rememberMe": true,
        "verifyEmail": true,
        "loginWithEmailAllowed": true,
        "duplicateEmailsAllowed": false,
        "sslRequired": "external",
        "accessTokenLifespan": 1800,
        "accessTokenLifespanForImplicitFlow": 900,
        "ssoSessionIdleTimeout": 3600,
        "ssoSessionMaxLifespan": 36000,
        "ssoSessionIdleTimeoutRememberMe": 604800,
        "ssoSessionMaxLifespanRememberMe": 2592000,
        "offlineSessionIdleTimeout": 2592000,
        "offlineSessionMaxLifespan": 5184000,
        "clientSessionIdleTimeout": 3600,
        "clientSessionMaxLifespan": 36000,
        "bruteForceProtected": true,
        "permanentLockout": false,
        "maxFailureWaitSeconds": 900,
        "minimumQuickLoginWaitSeconds": 60,
        "waitIncrementSeconds": 60,
        "quickLoginCheckMilliSeconds": 1000,
        "maxDeltaTimeSeconds": 43200,
        "failureFactor": 5
    }'

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${KEYCLOAK_URL}/admin/realms" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${REALM_CONFIG}")

    if [ "$HTTP_CODE" == "201" ]; then
        print_success "Realm '${REALM_NAME}' created successfully"
        return 0
    else
        print_error "Failed to create realm. HTTP Code: ${HTTP_CODE}"
        return 1
    fi
}

# Function to create realm roles
create_realm_roles() {
    print_info "Creating realm roles..."

    ROLES=("super_admin" "company_admin" "hr_user" "manager" "employee")
    DESCRIPTIONS=(
        "Super administrator with access to all tenants and system settings"
        "Company administrator with full access to their tenant"
        "HR user with access to employee management within their tenant"
        "Manager with access to their team's data"
        "Regular employee with access to their own data"
    )

    for i in "${!ROLES[@]}"; do
        ROLE_NAME="${ROLES[$i]}"
        ROLE_DESC="${DESCRIPTIONS[$i]}"

        print_info "Creating role: ${ROLE_NAME}"

        ROLE_CONFIG='{
            "name": "'${ROLE_NAME}'",
            "description": "'${ROLE_DESC}'",
            "composite": false,
            "clientRole": false
        }'

        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${ROLE_CONFIG}")

        if [ "$HTTP_CODE" == "201" ]; then
            print_success "Role '${ROLE_NAME}' created"
        elif [ "$HTTP_CODE" == "409" ]; then
            print_warning "Role '${ROLE_NAME}' already exists"
        else
            print_error "Failed to create role '${ROLE_NAME}'. HTTP Code: ${HTTP_CODE}"
        fi
    done

    # Set employee as default role
    print_info "Setting 'employee' as default role..."

    # Get the employee role
    EMPLOYEE_ROLE=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles/employee" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")

    ROLE_ID=$(echo $EMPLOYEE_ROLE | jq -r '.id')

    if [ "$ROLE_ID" != "null" ]; then
        # Add to default roles
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles-by-id/${ROLE_ID}/composites" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '[]' > /dev/null

        print_success "Default roles configured"
    fi
}

# Function to create client
create_client() {
    print_info "Creating client '${CLIENT_ID}'..."

    CLIENT_CONFIG='{
        "clientId": "'${CLIENT_ID}'",
        "name": "HRMS Web Application",
        "description": "Main web application for HRMS SaaS platform",
        "enabled": true,
        "clientAuthenticatorType": "client-secret",
        "redirectUris": [
            "https://hrms.yourdomain.com/*",
            "http://localhost:3000/*",
            "http://localhost:3001/*"
        ],
        "webOrigins": [
            "https://hrms.yourdomain.com",
            "http://localhost:3000",
            "http://localhost:3001",
            "+"
        ],
        "publicClient": false,
        "protocol": "openid-connect",
        "standardFlowEnabled": true,
        "implicitFlowEnabled": false,
        "directAccessGrantsEnabled": true,
        "serviceAccountsEnabled": false,
        "authorizationServicesEnabled": false,
        "fullScopeAllowed": true,
        "attributes": {
            "access.token.lifespan": "1800",
            "pkce.code.challenge.method": "S256"
        }
    }'

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${CLIENT_CONFIG}")

    if [ "$HTTP_CODE" == "201" ]; then
        print_success "Client '${CLIENT_ID}' created successfully"
        return 0
    elif [ "$HTTP_CODE" == "409" ]; then
        print_warning "Client '${CLIENT_ID}' already exists"
        return 0
    else
        print_error "Failed to create client. HTTP Code: ${HTTP_CODE}"
        return 1
    fi
}

# Function to get client UUID
get_client_uuid() {
    print_info "Getting client UUID..."
    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

    if [ "$CLIENT_UUID" == "null" ] || [ -z "$CLIENT_UUID" ]; then
        print_error "Failed to get client UUID"
        exit 1
    fi
    print_success "Client UUID: ${CLIENT_UUID}"
}

# Function to get client secret
get_client_secret() {
    print_info "Getting client secret..."
    CLIENT_SECRET=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')

    if [ "$CLIENT_SECRET" == "null" ] || [ -z "$CLIENT_SECRET" ]; then
        print_error "Failed to get client secret"
        exit 1
    fi
    print_success "Client secret obtained (will be displayed at the end)"
}

# Function to create protocol mappers
create_protocol_mappers() {
    print_info "Creating custom protocol mappers..."

    # Get dedicated scope
    DEDICATED_SCOPE=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/client-scopes" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[] | select(.name=="'${CLIENT_ID}'-dedicated") | .id')

    if [ "$DEDICATED_SCOPE" == "null" ] || [ -z "$DEDICATED_SCOPE" ]; then
        print_warning "Dedicated scope not found, using client directly"
        MAPPER_ENDPOINT="${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/protocol-mappers/models"
    else
        print_info "Using dedicated scope: ${DEDICATED_SCOPE}"
        MAPPER_ENDPOINT="${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/client-scopes/${DEDICATED_SCOPE}/protocol-mappers/models"
    fi

    # Define mappers
    declare -A MAPPERS=(
        ["company_id"]="company_id"
        ["tenant_id"]="tenant_id"
        ["employee_id"]="employee_id"
        ["user_type"]="user_type"
        ["company_code"]="company_code"
        ["company_name"]="company_name"
        ["phone"]="phone"
    )

    for MAPPER_NAME in "${!MAPPERS[@]}"; do
        CLAIM_NAME="${MAPPERS[$MAPPER_NAME]}"

        print_info "Creating mapper: ${MAPPER_NAME}"

        MAPPER_CONFIG='{
            "name": "'${MAPPER_NAME}'",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-attribute-mapper",
            "config": {
                "user.attribute": "'${CLAIM_NAME}'",
                "claim.name": "'${CLAIM_NAME}'",
                "jsonType.label": "String",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "userinfo.token.claim": "true"
            }
        }'

        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "${MAPPER_ENDPOINT}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${MAPPER_CONFIG}")

        if [ "$HTTP_CODE" == "201" ]; then
            print_success "Mapper '${MAPPER_NAME}' created"
        elif [ "$HTTP_CODE" == "409" ]; then
            print_warning "Mapper '${MAPPER_NAME}' already exists"
        else
            print_error "Failed to create mapper '${MAPPER_NAME}'. HTTP Code: ${HTTP_CODE}"
        fi
    done
}

# Main execution
main() {
    echo ""
    echo "=================================="
    echo "  Keycloak HRMS SaaS Setup Script"
    echo "=================================="
    echo ""

    # Get admin token
    get_admin_token

    # Check if realm exists
    if check_realm_exists; then
        print_warning "Realm already exists. Skipping realm creation."
        print_info "Proceeding with client and mapper configuration..."
    else
        # Create realm
        create_realm || exit 1
    fi

    # Create roles
    create_realm_roles

    # Create client
    create_client

    # Get client UUID
    get_client_uuid

    # Get client secret
    get_client_secret

    # Create protocol mappers
    create_protocol_mappers

    echo ""
    echo "=================================="
    echo "  Setup Complete!"
    echo "=================================="
    echo ""
    print_success "Keycloak configuration completed successfully"
    echo ""
    echo "Realm Information:"
    echo "  Realm Name: ${REALM_NAME}"
    echo "  Keycloak URL: ${KEYCLOAK_URL}"
    echo "  Admin Console: ${KEYCLOAK_URL}/admin"
    echo ""
    echo "Client Information:"
    echo "  Client ID: ${CLIENT_ID}"
    echo "  Client UUID: ${CLIENT_UUID}"
    echo "  Client Secret: ${CLIENT_SECRET}"
    echo ""
    echo "Realm Roles Created:"
    echo "  - super_admin"
    echo "  - company_admin"
    echo "  - hr_user"
    echo "  - manager"
    echo "  - employee"
    echo ""
    echo "Custom JWT Mappers Created:"
    echo "  - company_id"
    echo "  - tenant_id"
    echo "  - employee_id"
    echo "  - user_type"
    echo "  - company_code"
    echo "  - company_name"
    echo "  - phone"
    echo ""
    print_info "Next steps:"
    echo "  1. Create test users: ./create-test-users.sh"
    echo "  2. Test token generation: ./test-token.sh"
    echo "  3. Review configuration in admin console: ${KEYCLOAK_URL}/admin"
    echo ""

    # Save configuration to file
    CONFIG_FILE="../config/keycloak-config.env"
    mkdir -p ../config
    cat > ${CONFIG_FILE} << EOF
# Keycloak Configuration for HRMS SaaS
# Generated: $(date)

KEYCLOAK_URL=${KEYCLOAK_URL}
KEYCLOAK_REALM=${REALM_NAME}
KEYCLOAK_CLIENT_ID=${CLIENT_ID}
KEYCLOAK_CLIENT_SECRET=${CLIENT_SECRET}
KEYCLOAK_CLIENT_UUID=${CLIENT_UUID}
KEYCLOAK_ADMIN_USERNAME=${ADMIN_USERNAME}
KEYCLOAK_ADMIN_PASSWORD=${ADMIN_PASSWORD}

# JWT Validation
KEYCLOAK_JWKS_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/certs
KEYCLOAK_ISSUER=${KEYCLOAK_URL}/realms/${REALM_NAME}

# Token Endpoints
KEYCLOAK_TOKEN_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token
KEYCLOAK_LOGOUT_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/logout
KEYCLOAK_USERINFO_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/userinfo
EOF

    print_success "Configuration saved to: ${CONFIG_FILE}"
    echo ""
}

# Run main function
main
