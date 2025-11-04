package com.systech.hrms;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * HRMS SaaS - Multi-Tenant Application
 *
 * Main Spring Boot application entry point for HRMS SaaS platform.
 *
 * Architecture:
 * - Multi-tenant with NanoID-based tenant isolation
 * - PostgreSQL with Row-Level Security (RLS)
 * - Keycloak OAuth2/JWT authentication
 * - REST API for authentication
 * - GraphQL API for business operations
 *
 * @author Systech Team
 * @version 1.0.0
 */
@SpringBootApplication
public class HrmsSaasApplication {

    public static void main(String[] args) {
        SpringApplication.run(HrmsSaasApplication.class, args);
    }
}
