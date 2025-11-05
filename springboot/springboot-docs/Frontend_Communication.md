# Frontend Communication Guide
## HRMS SaaS - Backend API Documentation

**Version:** 1.0.0
**Last Updated:** 2025-10-31
**Backend URL:** `http://localhost:8081`
**Auth Server:** `http://localhost:8090` (Keycloak)

---

## Table of Contents
1. [Overview](#overview)
2. [Authentication Flow](#authentication-flow)
3. [API Endpoints](#api-endpoints)
4. [Request/Response Examples](#requestresponse-examples)
5. [Error Handling](#error-handling)
6. [Keycloak Integration](#keycloak-integration)
7. [Multi-Tenant Architecture](#multi-tenant-architecture)
8. [Security & CORS](#security--cors)

---

## Overview

The HRMS SaaS backend provides REST and GraphQL APIs for managing multi-tenant HR operations. The authentication is handled by Keycloak (OAuth2/OIDC), and all authenticated requests require a valid JWT token.

### Key Concepts
- **Tenant ID**: 12-character NanoID (e.g., `a1lrqfv7lj7h`) uniquely identifies each company
- **User Types**: `company_admin`, `hr_user`, `employee`, `manager`
- **Subscription Plans**: `FREE`, `BASIC`, `PROFESSIONAL`, `ENTERPRISE`
- **Company Status**: `PENDING_ACTIVATION`, `PENDING_EMAIL_VERIFICATION`, `ACTIVE`, `SUSPENDED`, `INACTIVE`

---

## Authentication Flow

### 1. Company Signup Flow

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│   Frontend  │         │   Backend    │         │   Keycloak   │
└──────┬──────┘         └──────┬───────┘         └──────┬───────┘
       │                       │                        │
       │  POST /signup         │                        │
       │──────────────────────>│                        │
       │                       │                        │
       │                       │  Generate NanoID       │
       │                       │  (tenant_id)           │
       │                       │                        │
       │                       │  Create company_master │
       │                       │  record in PostgreSQL  │
       │                       │                        │
       │                       │  Create user           │
       │                       │───────────────────────>│
       │                       │                        │
       │                       │  User created with     │
       │                       │  tenant_id attribute   │
       │                       │<───────────────────────│
       │                       │                        │
       │                       │  Send verification     │
       │                       │  email (optional)      │
       │                       │───────────────────────>│
       │                       │                        │
       │  Success Response     │                        │
       │  (tenant_id + userId) │                        │
       │<──────────────────────│                        │
       │                       │                        │
```

### 2. Login Flow (Keycloak)

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│   Frontend  │         │   Keycloak   │         │   Backend    │
└──────┬──────┘         └──────┬───────┘         └──────┬───────┘
       │                       │                        │
       │  Redirect to          │                        │
       │  Keycloak login       │                        │
       │──────────────────────>│                        │
       │                       │                        │
       │  User enters          │                        │
       │  credentials          │                        │
       │──────────────────────>│                        │
       │                       │                        │
       │  Keycloak validates   │                        │
       │  & issues JWT token   │                        │
       │  (with tenant_id)     │                        │
       │<──────────────────────│                        │
       │                       │                        │
       │  API calls with       │                        │
       │  Authorization header │                        │
       │────────────────────────────────────────────────>│
       │                       │                        │
       │                       │  Backend validates JWT │
       │                       │  & extracts tenant_id  │
       │                       │                        │
       │  Protected resource   │                        │
       │<────────────────────────────────────────────────│
       │                       │                        │
```

---

## API Endpoints

### Base URL
```
http://localhost:8081/api/v1
```

### Public Endpoints (No Authentication Required)

#### 1. Company Signup
**Endpoint:** `POST /auth/signup`
**Description:** Create new company account (tenant) and admin user
**Content-Type:** `application/json`

**Request Body:**
```json
{
  "email": "admin@company.com",
  "password": "Admin@123",
  "firstName": "John",
  "lastName": "Doe",
  "companyName": "Acme Corporation",
  "phone": "+919876543210"
}
```

**Validation Rules:**
- **email**: Required, valid email format, unique across platform
- **password**: Required, min 8 chars, must contain:
  - At least 1 lowercase letter
  - At least 1 uppercase letter
  - At least 1 digit
  - At least 1 special character (@$!%*?&)
- **firstName**: Required, 2-50 characters
- **lastName**: Required, 2-50 characters
- **companyName**: Required, 2-255 characters
- **phone**: Optional, format: `+[country_code][10-15 digits]` (e.g., `+919876543210`)

**Success Response (201 Created):**
```json
{
  "success": true,
  "message": "Account created successfully. Please verify your email to continue.",
  "tenantId": "a1lrqfv7lj7h",
  "userId": "5db67d42-7df1-4d3f-b45f-4e1baeae11d5",
  "requiresEmailVerification": true
}
```

**Error Responses:**

*Conflict (409):*
```json
{
  "success": false,
  "message": "Email address already exists",
  "tenantId": null,
  "userId": null,
  "requiresEmailVerification": false
}
```

*Validation Error (400):*
```json
{
  "error": "VALIDATION_ERROR",
  "message": "Invalid request data",
  "fields": {
    "email": "Invalid email format",
    "password": "Password must be at least 8 characters",
    "phone": "Invalid phone number format. Must be 10-15 digits, optionally starting with +"
  }
}
```

*Service Unavailable (503):*
```json
{
  "success": false,
  "message": "Account creation pending. Please try again later.",
  "tenantId": null,
  "userId": null,
  "requiresEmailVerification": false
}
```

---

#### 2. Check Email Availability
**Endpoint:** `GET /auth/check-email`
**Description:** Check if email is available for registration
**Query Parameters:**
- `email` (required): Email address to check

**Request:**
```bash
GET /api/v1/auth/check-email?email=admin@company.com
```

**Response (200 OK):**
```json
{
  "available": false
}
```

---

#### 3. Resend Verification Email
**Endpoint:** `POST /auth/resend-verification`
**Description:** Resend email verification link
**Content-Type:** `application/json`

**Request Body:**
```json
{
  "email": "admin@company.com"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Verification email sent successfully"
}
```

**Error Response (500):**
```json
{
  "success": false,
  "message": "Failed to resend verification email"
}
```

---

### Protected Endpoints (Authentication Required)

All protected endpoints require a valid JWT token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

#### GraphQL Endpoint
**Endpoint:** `POST /graphql`
**Description:** GraphQL API for all business operations
**Status:** Coming soon (to be implemented)

#### GraphiQL Playground
**Endpoint:** `GET /graphiql`
**Description:** Interactive GraphQL IDE
**Status:** Coming soon (to be implemented)

---

## Request/Response Examples

### Example 1: Successful Signup

**cURL:**
```bash
curl -X POST http://localhost:8081/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "ceo@techcorp.com",
    "password": "SecurePass@123",
    "firstName": "Jane",
    "lastName": "Smith",
    "companyName": "TechCorp Solutions",
    "phone": "+919876543210"
  }'
```

**JavaScript (Fetch API):**
```javascript
const response = await fetch('http://localhost:8081/api/v1/auth/signup', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    email: 'ceo@techcorp.com',
    password: 'SecurePass@123',
    firstName: 'Jane',
    lastName: 'Smith',
    companyName: 'TechCorp Solutions',
    phone: '+919876543210'
  })
});

const data = await response.json();

if (response.ok) {
  console.log('Tenant ID:', data.tenantId);
  console.log('User ID:', data.userId);
  // Store tenantId for future use
  localStorage.setItem('tenantId', data.tenantId);
  // Redirect to email verification page or login
} else {
  console.error('Signup failed:', data.message);
}
```

**React Example:**
```jsx
import { useState } from 'react';

function SignupForm() {
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    firstName: '',
    lastName: '',
    companyName: '',
    phone: ''
  });
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const response = await fetch('http://localhost:8081/api/v1/auth/signup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(formData)
      });

      const data = await response.json();

      if (response.ok && data.success) {
        // Store tenant ID
        localStorage.setItem('tenantId', data.tenantId);
        // Redirect to verification page
        window.location.href = '/verify-email';
      } else {
        setError(data.message || 'Signup failed');
      }
    } catch (err) {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {error && <div className="error">{error}</div>}

      <input
        type="email"
        placeholder="Email"
        value={formData.email}
        onChange={(e) => setFormData({...formData, email: e.target.value})}
        required
      />

      <input
        type="password"
        placeholder="Password"
        value={formData.password}
        onChange={(e) => setFormData({...formData, password: e.target.value})}
        required
      />

      <input
        type="text"
        placeholder="First Name"
        value={formData.firstName}
        onChange={(e) => setFormData({...formData, firstName: e.target.value})}
        required
      />

      <input
        type="text"
        placeholder="Last Name"
        value={formData.lastName}
        onChange={(e) => setFormData({...formData, lastName: e.target.value})}
        required
      />

      <input
        type="text"
        placeholder="Company Name"
        value={formData.companyName}
        onChange={(e) => setFormData({...formData, companyName: e.target.value})}
        required
      />

      <input
        type="tel"
        placeholder="Phone (+919876543210)"
        value={formData.phone}
        onChange={(e) => setFormData({...formData, phone: e.target.value})}
      />

      <button type="submit" disabled={loading}>
        {loading ? 'Creating Account...' : 'Sign Up'}
      </button>
    </form>
  );
}
```

---

### Example 2: Email Availability Check

**JavaScript (Real-time Validation):**
```javascript
const checkEmailAvailability = async (email) => {
  try {
    const response = await fetch(
      `http://localhost:8081/api/v1/auth/check-email?email=${encodeURIComponent(email)}`
    );
    const data = await response.json();
    return data.available;
  } catch (error) {
    console.error('Failed to check email:', error);
    return false;
  }
};

// Usage in form
const emailInput = document.getElementById('email');
let debounceTimer;

emailInput.addEventListener('input', (e) => {
  clearTimeout(debounceTimer);

  debounceTimer = setTimeout(async () => {
    const email = e.target.value;
    if (email && email.includes('@')) {
      const available = await checkEmailAvailability(email);

      if (!available) {
        // Show error message
        emailInput.setCustomValidity('Email already exists');
      } else {
        emailInput.setCustomValidity('');
      }
    }
  }, 500); // Debounce 500ms
});
```

---

## Error Handling

### Error Response Format

All errors follow this structure:

```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable error message",
  "fields": {
    "fieldName": "Field-specific error message"
  }
}
```

### Common Error Codes

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| 400 | `VALIDATION_ERROR` | Invalid request data (check `fields` for details) |
| 401 | `UNAUTHORIZED` | Missing or invalid JWT token |
| 403 | `FORBIDDEN` | User doesn't have permission to access resource |
| 404 | `NOT_FOUND` | Resource not found |
| 409 | `CONFLICT` | Resource already exists (e.g., duplicate email) |
| 500 | `INTERNAL_SERVER_ERROR` | Server error |
| 503 | `SERVICE_UNAVAILABLE` | External service (Keycloak/DB) unavailable |

### Frontend Error Handling Best Practices

```javascript
async function apiCall(url, options) {
  try {
    const response = await fetch(url, options);
    const data = await response.json();

    // Handle specific HTTP status codes
    switch (response.status) {
      case 200:
      case 201:
        return { success: true, data };

      case 400:
        // Validation errors - show field-specific messages
        return {
          success: false,
          validationErrors: data.fields,
          message: data.message
        };

      case 401:
        // Unauthorized - redirect to login
        window.location.href = '/login';
        return { success: false, message: 'Session expired' };

      case 409:
        // Conflict - resource already exists
        return {
          success: false,
          message: data.message || 'Resource already exists'
        };

      case 503:
        // Service unavailable - show retry option
        return {
          success: false,
          message: 'Service temporarily unavailable. Please try again.',
          retry: true
        };

      default:
        return {
          success: false,
          message: data.message || 'An error occurred'
        };
    }
  } catch (error) {
    // Network error
    return {
      success: false,
      message: 'Network error. Please check your connection.',
      networkError: true
    };
  }
}
```

---

## Keycloak Integration

### Keycloak Configuration

**Realm:** `hrms-saas`
**Server URL:** `http://localhost:8090`
**Client ID:** `hrms-web-app`
**Client Secret:** `AhuaZRTwH4wsXHFrmMEciDjo1Kc8aS0M`

### Authentication URLs

```javascript
const keycloakConfig = {
  url: 'http://localhost:8090',
  realm: 'hrms-saas',
  clientId: 'hrms-web-app',
};

// Authorization Endpoint
const authUrl = `${keycloakConfig.url}/realms/${keycloakConfig.realm}/protocol/openid-connect/auth`;

// Token Endpoint
const tokenUrl = `${keycloakConfig.url}/realms/${keycloakConfig.realm}/protocol/openid-connect/token`;

// Logout Endpoint
const logoutUrl = `${keycloakConfig.url}/realms/${keycloakConfig.realm}/protocol/openid-connect/logout`;
```

### Keycloak Integration (React Example)

**Using keycloak-js library:**

```bash
npm install keycloak-js
```

```javascript
import Keycloak from 'keycloak-js';

// Initialize Keycloak
const keycloak = new Keycloak({
  url: 'http://localhost:8090',
  realm: 'hrms-saas',
  clientId: 'hrms-web-app'
});

// Initialize and login
keycloak.init({
  onLoad: 'login-required',
  checkLoginIframe: false
}).then(authenticated => {
  if (authenticated) {
    console.log('User authenticated');
    console.log('Access Token:', keycloak.token);
    console.log('Tenant ID:', keycloak.tokenParsed.tenant_id);

    // Store tenant ID
    localStorage.setItem('tenantId', keycloak.tokenParsed.tenant_id);

    // Make API calls with token
    makeAuthenticatedRequest(keycloak.token);
  } else {
    console.log('User not authenticated');
  }
});

// Make authenticated API call
async function makeAuthenticatedRequest(token) {
  const response = await fetch('http://localhost:8081/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      query: '{ companies { id name } }'
    })
  });

  const data = await response.json();
  return data;
}

// Auto-refresh token
setInterval(() => {
  keycloak.updateToken(70).then(refreshed => {
    if (refreshed) {
      console.log('Token refreshed');
    }
  }).catch(() => {
    console.error('Failed to refresh token');
  });
}, 60000); // Check every 60 seconds

// Logout
function logout() {
  keycloak.logout({
    redirectUri: window.location.origin
  });
}
```

### JWT Token Structure

After successful authentication, Keycloak issues a JWT token containing:

```json
{
  "exp": 1730379443,
  "iat": 1730379143,
  "jti": "5db67d42-7df1-4d3f-b45f-4e1baeae11d5",
  "iss": "http://localhost:8090/realms/hrms-saas",
  "sub": "5db67d42-7df1-4d3f-b45f-4e1baeae11d5",
  "typ": "Bearer",
  "azp": "hrms-web-app",
  "session_state": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "acr": "1",
  "realm_access": {
    "roles": ["company_admin"]
  },
  "scope": "openid profile email",
  "email_verified": true,
  "name": "John Doe",
  "preferred_username": "admin@systech.com",
  "given_name": "John",
  "family_name": "Doe",
  "email": "admin@systech.com",
  "tenant_id": "a1lrqfv7lj7h",
  "user_type": "company_admin",
  "company_name": "Systech Solutions"
}
```

**Key Claims:**
- `tenant_id`: NanoID identifying the company/tenant
- `user_type`: User role (company_admin, hr_user, employee, manager)
- `company_name`: Name of the company
- `email`: User's email address
- `sub`: Keycloak user ID (UUID)

---

## Multi-Tenant Architecture

### Understanding Tenant Isolation

Each company is identified by a unique **tenant_id** (12-char NanoID):
- Generated during signup: `a1lrqfv7lj7h`
- Stored in JWT token as custom claim
- Used for Row-Level Security (RLS) in database

### Tenant ID Usage in Frontend

```javascript
// After signup
const signupResponse = await signup(formData);
localStorage.setItem('tenantId', signupResponse.tenantId);

// After login (from JWT)
const token = keycloak.token;
const decoded = keycloak.tokenParsed;
localStorage.setItem('tenantId', decoded.tenant_id);

// Retrieve tenant ID
const tenantId = localStorage.getItem('tenantId');

// Use in API calls (optional - backend extracts from JWT)
const response = await fetch('/api/v1/employees', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'X-Tenant-ID': tenantId  // Optional header
  }
});
```

### Multi-Tenant Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                     User Login                          │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Keycloak Issues JWT                        │
│         (with tenant_id = a1lrqfv7lj7h)                │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│          Frontend Stores tenant_id                      │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│       API Call with Authorization: Bearer <JWT>         │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│      Backend Validates JWT & Extracts tenant_id         │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│      Backend Sets TenantContext (ThreadLocal)           │
│         TenantContext.setCurrentTenant("a1lrqfv7lj7h")  │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│      Database Queries Filtered by tenant_id             │
│      SELECT * FROM employees WHERE tenant_id = ?        │
└─────────────────────────────────────────────────────────┘
```

---

## Security & CORS

### CORS Configuration

The backend allows requests from the following origins:

```javascript
// Allowed Origins
const allowedOrigins = [
  'http://localhost:3000',
  'http://localhost:3001',
  'http://192.168.1.6:3000'
];

// CORS is pre-configured on backend
// No additional frontend configuration needed
```

### Security Headers

All API responses include security headers:
- `Access-Control-Allow-Origin`
- `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS`
- `Access-Control-Allow-Headers: *`
- `Access-Control-Allow-Credentials: true`
- `Access-Control-Expose-Headers: Authorization, Content-Type`

### Authentication Best Practices

1. **Store JWT Securely**
   ```javascript
   // ❌ Bad: Storing in localStorage (XSS vulnerable)
   localStorage.setItem('token', jwt);

   // ✅ Good: Use httpOnly cookies or memory storage
   // Let keycloak-js handle token storage
   ```

2. **Token Refresh**
   ```javascript
   // Refresh token before expiry
   setInterval(() => {
     keycloak.updateToken(70).then(refreshed => {
       if (refreshed) {
         console.log('Token refreshed');
       }
     });
   }, 60000);
   ```

3. **Handle Token Expiry**
   ```javascript
   // Intercept 401 responses
   fetch(url, options)
     .then(response => {
       if (response.status === 401) {
         // Token expired - re-login
         keycloak.login();
       }
       return response.json();
     });
   ```

4. **Logout Properly**
   ```javascript
   // Clear local storage and redirect to Keycloak logout
   function logout() {
     localStorage.clear();
     keycloak.logout({
       redirectUri: window.location.origin + '/login'
     });
   }
   ```

---

## Company Master Data

### Company Data Structure

After signup, the following company data is available:

```json
{
  "tenantId": "a1lrqfv7lj7h",
  "companyName": "Systech Solutions",
  "companyCode": null,
  "email": "admin@systech.com",
  "phone": "+919876543210",
  "address": null,
  "status": "PENDING_EMAIL_VERIFICATION",
  "subscriptionPlan": "FREE",
  "createdAt": "2025-10-31T14:17:23.689448Z",
  "updatedAt": "2025-10-31T14:17:23.689448Z",
  "createdBy": "admin@systech.com"
}
```

### Company Status States

| Status | Description | User Actions |
|--------|-------------|--------------|
| `PENDING_ACTIVATION` | Initial state after signup | Wait for email verification |
| `PENDING_EMAIL_VERIFICATION` | User created, awaiting email verification | Verify email via link |
| `ACTIVE` | Email verified, account active | Full access to all features |
| `SUSPENDED` | Account temporarily suspended | Contact support |
| `INACTIVE` | Account deactivated | Contact support to reactivate |

### Frontend UI Considerations

1. **Signup Success Screen**
   - Display tenant_id (for support reference)
   - Show "Verify your email" message
   - Provide "Resend verification email" button
   - Store tenant_id in localStorage

2. **Email Verification Pending**
   - Show banner: "Please verify your email to activate your account"
   - Provide "Resend verification" option
   - Disable certain features until verified

3. **Company Profile Page**
   - Display company name, email, phone
   - Show subscription plan (FREE, BASIC, PROFESSIONAL, ENTERPRISE)
   - Show account status with appropriate styling
   - Allow editing of company details (future)

---

## Testing Checklist for Frontend

### Signup Flow
- [ ] Test successful signup with valid data
- [ ] Test email already exists error
- [ ] Test password validation (too short, missing special chars, etc.)
- [ ] Test phone number format validation
- [ ] Test email format validation
- [ ] Test required field validation
- [ ] Test network error handling
- [ ] Test service unavailable (503) scenario
- [ ] Verify tenant_id is stored after successful signup
- [ ] Test "Resend verification email" functionality

### Email Availability Check
- [ ] Test with existing email (should return `available: false`)
- [ ] Test with new email (should return `available: true`)
- [ ] Test debouncing (avoid too many requests)
- [ ] Test network error handling

### Keycloak Integration
- [ ] Test login redirect to Keycloak
- [ ] Test successful login callback
- [ ] Test JWT token storage
- [ ] Test tenant_id extraction from JWT
- [ ] Test token refresh mechanism
- [ ] Test logout flow
- [ ] Test session expiry handling
- [ ] Test unauthorized (401) redirect to login

### Security
- [ ] Verify CORS works from your frontend origin
- [ ] Test with invalid JWT token (should get 401)
- [ ] Test with expired JWT token (should refresh or re-login)
- [ ] Test logout clears all stored data

---

## Contact & Support

For backend API issues or questions:
- **Email:** support@systech.com
- **Slack:** #hrms-backend-support
- **API Status:** http://localhost:8081/actuator/health

---

## Appendix: Quick Reference

### Environment Variables for Frontend

```env
# .env.local
REACT_APP_BACKEND_URL=http://localhost:8081
REACT_APP_KEYCLOAK_URL=http://localhost:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app
```

### Sample .env Configuration

```bash
# Backend API
VITE_API_BASE_URL=http://localhost:8081/api/v1
VITE_GRAPHQL_URL=http://localhost:8081/graphql

# Keycloak
VITE_KEYCLOAK_URL=http://localhost:8090
VITE_KEYCLOAK_REALM=hrms-saas
VITE_KEYCLOAK_CLIENT_ID=hrms-web-app
```

### HTTP Status Codes Quick Reference

| Code | Meaning | Action |
|------|---------|--------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Check validation errors |
| 401 | Unauthorized | Re-authenticate |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Resource already exists |
| 500 | Server Error | Retry or contact support |
| 503 | Service Unavailable | Retry after delay |

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-31
**Maintained By:** Backend Team - Systech Solutions
