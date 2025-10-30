# HRMS SaaS - Spring Boot Microservices Architecture

## 📋 Document Overview

**Project:** HRMS SaaS Multi-Tenant Platform
**Target Audience:** Spring Boot Backend Developers
**Architecture:** REST + GraphQL Microservices
**Security:** Keycloak OAuth2/OIDC with JWT
**Database:** PostgreSQL with Row-Level Security (RLS)
**Tenant Isolation:** NanoID-based Multi-Tenancy

---

## 🎯 Architecture Overview

### **High-Level Architecture**

```
┌─────────────────┐
│   React App     │  (Port 3000)
│  (Frontend)     │  - Sign-up form
│                 │  - Dashboard
└────────┬────────┘
         │ HTTP/HTTPS
         │ REST (Auth) + GraphQL (Business)
         ▼
┌─────────────────────────────────────┐
│      Spring Boot Backend            │  (Port 8081)
│  ┌──────────────────────────────┐   │
│  │   REST Controllers           │   │  /api/v1/auth/*
│  │   - Sign-up                  │   │
│  │   - Email verification       │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │   GraphQL API                │   │  /graphql
│  │   - Employee queries         │   │
│  │   - Department queries       │   │
│  │   - Mutations                │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │   Security Layer             │   │
│  │   - JWT Validation           │   │
│  │   - Tenant Context Filter    │   │
│  │   - RLS Setup                │   │
│  └──────────────────────────────┘   │
└────────┬─────────────────┬──────────┘
         │                 │
         ▼                 ▼
┌─────────────────┐  ┌──────────────────┐
│   Keycloak      │  │   PostgreSQL     │
│  (Port 8090)    │  │   (Port 5432)    │
│                 │  │                  │
│ - User Storage  │  │ - company_master │
│ - JWT Tokens    │  │ - employees      │
│ - Admin API     │  │ - RLS Policies   │
└─────────────────┘  └──────────────────┘
```

---

## 🔑 Core Concepts

### **1. Tenant Isolation with NanoID**

**What is a Tenant?**
- Each company is a separate tenant
- Complete data isolation between tenants
- Tenant identified by 12-character NanoID

**NanoID Format:**
```
tenant_id: a3b9c8d2e1f4
- Length: 12 characters
- Character set: a-z, 0-9 (lowercase alphanumeric)
- Collision probability: ~1 million years for 1000 IDs/hour
```

**Example:**
```
Company: Systech
tenant_id: a3b9c8d2e1f4

Company: Acme Corp
tenant_id: x7y8z9a1b2c3
```

### **2. Authentication Flow**

```
┌──────────┐                 ┌──────────┐                 ┌──────────┐
│  React   │                 │  Spring  │                 │ Keycloak │
│   App    │                 │   Boot   │                 │          │
└────┬─────┘                 └────┬─────┘                 └────┬─────┘
     │                            │                            │
     │ 1. POST /api/v1/auth/signup│                            │
     ├───────────────────────────>│                            │
     │   { email, password,       │                            │
     │     companyName }           │                            │
     │                            │ 2. Generate NanoID         │
     │                            │    tenant_id=a3b9c8d2e1f4  │
     │                            │                            │
     │                            │ 3. Create company_master   │
     │                            │    in PostgreSQL           │
     │                            │                            │
     │                            │ 4. Create Keycloak user    │
     │                            ├───────────────────────────>│
     │                            │   POST /admin/realms/      │
     │                            │   hrms-saas/users          │
     │                            │   attributes: {            │
     │                            │     tenant_id: a3b9c8...   │
     │                            │   }                        │
     │                            │                            │
     │                            │ 5. Send verification email │
     │                            │<───────────────────────────┤
     │                            │                            │
     │ 6. Response                │                            │
     │<───────────────────────────┤                            │
     │   { tenantId, userId,      │                            │
     │     requiresVerification } │                            │
     │                            │                            │
     │ 7. User clicks email link  │                            │
     │    (Keycloak verifies)     │                            │
     │                            │                            │
     │ 8. Click "Sign In"         │                            │
     │    Redirect to Keycloak    │                            │
     ├────────────────────────────┼───────────────────────────>│
     │                            │                            │
     │ 9. JWT Token (with tenant_id)                          │
     │<───────────────────────────┼────────────────────────────┤
     │   { sub, email,            │                            │
     │     tenant_id: a3b9c8...   │                            │
     │   }                        │                            │
```

