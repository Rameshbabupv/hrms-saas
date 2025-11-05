# Domain Validation - Testing Guide

## Quick Start Testing

### Prerequisites
- Spring Boot running on port 8081
- PostgreSQL database running
- Flyway migration V2 applied

---

## Test 1: Check Public Domain (Gmail)

```bash
curl "http://localhost:8081/api/v1/auth/check-domain?domain=gmail.com"
```

**Expected Response:**
```json
{
  "available": true,
  "isPublic": true,
  "domain": "gmail.com"
}
```

**What it means**: ✅ Multiple users can signup with gmail.com

---

## Test 2: Check Corporate Domain (Already Registered)

```bash
curl "http://localhost:8081/api/v1/auth/check-domain?domain=systech.com"
```

**Expected Response:**
```json
{
  "available": false,
  "isPublic": false,
  "domain": "systech.com"
}
```

**What it means**: ❌ Domain already locked to another tenant

---

## Test 3: Check New Corporate Domain

```bash
curl "http://localhost:8081/api/v1/auth/check-domain?domain=newcompany.com"
```

**Expected Response:**
```json
{
  "available": true,
  "isPublic": false,
  "domain": "newcompany.com"
}
```

**What it means**: ✅ First person can register this domain

---

## Test 4: Signup with Public Email (Gmail)

```bash
curl -X POST http://localhost:8081/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@gmail.com",
    "password": "SecurePass123!",
    "firstName": "John",
    "lastName": "Doe",
    "companyName": "John Freelance",
    "phone": "+1234567890"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "tenantId": "abc123xyz456",
  "keycloakUserId": "uuid-here",
  "message": "Account created successfully. Please verify your email."
}
```

**What happens**: ✅ Account created, domain NOT locked

---

## Test 5: Signup with New Corporate Domain

```bash
curl -X POST http://localhost:8081/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@acme.com",
    "password": "SecurePass123!",
    "firstName": "Admin",
    "lastName": "User",
    "companyName": "Acme Industries",
    "phone": "+1234567890"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "tenantId": "def456ghi789",
  "keycloakUserId": "uuid-here",
  "message": "Account created successfully. Please verify your email."
}
```

**What happens**:
1. ✅ Account created
2. 🔒 Domain "acme.com" locked to tenant "def456ghi789"
3. ❌ No one else can use acme.com

---

## Test 6: Try Second Signup with Same Corporate Domain

```bash
curl -X POST http://localhost:8081/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "another@acme.com",
    "password": "SecurePass123!",
    "firstName": "Another",
    "lastName": "User",
    "companyName": "Acme Location 2",
    "phone": "+0987654321"
  }'
```

**Expected Response:**
```json
{
  "success": false,
  "message": "Domain acme.com is already registered to another company"
}
```

**What happens**: ❌ Signup blocked - domain already locked

---

## Test 7: Verify Domain Locked in Database

```bash
psql -h localhost -U hrms_user -d hrms_db -c "
SELECT
  domain,
  is_public,
  is_locked,
  registered_tenant_id,
  created_at
FROM domain_master
WHERE domain = 'acme.com';
"
```

**Expected Output:**
```
   domain   | is_public | is_locked | registered_tenant_id |      created_at
------------+-----------+-----------+----------------------+---------------------
 acme.com   | f         | t         | def456ghi789        | 2025-11-05 13:30:00
```

---

## Test 8: Case Insensitive Domain Check

```bash
# Test with uppercase
curl "http://localhost:8081/api/v1/auth/check-domain?domain=GMAIL.COM"

# Test with mixed case
curl "http://localhost:8081/api/v1/auth/check-domain?domain=GmAiL.CoM"
```

**Expected**: All return lowercase `"domain": "gmail.com"`

---

## Test 9: Check All Public Domains

```bash
psql -h localhost -U hrms_user -d hrms_db -c "
SELECT domain FROM domain_master WHERE is_public = true ORDER BY domain;
"
```

**Expected Output:**
```
    domain
---------------
 aol.com
 gmail.com
 hotmail.com
 icloud.com
 mail.com
 outlook.com
 protonmail.com
 yahoo.com
 yandex.com
 zoho.com
```

---

## Test 10: Verify Company Has Domain

```bash
psql -h localhost -U hrms_user -d hrms_db -c "
SELECT
  tenant_id,
  company_name,
  email,
  domain,
  status
FROM company_master
WHERE domain = 'acme.com';
"
```

**Expected Output:**
```
   tenant_id    | company_name     |      email       |  domain  |         status
----------------+------------------+------------------+----------+------------------------
 def456ghi789   | Acme Industries  | admin@acme.com   | acme.com | PENDING_EMAIL_VERIFICATION
```

