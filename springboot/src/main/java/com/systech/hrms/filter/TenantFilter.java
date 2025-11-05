package com.systech.hrms.filter;

import com.systech.hrms.security.TenantContext;
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * TenantFilter - Extract tenant_id from JWT and set in ThreadLocal context
 *
 * This filter runs after Spring Security has validated the JWT token.
 * It extracts the tenant_id claim from the JWT and stores it in ThreadLocal
 * for use throughout the request lifecycle.
 *
 * Critical behaviors:
 * - Runs AFTER SecurityFilter (order = 2)
 * - Only processes authenticated requests with valid JWT
 * - ALWAYS clears context after request (prevent memory leaks)
 * - Logs tenant context for debugging
 *
 * Request Flow:
 * 1. Spring Security validates JWT signature
 * 2. TenantFilter extracts tenant_id from validated JWT
 * 3. Sets TenantContext.setCurrentTenant(tenantId)
 * 4. Request proceeds to controller/service
 * 5. Finally block clears context
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@Component
public class TenantFilter implements Filter {

    @Override
    public void doFilter(
        ServletRequest request,
        ServletResponse response,
        FilterChain chain
    ) throws IOException, ServletException {

        HttpServletRequest httpRequest = (HttpServletRequest) request;

        try {
            // Extract tenant_id from JWT token
            Authentication authentication = SecurityContextHolder
                .getContext()
                .getAuthentication();

            if (authentication != null && authentication.getPrincipal() instanceof Jwt) {
                Jwt jwt = (Jwt) authentication.getPrincipal();
                String tenantId = jwt.getClaim("tenant_id");

                if (tenantId != null && !tenantId.isEmpty()) {
                    // Set tenant context for this request
                    TenantContext.setCurrentTenant(tenantId);
                    log.debug("Tenant context set for request: {} - tenantId: {}",
                        httpRequest.getRequestURI(), tenantId);
                } else {
                    log.warn("JWT token missing tenant_id claim for request: {}",
                        httpRequest.getRequestURI());
                }
            } else {
                // No JWT present - likely a public endpoint
                log.debug("No JWT authentication for request: {} (public endpoint)",
                    httpRequest.getRequestURI());
            }

            // Continue the filter chain
            chain.doFilter(request, response);

        } finally {
            // CRITICAL: Always clear tenant context after request
            // This prevents memory leaks in ThreadLocal and ensures
            // no tenant context bleeds into subsequent requests
            String clearedTenant = TenantContext.getCurrentTenant();
            TenantContext.clear();

            if (clearedTenant != null) {
                log.debug("Tenant context cleared: {} for request: {}",
                    clearedTenant, httpRequest.getRequestURI());
            }
        }
    }

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        log.info("TenantFilter initialized - will extract tenant_id from JWT tokens");
    }

    @Override
    public void destroy() {
        log.info("TenantFilter destroyed");
    }
}
