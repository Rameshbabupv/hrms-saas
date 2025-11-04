package com.systech.hrms.exception;

/**
 * KeycloakIntegrationException - Thrown when Keycloak operations fail
 *
 * @author Systech Team
 * @version 1.0.0
 */
public class KeycloakIntegrationException extends RuntimeException {

    public KeycloakIntegrationException(String message) {
        super(message);
    }

    public KeycloakIntegrationException(String message, Throwable cause) {
        super(message, cause);
    }
}
