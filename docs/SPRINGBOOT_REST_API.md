# HRMS SaaS - REST API Implementation

## 📋 Part 3: REST API for Authentication

This document provides complete REST API implementation for user signup and authentication.

---

## 🎯 REST API Endpoints

### **Authentication Endpoints**

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/v1/auth/signup` | Create new customer account | No |
| POST | `/api/v1/auth/resend-verification` | Resend verification email | No |
| GET | `/api/v1/auth/verify-email` | Verify email with token | No |
| GET | `/api/v1/auth/check-email` | Check email availability | No |

---

## 📦 DTOs (Data Transfer Objects)

### **SignUpRequest.java**

```java
package com.systech.hrms.dto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SignUpRequest {

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "Password is required")
    @Size(min = 8, message = "Password must be at least 8 characters")
    @Pattern(
        regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$",
        message = "Password must contain uppercase, lowercase, number, and special character"
    )
    private String password;

    @NotBlank(message = "Company name is required")
    @Size(min = 2, max = 255, message = "Company name must be between 2 and 255 characters")
    private String companyName;

    @NotBlank(message = "First name is required")
    @Size(min = 1, max = 100, message = "First name must be between 1 and 100 characters")
    private String firstName;

    @NotBlank(message = "Last name is required")
    @Size(min = 1, max = 100, message = "Last name must be between 1 and 100 characters")
    private String lastName;

    @Pattern(
        regexp = "^[+]?[0-9]{10,15}$",
        message = "Invalid phone number format"
    )
    private String phone;
}
```

### **SignUpResponse.java**

```java
package com.systech.hrms.dto.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SignUpResponse {

    private boolean success;

    private String message;

    private String tenantId;  // NanoID

    private String userId;  // Keycloak user ID

    private boolean requiresEmailVerification;

    public static SignUpResponse success(String tenantId, String userId) {
        return SignUpResponse.builder()
            .success(true)
            .message("Account created successfully. Please verify your email.")
            .tenantId(tenantId)
            .userId(userId)
            .requiresEmailVerification(true)
            .build();
    }

    public static SignUpResponse error(String message) {
        return SignUpResponse.builder()
            .success(false)
            .message(message)
            .requiresEmailVerification(false)
            .build();
    }
}
```

---

## 🎮 Controller Layer

### **SignUpController.java**

```java
package com.systech.hrms.controller.auth;

import com.systech.hrms.dto.auth.SignUpRequest;
import com.systech.hrms.dto.auth.SignUpResponse;
import com.systech.hrms.service.SignUpService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@CrossOrigin(origins = {"http://localhost:3000", "http://192.168.1.6:3000"})
public class SignUpController {

    private final SignUpService signUpService;

    /**
     * Create new customer account
     * POST /api/v1/auth/signup
     */
    @PostMapping("/signup")
    public ResponseEntity<SignUpResponse> signUp(@Valid @RequestBody SignUpRequest request) {
        log.info("Received signup request for email: {}", request.getEmail());

        try {
            SignUpResponse response = signUpService.createCustomer(request);
            log.info("Signup successful for email: {}, tenantId: {}",
                request.getEmail(), response.getTenantId());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (EmailAlreadyExistsException e) {
            log.warn("Signup failed - email already exists: {}", request.getEmail());
            return ResponseEntity
                .status(HttpStatus.CONFLICT)
                .body(SignUpResponse.error("Email address already exists"));

        } catch (KeycloakIntegrationException e) {
            log.error("Keycloak integration failed during signup: {}", e.getMessage(), e);
            return ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(SignUpResponse.error("Account creation pending. Please try again later."));

        } catch (Exception e) {
            log.error("Unexpected error during signup: {}", e.getMessage(), e);
            return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(SignUpResponse.error("Sign-up failed. Please try again."));
        }
    }

    /**
     * Resend email verification
     * POST /api/v1/auth/resend-verification
     */
    @PostMapping("/resend-verification")
    public ResponseEntity<Map<String, Object>> resendVerification(
        @RequestBody Map<String, String> request
    ) {
        String email = request.get("email");
        log.info("Resend verification requested for: {}", email);

        try {
            signUpService.resendVerificationEmail(email);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Verification email sent successfully"
            ));
        } catch (Exception e) {
            log.error("Failed to resend verification: {}", e.getMessage(), e);
            return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of(
                    "success", false,
                    "message", "Failed to resend verification email"
                ));
        }
    }

    /**
     * Check email availability
     * GET /api/v1/auth/check-email?email=test@example.com
     */
    @GetMapping("/check-email")
    public ResponseEntity<Map<String, Boolean>> checkEmailAvailability(
        @RequestParam String email
    ) {
        boolean available = !signUpService.emailExists(email);
        return ResponseEntity.ok(Map.of("available", available));
    }
}
```

---

## 🔧 Service Layer

### **SignUpService.java**

```java
package com.systech.hrms.service;

