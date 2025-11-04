# Keycloak Implementation Guide for HRMS SaaS Application

**Document Version:** 1.0
**Date:** 2025-10-29
**Target Audience:** Keycloak Implementation Team
**Project:** HRMS SaaS - Company Master & Employee Master MVP

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Realm Configuration](#realm-configuration)
4. [Client Configuration](#client-configuration)
5. [User Management](#user-management)
6. [Role & Permission Setup](#role--permission-setup)
7. [JWT Token Configuration](#jwt-token-configuration)
8. [Multi-Tenancy Implementation](#multi-tenancy-implementation)
9. [User Provisioning Workflow](#user-provisioning-workflow)
10. [Security Requirements](#security-requirements)
11. [API Endpoints for Backend Team](#api-endpoints-for-backend-team)
12. [Testing & Validation](#testing--validation)
13. [Appendix](#appendix)

---

## 1. Executive Summary

### Purpose
This document provides complete specifications for implementing Keycloak SSO authentication for a multi-tenant SaaS HRMS application. The Keycloak team must configure realms, clients, user attributes, and custom JWT claims to support multi-tenant isolation.

### Key Requirements
- **Multi-Tenant Architecture:** Single Keycloak realm supporting multiple companies (tenants)
- **JWT Token-Based Authentication:** OAuth 2.0 / OpenID Connect
- **Custom Claims:** Include `company_id`, `tenant_id`, `employee_id` in JWT tokens
- **Role-Based Access Control:** Support for 5 user roles
- **User Provisioning:** Automated user creation via Admin API
- **Session Management:** Token lifecycle and refresh token handling

### Success Criteria
- ✅ Users can login and receive JWT tokens with tenant context
- ✅ JWT tokens contain all required custom claims
- ✅ Multi-tenant isolation works (users cannot access other tenants' data)
- ✅ Backend team can validate tokens and extract tenant context
- ✅ Frontend team can integrate Keycloak login flow

---

## 2. Architecture Overview

### High-Level Architecture

```
┌─────────────────┐
│  React Frontend │
│  (Port 3000)    │
└────────┬────────┘
         │ 1. Login Request
         ▼
┌─────────────────────────┐
│  Keycloak Server        │
│  (Port 8080)            │
│  Realm: hrms-saas       │
└────────┬────────────────┘
         │ 2. JWT Token (with company_id)
         ▼
┌─────────────────────────┐
│  Spring Boot Backend    │
│  (Port 8081)            │
│  - Validates JWT        │
│  - Extracts company_id  │
│  - Sets tenant context  │
└────────┬────────────────┘
         │ 3. Query with RLS
         ▼
┌─────────────────────────┐
│  PostgreSQL Database    │
│  - Row Level Security   │
│  - Filters by tenant    │
└─────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **Keycloak** | User authentication, JWT token generation, SSO, user management |
| **Frontend** | Login UI, token storage, token refresh, logout |
| **Backend** | Token validation, tenant context extraction, API authorization |
| **Database** | Data storage with tenant isolation (RLS) |

---

## 3. Realm Configuration

### 3.1 Create Realm

**Realm Name:** `hrms-saas`

**Steps:**
1. Login to Keycloak Admin Console
2. Click "Add Realm" (top-left dropdown)
3. Set Name: `hrms-saas`
4. Display Name: `HRMS SaaS Platform`
5. Enabled: `ON`
6. Click "Create"

### 3.2 Realm Settings

Navigate to: **Realm Settings** → **General**

```yaml
Display Name: HRMS SaaS Platform
HTML Display Name: <strong>HRMS</strong> SaaS Platform
Frontend URL: https://auth.yourdomain.com  # Public-facing Keycloak URL
Require SSL: all requests
User Managed Access: OFF
Endpoints: https://auth.yourdomain.com/realms/hrms-saas
```

### 3.3 Login Settings

Navigate to: **Realm Settings** → **Login**

```yaml
User Registration: OFF  # Only admins can create users
Edit Username: OFF
Forgot Password: ON
Remember Me: ON
Verify Email: ON
Login with Email: ON
Duplicate Emails: OFF  # Email must be unique
```

### 3.4 Email Settings

Navigate to: **Realm Settings** → **Email**

```yaml
From: noreply@yourdomain.com
From Display Name: HRMS Platform
Reply To: support@yourdomain.com
Reply To Display Name: HRMS Support
Envelope From: noreply@yourdomain.com

Host: smtp.gmail.com  # Or your SMTP server
Port: 587
Encryption: StartTLS
Authentication: ON
Username: your-smtp-username
Password: your-smtp-password
```

**Test Email:** Click "Save" then "Test Connection"

### 3.5 Token Settings

Navigate to: **Realm Settings** → **Tokens**

```yaml
Default Signature Algorithm: RS256

# Access Token Lifespan
Access Token Lifespan: 30 minutes
Access Token Lifespan For Implicit Flow: 15 minutes

# SSO Session Settings
SSO Session Idle: 1 hour
SSO Session Max: 10 hours
SSO Session Idle Remember Me: 7 days
SSO Session Max Remember Me: 30 days

# Offline Session Settings
Offline Session Idle: 30 days
Offline Session Max: 60 days

# Refresh Token Settings
Client Session Idle: 1 hour
Client Session Max: 10 hours

# Action Token Settings
User-Initiated Action Lifespan: 5 minutes
Default Admin-Initiated Action Lifespan: 12 hours

# Revoke Refresh Token: ON
Refresh Token Max Reuse: 0
```

### 3.6 Security Defenses

Navigate to: **Realm Settings** → **Security Defenses**

**Brute Force Detection:**
```yaml
Enabled: ON
Permanent Lockout: OFF
Max Login Failures: 5
Wait Increment: 60 seconds
Quick Login Check Milliseconds: 1000
Minimum Quick Login Wait: 60 seconds
Max Wait: 15 minutes
Failure Reset Time: 12 hours
```

**Headers:**
```yaml
X-Frame-Options: SAMEORIGIN
Content-Security-Policy: frame-src 'self'; frame-ancestors 'self'; object-src 'none';
X-Content-Type-Options: nosniff
X-Robots-Tag: none
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

---

## 4. Client Configuration

### 4.1 Create Web Application Client

Navigate to: **Clients** → **Create Client**

**Step 1: General Settings**
```yaml
Client Type: OpenID Connect
Client ID: hrms-web-app
Name: HRMS Web Application
Description: Main web application for HRMS SaaS platform
Always Display in Console: OFF
```

**Step 2: Capability Config**
```yaml
Client Authentication: ON  # Confidential client
Authorization: OFF
Authentication Flow:
  ✓ Standard Flow (Authorization Code Flow)
  ✓ Direct Access Grants (Resource Owner Password Credentials)
  ✗ Implicit Flow
  ✗ Service Accounts Roles
  ✗ OAuth 2.0 Device Authorization Grant
  ✗ OIDC CIBA Grant
```

**Step 3: Login Settings**
```yaml
Root URL: https://hrms.yourdomain.com
Home URL: https://hrms.yourdomain.com/dashboard
Valid Redirect URIs:
  - https://hrms.yourdomain.com/*
  - http://localhost:3000/*  # For local development
  - http://localhost:3001/*  # For local development (alternate port)
Valid Post Logout Redirect URIs:
  - https://hrms.yourdomain.com
  - http://localhost:3000
Web Origins:
  - https://hrms.yourdomain.com
  - http://localhost:3000
  - +  # Allow CORS from redirect URIs
Admin URL: https://hrms.yourdomain.com
```

**Step 4: Advanced Settings**
```yaml
Access Token Lifespan: 30 minutes
Client Session Idle: 1 hour
Client Session Max: 10 hours
Client Offline Session Idle: 30 days
Client Offline Session Max: 60 days

# Consent Required: OFF
# Display Client On Consent Screen: OFF

# PKCE (Proof Key for Code Exchange)
PKCE Code Challenge Method: S256
```

### 4.2 Get Client Secret

Navigate to: **Clients** → **hrms-web-app** → **Credentials**

```yaml
Client Authenticator: Client Id and Secret
```

**Copy and securely store the Client Secret** - Backend team will need this.

Example: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

---

## 5. User Management

### 5.1 User Attributes Schema

Each user in Keycloak must have these custom attributes:

| Attribute Name | Type | Required | Description | Example |
|----------------|------|----------|-------------|---------|
| `company_id` | String (UUID) | ✅ Yes | Tenant/Company UUID from PostgreSQL | `550e8400-e29b-41d4-a716-446655440000` |
| `tenant_id` | String (UUID) | ✅ Yes | Alias for company_id (same value) | `550e8400-e29b-41d4-a716-446655440000` |
| `employee_id` | String (UUID) | ⚠️ Optional | Employee UUID (if user is employee) | `660e8400-e29b-41d4-a716-446655440001` |
| `user_type` | String | ✅ Yes | Role category | `company_admin`, `hr_user`, `employee`, `manager` |
| `company_code` | String | ⚠️ Optional | Company code for display | `DEMO001`, `ACME` |
| `company_name` | String | ⚠️ Optional | Company name for display | `Demo Tech Solutions` |
| `phone` | String | ⚠️ Optional | Phone number | `+91-9876543210` |

### 5.2 Create User via Admin Console

Navigate to: **Users** → **Add User**

**Step 1: User Details**
```yaml
Username: john.doe@company.com  # Use email as username
Email: john.doe@company.com
Email Verified: OFF  # Will be verified via email link
First Name: John
Last Name: Doe
Enabled: ON
```

**Step 2: Attributes**
Click **Attributes** tab:

| Key | Value |
|-----|-------|
| company_id | 550e8400-e29b-41d4-a716-446655440000 |
| tenant_id | 550e8400-e29b-41d4-a716-446655440000 |
| employee_id | 660e8400-e29b-41d4-a716-446655440001 |
| user_type | employee |
| company_code | DEMO001 |
| company_name | Demo Tech Solutions |
| phone | +91-9876543210 |

**Step 3: Credentials**
Click **Credentials** tab:
- Set temporary password
- Temporary: ON (user must change on first login)
- Send "Update Password" email: Optional

**Step 4: Role Mappings**
Click **Role Mappings** tab:
- Assign realm roles (see Section 6)

### 5.3 User Creation via Admin API

**Endpoint:** `POST /admin/realms/hrms-saas/users`

**Request Headers:**
```http
Authorization: Bearer <admin-access-token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "username": "jane.smith@newcompany.com",
  "email": "jane.smith@newcompany.com",
  "firstName": "Jane",
  "lastName": "Smith",
  "enabled": true,
  "emailVerified": false,
  "attributes": {
    "company_id": ["770e8400-e29b-41d4-a716-446655440002"],
    "tenant_id": ["770e8400-e29b-41d4-a716-446655440002"],
    "employee_id": ["880e8400-e29b-41d4-a716-446655440003"],
    "user_type": ["hr_user"],
    "company_code": ["NEWCO"],
    "company_name": ["New Company Inc"],
    "phone": ["+91-9876543211"]
  },
  "credentials": [
    {
      "type": "password",
      "value": "TempPassword123!",
      "temporary": true
    }
  ],
  "realmRoles": ["hr_user"],
  "requiredActions": ["VERIFY_EMAIL", "UPDATE_PASSWORD"]
}
```

**Response (Success):**
```http
HTTP/1.1 201 Created
Location: https://auth.yourdomain.com/admin/realms/hrms-saas/users/a1b2c3d4-e5f6-7890-1234-567890abcdef
```

**Important:** Extract the user ID from the `Location` header for subsequent operations.

---

## 6. Role & Permission Setup

### 6.1 Realm Roles

Navigate to: **Realm Roles** → **Create Role**

Create the following 5 roles:

#### Role 1: super_admin
```yaml
Role Name: super_admin
Description: Super administrator with access to all tenants and system settings
Composite: OFF
```

#### Role 2: company_admin
```yaml
Role Name: company_admin
Description: Company administrator with full access to their tenant
Composite: OFF
```

#### Role 3: hr_user
```yaml
Role Name: hr_user
Description: HR user with access to employee management within their tenant
Composite: OFF
```

#### Role 4: manager
```yaml
Role Name: manager
Description: Manager with access to their team's data
Composite: OFF
```

#### Role 5: employee
```yaml
Role Name: employee
Description: Regular employee with access to their own data
Composite: OFF
```

### 6.2 Default Roles

Navigate to: **Realm Roles** → **Default Roles**

Add `employee` as default role:
- When a user is created, they automatically get the `employee` role
- Other roles must be explicitly assigned

### 6.3 Role Hierarchy (Optional - Advanced)

If you want role inheritance:

Navigate to: **Realm Roles** → **super_admin** → **Composite Roles**

```yaml
super_admin includes:
  ├─ company_admin
  ├─ hr_user
  ├─ manager
  └─ employee

company_admin includes:
  ├─ hr_user
  ├─ manager
  └─ employee

hr_user includes:
  └─ employee

manager includes:
  └─ employee
```

**Note:** Discuss with backend team if role hierarchy is needed or if flat roles are sufficient.

---

## 7. JWT Token Configuration

### 7.1 Token Claims Overview

The JWT token must contain these claims:

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
  "session_state": "session-uuid",
  "acr": "1",
  "realm_access": {
    "roles": ["employee", "manager"]
  },
  "scope": "openid profile email",
  "sid": "session-uuid",
  "email_verified": true,
  "preferred_username": "john.doe@company.com",
  "given_name": "John",
  "family_name": "Doe",
  "email": "john.doe@company.com",

  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "employee_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_type": "employee",
  "company_code": "DEMO001",
  "company_name": "Demo Tech Solutions"
}
```

### 7.2 Create Client Mappers

Navigate to: **Clients** → **hrms-web-app** → **Client Scopes** → **hrms-web-app-dedicated** → **Mappers**

#### Mapper 1: company_id

Click **Add Mapper** → **By Configuration** → **User Attribute**

```yaml
Name: company_id
User Attribute: company_id
Token Claim Name: company_id
Claim JSON Type: String
Add to ID token: ON
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
Aggregate attribute values: OFF
```

#### Mapper 2: tenant_id

```yaml
Name: tenant_id
User Attribute: tenant_id
Token Claim Name: tenant_id
Claim JSON Type: String
Add to ID token: ON
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
```

#### Mapper 3: employee_id

```yaml
Name: employee_id
User Attribute: employee_id
Token Claim Name: employee_id
Claim JSON Type: String
Add to ID token: ON
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
```

#### Mapper 4: user_type

```yaml
Name: user_type
User Attribute: user_type
Token Claim Name: user_type
Claim JSON Type: String
Add to ID token: ON
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
```

#### Mapper 5: company_code

```yaml
Name: company_code
User Attribute: company_code
Token Claim Name: company_code
Claim JSON Type: String
Add to ID token: OFF
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
```

#### Mapper 6: company_name

```yaml
Name: company_name
User Attribute: company_name
Token Claim Name: company_name
Claim JSON Type: String
Add to ID token: OFF
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
```

#### Mapper 7: phone

```yaml
Name: phone
User Attribute: phone
Token Claim Name: phone
Claim JSON Type: String
Add to ID token: OFF
Add to access token: ON
Add to userinfo: ON
Multivalued: OFF
```

#### Mapper 8: roles (Built-in)

Verify the **realm roles** mapper exists:

```yaml
Name: realm roles
Mapper Type: User Realm Role
Token Claim Name: realm_access.roles
Claim JSON Type: String
Add to ID token: ON
Add to access token: ON
Add to userinfo: OFF
Multivalued: ON
```

### 7.3 Verify Token Claims

After configuration, test token generation:

**Step 1: Get Token**
```bash
curl -X POST 'https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'client_id=hrms-web-app' \
  -d 'client_secret=<client-secret>' \
  -d 'username=john.doe@company.com' \
  -d 'password=user-password' \
  -d 'scope=openid'
```

**Step 2: Decode Token**

Use https://jwt.io to decode the `access_token` and verify all custom claims are present.

---

## 8. Multi-Tenancy Implementation

### 8.1 Tenant Isolation Strategy

**Approach:** Single Realm, Multi-Tenant with User Attributes

- All users from all companies exist in the same Keycloak realm (`hrms-saas`)
- Tenant isolation is achieved via `company_id` attribute stored on each user
- JWT token includes `company_id` claim
- Backend enforces data isolation using PostgreSQL Row-Level Security (RLS)

### 8.2 User Attribute Validation

**Critical:** Every user MUST have `company_id` and `tenant_id` attributes set.

**Validation Script (run periodically):**

```bash
# Get all users without company_id attribute
GET /admin/realms/hrms-saas/users?briefRepresentation=false

# Check each user has attributes.company_id
# If missing, contact backend team to identify orphaned users
```

### 8.3 Tenant Context Flow

```
1. User logs in → Keycloak authenticates
2. Keycloak generates JWT with company_id claim
3. Frontend receives token, stores it
4. Frontend calls Backend API with token in Authorization header
5. Backend validates token, extracts company_id
6. Backend sets PostgreSQL session variable: app.current_tenant_id = company_id
7. PostgreSQL RLS automatically filters all queries by company_id
8. User can only see/modify data from their company
```

### 8.4 Security Considerations

**Prevent Attribute Tampering:**
- Users cannot modify their own attributes via Keycloak Account Console
- Only admins can change `company_id` via Admin Console or Admin API
- Disable user self-service attribute editing

Navigate to: **Realm Settings** → **User Profile**
- Ensure `company_id`, `tenant_id`, `employee_id` attributes are **admin-only editable**

---

## 9. User Provisioning Workflow

### 9.1 New Company Sign-Up Flow

When a new company registers for the SaaS platform:

**Step 1: Backend creates company record in PostgreSQL**
```sql
-- Returns company_id (UUID)
INSERT INTO company (company_name, company_code, email, ...)
VALUES ('New Corp', 'NEWCORP', 'admin@newcorp.com', ...)
RETURNING id;
```

**Step 2: Backend calls Keycloak Admin API to create admin user**

**API Call:** `POST /admin/realms/hrms-saas/users`

```json
{
  "username": "admin@newcorp.com",
  "email": "admin@newcorp.com",
  "firstName": "Admin",
  "lastName": "User",
  "enabled": true,
  "emailVerified": false,
  "attributes": {
    "company_id": ["<company_id_from_step1>"],
    "tenant_id": ["<company_id_from_step1>"],
    "user_type": ["company_admin"],
    "company_code": ["NEWCORP"],
    "company_name": ["New Corp"]
  },
  "credentials": [
    {
      "type": "password",
      "value": "TempPassword123!",
      "temporary": true
    }
  ],
  "realmRoles": ["company_admin"],
  "requiredActions": ["VERIFY_EMAIL", "UPDATE_PASSWORD"]
}
```

**Step 3: Keycloak sends verification email**

**API Call:** `PUT /admin/realms/hrms-saas/users/<user_id>/send-verify-email`

**Step 4: Backend stores user mapping in PostgreSQL**

```sql
INSERT INTO user_account (keycloak_user_id, username, email, company_id, user_type)
VALUES ('<keycloak_user_id>', 'admin@newcorp.com', 'admin@newcorp.com',
        '<company_id>', 'company_admin');
```

### 9.2 Add Employee User Flow

When HR admin adds a new employee:

**Step 1: Backend creates employee record in PostgreSQL**
```sql
INSERT INTO employee (company_id, employee_code, employee_name, email, ...)
VALUES ('<company_id>', 'EMP001', 'John Doe', 'john.doe@newcorp.com', ...)
RETURNING id;
```

**Step 2: Backend calls Keycloak Admin API**

```json
{
  "username": "john.doe@newcorp.com",
  "email": "john.doe@newcorp.com",
  "firstName": "John",
  "lastName": "Doe",
  "enabled": true,
  "emailVerified": false,
  "attributes": {
    "company_id": ["<company_id>"],
    "tenant_id": ["<company_id>"],
    "employee_id": ["<employee_id_from_step1>"],
    "user_type": ["employee"],
    "company_code": ["NEWCORP"],
    "company_name": ["New Corp"]
  },
  "credentials": [
    {
      "type": "password",
      "value": "Welcome@123",
      "temporary": true
    }
  ],
  "realmRoles": ["employee"],
  "requiredActions": ["VERIFY_EMAIL", "UPDATE_PASSWORD"]
}
```

**Step 3: Send welcome email**

### 9.3 User Deactivation Flow

When an employee leaves:

**Step 1: Backend marks employee as inactive in PostgreSQL**
```sql
UPDATE employee SET is_active = false, date_of_exit = NOW()
WHERE id = '<employee_id>';
```

**Step 2: Backend disables user in Keycloak**

**API Call:** `PUT /admin/realms/hrms-saas/users/<user_id>`

```json
{
  "enabled": false
}
```

**Step 3: Revoke active sessions (optional)**

**API Call:** `POST /admin/realms/hrms-saas/users/<user_id>/logout`

---

## 10. Security Requirements

### 10.1 SSL/TLS Configuration

**Requirement:** Keycloak MUST be accessible only via HTTPS in production.

```yaml
# keycloak.conf or standalone.xml
spi-truststore-file-file: /path/to/truststore.jks
spi-truststore-file-password: <truststore-password>
https-certificate-file: /path/to/cert.pem
https-certificate-key-file: /path/to/key.pem
```

### 10.2 Admin Console Access

**Restrict Admin Console to specific IPs:**

Navigate to: **Realm Settings** → **Security Defenses** → **Headers**

Or configure at reverse proxy (Nginx/Apache) level:

```nginx
location /admin {
    allow 192.168.1.0/24;  # Office network
    allow 10.0.0.0/8;      # VPN network
    deny all;
}
```

### 10.3 Password Policy

Navigate to: **Authentication** → **Password Policy**

Add the following policies:

```yaml
- Minimum Length: 8
- Maximum Length: 64
- Uppercase Characters: 1
- Lowercase Characters: 1
- Digits: 1
- Special Characters: 1
- Not Username
- Not Email
- Password History: 3
- Expire Password: 90 days
```

### 10.4 Required Actions

Navigate to: **Authentication** → **Required Actions**

Enable:
- ✅ Verify Email
- ✅ Update Password (for temporary passwords)
- ✅ Update Profile (optional)
- ✅ Configure OTP (optional - for MFA in future)

### 10.5 Account Lockout

Already configured in Section 3.6 (Brute Force Detection)

### 10.6 Audit Logging

Navigate to: **Realm Settings** → **Events**

**Login Events Settings:**
```yaml
Save Events: ON
Expiration: 365 days
Saved Types:
  - LOGIN
  - LOGIN_ERROR
  - LOGOUT
  - CODE_TO_TOKEN
  - REFRESH_TOKEN
  - INTROSPECT_TOKEN
```

**Admin Events Settings:**
```yaml
Save Events: ON
Include Representation: ON
```

---

## 11. API Endpoints for Backend Team

### 11.1 Token Endpoints

**Base URL:** `https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect`

#### Get Access Token (Login)
```http
POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=password
&client_id=hrms-web-app
&client_secret=<client-secret>
&username=user@company.com
&password=user-password
&scope=openid
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 1800,
  "refresh_expires_in": 604800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "not-before-policy": 0,
  "session_state": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "scope": "openid profile email"
}
```

#### Refresh Token
```http
POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&client_id=hrms-web-app
&client_secret=<client-secret>
&refresh_token=<refresh-token>
```

#### Logout
```http
POST /logout
Content-Type: application/x-www-form-urlencoded

client_id=hrms-web-app
&client_secret=<client-secret>
&refresh_token=<refresh-token>
```

#### Introspect Token (Validate)
```http
POST /token/introspect
Content-Type: application/x-www-form-urlencoded

token=<access-token>
&client_id=hrms-web-app
&client_secret=<client-secret>
```

**Response:**
```json
{
  "exp": 1698767232,
  "iat": 1698765432,
  "jti": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "iss": "https://auth.yourdomain.com/realms/hrms-saas",
  "aud": "hrms-web-app",
  "sub": "user-uuid",
  "typ": "Bearer",
  "azp": "hrms-web-app",
  "active": true,
  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "employee_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_type": "employee",
  "email": "user@company.com",
  "preferred_username": "user@company.com"
}
```

#### Get User Info
```http
GET /userinfo
Authorization: Bearer <access-token>
```

### 11.2 Admin API Endpoints

**Base URL:** `https://auth.yourdomain.com/admin/realms/hrms-saas`

**Authentication:** All Admin API calls require admin access token.

**Get Admin Token:**
```bash
curl -X POST 'https://auth.yourdomain.com/realms/master/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' \
  -d 'username=<admin-username>' \
  -d 'password=<admin-password>'
```

#### Create User
```http
POST /users
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "username": "newuser@company.com",
  "email": "newuser@company.com",
  "enabled": true,
  "attributes": {
    "company_id": ["uuid"],
    "tenant_id": ["uuid"]
  }
}
```

#### Get User by ID
```http
GET /users/{user-id}
Authorization: Bearer <admin-token>
```

#### Update User
```http
PUT /users/{user-id}
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "attributes": {
    "employee_id": ["new-employee-uuid"]
  }
}
```

#### Delete User
```http
DELETE /users/{user-id}
Authorization: Bearer <admin-token>
```

#### Reset Password
```http
PUT /users/{user-id}/reset-password
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "type": "password",
  "value": "NewPassword123!",
  "temporary": true
}
```

#### Send Verification Email
```http
PUT /users/{user-id}/send-verify-email
Authorization: Bearer <admin-token>
```

#### Logout User (Revoke Sessions)
```http
POST /users/{user-id}/logout
Authorization: Bearer <admin-token>
```

#### Search Users by Attribute
```http
GET /users?briefRepresentation=false&q=company_id:550e8400-e29b-41d4-a716-446655440000
Authorization: Bearer <admin-token>
```

### 11.3 JWKS Endpoint (Public Keys)

Backend needs this to validate JWT signatures:

```http
GET /realms/hrms-saas/protocol/openid-connect/certs
```

**Response:**
```json
{
  "keys": [
    {
      "kid": "key-id",
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "n": "modulus",
      "e": "exponent"
    }
  ]
}
```

---

## 12. Testing & Validation

### 12.1 Manual Testing Checklist

#### Test 1: User Login
- [ ] User can login with username/password
- [ ] Access token is returned
- [ ] Refresh token is returned
- [ ] ID token is returned

#### Test 2: JWT Token Contents
- [ ] Decode access token using jwt.io
- [ ] Verify `company_id` claim exists
- [ ] Verify `tenant_id` claim exists
- [ ] Verify `employee_id` claim exists (if applicable)
- [ ] Verify `user_type` claim exists
- [ ] Verify `realm_access.roles` contains correct roles

#### Test 3: Token Refresh
- [ ] Use refresh token to get new access token
- [ ] New access token has updated `exp` claim
- [ ] New access token has same custom claims

#### Test 4: Token Expiry
- [ ] Wait for access token to expire (30 minutes)
- [ ] API calls with expired token return 401 Unauthorized
- [ ] Refresh token still works to get new access token

#### Test 5: User Logout
- [ ] Logout endpoint revokes tokens
- [ ] Access token becomes invalid after logout
- [ ] Refresh token becomes invalid after logout

#### Test 6: Multi-Tenancy Isolation
- [ ] Create users for Company A with company_id = UUID_A
- [ ] Create users for Company B with company_id = UUID_B
- [ ] Login as Company A user, verify token has UUID_A
- [ ] Login as Company B user, verify token has UUID_B
- [ ] Tokens contain different company_id values

#### Test 7: Admin API
- [ ] Create user via Admin API
- [ ] Get user details via Admin API
- [ ] Update user attributes via Admin API
- [ ] Delete user via Admin API
- [ ] Reset user password via Admin API

#### Test 8: Email Verification
- [ ] Create user with emailVerified = false
- [ ] Trigger send verification email
- [ ] Check email inbox for verification link
- [ ] Click link, verify email is marked as verified

#### Test 9: Password Reset
- [ ] Use "Forgot Password" flow
- [ ] Receive password reset email
- [ ] Reset password via link
- [ ] Login with new password

#### Test 10: Role-Based Access
- [ ] Assign different roles to different users
- [ ] Verify JWT token contains correct roles
- [ ] Backend can extract roles for authorization

### 12.2 Automated Testing Script

```bash
#!/bin/bash

KEYCLOAK_URL="https://auth.yourdomain.com"
REALM="hrms-saas"
CLIENT_ID="hrms-web-app"
CLIENT_SECRET="<client-secret>"

# Test 1: Get Token
echo "Test 1: Getting access token..."
TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=testuser@company.com" \
  -d "password=TestPassword123!")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
REFRESH_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.refresh_token')

if [ "$ACCESS_TOKEN" != "null" ]; then
  echo "✅ Access token received"
else
  echo "❌ Failed to get access token"
  exit 1
fi

# Test 2: Decode Token
echo "Test 2: Decoding token..."
TOKEN_PAYLOAD=$(echo $ACCESS_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null)
COMPANY_ID=$(echo $TOKEN_PAYLOAD | jq -r '.company_id')

if [ "$COMPANY_ID" != "null" ]; then
  echo "✅ company_id claim found: $COMPANY_ID"
else
  echo "❌ company_id claim missing"
  exit 1
fi

# Test 3: Introspect Token
echo "Test 3: Introspecting token..."
INTROSPECT_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token/introspect" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=${ACCESS_TOKEN}" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}")

TOKEN_ACTIVE=$(echo $INTROSPECT_RESPONSE | jq -r '.active')

if [ "$TOKEN_ACTIVE" == "true" ]; then
  echo "✅ Token is active"
else
  echo "❌ Token is not active"
  exit 1
fi

# Test 4: Refresh Token
echo "Test 4: Refreshing token..."
REFRESH_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "refresh_token=${REFRESH_TOKEN}")

NEW_ACCESS_TOKEN=$(echo $REFRESH_RESPONSE | jq -r '.access_token')

if [ "$NEW_ACCESS_TOKEN" != "null" ]; then
  echo "✅ Token refreshed successfully"
else
  echo "❌ Failed to refresh token"
  exit 1
fi

echo ""
echo "======================================"
echo "All tests passed! ✅"
echo "======================================"
```

### 12.3 Integration Testing with Backend

**Backend team should test:**

1. **JWT Validation:**
   - Backend can validate JWT signature using JWKS endpoint
   - Backend rejects expired tokens
   - Backend rejects tampered tokens

2. **Tenant Context Extraction:**
   - Backend extracts `company_id` from JWT
   - Backend sets PostgreSQL session variable correctly
   - RLS policies filter data correctly

3. **Role-Based Authorization:**
   - Backend enforces role-based access control
   - `company_admin` can access admin APIs
   - `employee` cannot access admin APIs

---

## 13. Appendix

### A. Environment Variables for Backend

Provide these to the backend team:

```properties
# Keycloak Configuration
KEYCLOAK_URL=https://auth.yourdomain.com
KEYCLOAK_REALM=hrms-saas
KEYCLOAK_CLIENT_ID=hrms-web-app
KEYCLOAK_CLIENT_SECRET=<client-secret>

# JWT Validation
KEYCLOAK_JWKS_URL=https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/certs
KEYCLOAK_ISSUER=https://auth.yourdomain.com/realms/hrms-saas

# Admin API (for user provisioning)
KEYCLOAK_ADMIN_USERNAME=<admin-username>
KEYCLOAK_ADMIN_PASSWORD=<admin-password>
KEYCLOAK_ADMIN_CLIENT_ID=admin-cli
```

### B. Frontend Configuration

Provide these to the frontend team:

```javascript
// keycloak.json
{
  "realm": "hrms-saas",
  "url": "https://auth.yourdomain.com",
  "clientId": "hrms-web-app",
  "ssl-required": "external",
  "public-client": false,
  "confidential-port": 0,
  "credentials": {
    "secret": "<client-secret>"
  }
}
```

### C. Database User Attributes Mapping

| Keycloak Attribute | PostgreSQL Column | Table |
|-------------------|-------------------|-------|
| `sub` (user ID) | `keycloak_user_id` | `user_account` |
| `company_id` | `company_id` | `user_account`, `employee` |
| `employee_id` | `id` | `employee` |
| `email` | `email` | `user_account`, `employee` |
| `preferred_username` | `username` | `user_account` |

### D. Common Issues & Troubleshooting

#### Issue 1: Custom Claims Not in Token
**Solution:**
- Check client mappers are configured correctly
- Ensure user attributes are set on the user
- Verify mapper is added to access token (not just ID token)

#### Issue 2: CORS Errors from Frontend
**Solution:**
- Add frontend URL to "Web Origins" in client settings
- Use `+` to allow all valid redirect URIs

#### Issue 3: Token Validation Fails
**Solution:**
- Verify JWKS endpoint is accessible from backend
- Check clock sync between Keycloak and backend servers
- Ensure issuer claim matches exactly

#### Issue 4: User Cannot Login
**Solution:**
- Check user is enabled in Keycloak
- Verify email is correct
- Check password is correct
- Look at Keycloak admin events for login failures

#### Issue 5: Admin API Returns 403
**Solution:**
- Verify admin token is valid
- Check admin user has correct realm management roles
- Use token from `master` realm, not `hrms-saas` realm

### E. Monitoring & Maintenance

**Daily Tasks:**
- Monitor failed login attempts
- Review audit logs for suspicious activity

**Weekly Tasks:**
- Review user growth per tenant
- Check for users without company_id attribute
- Verify email delivery success rate

**Monthly Tasks:**
- Review token expiry policies
- Clean up disabled users
- Backup Keycloak database
- Update Keycloak to latest patch version

### F. Support Contacts

| Role | Contact | Purpose |
|------|---------|---------|
| Backend Team Lead | <backend-lead-email> | JWT validation, API integration |
| Frontend Team Lead | <frontend-lead-email> | Login flow, token storage |
| Database Team Lead | <db-lead-email> | RLS policies, tenant context |
| DevOps Lead | <devops-lead-email> | SSL certificates, domain setup |

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-29 | Claude Code | Initial document creation |

---

**End of Document**

Please reach out to the project team if you have any questions or need clarifications on any section of this document.
