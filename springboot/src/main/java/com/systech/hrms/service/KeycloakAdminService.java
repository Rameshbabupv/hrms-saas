package com.systech.hrms.service;

import com.systech.hrms.exception.KeycloakIntegrationException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.keycloak.admin.client.Keycloak;
import org.keycloak.admin.client.KeycloakBuilder;
import org.keycloak.admin.client.resource.RealmResource;
import org.keycloak.admin.client.resource.UsersResource;
import org.keycloak.representations.idm.CredentialRepresentation;
import org.keycloak.representations.idm.UserRepresentation;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.ws.rs.core.Response;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * KeycloakAdminService - Keycloak Admin API integration
 *
 * Provides methods to:
 * - Create users in Keycloak
 * - Assign roles to users
 * - Send verification emails
 * - Manage user attributes (tenant_id, user_type)
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@Service
public class KeycloakAdminService {

    @Value("${keycloak.server-url}")
    private String serverUrl;

    @Value("${keycloak.realm}")
    private String realm;

    @Value("${keycloak.admin.username}")
    private String adminUsername;

    @Value("${keycloak.admin.password}")
    private String adminPassword;

    @Value("${keycloak.admin.client-id}")
    private String adminClientId;

    private Keycloak keycloak;
    private RealmResource realmResource;

    /**
     * Initialize Keycloak Admin Client after bean construction
     */
    @PostConstruct
    public void init() {
        log.info("Initializing Keycloak Admin Client for realm: {}", realm);
        try {
            this.keycloak = KeycloakBuilder.builder()
                .serverUrl(serverUrl)
                .realm("master")  // Admin client connects to master realm
                .clientId(adminClientId)
                .username(adminUsername)
                .password(adminPassword)
                .build();

            this.realmResource = keycloak.realm(realm);
            log.info("Keycloak Admin Client initialized successfully");
        } catch (Exception e) {
            log.error("Failed to initialize Keycloak Admin Client", e);
            throw new KeycloakIntegrationException("Failed to initialize Keycloak connection", e);
        }
    }

    /**
     * Create a new user in Keycloak with tenant_id attribute
     *
     * @param email user email (also username)
     * @param password user password
     * @param firstName user first name
     * @param lastName user last name
     * @param tenantId NanoID tenant identifier
     * @param userType user type (company_admin, hr_user, etc.)
     * @param companyName company name
     * @return Keycloak user ID
     */
    public String createUser(
        String email,
        String password,
        String firstName,
        String lastName,
        String tenantId,
        String userType,
        String companyName
    ) {
        log.info("Creating Keycloak user: email={}, tenantId={}", email, tenantId);

        try {
            UsersResource usersResource = realmResource.users();

            // Build user representation
            UserRepresentation user = new UserRepresentation();
            user.setUsername(email);
            user.setEmail(email);
            user.setFirstName(firstName);
            user.setLastName(lastName);
            user.setEnabled(true);  // Enabled - Keycloak handles email verification
            user.setEmailVerified(false);  // Require email verification

            // Set custom attributes for multi-tenancy
            user.setAttributes(Map.of(
                "tenant_id", List.of(tenantId),
                "user_type", List.of(userType),
                "company_name", List.of(companyName)
            ));

            // Set password credential
            CredentialRepresentation credential = new CredentialRepresentation();
            credential.setType(CredentialRepresentation.PASSWORD);
            credential.setValue(password);
            credential.setTemporary(false);
            user.setCredentials(Collections.singletonList(credential));

            // Create user
            Response response = usersResource.create(user);

            if (response.getStatus() == 201) {
                // Extract user ID from Location header
                String locationHeader = response.getHeaderString("Location");
                String userId = locationHeader.substring(locationHeader.lastIndexOf('/') + 1);
                log.info("Keycloak user created successfully: userId={}", userId);

                // Assign default role
                assignRoleToUser(userId, userType);

                return userId;
            } else {
                String errorMessage = response.readEntity(String.class);
                log.error("Failed to create Keycloak user. Status: {}, Error: {}",
                    response.getStatus(), errorMessage);
                throw new KeycloakIntegrationException(
                    "Failed to create user in Keycloak: " + errorMessage
                );
            }

        } catch (Exception e) {
            log.error("Error creating Keycloak user: {}", e.getMessage(), e);
            throw new KeycloakIntegrationException("Failed to create Keycloak user", e);
        }
    }

    /**
     * Assign a role to a user
     *
     * @param userId Keycloak user ID
     * @param roleName role name
     */
    private void assignRoleToUser(String userId, String roleName) {
        try {
            // Note: Role assignment implementation depends on your Keycloak setup
            // This is a simplified version
            log.info("Assigning role {} to user {}", roleName, userId);
            // Implementation would use realmResource.roles() and user roles API
        } catch (Exception e) {
            log.warn("Failed to assign role to user: {}", e.getMessage());
            // Don't fail signup if role assignment fails
        }
    }

    /**
     * Send email verification to user
     *
     * @param userId Keycloak user ID
     */
    public void sendVerifyEmail(String userId) {
        log.info("Sending verification email for user: {}", userId);
        try {
            realmResource.users()
                .get(userId)
                .sendVerifyEmail();
            log.info("Verification email sent successfully");
        } catch (Exception e) {
            log.error("Failed to send verification email: {}", e.getMessage(), e);
            throw new KeycloakIntegrationException("Failed to send verification email", e);
        }
    }

    /**
     * Check if user exists by email
     *
     * @param email user email
     * @return true if user exists in Keycloak
     */
    public boolean userExistsByEmail(String email) {
        log.debug("Checking if Keycloak user exists: {}", email);
        try {
            List<UserRepresentation> users = realmResource.users()
                .search(email, true);
            return !users.isEmpty();
        } catch (Exception e) {
            log.error("Failed to check user existence: {}", e.getMessage(), e);
            return false;
        }
    }

    /**
     * Find user by email
     *
     * @param email user email
     * @return Keycloak user ID
     */
    public String findUserByEmail(String email) {
        log.info("Finding Keycloak user by email: {}", email);
        try {
            List<UserRepresentation> users = realmResource.users()
                .search(email, true);

            if (users.isEmpty()) {
                throw new KeycloakIntegrationException("User not found: " + email);
            }

            return users.get(0).getId();
        } catch (Exception e) {
            log.error("Failed to find user by email: {}", e.getMessage(), e);
            throw new KeycloakIntegrationException("Failed to find user", e);
        }
    }
}
