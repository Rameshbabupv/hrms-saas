package com.systech.hrms.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

/**
 * CompanyMaster Entity - Tenant/Company Master Record
 *
 * Represents a tenant (company) in the multi-tenant HRMS system.
 * Each company is identified by a unique NanoID (tenant_id).
 *
 * Hybrid Approach:
 * - tenant_id: NanoID (12 chars) - External identifier for user-facing operations
 * - Used in: JWT tokens, URLs, RLS policies
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Entity
@Table(name = "company_master", indexes = {
    @Index(name = "idx_company_email", columnList = "email"),
    @Index(name = "idx_company_status", columnList = "status")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CompanyMaster {

    /**
     * Tenant ID (Primary Key) - NanoID format
     * Example: a3b9c8d2e1f4
     */
    @Id
    @Column(name = "tenant_id", length = 21, nullable = false)
    @NotBlank(message = "Tenant ID is required")
    private String tenantId;

    /**
     * Company Name
     */
    @Column(name = "company_name", nullable = false)
    @NotBlank(message = "Company name is required")
    @Size(min = 2, max = 255, message = "Company name must be between 2 and 255 characters")
    private String companyName;

    /**
     * Company Code (optional, user-defined)
     */
    @Column(name = "company_code", length = 50)
    private String companyCode;

    /**
     * Primary Email Address (unique across platform)
     */
    @Column(name = "email", nullable = false, unique = true)
    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    /**
     * Contact Phone Number
     */
    @Column(name = "phone", length = 50)
    private String phone;

    /**
     * Company Address
     */
    @Column(name = "address", columnDefinition = "TEXT")
    private String address;

    /**
     * Account Status
     * Values: PENDING_ACTIVATION, PENDING_EMAIL_VERIFICATION, ACTIVE, SUSPENDED, INACTIVE
     */
    @Column(name = "status", length = 30)
    @Builder.Default
    private String status = "PENDING_ACTIVATION";

    /**
     * Subscription Plan
     * Values: FREE, BASIC, PROFESSIONAL, ENTERPRISE
     */
    @Column(name = "subscription_plan", length = 50)
    @Builder.Default
    private String subscriptionPlan = "FREE";

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
     * Created By (email of user who created this record)
     */
    @Column(name = "created_by", length = 100)
    private String createdBy;

    /**
     * Check if company is active
     */
    public boolean isActive() {
        return "ACTIVE".equals(status);
    }

    /**
     * Check if email verification is pending
     */
    public boolean isPendingEmailVerification() {
        return "PENDING_EMAIL_VERIFICATION".equals(status);
    }

    /**
     * Activate company account
     */
    public void activate() {
        this.status = "ACTIVE";
    }

    /**
     * Suspend company account
     */
    public void suspend() {
        this.status = "SUSPENDED";
    }
}