### **3. Multi-Tenant Request Flow**

```
React sends GraphQL query with JWT:
┌──────────────────────────────────────────────┐
│ Authorization: Bearer eyJhbGciOiJSUzI1NiI... │
└──────────────────────────────────────────────┘

Spring Boot Security Filter:
1. Validate JWT signature
2. Extract tenant_id from JWT claims
3. Set PostgreSQL session variable
4. Execute query with RLS

PostgreSQL:
1. Check RLS policy
2. Filter results WHERE tenant_id = 'a3b9c8d2e1f4'
3. Return only tenant's data
```

---

## 📊 Database Schema

### **Schema Design with NanoID**

```sql
-- ============================================
-- 1. COMPANY MASTER TABLE
-- ============================================
CREATE TABLE company_master (
    tenant_id VARCHAR(21) PRIMARY KEY,  -- NanoID: 12 chars (using VARCHAR(21) for safety)
    company_name VARCHAR(255) NOT NULL,
    company_code VARCHAR(50),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    address TEXT,
    status VARCHAR(20) DEFAULT 'PENDING_ACTIVATION',  -- PENDING_ACTIVATION, ACTIVE, SUSPENDED
    subscription_plan VARCHAR(50) DEFAULT 'FREE',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(100),

    CONSTRAINT company_name_min_length CHECK (LENGTH(company_name) >= 2),
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_company_email ON company_master(email);
CREATE INDEX idx_company_status ON company_master(status);

COMMENT ON TABLE company_master IS 'Master table for all companies (tenants)';
COMMENT ON COLUMN company_master.tenant_id IS 'NanoID: 12-char unique identifier for tenant isolation';
COMMENT ON COLUMN company_master.status IS 'Company activation status';

-- ============================================
-- 2. EMPLOYEES TABLE (Multi-Tenant)
-- ============================================
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(21) NOT NULL,
    employee_code VARCHAR(50) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    date_of_birth DATE,
    date_of_joining DATE,
    designation VARCHAR(100),
    department_id UUID,
    manager_id UUID,
    employment_type VARCHAR(50),  -- FULL_TIME, PART_TIME, CONTRACT
    status VARCHAR(20) DEFAULT 'ACTIVE',  -- ACTIVE, INACTIVE, TERMINATED
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(100),

    CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES company_master(tenant_id) ON DELETE CASCADE,
    CONSTRAINT fk_manager FOREIGN KEY (manager_id) REFERENCES employees(id),
    CONSTRAINT unique_employee_code_per_tenant UNIQUE (tenant_id, employee_code),
    CONSTRAINT unique_email_per_tenant UNIQUE (tenant_id, email)
);

CREATE INDEX idx_employees_tenant ON employees(tenant_id);
CREATE INDEX idx_employees_email ON employees(tenant_id, email);
CREATE INDEX idx_employees_status ON employees(tenant_id, status);

COMMENT ON TABLE employees IS 'Multi-tenant employee records';
COMMENT ON COLUMN employees.tenant_id IS 'References company_master.tenant_id for RLS';

-- ============================================
-- 3. DEPARTMENTS TABLE (Multi-Tenant)
-- ============================================
CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(21) NOT NULL,
    department_code VARCHAR(50) NOT NULL,
    department_name VARCHAR(255) NOT NULL,
    description TEXT,
    head_of_department_id UUID,
    parent_department_id UUID,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES company_master(tenant_id) ON DELETE CASCADE,
    CONSTRAINT fk_hod FOREIGN KEY (head_of_department_id) REFERENCES employees(id),
    CONSTRAINT fk_parent_dept FOREIGN KEY (parent_department_id) REFERENCES departments(id),
    CONSTRAINT unique_dept_code_per_tenant UNIQUE (tenant_id, department_code)
);

CREATE INDEX idx_departments_tenant ON departments(tenant_id);

-- ============================================
-- 4. USERS TABLE (Multi-Tenant)
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(21) NOT NULL,
    keycloak_user_id VARCHAR(100) UNIQUE NOT NULL,
    employee_id UUID,
    email VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL,
    user_type VARCHAR(50) NOT NULL,  -- company_admin, hr_user, manager, employee
    status VARCHAR(20) DEFAULT 'ACTIVE',
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES company_master(tenant_id) ON DELETE CASCADE,
    CONSTRAINT fk_employee FOREIGN KEY (employee_id) REFERENCES employees(id),
    CONSTRAINT unique_email_per_tenant UNIQUE (tenant_id, email)
);

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_keycloak ON users(keycloak_user_id);

-- ============================================
-- 5. ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on employees table
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_policy ON employees
    USING (tenant_id = current_setting('app.current_tenant', true)::VARCHAR);

COMMENT ON POLICY tenant_isolation_policy ON employees IS
    'RLS policy: Users can only see employees from their own tenant';

-- Enable RLS on departments table
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_policy ON departments
    USING (tenant_id = current_setting('app.current_tenant', true)::VARCHAR);

-- Enable RLS on users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_policy ON users
    USING (tenant_id = current_setting('app.current_tenant', true)::VARCHAR);

-- ============================================
-- 6. TESTING RLS
-- ============================================

-- Set tenant context
SET app.current_tenant = 'a3b9c8d2e1f4';

-- This will only return employees for tenant 'a3b9c8d2e1f4'
SELECT * FROM employees;

-- Change tenant context
SET app.current_tenant = 'x7y8z9a1b2c3';

-- This will only return employees for tenant 'x7y8z9a1b2c3'
SELECT * FROM employees;
```

