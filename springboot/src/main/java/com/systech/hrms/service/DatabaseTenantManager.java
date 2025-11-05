package com.systech.hrms.service;

import com.systech.hrms.exception.TenantNotFoundException;
import com.systech.hrms.security.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * DatabaseTenantManager - Manages PostgreSQL session variables for Row-Level Security (RLS)
 *
 * This service sets the PostgreSQL session variable 'app.current_tenant_id'
 * which is used by Row-Level Security policies to filter data by tenant.
 *
 * Flow:
 * 1. TenantFilter extracts tenant_id from JWT → sets ThreadLocal
 * 2. Service calls setTenantSession() → sets PostgreSQL session variable
 * 3. RLS policies automatically filter queries using session variable
 * 4. All queries return only data for current tenant
 *
 * PostgreSQL RLS Policy Example:
 * ```sql
 * CREATE POLICY employee_tenant_isolation ON employee
 *   USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
 * ```
 *
 * Usage in Services:
 * ```java
 * @Service
 * public class EmployeeService {
 *     @Autowired
 *     private DatabaseTenantManager dbTenantManager;
 *
 *     public List<Employee> getAllEmployees() {
 *         // Set database session for current tenant
 *         dbTenantManager.setTenantSession();
 *
 *         // Now all queries are automatically filtered by RLS
 *         return employeeRepository.findAll();
 *     }
 * }
 * ```
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DatabaseTenantManager {

    private final JdbcTemplate jdbcTemplate;

    /**
     * Set PostgreSQL session variable for current tenant from TenantContext
     *
     * This method retrieves the tenant_id from ThreadLocal (TenantContext)
     * and sets it as a PostgreSQL session variable for RLS filtering.
     *
     * @throws TenantNotFoundException if tenant context is not set
     */
    public void setTenantSession() {
        String tenantId = TenantContext.getCurrentTenant();

        if (tenantId == null || tenantId.isEmpty()) {
            throw new TenantNotFoundException(
                "Tenant context not set. Cannot execute database operations without tenant context."
            );
        }

        setTenantSession(tenantId);
    }

    /**
     * Set PostgreSQL session variable for specific tenant
     *
     * Sets the 'app.current_tenant_id' session variable which is used by
     * PostgreSQL Row-Level Security policies to filter data.
     *
     * The third parameter (false) means this setting is local to the current
     * transaction/connection and won't persist beyond it.
     *
     * @param tenantId the tenant ID to set (12-char NanoID)
     * @throws TenantNotFoundException if tenantId is null or empty
     * @throws RuntimeException if database operation fails
     */
    public void setTenantSession(String tenantId) {
        if (tenantId == null || tenantId.isEmpty()) {
            throw new TenantNotFoundException("Tenant ID cannot be null or empty");
        }

        try {
            // Set PostgreSQL session variable for RLS
            // Syntax: set_config(setting_name, new_value, is_local)
            // is_local = false means setting applies only to current transaction
            String sql = "SELECT set_config('app.current_tenant_id', ?, false)";
            jdbcTemplate.queryForObject(sql, String.class, tenantId);

            log.debug("PostgreSQL session variable set: app.current_tenant_id = {}", tenantId);

        } catch (Exception e) {
            log.error("Failed to set PostgreSQL session variable for tenant: {}", tenantId, e);
            throw new RuntimeException(
                "Failed to set tenant context in database: " + e.getMessage(), e
            );
        }
    }

    /**
     * Get current tenant ID from PostgreSQL session variable
     *
     * Retrieves the value of 'app.current_tenant_id' from the current database session.
     * Useful for debugging and validation.
     *
     * The second parameter (true) means return NULL if setting doesn't exist
     * instead of throwing an error.
     *
     * @return current tenant ID from database session, or null if not set
     */
    public String getCurrentTenantSession() {
        try {
            // Get current setting, return null if not set (true parameter)
            String sql = "SELECT current_setting('app.current_tenant_id', true)";
            return jdbcTemplate.queryForObject(sql, String.class);

        } catch (Exception e) {
            log.debug("Failed to get tenant session variable (might not be set yet): {}",
                e.getMessage());
            return null;
        }
    }

    /**
     * Clear PostgreSQL session variable (for testing/cleanup)
     *
     * Removes the 'app.current_tenant_id' session variable.
     * Generally not needed as session variables are transaction-scoped,
     * but useful for testing.
     */
    public void clearTenantSession() {
        try {
            String sql = "SELECT set_config('app.current_tenant_id', NULL, false)";
            jdbcTemplate.queryForObject(sql, String.class);

            log.debug("PostgreSQL session variable cleared");

        } catch (Exception e) {
            log.warn("Failed to clear tenant session variable: {}", e.getMessage());
        }
    }

    /**
     * Validate that tenant session matches current tenant context
     *
     * Ensures database session variable matches ThreadLocal tenant context.
     * Useful for debugging multi-tenant issues.
     *
     * @return true if session and context match, false otherwise
     */
    public boolean validateTenantSession() {
        String contextTenant = TenantContext.getCurrentTenant();
        String sessionTenant = getCurrentTenantSession();

        boolean matches = contextTenant != null && contextTenant.equals(sessionTenant);

        if (!matches) {
            log.warn("Tenant context mismatch! Context: {}, Session: {}",
                contextTenant, sessionTenant);
        }

        return matches;
    }
}
