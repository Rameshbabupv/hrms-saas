# HRMS SaaS Frontend - Multi-Tenant React Application

🏢 **Multi-tenant HRMS Application with Keycloak Authentication and Row-Level Security (RLS) Support**

## 📋 Overview

This React application provides the frontend for a multi-tenant HRMS SaaS platform with:

- ✅ **Keycloak Authentication** - SSO with custom JWT claims
- ✅ **Multi-Tenancy Support** - Automatic tenant isolation via `tenant_id`
- ✅ **Row-Level Security (RLS)** - Database-level data isolation
- ✅ **User Provisioning** - Register employees with tenant context
- ✅ **Role-Based Access Control** - 5 user roles (super_admin, company_admin, hr_user, manager, employee)

## 🏗️ Architecture

```
┌─────────────────┐
│  React Frontend │  ← You are here
│  (Port 3000)    │
└────────┬────────┘
         │ 1. Login Request
         ▼
┌─────────────────────────┐
│  Keycloak Server        │
│  Realm: hrms-saas       │
│  (Port 8090)            │
└────────┬────────────────┘
         │ 2. JWT Token with company_id, tenant_id
         ▼
┌─────────────────────────┐
│  Spring Boot Backend    │
│  (Port 8081)            │
│  - Validates JWT        │
│  - Extracts tenant_id   │
│  - Sets RLS context     │
└────────┬────────────────┘
         │ 3. Query with RLS
         ▼
┌─────────────────────────┐
│  PostgreSQL Database    │
│  - Row Level Security   │
│  - Filters by tenant_id │
└─────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ and npm
- Keycloak server running on port 8090
- Backend API running on port 8081
- PostgreSQL database with RLS configured

### Installation

```bash
# Install dependencies
npm install

# Copy environment configuration
cp .env.example .env

# Update .env with your Keycloak configuration
# See "Configuration" section below

# Start development server
npm start
```

The app will open at `http://localhost:3000`

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# Keycloak Configuration
REACT_APP_KEYCLOAK_URL=http://localhost:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT=hrms-web-app

# Backend API
REACT_APP_API_URL=http://localhost:8081
REACT_APP_GRAPHQL_URL=http://localhost:8081/graphql

# Application
REACT_APP_NAME=HRMS SaaS Platform
NODE_ENV=development
```

### Keycloak Setup Required

Before running the app, ensure Keycloak is configured with:

1. **Realm**: `hrms-saas`
2. **Client**: `hrms-web-app` (confidential client)
3. **Custom JWT Mappers** for:
   - `company_id` (UUID)
   - `tenant_id` (UUID)
   - `employee_id` (UUID, optional)
   - `user_type` (string)
   - `company_code` (string, optional)
   - `company_name` (string, optional)

See `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md` for detailed setup instructions.

## 📁 Project Structure

```
src/
├── components/
│   ├── auth/
│   │   └── UserRegistration.tsx    # User registration with tenant_id
│   ├── layout/
│   └── ui/
├── contexts/
│   └── AuthContext.tsx              # Authentication + Tenant context
├── services/
│   ├── keycloak.service.ts          # Keycloak auth + tenant extraction
│   └── keycloak-admin.service.ts    # User provisioning API
├── types/
│   └── auth.types.ts                # TypeScript types for auth & tenancy
├── hooks/
├── utils/
└── App.tsx
```

## 🔐 Authentication Flow

### 1. User Login

```tsx
import { useAuth } from './contexts/AuthContext';

function LoginButton() {
  const { login, isAuthenticated } = useAuth();

  if (isAuthenticated) {
    return <div>Already logged in</div>;
  }

  return <button onClick={login}>Login with Keycloak</button>;
}
```

### 2. Access Tenant Context

```tsx
import { useAuth, useTenant } from './contexts/AuthContext';

function Dashboard() {
  const { user } = useAuth();
  const { tenantContext, companyId, companyName } = useTenant();

  return (
    <div>
      <h1>Welcome {user?.firstName}</h1>
      <p>Company: {companyName}</p>
      <p>Tenant ID (for RLS): {companyId}</p>
    </div>
  );
}
```

### 3. Make API Calls with Tenant Context

```tsx
import { useAuth } from './contexts/AuthContext';

function EmployeeList() {
  const { accessToken, getCompanyId } = useAuth();

  useEffect(() => {
    // Token automatically includes tenant_id in JWT claims
    // Backend will extract it for RLS
    fetch('http://localhost:8081/api/employees', {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        // No need to manually send company_id - it's in the JWT!
      },
    })
      .then(res => res.json())
      .then(data => console.log('Employees:', data));
  }, [accessToken]);

  return <div>...</div>;
}
```

## 👥 User Registration (with Tenant ID)

### Register New Employee

```tsx
import { UserRegistration } from './components/auth/UserRegistration';

function HRDashboard() {
  return (
    <div>
      <h1>HR Dashboard</h1>
      <UserRegistration />
    </div>
  );
}
```

The `UserRegistration` component:
- ✅ Automatically assigns tenant_id from logged-in user's context
- ✅ Creates user in Keycloak with custom attributes
- ✅ Sends email verification
- ✅ Enforces role-based access (only HR/Admin can register users)

### Programmatic User Creation

```tsx
import { keycloakAdminService } from './services/keycloak-admin.service';
import { useTenant } from './contexts/AuthContext';

