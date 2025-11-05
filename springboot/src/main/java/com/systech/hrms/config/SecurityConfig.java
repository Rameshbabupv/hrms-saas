package com.systech.hrms.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

/**
 * SecurityConfig - Security configuration for HRMS SaaS
 *
 * Configures:
 * - JWT validation via OAuth2 Resource Server
 * - Public endpoints (signup, health checks)
 * - Protected endpoints (GraphQL, authenticated APIs)
 * - CORS for React frontend
 * - Stateless session management
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            // CORS configuration
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))

            // Disable CSRF (stateless API)
            .csrf(csrf -> csrf.disable())

            // Stateless session (JWT-based)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )

            // Authorization rules
            .authorizeHttpRequests(auth -> auth
                // Public endpoints - no authentication required
                .requestMatchers("/api/v1/auth/signup").permitAll()
                .requestMatchers("/api/v1/auth/verify-email").permitAll()
                .requestMatchers("/api/v1/auth/resend-verification").permitAll()
                .requestMatchers("/api/v1/auth/check-email").permitAll()
                .requestMatchers("/api/v1/auth/check-domain").permitAll()

                // GraphiQL - for development only
                .requestMatchers("/graphiql/**").permitAll()

                // Health checks - for monitoring
                .requestMatchers("/actuator/health").permitAll()

                // All other endpoints require authentication
                .requestMatchers("/graphql").authenticated()
                .requestMatchers("/api/v1/**").authenticated()

                .anyRequest().authenticated()
            )

            // OAuth2 Resource Server (JWT)
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            );

        return http.build();
    }

    /**
     * JWT Authentication Converter - Maps Keycloak roles to Spring Security authorities
     *
     * Extracts roles from JWT token's "realm_access.roles" claim and converts them
     * to Spring Security authorities with "ROLE_" prefix.
     *
     * Example:
     * - JWT claim: "realm_access.roles": ["company_admin", "employee"]
     * - Spring authorities: ["ROLE_company_admin", "ROLE_employee"]
     *
     * This enables @PreAuthorize("hasRole('company_admin')") annotations
     */
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();

        // Configure authorities converter for Keycloak roles
        JwtGrantedAuthoritiesConverter authoritiesConverter = new JwtGrantedAuthoritiesConverter();

        // Extract roles from "realm_access.roles" claim in JWT
        authoritiesConverter.setAuthoritiesClaimName("realm_access.roles");

        // Add "ROLE_" prefix to match Spring Security conventions
        authoritiesConverter.setAuthorityPrefix("ROLE_");

        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);

        return converter;
    }

    /**
     * CORS configuration for React frontend
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // Allow specific origins (React app)
        configuration.setAllowedOrigins(List.of(
            "http://localhost:3000",
            "http://localhost:3001",
            "http://192.168.1.6:3000"
        ));

        // Allow HTTP methods
        configuration.setAllowedMethods(List.of(
            "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"
        ));

        // Allow all headers
        configuration.setAllowedHeaders(List.of("*"));

        // Expose headers
        configuration.setExposedHeaders(List.of("Authorization", "Content-Type"));

        // Allow credentials (cookies, authorization headers)
        configuration.setAllowCredentials(true);

        // Max age for preflight requests
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
