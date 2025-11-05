# Multi-Tenant Testing Guide 🧪

**Date**: November 4, 2025
**Version**: 1.0

---

## 📋 Prerequisites

Before testing, ensure:
- ✅ PostgreSQL is running (port 5432)
- ✅ Keycloak is running (port 8090)
- ✅ Database `hrms_saas` exists
- ✅ Keycloak realm `hrms-saas` is configured
- ✅ Keycloak client `hrms-web-app` with correct secret
- ✅ At least one test user exists in Keycloak with tenant_id attribute

---

## 🚀 Start Spring Boot Application

```bash
cd /Users/rameshbabu/data/projects/systech/hrms-saas/springboot

# Option 1: Using Maven
mvn spring-boot:run

# Option 2: Using JAR (after mvn package)
java -jar target/hrms-saas-backend-1.0.0-SNAPSHOT.jar

# Check logs for:
# - "TenantFilter initialized"
# - "TenantFilter registered successfully"
# - "Keycloak Admin Client initialized successfully"
```

**Expected Startup Logs**:
```
INFO TenantFilter - TenantFilter initialized - will extract tenant_id from JWT tokens
INFO FilterConfig - Registering TenantFilter with order 2 (after SecurityFilter)
INFO FilterConfig - TenantFilter registered successfully
INFO KeycloakAdminService - Keycloak Admin Client initialized successfully
INFO HrmsSaasApplication - Started HrmsSaasApplication in 3.5 seconds
```

---

## 🧪 Test 1: Create Test User (If Not Exists)

### Using Existing Sign-Up Endpoint

```bash
curl -X POST http://localhost:8081/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPassword123!",
    "companyName": "Test Company Ltd",
    "firstName": "Test",
    "lastName": "User",
    "phone": "+1234567890"
  }' | jq .
```

**Expected Response**:
```json
{
  "success": true,
  "message": "Account created successfully. Please verify your email to continue.",
  "tenantId": "a3b9c8d2e1f4",
  "userId": "226f442e-c931-4119-90d8-09435b2de2cf",
  "requiresEmailVerification": true
}
```

**Verify in Keycloak**:
1. Open http://localhost:8090/admin
2. Login: admin / secret
3. Select Realm: hrms-saas
4. Users → View all users
5. Click on "testuser@example.com"
6. Go to "Attributes" tab
7. Verify: `tenant_id`, `company_id`, `user_type`, `company_name` are set

---

## 🔑 Test 2: Get JWT Token

```bash
# Get access token
TOKEN=$(curl -s -X POST "http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=hrms-web-app" \
  -d "client_secret=xE39L2zsTFkOjmAt47ToFQRwgIekjW3l" \
  -d "username=testuser@example.com" \
  -d "password=TestPassword123!" | jq -r '.access_token')

# Check if token was retrieved
echo "Token: ${TOKEN:0:50}..."

# Decode JWT to see claims (requires jq)
echo $TOKEN | cut -d '.' -f 2 | base64 -d | jq .
```

**Expected JWT Claims**:
```json
{
  "exp": 1699105200,
  "iat": 1699101600,
  "iss": "http://localhost:8090/realms/hrms-saas",
  "sub": "226f442e-c931-4119-90d8-09435b2de2cf",
  "email": "testuser@example.com",
  "email_verified": false,
  "name": "Test User",
  "given_name": "Test",
  "family_name": "User",
  "realm_access": {
    "roles": ["company_admin", "offline_access"]
  },
  "tenant_id": "a3b9c8d2e1f4",
  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_type": "company_admin",
  "company_name": "Test Company Ltd"
}
```

**Critical**: Verify `tenant_id`, `company_id`, `user_type`, `company_name` are present!

---

## 🧪 Test 3: User Profile Endpoint

