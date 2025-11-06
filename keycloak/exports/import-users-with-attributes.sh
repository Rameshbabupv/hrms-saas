#!/bin/bash

################################################################################
# Import Users with Attributes
#
# This script imports users from the detailed export including:
# - User profiles (username, email, first name, last name)
# - Custom attributes (company_id, tenant_id, employee_id, etc.)
# - Email verification status
#
# NOTE: This does NOT import passwords - you'll need to set them manually
#
# Usage: ./import-users-with-attributes.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

echo ""
echo "========================================"
echo "  Import Users with Attributes"
echo "========================================"
echo ""

# Check if export file exists
if [ ! -f "hrms-saas-users-detailed.json" ]; then
    print_error "Export file 'hrms-saas-users-detailed.json' not found!"
    print_info "Make sure you're running this script from the exports directory"
    exit 1
fi

USER_COUNT=$(jq '. | length' hrms-saas-users-detailed.json)
print_info "Found $USER_COUNT users to import"

# Check if Keycloak is accessible
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/ 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
    print_error "Keycloak is not accessible at http://localhost:8090"
    print_info "Please start Keycloak first"
    exit 1
fi

# Get admin access token
print_info "Authenticating with Keycloak..."
TOKEN=$(curl -s -X POST "http://localhost:8090/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=secret" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    print_error "Failed to get access token"
    exit 1
fi

print_success "Successfully authenticated"

# Check if realm exists
print_info "Checking if realm 'hrms-saas' exists..."
REALM_EXISTS=$(curl -s -X GET "http://localhost:8090/admin/realms/hrms-saas" \
  -H "Authorization: Bearer $TOKEN" \
  -o /dev/null -w "%{http_code}")

if [ "$REALM_EXISTS" != "200" ]; then
    print_error "Realm 'hrms-saas' does not exist"
    print_info "Please import the realm configuration first using: ./import-realm-config.sh"
    exit 1
fi

print_success "Realm 'hrms-saas' found"

# Import each user
print_info "Importing users..."
IMPORTED=0
SKIPPED=0
FAILED=0

# Read users from JSON
jq -c '.[]' hrms-saas-users-detailed.json | while read user; do
    USERNAME=$(echo "$user" | jq -r '.username')
    EMAIL=$(echo "$user" | jq -r '.email')
    FIRST_NAME=$(echo "$user" | jq -r '.firstName // ""')
    LAST_NAME=$(echo "$user" | jq -r '.lastName // ""')

    print_info "Processing user: $USERNAME"

    # Check if user already exists
    EXISTING_USER=$(curl -s -X GET "http://localhost:8090/admin/realms/hrms-saas/users?username=$USERNAME&exact=true" \
      -H "Authorization: Bearer $TOKEN")

    if [ "$(echo "$EXISTING_USER" | jq '. | length')" -gt 0 ]; then
        print_warning "User $USERNAME already exists - skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Create user payload
    USER_PAYLOAD=$(echo "$user" | jq '{
        username: .username,
        email: .email,
        firstName: (.firstName // ""),
        lastName: (.lastName // ""),
        enabled: (.enabled // true),
        emailVerified: (.emailVerified // false),
        attributes: (.attributes // {})
    }')

    # Create user
    RESPONSE=$(curl -s -X POST "http://localhost:8090/admin/realms/hrms-saas/users" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$USER_PAYLOAD" \
      -w "\n%{http_code}")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" == "201" ]; then
        print_success "Created user: $USERNAME"
        IMPORTED=$((IMPORTED + 1))

        # Show attributes if any
        ATTRS=$(echo "$user" | jq -r '.attributes // {} | keys | .[]' 2>/dev/null)
        if [ ! -z "$ATTRS" ]; then
            print_info "  └─ Attributes: $(echo "$ATTRS" | tr '\n' ', ' | sed 's/,$//')"
        fi
    else
        print_error "Failed to create user: $USERNAME (HTTP $HTTP_CODE)"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "========================================"
echo "  Import Summary"
echo "========================================"
echo ""
print_success "Successfully imported: $IMPORTED users"
if [ $SKIPPED -gt 0 ]; then
    print_warning "Skipped (already exist): $SKIPPED users"
fi
if [ $FAILED -gt 0 ]; then
    print_error "Failed to import: $FAILED users"
fi
echo ""
print_warning "IMPORTANT: Passwords were NOT imported!"
echo ""
echo "Next Steps:"
echo "  1. Set passwords for all users via Admin Console"
echo "  2. Or use the reset password API endpoint"
echo "  3. Verify custom attributes are present"
echo ""
echo "Access Information:"
echo "  • Admin Console: http://localhost:8090/admin"
echo "  • Realm: hrms-saas"
echo "  • Users Section: http://localhost:8090/admin/master/console/#/hrms-saas/users"
echo ""
