package com.systech.hrms.service;

import com.systech.hrms.dto.auth.SignUpRequest;
import com.systech.hrms.dto.auth.SignUpResponse;
import com.systech.hrms.entity.CompanyMaster;
import com.systech.hrms.exception.CompanyNameAlreadyExistsException;
import com.systech.hrms.exception.EmailAlreadyExistsException;
import com.systech.hrms.exception.KeycloakIntegrationException;
import com.systech.hrms.repository.CompanyRepository;
import com.systech.hrms.util.NanoIdGenerator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * SignUpService - Business logic for customer signup
 *
 * Process:
 * 1. Validate email uniqueness
 * 2. Generate NanoID for tenant_id
 * 3. Create company_master record in PostgreSQL
 * 4. Create user in Keycloak with tenant_id attribute
 * 5. Send email verification
 *
 * Rollback Strategy:
 * - If company creation succeeds but Keycloak fails: Mark company as PENDING_KEYCLOAK_SETUP
 * - If email sending fails: Keep user, allow manual resend
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SignUpService {

    private final CompanyRepository companyRepository;
    private final KeycloakAdminService keycloakAdminService;
    private final NanoIdGenerator nanoIdGenerator;

    /**
     * Create new customer account
     *
     * @param request signup request
     * @return signup response
     */
    @Transactional
    public SignUpResponse createCustomer(SignUpRequest request) {
        log.info("Starting customer creation for: {}", request.getEmail());

        // Step 1: Check email uniqueness in PostgreSQL
        if (emailExists(request.getEmail())) {
            log.warn("Email already exists in database: {}", request.getEmail());
            throw new EmailAlreadyExistsException("Email address already exists: " + request.getEmail());
        }

        // Step 1.1: Check email uniqueness in Keycloak
        if (keycloakAdminService.userExistsByEmail(request.getEmail())) {
            log.warn("Email already exists in Keycloak: {}", request.getEmail());
            throw new EmailAlreadyExistsException("Email address already exists: " + request.getEmail());
        }

        // Step 1.2: Check company name uniqueness
        if (companyNameExists(request.getCompanyName())) {
            CompanyMaster existingCompany = companyRepository
                .findByCompanyNameIgnoreCase(request.getCompanyName())
                .orElseThrow();

            log.warn("Company name already exists: {} (admin: {})",
                request.getCompanyName(), existingCompany.getEmail());

            throw new CompanyNameAlreadyExistsException(
                request.getCompanyName(),
                existingCompany.getEmail()
            );
        }

        // Step 2: Generate unique NanoID for tenant_id
        String tenantId = generateUniqueTenantId();
        log.info("Generated tenant_id: {}", tenantId);

        // Step 3: Create company_master record
        CompanyMaster company = createCompany(tenantId, request);
        log.info("Company created: {} with tenant_id: {}", company.getCompanyName(), tenantId);

        // Step 4: Create Keycloak user with tenant_id attribute
        String keycloakUserId;
        try {
            keycloakUserId = createKeycloakUser(tenantId, company, request);
            log.info("Keycloak user created: {}", keycloakUserId);
        } catch (Exception e) {
            log.error("Keycloak user creation failed for tenant_id: {}", tenantId, e);
            // Mark company as pending Keycloak setup
            company.setStatus("PENDING_KEYCLOAK_SETUP");
            companyRepository.save(company);
            throw new KeycloakIntegrationException("Failed to create Keycloak user", e);
        }

        // Step 5: Send verification email (Keycloak handles this)
        try {
            keycloakAdminService.sendVerifyEmail(keycloakUserId);
            log.info("Verification email sent to: {}", request.getEmail());
        } catch (Exception e) {
            log.warn("Failed to send verification email to: {}", request.getEmail(), e);
            // Don't fail - user can request resend later
        }

        // Step 6: Update company status
        company.setStatus("PENDING_EMAIL_VERIFICATION");
        companyRepository.save(company);

        return SignUpResponse.success(tenantId, keycloakUserId);
    }

    /**
     * Generate unique tenant ID using NanoID
     * Retry if collision detected (extremely rare)
     */
    private String generateUniqueTenantId() {
        int maxRetries = 5;
        for (int i = 0; i < maxRetries; i++) {
            String tenantId = nanoIdGenerator.generateTenantId();
            if (!companyRepository.existsByTenantId(tenantId)) {
                return tenantId;
            }
            log.warn("Tenant ID collision detected, retrying... (attempt {})", i + 1);
        }
        throw new RuntimeException("Failed to generate unique tenant ID after " + maxRetries + " attempts");
    }

    /**
     * Create company_master record
     */
    private CompanyMaster createCompany(String tenantId, SignUpRequest request) {
        CompanyMaster company = CompanyMaster.builder()
            .tenantId(tenantId)
            .companyName(request.getCompanyName())
            .email(request.getEmail())
            .phone(request.getPhone())
            .status("PENDING_ACTIVATION")
            .subscriptionPlan("FREE")
            .createdBy(request.getEmail())
            .build();

        return companyRepository.save(company);
    }

    /**
     * Create Keycloak user with tenant_id attribute
     */
    private String createKeycloakUser(
        String tenantId,
        CompanyMaster company,
        SignUpRequest request
    ) {
        return keycloakAdminService.createUser(
            request.getEmail(),
            request.getPassword(),
            request.getFirstName(),
            request.getLastName(),
            tenantId,
            "company_admin",  // First user is always company admin
            company.getCompanyName()
        );
    }

    /**
     * Resend verification email
     */
    public void resendVerificationEmail(String email) {
        CompanyMaster company = companyRepository.findByEmail(email)
            .orElseThrow(() -> new RuntimeException("Email not found: " + email));

        // Get Keycloak user ID from email
        String keycloakUserId = keycloakAdminService.findUserByEmail(email);

        // Resend verification email
        keycloakAdminService.sendVerifyEmail(keycloakUserId);
    }

    /**
     * Check if email exists in PostgreSQL
     */
    public boolean emailExists(String email) {
        return companyRepository.existsByEmail(email);
    }

    /**
     * Check if company name exists (case-insensitive)
     */
    public boolean companyNameExists(String companyName) {
        return companyRepository.existsByCompanyNameIgnoreCase(companyName);
    }
}
