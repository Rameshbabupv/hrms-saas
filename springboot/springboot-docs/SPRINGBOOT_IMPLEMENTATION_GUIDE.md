# HRMS SaaS - Spring Boot Implementation Guide

## 📋 Part 2: Configuration & Implementation

This document continues from `SPRINGBOOT_ARCHITECTURE.md` with detailed implementation examples.

---

## ⚙️ Application Configuration

### **application.yml**

```yaml
spring:
  application:
    name: hrms-saas-backend

  datasource:
    url: jdbc:postgresql://localhost:5432/hrms_saas_db
    username: hrms_user
    password: hrms_password
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000

  jpa:
    hibernate:
      ddl-auto: validate  # Use Flyway for migrations
    show-sql: true
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
        jdbc:
          batch_size: 20

  flyway:
    enabled: true
    baseline-on-migrate: true
    locations: classpath:db/migration
    schemas: public

  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://localhost:8090/realms/hrms-saas
          jwk-set-uri: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs

  graphql:
    graphiql:
      enabled: true
      path: /graphiql
    path: /graphql
    schema:
      printer:
        enabled: true

server:
  port: 8081
  servlet:
    context-path: /

logging:
  level:
    root: INFO
    com.systech.hrms: DEBUG
    org.springframework.security: DEBUG
    org.hibernate.SQL: DEBUG

# Keycloak Configuration
keycloak:
  server-url: http://localhost:8090
  realm: hrms-saas
  admin:
    username: admin
    password: admin
    client-id: admin-cli

# NanoID Configuration
nanoid:
  size: 12
  alphabet: "0123456789abcdefghijklmnopqrstuvwxyz"

# CORS Configuration
cors:
  allowed-origins:
    - http://localhost:3000
    - http://192.168.1.6:3000
  allowed-methods:
    - GET
    - POST
    - PUT
    - DELETE
    - OPTIONS
  allowed-headers:
    - "*"
  exposed-headers:
    - Authorization
  allow-credentials: true
```

---

## 🔐 Security Implementation

### **1. SecurityConfig.java**

```java
package com.systech.hrms.config;

import com.systech.hrms.security.TenantFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final TenantFilter tenantFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            .authorizeHttpRequests(auth -> auth
                // Public endpoints
                .requestMatchers("/api/v1/auth/signup").permitAll()
                .requestMatchers("/api/v1/auth/verify-email").permitAll()
                .requestMatchers("/api/v1/auth/resend-verification").permitAll()
                .requestMatchers("/graphiql/**").permitAll()

                // Protected endpoints
                .requestMatchers("/graphql").authenticated()
                .requestMatchers("/api/v1/**").authenticated()

                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            )
            // Add TenantFilter AFTER JWT authentication
            .addFilterAfter(tenantFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();

        // Extract roles from realm_access.roles
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            var realmAccess = jwt.getClaimAsMap("realm_access");
            if (realmAccess != null && realmAccess.containsKey("roles")) {
                @SuppressWarnings("unchecked")
                var roles = (List<String>) realmAccess.get("roles");
                return roles.stream()
                    .map(role -> new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
                    .collect(Collectors.toList());
            }
            return Collections.emptyList();
        });

        return converter;
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(List.of("http://localhost:3000", "http://192.168.1.6:3000"));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setExposedHeaders(List.of("Authorization"));
        configuration.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
```

### **2. TenantContext.java**

```java
package com.systech.hrms.security;

/**
 * ThreadLocal storage for current tenant context
 * Used throughout the application to access tenant_id
 */
public class TenantContext {

    private static final ThreadLocal<String> CURRENT_TENANT = new ThreadLocal<>();

    public static void setCurrentTenant(String tenantId) {
        CURRENT_TENANT.set(tenantId);
    }

    public static String getCurrentTenant() {
        return CURRENT_TENANT.get();
    }

    public static void clear() {
        CURRENT_TENANT.remove();
    }

    public static boolean hasTenant() {
        return CURRENT_TENANT.get() != null;
    }
}
```

### **3. TenantFilter.java**

```java
package com.systech.hrms.security;

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

/**
 * Filter to extract tenant_id from JWT and set up RLS context
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class TenantFilter extends OncePerRequestFilter {

    private final JdbcTemplate jdbcTemplate;

    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain filterChain
    ) throws ServletException, IOException {

        try {
            // Get authentication from SecurityContext
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication != null && authentication.getPrincipal() instanceof Jwt) {
                Jwt jwt = (Jwt) authentication.getPrincipal();

                // Extract tenant_id from JWT claims
                String tenantId = jwt.getClaimAsString("tenant_id");

                if (tenantId != null && !tenantId.isBlank()) {
                    log.debug("Setting tenant context: {}", tenantId);

                    // Store in ThreadLocal
                    TenantContext.setCurrentTenant(tenantId);

                    // Set PostgreSQL session variable for RLS
                    jdbcTemplate.execute(
                        "SET LOCAL app.current_tenant = '" + tenantId + "'"
                    );

                    log.debug("PostgreSQL RLS context set for tenant: {}", tenantId);
                } else {
                    log.warn("JWT token missing tenant_id claim");
                }
            }

            // Continue filter chain
            filterChain.doFilter(request, response);

        } finally {
            // Clear ThreadLocal to prevent memory leaks
            TenantContext.clear();
        }
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        // Skip filter for public endpoints
        String path = request.getRequestURI();
        return path.startsWith("/api/v1/auth/signup") ||
               path.startsWith("/api/v1/auth/verify-email") ||
               path.startsWith("/api/v1/auth/resend-verification");
    }
}
```