import com.systech.hrms.dto.auth.SignUpRequest;
import com.systech.hrms.dto.auth.SignUpResponse;
import com.systech.hrms.entity.CompanyMaster;
import com.systech.hrms.exception.EmailAlreadyExistsException;
import com.systech.hrms.exception.KeycloakIntegrationException;
import com.systech.hrms.repository.CompanyRepository;
import com.systech.hrms.util.NanoIdGenerator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class SignUpService {

    private final CompanyRepository companyRepository;
    private final KeycloakAdminService keycloakAdminService;
    private final NanoIdGenerator nanoIdGenerator;

    /**
     * Create new customer account
     *
     * Process:
     * 1. Validate email uniqueness
     * 2. Generate NanoID for tenant_id
     * 3. Create company_master record
     * 4. Create Keycloak user with tenant_id attribute
     * 5. Send verification email
     *
     * Rollback Strategy: Partial rollback with retry
     * - If company creation succeeds but Keycloak fails: Keep company, allow retry
     * - If email sending fails: Keep user, allow manual resend
     */
    @Transactional
    public SignUpResponse createCustomer(SignUpRequest request) {
        log.info("Starting customer creation for: {}", request.getEmail());

        // 1. Check email uniqueness
        if (emailExists(request.getEmail())) {
            throw new EmailAlreadyExistsException("Email address already exists: " + request.getEmail());
        }

        // 2. Generate unique NanoID for tenant_id
        String tenantId = generateUniqueTenantId();
        log.info("Generated tenant_id: {}", tenantId);

        // 3. Create company_master record
        CompanyMaster company = createCompany(tenantId, request);
        log.info("Company created: {} with tenant_id: {}", company.getCompanyName(), tenantId);

        // 4. Create Keycloak user with tenant_id attribute
        String keycloakUserId;
        try {
            keycloakUserId = createKeycloakUser(tenantId, company, request);
            log.info("Keycloak user created: {}", keycloakUserId);
        } catch (Exception e) {
            log.error("Keycloak user creation failed for tenant_id: {}", tenantId, e);
            // Mark company as pending activation
            company.setStatus("PENDING_KEYCLOAK_SETUP");
            companyRepository.save(company);
            throw new KeycloakIntegrationException("Failed to create Keycloak user", e);
        }

        // 5. Send verification email (Keycloak handles this)
        try {
            keycloakAdminService.sendVerifyEmail(keycloakUserId);
            log.info("Verification email sent to: {}", request.getEmail());
        } catch (Exception e) {
            log.warn("Failed to send verification email to: {}", request.getEmail(), e);
            // Don't fail - user can request resend later
        }

        // 6. Update company status to active (pending email verification)
        company.setStatus("PENDING_EMAIL_VERIFICATION");
        companyRepository.save(company);

        return SignUpResponse.success(tenantId, keycloakUserId);
    }

    /**
     * Generate unique tenant ID using NanoID
     * Retry if collision detected (extremely rare)
     */
    private String generateUniqueTenantId() {
        int maxRetries = 5;
        for (int i = 0; i < maxRetries; i++) {
            String tenantId = nanoIdGenerator.generateTenantId();
            if (!companyRepository.existsById(tenantId)) {
                return tenantId;
            }
            log.warn("Tenant ID collision detected, retrying... (attempt {})", i + 1);
        }
        throw new RuntimeException("Failed to generate unique tenant ID after " + maxRetries + " attempts");
    }

    /**
     * Create company_master record
     */
    private CompanyMaster createCompany(String tenantId, SignUpRequest request) {
        CompanyMaster company = CompanyMaster.builder()
            .tenantId(tenantId)
            .companyName(request.getCompanyName())
            .email(request.getEmail())
            .phone(request.getPhone())
            .status("PENDING_ACTIVATION")
            .subscriptionPlan("FREE")
            .createdBy(request.getEmail())
            .build();

        return companyRepository.save(company);
    }

    /**
     * Create Keycloak user with tenant_id attribute
     */
    private String createKeycloakUser(
        String tenantId,
        CompanyMaster company,
        SignUpRequest request
    ) {
        // Build Keycloak user request
        var keycloakUser = KeycloakUserRequest.builder()
            .username(request.getEmail())
            .email(request.getEmail())
            .firstName(request.getFirstName())
            .lastName(request.getLastName())
            .enabled(false)  // Disabled until email verified
            .emailVerified(false)
            .attributes(Map.of(
                "tenant_id", List.of(tenantId),  // ✅ NanoID stored in Keycloak
                "user_type", List.of("company_admin"),
                "company_name", List.of(company.getCompanyName())
            ))
            .realmRoles(List.of("company_admin"))
            .build();

        // Create user in Keycloak via Admin API
        return keycloakAdminService.createUser(keycloakUser, request.getPassword());
    }

    /**
     * Resend verification email
     */
    public void resendVerificationEmail(String email) {
        CompanyMaster company = companyRepository.findByEmail(email)
            .orElseThrow(() -> new RuntimeException("Email not found: " + email));

        // Get Keycloak user ID from email
        String keycloakUserId = keycloakAdminService.findUserByEmail(email);

        // Resend verification email
        keycloakAdminService.sendVerifyEmail(keycloakUserId);
    }

    /**
     * Check if email exists
     */
    public boolean emailExists(String email) {
        return companyRepository.existsByEmail(email);
    }
}
```

---

## 🔐 Keycloak Admin Service

### **KeycloakAdminService.java**

```java
package com.systech.hrms.service;