### Test GET /api/v1/user/profile

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/api/v1/user/profile | jq .
```

**Expected Response**:
```json
{
  "userId": "226f442e-c931-4119-90d8-09435b2de2cf",
  "email": "testuser@example.com",
  "name": "Test User",
  "firstName": "Test",
  "lastName": "User",
  "tenantId": "a3b9c8d2e1f4",
  "companyId": "550e8400-e29b-41d4-a716-446655440000",
  "userType": "company_admin",
  "companyName": "Test Company Ltd",
  "companyCode": null,
  "employeeId": null,
  "phone": "+1234567890",
  "roles": ["company_admin", "offline_access"],
  "contextTenantId": "a3b9c8d2e1f4",
  "dbTenantId": "a3b9c8d2e1f4",
  "tenantContextMatch": true
}
```

**✅ Success Criteria**:
1. `tenantId` is not null (from JWT)
2. `contextTenantId` equals `tenantId` (from ThreadLocal)
3. `dbTenantId` equals `tenantId` (from PostgreSQL session)
4. `tenantContextMatch` is `true`

**❌ If tenantContextMatch is false**:
- Check TenantFilter is registered
- Check DatabaseTenantManager is being called
- Check Spring Boot logs for errors

---

## 🧪 Test 4: Tenant Info Endpoint

### Test GET /api/v1/user/tenant-info

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/api/v1/user/tenant-info | jq .
```

**Expected Response**:
```json
{
  "jwtTenantId": "a3b9c8d2e1f4",
  "contextTenantId": "a3b9c8d2e1f4",
  "dbTenantId": "a3b9c8d2e1f4",
  "allMatch": true,
  "timestamp": 1699105200000,
  "requestedBy": "testuser@example.com"
}
```

**✅ Success Criteria**:
- `allMatch` is `true`
- All three tenant IDs match

---

## 🧪 Test 5: JWT Claims Endpoint

### Test GET /api/v1/user/jwt-claims

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/api/v1/user/jwt-claims | jq .
```

**Expected**: Complete JWT claims object

**Use this to verify**:
- All required custom claims are present
- Protocol mappers are configured correctly in Keycloak

---

## 🧪 Test 6: Test Without JWT (Should Fail)

### Attempt to access protected endpoint without token

```bash
curl -s http://localhost:8081/api/v1/user/profile | jq .
```

**Expected Response**: 401 Unauthorized
```json
{
  "timestamp": "2025-11-04T12:00:00.000+00:00",
  "status": 401,
  "error": "Unauthorized",
  "path": "/api/v1/user/profile"
}
```

---

## 🧪 Test 7: Verify Logs

### Check Spring Boot logs for tenant context

**Look for these log entries**:
```
DEBUG TenantFilter - Tenant context set for request: /api/v1/user/profile - tenantId: a3b9c8d2e1f4
DEBUG DatabaseTenantManager - PostgreSQL session variable set: app.current_tenant_id = a3b9c8d2e1f4
INFO  UserController - Fetching user profile for: testuser@example.com
INFO  UserController - User profile built: tenantId=a3b9c8d2e1f4, userType=company_admin, contextMatch=true
DEBUG TenantFilter - Tenant context cleared: a3b9c8d2e1f4 for request: /api/v1/user/profile
```

**✅ Critical Checks**:
1. Tenant context SET before request processing
2. PostgreSQL session variable SET
3. Tenant context CLEARED after request

---

## 🧪 Test 8: Multi-Tenant Isolation (Advanced)

### Create second test user with different tenant

```bash
# Sign up second user
curl -X POST http://localhost:8081/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user2@company2.com",
    "password": "TestPassword123!",
    "companyName": "Company 2",
    "firstName": "User",
    "lastName": "Two"
  }' | jq .
```

### Get token for second user

```bash
TOKEN2=$(curl -s -X POST "http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=hrms-web-app" \
  -d "client_secret=xE39L2zsTFkOjmAt47ToFQRwgIekjW3l" \
  -d "username=user2@company2.com" \
  -d "password=TestPassword123!" | jq -r '.access_token')
```

### Compare tenant IDs

```bash
# User 1 tenant
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/api/v1/user/tenant-info | jq '.jwtTenantId'

# User 2 tenant (should be different)
curl -s -H "Authorization: Bearer $TOKEN2" \
  http://localhost:8081/api/v1/user/tenant-info | jq '.jwtTenantId'
```

**✅ Success**: Two different tenant IDs returned

---

## 🧪 Test 9: Database Session Verification

### Connect to PostgreSQL and check session variable

```bash
# Connect to database
psql -h localhost -U admin -d hrms_saas

# In psql, run:
SELECT current_setting('app.current_tenant_id', true);

