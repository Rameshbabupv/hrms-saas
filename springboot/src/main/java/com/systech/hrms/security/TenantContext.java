package com.systech.hrms.security;

/**
 * TenantContext - ThreadLocal storage for current tenant
 *
 * Provides thread-safe storage for the current tenant ID throughout the request lifecycle.
 * Used by filters, services, and repositories to access the current tenant context.
 *
 * Usage:
 * - TenantFilter extracts tenant_id from JWT and sets it here
 * - Services and repositories access it via getCurrentTenant()
 * - Cleared automatically after request completes
 *
 * @author Systech Team
 * @version 1.0.0
 */
public class TenantContext {

    private static final ThreadLocal<String> CURRENT_TENANT = new ThreadLocal<>();

    /**
     * Set the current tenant ID for this thread
     *
     * @param tenantId NanoID tenant identifier (12 chars)
     */
    public static void setCurrentTenant(String tenantId) {
        CURRENT_TENANT.set(tenantId);
    }

    /**
     * Get the current tenant ID for this thread
     *
     * @return tenant ID or null if not set
     */
    public static String getCurrentTenant() {
        return CURRENT_TENANT.get();
    }

    /**
     * Clear the current tenant context
     * Should be called in finally block to prevent memory leaks
     */
    public static void clear() {
        CURRENT_TENANT.remove();
    }

    /**
     * Check if tenant context is set
     *
     * @return true if tenant is set
     */
    public static boolean hasTenant() {
        return CURRENT_TENANT.get() != null;
    }
}