---

## 🛠️ NanoID Generator

### **NanoIdGenerator.java**

```java
package com.systech.hrms.util;

import com.aventrix.jnanoid.jnanoid.NanoIdUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.security.SecureRandom;

/**
 * NanoID generator for tenant IDs
 * Generates 12-character lowercase alphanumeric IDs
 */
@Slf4j
@Component
public class NanoIdGenerator {

    private static final char[] ALPHABET =
        "0123456789abcdefghijklmnopqrstuvwxyz".toCharArray();

    private static final int SIZE = 12;

    private final SecureRandom random = new SecureRandom();

    /**
     * Generate a unique NanoID for tenant identification
     *
     * @return 12-character lowercase alphanumeric ID (e.g., "a3b9c8d2e1f4")
     */
    public String generateTenantId() {
        String tenantId = NanoIdUtils.randomNanoId(random, ALPHABET, SIZE);
        log.debug("Generated tenant_id: {}", tenantId);
        return tenantId;
    }

    /**
     * Validate tenant ID format
     *
     * @param tenantId the tenant ID to validate
     * @return true if valid format
     */
    public boolean isValidTenantId(String tenantId) {
        if (tenantId == null || tenantId.length() != SIZE) {
            return false;
        }

        // Check all characters are in alphabet
        for (char c : tenantId.toCharArray()) {
            boolean found = false;
            for (char allowed : ALPHABET) {
                if (c == allowed) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
        }

        return true;
    }
}
```

---

## 📝 Entity Classes

### **1. CompanyMaster.java**

```java
package com.systech.hrms.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "company_master")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CompanyMaster {

    @Id
    @Column(name = "tenant_id", length = 21, nullable = false)
    private String tenantId;

    @Column(name = "company_name", nullable = false)
    private String companyName;

    @Column(name = "company_code", length = 50)
    private String companyCode;

    @Column(name = "email", nullable = false, unique = true)
    private String email;

    @Column(name = "phone", length = 50)
    private String phone;

    @Column(name = "address", columnDefinition = "TEXT")
    private String address;

    @Column(name = "status", length = 20)
    @Builder.Default
    private String status = "PENDING_ACTIVATION";

    @Column(name = "subscription_plan", length = 50)
    @Builder.Default
    private String subscriptionPlan = "FREE";

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by", length = 100)
    private String createdBy;
}
```

### **2. Employee.java**

```java
package com.systech.hrms.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "employees",
    uniqueConstraints = {
        @UniqueConstraint(columnNames = {"tenant_id", "employee_code"}),
        @UniqueConstraint(columnNames = {"tenant_id", "email"})
    }
)
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Employee {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "tenant_id", length = 21, nullable = false)
    private String tenantId;

    @Column(name = "employee_code", length = 50, nullable = false)
    private String employeeCode;

    @Column(name = "first_name", length = 100, nullable = false)
    private String firstName;

    @Column(name = "last_name", length = 100, nullable = false)
    private String lastName;

    @Column(name = "email", nullable = false)
    private String email;

    @Column(name = "phone", length = 50)
    private String phone;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "date_of_joining")
    private LocalDate dateOfJoining;

    @Column(name = "designation", length = 100)
    private String designation;

    @Column(name = "department_id")
    private UUID departmentId;

    @Column(name = "manager_id")
    private UUID managerId;

    @Column(name = "employment_type", length = 50)
    private String employmentType;

    @Column(name = "status", length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by", length = 100)
    private String createdBy;

    // Helper methods
    public String getFullName() {
        return firstName + " " + lastName;
    }
}
```

---

## 🔌 Repository Layer

### **CompanyRepository.java**

```java
package com.systech.hrms.repository;

import com.systech.hrms.entity.CompanyMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CompanyRepository extends JpaRepository<CompanyMaster, String> {

    Optional<CompanyMaster> findByEmail(String email);

    boolean existsByEmail(String email);

    Optional<CompanyMaster> findByTenantId(String tenantId);
}
```

### **EmployeeRepository.java**

```java
package com.systech.hrms.repository;

import com.systech.hrms.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, UUID> {

    // RLS automatically filters by tenant_id via PostgreSQL policy

    List<Employee> findByStatus(String status);

    Optional<Employee> findByEmail(String email);

    boolean existsByEmail(String email);

    List<Employee> findByDepartmentId(UUID departmentId);

    @Query("SELECT e FROM Employee e WHERE " +
           "LOWER(e.firstName) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(e.lastName) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(e.email) LIKE LOWER(CONCAT('%', :search, '%'))")
    List<Employee> searchEmployees(@Param("search") String search);
}
```

---

**Continued in SPRINGBOOT_REST_API.md...**
