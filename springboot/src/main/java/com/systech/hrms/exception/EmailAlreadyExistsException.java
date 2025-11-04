package com.systech.hrms.exception;

/**
 * EmailAlreadyExistsException - Thrown when signup email already exists
 *
 * @author Systech Team
 * @version 1.0.0
 */
public class EmailAlreadyExistsException extends RuntimeException {

    public EmailAlreadyExistsException(String message) {
        super(message);
    }

    public EmailAlreadyExistsException(String message, Throwable cause) {
        super(message, cause);
    }
}
