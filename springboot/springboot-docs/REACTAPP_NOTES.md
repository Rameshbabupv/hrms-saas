# React Team Notes
## SaaS HRMS MVP - Frontend Development Guide

**Document Version:** 1.0
**Date:** 2025-10-29
**Target Audience:** React Frontend Development Team
**Project:** HRMS SaaS - Company Master & Employee Master MVP

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Keycloak Integration](#keycloak-integration)
4. [GraphQL Client Setup](#graphql-client-setup)
5. [Component Structure](#component-structure)
6. [Forms & Validation](#forms--validation)
7. [Multi-Tenancy Context](#multi-tenancy-context)
8. [Testing Strategy](#testing-strategy)

---

## 1. Quick Start

### Tech Stack
- **Framework:** React 18+
- **Language:** TypeScript 5+
- **UI Library:** Material-UI (MUI) v5
- **Styling:** Tailwind CSS v3
- **State Management:** React Hook Form + Zod validation
- **Data Fetching:** Apollo Client (GraphQL)
- **Authentication:** Keycloak React adapter
- **Build Tool:** Vite or Create React App
- **Testing:** Jest + React Testing Library

### Project Structure
```
nexus-frontend/
├── src/
│   ├── components/
│   │   ├── company/         # Company Master components
│   │   ├── employee/        # Employee Master components
│   │   ├── layout/          # Header, Sidebar, Footer
│   │   └── ui/              # Reusable UI components
│   ├── graphql/
│   │   ├── queries/         # GraphQL queries
│   │   ├── mutations/       # GraphQL mutations
│   │   └── types/           # Generated TypeScript types
│   ├── hooks/               # Custom React hooks
│   ├── context/             # React Context (auth, tenant)
│   ├── utils/               # Utility functions
│   ├── services/            # API services
│   └── App.tsx              # Main app component
├── public/
└── package.json
```

### Timeline
- **Week 1:** Setup + Keycloak auth + Layout
- **Week 2-3:** Company Master forms and list
- **Week 4-6:** Employee Master forms and list
- **Week 7:** Dashboard + Reporting hierarchy
- **Week 8:** Testing + Polish

---

## 2. Architecture Overview

### 2.1 Data Flow

```
User Login
    ↓
Keycloak (returns JWT with company_id)
    ↓
React App (stores token + company_id)
    ↓
GraphQL Query (with Authorization header)
    ↓
Spring Boot Backend (validates JWT, sets tenant context)
    ↓
PostgreSQL (RLS filters by tenant)
    ↓
Data returned to React
```

### 2.2 Key Concepts

**Multi-Tenancy:**
- JWT token contains `company_id` claim
- Frontend extracts and stores `company_id`
- Every GraphQL request includes JWT in Authorization header
- Backend enforces data isolation via Row-Level Security

**Parent-Subsidiary Hierarchy:**
- Parent company users can view subsidiary data (read-only)
- Subsidiary users can only view their own data
- UI shows "Group View" toggle for parent company admins

---

## 3. Keycloak Integration

### 3.1 Install Dependencies

```bash
npm install keycloak-js @react-keycloak/web
npm install jwt-decode  # For decoding JWT tokens
```

### 3.2 Keycloak Configuration

**File:** `src/keycloak.ts`

```typescript
import Keycloak from 'keycloak-js';

const keycloakConfig = {
  url: import.meta.env.VITE_KEYCLOAK_URL || 'https://auth.yourdomain.com',
  realm: 'hrms-saas',
  clientId: 'hrms-web-app',
};

const keycloak = new Keycloak(keycloakConfig);

export default keycloak;
```

### 3.3 App-Level Keycloak Provider

**File:** `src/main.tsx` or `src/index.tsx`

```typescript
import React from 'react';
import ReactDOM from 'react-dom/client';
import { ReactKeycloakProvider } from '@react-keycloak/web';
import keycloak from './keycloak';
import App from './App';
import './index.css';

const eventLogger = (event: unknown, error: unknown) => {
  console.log('Keycloak event:', event, error);
};

const tokenLogger = (tokens: any) => {
  console.log('Keycloak tokens updated');

  // Store tokens in localStorage
  if (tokens.token) {
    localStorage.setItem('access_token', tokens.token);
  }
  if (tokens.refreshToken) {
    localStorage.setItem('refresh_token', tokens.refreshToken);
  }
};

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ReactKeycloakProvider
      authClient={keycloak}
      initOptions={{
        onLoad: 'login-required',  // Force login on app load
        checkLoginIframe: false,
        pkceMethod: 'S256',         // Use PKCE for security
      }}
      onEvent={eventLogger}
      onTokens={tokenLogger}
    >
      <App />
    </ReactKeycloakProvider>
  </React.StrictMode>
);
```

### 3.4 Authentication Context

**File:** `src/context/AuthContext.tsx`

```typescript
import React, { createContext, useContext, useEffect, useState } from 'react';
import { useKeycloak } from '@react-keycloak/web';
import jwtDecode from 'jwt-decode';

interface JWTPayload {
  sub: string;
  email: string;
  preferred_username: string;
  given_name: string;
  family_name: string;
  company_id: string;
  tenant_id: string;
  employee_id?: string;
  user_type: string;
  company_code: string;
  company_name: string;
  realm_access: {
    roles: string[];
  };
}

interface AuthContextType {
  user: JWTPayload | null;
  companyId: string | null;
  tenantId: string | null;
  employeeId: string | null;
  userType: string | null;
  roles: string[];
  isAuthenticated: boolean;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { keycloak, initialized } = useKeycloak();
  const [user, setUser] = useState<JWTPayload | null>(null);

  useEffect(() => {
    if (initialized && keycloak.authenticated && keycloak.token) {
      try {
        const decoded = jwtDecode<JWTPayload>(keycloak.token);
        setUser(decoded);

        // Store tenant context in localStorage
        localStorage.setItem('company_id', decoded.company_id);
        localStorage.setItem('tenant_id', decoded.tenant_id);
        localStorage.setItem('user_type', decoded.user_type);

        if (decoded.employee_id) {
          localStorage.setItem('employee_id', decoded.employee_id);
        }
      } catch (error) {
        console.error('Failed to decode JWT token:', error);
      }
    }
  }, [keycloak.authenticated, keycloak.token, initialized]);

  const logout = () => {
    localStorage.clear();
    keycloak.logout();
  };

  const value: AuthContextType = {
    user,
    companyId: user?.company_id || null,
    tenantId: user?.tenant_id || null,
    employeeId: user?.employee_id || null,
    userType: user?.user_type || null,
    roles: user?.realm_access?.roles || [],
    isAuthenticated: keycloak.authenticated || false,
    logout,
  };

  if (!initialized) {
    return <div>Loading...</div>;
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

### 3.5 Protected Route Component

```typescript
import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

interface ProtectedRouteProps {
  children: React.ReactNode;
  allowedRoles?: string[];
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  allowedRoles
}) => {
  const { isAuthenticated, roles } = useAuth();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (allowedRoles && !allowedRoles.some(role => roles.includes(role))) {
    return <Navigate to="/unauthorized" replace />;
  }

  return <>{children}</>;
};
```

---

## 4. GraphQL Client Setup

### 4.1 Install Apollo Client

```bash
npm install @apollo/client graphql
```

### 4.2 Apollo Client Configuration

**File:** `src/apollo/client.ts`

```typescript
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';

const httpLink = createHttpLink({
  uri: import.meta.env.VITE_GRAPHQL_URL || 'http://localhost:8081/graphql',
});

// Add JWT token to every request
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('access_token');

  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    },
  };
});

// Error handling
const errorLink = onError(({ graphQLErrors, networkError }) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({ message, locations, path }) => {
      console.error(
        `[GraphQL error]: Message: ${message}, Location: ${locations}, Path: ${path}`
      );
    });
  }

  if (networkError) {
    console.error(`[Network error]: ${networkError}`);

    // Handle 401 Unauthorized - token expired
    if ('statusCode' in networkError && networkError.statusCode === 401) {
      localStorage.clear();
      window.location.href = '/login';
    }
  }
});

