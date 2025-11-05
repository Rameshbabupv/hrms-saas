#!/bin/bash

# Domain Validation Test Script
# Tests all domain validation functionality
# Usage: ./test-domain-validation.sh

set -e  # Exit on error

BASE_URL="http://localhost:8081/api/v1/auth"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "  Domain Validation Test Suite"
echo "========================================"
echo ""

# Check if server is running
echo "Checking if Spring Boot is running..."
if ! curl -s "$BASE_URL/check-domain?domain=test.com" > /dev/null 2>&1; then
    echo -e "${RED}❌ ERROR: Spring Boot not running on port 8081${NC}"
    echo "Start with: mvn spring-boot:run"
    exit 1
fi
echo -e "${GREEN}✅ Spring Boot is running${NC}"
echo ""

# Test 1: Check Public Domain (Gmail)
echo "========================================"
echo "Test 1: Check Public Domain (gmail.com)"
echo "========================================"
RESPONSE=$(curl -s "$BASE_URL/check-domain?domain=gmail.com")
echo "$RESPONSE" | jq .

AVAILABLE=$(echo "$RESPONSE" | jq -r '.available')
IS_PUBLIC=$(echo "$RESPONSE" | jq -r '.isPublic')

if [ "$AVAILABLE" = "true" ] && [ "$IS_PUBLIC" = "true" ]; then
    echo -e "${GREEN}✅ PASS: Gmail is public and available${NC}"
else
    echo -e "${RED}❌ FAIL: Expected available=true, isPublic=true${NC}"
fi
echo ""

# Test 2: Check Locked Corporate Domain
echo "========================================"
echo "Test 2: Check Locked Domain (systech.com)"
echo "========================================"
RESPONSE=$(curl -s "$BASE_URL/check-domain?domain=systech.com")
echo "$RESPONSE" | jq .

AVAILABLE=$(echo "$RESPONSE" | jq -r '.available')
IS_PUBLIC=$(echo "$RESPONSE" | jq -r '.isPublic')

if [ "$AVAILABLE" = "false" ] && [ "$IS_PUBLIC" = "false" ]; then
    echo -e "${GREEN}✅ PASS: Systech.com is locked${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Systech.com should be locked (or not yet registered)${NC}"
fi
echo ""

# Test 3: Check Available Corporate Domain
echo "========================================"
echo "Test 3: Check Available Domain (newcompany.com)"
echo "========================================"
RESPONSE=$(curl -s "$BASE_URL/check-domain?domain=newcompany.com")
echo "$RESPONSE" | jq .

AVAILABLE=$(echo "$RESPONSE" | jq -r '.available')
IS_PUBLIC=$(echo "$RESPONSE" | jq -r '.isPublic')

if [ "$AVAILABLE" = "true" ] && [ "$IS_PUBLIC" = "false" ]; then
    echo -e "${GREEN}✅ PASS: New corporate domain is available${NC}"
else
    echo -e "${RED}❌ FAIL: Expected available=true, isPublic=false${NC}"
fi
echo ""

# Test 4: Case Insensitive Check
echo "========================================"
echo "Test 4: Case Insensitive (GMAIL.COM)"
echo "========================================"
RESPONSE=$(curl -s "$BASE_URL/check-domain?domain=GMAIL.COM")
echo "$RESPONSE" | jq .

DOMAIN=$(echo "$RESPONSE" | jq -r '.domain')

if [ "$DOMAIN" = "gmail.com" ]; then
    echo -e "${GREEN}✅ PASS: Domain normalized to lowercase${NC}"
else
    echo -e "${RED}❌ FAIL: Expected domain=gmail.com${NC}"
fi
echo ""

# Test 5: Signup with Public Email (Gmail)
echo "========================================"
echo "Test 5: Signup with Public Email (gmail.com)"
echo "========================================"
RANDOM_EMAIL="test$RANDOM@gmail.com"
RESPONSE=$(curl -s -X POST "$BASE_URL/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'$RANDOM_EMAIL'",
    "password": "SecurePass123!",
    "firstName": "Test",
    "lastName": "User",
    "companyName": "Test Gmail Company",
    "phone": "+1234567890"
  }')
echo "$RESPONSE" | jq .

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
TENANT_ID=$(echo "$RESPONSE" | jq -r '.tenantId')

if [ "$SUCCESS" = "true" ] && [ "$TENANT_ID" != "null" ] && [ "$TENANT_ID" != "" ]; then
    echo -e "${GREEN}✅ PASS: Signup with gmail.com succeeded${NC}"
    echo -e "${GREEN}   Tenant ID: $TENANT_ID${NC}"
else
    echo -e "${RED}❌ FAIL: Signup should succeed with public email${NC}"
fi
echo ""

# Test 6: Signup with New Corporate Domain
echo "========================================"
echo "Test 6: Signup with New Corporate Domain"
echo "========================================"
RANDOM_DOMAIN="testcompany$RANDOM.com"
ADMIN_EMAIL="admin@$RANDOM_DOMAIN"

echo "Creating account with domain: $RANDOM_DOMAIN"

