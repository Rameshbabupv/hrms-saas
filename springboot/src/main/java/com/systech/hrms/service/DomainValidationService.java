package com.systech.hrms.service;

import com.systech.hrms.entity.DomainMaster;
import com.systech.hrms.repository.DomainMasterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * DomainValidationService - Domain validation and registration logic
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DomainValidationService {

    private final DomainMasterRepository domainRepository;

    /**
     * Extract domain from email address
     */
    public String extractDomainFromEmail(String email) {
        if (email == null || !email.contains("@")) {
            throw new IllegalArgumentException("Invalid email format");
        }
        return email.substring(email.indexOf("@") + 1).toLowerCase();
    }

    /**
     * Check if domain is public (gmail, yahoo, etc.)
     */
    public boolean isPublicDomain(String domain) {
        return domainRepository.isPublicDomain(domain.toLowerCase()).orElse(false);
    }

    /**
     * Check if domain is available for new company registration
     *
     * Returns true if:
     * - Domain is public (gmail, yahoo) → Multiple companies allowed
     * - Domain doesn't exist yet → New corporate domain
     * - Domain exists but not locked → Available
     *
     * Returns false if:
     * - Domain is locked to another tenant
     */
    public boolean isDomainAvailableForRegistration(String domain) {
        String lowerDomain = domain.toLowerCase();

        return domainRepository.findByDomainIgnoreCase(lowerDomain)
            .map(DomainMaster::isAvailableForRegistration)
            .orElse(true); // Domain doesn't exist → available
    }

    /**
     * Validate domain for new company signup
     *
     * @throws IllegalArgumentException if domain is locked to another tenant
     */
    @Transactional
    public void validateAndRegisterDomain(String domain, String tenantId) {
        String lowerDomain = domain.toLowerCase();
        log.info("Validating domain: {} for tenant: {}", lowerDomain, tenantId);

        DomainMaster domainMaster = domainRepository.findByDomainIgnoreCase(lowerDomain)
            .orElse(null);

        if (domainMaster == null) {
            // New corporate domain - register and lock it
            log.info("Registering new corporate domain: {}", lowerDomain);
            domainMaster = DomainMaster.builder()
                .domain(lowerDomain)
                .isPublic(false)
                .isLocked(true)
                .registeredTenantId(tenantId)
                .build();
            domainRepository.save(domainMaster);
            return;
        }

        // Domain exists - check if available
        if (domainMaster.getIsPublic()) {
            // Public domain (gmail, yahoo) - allow
            log.info("Using public domain: {}", lowerDomain);
            return;
        }

        if (domainMaster.getIsLocked() && !tenantId.equals(domainMaster.getRegisteredTenantId())) {
            // Corporate domain locked to another tenant
            log.warn("Domain {} is locked to another tenant", lowerDomain);
            throw new IllegalArgumentException(
                "Domain " + lowerDomain + " is already registered to another company"
            );
        }

        // Corporate domain available - lock it to this tenant
        if (!domainMaster.getIsLocked()) {
            log.info("Locking domain {} to tenant {}", lowerDomain, tenantId);
            domainMaster.lockToTenant(tenantId);
            domainRepository.save(domainMaster);
        }
    }

    /**
     * Release domain from tenant (when company is deleted or trial expires)
     */
    @Transactional
    public void releaseDomain(String domain) {
        String lowerDomain = domain.toLowerCase();
        log.info("Releasing domain: {}", lowerDomain);

        domainRepository.findByDomainIgnoreCase(lowerDomain).ifPresent(domainMaster -> {
            if (!domainMaster.getIsPublic()) {
                domainMaster.unlock();
                domainRepository.save(domainMaster);
                log.info("Domain {} released", lowerDomain);
            }
        });
    }

    /**
     * Check if email domain is valid for tenant
     * (Used for adding new portal users to existing company)
     */
    public boolean isEmailValidForTenant(String email, String tenantId) {
        String domain = extractDomainFromEmail(email);

        return domainRepository.findByDomainIgnoreCase(domain)
            .map(d -> d.getIsPublic() || d.isLockedToTenant(tenantId))
            .orElse(false);
    }
}