const client = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache: new InMemoryCache(),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
    },
  },
});

export default client;
```

### 4.3 Wrap App with Apollo Provider

**File:** `src/App.tsx`

```typescript
import { ApolloProvider } from '@apollo/client';
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import apolloClient from './apollo/client';
import AppRoutes from './routes';

function App() {
  return (
    <ApolloProvider client={apolloClient}>
      <AuthProvider>
        <BrowserRouter>
          <AppRoutes />
        </BrowserRouter>
      </AuthProvider>
    </ApolloProvider>
  );
}

export default App;
```

---

## 5. Component Structure

### 5.1 Company List Component

**File:** `src/components/company/CompanyList.tsx`

```typescript
import React from 'react';
import { useQuery, gql } from '@apollo/client';
import {
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  CircularProgress,
  Alert,
} from '@mui/material';

const GET_COMPANIES = gql`
  query GetCompanies {
    companies {
      id
      companyName
      companyCode
      companyType
      corporateGroupName
      employeeCount
      city
      state
    }
  }
`;

interface Company {
  id: string;
  companyName: string;
  companyCode: string;
  companyType: string;
  corporateGroupName?: string;
  employeeCount: number;
  city?: string;
  state?: string;
}

export const CompanyList: React.FC = () => {
  const { loading, error, data } = useQuery<{ companies: Company[] }>(GET_COMPANIES);

  if (loading) return <CircularProgress />;
  if (error) return <Alert severity="error">Error: {error.message}</Alert>;

  return (
    <TableContainer component={Paper}>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Company Code</TableCell>
            <TableCell>Company Name</TableCell>
            <TableCell>Type</TableCell>
            <TableCell>Group</TableCell>
            <TableCell>City</TableCell>
            <TableCell>Employees</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {data?.companies.map((company) => (
            <TableRow key={company.id}>
              <TableCell>{company.companyCode}</TableCell>
              <TableCell>{company.companyName}</TableCell>
              <TableCell>{company.companyType}</TableCell>
              <TableCell>{company.corporateGroupName || '-'}</TableCell>
              <TableCell>{company.city}, {company.state}</TableCell>
              <TableCell>{company.employeeCount}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
};
```

### 5.2 Employee List Component

**File:** `src/components/employee/EmployeeList.tsx`

```typescript
import React, { useState } from 'react';
import { useQuery, gql } from '@apollo/client';
import {
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  TextField,
  Box,
  Chip,
} from '@mui/material';

const GET_EMPLOYEES = gql`
  query GetEmployees($filter: EmployeeFilter) {
    employees(filter: $filter) {
      id
      employeeCode
      employeeName
      email
      designation
      department
      dateOfJoining
      employmentType
      isActive
    }
  }
`;

export const EmployeeList: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');

  const { loading, error, data } = useQuery(GET_EMPLOYEES, {
    variables: {
      filter: {
        isActive: true,
      },
    },
  });

  const filteredEmployees = data?.employees.filter((emp: any) =>
    emp.employeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    emp.employeeCode.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <Box>
      <TextField
        fullWidth
        label="Search employees..."
        variant="outlined"
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
        sx={{ mb: 2 }}
      />

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Employee Code</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Designation</TableCell>
              <TableCell>Department</TableCell>
              <TableCell>Joining Date</TableCell>
              <TableCell>Status</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredEmployees?.map((employee: any) => (
              <TableRow key={employee.id}>
                <TableCell>{employee.employeeCode}</TableCell>
                <TableCell>{employee.employeeName}</TableCell>
                <TableCell>{employee.email}</TableCell>
                <TableCell>{employee.designation}</TableCell>
                <TableCell>{employee.department}</TableCell>
                <TableCell>{employee.dateOfJoining}</TableCell>
                <TableCell>
                  <Chip
                    label={employee.isActive ? 'Active' : 'Inactive'}
                    color={employee.isActive ? 'success' : 'default'}
                    size="small"
                  />
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
};
```

---

## 6. Forms & Validation

### 6.1 Install Form Libraries

```bash
npm install react-hook-form @hookform/resolvers zod
```

### 6.2 Employee Form with Validation

**File:** `src/components/employee/EmployeeForm.tsx`

```typescript
import React from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useMutation, gql } from '@apollo/client';
import {
  TextField,
  Button,
  Grid,
  MenuItem,
  Box,
} from '@mui/material';

const CREATE_EMPLOYEE = gql`
  mutation CreateEmployee($input: CreateEmployeeInput!) {
    createEmployee(input: $input) {
      id
      employeeCode
      employeeName
    }
  }
`;

const employeeSchema = z.object({
  employeeCode: z.string().min(1, 'Employee code is required'),
  employeeName: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  mobileNo: z.string().regex(/^[0-9]{10}$/, 'Mobile number must be 10 digits'),
  dateOfBirth: z.string().optional(),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER']),
  dateOfJoining: z.string().min(1, 'Joining date is required'),
  designation: z.string().min(1, 'Designation is required'),
  department: z.string().min(1, 'Department is required'),
  employmentType: z.enum(['PERMANENT', 'CONTRACT', 'CONSULTANT', 'INTERN']),
  monthlyCtc: z.number().positive('CTC must be positive'),
});

type EmployeeFormData = z.infer<typeof employeeSchema>;

export const EmployeeForm: React.FC = () => {
  const [createEmployee, { loading }] = useMutation(CREATE_EMPLOYEE);

  const {
    control,
    handleSubmit,
    formState: { errors },
    reset,
  } = useForm<EmployeeFormData>({
    resolver: zodResolver(employeeSchema),
    defaultValues: {
      gender: 'MALE',
      employmentType: 'PERMANENT',
    },
  });

  const onSubmit = async (data: EmployeeFormData) => {
    try {
      await createEmployee({
        variables: { input: data },
      });
      alert('Employee created successfully!');
      reset();
    } catch (error) {
      console.error('Error creating employee:', error);
      alert('Failed to create employee');
    }
  };

  return (
    <Box component="form" onSubmit={handleSubmit(onSubmit)} sx={{ mt: 3 }}>
      <Grid container spacing={3}>
        <Grid item xs={12} sm={6}>
          <Controller
            name="employeeCode"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                fullWidth
                label="Employee Code"
                error={!!errors.employeeCode}
                helperText={errors.employeeCode?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} sm={6}>
          <Controller
            name="employeeName"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                fullWidth
                label="Employee Name"
                error={!!errors.employeeName}
                helperText={errors.employeeName?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} sm={6}>
          <Controller
            name="email"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                fullWidth
                label="Email"
                type="email"
                error={!!errors.email}
                helperText={errors.email?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} sm={6}>
          <Controller
            name="mobileNo"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                fullWidth
                label="Mobile Number"
                error={!!errors.mobileNo}
                helperText={errors.mobileNo?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} sm={6}>
          <Controller
            name="gender"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                fullWidth
                select
                label="Gender"
                error={!!errors.gender}
                helperText={errors.gender?.message}
              >
                <MenuItem value="MALE">Male</MenuItem>
                <MenuItem value="FEMALE">Female</MenuItem>
                <MenuItem value="OTHER">Other</MenuItem>
              </TextField>
            )}
          />
        </Grid>

        <Grid item xs={12} sm={6}>
          <Controller
            name="dateOfJoining"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                fullWidth
                label="Date of Joining"
                type="date"
                InputLabelProps={{ shrink: true }}
                error={!!errors.dateOfJoining}
                helperText={errors.dateOfJoining?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} sm={6}>
          <Controller
            name="designation"
            control={control}
            render={({ field}) => (
              <TextField
                {...field}
                fullWidth
                label="Designation"
                error={!!errors.designation}
                helperText={errors.designation?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12} sm={6}>
          <Controller
            name="department"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                fullWidth
                label="Department"
                error={!!errors.department}
                helperText={errors.department?.message}
              />
            )}
          />
        </Grid>

        <Grid item xs={12}>
          <Button
            type="submit"
            variant="contained"
            color="primary"
            size="large"
            disabled={loading}
          >
            {loading ? 'Creating...' : 'Create Employee'}
          </Button>
        </Grid>
      </Grid>
    </Box>
  );
};
```

---

## 7. Multi-Tenancy Context

### 7.1 Tenant Context Hook

**File:** `src/hooks/useTenantContext.ts`

```typescript
import { useAuth } from '../context/AuthContext';

export const useTenantContext = () => {
  const { companyId, user } = useAuth();

  const isParentCompany = user?.company_type === 'HOLDING';

  return {
    companyId,
    tenantId: companyId,
    isParentCompany,
    canViewSubsidiaries: isParentCompany,
  };
};
```

### 7.2 Group View Toggle (for Parent Companies)

```typescript
import React, { useState } from 'react';
import { FormControlLabel, Switch } from '@mui/material';
import { useTenantContext } from '../hooks/useTenantContext';

export const GroupViewToggle: React.FC = () => {
  const { isParentCompany } = useTenantContext();
  const [groupView, setGroupView] = useState(false);

  if (!isParentCompany) {
    return null;  // Only show for parent companies
  }

  return (
    <FormControlLabel
      control={
        <Switch
          checked={groupView}
          onChange={(e) => setGroupView(e.target.checked)}
        />
      }
      label="View All Group Companies"
    />
  );
};
```

---

## 8. Testing Strategy

### 8.1 Component Testing

```typescript
import { render, screen } from '@testing-library/react';
import { MockedProvider } from '@apollo/client/testing';
import { CompanyList, GET_COMPANIES } from './CompanyList';

const mocks = [
  {
    request: {
      query: GET_COMPANIES,
    },
    result: {
      data: {
        companies: [
          {
            id: '1',
            companyName: 'Test Company',
            companyCode: 'TEST001',
            companyType: 'INDEPENDENT',
            employeeCount: 10,
          },
        ],
      },
    },
  },
];

test('renders company list', async () => {
  render(
    <MockedProvider mocks={mocks} addTypename={false}>
      <CompanyList />
    </MockedProvider>
  );

  expect(await screen.findByText('Test Company')).toBeInTheDocument();
});
```

---

## Appendix

### Environment Variables

**File:** `.env`

```env
VITE_KEYCLOAK_URL=https://auth.yourdomain.com
VITE_GRAPHQL_URL=http://localhost:8081/graphql
```

### Related Documents

- **Keycloak Guide:** `KEYCLOAK_IMPLEMENTATION_GUIDE.md`
- **Backend API:** `SPRINGBOOT_NOTES.md`
- **Database Schema:** `DBA_NOTES.md`

---

**End of React Team Notes**

✅ **Timeline:** 8 weeks for MVP completion
