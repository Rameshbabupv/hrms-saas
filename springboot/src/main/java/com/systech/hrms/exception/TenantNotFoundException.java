package com.systech.hrms.exception;

/**
 * TenantNotFoundException - Thrown when tenant is not found
 *
 * @author Systech Team
 * @version 1.0.0
 */
public class TenantNotFoundException extends RuntimeException {

    public TenantNotFoundException(String message) {
        super(message);
    }

    public TenantNotFoundException(String message, Throwable cause) {
        super(message, cause);
    }
}
