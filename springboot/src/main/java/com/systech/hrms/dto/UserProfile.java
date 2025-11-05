package com.systech.hrms.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * UserProfile - DTO for user profile information
 *
 * Contains user information extracted from JWT token and tenant context.
 * Used for testing and verification of multi-tenant setup.
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserProfile {

    // Standard user information from JWT
    private String userId;           // From JWT 'sub' claim (Keycloak user ID)
    private String email;            // From JWT 'email' claim
    private String name;             // From JWT 'name' claim
    private String firstName;        // From JWT 'given_name' claim
    private String lastName;         // From JWT 'family_name' claim

    // Multi-tenant information from JWT custom claims
    private String tenantId;         // From JWT 'tenant_id' claim (12-char NanoID)
    private String companyId;        // From JWT 'company_id' claim (UUID)
    private String userType;         // From JWT 'user_type' claim (company_admin, hr_user, etc.)
    private String companyName;      // From JWT 'company_name' claim
    private String companyCode;      // From JWT 'company_code' claim
    private String employeeId;       // From JWT 'employee_id' claim (if set)
    private String phone;            // From JWT 'phone' claim

    // Roles from JWT
    private List<String> roles;      // From JWT 'realm_access.roles'

    // Debugging/validation fields
    private String contextTenantId;  // From TenantContext (ThreadLocal)
    private String dbTenantId;       // From PostgreSQL session variable
    private Boolean tenantContextMatch;  // Does context match DB session?
}