---

## Complete End-to-End Test Script

Save as `test-domain-validation.sh`:

```bash
#!/bin/bash

BASE_URL="http://localhost:8081/api/v1/auth"

echo "=== Test 1: Check gmail.com (public) ==="
curl -s "$BASE_URL/check-domain?domain=gmail.com" | jq .
echo ""

echo "=== Test 2: Check systech.com (locked) ==="
curl -s "$BASE_URL/check-domain?domain=systech.com" | jq .
echo ""

echo "=== Test 3: Check newdomain.com (available) ==="
curl -s "$BASE_URL/check-domain?domain=newdomain.com" | jq .
echo ""

echo "=== Test 4: Signup with gmail.com ==="
curl -s -X POST "$BASE_URL/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test'$RANDOM'@gmail.com",
    "password": "SecurePass123!",
    "firstName": "Test",
    "lastName": "User",
    "companyName": "Test Company",
    "phone": "+1234567890"
  }' | jq .
echo ""

echo "=== Test 5: Signup with new corporate domain ==="
RANDOM_DOMAIN="company$RANDOM.com"
curl -s -X POST "$BASE_URL/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@'$RANDOM_DOMAIN'",
    "password": "SecurePass123!",
    "firstName": "Admin",
    "lastName": "User",
    "companyName": "Test Corp",
    "phone": "+1234567890"
  }' | jq .
echo ""

echo "=== Test 6: Try second signup with same domain (should fail) ==="
curl -s -X POST "$BASE_URL/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "another@'$RANDOM_DOMAIN'",
    "password": "SecurePass123!",
    "firstName": "Another",
    "lastName": "User",
    "companyName": "Test Corp 2",
    "phone": "+0987654321"
  }' | jq .
echo ""

echo "=== All tests completed ==="
```

**Run it:**
```bash
chmod +x test-domain-validation.sh
./test-domain-validation.sh
```

---

## Using Postman

### Setup:
1. Create new collection: "Domain Validation Tests"
2. Set base URL variable: `{{baseUrl}}` = `http://localhost:8081`

### Test 1: Check Domain
- **Method**: GET
- **URL**: `{{baseUrl}}/api/v1/auth/check-domain?domain=gmail.com`
- **Headers**: None needed

### Test 2: Signup
- **Method**: POST
- **URL**: `{{baseUrl}}/api/v1/auth/signup`
- **Headers**: `Content-Type: application/json`
- **Body (raw JSON)**:
```json
{
  "email": "test@example.com",
  "password": "SecurePass123!",
  "firstName": "Test",
  "lastName": "User",
  "companyName": "Test Company",
  "phone": "+1234567890"
}
```

---

## Troubleshooting

### Issue: 401 Unauthorized
**Cause**: Endpoint requires authentication
**Fix**: `/check-domain` should be public. Check SecurityConfig.java:
```java
.requestMatchers("/api/v1/auth/check-domain").permitAll()
```

### Issue: Domain not found error
**Cause**: Migration V2 not applied
**Fix**:
```bash
# Check migration status
psql -h localhost -U hrms_user -d hrms_db -c "SELECT * FROM flyway_schema_history;"

# Restart Spring Boot to apply migration
```

### Issue: All domains return available=false
**Cause**: Database connection issue or empty domain_master table
**Fix**:
```sql
-- Check if public domains exist
SELECT COUNT(*) FROM domain_master WHERE is_public = true;
-- Should return 10

-- If 0, migration didn't run properly
```

### Issue: Signup succeeds but domain not locked
**Cause**: Transaction rollback or service error
**Check logs**:
```bash
tail -f logs/spring-boot-application.log | grep -i domain
```

---

## Success Criteria

✅ Public domains (gmail.com) always show `available=true, isPublic=true`
✅ New corporate domains show `available=true, isPublic=false`
✅ Locked corporate domains show `available=false, isPublic=false`
✅ First signup locks corporate domain
✅ Second signup with same domain is blocked
✅ Multiple users can signup with public domains
✅ Domain matching is case-insensitive
✅ Database shows correct is_locked and registered_tenant_id

---

## Next Steps After Testing

1. ✅ Verify all tests pass
2. 📝 Document any issues found
3. 🔄 Commit working changes
4. 🚀 Share API docs with Frontend team
5. 👥 Train support team on domain validation rules

---

**Questions?** Check the other documentation:
- `domain-validation-frontend-05-nov-2025.md` - Frontend integration
- `domain-validation-dba-05-nov-2025.md` - Database details
- `domain-validation-business-05-nov-2025.md` - Business rules
