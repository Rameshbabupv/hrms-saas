# Keycloak Team Notes
## SaaS HRMS MVP - Authentication & Authorization Setup

**Document Version:** 1.0
**Date:** 2025-10-29
**Target Audience:** Keycloak Implementation Team
**Project:** HRMS SaaS - Company Master & Employee Master MVP
**Related Document:** `KEYCLOAK_IMPLEMENTATION_GUIDE.md` (detailed version)

---

## Table of Contents

1. [Quick Start Summary](#quick-start-summary)
2. [Critical Requirements](#critical-requirements)
3. [Implementation Checklist](#implementation-checklist)
4. [JWT Token Structure](#jwt-token-structure)
5. [User Provisioning Workflow](#user-provisioning-workflow)
6. [Testing Procedures](#testing-procedures)
7. [Handoff to Other Teams](#handoff-to-other-teams)

---

## 1. Quick Start Summary

### What You're Building
A multi-tenant SSO authentication system using Keycloak for a SaaS HRMS platform supporting corporate hierarchies.

### Key Deliverables
1. ✅ Keycloak Realm: `hrms-saas`
2. ✅ Client: `hrms-web-app` (web application)
3. ✅ JWT tokens with custom claims (`company_id`, `employee_id`, etc.)
4. ✅ 5 realm roles (super_admin, company_admin, hr_user, manager, employee)
5. ✅ User attributes for multi-tenancy

### Timeline
- **Day 1-2:** Realm and client setup
- **Day 3-4:** Custom mappers and role configuration
- **Day 5:** User creation and testing
- **Day 6:** Integration testing with backend team
- **Day 7:** Documentation and handoff

---

## 2. Critical Requirements

### 2.1 Multi-Tenancy Strategy

**CRITICAL:** Single realm for ALL tenants

```
Keycloak Realm: "hrms-saas"
└── All users from all companies
    ├── User Attribute: company_id = "uuid-of-company-a"
    ├── User Attribute: company_id = "uuid-of-company-b"
    └── User Attribute: company_id = "uuid-of-company-c"
```

**Why Single Realm?**
- ✅ Easier management (1 realm vs 1000 realms for 1000 companies)
- ✅ Lower resource usage
- ✅ Tenant isolation via `company_id` attribute in JWT token

### 2.2 JWT Token Must Contain

**CRITICAL CUSTOM CLAIMS (Required by Backend):**

| Claim Name | Source | Required | Example Value |
|------------|--------|----------|---------------|
| `company_id` | User attribute | ✅ YES | `550e8400-e29b-41d4-a716-446655440000` |
| `tenant_id` | User attribute | ✅ YES | `550e8400-e29b-41d4-a716-446655440000` (same as company_id) |
| `employee_id` | User attribute | ⚠️ Optional | `660e8400-e29b-41d4-a716-446655440001` |
| `user_type` | User attribute | ✅ YES | `employee`, `hr_user`, `company_admin` |
| `company_code` | User attribute | Optional | `DEMO001`, `ABC-HOLD` |
| `company_name` | User attribute | Optional | `Demo Tech Solutions` |

**Why These Claims Matter:**
- Backend uses `company_id` to set PostgreSQL Row-Level Security context
- Without `company_id`, backend cannot filter data by tenant
- Data leakage will occur if `company_id` is missing or wrong

### 2.3 User Roles Required

**Create these 5 realm roles:**

| Role Name | Description | Use Case |
|-----------|-------------|----------|
| `super_admin` | System administrator | Anthropic support, platform admin |
| `company_admin` | Company administrator | HR head, company owner |
| `hr_user` | HR department user | HR managers, HR executives |
| `manager` | Team manager | Department managers, team leads |
| `employee` | Regular employee | All employees (default role) |

**Role Hierarchy (Optional):**
```
super_admin (includes all below)
└── company_admin (includes all below)
    └── hr_user (includes all below)
        └── manager (includes all below)
            └── employee (base role)
```

---

## 3. Implementation Checklist

### Phase 1: Realm Setup ✅

- [ ] **Create Realm:** `hrms-saas`
  - Display Name: `HRMS SaaS Platform`
  - Enabled: `ON`

- [ ] **Login Settings:**
  - User Registration: `OFF` (admin-only user creation)
  - Forgot Password: `ON`
  - Remember Me: `ON`
  - Verify Email: `ON`
  - Login with Email: `ON`

- [ ] **Token Settings:**
  - Access Token Lifespan: `30 minutes`
  - SSO Session Idle: `1 hour`
  - SSO Session Max: `10 hours`
  - Refresh Token: `7 days` (or session-based)

- [ ] **Email Configuration:**
  - SMTP Host: `smtp.gmail.com` (or company SMTP)
  - Port: `587`
  - From: `noreply@yourdomain.com`
  - **Test Email:** Send test email to verify setup

- [ ] **Security Defenses:**
  - Brute Force Detection: `ON`
  - Max Login Failures: `5`
  - Wait Increment: `60 seconds`

### Phase 2: Client Configuration ✅

- [ ] **Create Client:** `hrms-web-app`
  - Client Type: `OpenID Connect`
  - Client Authentication: `ON` (confidential client)

- [ ] **Authentication Flow:**
  - ✅ Standard Flow (Authorization Code)
  - ✅ Direct Access Grants (for testing)
  - ❌ Implicit Flow (disabled)

- [ ] **Login Settings:**
  - Root URL: `https://hrms.yourdomain.com`
  - Valid Redirect URIs:
    - `https://hrms.yourdomain.com/*`
    - `http://localhost:3000/*` (dev)
  - Web Origins: `+` (allow all redirect URIs)

- [ ] **Get Client Secret:**
  - Navigate to: Credentials tab
  - Copy secret (format: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
  - **Share with backend team securely**

### Phase 3: Custom JWT Mappers (CRITICAL) ✅

Navigate to: **Clients → hrms-web-app → Client Scopes → hrms-web-app-dedicated → Mappers**

**Create 7 Custom Mappers:**

1. **company_id Mapper**
   - Mapper Type: `User Attribute`
   - User Attribute: `company_id`
   - Token Claim Name: `company_id`
   - Claim JSON Type: `String`
   - Add to access token: `ON` ✅
   - Add to ID token: `ON` ✅

2. **tenant_id Mapper**
   - Mapper Type: `User Attribute`
   - User Attribute: `tenant_id`
   - Token Claim Name: `tenant_id`
   - Add to access token: `ON` ✅

3. **employee_id Mapper**
   - Mapper Type: `User Attribute`
   - User Attribute: `employee_id`
   - Token Claim Name: `employee_id`
   - Add to access token: `ON` ✅

4. **user_type Mapper**
   - Mapper Type: `User Attribute`
   - User Attribute: `user_type`
   - Token Claim Name: `user_type`
   - Add to access token: `ON` ✅

5. **company_code Mapper**
   - User Attribute: `company_code`
   - Token Claim Name: `company_code`
   - Add to access token: `ON` ✅

6. **company_name Mapper**
   - User Attribute: `company_name`
   - Token Claim Name: `company_name`
   - Add to access token: `ON` ✅

7. **phone Mapper**
   - User Attribute: `phone`
   - Token Claim Name: `phone`
   - Add to access token: `ON` ✅

**Verify:** Built-in `realm roles` mapper exists (adds roles to token)

### Phase 4: Realm Roles ✅

- [ ] Create role: `super_admin`
- [ ] Create role: `company_admin`
- [ ] Create role: `hr_user`
- [ ] Create role: `manager`
- [ ] Create role: `employee`
- [ ] Set `employee` as **default role**

### Phase 5: Test User Creation ✅

**Create 2 test users for integration testing:**

**Test User 1: Company Admin**
```yaml
Username: admin@testcompany.com
Email: admin@testcompany.com
First Name: Admin
Last Name: User
Enabled: ON
Email Verified: ON

Attributes:
  company_id: "550e8400-e29b-41d4-a716-446655440000"  # Use actual UUID from DB
  tenant_id: "550e8400-e29b-41d4-a716-446655440000"
  user_type: "company_admin"
  company_code: "TEST001"
  company_name: "Test Company Ltd"

Credentials:
  Password: TestAdmin@123
  Temporary: OFF

Roles:
  - company_admin
```

**Test User 2: Regular Employee**
```yaml
Username: john.doe@testcompany.com
Email: john.doe@testcompany.com
First Name: John
Last Name: Doe
Enabled: ON
Email Verified: ON

Attributes:
  company_id: "550e8400-e29b-41d4-a716-446655440000"  # Same company as admin
  tenant_id: "550e8400-e29b-41d4-a716-446655440000"
  employee_id: "660e8400-e29b-41d4-a716-446655440001"  # Use actual employee UUID from DB
  user_type: "employee"
  company_code: "TEST001"
  company_name: "Test Company Ltd"
  phone: "+91-9876543210"

Credentials:
  Password: TestUser@123
  Temporary: OFF

Roles:
  - employee
```

---

## 4. JWT Token Structure

### 4.1 Expected Token Output

After configuration, tokens should look like this:

```json
{
  "exp": 1698767232,
  "iat": 1698765432,
  "jti": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "iss": "https://auth.yourdomain.com/realms/hrms-saas",
  "aud": "hrms-web-app",
  "sub": "user-uuid-from-keycloak",
  "typ": "Bearer",
  "azp": "hrms-web-app",

  "realm_access": {
    "roles": ["employee", "manager"]
  },

  "email_verified": true,
  "preferred_username": "john.doe@company.com",
  "given_name": "John",
  "family_name": "Doe",
  "email": "john.doe@company.com",

  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "employee_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_type": "employee",
  "company_code": "TEST001",
  "company_name": "Test Company Ltd",
  "phone": "+91-9876543210"
}
```

### 4.2 Verify Token Claims

**Use jwt.io to decode tokens:**

1. Get token using curl:
```bash
curl -X POST 'https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'client_id=hrms-web-app' \
  -d 'client_secret=<your-client-secret>' \
  -d 'username=john.doe@testcompany.com' \
  -d 'password=TestUser@123' \
  -d 'scope=openid'
```

2. Copy `access_token` from response
3. Go to https://jwt.io
4. Paste token
5. Verify all custom claims are present

---

## 5. User Provisioning Workflow

### 5.1 New Company Sign-Up Flow

**When a new company registers on the platform:**

**Step 1:** Backend creates company in PostgreSQL
```sql
-- Backend executes this
INSERT INTO company (company_name, company_code, email, ...)
VALUES ('New Corp', 'NEWCORP', 'admin@newcorp.com', ...)
RETURNING id;  -- Returns company_id (UUID)
```

**Step 2:** Backend calls Keycloak Admin API to create admin user

**API Endpoint:** `POST /admin/realms/hrms-saas/users`

**Request:**
```json
{
  "username": "admin@newcorp.com",
  "email": "admin@newcorp.com",
  "firstName": "Admin",
  "lastName": "User",
  "enabled": true,
  "emailVerified": false,
  "attributes": {
    "company_id": ["<uuid-from-step1>"],
    "tenant_id": ["<uuid-from-step1>"],
    "user_type": ["company_admin"],
    "company_code": ["NEWCORP"],
    "company_name": ["New Corp"]
  },
  "credentials": [{
    "type": "password",
    "value": "TempPassword@123",
    "temporary": true
  }],
  "realmRoles": ["company_admin"],
  "requiredActions": ["VERIFY_EMAIL", "UPDATE_PASSWORD"]
}
```

**Step 3:** Send verification email
```
PUT /admin/realms/hrms-saas/users/<user-id>/send-verify-email
```

**Step 4:** Backend stores mapping in PostgreSQL
```sql
INSERT INTO user_account (keycloak_user_id, username, email, company_id, ...)
VALUES ('<keycloak-uuid>', 'admin@newcorp.com', 'admin@newcorp.com', '<company-uuid>', ...);
```

### 5.2 Add Employee User Flow

**When HR admin adds a new employee:**

**Step 1:** Backend creates employee record
```sql
INSERT INTO employee (company_id, employee_code, employee_name, email, ...)
VALUES ('<company-uuid>', 'EMP001', 'Jane Smith', 'jane@newcorp.com', ...)
RETURNING id;  -- Returns employee_id
```

**Step 2:** Backend calls Keycloak Admin API
```json
{
  "username": "jane@newcorp.com",
  "email": "jane@newcorp.com",
  "firstName": "Jane",
  "lastName": "Smith",
  "enabled": true,
  "emailVerified": false,
  "attributes": {
    "company_id": ["<company-uuid>"],
    "tenant_id": ["<company-uuid>"],
    "employee_id": ["<employee-uuid-from-step1>"],
    "user_type": ["employee"],
    "company_code": ["NEWCORP"],
    "company_name": ["New Corp"]
  },
  "credentials": [{
    "type": "password",
    "value": "Welcome@123",
    "temporary": true
  }],
  "realmRoles": ["employee"],
  "requiredActions": ["VERIFY_EMAIL", "UPDATE_PASSWORD"]
}
```

### 5.3 User Deactivation Flow

**When employee leaves:**

**Step 1:** Backend disables user in Keycloak
```
PUT /admin/realms/hrms-saas/users/<user-id>
Body: { "enabled": false }
```

**Step 2:** Revoke active sessions
```
POST /admin/realms/hrms-saas/users/<user-id>/logout
```

---

## 6. Testing Procedures

### 6.1 Manual Testing Checklist

**Test 1: User Login ✅**
```bash
curl -X POST 'https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'client_id=hrms-web-app' \
  -d 'client_secret=<client-secret>' \
  -d 'username=john.doe@testcompany.com' \
  -d 'password=TestUser@123'
```

**Expected:** Access token, refresh token, ID token returned

**Test 2: Token Contains Custom Claims ✅**
- Decode token at jwt.io
- Verify `company_id` exists
- Verify `tenant_id` exists
- Verify `employee_id` exists (if user is employee)
- Verify `user_type` exists
- Verify `realm_access.roles` contains correct roles

**Test 3: Token Refresh ✅**
```bash
curl -X POST 'https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=refresh_token' \
  -d 'client_id=hrms-web-app' \
  -d 'client_secret=<client-secret>' \
  -d 'refresh_token=<refresh-token>'
```

**Expected:** New access token with same custom claims

**Test 4: Multi-Tenancy Isolation ✅**
- Create User A with `company_id=uuid-A`
- Create User B with `company_id=uuid-B`
- Login as User A, verify token has `uuid-A`
- Login as User B, verify token has `uuid-B`
- Tokens should have DIFFERENT `company_id` values

**Test 5: Email Verification ✅**
- Create user with `emailVerified=false`
- Trigger send verification email
- Check email inbox
- Click verification link
- Verify email marked as verified in Keycloak

**Test 6: Logout ✅**
```bash
curl -X POST 'https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/logout' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'client_id=hrms-web-app' \
  -d 'client_secret=<client-secret>' \
  -d 'refresh_token=<refresh-token>'
```

**Expected:** Tokens invalidated, re-login required

### 6.2 Integration Testing with Backend

**Coordinate with Spring Boot team:**

1. **Provide JWKS URL:**
   ```
   https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/certs
   ```

2. **Provide Test Tokens:**
   - Generate access token for test user
   - Share token with backend team
   - Backend team validates token signature
   - Backend team extracts `company_id` claim

3. **Test Tenant Context:**
   - Backend sets PostgreSQL session variable from `company_id`
   - Backend queries employee table
   - Verify RLS filters data correctly

4. **Test Role-Based Access:**
   - `company_admin` token should allow admin APIs
   - `employee` token should reject admin APIs

---

## 7. Handoff to Other Teams

### 7.1 Information for Spring Boot Team

**Provide these values securely:**

```properties
# Keycloak Server Configuration
keycloak.url=https://auth.yourdomain.com
keycloak.realm=hrms-saas
keycloak.client-id=hrms-web-app
keycloak.client-secret=<actual-client-secret>

# JWT Validation
keycloak.jwks-url=https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/certs
keycloak.issuer=https://auth.yourdomain.com/realms/hrms-saas

# Admin API (for user provisioning)
keycloak.admin.username=<admin-username>
keycloak.admin.password=<admin-password>
keycloak.admin.client-id=admin-cli
```

**What Backend Team Needs to Do:**
1. Validate JWT tokens using JWKS endpoint
2. Extract `company_id` from token
3. Call `SELECT set_current_tenant('<company_id>')` for every request
4. Use Keycloak Admin API for user provisioning

### 7.2 Information for React Team

**Provide keycloak.json:**

```json
{
  "realm": "hrms-saas",
  "url": "https://auth.yourdomain.com",
  "clientId": "hrms-web-app",
  "ssl-required": "external",
  "public-client": false,
  "confidential-port": 0
}
```

**What Frontend Team Needs to Do:**
1. Install `keycloak-js` and `@react-keycloak/web` libraries
2. Initialize Keycloak on app load
3. Store access token in localStorage/sessionStorage
4. Add token to Authorization header for all API calls
5. Handle token refresh (30-minute expiry)
6. Implement logout flow

**Example Frontend Code:**
```javascript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'https://auth.yourdomain.com',
  realm: 'hrms-saas',
  clientId: 'hrms-web-app'
});

keycloak.init({ onLoad: 'login-required' }).then(authenticated => {
  if (authenticated) {
    // Store token
    localStorage.setItem('access_token', keycloak.token);

    // Decode token to get company_id
    const decoded = jwt_decode(keycloak.token);
    console.log('Company ID:', decoded.company_id);
  }
});
```

### 7.3 Information for DBA Team

**No direct Keycloak-Database integration needed.**

**However, coordinate on:**
- User attribute values (`company_id`, `employee_id`) must match database UUIDs exactly
- Backend team handles sync between Keycloak users and `user_account` table in PostgreSQL

### 7.4 Information for DevOps Team

**Deployment Requirements:**

1. **SSL Certificate:**
   - Keycloak MUST be accessible via HTTPS
   - Domain: `auth.yourdomain.com`

2. **Reverse Proxy (Nginx):**
```nginx
server {
    listen 443 ssl;
    server_name auth.yourdomain.com;

    ssl_certificate /etc/ssl/certs/auth.yourdomain.com.crt;
    ssl_certificate_key /etc/ssl/private/auth.yourdomain.com.key;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

3. **Firewall Rules:**
   - Allow port 8080 (Keycloak) only from reverse proxy
   - Allow port 443 (HTTPS) from internet

4. **Backup Keycloak Database:**
   - Keycloak uses its own database (H2/PostgreSQL/MySQL)
   - Schedule daily backups
   - Test restore procedure

---

## Appendix

### A. Admin API Quick Reference

**Base URL:** `https://auth.yourdomain.com/admin/realms/hrms-saas`

**Get Admin Token:**
```bash
curl -X POST 'https://auth.yourdomain.com/realms/master/protocol/openid-connect/token' \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' \
  -d 'username=<admin>' \
  -d 'password=<password>'
```

**Create User:** `POST /users`
**Get User:** `GET /users/{user-id}`
**Update User:** `PUT /users/{user-id}`
**Delete User:** `DELETE /users/{user-id}`
**Reset Password:** `PUT /users/{user-id}/reset-password`
**Send Verify Email:** `PUT /users/{user-id}/send-verify-email`
**Logout User:** `POST /users/{user-id}/logout`

### B. Troubleshooting

**Issue 1: Custom claims not in token**
- Check client mappers are configured
- Verify user has attributes set
- Ensure mapper is added to access token (not just ID token)

**Issue 2: CORS errors**
- Add frontend URL to Web Origins in client settings
- Use `+` to allow all redirect URIs

**Issue 3: Token validation fails**
- Verify JWKS endpoint is accessible
- Check issuer claim matches exactly
- Verify clock sync between servers

**Issue 4: Email not sending**
- Check SMTP configuration
- Test email connection from Keycloak admin
- Check spam folder

### C. Contact Information

| Role | Contact | Purpose |
|------|---------|---------|
| Spring Boot Team | <backend-email> | JWT validation, Admin API integration |
| React Team | <frontend-email> | Login flow, token management |
| DBA Team | <dba-email> | User ID coordination |
| DevOps Team | <devops-email> | SSL, domain, deployment |

### D. Document References

- **Detailed Guide:** `KEYCLOAK_IMPLEMENTATION_GUIDE.md` (200+ sections)
- **DBA Guide:** `DBA_NOTES.md`
- **Backend Guide:** `SPRINGBOOT_NOTES.md` (coming soon)
- **Frontend Guide:** `REACTAPP_NOTES.md` (coming soon)

---

**End of Keycloak Team Notes**

✅ **Status:** Ready for implementation
📅 **Target Completion:** 7 days
🔗 **Dependencies:** Domain setup (DevOps), Database ready (DBA)

For detailed implementation steps, refer to `KEYCLOAK_IMPLEMENTATION_GUIDE.md`.