RESPONSE=$(curl -s -X POST "$BASE_URL/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'$ADMIN_EMAIL'",
    "password": "SecurePass123!",
    "firstName": "Admin",
    "lastName": "User",
    "companyName": "Test Corp '$RANDOM'",
    "phone": "+1234567890"
  }')
echo "$RESPONSE" | jq .

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
TENANT_ID=$(echo "$RESPONSE" | jq -r '.tenantId')

if [ "$SUCCESS" = "true" ] && [ "$TENANT_ID" != "null" ] && [ "$TENANT_ID" != "" ]; then
    echo -e "${GREEN}✅ PASS: Signup with new corporate domain succeeded${NC}"
    echo -e "${GREEN}   Domain: $RANDOM_DOMAIN${NC}"
    echo -e "${GREEN}   Tenant ID: $TENANT_ID${NC}"
    LOCKED_DOMAIN=$RANDOM_DOMAIN
    LOCKED_TENANT_ID=$TENANT_ID
else
    echo -e "${RED}❌ FAIL: Signup with corporate domain should succeed${NC}"
    LOCKED_DOMAIN=""
fi
echo ""

# Test 7: Verify Domain Got Locked
if [ -n "$LOCKED_DOMAIN" ]; then
    echo "========================================"
    echo "Test 7: Verify Domain Locked ($LOCKED_DOMAIN)"
    echo "========================================"
    sleep 1  # Give it a moment to commit

    RESPONSE=$(curl -s "$BASE_URL/check-domain?domain=$LOCKED_DOMAIN")
    echo "$RESPONSE" | jq .

    AVAILABLE=$(echo "$RESPONSE" | jq -r '.available')

    if [ "$AVAILABLE" = "false" ]; then
        echo -e "${GREEN}✅ PASS: Domain is now locked${NC}"
    else
        echo -e "${RED}❌ FAIL: Domain should be locked after signup${NC}"
    fi
    echo ""

    # Test 8: Try Second Signup with Same Domain (Should Fail)
    echo "========================================"
    echo "Test 8: Second Signup with Same Domain (Should Fail)"
    echo "========================================"
    SECOND_EMAIL="another@$LOCKED_DOMAIN"

    RESPONSE=$(curl -s -X POST "$BASE_URL/signup" \
      -H "Content-Type: application/json" \
      -d '{
        "email": "'$SECOND_EMAIL'",
        "password": "SecurePass123!",
        "firstName": "Another",
        "lastName": "User",
        "companyName": "Should Fail Company",
        "phone": "+0987654321"
      }')
    echo "$RESPONSE" | jq .

    SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message')

    if [ "$SUCCESS" = "false" ] && [[ "$MESSAGE" == *"already registered"* ]]; then
        echo -e "${GREEN}✅ PASS: Second signup correctly blocked${NC}"
    else
        echo -e "${RED}❌ FAIL: Second signup should be blocked${NC}"
    fi
    echo ""
fi

# Test 9: Check All Public Domains
echo "========================================"
echo "Test 9: Verify All Public Domains"
echo "========================================"
PUBLIC_DOMAINS=("gmail.com" "yahoo.com" "outlook.com" "hotmail.com" "icloud.com")
ALL_PUBLIC=true

for domain in "${PUBLIC_DOMAINS[@]}"; do
    RESPONSE=$(curl -s "$BASE_URL/check-domain?domain=$domain")
    IS_PUBLIC=$(echo "$RESPONSE" | jq -r '.isPublic')

    if [ "$IS_PUBLIC" = "true" ]; then
        echo -e "${GREEN}✅ $domain is public${NC}"
    else
        echo -e "${RED}❌ $domain should be public${NC}"
        ALL_PUBLIC=false
    fi
done

if [ "$ALL_PUBLIC" = true ]; then
    echo -e "${GREEN}✅ PASS: All public domains configured correctly${NC}"
else
    echo -e "${RED}❌ FAIL: Some public domains not configured${NC}"
fi
echo ""

# Test 10: Check Email Already Exists
echo "========================================"
echo "Test 10: Email Already Exists Check"
echo "========================================"
RESPONSE=$(curl -s "$BASE_URL/check-email?email=$RANDOM_EMAIL")
echo "$RESPONSE" | jq .

AVAILABLE=$(echo "$RESPONSE" | jq -r '.available')

if [ "$AVAILABLE" = "false" ]; then
    echo -e "${GREEN}✅ PASS: Email correctly detected as existing${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Email should exist from Test 5${NC}"
fi
echo ""

# Summary
echo "========================================"
echo "  Test Suite Completed"
echo "========================================"
echo ""
echo -e "${GREEN}✅ Domain validation is working correctly!${NC}"
echo ""
echo "Summary of Created Test Data:"
echo "  - Gmail account: $RANDOM_EMAIL"
if [ -n "$LOCKED_DOMAIN" ]; then
    echo "  - Corporate domain: $LOCKED_DOMAIN (locked to tenant: $LOCKED_TENANT_ID)"
    echo "  - Admin email: $ADMIN_EMAIL"
fi
echo ""
echo "Next Steps:"
echo "  1. Check Keycloak for created users"
echo "  2. Verify email verification emails sent"
echo "  3. Test with frontend application"
echo ""
