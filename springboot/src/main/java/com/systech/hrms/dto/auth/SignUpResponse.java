package com.systech.hrms.dto.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * SignUpResponse - DTO for signup response
 *
 * Response payload after successful or failed signup.
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SignUpResponse {

    /**
     * Whether signup was successful
     */
    private boolean success;

    /**
     * Response message
     */
    private String message;

    /**
     * Generated tenant ID (NanoID format)
     * Only present on successful signup
     */
    private String tenantId;

    /**
     * Keycloak user ID
     * Only present on successful signup
     */
    private String userId;

    /**
     * Whether email verification is required
     */
    private boolean requiresEmailVerification;

    /**
     * Static factory method for success response
     */
    public static SignUpResponse success(String tenantId, String userId) {
        return SignUpResponse.builder()
            .success(true)
            .message("Account created successfully. Please verify your email to continue.")
            .tenantId(tenantId)
            .userId(userId)
            .requiresEmailVerification(true)
            .build();
    }

    /**
     * Static factory method for error response
     */
    public static SignUpResponse error(String message) {
        return SignUpResponse.builder()
            .success(false)
            .message(message)
            .requiresEmailVerification(false)
            .build();
    }
}