# Should return NULL (no active request)
# During an active request, it would show the tenant_id
```

**Note**: Session variable is request-scoped, so it's only set during active HTTP requests.

---

## 🧪 Test 10: Performance Test (Optional)

### Test concurrent requests

```bash
# Install Apache Bench if not available
# brew install httpd

# Run 100 requests, 10 concurrent
ab -n 100 -c 10 \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/api/v1/user/tenant-info
```

**Check for**:
- No memory leaks (check logs)
- All requests return same tenant_id
- No context bleeding between requests

---

## 📊 Expected Behavior Summary

| Test | Expected Result |
|------|----------------|
| Sign-up | ✅ Creates user with tenant_id attribute |
| JWT token | ✅ Contains tenant_id, company_id, user_type claims |
| /user/profile | ✅ All three tenant IDs match |
| /user/tenant-info | ✅ allMatch = true |
| Without JWT | ✅ 401 Unauthorized |
| Logs | ✅ Context set → cleared |
| Multi-tenant | ✅ Different users = different tenant IDs |

---

## 🐛 Troubleshooting

### Issue: tenantContextMatch is false

**Possible Causes**:
1. TenantFilter not running
2. DatabaseTenantManager not called
3. PostgreSQL function `set_config` failing

**Solutions**:
```bash
# 1. Check TenantFilter is registered
grep "TenantFilter registered" logs/spring-boot.log

# 2. Check logs for tenant context
grep "Tenant context set" logs/spring-boot.log

# 3. Check PostgreSQL logs
podman logs nexus-postgres-dev
```

---

### Issue: JWT missing tenant_id claim

**Possible Causes**:
1. User doesn't have tenant_id attribute in Keycloak
2. Protocol mapper not configured
3. Wrong client selected

**Solutions**:
1. Verify user attributes in Keycloak Admin Console
2. Check protocol mappers exist in client `hrms-web-app`
3. Regenerate token (old tokens won't have new claims)

---

### Issue: 401 Unauthorized with valid token

**Possible Causes**:
1. Token expired (5 min default)
2. Wrong client secret
3. Issuer mismatch

**Solutions**:
```bash
# 1. Check token expiration
echo $TOKEN | cut -d '.' -f 2 | base64 -d | jq '.exp'

# 2. Verify client secret in application.yml
grep "client.secret" src/main/resources/application.yml

# 3. Check issuer matches
echo $TOKEN | cut -d '.' -f 2 | base64 -d | jq '.iss'
```

---

## ✅ Acceptance Criteria

Before marking testing complete, verify:

- [ ] Spring Boot starts without errors
- [ ] TenantFilter is registered (check logs)
- [ ] JWT token contains all custom claims
- [ ] /user/profile returns data with matching tenant IDs
- [ ] tenantContextMatch = true
- [ ] Logs show context set and cleared
- [ ] Unauthorized access returns 401
- [ ] Multiple users have different tenant IDs
- [ ] No memory leaks after 100+ requests

---

## 📝 Test Report Template

```markdown
## Multi-Tenant Testing Report

**Date**: YYYY-MM-DD
**Tester**: [Name]
**Environment**: Development/QA/Staging

### Test Results

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Create Test User | ✅ / ❌ | |
| 2 | Get JWT Token | ✅ / ❌ | |
| 3 | User Profile Endpoint | ✅ / ❌ | |
| 4 | Tenant Info Endpoint | ✅ / ❌ | |
| 5 | JWT Claims | ✅ / ❌ | |
| 6 | Unauthorized Access | ✅ / ❌ | |
| 7 | Verify Logs | ✅ / ❌ | |
| 8 | Multi-Tenant Isolation | ✅ / ❌ | |
| 9 | Database Session | ✅ / ❌ | |
| 10 | Performance Test | ✅ / ❌ | |

### Issues Found
- [List any issues]

### Overall Status
✅ PASSED / ❌ FAILED

### Notes
[Additional notes]
```

---

## 🎯 Next Steps After Testing

If all tests pass:
1. ✅ Mark multi-tenant implementation as complete
2. ✅ Begin implementing business logic (Employee, Department CRUD)
3. ✅ Integrate DatabaseTenantManager in all services
4. ✅ Add @PreAuthorize annotations for role-based access
5. ✅ Create comprehensive unit tests

---

**Happy Testing! 🚀**
