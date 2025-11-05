package com.systech.hrms.controller;

import com.systech.hrms.dto.UserProfile;
import com.systech.hrms.security.TenantContext;
import com.systech.hrms.service.DatabaseTenantManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * UserController - Test endpoints for multi-tenant verification
 *
 * Provides endpoints to:
 * - Get current user profile with tenant information
 * - Verify tenant context is set correctly
 * - Test JWT claims extraction
 * - Validate multi-tenant isolation
 *
 * These endpoints are primarily for testing and debugging the multi-tenant setup.
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/user")
@RequiredArgsConstructor
public class UserController {

    private final DatabaseTenantManager dbTenantManager;

    /**
     * Get current user profile with tenant context
     *
     * Extracts all JWT claims and tenant context information.
     * Useful for verifying that:
     * - JWT contains all required custom claims
     * - TenantFilter extracted tenant_id correctly
     * - Database session variable is set
     * - Tenant context matches across all layers
     *
     * GET /api/v1/user/profile
     * Authorization: Bearer <jwt_token>
     *
     * @param jwt JWT token from authenticated request
     * @return UserProfile with all user and tenant information
     */
    @GetMapping("/profile")
    public ResponseEntity<UserProfile> getUserProfile(
        @AuthenticationPrincipal Jwt jwt
    ) {
        String emailClaim = jwt.getClaim("email");
        log.info("Fetching user profile for: {}", emailClaim);

        // Extract standard JWT claims
        String userId = jwt.getSubject();
        String email = jwt.getClaim("email");
        String name = jwt.getClaim("name");
        String firstName = jwt.getClaim("given_name");
        String lastName = jwt.getClaim("family_name");

        // Extract custom tenant claims
        String tenantId = jwt.getClaim("tenant_id");
        String companyId = jwt.getClaim("company_id");
        String userType = jwt.getClaim("user_type");
        String companyName = jwt.getClaim("company_name");
        String companyCode = jwt.getClaim("company_code");
        String employeeId = jwt.getClaim("employee_id");
        String phone = jwt.getClaim("phone");

        // Extract roles from realm_access
        List<String> roles = extractRoles(jwt);

        // Get tenant from ThreadLocal context (set by TenantFilter)
        String contextTenantId = TenantContext.getCurrentTenant();

        // Get tenant from database session variable
        String dbTenantId = dbTenantManager.getCurrentTenantSession();

        // Validate tenant context matches
        boolean tenantMatch = contextTenantId != null && contextTenantId.equals(dbTenantId);

        UserProfile profile = UserProfile.builder()
            .userId(userId)
            .email(email)
            .name(name)
            .firstName(firstName)
            .lastName(lastName)
            .tenantId(tenantId)
            .companyId(companyId)
            .userType(userType)
            .companyName(companyName)
            .companyCode(companyCode)
            .employeeId(employeeId)
            .phone(phone)
            .roles(roles)
            .contextTenantId(contextTenantId)
            .dbTenantId(dbTenantId)
            .tenantContextMatch(tenantMatch)
            .build();

        log.info("User profile built: tenantId={}, userType={}, contextMatch={}",
            tenantId, userType, String.valueOf(tenantMatch));

        return ResponseEntity.ok(profile);
    }

    /**
     * Get tenant information only (lightweight endpoint)
     *
     * Returns tenant context information from all layers:
     * - JWT claim
     * - ThreadLocal context (TenantContext)
     * - Database session variable
     *
     * Useful for quick verification that tenant context is set correctly.
     *
     * GET /api/v1/user/tenant-info
     * Authorization: Bearer <jwt_token>
     *
     * @param jwt JWT token from authenticated request
     * @return Map with tenant information from all sources
     */
    @GetMapping("/tenant-info")
    public ResponseEntity<Map<String, Object>> getTenantInfo(
        @AuthenticationPrincipal Jwt jwt
    ) {
        String jwtTenantId = jwt.getClaim("tenant_id");
        String contextTenantId = TenantContext.getCurrentTenant();
        String dbTenantId = dbTenantManager.getCurrentTenantSession();

        boolean allMatch = jwtTenantId != null
            && jwtTenantId.equals(contextTenantId)
            && jwtTenantId.equals(dbTenantId);

        Map<String, Object> tenantInfo = Map.of(
            "jwtTenantId", jwtTenantId != null ? jwtTenantId : "NOT_SET",
            "contextTenantId", contextTenantId != null ? contextTenantId : "NOT_SET",
            "dbTenantId", dbTenantId != null ? dbTenantId : "NOT_SET",
            "allMatch", allMatch,
            "timestamp", System.currentTimeMillis(),
            "requestedBy", jwt.getClaim("email")
        );

        log.debug("Tenant info: JWT={}, Context={}, DB={}, Match={}",
            jwtTenantId, contextTenantId, dbTenantId, allMatch);

        return ResponseEntity.ok(tenantInfo);
    }

    /**
     * Test endpoint to verify JWT claims
     *
     * Returns all JWT claims for debugging purposes.
     * Useful for verifying that Keycloak protocol mappers are configured correctly.
     *
     * GET /api/v1/user/jwt-claims
     * Authorization: Bearer <jwt_token>
     *
     * @param jwt JWT token from authenticated request
     * @return All JWT claims
     */
    @GetMapping("/jwt-claims")
    public ResponseEntity<Map<String, Object>> getJwtClaims(
        @AuthenticationPrincipal Jwt jwt
    ) {
        log.debug("Retrieving all JWT claims");
        return ResponseEntity.ok(jwt.getClaims());
    }

    /**
     * Extract roles from JWT realm_access claim
     *
     * @param jwt JWT token
     * @return List of roles, or empty list if not found
     */
    @SuppressWarnings("unchecked")
    private List<String> extractRoles(Jwt jwt) {
        try {
            Map<String, Object> realmAccess = jwt.getClaim("realm_access");
            if (realmAccess != null && realmAccess.containsKey("roles")) {
                return (List<String>) realmAccess.get("roles");
            }
        } catch (Exception e) {
            log.warn("Failed to extract roles from JWT: {}", e.getMessage());
        }
        return List.of();
    }
}
