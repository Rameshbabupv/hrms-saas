#!/bin/bash

################################################################################
# Test JWT Token Generation and Validation
#
# This script:
# 1. Authenticates test users
# 2. Retrieves JWT tokens
# 3. Decodes and validates custom claims
# 4. Tests token refresh
#
# Usage: ./test-token.sh [username]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_header() {
    echo -e "${CYAN}$1${NC}"
}

# Function to decode JWT (base64url decode)
decode_jwt() {
    local jwt=$1
    local part=$2  # 0=header, 1=payload, 2=signature

    # Extract the part
    local token_part=$(echo "$jwt" | cut -d'.' -f$((part+1)))

    # Add padding if needed
    local padding=$((4 - ${#token_part} % 4))
    if [ $padding -lt 4 ]; then
        token_part="${token_part}$(printf '=%.0s' $(seq 1 $padding))"
    fi

    # Decode base64url (replace - with +, _ with /)
    echo "$token_part" | tr '_-' '/+' | base64 -d 2>/dev/null | jq '.' 2>/dev/null || echo "Failed to decode"
}

# Function to get token
get_token() {
    local username=$1
    local password=$2

    print_info "Authenticating user: ${username}"

    RESPONSE=$(curl -s -X POST "${KEYCLOAK_TOKEN_URL}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=${KEYCLOAK_CLIENT_ID}" \
        -d "client_secret=${KEYCLOAK_CLIENT_SECRET}" \
        -d "username=${username}" \
        -d "password=${password}")

    # Check if we got a token
    ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
    REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token')
    EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.expires_in')

    if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
        print_error "Failed to get access token"
        echo "$RESPONSE" | jq '.'
        return 1
    fi

    print_success "Access token obtained"
    print_info "Token expires in: ${EXPIRES_IN} seconds ($(($EXPIRES_IN / 60)) minutes)"
}

# Function to verify custom claims
verify_custom_claims() {
    print_header ""
    print_header "Verifying Custom JWT Claims..."
    print_header "================================"

    # Decode the payload (part 1)
    PAYLOAD=$(decode_jwt "$ACCESS_TOKEN" 1)

    if [ "$PAYLOAD" == "Failed to decode" ]; then
        print_error "Failed to decode JWT token"
        return 1
    fi

    echo "$PAYLOAD" > /tmp/jwt_payload.json

    # Check required claims
    declare -a REQUIRED_CLAIMS=("company_id" "tenant_id" "user_type")
    declare -a OPTIONAL_CLAIMS=("employee_id" "company_code" "company_name" "phone")

    local all_required_present=true

    echo ""
    print_header "Required Claims:"
    for claim in "${REQUIRED_CLAIMS[@]}"; do
        value=$(jq -r ".${claim}" /tmp/jwt_payload.json)
        if [ "$value" != "null" ] && [ -n "$value" ]; then
            print_success "${claim}: ${value}"
        else
            print_error "${claim}: MISSING"
            all_required_present=false
        fi
    done

    echo ""
    print_header "Optional Claims:"
    for claim in "${OPTIONAL_CLAIMS[@]}"; do
        value=$(jq -r ".${claim}" /tmp/jwt_payload.json)
        if [ "$value" != "null" ] && [ -n "$value" ]; then
            print_success "${claim}: ${value}"
        else
            print_warning "${claim}: not present"
        fi
    done

    echo ""
    print_header "Standard Claims:"
    echo "  Issuer: $(jq -r '.iss' /tmp/jwt_payload.json)"
    echo "  Subject: $(jq -r '.sub' /tmp/jwt_payload.json)"
    echo "  Email: $(jq -r '.email' /tmp/jwt_payload.json)"
    echo "  Username: $(jq -r '.preferred_username' /tmp/jwt_payload.json)"
    echo "  Email Verified: $(jq -r '.email_verified' /tmp/jwt_payload.json)"

    echo ""
    print_header "Realm Roles:"
    ROLES=$(jq -r '.realm_access.roles[]' /tmp/jwt_payload.json 2>/dev/null)
    if [ -n "$ROLES" ]; then
        echo "$ROLES" | while read role; do
            echo "  - $role"
        done
    else
        print_warning "No realm roles found"
    fi

    echo ""
    if [ "$all_required_present" = true ]; then
        print_success "All required custom claims are present!"
        return 0
    else
        print_error "Some required claims are missing!"
        return 1
    fi
}

# Function to test token refresh
test_token_refresh() {
    print_header ""
    print_header "Testing Token Refresh..."
    print_header "========================"

    print_info "Using refresh token to get new access token..."

    REFRESH_RESPONSE=$(curl -s -X POST "${KEYCLOAK_TOKEN_URL}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token" \
        -d "client_id=${KEYCLOAK_CLIENT_ID}" \
        -d "client_secret=${KEYCLOAK_CLIENT_SECRET}" \
        -d "refresh_token=${REFRESH_TOKEN}")

    NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.access_token')

    if [ "$NEW_ACCESS_TOKEN" != "null" ] && [ -n "$NEW_ACCESS_TOKEN" ]; then
        print_success "Token refresh successful"
        print_info "New token obtained"

        # Verify claims in new token
        OLD_COMPANY_ID=$(decode_jwt "$ACCESS_TOKEN" 1 | jq -r '.company_id')
        NEW_COMPANY_ID=$(decode_jwt "$NEW_ACCESS_TOKEN" 1 | jq -r '.company_id')

        if [ "$OLD_COMPANY_ID" == "$NEW_COMPANY_ID" ]; then
            print_success "Custom claims preserved in refreshed token"
        else
            print_error "Custom claims changed in refreshed token!"
        fi
    else
        print_error "Token refresh failed"
        echo "$REFRESH_RESPONSE" | jq '.'
        return 1
    fi
}

# Function to display full token
display_full_token() {
    print_header ""
    print_header "Full JWT Token Payload:"
    print_header "======================="
    echo ""
    decode_jwt "$ACCESS_TOKEN" 1 | jq '.'
}

# Function to save tokens
save_tokens() {
    local username=$1
    local token_file="../config/tokens-$(echo $username | cut -d'@' -f1).json"

    cat > "$token_file" << EOF
{
  "username": "$username",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "access_token": "$ACCESS_TOKEN",
  "refresh_token": "$REFRESH_TOKEN",
  "expires_in": $EXPIRES_IN,
  "token_type": "Bearer",
  "decoded_payload": $(decode_jwt "$ACCESS_TOKEN" 1)
}
EOF

    print_success "Tokens saved to: $token_file"
}

# Main execution
main() {
    local test_user=$1

    echo ""
    echo "=========================================="
    echo "  JWT Token Generation & Validation Test"
    echo "=========================================="
    echo ""

    # Determine which user to test
    if [ -z "$test_user" ]; then
        print_info "No username provided, testing employee user"
        TEST_USERNAME="john.doe@testcompany.com"
        TEST_PASSWORD="TestUser@123"
    elif [ "$test_user" == "admin" ]; then
        TEST_USERNAME="admin@testcompany.com"
        TEST_PASSWORD="TestAdmin@123"
    elif [ "$test_user" == "employee" ]; then
        TEST_USERNAME="john.doe@testcompany.com"
        TEST_PASSWORD="TestUser@123"
    else
        TEST_USERNAME="$test_user"
        print_info "Enter password for $TEST_USERNAME:"
        read -s TEST_PASSWORD
    fi

    # Get token
    get_token "$TEST_USERNAME" "$TEST_PASSWORD" || exit 1

    # Verify custom claims
    verify_custom_claims

    # Test token refresh
    test_token_refresh

    # Display full token
    display_full_token

    # Save tokens
    save_tokens "$TEST_USERNAME"

    echo ""
    echo "=========================================="
    echo "  Test Complete!"
    echo "=========================================="
    echo ""
    print_success "All token tests passed successfully"
    echo ""
    print_info "Access Token (first 80 chars):"
    echo "  ${ACCESS_TOKEN:0:80}..."
    echo ""
    print_info "Usage Examples:"
    echo ""
    echo "  # Test employee user (default)"
    echo "  ./test-token.sh"
    echo ""
    echo "  # Test admin user"
    echo "  ./test-token.sh admin"
    echo ""
    echo "  # Test specific user"
    echo "  ./test-token.sh user@company.com"
    echo ""
    print_info "To decode tokens online, visit: https://jwt.io"
    echo ""
}

# Check for jq
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it first:"
    echo "  brew install jq"
    exit 1
fi

# Run main with arguments
main "$@"
