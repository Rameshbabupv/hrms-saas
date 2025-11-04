package com.systech.hrms.controller.auth;

import com.systech.hrms.dto.auth.SignUpRequest;
import com.systech.hrms.dto.auth.SignUpResponse;
import com.systech.hrms.exception.EmailAlreadyExistsException;
import com.systech.hrms.exception.KeycloakIntegrationException;
import com.systech.hrms.service.SignUpService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * SignUpController - REST API for customer signup
 *
 * Endpoints:
 * - POST /api/v1/auth/signup - Create new customer account
 * - POST /api/v1/auth/resend-verification - Resend verification email
 * - GET /api/v1/auth/check-email - Check email availability
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@CrossOrigin(origins = {"http://localhost:3000", "http://localhost:3001", "http://192.168.1.6:3000"})
public class SignUpController {

    private final SignUpService signUpService;

    /**
     * Create new customer account
     * POST /api/v1/auth/signup
     *
     * @param request signup request
     * @return signup response
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
     *
     * @param request request containing email
     * @return response
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
     *
     * @param email email to check
     * @return availability status
     */
    @GetMapping("/check-email")
    public ResponseEntity<Map<String, Boolean>> checkEmailAvailability(
        @RequestParam String email
    ) {
        boolean available = !signUpService.emailExists(email);
        return ResponseEntity.ok(Map.of("available", available));
    }
}