import com.systech.hrms.dto.auth.KeycloakUserRequest;
import com.systech.hrms.exception.KeycloakIntegrationException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.keycloak.admin.client.Keycloak;
import org.keycloak.admin.client.KeycloakBuilder;
import org.keycloak.admin.client.resource.RealmResource;
import org.keycloak.admin.client.resource.UsersResource;
import org.keycloak.representations.idm.CredentialRepresentation;
import org.keycloak.representations.idm.UserRepresentation;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.ws.rs.core.Response;
import java.util.Collections;
import java.util.List;

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
        log.info("Initializing Keycloak Admin Client");
        this.keycloak = KeycloakBuilder.builder()
            .serverUrl(serverUrl)
            .realm("master")  // Admin uses master realm
            .clientId(adminClientId)
            .username(adminUsername)
            .password(adminPassword)
            .build();

        this.realmResource = keycloak.realm(realm);
        log.info("Keycloak Admin Client initialized successfully");
    }

    /**
     * Create user in Keycloak with tenant_id attribute
     *
     * @param request User details with attributes
     * @param password User password
     * @return Keycloak user ID
     */
    public String createUser(KeycloakUserRequest request, String password) {
        log.info("Creating Keycloak user: {}", request.getEmail());

        try {
            UsersResource usersResource = realmResource.users();

            // Build user representation
            UserRepresentation user = new UserRepresentation();
            user.setUsername(request.getUsername());
            user.setEmail(request.getEmail());
            user.setFirstName(request.getFirstName());
            user.setLastName(request.getLastName());
            user.setEnabled(request.isEnabled());
            user.setEmailVerified(request.isEmailVerified());
            user.setAttributes(request.getAttributes());
            user.setRealmRoles(request.getRealmRoles());

            // Set password credential
            CredentialRepresentation credential = new CredentialRepresentation();
            credential.setType(CredentialRepresentation.PASSWORD);
            credential.setValue(password);
            credential.setTemporary(false);
            user.setCredentials(Collections.singletonList(credential));

            // Create user
            Response response = usersResource.create(user);

            if (response.getStatus() == 201) {
                String locationHeader = response.getHeaderString("Location");
                String userId = locationHeader.substring(locationHeader.lastIndexOf('/') + 1);
                log.info("Keycloak user created successfully: {}", userId);
                return userId;
            } else {
                String errorMessage = response.readEntity(String.class);
                log.error("Failed to create Keycloak user. Status: {}, Error: {}",
                    response.getStatus(), errorMessage);
                throw new KeycloakIntegrationException(
                    "Failed to create user in Keycloak: " + errorMessage
                );
            }

        } catch (Exception e) {
            log.error("Error creating Keycloak user: {}", e.getMessage(), e);
            throw new KeycloakIntegrationException("Failed to create Keycloak user", e);
        }
    }

    /**
     * Send email verification to user
     *
     * @param userId Keycloak user ID
     */
    public void sendVerifyEmail(String userId) {
        log.info("Sending verification email for user: {}", userId);
        try {
            realmResource.users()
                .get(userId)
                .sendVerifyEmail();
            log.info("Verification email sent successfully");
        } catch (Exception e) {
            log.error("Failed to send verification email: {}", e.getMessage(), e);
            throw new KeycloakIntegrationException("Failed to send verification email", e);
        }
    }

    /**
     * Find user by email
     *
     * @param email User email
     * @return Keycloak user ID
     */
    public String findUserByEmail(String email) {
        log.info("Finding Keycloak user by email: {}", email);
        try {
            List<UserRepresentation> users = realmResource.users()
                .search(email, true);

            if (users.isEmpty()) {
                throw new KeycloakIntegrationException("User not found: " + email);
            }

            return users.get(0).getId();
        } catch (Exception e) {
            log.error("Failed to find user by email: {}", e.getMessage(), e);
            throw new KeycloakIntegrationException("Failed to find user", e);
        }
    }
}
```

### **KeycloakUserRequest.java**

```java
package com.systech.hrms.dto.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KeycloakUserRequest {
    private String username;
    private String email;
    private String firstName;
    private String lastName;
    private boolean enabled;
    private boolean emailVerified;
    private Map<String, List<String>> attributes;
    private List<String> realmRoles;
}
```

---

## ❌ Exception Handling

### **Custom Exceptions**

```java
package com.systech.hrms.exception;

