# HRMS SaaS Frontend Setup Guide

Complete step-by-step guide to set up the HRMS SaaS multi-tenant React application with Keycloak authentication and Row-Level Security.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Keycloak Configuration](#keycloak-configuration)
3. [Database Setup](#database-setup)
4. [Backend API Setup](#backend-api-setup)
5. [Frontend Setup](#frontend-setup)
6. [Testing the Integration](#testing-the-integration)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- ✅ **Node.js 18+** and npm
- ✅ **Keycloak 26+** (running on port 8090)
- ✅ **PostgreSQL 16+** (with RLS configured)
- ✅ **Spring Boot Backend** (running on port 8081)

### Verify Prerequisites

```bash
# Check Node.js version
node --version  # Should be v18.0.0 or higher

# Check npm version
npm --version

# Check if Keycloak is running
curl http://localhost:8090/realms/hrms-saas

# Check if database is accessible
psql -h localhost -U hrms_app -d hrms_saas -c "SELECT version();"

# Check if backend API is running
curl http://localhost:8081/actuator/health
```

---

## Keycloak Configuration

### Step 1: Verify Realm

Ensure the `hrms-saas` realm exists in Keycloak:

1. Open Keycloak Admin Console: `http://localhost:8090`
2. Login with admin credentials
3. Select realm **`hrms-saas`** from top-left dropdown
4. If realm doesn't exist, refer to `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md`

### Step 2: Verify Client Configuration

Navigate to: **Clients** → **hrms-web-app**

Verify these settings:

```yaml
Client ID: hrms-web-app
Client Authentication: ON (Confidential)
Valid Redirect URIs:
  - http://localhost:3000/*
  - https://your-domain.com/*
Valid Post Logout Redirect URIs:
  - http://localhost:3000
Web Origins:
  - http://localhost:3000
  - +
```

### Step 3: Get Client Secret

1. Navigate to: **Clients** → **hrms-web-app** → **Credentials** tab
2. Copy the **Client Secret**
3. Save it - you'll need it for environment configuration

Example: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

### Step 4: Verify Client Mappers

Navigate to: **Clients** → **hrms-web-app** → **Client Scopes** → **hrms-web-app-dedicated** → **Mappers**

Ensure these mappers exist:

| Mapper Name | Type | User Attribute | Token Claim Name | In Access Token |
|-------------|------|----------------|------------------|-----------------|
| company_id | User Attribute | company_id | company_id | ✅ YES |
| tenant_id | User Attribute | tenant_id | tenant_id | ✅ YES |
| employee_id | User Attribute | employee_id | employee_id | ✅ YES |
| user_type | User Attribute | user_type | user_type | ✅ YES |
| company_code | User Attribute | company_code | company_code | ✅ YES |
| company_name | User Attribute | company_name | company_name | ✅ YES |

If mappers don't exist, create them:

**Example: Creating company_id mapper**

1. Click **Add Mapper** → **By Configuration** → **User Attribute**
2. Fill in:
   - Name: `company_id`
   - User Attribute: `company_id`
   - Token Claim Name: `company_id`
   - Claim JSON Type: `String`
   - Add to access token: `ON`
   - Add to ID token: `ON`
   - Add to userinfo: `ON`
3. Click **Save**

Repeat for other mappers.

### Step 5: Create Test User

Create a test user with tenant context:

1. Navigate to: **Users** → **Add User**
2. Fill in:
   - Username: `admin@testcompany.com`
   - Email: `admin@testcompany.com`
   - First Name: `Admin`
   - Last Name: `User`
   - Email Verified: `ON`
   - Enabled: `ON`
3. Click **Create**

4. Go to **Attributes** tab:

   | Key | Value |
   |-----|-------|
   | company_id | `550e8400-e29b-41d4-a716-446655440000` |
   | tenant_id | `550e8400-e29b-41d4-a716-446655440000` |
   | user_type | `company_admin` |
   | company_code | `TEST001` |
   | company_name | `Test Company Ltd` |

5. Go to **Credentials** tab:
   - Set password: `TestAdmin@123`
   - Temporary: `OFF`

6. Go to **Role Mappings** tab:
   - Assign role: `company_admin`

---

## Database Setup

### Step 1: Verify Database Exists

```bash
psql -h localhost -U admin -c "SELECT datname FROM pg_database WHERE datname = 'hrms_saas';"
```

### Step 2: Verify Tables Exist

```bash
psql -h localhost -U hrms_app -d hrms_saas -c "\dt"
```

Expected tables:
- `company`
- `employee`
- `department_master`
- `designation_master`
- `employee_education`
- `employee_experience`

### Step 3: Insert Test Company

```bash
psql -h localhost -U hrms_app -d hrms_saas
```

```sql
-- Insert test company (use same UUID as Keycloak user's company_id)
INSERT INTO company (
  id,
  company_code,
  company_name,
  company_type,
  email,
  phone,
  city,
  state,
  country,
  is_active
) VALUES (
  '550e8400-e29b-41d4-a716-446655440000',
  'TEST001',
  'Test Company Ltd',
  'INDEPENDENT',
  'contact@testcompany.com',
  '+1-555-0123',
  'San Francisco',
  'California',
  'USA',
  true
);

-- Verify insertion
SELECT id, company_code, company_name FROM company;
```

### Step 4: Verify RLS is Enabled

```sql
-- Check RLS status
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('company', 'employee');

-- Should show rowsecurity = true for both tables
```

### Step 5: Test RLS Policies

```sql
-- Set tenant context
SELECT set_current_tenant('550e8400-e29b-41d4-a716-446655440000');

-- Query should return only Test Company
SELECT * FROM company;

-- Clear tenant context
RESET app.current_tenant_id;

-- Query with RLS should return no rows (or error)
SELECT * FROM company;
```

---

## Backend API Setup

Ensure your Spring Boot backend is configured to:

1. **Validate JWT tokens** from Keycloak
2. **Extract tenant_id** from JWT custom claims
3. **Set PostgreSQL session variable** for RLS

### Verify Backend Configuration

Check `application.properties` or `application.yml`:

```properties
# Keycloak Configuration
spring.security.oauth2.resourceserver.jwt.issuer-uri=http://localhost:8090/realms/hrms-saas
spring.security.oauth2.resourceserver.jwt.jwk-set-uri=http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs

# Database Configuration
spring.datasource.url=jdbc:postgresql://localhost:5432/hrms_saas
spring.datasource.username=hrms_app
spring.datasource.password=HrmsApp@2025
```

### Verify Backend Extracts Tenant Context

Backend should have code like:

```java
@Component
public class TenantInterceptor {
    @Override
    public boolean preHandle(HttpServletRequest request, ...) {
        // Extract tenant_id from JWT token
        String tenantId = jwtToken.getClaim("tenant_id");

        // Set PostgreSQL session variable for RLS
        jdbcTemplate.execute("SELECT set_current_tenant('" + tenantId + "')");

        return true;
    }
}
```

---

## Frontend Setup

### Step 1: Clone and Navigate

```bash
cd /Users/rameshbabu/data/projects/systech/hrms-saas/reactapp
```

### Step 2: Install Dependencies

```bash
npm install
```

This installs:
- React 19
- Keycloak JS 26
- TypeScript 5
- Axios for HTTP requests
- JWT Decode for token parsing

### Step 3: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit .env file
nano .env
```

Update `.env` with your configuration:

```env
# Keycloak Configuration
REACT_APP_KEYCLOAK_URL=http://localhost:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT=hrms-web-app

# Backend API
REACT_APP_API_URL=http://localhost:8081
REACT_APP_GRAPHQL_URL=http://localhost:8081/graphql

# Admin API (for user provisioning)
# WARNING: Do NOT commit real credentials to git
REACT_APP_KEYCLOAK_ADMIN_URL=http://localhost:8090
REACT_APP_KEYCLOAK_ADMIN_REALM=master
REACT_APP_KEYCLOAK_ADMIN_CLIENT=admin-cli

# Application
REACT_APP_NAME=HRMS SaaS Platform
NODE_ENV=development
```

### Step 4: Start Development Server

```bash
npm start
```

App should open at `http://localhost:3000`

### Step 5: Verify Auto-Redirect to Keycloak

1. Browser opens `http://localhost:3000`
2. App initializes Keycloak (`check-sso`)
3. If not authenticated, shows login button
4. Click login → Redirects to Keycloak login page
5. Login with test user credentials
6. Redirects back to `http://localhost:3000`
7. App displays user info and tenant context

---

## Testing the Integration

### Test 1: Login and View Tenant Context

1. Open browser: `http://localhost:3000`
2. Click **Login**
3. Enter credentials:
   - Username: `admin@testcompany.com`
   - Password: `TestAdmin@123`
4. After login, check browser console:
   ```
   🔐 Authenticated with tenant context: {
     companyId: "550e8400-e29b-41d4-a716-446655440000",
     tenantId: "550e8400-e29b-41d4-a716-446655440000",
     userType: "company_admin"
   }
   ```

### Test 2: Verify JWT Token Contains Custom Claims

1. Open browser DevTools → Application → Local Storage
2. Find key: `access_token`
3. Copy token value
4. Go to https://jwt.io
5. Paste token
6. Verify payload contains:
   ```json
   {
     "company_id": "550e8400-e29b-41d4-a716-446655440000",
     "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
     "user_type": "company_admin",
     "company_code": "TEST001",
     "company_name": "Test Company Ltd"
   }
   ```

### Test 3: API Call with Tenant Context

1. Open browser console
2. Run:
   ```javascript
   const token = localStorage.getItem('access_token');
   fetch('http://localhost:8081/api/companies', {
     headers: { 'Authorization': `Bearer ${token}` }
   })
     .then(r => r.json())
     .then(data => console.log('Companies:', data));
   ```
3. Verify API returns only companies for tenant `550e8400-...`

### Test 4: Register New Employee

1. Navigate to User Registration page
2. Fill in form:
   - Email: `john.doe@testcompany.com`
   - First Name: `John`
   - Last Name: `Doe`
   - Role: `Employee`
   - Password: `TempPass123!`
3. Click **Create User**
4. Verify success message
5. Check Keycloak:
   - Navigate to **Users** in Keycloak Admin
   - Find `john.doe@testcompany.com`
   - Go to **Attributes** tab
   - Verify `company_id` matches `550e8400-...`

### Test 5: Multi-Tenant Isolation

1. Create second test company in database:
   ```sql
   INSERT INTO company (id, company_code, company_name, company_type, is_active)
   VALUES ('770e8400-e29b-41d4-a716-446655440002', 'TEST002', 'Another Company', 'INDEPENDENT', true);
   ```

2. Create user for second company in Keycloak with `company_id=770e8400-...`

3. Login as first user (Test Company) → See only Test Company data
4. Logout → Login as second user (Another Company) → See only Another Company data

---

## Troubleshooting

### Issue 1: Keycloak Connection Failed

**Symptom:** `Failed to initialize Keycloak: Network error`

**Solution:**
```bash
# Verify Keycloak is running
curl http://localhost:8090/realms/hrms-saas

# Check Keycloak logs
docker logs keycloak-container  # or podman logs

# Verify firewall allows port 8090
```

### Issue 2: JWT Missing tenant_id

**Symptom:** Console error: `Invalid token: Missing tenant context`

**Solution:**
1. Check Keycloak user has `company_id` and `tenant_id` attributes
2. Verify client mappers are configured
3. Ensure mappers are added to **access token**
4. Get new token (logout and login again)

### Issue 3: CORS Error

**Symptom:** `CORS policy: No 'Access-Control-Allow-Origin' header`

**Solution:**
1. Add `http://localhost:3000` to Keycloak client "Web Origins"
2. Or add `+` to allow all valid redirect URIs

### Issue 4: Backend RLS Not Working

**Symptom:** Users can see data from other tenants

**Solution:**
1. Verify backend extracts `tenant_id` from JWT
2. Verify backend calls `set_current_tenant()`
3. Check PostgreSQL RLS policies:
   ```sql
   SELECT * FROM pg_policies WHERE schemaname = 'public';
   ```

### Issue 5: User Registration Fails

**Symptom:** `Failed to create user: 403 Forbidden`

**Solution:**
1. Admin API credentials in `.env` are incorrect
2. Admin user doesn't have realm management permissions
3. Use backend API instead of direct Keycloak Admin API from frontend

---

## Production Deployment

### Security Checklist

- [ ] Remove Keycloak admin credentials from frontend `.env`
- [ ] Use HTTPS for all connections (Keycloak, Backend, Frontend)
- [ ] Configure proper CORS origins (no wildcards)
- [ ] Enable SSL certificate verification
- [ ] Use environment-specific secrets (not hardcoded)
- [ ] Implement backend API for user provisioning (not direct Keycloak Admin API)
- [ ] Enable Keycloak security headers and brute force protection
- [ ] Set up monitoring for failed authentication attempts
- [ ] Configure token expiry (30 minutes for access token)
- [ ] Enable audit logging in Keycloak

### Deployment Steps

1. **Build Frontend:**
   ```bash
   npm run build
   ```

2. **Deploy to Web Server** (Nginx, Apache, etc.)

3. **Update Environment Variables** for production

4. **Update Keycloak Client:**
   - Add production URLs to Valid Redirect URIs
   - Add production domain to Web Origins
   - Remove localhost URLs

5. **Test Production Deployment:**
   - Verify login works
   - Verify tenant isolation
   - Verify API calls succeed

---

## Next Steps

After successful setup:

1. **Implement Company Master CRUD** - Create/Read/Update/Delete companies
2. **Implement Employee Master CRUD** - Manage employee records
3. **Build Dashboard** - Overview of company and employee statistics
4. **Add Reporting Hierarchy** - Manager-employee relationships
5. **Implement Search and Filters** - Find employees by name, department, etc.

---

## Support

For issues or questions:

- Check documentation in `docs/` folder
- Review Keycloak logs
- Review Backend API logs
- Review Browser console for errors

---

**Setup Complete! 🎉**

You now have a fully functional multi-tenant HRMS application with Keycloak authentication and Row-Level Security.
