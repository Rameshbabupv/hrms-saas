# Spring Boot Team Notes
## SaaS HRMS MVP - Backend Development Guide

**Document Version:** 1.0
**Date:** 2025-10-29
**Target Audience:** Spring Boot Backend Development Team
**Project:** HRMS SaaS - Company Master & Employee Master MVP

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Database Integration](#database-integration)
4. [Keycloak Integration](#keycloak-integration)
5. [Multi-Tenancy Implementation](#multi-tenancy-implementation)
6. [GraphQL API Design](#graphql-api-design)
7. [Testing Strategy](#testing-strategy)
8. [Deployment Checklist](#deployment-checklist)

---

## 1. Quick Start

### Tech Stack
- **Framework:** Spring Boot 3.2+
- **Java Version:** Java 17 or 21
- **Database:** PostgreSQL 15+ via Spring Data JPA
- **API:** GraphQL (Spring for GraphQL)
- **Authentication:** Keycloak OAuth2/JWT
- **Build Tool:** Maven or Gradle
- **Container:** Podman (not Docker)

### Project Structure
```
nexus-backend/
├── company-service/          # Company Master CRUD
├── employee-service/         # Employee Master CRUD
├── auth-service/            # Authentication & Authorization
├── file-service/            # Document upload/download
├── notification-service/    # Email/SMS notifications
├── common/                  # Shared utilities
└── gateway/                 # API Gateway (optional for MVP)
```

### Timeline
- **Week 1-2:** Setup + Database integration + Keycloak auth
- **Week 3-4:** Company Master APIs (CRUD + hierarchy)
- **Week 5-7:** Employee Master APIs (CRUD + relationships)
- **Week 8:** Testing + Documentation

---

## 2. Architecture Overview

### 2.1 High-Level Flow

```
React Frontend
    ↓ (HTTPS with JWT token)
Spring Boot Backend
    ├─→ Extract JWT → Get company_id
    ├─→ Set PostgreSQL tenant context
    ├─→ Execute query (RLS auto-filters by tenant)
    └─→ Return data
```

### 2.2 Multi-Tenancy Strategy

**CRITICAL:** Every request must set PostgreSQL session variable

```java
// For every incoming request:
String companyId = extractCompanyIdFromJWT(token);
jdbcTemplate.execute("SELECT set_current_tenant('" + companyId + "')");
// Now all queries are automatically filtered by RLS
```

---

## 3. Database Integration

### 3.1 Application Properties

**File:** `src/main/resources/application.yml`

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/hrms_saas
    username: hrms_app
    password: ${DB_PASSWORD}  # Use environment variable
    driver-class-name: org.postgresql.Driver

  jpa:
    hibernate:
      ddl-auto: validate  # Do NOT use 'update' or 'create-drop' in production
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
        default_schema: public

  # Connection Pool (HikariCP - default in Spring Boot)
  hikari:
    maximum-pool-size: 20
    minimum-idle: 5
    connection-timeout: 30000
    idle-timeout: 600000
    max-lifetime: 1800000
```

### 3.2 JPA Entities

**Company Entity:**

```java
package com.hrms.company.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.GenericGenerator;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "company")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Company {

    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    private UUID id;

    @Column(name = "company_name", nullable = false, length = 200)
    private String companyName;

    @Column(name = "company_code", nullable = false, unique = true, length = 20)
    private String companyCode;

    // Hierarchy fields
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_company_id")
    private Company parentCompany;

    @Enumerated(EnumType.STRING)
    @Column(name = "company_type")
    private CompanyType companyType;

    @Column(name = "corporate_group_name", length = 200)
    private String corporateGroupName;

    @Column(name = "is_parent")
    private Boolean isParent;

    @Column(name = "hierarchy_level")
    private Integer hierarchyLevel;

    // Contact details
    @Column(name = "email", length = 100)
    private String email;

    @Column(name = "phone", length = 20)
    private String phone;

    // Address
    @Column(name = "address_line1", length = 200)
    private String addressLine1;

    @Column(name = "city", length = 100)
    private String city;

    @Column(name = "state", length = 100)
    private String state;

    @Column(name = "country", length = 100)
    private String country = "India";

    // Legal compliance
    @Column(name = "pan_no", length = 10)
    private String panNo;

    @Column(name = "gstin_no", length = 15)
    private String gstinNo;

    // Subscription
    @Column(name = "subscription_plan", length = 50)
    private String subscriptionPlan;

    @Column(name = "max_employees")
    private Integer maxEmployees;

    @Column(name = "subscription_start_date")
    private LocalDate subscriptionStartDate;

    @Column(name = "subscription_end_date")
    private LocalDate subscriptionEndDate;

    @Column(name = "is_trial")
    private Boolean isTrial;

    // Flexible billing
    @Enumerated(EnumType.STRING)
    @Column(name = "subscription_paid_by")
    private SubscriptionPaidBy subscriptionPaidBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "billing_company_id")
    private Company billingCompany;

    // Audit fields
    @Enumerated(EnumType.STRING)
    @Column(name = "status")
    private Status status;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "updated_by")
    private UUID updatedBy;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (status == null) {
            status = Status.ACTIVE;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

// Enums
enum CompanyType { HOLDING, SUBSIDIARY, INDEPENDENT }
enum SubscriptionPaidBy { SELF, PARENT, EXTERNAL }
enum Status { ACTIVE, INACTIVE, DELETED }
```

**Employee Entity:**

```java
package com.hrms.employee.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.GenericGenerator;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "employee")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Employee {

    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    private UUID id;

    // TENANT ISOLATION - CRITICAL
    @Column(name = "company_id", nullable = false)
    private UUID companyId;

    @Column(name = "employee_code", nullable = false, length = 50)
    private String employeeCode;

    @Column(name = "employee_name", nullable = false, length = 200)
    private String employeeName;

    @Column(name = "email", length = 100)
    private String email;

    @Column(name = "personal_email", length = 100)
    private String personalEmail;

    @Column(name = "mobile_no", length = 20)
    private String mobileNo;

    // Personal details
    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Enumerated(EnumType.STRING)
    @Column(name = "gender")
    private Gender gender;

    @Enumerated(EnumType.STRING)
    @Column(name = "marital_status")
    private MaritalStatus maritalStatus;

    @Column(name = "blood_group", length = 10)
    private String bloodGroup;

    // Address
    @Column(name = "city", length = 100)
    private String city;

    @Column(name = "state", length = 100)
    private String state;

    @Column(name = "country", length = 100)
    private String country = "India";

    // Employment details
    @Column(name = "date_of_joining", nullable = false)
    private LocalDate dateOfJoining;

    @Column(name = "date_of_confirmation")
    private LocalDate dateOfConfirmation;

    @Enumerated(EnumType.STRING)
    @Column(name = "employment_type")
    private EmploymentType employmentType;

    @Column(name = "designation", length = 100)
    private String designation;

    @Column(name = "department", length = 100)
    private String department;

    // Reporting structure
    @Column(name = "reporting_manager_id")
    private UUID reportingManagerId;

    // Compensation
    @Column(name = "monthly_ctc", precision = 12, scale = 2)
    private BigDecimal monthlyCtc;

    @Column(name = "monthly_gross", precision = 12, scale = 2)
    private BigDecimal monthlyGross;

    // Statutory details
    @Column(name = "pan_no", length = 10)
    private String panNo;

    @Column(name = "aadhaar_no", length = 12)
    private String aadhaarNo;

    @Column(name = "uan_no", length = 12)
    private String uanNo;

    // Bank details
    @Column(name = "bank_name", length = 100)
    private String bankName;

    @Column(name = "bank_account_no", length = 50)
    private String bankAccountNo;

    @Column(name = "bank_ifsc_code", length = 11)
    private String bankIfscCode;

    // Document URLs
    @Column(name = "photo_url", length = 500)
    private String photoUrl;

    @Column(name = "aadhaar_url", length = 500)
    private String aadhaarUrl;

    @Column(name = "pan_url", length = 500)
    private String panUrl;

    // Employment status
    @Column(name = "is_active")
    private Boolean isActive;

    @Column(name = "date_of_exit")
    private LocalDate dateOfExit;

    // Audit fields
    @Enumerated(EnumType.STRING)
    @Column(name = "status")
    private Status status;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (status == null) {
            status = Status.ACTIVE;
        }
        if (isActive == null) {
            isActive = true;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

// Enums
enum Gender { MALE, FEMALE, OTHER }
enum MaritalStatus { SINGLE, MARRIED, DIVORCED, WIDOWED }
enum EmploymentType { PERMANENT, CONTRACT, CONSULTANT, INTERN, TEMPORARY }
```

### 3.3 Repository Layer

```java
package com.hrms.company.repository;

import com.hrms.company.entity.Company;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CompanyRepository extends JpaRepository<Company, UUID> {

    Optional<Company> findByCompanyCode(String companyCode);

    List<Company> findByParentCompanyId(UUID parentCompanyId);

    List<Company> findByCorporateGroupName(String groupName);

    @Query(value = "SELECT * FROM get_subsidiary_companies(:parentId)", nativeQuery = true)
    List<Object[]> getSubsidiaryCompanies(@Param("parentId") UUID parentId);

    @Query(value = "SELECT get_employee_count(:companyId, :includeSubsidiaries)", nativeQuery = true)
    Integer getEmployeeCount(@Param("companyId") UUID companyId,
                             @Param("includeSubsidiaries") Boolean includeSubsidiaries);
}
```

```java
package com.hrms.employee.repository;

import com.hrms.employee.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, UUID> {

    // RLS handles tenant filtering automatically
    List<Employee> findByCompanyId(UUID companyId);

    Optional<Employee> findByCompanyIdAndEmployeeCode(UUID companyId, String employeeCode);

    Optional<Employee> findByEmail(String email);

    List<Employee> findByReportingManagerId(UUID managerId);

    List<Employee> findByDepartment(String department);

    List<Employee> findByDesignation(String designation);

    Long countByCompanyIdAndIsActive(UUID companyId, Boolean isActive);
}
```

---

## 4. Keycloak Integration

### 4.1 Dependencies

**pom.xml (Maven):**
```xml
<dependencies>
    <!-- Spring Boot Starter -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <!-- OAuth2 Resource Server (JWT validation) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
    </dependency>

    <!-- Spring Security -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-security</artifactId>
    </dependency>

    <!-- PostgreSQL Driver -->
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
    </dependency>

    <!-- Spring Data JPA -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>

    <!-- GraphQL -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-graphql</artifactId>
    </dependency>

    <!-- Lombok -->
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>
```

### 4.2 Security Configuration

```java
package com.hrms.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/**", "/graphiql/**").permitAll()
                .requestMatchers("/graphql/**").authenticated()
                .anyRequest().authenticated()
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            );
        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(new KeycloakRoleConverter());
        return converter;
    }
}
```

**Keycloak Role Converter:**

```java
package com.hrms.config;

import org.springframework.core.convert.converter.Converter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

import java.util.*;
import java.util.stream.Collectors;

public class KeycloakRoleConverter implements Converter<Jwt, Collection<GrantedAuthority>> {

    @Override
    public Collection<GrantedAuthority> convert(Jwt jwt) {
        Map<String, Object> realmAccess = jwt.getClaim("realm_access");
        if (realmAccess == null || realmAccess.isEmpty()) {
            return Collections.emptyList();
        }

        List<String> roles = (List<String>) realmAccess.get("roles");
        if (roles == null) {
            return Collections.emptyList();
        }

        return roles.stream()
                .map(role -> new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
                .collect(Collectors.toList());
    }
}
```

### 4.3 Application Properties for Keycloak

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.yourdomain.com/realms/hrms-saas
          jwk-set-uri: https://auth.yourdomain.com/realms/hrms-saas/protocol/openid-connect/certs

keycloak:
  realm: hrms-saas
  auth-server-url: https://auth.yourdomain.com
  resource: hrms-web-app
  credentials:
    secret: ${KEYCLOAK_CLIENT_SECRET}
```

---

## 5. Multi-Tenancy Implementation

### 5.1 Tenant Context Filter

**CRITICAL:** Extract `company_id` from JWT and set PostgreSQL session variable

```java
package com.hrms.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class TenantContextFilter extends OncePerRequestFilter {

    private final JdbcTemplate jdbcTemplate;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain) throws ServletException, IOException {

        try {
            // Extract JWT from Security Context
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication != null && authentication.getPrincipal() instanceof Jwt) {
                Jwt jwt = (Jwt) authentication.getPrincipal();

                // Extract company_id from JWT
                String companyId = jwt.getClaimAsString("company_id");

                if (companyId != null && !companyId.isEmpty()) {
                    // Validate UUID format
                    UUID companyUuid = UUID.fromString(companyId);

                    // Set PostgreSQL session variable for RLS
                    jdbcTemplate.execute(
                        "SELECT set_current_tenant('" + companyUuid + "')"
                    );

                    log.debug("Tenant context set to: {}", companyId);

                    // Store in thread-local for easy access
                    TenantContext.setCurrentTenant(companyUuid);
                    TenantContext.setCurrentUser(UUID.fromString(jwt.getSubject()));
                } else {
                    log.warn("company_id claim missing in JWT token");
                    response.sendError(HttpServletResponse.SC_FORBIDDEN, "Missing tenant context");
                    return;
                }
            }

            filterChain.doFilter(request, response);

        } finally {
            // Clear thread-local after request
            TenantContext.clear();
        }
    }
}
```

**Tenant Context Holder:**

```java
package com.hrms.context;

import java.util.UUID;

public class TenantContext {

    private static final ThreadLocal<UUID> currentTenant = new ThreadLocal<>();
    private static final ThreadLocal<UUID> currentUser = new ThreadLocal<>();

    public static void setCurrentTenant(UUID tenantId) {
        currentTenant.set(tenantId);
    }

    public static UUID getCurrentTenant() {
        return currentTenant.get();
    }

    public static void setCurrentUser(UUID userId) {
        currentUser.set(userId);
    }

    public static UUID getCurrentUser() {
        return currentUser.get();
    }

    public static void clear() {
        currentTenant.remove();
        currentUser.remove();
    }
}
```

### 5.2 Tenant Validation Service

```java
package com.hrms.service;

import com.hrms.context.TenantContext;
import com.hrms.repository.CompanyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TenantValidationService {

    private final CompanyRepository companyRepository;

    public void validateTenantAccess(UUID resourceCompanyId) {
        UUID currentTenant = TenantContext.getCurrentTenant();

        // Check if resource belongs to current tenant or subsidiary
        if (!resourceCompanyId.equals(currentTenant)) {
            // Check if current tenant is parent of resource company
            boolean isParent = companyRepository.existsByIdAndParentCompanyId(
                resourceCompanyId, currentTenant
            );

            if (!isParent) {
                throw new UnauthorizedAccessException(
                    "Access denied to resource from another tenant"
                );
            }
        }
    }
}
```

---

## 6. GraphQL API Design

### 6.1 GraphQL Schema

**File:** `src/main/resources/graphql/schema.graphqls`

```graphql
# Company Types
type Company {
    id: ID!
    companyName: String!
    companyCode: String!
    companyType: CompanyType!
    parentCompany: Company
    subsidiaries: [Company!]
    corporateGroupName: String
    hierarchyLevel: Int!

    email: String
    phone: String
    city: String
    state: String
    country: String

    panNo: String
    gstinNo: String

    subscriptionPlan: String
    maxEmployees: Int
    subscriptionEndDate: String
    isTrial: Boolean

    employeeCount: Int
    employees: [Employee!]

    createdAt: String!
    updatedAt: String!
}

enum CompanyType {
    HOLDING
    SUBSIDIARY
    INDEPENDENT
}

# Employee Types
type Employee {
    id: ID!
    companyId: ID!
    company: Company

    employeeCode: String!
    employeeName: String!
    email: String
    mobileNo: String

    dateOfBirth: String
    gender: Gender
    maritalStatus: MaritalStatus

    dateOfJoining: String!
    employmentType: EmploymentType
    designation: String
    department: String

    reportingManager: Employee
    teamMembers: [Employee!]

    monthlyCtc: Float
    monthlyGross: Float

    panNo: String
    aadhaarNo: String

    isActive: Boolean!

    education: [EmployeeEducation!]
    experience: [EmployeeExperience!]

    createdAt: String!
    updatedAt: String!
}

enum Gender { MALE FEMALE OTHER }
enum MaritalStatus { SINGLE MARRIED DIVORCED WIDOWED }
enum EmploymentType { PERMANENT CONTRACT CONSULTANT INTERN TEMPORARY }

type EmployeeEducation {
    id: ID!
    degree: String
    institution: String
    yearOfPassing: Int
}

type EmployeeExperience {
    id: ID!
    companyName: String
    designation: String
    fromDate: String
    toDate: String
}

# Queries
type Query {
    # Company queries
    company(id: ID!): Company
    companies(filter: CompanyFilter, page: Int, size: Int): CompanyPage!
    subsidiaries(parentId: ID!): [Company!]!
    corporateGroupSummary(groupName: String!): GroupSummary!

    # Employee queries
    employee(id: ID!): Employee
    employees(filter: EmployeeFilter, page: Int, size: Int): EmployeePage!
    employeesByDepartment(department: String!): [Employee!]!
    employeesByManager(managerId: ID!): [Employee!]!
}

# Mutations
type Mutation {
    # Company mutations
    createCompany(input: CreateCompanyInput!): Company!
    updateCompany(id: ID!, input: UpdateCompanyInput!): Company!
    deleteCompany(id: ID!): Boolean!

    # Employee mutations
    createEmployee(input: CreateEmployeeInput!): Employee!
    updateEmployee(id: ID!, input: UpdateEmployeeInput!): Employee!
    deleteEmployee(id: ID!): Boolean!
}

# Input Types
input CompanyFilter {
    companyType: CompanyType
    corporateGroupName: String
    status: String
}

input EmployeeFilter {
    department: String
    designation: String
    employmentType: EmploymentType
    isActive: Boolean
}

input CreateCompanyInput {
    companyName: String!
    companyCode: String!
    email: String
    phone: String
    city: String
    state: String
    country: String
    panNo: String
    gstinNo: String
}

input CreateEmployeeInput {
    employeeCode: String!
    employeeName: String!
    email: String!
    mobileNo: String
    dateOfBirth: String
    gender: Gender
    dateOfJoining: String!
    employmentType: EmploymentType
    designation: String
    department: String
    reportingManagerId: ID
    monthlyCtc: Float
}

# Pagination
type CompanyPage {
    content: [Company!]!
    totalElements: Int!
    totalPages: Int!
    number: Int!
    size: Int!
}

type EmployeePage {
    content: [Employee!]!
    totalElements: Int!
    totalPages: Int!
    number: Int!
    size: Int!
}

type GroupSummary {
    totalCompanies: Int!
    totalEmployees: Int!
    activeSubscriptions: Int!
}
```

### 6.2 GraphQL Resolvers

```java
package com.hrms.graphql;

import com.hrms.context.TenantContext;
import com.hrms.entity.Company;
import com.hrms.service.CompanyService;
import lombok.RequiredArgsConstructor;
import org.springframework.graphql.data.method.annotation.Argument;
import org.springframework.graphql.data.method.annotation.MutationMapping;
import org.springframework.graphql.data.method.annotation.QueryMapping;
import org.springframework.graphql.data.method.annotation.SchemaMapping;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;

import java.util.List;
import java.util.UUID;

@Controller
@RequiredArgsConstructor
public class CompanyResolver {

    private final CompanyService companyService;

    @QueryMapping
    public Company company(@Argument UUID id) {
        return companyService.findById(id);
    }

    @QueryMapping
    public List<Company> companies(
            @Argument CompanyFilter filter,
            @Argument Integer page,
            @Argument Integer size) {

        return companyService.findAll(filter, page, size);
    }

    @QueryMapping
    public List<Company> subsidiaries(@Argument UUID parentId) {
        return companyService.findSubsidiaries(parentId);
    }

    @MutationMapping
    @PreAuthorize("hasRole('COMPANY_ADMIN')")
    public Company createCompany(@Argument CreateCompanyInput input) {
        return companyService.create(input);
    }

    @MutationMapping
    @PreAuthorize("hasRole('COMPANY_ADMIN')")
    public Company updateCompany(@Argument UUID id, @Argument UpdateCompanyInput input) {
        return companyService.update(id, input);
    }

    // Field resolver for nested data
    @SchemaMapping(typeName = "Company", field = "employeeCount")
    public Integer employeeCount(Company company) {
        return companyService.getEmployeeCount(company.getId(), false);
    }
}
```

### 6.3 Service Layer Example

```java
package com.hrms.service;

import com.hrms.context.TenantContext;
import com.hrms.dto.CreateEmployeeInput;
import com.hrms.entity.Employee;
import com.hrms.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final TenantValidationService tenantValidationService;

    public Employee findById(UUID id) {
        Employee employee = employeeRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("Employee not found"));

        // Validate tenant access (RLS already filters, but double-check)
        tenantValidationService.validateTenantAccess(employee.getCompanyId());

        return employee;
    }

    public Employee create(CreateEmployeeInput input) {
        UUID currentTenant = TenantContext.getCurrentTenant();
        UUID currentUser = TenantContext.getCurrentUser();

        Employee employee = Employee.builder()
            .companyId(currentTenant)  // Auto-assign to current tenant
            .employeeCode(input.getEmployeeCode())
            .employeeName(input.getEmployeeName())
            .email(input.getEmail())
            .dateOfJoining(input.getDateOfJoining())
            .createdBy(currentUser)
            .build();

        return employeeRepository.save(employee);
    }
}
```

---

## 7. Testing Strategy

### 7.1 Unit Tests

```java
package com.hrms.service;

import com.hrms.context.TenantContext;
import com.hrms.entity.Employee;
import com.hrms.repository.EmployeeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EmployeeServiceTest {

    @Mock
    private EmployeeRepository employeeRepository;

    @InjectMocks
    private EmployeeService employeeService;

    private UUID testTenantId;
    private Employee testEmployee;

    @BeforeEach
    void setUp() {
        testTenantId = UUID.randomUUID();
        TenantContext.setCurrentTenant(testTenantId);

        testEmployee = Employee.builder()
            .id(UUID.randomUUID())
            .companyId(testTenantId)
            .employeeCode("EMP001")
            .employeeName("Test Employee")
            .build();
    }

    @Test
    void findById_ShouldReturnEmployee_WhenExists() {
        when(employeeRepository.findById(testEmployee.getId()))
            .thenReturn(Optional.of(testEmployee));

        Employee result = employeeService.findById(testEmployee.getId());

        assertNotNull(result);
        assertEquals("EMP001", result.getEmployeeCode());
        verify(employeeRepository, times(1)).findById(testEmployee.getId());
    }
}
```

### 7.2 Integration Tests

```java
package com.hrms.integration;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class EmployeeIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    @WithMockUser(roles = "COMPANY_ADMIN")
    void createEmployee_ShouldReturn200_WhenValidInput() throws Exception {
        // Set tenant context
        UUID tenantId = UUID.fromString("550e8400-e29b-41d4-a716-446655440000");
        jdbcTemplate.execute("SELECT set_current_tenant('" + tenantId + "')");

        String graphqlQuery = """
            mutation {
                createEmployee(input: {
                    employeeCode: "EMP001"
                    employeeName: "John Doe"
                    email: "john@company.com"
                    dateOfJoining: "2025-01-01"
                }) {
                    id
                    employeeCode
                    employeeName
                }
            }
        """;

        mockMvc.perform(post("/graphql")
                .contentType("application/json")
                .content("{\"query\": \"" + graphqlQuery + "\"}"))
            .andExpect(status().isOk());
    }
}
```

---

## 8. Deployment Checklist

### 8.1 Pre-Deployment

- [ ] Run all unit tests (`mvn test`)
- [ ] Run all integration tests
- [ ] Build application (`mvn clean package`)
- [ ] Test with local PostgreSQL
- [ ] Test with local Keycloak
- [ ] Load test with JMeter (100+ concurrent users)
- [ ] Security scan (OWASP ZAP)

### 8.2 Environment Variables

```bash
# Production environment variables
export DB_HOST=postgres.production.com
export DB_PORT=5432
export DB_NAME=hrms_saas
export DB_USERNAME=hrms_app
export DB_PASSWORD=<strong-password>

export KEYCLOAK_URL=https://auth.yourdomain.com
export KEYCLOAK_REALM=hrms-saas
export KEYCLOAK_CLIENT_SECRET=<client-secret>

export SPRING_PROFILES_ACTIVE=production
export SERVER_PORT=8081
```

### 8.3 Podman Deployment

**Dockerfile:**
```dockerfile
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/hrms-backend-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Build and Run:**
```bash
# Build container
podman build -t hrms-backend:v1 .

# Run container
podman run -d \
  --name hrms-backend \
  -p 8081:8081 \
  -e DB_HOST=postgres.local \
  -e DB_PASSWORD=${DB_PASSWORD} \
  -e KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET} \
  hrms-backend:v1

# Check logs
podman logs -f hrms-backend
```

---

## Appendix

### A. Dependencies Reference

**Full POM.xml:**
See `KEYCLOAK_IMPLEMENTATION_GUIDE.md` for complete dependencies list

### B. Contact Information

| Role | Contact | Purpose |
|------|---------|---------|
| Keycloak Team | <keycloak-email> | JWT token structure, Admin API |
| DBA Team | <dba-email> | Database schema, RLS policies |
| React Team | <frontend-email> | API contracts, GraphQL schema |
| DevOps Team | <devops-email> | Deployment, Podman, monitoring |

### C. Related Documents

- **Database Schema:** `saas_mvp_schema_v2_with_hierarchy.sql`
- **DBA Guide:** `DBA_NOTES.md`
- **Keycloak Guide:** `KEYCLOAK_IMPLEMENTATION_GUIDE.md`
- **Frontend Guide:** `REACTAPP_NOTES.md` (next)

---

**End of Spring Boot Team Notes**

✅ **Critical Path Items:**
1. Set up tenant context filter (Section 5.1)
2. Configure Keycloak JWT validation (Section 4)
3. Implement Company & Employee GraphQL APIs (Section 6)
4. Test multi-tenancy isolation (Section 7)

**Estimated Timeline:** 8 weeks for MVP completion
