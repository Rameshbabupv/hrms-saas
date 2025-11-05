package com.systech.hrms.repository;

import com.systech.hrms.entity.CompanyMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * CompanyRepository - Data access layer for company_master table
 *
 * Provides CRUD operations and custom queries for company/tenant management.
 *
 * Note: No RLS required on company_master table as it's the tenant root table.
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Repository
public interface CompanyRepository extends JpaRepository<CompanyMaster, String> {

    /**
     * Find company by email address
     *
     * @param email company email
     * @return Optional containing company if found
     */
    Optional<CompanyMaster> findByEmail(String email);

    /**
     * Find company by tenant ID
     *
     * @param tenantId NanoID tenant identifier
     * @return Optional containing company if found
     */
    Optional<CompanyMaster> findByTenantId(String tenantId);

    /**
     * Check if email already exists
     *
     * @param email company email
     * @return true if email exists
     */
    boolean existsByEmail(String email);

    /**
     * Check if tenant ID already exists
     *
     * @param tenantId NanoID tenant identifier
     * @return true if tenant ID exists
     */
    boolean existsByTenantId(String tenantId);

    /**
     * Find all companies by status
     *
     * @param status company status (ACTIVE, SUSPENDED, etc.)
     * @return list of companies with matching status
     */
    List<CompanyMaster> findByStatus(String status);

    /**
     * Find all active companies
     *
     * @return list of active companies
     */
    @Query("SELECT c FROM CompanyMaster c WHERE c.status = 'ACTIVE'")
    List<CompanyMaster> findAllActive();

    /**
     * Find companies by subscription plan
     *
     * @param subscriptionPlan subscription plan name
     * @return list of companies with matching plan
     */
    List<CompanyMaster> findBySubscriptionPlan(String subscriptionPlan);

    /**
     * Count companies by status
     *
     * @param status company status
     * @return count of companies
     */
    long countByStatus(String status);

    /**
     * Search companies by name (case-insensitive)
     *
     * @param name search term
     * @return list of matching companies
     */
    @Query("SELECT c FROM CompanyMaster c WHERE LOWER(c.companyName) LIKE LOWER(CONCAT('%', :name, '%'))")
    List<CompanyMaster> searchByName(@Param("name") String name);

    /**
     * Find company by exact company name (case-insensitive)
     *
     * @param companyName company name
     * @return Optional containing company if found
     */
    @Query("SELECT c FROM CompanyMaster c WHERE LOWER(c.companyName) = LOWER(:companyName)")
    Optional<CompanyMaster> findByCompanyNameIgnoreCase(@Param("companyName") String companyName);

    /**
     * Check if company name already exists (case-insensitive)
     *
     * @param companyName company name
     * @return true if company name exists
     */
    @Query("SELECT COUNT(c) > 0 FROM CompanyMaster c WHERE LOWER(c.companyName) = LOWER(:companyName)")
    boolean existsByCompanyNameIgnoreCase(@Param("companyName") String companyName);
}
