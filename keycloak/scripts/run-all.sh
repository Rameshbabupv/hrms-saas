#!/bin/bash

################################################################################
# Master Script - Complete Keycloak Setup for HRMS SaaS
#
# This script runs all setup scripts in sequence:
# 1. Setup Keycloak realm and client
# 2. Create test users
# 3. Test token generation
#
# Usage: ./run-all.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo ""
    echo -e "${CYAN}=========================================="
    echo -e "  $1"
    echo -e "==========================================${NC}"
    echo ""
}

main() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║     Keycloak HRMS SaaS - Automated Setup Master Script       ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "This script will perform the following steps:"
    echo "  1. Create hrms-saas realm with all configurations"
    echo "  2. Create hrms-web-app client with custom mappers"
    echo "  3. Create 5 realm roles"
    echo "  4. Create 2 test users (admin + employee)"
    echo "  5. Test JWT token generation and validation"
    echo ""
    echo -e "${BLUE}Press ENTER to continue or Ctrl+C to cancel...${NC}"
    read

    # Step 1: Setup Keycloak
    print_step "Step 1: Setting up Keycloak Realm & Client"
    ./setup-keycloak.sh

    # Step 2: Create test users
    print_step "Step 2: Creating Test Users"
    ./create-test-users.sh

    # Step 3: Test token generation
    print_step "Step 3: Testing JWT Token Generation"
    ./test-token.sh employee

    # Summary
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║                 SETUP COMPLETED SUCCESSFULLY!                 ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Configuration Files Generated:"
    echo "  • config/keycloak-config.env    - Environment variables"
    echo "  • config/test-users.txt          - Test user credentials"
    echo "  • config/tokens-*.json           - Sample JWT tokens"
    echo ""
    echo "Next Steps:"
    echo "  1. Review configuration: cat ../config/keycloak-config.env"
    echo "  2. Access Admin Console: http://localhost:8090/admin"
    echo "  3. Login with: admin/secret"
    echo "  4. Share config with backend team"
    echo ""
    echo "Individual Scripts:"
    echo "  • ./setup-keycloak.sh       - Re-run realm setup"
    echo "  • ./create-test-users.sh    - Create additional test users"
    echo "  • ./test-token.sh [user]    - Test token for specific user"
    echo ""
}

main
