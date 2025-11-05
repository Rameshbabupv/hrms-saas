package com.systech.hrms.exception;

/**
 * Exception thrown when attempting to create a company with a name that already exists
 *
 * This is used during signup when a user tries to register with a company name
 * that is already registered in the system.
 *
 * @author Systech Team
 * @version 1.0.0
 */
public class CompanyNameAlreadyExistsException extends RuntimeException {

    private final String companyName;
    private final String adminEmail;

    public CompanyNameAlreadyExistsException(String companyName, String adminEmail) {
        super(String.format(
            "Company '%s' already exists. Please contact the company administrator at %s to join the organization.",
            companyName,
            adminEmail
        ));
        this.companyName = companyName;
        this.adminEmail = adminEmail;
    }

    public String getCompanyName() {
        return companyName;
    }

    public String getAdminEmail() {
        return adminEmail;
    }
}
