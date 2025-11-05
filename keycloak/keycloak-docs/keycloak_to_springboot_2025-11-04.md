# Keycloak Integration Guide for Spring Boot Developers

**Document Version:** 1.0
**Date:** November 4, 2025
**Target Audience:** Spring Boot Backend Developers
**Keycloak Realm:** hrms-saas

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Keycloak Configuration Reference](#keycloak-configuration-reference)
4. [Spring Boot Dependencies](#spring-boot-dependencies)
5. [Application Configuration](#application-configuration)
6. [Security Configuration](#security-configuration)
7. [Creating Users in Keycloak](#creating-users-in-keycloak)
8. [User Attribute Management](#user-attribute-management)
9. [JWT Token Structure](#jwt-token-structure)
10. [Multi-Tenant Implementation](#multi-tenant-implementation)
11. [API Endpoints](#api-endpoints)
12. [Testing & Validation](#testing--validation)
13. [Error Handling](#error-handling)
14. [Best Practices](#best-practices)
15. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides comprehensive instructions for Spring Boot developers to integrate with the **hrms-saas** Keycloak realm. The integration covers:

- OAuth2/OIDC authentication
- JWT token validation
- User creation and management via Keycloak Admin API
- Multi-tenant user attribute management
- Role-based access control

### Architecture Pattern

```
┌─────────────┐     JWT Token      ┌──────────────────┐
│   React     │ ─────────────────> │  Spring Boot     │
│   Client    │ <───────────────── │  Backend         │
└─────────────┘     API Response   └──────────────────┘
       │                                     │
       │ Login/Signup                        │ Validate JWT
       ▼                                     │ Create Users
┌─────────────┐                             │
│  Keycloak   │ <───────────────────────────┘
│  Server     │      Admin API
└─────────────┘
```

---

## Prerequisites

### Required Software

- **Java:** 17 or higher
- **Spring Boot:** 3.2.1 or higher
- **Maven:** 3.8+
- **PostgreSQL:** 16
- **Keycloak:** Latest (running on port 8090)

### Keycloak Setup Status

Ensure Keycloak is running with the hrms-saas realm configured:

```bash
# Check Keycloak status
curl -s http://localhost:8090/realms/hrms-saas/.well-known/openid-configuration | jq -r '.issuer'
# Expected: http://localhost:8090/realms/hrms-saas
```

### Keycloak Realm Configuration

| Component | Value |
|-----------|-------|
| **Realm Name** | hrms-saas |
| **Client ID** | hrms-web-app |
| **Client UUID** | 7bfc541b-5d82-42c3-9f6d-88bb553713c8 |
| **Client Secret** | xE39L2zsTFkOjmAt47ToFQRwgIekjW3l |
| **Keycloak URL** | http://localhost:8090 |
| **Admin Console** | http://localhost:8090/admin |
| **Admin Username** | admin |
| **Admin Password** | secret |

---

## Keycloak Configuration Reference

### Realm: hrms-saas

#### Roles

The realm has 5 predefined roles:

| Role | Description | Use Case |
|------|-------------|----------|
| `super_admin` | System-wide administrator | Platform management |
| `company_admin` | Company administrator | Company-level operations |
| `hr_user` | HR personnel | HR operations |
| `manager` | Department manager | Team management |
| `employee` | Regular employee (default) | Self-service operations |

#### JWT Custom Mappers

The following custom claims are automatically added to JWT tokens:

| Claim Name | Type | Source | Description |
|------------|------|--------|-------------|
| `company_id` | String | User Attribute | UUID of the company (same as tenant_id) |
| `tenant_id` | String | User Attribute | 12-char NanoID for tenant isolation |
| `employee_id` | String | User Attribute | UUID of the employee record |
| `user_type` | String | User Attribute | User role type (company_admin, hr_user, etc.) |
| `company_code` | String | User Attribute | Company code for display |
| `company_name` | String | User Attribute | Company display name |
| `phone` | String | User Attribute | User phone number |

#### Client Configuration

**Client ID:** `hrms-web-app`

**Settings:**
- Access Type: Confidential
- Standard Flow Enabled: Yes
- Direct Access Grants Enabled: Yes
- Service Accounts Enabled: No
- Authorization Enabled: No
- Valid Redirect URIs: `http://localhost:3000/*`, `http://localhost:3001/*`
- Web Origins: `http://localhost:3000`, `http://localhost:3001`

**Credentials:**
- Client Secret: `xE39L2zsTFkOjmAt47ToFQRwgIekjW3l`

---

## Spring Boot Dependencies

### pom.xml Configuration

Add these dependencies to your `pom.xml`:

```xml
<dependencies>
    <!-- Spring Boot Starter -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <!-- Spring Security OAuth2 Resource Server -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
    </dependency>

    <!-- Spring Security for JWT validation -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-security</artifactId>
    </dependency>

    <!-- Keycloak Admin Client (for user creation) -->
    <dependency>
        <groupId>org.keycloak</groupId>
        <artifactId>keycloak-admin-client</artifactId>
        <version>23.0.3</version>
    </dependency>

    <!-- JBoss RESTEasy (required by Keycloak Admin Client) -->
    <dependency>
        <groupId>org.jboss.resteasy</groupId>
        <artifactId>resteasy-client</artifactId>
        <version>6.2.6.Final</version>
    </dependency>

    <dependency>
        <groupId>org.jboss.resteasy</groupId>
        <artifactId>resteasy-jackson2-provider</artifactId>
        <version>6.2.6.Final</version>
    </dependency>

    <!-- Database -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>

    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <scope>runtime</scope>
    </dependency>

    <!-- Utilities -->
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>
```

---

## Application Configuration

### application.yml

Create or update your `application.yml`:

```yaml
server:
  port: 8081
  servlet:
    context-path: /

spring:
  application:
    name: hrms-saas-backend

  # Database Configuration
  datasource:
    url: jdbc:postgresql://localhost:5432/hrms_saas
    username: admin
    password: admin
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000

  # JPA/Hibernate
  jpa:
    hibernate:
      ddl-auto: validate  # Use Flyway for schema management
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true

  # OAuth2 Resource Server (JWT Validation)
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://localhost:8090/realms/hrms-saas
          jwk-set-uri: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs

# Keycloak Configuration
keycloak:
  server-url: http://localhost:8090
  realm: hrms-saas

  # Admin credentials for Keycloak Admin API
  admin:
    username: admin
    password: secret
    client-id: admin-cli

  # Application client credentials
  client:
    id: hrms-web-app
    secret: xE39L2zsTFkOjmAt47ToFQRwgIekjW3l
    uuid: 7bfc541b-5d82-42c3-9f6d-88bb553713c8

# Logging
logging:
  level:
    root: INFO
    com.systech.hrms: DEBUG
    org.springframework.security: INFO
    org.keycloak: DEBUG
```

### Environment Variables (Optional)

For production, use environment variables:

```bash
export KEYCLOAK_SERVER_URL=http://localhost:8090
export KEYCLOAK_REALM=hrms-saas
export KEYCLOAK_CLIENT_ID=hrms-web-app
export KEYCLOAK_CLIENT_SECRET=xE39L2zsTFkOjmAt47ToFQRwgIekjW3l
export KEYCLOAK_ADMIN_USERNAME=admin
export KEYCLOAK_ADMIN_PASSWORD=secret
```

---

## Security Configuration

### SecurityConfig.java

Create a security configuration class:

```java
package com.systech.hrms.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            // Disable CSRF for stateless JWT authentication
            .csrf(csrf -> csrf.disable())

            // Configure CORS
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))

            // Configure authorization rules
            .authorizeHttpRequests(auth -> auth
                // Public endpoints (no authentication required)
                .requestMatchers(
                    "/api/v1/auth/signup",
                    "/api/v1/auth/verify-email",
                    "/api/v1/auth/resend-verification",
                    "/api/v1/auth/check-email",
                    "/actuator/health",
                    "/graphiql/**"  // Remove in production
                ).permitAll()

                // All other endpoints require authentication
                .anyRequest().authenticated()
            )

            // Configure session management (stateless for JWT)
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )

            // Configure OAuth2 Resource Server (JWT validation)
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            );

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // Allowed origins (React frontend)
        configuration.setAllowedOrigins(Arrays.asList(
            "http://localhost:3000",
            "http://localhost:3001",
            "http://192.168.1.6:3000"
        ));

        // Allowed methods
        configuration.setAllowedMethods(Arrays.asList(
            "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"
        ));

        // Allowed headers
        configuration.setAllowedHeaders(Arrays.asList("*"));

        // Allow credentials (cookies, authorization headers)
        configuration.setAllowCredentials(true);

        // Max age for preflight requests (1 hour)
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);

        return source;
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();

        // Convert Keycloak roles to Spring Security authorities
        JwtGrantedAuthoritiesConverter grantedAuthoritiesConverter =
            new JwtGrantedAuthoritiesConverter();
        grantedAuthoritiesConverter.setAuthoritiesClaimName("realm_access.roles");
        grantedAuthoritiesConverter.setAuthorityPrefix("ROLE_");

        converter.setJwtGrantedAuthoritiesConverter(grantedAuthoritiesConverter);

        return converter;
    }
}
```

### Key Security Points

1. **Stateless Sessions:** No server-side session storage (JWT-based)
2. **CORS:** Configured for React frontend on localhost:3000
3. **Public Endpoints:** Sign-up, email verification, health checks
4. **JWT Validation:** Automatic validation against Keycloak's public key
5. **Role Mapping:** Keycloak roles mapped to Spring Security authorities

---

## Creating Users in Keycloak

### KeycloakAdminService.java

Create a service to interact with Keycloak Admin API:

```java
package com.systech.hrms.service;

import lombok.extern.slf4j.Slf4j;
import org.keycloak.admin.client.Keycloak;
import org.keycloak.admin.client.KeycloakBuilder;
import org.keycloak.admin.client.resource.RealmResource;
import org.keycloak.admin.client.resource.UserResource;
import org.keycloak.admin.client.resource.UsersResource;
import org.keycloak.representations.idm.CredentialRepresentation;
import org.keycloak.representations.idm.RoleRepresentation;
import org.keycloak.representations.idm.UserRepresentation;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import javax.ws.rs.core.Response;
import java.util.*;

@Slf4j
@Service
public class KeycloakAdminService {

    @Value("${keycloak.server-url}")
    private String serverUrl;

    @Value("${keycloak.realm}")
    private String realm;

    @Value("${keycloak.admin.username}")
    private String adminUsername;

    @Value("${keycloak.admin.password}")
    private String adminPassword;

    @Value("${keycloak.admin.client-id}")
    private String adminClientId;

    private Keycloak keycloak;
    private RealmResource realmResource;

    @PostConstruct
    public void init() {
        log.info("Initializing Keycloak Admin Client for realm: {}", realm);

        this.keycloak = KeycloakBuilder.builder()
            .serverUrl(serverUrl)
            .realm("master")  // Admin API uses master realm
            .username(adminUsername)
            .password(adminPassword)
            .clientId(adminClientId)
            .build();

        this.realmResource = keycloak.realm(realm);

        log.info("Keycloak Admin Client initialized successfully");
    }

    @PreDestroy
    public void cleanup() {
        if (keycloak != null) {
            keycloak.close();
            log.info("Keycloak Admin Client closed");
        }
    }

    /**
     * Create a new user in Keycloak with custom attributes
     *
     * @param email User email (also username)
     * @param password User password
     * @param firstName User first name
     * @param lastName User last name
     * @param attributes Custom attributes (tenant_id, company_id, etc.)
     * @param roles List of roles to assign
     * @return Keycloak user ID (UUID)
     */
    public String createUser(
        String email,
        String password,
        String firstName,
        String lastName,
        Map<String, List<String>> attributes,
        List<String> roles
    ) {
        try {
            log.info("Creating Keycloak user: {}", email);

            // Build user representation
            UserRepresentation user = new UserRepresentation();
            user.setUsername(email);
            user.setEmail(email);
            user.setFirstName(firstName);
            user.setLastName(lastName);
            user.setEnabled(true);
            user.setEmailVerified(false);  // Require email verification
            user.setAttributes(attributes);

            // Create user
            UsersResource usersResource = realmResource.users();
            Response response = usersResource.create(user);

            if (response.getStatus() != 201) {
                String error = response.readEntity(String.class);
                log.error("Failed to create user. Status: {}, Error: {}",
                    response.getStatus(), error);
                throw new RuntimeException("Failed to create user: " + error);
            }

            // Extract user ID from Location header
            String locationHeader = response.getHeaderString("Location");
            String userId = locationHeader.substring(locationHeader.lastIndexOf('/') + 1);

            log.info("User created successfully with ID: {}", userId);

            // Set password
            setUserPassword(userId, password);

            // Assign roles
            assignRoles(userId, roles);

            return userId;

        } catch (Exception e) {
            log.error("Error creating Keycloak user: {}", email, e);
            throw new RuntimeException("Failed to create Keycloak user", e);
        }
    }

    /**
     * Set user password
     */
    private void setUserPassword(String userId, String password) {
        try {
            CredentialRepresentation credential = new CredentialRepresentation();
            credential.setType(CredentialRepresentation.PASSWORD);
            credential.setValue(password);
            credential.setTemporary(false);  // Don't force password change

            UserResource userResource = realmResource.users().get(userId);
            userResource.resetPassword(credential);

            log.info("Password set for user: {}", userId);

        } catch (Exception e) {
            log.error("Error setting password for user: {}", userId, e);
            throw new RuntimeException("Failed to set user password", e);
        }
    }

    /**
     * Assign roles to user
     */
    private void assignRoles(String userId, List<String> roleNames) {
        if (roleNames == null || roleNames.isEmpty()) {
            log.info("No roles to assign for user: {}", userId);
            return;
        }

        try {
            UserResource userResource = realmResource.users().get(userId);

            // Get role representations
            List<RoleRepresentation> rolesToAdd = new ArrayList<>();
            for (String roleName : roleNames) {
                RoleRepresentation role = realmResource.roles().get(roleName).toRepresentation();
                rolesToAdd.add(role);
            }

            // Assign roles
            userResource.roles().realmLevel().add(rolesToAdd);

            log.info("Roles assigned to user {}: {}", userId, roleNames);

        } catch (Exception e) {
            log.error("Error assigning roles to user: {}", userId, e);
            throw new RuntimeException("Failed to assign roles", e);
        }
    }

    /**
     * Send email verification
     */
    public void sendVerifyEmail(String userId) {
        try {
            UserResource userResource = realmResource.users().get(userId);
            userResource.sendVerifyEmail();

            log.info("Verification email sent to user: {}", userId);

        } catch (Exception e) {
            log.error("Error sending verification email to user: {}", userId, e);
            // Don't throw exception - email sending is not critical
            // User can request resend later
        }
    }

    /**
     * Find user by email
     */
    public String findUserIdByEmail(String email) {
        try {
            List<UserRepresentation> users = realmResource.users()
                .search(email, true);  // exact match

            if (users.isEmpty()) {
                return null;
            }

            return users.get(0).getId();

        } catch (Exception e) {
            log.error("Error finding user by email: {}", email, e);
            return null;
        }
    }

    /**
     * Update user attributes
     */
    public void updateUserAttributes(String userId, Map<String, List<String>> attributes) {
        try {
            UserResource userResource = realmResource.users().get(userId);
            UserRepresentation user = userResource.toRepresentation();

            if (user.getAttributes() == null) {
                user.setAttributes(new HashMap<>());
            }

            user.getAttributes().putAll(attributes);
            userResource.update(user);

            log.info("User attributes updated for user: {}", userId);

        } catch (Exception e) {
            log.error("Error updating user attributes: {}", userId, e);
            throw new RuntimeException("Failed to update user attributes", e);
        }
    }

    /**
     * Delete user
     */
    public void deleteUser(String userId) {
        try {
            realmResource.users().delete(userId);
            log.info("User deleted: {}", userId);

        } catch (Exception e) {
            log.error("Error deleting user: {}", userId, e);
            throw new RuntimeException("Failed to delete user", e);
        }
    }
}
```

---

## User Attribute Management

### Required User Attributes for Multi-Tenancy

When creating users, you must set these attributes:

| Attribute Name | Type | Required | Description | Example |
|---------------|------|----------|-------------|---------|
| `tenant_id` | String | Yes | 12-char NanoID for tenant isolation | `a3b9c8d2e1f4` |
| `company_id` | String | Yes | UUID of company (same as tenant_id for now) | `550e8400-e29b-41d4-a716-446655440000` |
| `user_type` | String | Yes | User role type | `company_admin`, `hr_user`, `employee` |
| `company_name` | String | Yes | Company display name | `Acme Corporation` |
| `company_code` | String | No | Company code | `ACME001` |
| `employee_id` | String | No | UUID of employee record | `660e8400-e29b-41d4-a716-446655440001` |
| `phone` | String | No | Phone number | `+1234567890` |

### Example: Creating User with Attributes

```java
@Service
public class SignUpService {

    @Autowired
    private KeycloakAdminService keycloakService;

    @Autowired
    private NanoIdGenerator nanoIdGenerator;

    public SignUpResponse createCustomer(SignUpRequest request) {
        // 1. Generate tenant ID
        String tenantId = nanoIdGenerator.generateTenantId(); // 12-char NanoID

        // 2. Prepare user attributes
        Map<String, List<String>> attributes = new HashMap<>();
        attributes.put("tenant_id", Collections.singletonList(tenantId));
        attributes.put("company_id", Collections.singletonList(tenantId));
        attributes.put("user_type", Collections.singletonList("company_admin"));
        attributes.put("company_name", Collections.singletonList(request.getCompanyName()));

        if (request.getPhone() != null) {
            attributes.put("phone", Collections.singletonList(request.getPhone()));
        }

        // 3. Define roles
        List<String> roles = Arrays.asList("company_admin");

        // 4. Create user in Keycloak
        String userId = keycloakService.createUser(
            request.getEmail(),
            request.getPassword(),
            request.getFirstName(),
            request.getLastName(),
            attributes,
            roles
        );

        // 5. Send verification email
        keycloakService.sendVerifyEmail(userId);

        return SignUpResponse.success(tenantId, userId);
    }
}
```

### NanoID Generator for Tenant ID

```java
package com.systech.hrms.util;

import com.aventrix.jnanoid.jnanoid.NanoId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class NanoIdGenerator {

    @Value("${nanoid.size:12}")
    private int size;

    @Value("${nanoid.alphabet:0123456789abcdefghijklmnopqrstuvwxyz}")
    private String alphabet;

    /**
     * Generate a unique 12-character tenant ID
     * Format: lowercase alphanumeric
     * Example: a3b9c8d2e1f4
     */
    public String generateTenantId() {
        return NanoId.generate(alphabet.toCharArray(), size);
    }
}
```

Add to `pom.xml`:

```xml
<dependency>
    <groupId>com.aventrix.jnanoid</groupId>
    <artifactId>jnanoid</artifactId>
    <version>2.0.0</version>
</dependency>
```

---

## JWT Token Structure

### Sample JWT Token Claims

When a user authenticates, Keycloak returns a JWT token with these claims:

```json
{
  "exp": 1699105200,
  "iat": 1699101600,
  "jti": "a3b9c8d2-e1f4-4567-8901-234567890abc",
  "iss": "http://localhost:8090/realms/hrms-saas",
  "aud": "account",
  "sub": "226f442e-c931-4119-90d8-09435b2de2cf",
  "typ": "Bearer",
  "azp": "hrms-web-app",

  "preferred_username": "admin@testcompany.com",
  "email": "admin@testcompany.com",
  "email_verified": true,
  "name": "Admin User",
  "given_name": "Admin",
  "family_name": "User",

  "realm_access": {
    "roles": [
      "company_admin",
      "offline_access",
      "uma_authorization"
    ]
  },

  "tenant_id": "a3b9c8d2e1f4",
  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_type": "company_admin",
  "company_name": "Test Company Ltd",
  "company_code": "TEST001",
  "phone": "+1234567890"
}
```

### Extracting Claims in Spring Boot

```java
@RestController
@RequestMapping("/api/v1/user")
public class UserController {

    @GetMapping("/profile")
    public ResponseEntity<UserProfile> getUserProfile(
        @AuthenticationPrincipal Jwt jwt
    ) {
        // Extract standard claims
        String userId = jwt.getSubject();
        String email = jwt.getClaim("email");
        String name = jwt.getClaim("name");

        // Extract custom claims
        String tenantId = jwt.getClaim("tenant_id");
        String companyId = jwt.getClaim("company_id");
        String userType = jwt.getClaim("user_type");
        String companyName = jwt.getClaim("company_name");

        // Extract roles
        List<String> roles = jwt.getClaimAsStringList("realm_access.roles");

        UserProfile profile = UserProfile.builder()
            .userId(userId)
            .email(email)
            .name(name)
            .tenantId(tenantId)
            .companyId(companyId)
            .userType(userType)
            .companyName(companyName)
            .roles(roles)
            .build();

        return ResponseEntity.ok(profile);
    }
}
```

---

## Multi-Tenant Implementation

### Tenant Context (ThreadLocal)

Create a thread-safe tenant context:

```java
package com.systech.hrms.security;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class TenantContext {

    private static final ThreadLocal<String> currentTenant = new ThreadLocal<>();

    /**
     * Set the current tenant ID for this thread
     */
    public static void setCurrentTenant(String tenantId) {
        log.debug("Setting tenant context: {}", tenantId);
        currentTenant.set(tenantId);
    }

    /**
     * Get the current tenant ID
     * @return tenant ID or null if not set
     */
    public static String getCurrentTenant() {
        return currentTenant.get();
    }

    /**
     * Clear the tenant context (MUST be called after request)
     */
    public static void clear() {
        log.debug("Clearing tenant context: {}", currentTenant.get());
        currentTenant.remove();
    }

    /**
     * Check if tenant is set
     */
    public static boolean hasTenant() {
        return currentTenant.get() != null;
    }
}
```

### Tenant Filter

Create a filter to extract tenant_id from JWT and set context:

```java
package com.systech.hrms.filter;

import com.systech.hrms.security.TenantContext;
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Slf4j
@Component
public class TenantFilter implements Filter {

    @Override
    public void doFilter(
        ServletRequest request,
        ServletResponse response,
        FilterChain chain
    ) throws IOException, ServletException {

        try {
            HttpServletRequest httpRequest = (HttpServletRequest) request;

            // Extract tenant_id from JWT token
            Authentication authentication = SecurityContextHolder
                .getContext()
                .getAuthentication();

            if (authentication != null && authentication.getPrincipal() instanceof Jwt) {
                Jwt jwt = (Jwt) authentication.getPrincipal();
                String tenantId = jwt.getClaim("tenant_id");

                if (tenantId != null && !tenantId.isEmpty()) {
                    TenantContext.setCurrentTenant(tenantId);
                    log.debug("Tenant context set for request: {} - {}",
                        httpRequest.getRequestURI(), tenantId);
                } else {
                    log.warn("JWT token missing tenant_id claim for request: {}",
                        httpRequest.getRequestURI());
                }
            }

            // Continue the filter chain
            chain.doFilter(request, response);

        } finally {
            // CRITICAL: Always clear tenant context after request
            TenantContext.clear();
        }
    }
}
```

Register the filter:

```java
@Configuration
public class FilterConfig {

    @Bean
    public FilterRegistrationBean<TenantFilter> tenantFilter(TenantFilter filter) {
        FilterRegistrationBean<TenantFilter> registration =
            new FilterRegistrationBean<>(filter);
        registration.setOrder(2);  // After security filter
        return registration;
    }
}
```

### Using Tenant Context in Services

```java
@Service
public class EmployeeService {

    @Autowired
    private EmployeeRepository employeeRepository;

    public List<Employee> getAllEmployees() {
        String tenantId = TenantContext.getCurrentTenant();

        if (tenantId == null) {
            throw new TenantNotFoundException("Tenant context not set");
        }

        // Fetch employees for current tenant only
        return employeeRepository.findByTenantId(tenantId);
    }
}
```

---

## API Endpoints

### Public Endpoints (No Authentication)

#### 1. Sign Up (Create Customer)

**Endpoint:** `POST /api/v1/auth/signup`

**Request Body:**
```json
{
  "email": "admin@example.com",
  "password": "Password123!",
  "companyName": "Example Corp",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890"
}
```

**Response (Success):**
```json
{
  "success": true,
  "tenantId": "a3b9c8d2e1f4",
  "userId": "226f442e-c931-4119-90d8-09435b2de2cf",
  "requiresEmailVerification": true,
  "message": "Sign-up successful. Please verify your email."
}
```

**Response (Error - Email Exists):**
```json
{
  "timestamp": "2025-11-04T10:30:00",
  "status": 409,
  "error": "Conflict",
  "message": "Email address already exists: admin@example.com",
  "path": "/api/v1/auth/signup"
}
```

#### 2. Check Email Availability

**Endpoint:** `GET /api/v1/auth/check-email?email=test@example.com`

**Response:**
```json
{
  "available": false,
  "message": "Email address is already registered"
}
```

#### 3. Resend Verification Email

**Endpoint:** `POST /api/v1/auth/resend-verification`

**Request Body:**
```json
{
  "email": "admin@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Verification email sent successfully"
}
```

### Protected Endpoints (Require JWT Token)

All GraphQL endpoints and other API endpoints require JWT token in header:

```
Authorization: Bearer <jwt_token>
```

#### Example: Get User Profile

**Endpoint:** `GET /api/v1/user/profile`

**Headers:**
```
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:**
```json
{
  "userId": "226f442e-c931-4119-90d8-09435b2de2cf",
  "email": "admin@testcompany.com",
  "name": "Admin User",
  "tenantId": "a3b9c8d2e1f4",
  "companyId": "550e8400-e29b-41d4-a716-446655440000",
  "userType": "company_admin",
  "companyName": "Test Company Ltd",
  "roles": ["company_admin", "offline_access"]
}
```

---

## Testing & Validation

### 1. Test Keycloak Connectivity

```bash
# Test realm endpoint
curl -s http://localhost:8090/realms/hrms-saas/.well-known/openid-configuration | jq -r '.issuer'

# Expected output: http://localhost:8090/realms/hrms-saas
```

### 2. Test User Creation

Use the Keycloak Admin Console to verify user creation:

1. Open: http://localhost:8090/admin
2. Login: admin / secret
3. Select Realm: hrms-saas
4. Go to: Users → View all users
5. Click on created user
6. Verify:
   - Email verified status
   - Roles assigned
   - Attributes tab shows: tenant_id, company_id, user_type, company_name

### 3. Test Token Generation

```bash
# Get access token
TOKEN=$(curl -s -X POST "http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=hrms-web-app" \
  -d "client_secret=xE39L2zsTFkOjmAt47ToFQRwgIekjW3l" \
  -d "username=admin@testcompany.com" \
  -d "password=TestAdmin@123" | jq -r '.access_token')

# Decode JWT (requires jq)
echo $TOKEN | cut -d '.' -f 2 | base64 -d | jq .

# Test API with token
curl -s "http://localhost:8081/api/v1/user/profile" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### 4. Unit Tests

#### Test User Creation

```java
@SpringBootTest
@AutoConfigureMockMvc
class SignUpControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void testSignUp_Success() throws Exception {
        String requestBody = """
            {
              "email": "test@example.com",
              "password": "Password123!",
              "companyName": "Test Company",
              "firstName": "Test",
              "lastName": "User",
              "phone": "+1234567890"
            }
            """;

        mockMvc.perform(post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.tenantId").exists())
            .andExpect(jsonPath("$.userId").exists());
    }

    @Test
    void testSignUp_EmailExists() throws Exception {
        // First signup
        String requestBody = """
            {
              "email": "duplicate@example.com",
              "password": "Password123!",
              "companyName": "Test Company",
              "firstName": "Test",
              "lastName": "User"
            }
            """;

        mockMvc.perform(post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
            .andExpect(status().isOk());

        // Duplicate signup
        mockMvc.perform(post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.error").value("Conflict"));
    }
}
```

---

## Error Handling

### Global Exception Handler

```java
package com.systech.hrms.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(EmailAlreadyExistsException.class)
    public ResponseEntity<ErrorResponse> handleEmailExists(
        EmailAlreadyExistsException ex,
        WebRequest request
    ) {
        log.error("Email already exists: {}", ex.getMessage());

        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.CONFLICT.value())
            .error("Conflict")
            .message(ex.getMessage())
            .path(request.getDescription(false).replace("uri=", ""))
            .build();

        return ResponseEntity.status(HttpStatus.CONFLICT).body(error);
    }

    @ExceptionHandler(KeycloakIntegrationException.class)
    public ResponseEntity<ErrorResponse> handleKeycloakError(
        KeycloakIntegrationException ex,
        WebRequest request
    ) {
        log.error("Keycloak integration error: {}", ex.getMessage(), ex);

        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
            .error("Internal Server Error")
            .message("Failed to complete user registration. Please try again.")
            .path(request.getDescription(false).replace("uri=", ""))
            .build();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationErrors(
        MethodArgumentNotValidException ex,
        WebRequest request
    ) {
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
            errors.put(error.getField(), error.getDefaultMessage())
        );

        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.BAD_REQUEST.value())
            .error("Validation Failed")
            .message("Invalid request data")
            .path(request.getDescription(false).replace("uri=", ""))
            .validationErrors(errors)
            .build();

        return ResponseEntity.badRequest().body(error);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericError(
        Exception ex,
        WebRequest request
    ) {
        log.error("Unexpected error: {}", ex.getMessage(), ex);

        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
            .error("Internal Server Error")
            .message("An unexpected error occurred")
            .path(request.getDescription(false).replace("uri=", ""))
            .build();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}
```

---

## Best Practices

### Security Best Practices

1. **NEVER trust client-provided tenant_id**
   - Always extract from validated JWT token

2. **ALWAYS validate JWT signatures**
   - Spring Security handles this automatically

3. **ALWAYS set and clear TenantContext**
   ```java
   try {
       TenantContext.setCurrentTenant(tenantId);
       // ... business logic
   } finally {
       TenantContext.clear();  // Prevent memory leaks
   }
   ```

4. **NEVER log sensitive data**
   - Passwords, tokens, PII
   - Use log levels appropriately

5. **Use HTTPS in production**
   - Keycloak should use HTTPS
   - Backend API should use HTTPS

6. **Rotate client secrets regularly**
   - Change `keycloak.client.secret` periodically

7. **Implement rate limiting**
   - Prevent brute force attacks on login

8. **Validate all inputs**
   - Use Jakarta Bean Validation (`@Valid`, `@NotBlank`, etc.)

### Multi-Tenancy Best Practices

1. **Use Row-Level Security (RLS) in PostgreSQL**
   - Final defense layer at database level

2. **Set session variable for tenant filtering**
   ```sql
   SET app.current_tenant_id = 'a3b9c8d2e1f4';
   ```

3. **NEVER allow cross-tenant data access**
   - Always filter by tenant_id

4. **Test tenant isolation thoroughly**
   - Unit tests for tenant context
   - Integration tests for RLS policies

### Code Organization Best Practices

1. **Separate concerns**
   - Controllers: HTTP layer
   - Services: Business logic
   - Repositories: Data access
   - Security: Authentication/Authorization

2. **Use DTOs for API contracts**
   - Don't expose entities directly

3. **Implement proper exception handling**
   - Use `@RestControllerAdvice`
   - Return consistent error format

4. **Use Lombok to reduce boilerplate**
   - `@Data`, `@Builder`, `@Slf4j`

5. **Write comprehensive tests**
   - Unit tests for services
   - Integration tests for controllers
   - Security tests for auth flows

### Performance Best Practices

1. **Use connection pooling (HikariCP)**
   - Configure appropriate pool size

2. **Implement caching where appropriate**
   - User profiles, roles, permissions

3. **Use lazy loading for JPA relationships**
   - Avoid N+1 queries

4. **Index database columns**
   - tenant_id, email, status

5. **Monitor token validation performance**
   - Keycloak's JWKS endpoint is cached by Spring

---

## Troubleshooting

### Issue: JWT Validation Fails

**Symptoms:**
- 401 Unauthorized errors
- "Invalid JWT token" in logs

**Solutions:**

1. **Verify Keycloak is accessible**
   ```bash
   curl http://localhost:8090/realms/hrms-saas/.well-known/openid-configuration
   ```

2. **Check issuer URI matches**
   - application.yml: `http://localhost:8090/realms/hrms-saas`
   - JWT claim: `"iss": "http://localhost:8090/realms/hrms-saas"`

3. **Verify JWK Set URI is accessible**
   ```bash
   curl http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs
   ```

4. **Check token expiration**
   - JWT tokens expire after 5 minutes by default
   - Use refresh token to get new access token

5. **Verify client configuration**
   - Keycloak client ID: `hrms-web-app`
   - Client secret matches application.yml

---

### Issue: User Creation Fails

**Symptoms:**
- KeycloakIntegrationException thrown
- "Failed to create user" in logs

**Solutions:**

1. **Check Keycloak Admin credentials**
   ```yaml
   keycloak:
     admin:
       username: admin
       password: secret
   ```

2. **Verify Keycloak is running**
   ```bash
   curl http://localhost:8090/admin/realms/hrms-saas
   ```

3. **Check if user already exists**
   - Email must be unique in realm
   - Use `findUserIdByEmail()` before creation

4. **Verify realm name is correct**
   - Realm: `hrms-saas` (case-sensitive)

5. **Check Keycloak logs**
   ```bash
   podman logs keycloak-dev
   ```

---

### Issue: Missing Custom Claims in JWT

**Symptoms:**
- `tenant_id`, `company_id` are null in JWT
- Custom attributes not appearing in token

**Solutions:**

1. **Verify user attributes are set in Keycloak**
   - Admin Console → Users → Attributes tab
   - Should see: tenant_id, company_id, user_type, etc.

2. **Check protocol mappers exist**
   - Admin Console → Clients → hrms-web-app → Mappers
   - Should see: tenant_id, company_id, user_type, company_name, etc.

3. **Verify mapper configuration**
   - Mapper Type: User Attribute
   - User Attribute: tenant_id
   - Token Claim Name: tenant_id
   - Claim JSON Type: String
   - Add to ID token: ON
   - Add to access token: ON
   - Add to userinfo: ON

4. **Regenerate token after fixing**
   - Old tokens won't have new claims
   - User must login again

---

### Issue: CORS Errors

**Symptoms:**
- "CORS policy: No 'Access-Control-Allow-Origin' header"
- Preflight OPTIONS requests fail

**Solutions:**

1. **Verify CORS configuration in SecurityConfig**
   ```java
   configuration.setAllowedOrigins(Arrays.asList(
       "http://localhost:3000"  // React frontend URL
   ));
   ```

2. **Check if origin is allowed**
   - Must match exactly (including port)
   - No trailing slashes

3. **Verify credentials are allowed**
   ```java
   configuration.setAllowCredentials(true);
   ```

4. **Check allowed methods**
   ```java
   configuration.setAllowedMethods(Arrays.asList(
       "GET", "POST", "PUT", "DELETE", "OPTIONS"
   ));
   ```

5. **Ensure CORS filter runs before security**
   - Spring Security's CORS config should work
   - Don't create duplicate CORS filters

---

### Issue: Tenant Context Not Set

**Symptoms:**
- TenantNotFoundException thrown
- `TenantContext.getCurrentTenant()` returns null

**Solutions:**

1. **Verify TenantFilter is registered**
   ```java
   @Bean
   public FilterRegistrationBean<TenantFilter> tenantFilter() {
       // ...
   }
   ```

2. **Check filter order**
   - Must run AFTER SecurityFilter
   - Order should be > 1

3. **Verify JWT has tenant_id claim**
   ```bash
   echo $TOKEN | cut -d '.' -f 2 | base64 -d | jq '.tenant_id'
   ```

4. **Check endpoint requires authentication**
   - Public endpoints won't have JWT
   - TenantContext only set for authenticated requests

5. **Verify token is being sent**
   - Header: `Authorization: Bearer <token>`
   - Frontend must include header in requests

---

### Issue: Database Connection Fails

**Symptoms:**
- "Connection refused" errors
- Application won't start

**Solutions:**

1. **Verify PostgreSQL is running**
   ```bash
   podman ps | grep postgres
   ```

2. **Check database exists**
   ```bash
   psql -h localhost -U admin -d hrms_saas -c "\dt"
   ```

3. **Verify connection details**
   ```yaml
   spring:
     datasource:
       url: jdbc:postgresql://localhost:5432/hrms_saas
       username: admin
       password: admin
   ```

4. **Test connection manually**
   ```bash
   psql -h localhost -p 5432 -U admin -d hrms_saas
   ```

5. **Check Flyway migrations**
   ```bash
   mvn flyway:info
   mvn flyway:migrate
   ```

---

## Additional Resources

### Documentation

1. **Keycloak Documentation**
   - [Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/)
   - [Securing Applications](https://www.keycloak.org/docs/latest/securing_apps/)
   - [Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/)

2. **Spring Security OAuth2**
   - [OAuth2 Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/index.html)
   - [JWT Authentication](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)

3. **Project Documentation**
   - Located in: `/docs/`
   - SPRINGBOOT_QUICK_START.md
   - SPRINGBOOT_ARCHITECTURE.md
   - SPRINGBOOT_IMPLEMENTATION_GUIDE.md

### Sample Code

Complete working examples available in:
- `/springboot/src/main/java/com/systech/hrms/`

### Configuration Files

- Keycloak config: `/keycloak/config/keycloak-config.env`
- Test users: `/keycloak/config/test-users.txt`
- Spring Boot config: `/springboot/src/main/resources/application.yml`

### Scripts

- Keycloak setup: `/keycloak/scripts/setup-keycloak.sh`
- Create mappers: `/keycloak/scripts/create-mappers.sh`
- Create test users: `/keycloak/scripts/create-test-users.sh`
- Test tokens: `/keycloak/scripts/test-token.sh`

---

## Summary Checklist

Before deploying your Spring Boot application with Keycloak:

- [ ] Keycloak is running and accessible
- [ ] Realm `hrms-saas` exists with correct configuration
- [ ] Client `hrms-web-app` is configured with correct secret
- [ ] All 7 protocol mappers are created
- [ ] Spring Boot dependencies added to pom.xml
- [ ] application.yml configured with correct Keycloak URLs and credentials
- [ ] SecurityConfig.java created with JWT validation
- [ ] KeycloakAdminService.java implemented for user management
- [ ] TenantContext.java created for multi-tenancy
- [ ] TenantFilter.java created and registered
- [ ] User creation flow includes all required attributes (tenant_id, company_id, user_type, company_name)
- [ ] Exception handling implemented
- [ ] CORS configured for frontend
- [ ] Unit tests written for user creation
- [ ] Integration tests for JWT validation
- [ ] Logging configured appropriately
- [ ] Database connection tested
- [ ] Token generation tested with test users

---

## Support

For issues or questions:

1. **Check Keycloak Admin Console**
   - http://localhost:8090/admin
   - Verify realm, client, user configuration

2. **Review application logs**
   - Enable DEBUG logging for `com.systech.hrms`
   - Check for Keycloak-related errors

3. **Test with curl commands**
   - Verify endpoints are accessible
   - Test token generation manually

4. **Consult project documentation**
   - `/docs/SPRINGBOOT_*.md` files
   - `/keycloak/keycloak-docs/` directory

---

**Document Owner:** Backend Development Team
**Last Updated:** November 4, 2025
**Next Review:** Every Sprint

---

*This document is part of the HRMS SaaS project documentation suite.*
