package com.systech.hrms.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

/**
 * DomainMaster Entity - Email Domain Registry
 *
 * Manages email domains for multi-tenant isolation:
 * - Public domains (gmail.com, yahoo.com) → Multiple tenants allowed
 * - Corporate domains (systech.com) → Locked to single tenant
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Entity
@Table(name = "domain_master", indexes = {
    @Index(name = "idx_domain_public", columnList = "is_public"),
    @Index(name = "idx_domain_locked", columnList = "is_locked"),
    @Index(name = "idx_domain_tenant", columnList = "registered_tenant_id")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DomainMaster {

    /**
     * Domain name (Primary Key)
     * Example: systech.com, gmail.com
     * Always stored in lowercase
     */
    @Id
    @Column(name = "domain", length = 255, nullable = false)
    @NotBlank(message = "Domain is required")
    @Pattern(regexp = "^[a-z0-9.-]+\\.[a-z]{2,}$", message = "Invalid domain format")
    private String domain;

    /**
     * Is this a public email domain?
     * true = gmail.com, yahoo.com (multiple tenants allowed)
     * false = corporate domain (single tenant)
     */
    @Column(name = "is_public", nullable = false)
    @Builder.Default
    private Boolean isPublic = false;

    /**
     * Is this domain locked to a tenant?
     * true = Domain reserved for registered_tenant_id
     * false = Available for registration or public
     */
    @Column(name = "is_locked", nullable = false)
    @Builder.Default
    private Boolean isLocked = false;

    /**
     * Tenant ID that owns this domain (for locked domains)
     * NULL for public domains
     */
    @Column(name = "registered_tenant_id", length = 21)
    private String registeredTenantId;

    /**
     * Created Timestamp
     */
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * Last Updated Timestamp
     */
    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /**
     * Check if domain is available for new tenant registration
     */
    public boolean isAvailableForRegistration() {
        return isPublic || (!isLocked && registeredTenantId == null);
    }

    /**
     * Check if domain is locked to a specific tenant
     */
    public boolean isLockedToTenant(String tenantId) {
        return isLocked && tenantId != null && tenantId.equals(registeredTenantId);
    }

    /**
     * Lock domain to a tenant (corporate domain registration)
     */
    public void lockToTenant(String tenantId) {
        if (isPublic) {
            throw new IllegalStateException("Cannot lock public domain: " + domain);
        }
        this.isLocked = true;
        this.registeredTenantId = tenantId;
    }

    /**
     * Unlock domain (release from tenant)
     */
    public void unlock() {
        this.isLocked = false;
        this.registeredTenantId = null;
    }
}
