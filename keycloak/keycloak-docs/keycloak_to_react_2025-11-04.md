# Keycloak Integration Guide for React Developers

**Document Version:** 1.0
**Date:** November 4, 2025
**Target Audience:** React Frontend Developers
**Keycloak Realm:** hrms-saas

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Keycloak Configuration Reference](#keycloak-configuration-reference)
4. [React Dependencies](#react-dependencies)
5. [Environment Configuration](#environment-configuration)
6. [Keycloak Setup & Initialization](#keycloak-setup--initialization)
7. [Authentication Flow](#authentication-flow)
8. [Protected Routes](#protected-routes)
9. [API Integration with JWT](#api-integration-with-jwt)
10. [User Profile & Claims](#user-profile--claims)
11. [Role-Based Access Control](#role-based-access-control)
12. [Token Management](#token-management)
13. [Error Handling](#error-handling)
14. [Best Practices](#best-practices)
15. [Testing](#testing)
16. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides comprehensive instructions for React developers to integrate with the **hrms-saas** Keycloak realm for authentication and authorization.

### What You'll Learn

- Setting up Keycloak adapter in React
- Implementing login/logout flows
- Protecting routes with authentication
- Accessing user information and custom JWT claims
- Making authenticated API calls to Spring Boot backend
- Implementing role-based UI components

### Architecture Flow

```
┌──────────────────┐
│   React App      │
│  (localhost:3000)│
└────────┬─────────┘
         │
         │ 1. Redirect to login
         │ 2. Login credentials
         ▼
┌──────────────────┐
│   Keycloak       │
│  (localhost:8090)│
└────────┬─────────┘
         │
         │ 3. JWT Token (with claims)
         ▼
┌──────────────────┐
│   React App      │
│  (Store token)   │
└────────┬─────────┘
         │
         │ 4. API call with JWT
         ▼
┌──────────────────┐
│  Spring Boot API │
│  (localhost:8081)│
└──────────────────┘
```

---

## Prerequisites

### Required Software

- **Node.js:** 18+ or 20+
- **npm:** 9+ or **yarn:** 1.22+
- **React:** 18+
- **TypeScript:** 5+ (recommended)

### Keycloak Server

Ensure Keycloak is running:

```bash
# Test Keycloak accessibility
curl http://localhost:8090/realms/hrms-saas/.well-known/openid-configuration

# Expected: JSON response with issuer, authorization_endpoint, token_endpoint
```

---

## Keycloak Configuration Reference

### Realm Configuration

| Setting | Value |
|---------|-------|
| **Realm Name** | hrms-saas |
| **Keycloak URL** | http://localhost:8090 |
| **Client ID** | hrms-web-app |
| **Client Type** | Public (for React SPA) |
| **Valid Redirect URIs** | `http://localhost:3000/*`, `http://localhost:3001/*` |
| **Web Origins** | `http://localhost:3000`, `http://localhost:3001` |
| **Admin Console** | http://localhost:8090/admin |

### Available Roles

| Role | Description |
|------|-------------|
| `super_admin` | Platform administrator |
| `company_admin` | Company administrator |
| `hr_user` | HR personnel |
| `manager` | Department manager |
| `employee` | Regular employee (default) |

### Custom JWT Claims

When users log in, these custom claims are included in the JWT token:

| Claim | Type | Description | Example |
|-------|------|-------------|---------|
| `tenant_id` | string | 12-char tenant identifier | `a3b9c8d2e1f4` |
| `company_id` | string | Company UUID | `550e8400-e29b-41d4-a716-446655440000` |
| `employee_id` | string | Employee UUID | `660e8400-e29b-41d4-a716-446655440001` |
| `user_type` | string | User role type | `company_admin`, `employee` |
| `company_name` | string | Company display name | `Acme Corporation` |
| `company_code` | string | Company code | `ACME001` |
| `phone` | string | Phone number | `+1234567890` |

---

## React Dependencies

### Installation

Install the official Keycloak JavaScript adapter:

```bash
npm install keycloak-js
# or
yarn add keycloak-js
```

### Additional Recommended Packages

```bash
# For TypeScript support
npm install --save-dev @types/keycloak-js

# For routing (if not already installed)
npm install react-router-dom

# For API calls
npm install axios

# For state management (optional)
npm install zustand
# or
npm install @reduxjs/toolkit react-redux
```

### package.json

Your `package.json` should include:

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "keycloak-js": "^23.0.3",
    "axios": "^1.6.2"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/keycloak-js": "^23.0.0",
    "typescript": "^5.3.0"
  }
}
```

---

## Environment Configuration

### .env File

Create a `.env` file in your React project root:

```env
# Keycloak Configuration
REACT_APP_KEYCLOAK_URL=http://localhost:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app

# Backend API Configuration
REACT_APP_API_URL=http://localhost:8081
REACT_APP_GRAPHQL_URL=http://localhost:8081/graphql

# App Configuration
REACT_APP_NAME=HRMS SaaS
REACT_APP_VERSION=1.0.0
```

### .env.development (Optional)

```env
REACT_APP_KEYCLOAK_URL=http://localhost:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app
REACT_APP_API_URL=http://localhost:8081
```

### .env.production

```env
REACT_APP_KEYCLOAK_URL=https://auth.yourcompany.com
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app
REACT_APP_API_URL=https://api.yourcompany.com
```

---

## Keycloak Setup & Initialization

### 1. Keycloak Configuration File

Create `src/config/keycloak.ts`:

```typescript
import Keycloak from 'keycloak-js';

const keycloakConfig = {
  url: process.env.REACT_APP_KEYCLOAK_URL,
  realm: process.env.REACT_APP_KEYCLOAK_REALM || 'hrms-saas',
  clientId: process.env.REACT_APP_KEYCLOAK_CLIENT_ID || 'hrms-web-app',
};

const keycloak = new Keycloak(keycloakConfig);

export default keycloak;
```

### 2. Keycloak Context Provider

Create `src/context/KeycloakContext.tsx`:

```typescript
import React, { createContext, useContext, useState, useEffect } from 'react';
import keycloak from '../config/keycloak';
import { KeycloakProfile, KeycloakTokenParsed } from 'keycloak-js';

interface KeycloakContextType {
  keycloak: typeof keycloak;
  authenticated: boolean;
  initialized: boolean;
  user: KeycloakProfile | null;
  token: string | null;
  parsedToken: CustomTokenParsed | null;
  login: () => void;
  logout: () => void;
  register: () => void;
  hasRole: (role: string) => boolean;
  loading: boolean;
}

interface CustomTokenParsed extends KeycloakTokenParsed {
  tenant_id?: string;
  company_id?: string;
  employee_id?: string;
  user_type?: string;
  company_name?: string;
  company_code?: string;
  phone?: string;
  realm_access?: {
    roles: string[];
  };
}

const KeycloakContext = createContext<KeycloakContextType | undefined>(undefined);

export const KeycloakProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [authenticated, setAuthenticated] = useState(false);
  const [initialized, setInitialized] = useState(false);
  const [user, setUser] = useState<KeycloakProfile | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [parsedToken, setParsedToken] = useState<CustomTokenParsed | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const initKeycloak = async () => {
      try {
        const authenticated = await keycloak.init({
          onLoad: 'check-sso',
          silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
          pkceMethod: 'S256', // Use PKCE for enhanced security
          checkLoginIframe: false, // Disable iframe checks for better performance
        });

        setAuthenticated(authenticated);
        setInitialized(true);

        if (authenticated) {
          // Load user profile
          const profile = await keycloak.loadUserProfile();
          setUser(profile);
          setToken(keycloak.token || null);
          setParsedToken(keycloak.tokenParsed as CustomTokenParsed || null);

          // Setup token refresh
          setupTokenRefresh();
        }
      } catch (error) {
        console.error('Failed to initialize Keycloak', error);
        setInitialized(true);
      } finally {
        setLoading(false);
      }
    };

    initKeycloak();
  }, []);

  const setupTokenRefresh = () => {
    // Refresh token every 5 minutes
    setInterval(() => {
      keycloak
        .updateToken(70) // Refresh if token expires in 70 seconds
        .then((refreshed) => {
          if (refreshed) {
            console.log('Token refreshed');
            setToken(keycloak.token || null);
            setParsedToken(keycloak.tokenParsed as CustomTokenParsed || null);
          }
        })
        .catch(() => {
          console.error('Failed to refresh token');
          logout();
        });
    }, 60000); // Check every minute
  };

  const login = () => {
    keycloak.login({
      redirectUri: window.location.origin,
    });
  };

  const logout = () => {
    keycloak.logout({
      redirectUri: window.location.origin,
    });
  };

  const register = () => {
    keycloak.register({
      redirectUri: window.location.origin,
    });
  };

  const hasRole = (role: string): boolean => {
    return keycloak.hasRealmRole(role);
  };

  return (
    <KeycloakContext.Provider
      value={{
        keycloak,
        authenticated,
        initialized,
        user,
        token,
        parsedToken,
        login,
        logout,
        register,
        hasRole,
        loading,
      }}
    >
      {children}
    </KeycloakContext.Provider>
  );
};

export const useKeycloak = () => {
  const context = useContext(KeycloakContext);
  if (context === undefined) {
    throw new Error('useKeycloak must be used within a KeycloakProvider');
  }
  return context;
};
```

### 3. Silent Check SSO (Optional)

Create `public/silent-check-sso.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Silent SSO Check</title>
</head>
<body>
    <script>
        parent.postMessage(location.href, location.origin);
    </script>
</body>
</html>
```

### 4. Update App.tsx

Wrap your app with `KeycloakProvider`:

```typescript
import React from 'react';
import { BrowserRouter } from 'react-router-dom';
import { KeycloakProvider } from './context/KeycloakContext';
import AppRoutes from './routes/AppRoutes';
import LoadingSpinner from './components/LoadingSpinner';

function App() {
  return (
    <KeycloakProvider>
      <BrowserRouter>
        <AppContent />
      </BrowserRouter>
    </KeycloakProvider>
  );
}

function AppContent() {
  const { initialized, loading } = useKeycloak();

  if (!initialized || loading) {
    return <LoadingSpinner />;
  }

  return <AppRoutes />;
}

export default App;
```

---

## Authentication Flow

### Login Component

Create `src/components/auth/LoginPage.tsx`:

```typescript
import React from 'react';
import { useKeycloak } from '../../context/KeycloakContext';
import { Navigate } from 'react-router-dom';

const LoginPage: React.FC = () => {
  const { authenticated, login, register } = useKeycloak();

  // Redirect if already authenticated
  if (authenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <div className="login-page">
      <div className="login-container">
        <h1>HRMS SaaS</h1>
        <p>Welcome! Please sign in to continue.</p>

        <div className="login-actions">
          <button onClick={login} className="btn-primary">
            Sign In
          </button>

          <button onClick={register} className="btn-secondary">
            Create Account
          </button>
        </div>

        <div className="login-info">
          <p>Test Credentials:</p>
          <ul>
            <li>Admin: admin@testcompany.com / TestAdmin@123</li>
            <li>Employee: john.doe@testcompany.com / TestUser@123</li>
          </ul>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
```

### Logout Component

Create `src/components/auth/LogoutButton.tsx`:

```typescript
import React from 'react';
import { useKeycloak } from '../../context/KeycloakContext';

const LogoutButton: React.FC = () => {
  const { logout } = useKeycloak();

  return (
    <button onClick={logout} className="btn-logout">
      Sign Out
    </button>
  );
};

export default LogoutButton;
```

### User Profile Display

Create `src/components/auth/UserProfile.tsx`:

```typescript
import React from 'react';
import { useKeycloak } from '../../context/KeycloakContext';

const UserProfile: React.FC = () => {
  const { user, parsedToken } = useKeycloak();

  if (!user || !parsedToken) {
    return null;
  }

  return (
    <div className="user-profile">
      <div className="user-avatar">
        {user.firstName?.[0]}{user.lastName?.[0]}
      </div>

      <div className="user-info">
        <h3>{user.firstName} {user.lastName}</h3>
        <p className="user-email">{user.email}</p>
        <p className="user-company">{parsedToken.company_name}</p>
        <p className="user-role">{parsedToken.user_type}</p>
      </div>

      <div className="user-details">
        <p><strong>Tenant ID:</strong> {parsedToken.tenant_id}</p>
        <p><strong>Company Code:</strong> {parsedToken.company_code}</p>
        {parsedToken.phone && (
          <p><strong>Phone:</strong> {parsedToken.phone}</p>
        )}
      </div>
    </div>
  );
};

export default UserProfile;
```

---

## Protected Routes

### ProtectedRoute Component

Create `src/components/auth/ProtectedRoute.tsx`:

```typescript
import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useKeycloak } from '../../context/KeycloakContext';
import LoadingSpinner from '../LoadingSpinner';

interface ProtectedRouteProps {
  children: React.ReactNode;
  roles?: string[];
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  roles = [],
}) => {
  const { authenticated, initialized, loading, hasRole } = useKeycloak();
  const location = useLocation();

  if (!initialized || loading) {
    return <LoadingSpinner />;
  }

  if (!authenticated) {
    // Redirect to login page with return URL
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Check role-based access
  if (roles.length > 0) {
    const hasRequiredRole = roles.some((role) => hasRole(role));

    if (!hasRequiredRole) {
      return <Navigate to="/unauthorized" replace />;
    }
  }

  return <>{children}</>;
};

export default ProtectedRoute;
```

### Routes Configuration

Create `src/routes/AppRoutes.tsx`:

```typescript
import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import ProtectedRoute from '../components/auth/ProtectedRoute';
import LoginPage from '../pages/auth/LoginPage';
import Dashboard from '../pages/Dashboard';
import EmployeesPage from '../pages/EmployeesPage';
import CompanySettings from '../pages/CompanySettings';
import UnauthorizedPage from '../pages/UnauthorizedPage';
import { useKeycloak } from '../context/KeycloakContext';

const AppRoutes: React.FC = () => {
  const { authenticated } = useKeycloak();

  return (
    <Routes>
      {/* Public Routes */}
      <Route path="/login" element={<LoginPage />} />
      <Route path="/unauthorized" element={<UnauthorizedPage />} />

      {/* Protected Routes */}
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <Dashboard />
          </ProtectedRoute>
        }
      />

      <Route
        path="/employees"
        element={
          <ProtectedRoute roles={['company_admin', 'hr_user', 'manager']}>
            <EmployeesPage />
          </ProtectedRoute>
        }
      />

      <Route
        path="/settings"
        element={
          <ProtectedRoute roles={['company_admin']}>
            <CompanySettings />
          </ProtectedRoute>
        }
      />

      {/* Default Route */}
      <Route
        path="/"
        element={
          authenticated ? (
            <Navigate to="/dashboard" replace />
          ) : (
            <Navigate to="/login" replace />
          )
        }
      />

      {/* 404 Not Found */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

export default AppRoutes;
```

---

## API Integration with JWT

### Axios Interceptor Setup

Create `src/services/api.ts`:

```typescript
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';
import keycloak from '../config/keycloak';

const apiClient: AxiosInstance = axios.create({
  baseURL: process.env.REACT_APP_API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - Add JWT token to all requests
apiClient.interceptors.request.use(
  async (config) => {
    if (keycloak.authenticated && keycloak.token) {
      // Refresh token if needed
      try {
        await keycloak.updateToken(30); // Refresh if expires in 30 seconds
        config.headers.Authorization = `Bearer ${keycloak.token}`;
      } catch (error) {
        console.error('Failed to refresh token', error);
        keycloak.logout();
      }
    }

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor - Handle 401 errors
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      // Token expired or invalid
      console.error('Unauthorized - logging out');
      keycloak.logout();
    }

    return Promise.reject(error);
  }
);

export default apiClient;
```

### GraphQL Client Setup

Create `src/services/graphql.ts`:

```typescript
import axios from 'axios';
import keycloak from '../config/keycloak';

const graphqlClient = async (query: string, variables?: any) => {
  if (!keycloak.authenticated || !keycloak.token) {
    throw new Error('Not authenticated');
  }

  // Refresh token if needed
  await keycloak.updateToken(30);

  const response = await axios.post(
    process.env.REACT_APP_GRAPHQL_URL || 'http://localhost:8081/graphql',
    {
      query,
      variables,
    },
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${keycloak.token}`,
      },
    }
  );

  if (response.data.errors) {
    throw new Error(response.data.errors[0].message);
  }

  return response.data.data;
};

export default graphqlClient;
```

### API Service Example

Create `src/services/employeeService.ts`:

```typescript
import apiClient from './api';
import graphqlClient from './graphql';

export interface Employee {
  id: string;
  companyId: string;
  employeeCode: string;
  employeeName: string;
  email: string;
  designation: string;
  status: string;
}

class EmployeeService {
  // REST API example
  async getEmployeeById(id: string): Promise<Employee> {
    const response = await apiClient.get(`/api/v1/employees/${id}`);
    return response.data;
  }

  // GraphQL example
  async getAllEmployees(): Promise<Employee[]> {
    const query = `
      query GetEmployees {
        employees {
          id
          companyId
          employeeCode
          employeeName
          email
          designation
          status
        }
      }
    `;

    const data = await graphqlClient(query);
    return data.employees;
  }

  async createEmployee(input: Partial<Employee>): Promise<Employee> {
    const mutation = `
      mutation CreateEmployee($input: EmployeeInput!) {
        createEmployee(input: $input) {
          id
          employeeCode
          employeeName
          email
        }
      }
    `;

    const data = await graphqlClient(mutation, { input });
    return data.createEmployee;
  }
}

export default new EmployeeService();
```

### Using API Service in Components

```typescript
import React, { useEffect, useState } from 'react';
import employeeService, { Employee } from '../services/employeeService';
import { useKeycloak } from '../context/KeycloakContext';

const EmployeesPage: React.FC = () => {
  const { parsedToken } = useKeycloak();
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchEmployees = async () => {
      try {
        setLoading(true);
        const data = await employeeService.getAllEmployees();
        setEmployees(data);
      } catch (err: any) {
        setError(err.message || 'Failed to fetch employees');
      } finally {
        setLoading(false);
      }
    };

    fetchEmployees();
  }, []);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className="employees-page">
      <h1>Employees - {parsedToken?.company_name}</h1>
      <p>Tenant ID: {parsedToken?.tenant_id}</p>

      <table>
        <thead>
          <tr>
            <th>Code</th>
            <th>Name</th>
            <th>Email</th>
            <th>Designation</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {employees.map((employee) => (
            <tr key={employee.id}>
              <td>{employee.employeeCode}</td>
              <td>{employee.employeeName}</td>
              <td>{employee.email}</td>
              <td>{employee.designation}</td>
              <td>{employee.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default EmployeesPage;
```

---

## User Profile & Claims

### Access User Information

```typescript
import { useKeycloak } from '../context/KeycloakContext';

function MyComponent() {
  const { user, parsedToken } = useKeycloak();

  return (
    <div>
      {/* Standard user info */}
      <p>Name: {user?.firstName} {user?.lastName}</p>
      <p>Email: {user?.email}</p>
      <p>Username: {user?.username}</p>

      {/* Custom JWT claims */}
      <p>Tenant ID: {parsedToken?.tenant_id}</p>
      <p>Company: {parsedToken?.company_name}</p>
      <p>Company Code: {parsedToken?.company_code}</p>
      <p>User Type: {parsedToken?.user_type}</p>
      <p>Employee ID: {parsedToken?.employee_id}</p>
      <p>Phone: {parsedToken?.phone}</p>

      {/* Roles */}
      <p>Roles: {parsedToken?.realm_access?.roles.join(', ')}</p>
    </div>
  );
}
```

---

## Role-Based Access Control

### Check Roles in Components

```typescript
import { useKeycloak } from '../context/KeycloakContext';

const AdminPanel: React.FC = () => {
  const { hasRole, parsedToken } = useKeycloak();

  const isCompanyAdmin = hasRole('company_admin');
  const isHRUser = hasRole('hr_user');
  const isManager = hasRole('manager');

  return (
    <div>
      {isCompanyAdmin && (
        <div className="admin-section">
          <h2>Company Administration</h2>
          <button>Manage Users</button>
          <button>Company Settings</button>
        </div>
      )}

      {(isCompanyAdmin || isHRUser) && (
        <div className="hr-section">
          <h2>HR Operations</h2>
          <button>Manage Employees</button>
          <button>Payroll</button>
        </div>
      )}

      {(isCompanyAdmin || isHRUser || isManager) && (
        <div className="manager-section">
          <h2>Team Management</h2>
          <button>View Team</button>
          <button>Approve Leave</button>
        </div>
      )}

      {/* All authenticated users */}
      <div className="employee-section">
        <h2>Self Service</h2>
        <button>My Profile</button>
        <button>Request Leave</button>
      </div>
    </div>
  );
};
```

### Conditional Rendering Hook

Create `src/hooks/useAuthorization.ts`:

```typescript
import { useKeycloak } from '../context/KeycloakContext';

export const useAuthorization = () => {
  const { hasRole, parsedToken } = useKeycloak();

  const can = (action: string): boolean => {
    switch (action) {
      case 'manage_company':
        return hasRole('company_admin');

      case 'manage_employees':
        return hasRole('company_admin') || hasRole('hr_user');

      case 'view_employees':
        return (
          hasRole('company_admin') ||
          hasRole('hr_user') ||
          hasRole('manager')
        );

      case 'approve_leave':
        return hasRole('company_admin') || hasRole('manager');

      case 'manage_payroll':
        return hasRole('company_admin') || hasRole('hr_user');

      default:
        return false;
    }
  };

  const isCompanyAdmin = hasRole('company_admin');
  const isHRUser = hasRole('hr_user');
  const isManager = hasRole('manager');
  const isEmployee = hasRole('employee');

  return {
    can,
    isCompanyAdmin,
    isHRUser,
    isManager,
    isEmployee,
    userType: parsedToken?.user_type,
  };
};
```

Usage:

```typescript
import { useAuthorization } from '../hooks/useAuthorization';

const EmployeeActions: React.FC = () => {
  const { can } = useAuthorization();

  return (
    <div>
      {can('manage_employees') && (
        <button>Edit Employee</button>
      )}

      {can('approve_leave') && (
        <button>Approve Leave</button>
      )}

      {can('manage_payroll') && (
        <button>Process Payroll</button>
      )}
    </div>
  );
};
```

---

## Token Management

### Auto Token Refresh

Token refresh is already handled in `KeycloakContext.tsx`:

```typescript
// Refresh token every minute
setInterval(() => {
  keycloak
    .updateToken(70) // Refresh if expires in 70 seconds
    .then((refreshed) => {
      if (refreshed) {
        console.log('Token refreshed');
        setToken(keycloak.token || null);
      }
    })
    .catch(() => {
      console.error('Failed to refresh token');
      logout();
    });
}, 60000);
```

### Manual Token Refresh

```typescript
import { useKeycloak } from '../context/KeycloakContext';

const MyComponent: React.FC = () => {
  const { keycloak } = useKeycloak();

  const refreshToken = async () => {
    try {
      const refreshed = await keycloak.updateToken(30);
      if (refreshed) {
        console.log('Token refreshed successfully');
      } else {
        console.log('Token is still valid');
      }
    } catch (error) {
      console.error('Failed to refresh token', error);
    }
  };

  return <button onClick={refreshToken}>Refresh Token</button>;
};
```

### Token Expiration Handling

Create `src/hooks/useTokenExpiration.ts`:

```typescript
import { useEffect, useState } from 'react';
import { useKeycloak } from '../context/KeycloakContext';

export const useTokenExpiration = () => {
  const { keycloak, parsedToken } = useKeycloak();
  const [timeLeft, setTimeLeft] = useState<number>(0);

  useEffect(() => {
    if (!parsedToken?.exp) return;

    const interval = setInterval(() => {
      const now = Math.floor(Date.now() / 1000);
      const expiresIn = parsedToken.exp - now;
      setTimeLeft(expiresIn);

      // Auto refresh if less than 1 minute left
      if (expiresIn < 60 && expiresIn > 0) {
        keycloak.updateToken(30).catch((error) => {
          console.error('Token refresh failed', error);
        });
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [keycloak, parsedToken]);

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return {
    timeLeft,
    formattedTime: formatTime(timeLeft),
    isExpiringSoon: timeLeft < 300, // 5 minutes
  };
};
```

---

## Error Handling

### Error Boundary Component

Create `src/components/ErrorBoundary.tsx`:

```typescript
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
    };
  }

  static getDerivedStateFromError(error: Error): State {
    return {
      hasError: true,
      error,
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-page">
          <h1>Something went wrong</h1>
          <p>{this.state.error?.message}</p>
          <button onClick={() => window.location.reload()}>
            Reload Page
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
```

### API Error Handling

Create `src/utils/errorHandler.ts`:

```typescript
import axios from 'axios';

export interface ApiError {
  status: number;
  message: string;
  details?: any;
}

export const handleApiError = (error: any): ApiError => {
  if (axios.isAxiosError(error)) {
    if (error.response) {
      // Server responded with error
      return {
        status: error.response.status,
        message: error.response.data?.message || error.message,
        details: error.response.data,
      };
    } else if (error.request) {
      // Request made but no response
      return {
        status: 0,
        message: 'Network error - please check your connection',
      };
    }
  }

  // Generic error
  return {
    status: 500,
    message: error.message || 'An unexpected error occurred',
  };
};
```

Usage:

```typescript
import { handleApiError } from '../utils/errorHandler';

const fetchData = async () => {
  try {
    const data = await employeeService.getAllEmployees();
    setEmployees(data);
  } catch (error) {
    const apiError = handleApiError(error);
    setError(apiError.message);

    if (apiError.status === 401) {
      // Handle unauthorized
      console.log('User not authenticated');
    } else if (apiError.status === 403) {
      // Handle forbidden
      console.log('User not authorized');
    }
  }
};
```

---

## Best Practices

### 1. Security Best Practices

- **Never store tokens in localStorage or sessionStorage**
  - Keycloak handles token storage securely

- **Always use HTTPS in production**
  - Configure Keycloak and API with SSL certificates

- **Implement PKCE for authorization code flow**
  - Already configured in `KeycloakContext.tsx`

- **Validate tokens on every API request**
  - Backend validates JWT signatures

- **Use short token lifetimes**
  - Default: 5 minutes for access tokens
  - Automatic refresh handled by Keycloak adapter

### 2. Performance Best Practices

- **Implement code splitting**
  ```typescript
  const Dashboard = lazy(() => import('./pages/Dashboard'));
  const EmployeesPage = lazy(() => import('./pages/EmployeesPage'));
  ```

- **Cache API responses**
  - Use React Query or SWR for data fetching

- **Debounce token refresh checks**
  - Don't refresh on every request

- **Use React.memo for expensive components**

### 3. UX Best Practices

- **Show loading states during authentication**
  - Display spinner while Keycloak initializes

- **Provide clear error messages**
  - "Session expired - please login again"
  - "You don't have permission to access this page"

- **Implement session timeout warnings**
  - Warn user before token expires

- **Graceful logout**
  - Clear application state on logout

### 4. Code Organization

```
src/
├── components/
│   ├── auth/
│   │   ├── LoginPage.tsx
│   │   ├── LogoutButton.tsx
│   │   ├── ProtectedRoute.tsx
│   │   └── UserProfile.tsx
│   ├── common/
│   └── layout/
├── config/
│   └── keycloak.ts
├── context/
│   └── KeycloakContext.tsx
├── hooks/
│   ├── useAuthorization.ts
│   └── useTokenExpiration.ts
├── pages/
│   ├── Dashboard.tsx
│   ├── EmployeesPage.tsx
│   └── UnauthorizedPage.tsx
├── routes/
│   └── AppRoutes.tsx
├── services/
│   ├── api.ts
│   ├── graphql.ts
│   └── employeeService.ts
└── utils/
    └── errorHandler.ts
```

---

## Testing

### Mock Keycloak for Tests

Create `src/__mocks__/keycloak.ts`:

```typescript
const mockKeycloak = {
  init: jest.fn().mockResolvedValue(true),
  login: jest.fn(),
  logout: jest.fn(),
  register: jest.fn(),
  updateToken: jest.fn().mockResolvedValue(false),
  loadUserProfile: jest.fn().mockResolvedValue({
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'User',
  }),
  hasRealmRole: jest.fn().mockReturnValue(true),
  authenticated: true,
  token: 'mock-token',
  tokenParsed: {
    sub: 'user-id',
    email: 'test@example.com',
    tenant_id: 'test-tenant',
    company_id: 'test-company',
    user_type: 'company_admin',
    company_name: 'Test Company',
  },
};

export default mockKeycloak;
```

### Test Protected Routes

```typescript
import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import ProtectedRoute from '../components/auth/ProtectedRoute';
import { KeycloakProvider } from '../context/KeycloakContext';

jest.mock('../config/keycloak');

test('renders children when authenticated', () => {
  render(
    <KeycloakProvider>
      <BrowserRouter>
        <ProtectedRoute>
          <div>Protected Content</div>
        </ProtectedRoute>
      </BrowserRouter>
    </KeycloakProvider>
  );

  expect(screen.getByText('Protected Content')).toBeInTheDocument();
});
```

---

## Troubleshooting

### Issue: Keycloak fails to initialize

**Solutions:**
1. Check Keycloak is running: `curl http://localhost:8090`
2. Verify realm exists: Check Admin Console
3. Check browser console for errors
4. Verify client configuration in Keycloak

### Issue: Token not included in API requests

**Solutions:**
1. Check axios interceptor is configured
2. Verify `keycloak.token` is not null
3. Check token expiration
4. Ensure `updateToken()` is called before request

### Issue: CORS errors

**Solutions:**
1. Verify backend CORS configuration
2. Check allowed origins include React dev server
3. Ensure credentials are allowed
4. Check preflight OPTIONS requests

### Issue: Infinite redirect loop

**Solutions:**
1. Change `onLoad` to `'check-sso'` instead of `'login-required'`
2. Disable `checkLoginIframe`
3. Clear browser cookies/cache
4. Check redirect URIs in Keycloak client

---

## Summary Checklist

Before deploying:

- [ ] Keycloak is running and accessible
- [ ] Environment variables configured (.env file)
- [ ] keycloak-js dependency installed
- [ ] KeycloakContext provider implemented
- [ ] App wrapped with KeycloakProvider
- [ ] Protected routes configured
- [ ] API interceptors set up for JWT
- [ ] Error handling implemented
- [ ] Role-based access control implemented
- [ ] Token refresh working
- [ ] Logout functionality tested
- [ ] Production URLs configured (.env.production)

---

## Additional Resources

### Documentation
- [Keycloak JS Adapter](https://www.keycloak.org/docs/latest/securing_apps/#_javascript_adapter)
- [React Router](https://reactrouter.com/)
- [Axios Documentation](https://axios-http.com/)

### Example Code
- Complete working example in: `/reactapp/src/`

---

**Document Owner:** Frontend Development Team
**Last Updated:** November 4, 2025

---

*This document is part of the HRMS SaaS project documentation suite.*
