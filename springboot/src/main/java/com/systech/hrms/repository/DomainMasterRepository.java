package com.systech.hrms.repository;

import com.systech.hrms.entity.DomainMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * DomainMasterRepository - Data access layer for domain_master table
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Repository
public interface DomainMasterRepository extends JpaRepository<DomainMaster, String> {

    /**
     * Find domain by name (case-insensitive)
     */
    @Query("SELECT d FROM DomainMaster d WHERE LOWER(d.domain) = LOWER(:domain)")
    Optional<DomainMaster> findByDomainIgnoreCase(@Param("domain") String domain);

    /**
     * Check if domain exists
     */
    boolean existsByDomain(String domain);

    /**
     * Find all public domains
     */
    List<DomainMaster> findByIsPublicTrue();

    /**
     * Find all locked domains
     */
    List<DomainMaster> findByIsLockedTrue();

    /**
     * Find domains by tenant
     */
    List<DomainMaster> findByRegisteredTenantId(String tenantId);

    /**
     * Check if domain is available for registration
     */
    @Query("SELECT CASE WHEN (d.isPublic = true OR (d.isLocked = false AND d.registeredTenantId IS NULL)) " +
           "THEN true ELSE false END " +
           "FROM DomainMaster d WHERE LOWER(d.domain) = LOWER(:domain)")
    Optional<Boolean> isDomainAvailable(@Param("domain") String domain);

    /**
     * Check if domain is public
     */
    @Query("SELECT d.isPublic FROM DomainMaster d WHERE LOWER(d.domain) = LOWER(:domain)")
    Optional<Boolean> isPublicDomain(@Param("domain") String domain);
}
