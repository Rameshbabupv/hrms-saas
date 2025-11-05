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

/**
 * GlobalExceptionHandler - Centralized exception handling
 *
 * Handles all exceptions thrown by controllers and services,
 * converts them to appropriate HTTP responses.
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * Handle email already exists exception
     */
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

    /**
     * Handle company name already exists exception
     */
    @ExceptionHandler(CompanyNameAlreadyExistsException.class)
    public ResponseEntity<Map<String, Object>> handleCompanyNameExists(CompanyNameAlreadyExistsException e) {
        log.warn("Company name already exists: {}", e.getCompanyName());
        return ResponseEntity
            .status(HttpStatus.CONFLICT)
            .body(Map.of(
                "error", "COMPANY_EXISTS",
                "message", e.getMessage(),
                "companyName", e.getCompanyName(),
                "adminEmail", e.getAdminEmail()
            ));
    }

    /**
     * Handle Keycloak integration errors
     */
    @ExceptionHandler(KeycloakIntegrationException.class)
    public ResponseEntity<Map<String, Object>> handleKeycloakError(KeycloakIntegrationException e) {
        log.error("Keycloak integration error: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.SERVICE_UNAVAILABLE)
            .body(Map.of(
                "error", "KEYCLOAK_ERROR",
                "message", "Authentication service temporarily unavailable. Please try again later."
            ));
    }

    /**
     * Handle tenant not found exception
     */
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

    /**
     * Handle validation errors (from @Valid annotations)
     */
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

        log.warn("Validation error: {}", errors);

        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(Map.of(
                "error", "VALIDATION_ERROR",
                "message", "Invalid request data",
                "fields", errors
            ));
    }

    /**
     * Handle all other exceptions
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericError(Exception e) {
        log.error("Unexpected error: {}", e.getMessage(), e);
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of(
                "error", "INTERNAL_ERROR",
                "message", "An unexpected error occurred. Please try again later."
            ));
    }
}