async function createEmployee() {
  const { companyId } = useTenant();

  const result = await keycloakAdminService.createUser({
    username: 'john.doe@company.com',
    email: 'john.doe@company.com',
    firstName: 'John',
    lastName: 'Doe',
    companyId: companyId!, // CRITICAL: Tenant ID for RLS
    userType: 'employee',
    password: 'TempPassword123!',
    temporary: true,
    enabled: true,
    emailVerified: false,
    requiredActions: ['VERIFY_EMAIL', 'UPDATE_PASSWORD'],
  });

  console.log('User created:', result.userId);
}
```

## 🔒 Row-Level Security (RLS) Integration

### How It Works

1. **User logs in** → Keycloak returns JWT token
2. **JWT token contains** `company_id` and `tenant_id` custom claims
3. **Frontend extracts tenant context** from JWT
4. **Frontend makes API call** with JWT token in Authorization header
5. **Backend validates JWT** and extracts `tenant_id`
6. **Backend sets PostgreSQL session variable**:
   ```sql
   SELECT set_current_tenant('<tenant_id_from_jwt>');
   ```
7. **RLS policies automatically filter data** by tenant

### Example: Querying Employees

**Frontend Code:**
```tsx
const { accessToken } = useAuth();

// Make API call (tenant_id is in JWT token)
fetch('/api/employees', {
  headers: { 'Authorization': `Bearer ${accessToken}` }
});
```

**Backend Code (Spring Boot):**
```java
// Extract tenant_id from JWT
String tenantId = jwtToken.getClaim("tenant_id");

// Set PostgreSQL session variable for RLS
jdbcTemplate.execute("SELECT set_current_tenant('" + tenantId + "')");

// Query employees - RLS automatically filters by tenant
return employeeRepository.findAll();
```

**Database (PostgreSQL):**
```sql
-- RLS policy automatically applies WHERE clause
SELECT * FROM employee WHERE company_id = current_setting('app.current_tenant_id')::uuid;
```

## 🎭 Role-Based Access Control

### Available Roles

| Role | Description | Can Create Users | Can View Subsidiaries |
|------|-------------|------------------|----------------------|
| `super_admin` | System administrator | ✅ Yes | ✅ Yes (all tenants) |
| `company_admin` | Company owner/admin | ✅ Yes | ✅ Yes (own + subsidiaries) |
| `hr_user` | HR department user | ✅ Yes | ❌ No |
| `manager` | Team manager | ❌ No | ❌ No |
| `employee` | Regular employee | ❌ No | ❌ No |

### Checking Roles

```tsx
import { useAuth } from './contexts/AuthContext';

function AdminPanel() {
  const { isSuperAdmin, isCompanyAdmin, isHRUser, hasRole } = useAuth();

  if (!isCompanyAdmin()) {
    return <div>Access Denied</div>;
  }

  return (
    <div>
      <h1>Admin Panel</h1>
      {isSuperAdmin() && <button>Platform Settings</button>}
      {isHRUser() && <button>Manage Employees</button>}
      {hasRole('manager') && <button>Team Dashboard</button>}
    </div>
  );
}
```

## 🧪 Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Run specific test file
npm test -- UserRegistration.test.tsx
```

## 📚 API Reference

### AuthContext

```tsx
const {
  // Authentication state
  isAuthenticated: boolean;
  loading: boolean;

  // User and tenant
  user: AuthUser | null;
  tenantContext: TenantContext | null;
  accessToken: string | null;

  // Actions
  login: () => Promise<void>;
  logout: () => Promise<void>;

  // Role checks
  hasRole: (role: string) => boolean;
  isSuperAdmin: () => boolean;
  isCompanyAdmin: () => boolean;
  isHRUser: () => boolean;

  // Tenant helpers
  getCompanyId: () => string | null;
  getTenantId: () => string | null;
} = useAuth();
```

### Keycloak Service

```tsx
import { authService } from './services/keycloak.service';

// Get authenticated user
const user = authService.getUser();

// Get tenant context
const tenant = authService.getTenantContext();

// Get access token
const token = authService.getToken();

// Check authentication
const isAuth = authService.isAuthenticated();
```

### Keycloak Admin Service

```tsx
import { keycloakAdminService } from './services/keycloak-admin.service';

// Create user
const result = await keycloakAdminService.createUser(request);

// Send verification email
await keycloakAdminService.sendVerificationEmail(userId);

// Reset password
await keycloakAdminService.resetPassword(userId, newPassword);

// Disable user
await keycloakAdminService.setUserEnabled(userId, false);

// Get users by company
const users = await keycloakAdminService.getUsersByCompanyId(companyId);
```

## 🔧 Troubleshooting

### Issue: JWT Token Missing tenant_id

**Problem:** API calls fail with "Invalid token: Missing tenant context"

**Solution:**
1. Verify Keycloak client mappers are configured correctly
2. Check that user has `company_id` and `tenant_id` attributes set
3. Ensure mappers are added to **access token** (not just ID token)

### Issue: CORS Errors

**Problem:** CORS policy blocking requests to Keycloak

**Solution:**
1. Add frontend URL to "Web Origins" in Keycloak client settings
2. Use `+` to allow all valid redirect URIs

### Issue: User Cannot Register Employees

**Problem:** "Access Denied" error when trying to create users

**Solution:**
1. Verify user has `company_admin` or `hr_user` role
2. Check that JWT token contains correct roles in `realm_access.roles`

## 📖 Related Documentation

- [`docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md`](../docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md) - Complete Keycloak setup guide
- [`docs/DBA_NOTES.md`](../docs/DBA_NOTES.md) - Database RLS configuration
- [`docs/REACTAPP_NOTES.md`](../docs/REACTAPP_NOTES.md) - React development guide

## 🤝 Contributing

This is an internal project. For questions or issues, contact the development team.

## 📄 License

Proprietary - All rights reserved

---

**Built with ❤️ for Systech HRMS SaaS Platform**