public class EmailAlreadyExistsException extends RuntimeException {
    public EmailAlreadyExistsException(String message) {
        super(message);
    }
}

public class KeycloakIntegrationException extends RuntimeException {
    public KeycloakIntegrationException(String message) {
        super(message);
    }

    public KeycloakIntegrationException(String message, Throwable cause) {
        super(message, cause);
    }
}

public class TenantNotFoundException extends RuntimeException {
    public TenantNotFoundException(String message) {
        super(message);
    }
}
```

### **GlobalExceptionHandler.java**

```java
package com.systech.hrms.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(EmailAlreadyExistsException.class)
    public ResponseEntity<Map<String, Object>> handleEmailExists(EmailAlreadyExistsException e) {
        log.warn("Email already exists: {}", e.getMessage());
        return ResponseEntity
            .status(HttpStatus.CONFLICT)
            .body(Map.of(
                "error", "EMAIL_EXISTS",
                "message", e.getMessage()
            ));
    }

    @ExceptionHandler(KeycloakIntegrationException.class)
    public ResponseEntity<Map<String, Object>> handleKeycloakError(KeycloakIntegrationException e) {
        log.error("Keycloak integration error: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.SERVICE_UNAVAILABLE)
            .body(Map.of(
                "error", "KEYCLOAK_ERROR",
                "message", "Authentication service temporarily unavailable"
            ));
    }

    @ExceptionHandler(TenantNotFoundException.class)
    public ResponseEntity<Map<String, Object>> handleTenantNotFound(TenantNotFoundException e) {
        log.warn("Tenant not found: {}", e.getMessage());
        return ResponseEntity
            .status(HttpStatus.NOT_FOUND)
            .body(Map.of(
                "error", "TENANT_NOT_FOUND",
                "message", e.getMessage()
            ));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationErrors(
        MethodArgumentNotValidException e
    ) {
        Map<String, String> errors = new HashMap<>();
        e.getBindingResult().getAllErrors().forEach(error -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            errors.put(fieldName, errorMessage);
        });

        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(Map.of(
                "error", "VALIDATION_ERROR",
                "message", "Invalid request data",
                "fields", errors
            ));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericError(Exception e) {
        log.error("Unexpected error: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of(
                "error", "INTERNAL_ERROR",
                "message", "An unexpected error occurred"
            ));
    }
}
```

---

**Continued in SPRINGBOOT_GRAPHQL.md...**