---

## 🔐 Security Configuration

### **JWT Token Structure**

**Keycloak JWT Token (after login):**
```json
{
  "exp": 1735567200,
  "iat": 1735563600,
  "jti": "abc123-uuid",
  "iss": "http://localhost:8090/realms/hrms-saas",
  "aud": "hrms-web-app",
  "sub": "a1b2c3d4-uuid-keycloak-user-id",
  "typ": "Bearer",
  "azp": "hrms-web-app",
  "session_state": "xyz789",
  "scope": "openid profile email",
  "email_verified": true,
  "name": "Babu Ramesh",
  "preferred_username": "babu@systech.com",
  "given_name": "Babu",
  "family_name": "Ramesh",
  "email": "babu@systech.com",

  "tenant_id": "a3b9c8d2e1f4",
  "user_type": "company_admin",
  "company_name": "Systech",
  "employee_id": "emp-uuid-optional",

  "realm_access": {
    "roles": ["company_admin", "hr_user"]
  }
}
```

**Key Claims:**
- `tenant_id`: NanoID for RLS (CRITICAL)
- `user_type`: Role within the company
- `sub`: Keycloak user ID
- `email`: User email

---

## 🚀 Spring Boot Project Structure

```
hrms-saas-backend/
├── pom.xml
├── docker-compose.yml
├── README.md
│
├── src/main/java/com/systech/hrms/
│   ├── HrmsSaasApplication.java
│   │
│   ├── config/
│   │   ├── SecurityConfig.java           # JWT validation, OAuth2 Resource Server
│   │   ├── GraphQLConfig.java            # GraphQL configuration
│   │   ├── DatabaseConfig.java           # PostgreSQL, Flyway
│   │   ├── KeycloakConfig.java           # Keycloak Admin API client
│   │   └── NanoIdConfig.java             # NanoID generator bean
│   │
│   ├── security/
│   │   ├── TenantContext.java            # ThreadLocal tenant storage
│   │   ├── TenantFilter.java             # Extract tenant_id from JWT
│   │   ├── RLSInterceptor.java           # Set PostgreSQL session variable
│   │   └── JwtAuthenticationConverter.java
│   │
│   ├── controller/
│   │   └── auth/
│   │       ├── SignUpController.java     # POST /api/v1/auth/signup
│   │       └── EmailVerificationController.java
│   │
│   ├── graphql/
│   │   ├── resolver/
│   │   │   ├── EmployeeQueryResolver.java
│   │   │   ├── EmployeeMutationResolver.java
│   │   │   ├── DepartmentQueryResolver.java
│   │   │   └── CompanyQueryResolver.java
│   │   └── scalar/
│   │       └── DateScalar.java
│   │
│   ├── service/
│   │   ├── SignUpService.java            # Business logic for signup
│   │   ├── KeycloakAdminService.java     # Keycloak Admin API
│   │   ├── TenantService.java            # Tenant/company operations
│   │   ├── EmployeeService.java
│   │   ├── DepartmentService.java
│   │   └── UserService.java
│   │
│   ├── repository/
│   │   ├── CompanyRepository.java
│   │   ├── EmployeeRepository.java
│   │   ├── DepartmentRepository.java
│   │   └── UserRepository.java
│   │
│   ├── entity/
│   │   ├── CompanyMaster.java
│   │   ├── Employee.java
│   │   ├── Department.java
│   │   └── User.java
│   │
│   ├── dto/
│   │   ├── auth/
│   │   │   ├── SignUpRequest.java
│   │   │   ├── SignUpResponse.java
│   │   │   └── EmailVerificationRequest.java
│   │   └── graphql/
│   │       ├── EmployeeInput.java
│   │       └── DepartmentInput.java
│   │
│   ├── exception/
│   │   ├── GlobalExceptionHandler.java
│   │   ├── TenantNotFoundException.java
│   │   ├── EmailAlreadyExistsException.java
│   │   └── KeycloakIntegrationException.java
│   │
│   └── util/
│       ├── NanoIdGenerator.java          # Generate unique NanoIDs
│       └── TenantValidator.java          # Validate tenant context
│
├── src/main/resources/
│   ├── application.yml
│   ├── application-dev.yml
│   ├── application-prod.yml
│   ├── db/migration/
│   │   ├── V1__create_company_master.sql
│   │   ├── V2__create_employees.sql
│   │   ├── V3__create_departments.sql
│   │   ├── V4__create_users.sql
│   │   └── V5__enable_rls.sql
│   └── graphql/
│       └── schema.graphqls              # GraphQL schema definition
│
└── src/test/java/com/systech/hrms/
    ├── controller/
    ├── service/
    └── integration/
        └── MultiTenantIntegrationTest.java
```

