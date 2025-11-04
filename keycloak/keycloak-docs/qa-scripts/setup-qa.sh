#!/bin/bash

################################################################################
# Keycloak QA Setup Script for HRMS SaaS
#
# This script automates the complete setup of Keycloak in QA environment:
# - Creates realm
# - Configures client
# - Sets up roles
# - Creates custom JWT mappers
#
# Usage: ./setup-qa.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - Update these for your QA environment
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8090}"
ADMIN_USERNAME="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-secret}"
REALM_NAME="${REALM_NAME:-hrms-saas}"
CLIENT_ID="${CLIENT_ID:-hrms-web-app}"

# Redirect URIs - Update with your QA URLs
REDIRECT_URIS='["https://hrms-qa.yourdomain.com/*", "http://localhost:3000/*", "http://localhost:3001/*"]'
WEB_ORIGINS='["https://hrms-qa.yourdomain.com", "http://localhost:3000", "http://localhost:3001", "+"]'

# Functions
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

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq: apt-get install jq"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Wait for Keycloak to be ready
wait_for_keycloak() {
    print_info "Waiting for Keycloak to be ready..."
    MAX_RETRIES=60
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${KEYCLOAK_URL}" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
            print_success "Keycloak is ready!"
            return 0
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -n "."
        sleep 2
    done

    echo ""
    print_error "Keycloak did not start within expected time"
    return 1
}

# Get admin access token
get_admin_token() {
    print_info "Getting admin access token..."

    RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        -d "username=${ADMIN_USERNAME}" \
        -d "password=${ADMIN_PASSWORD}")

    ADMIN_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

    if [ "$ADMIN_TOKEN" == "null" ] || [ -z "$ADMIN_TOKEN" ]; then
        print_error "Failed to get admin token"
        echo "Response: $RESPONSE"
        exit 1
    fi

    print_success "Admin token obtained"
}

# Create realm
create_realm() {
    print_info "Creating realm '${REALM_NAME}'..."

    # Check if realm exists
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")

    if [ "$HTTP_CODE" == "200" ]; then
        print_warning "Realm '${REALM_NAME}' already exists. Skipping creation."
        return 0
    fi

    REALM_CONFIG=$(cat <<EOF
{
    "realm": "${REALM_NAME}",
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
}
EOF
)

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${KEYCLOAK_URL}/admin/realms" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${REALM_CONFIG}")

    if [ "$HTTP_CODE" == "201" ]; then
        print_success "Realm '${REALM_NAME}' created successfully"
    else
        print_error "Failed to create realm. HTTP Code: ${HTTP_CODE}"
        exit 1
    fi
}

