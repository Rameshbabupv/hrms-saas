package com.systech.hrms.config;

import com.systech.hrms.filter.TenantFilter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * FilterConfig - Configure and register custom filters
 *
 * Registers the TenantFilter to extract tenant_id from JWT tokens.
 *
 * Filter Order:
 * - Order 1: Spring Security Filter (validates JWT)
 * - Order 2: TenantFilter (extracts tenant_id) ← This filter
 * - Order 3+: Other filters
 *
 * The TenantFilter MUST run AFTER Spring Security has validated the JWT,
 * otherwise the JWT principal won't be available in SecurityContext.
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@Configuration
public class FilterConfig {

    /**
     * Register TenantFilter with order 2 (after SecurityFilter)
     *
     * @param tenantFilter the TenantFilter component
     * @return FilterRegistrationBean configuration
     */
    @Bean
    public FilterRegistrationBean<TenantFilter> tenantFilterRegistration(TenantFilter tenantFilter) {
        log.info("Registering TenantFilter with order 2 (after SecurityFilter)");

        FilterRegistrationBean<TenantFilter> registration = new FilterRegistrationBean<>(tenantFilter);

        // Set order to 2 (SecurityFilter is typically order 1)
        // This ensures JWT is validated before we try to extract tenant_id
        registration.setOrder(2);

        // Apply to all URL patterns
        registration.addUrlPatterns("/*");

        registration.setName("tenantFilter");

        log.info("TenantFilter registered successfully");

        return registration;
    }
}