---

## 📦 Maven Dependencies (pom.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.1</version>
        <relativePath/>
    </parent>

    <groupId>com.systech</groupId>
    <artifactId>hrms-saas-backend</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <name>HRMS SaaS Backend</name>
    <description>Multi-tenant HRMS SaaS platform with GraphQL</description>

    <properties>
        <java.version>17</java.version>
        <keycloak.version>23.0.3</keycloak.version>
        <nanoid.version>2.0.0</nanoid.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Starters -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>

        <!-- GraphQL -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-graphql</artifactId>
        </dependency>

        <!-- PostgreSQL -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>

        <!-- Flyway Database Migration -->
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-core</artifactId>
        </dependency>

        <!-- Keycloak Admin Client -->
        <dependency>
            <groupId>org.keycloak</groupId>
            <artifactId>keycloak-admin-client</artifactId>
            <version>${keycloak.version}</version>
        </dependency>

        <!-- NanoID Generator -->
        <dependency>
            <groupId>com.aventrix.jnanoid</groupId>
            <artifactId>jnanoid</artifactId>
            <version>${nanoid.version}</version>
        </dependency>

        <!-- Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- Testing -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>

        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>

        <dependency>
            <groupId>org.springframework.graphql</groupId>
            <artifactId>spring-graphql-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

---

## ⚙️ Configuration Files

**Continued in next document...**