# Create realm roles
create_realm_roles() {
    print_info "Creating realm roles..."

    declare -a ROLES=("super_admin" "company_admin" "hr_user" "manager" "employee")
    declare -a DESCRIPTIONS=(
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

        ROLE_CONFIG=$(cat <<EOF
{
    "name": "${ROLE_NAME}",
    "description": "${ROLE_DESC}",
    "composite": false,
    "clientRole": false
}
EOF
)

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
}

# Create client
create_client() {
    print_info "Creating client '${CLIENT_ID}'..."

    CLIENT_CONFIG=$(cat <<EOF
{
    "clientId": "${CLIENT_ID}",
    "name": "HRMS Web Application",
    "description": "Main web application for HRMS SaaS platform",
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "redirectUris": ${REDIRECT_URIS},
    "webOrigins": ${WEB_ORIGINS},
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
}
EOF
)

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${CLIENT_CONFIG}")

    if [ "$HTTP_CODE" == "201" ]; then
        print_success "Client '${CLIENT_ID}' created successfully"
    elif [ "$HTTP_CODE" == "409" ]; then
        print_warning "Client '${CLIENT_ID}' already exists"
    else
        print_error "Failed to create client. HTTP Code: ${HTTP_CODE}"
        exit 1
    fi
}

# Get client UUID and secret
get_client_info() {
    print_info "Getting client information..."

    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

    if [ "$CLIENT_UUID" == "null" ] || [ -z "$CLIENT_UUID" ]; then
        print_error "Failed to get client UUID"
        exit 1
    fi

    CLIENT_SECRET=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')

    if [ "$CLIENT_SECRET" == "null" ] || [ -z "$CLIENT_SECRET" ]; then
        print_error "Failed to get client secret"
        exit 1
    fi

    print_success "Client UUID: ${CLIENT_UUID}"
    print_success "Client secret obtained"
}

# Create protocol mappers
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

        MAPPER_CONFIG=$(cat <<EOF
{
    "name": "${MAPPER_NAME}",
    "protocol": "openid-connect",
    "protocolMapper": "oidc-usermodel-attribute-mapper",
    "config": {
        "user.attribute": "${CLAIM_NAME}",
        "claim.name": "${CLAIM_NAME}",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
    }
}
EOF
)

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

# Save configuration
save_configuration() {
    print_info "Saving configuration..."

    CONFIG_FILE="keycloak-qa-config.env"
    cat > ${CONFIG_FILE} << EOF
# Keycloak QA Configuration for HRMS SaaS
# Generated: $(date)

# Keycloak Settings
KEYCLOAK_URL=${KEYCLOAK_URL}
KEYCLOAK_REALM=${REALM_NAME}
KEYCLOAK_CLIENT_ID=${CLIENT_ID}
KEYCLOAK_CLIENT_SECRET=${CLIENT_SECRET}
KEYCLOAK_CLIENT_UUID=${CLIENT_UUID}

# Admin Credentials (Keep secure!)
KEYCLOAK_ADMIN_USERNAME=${ADMIN_USERNAME}
KEYCLOAK_ADMIN_PASSWORD=${ADMIN_PASSWORD}

# JWT Endpoints
KEYCLOAK_JWKS_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/certs
KEYCLOAK_ISSUER=${KEYCLOAK_URL}/realms/${REALM_NAME}
KEYCLOAK_TOKEN_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token
KEYCLOAK_LOGOUT_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/logout
KEYCLOAK_USERINFO_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/userinfo

# For Spring Boot application.yml
SPRING_SECURITY_OAUTH2_ISSUER_URI=${KEYCLOAK_URL}/realms/${REALM_NAME}
SPRING_SECURITY_OAUTH2_JWK_SET_URI=${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/certs

# For React .env
REACT_APP_KEYCLOAK_URL=${KEYCLOAK_URL}
REACT_APP_KEYCLOAK_REALM=${REALM_NAME}
REACT_APP_KEYCLOAK_CLIENT_ID=${CLIENT_ID}
EOF

    print_success "Configuration saved to: ${CONFIG_FILE}"
}

# Main execution
main() {
    echo ""
    echo "========================================"
    echo "  Keycloak QA Setup for HRMS SaaS"
    echo "========================================"
    echo ""
    echo "Configuration:"
    echo "  Keycloak URL: ${KEYCLOAK_URL}"
    echo "  Realm: ${REALM_NAME}"
    echo "  Client ID: ${CLIENT_ID}"
    echo ""

    check_prerequisites
    wait_for_keycloak
    get_admin_token
    create_realm
    create_realm_roles
    create_client
    get_client_info
    create_protocol_mappers
    save_configuration

    echo ""
    echo "========================================"
    echo "  Setup Complete!"
    echo "========================================"
    echo ""
    print_success "Keycloak QA configuration completed successfully"
    echo ""
    echo "Access Information:"
    echo "  Admin Console: ${KEYCLOAK_URL}/admin"
    echo "  Realm: ${REALM_NAME}"
    echo "  Client ID: ${CLIENT_ID}"
    echo "  Client Secret: ${CLIENT_SECRET}"
    echo ""
    echo "Configuration file: ${CONFIG_FILE}"
    echo ""
    print_info "Next steps:"
    echo "  1. Review configuration in admin console"
    echo "  2. Create test users if needed"
    echo "  3. Test token generation"
    echo "  4. Integrate with HRMS SaaS applications"
    echo ""
}

# Run main function
main
