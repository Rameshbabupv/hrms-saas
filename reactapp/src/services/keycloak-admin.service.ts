/**
 * Keycloak Admin API Service for HRMS SaaS
 *
 * Handles user provisioning via Keycloak Admin API with tenant_id support
 *
 * IMPORTANT: This should be called from Backend API, not directly from frontend
 * for security reasons. Frontend should call backend API which then calls Keycloak Admin API.
 *
 * Based on: KEYCLOAK_IMPLEMENTATION_GUIDE.md Section 9 & 11
 */

import axios, { AxiosInstance } from 'axios';
import type {
  UserRegistrationRequest,
  KeycloakUserCreationResponse,
} from '../types/auth.types';

interface KeycloakAdminConfig {
  baseUrl: string;
  realm: string;
  adminUsername: string;
  adminPassword: string;
  clientId: string;
}

/**
 * Keycloak Admin API Client
 *
 * NOTE: In production, this logic should be in the BACKEND (Spring Boot),
 * not in the frontend. The frontend should call backend API endpoints
 * like /api/users/create which then calls Keycloak Admin API.
 */
export class KeycloakAdminService {
  private config: KeycloakAdminConfig;
  private httpClient: AxiosInstance;
  private accessToken: string | null = null;

  constructor(config?: Partial<KeycloakAdminConfig>) {
    this.config = {
      baseUrl: config?.baseUrl || process.env.REACT_APP_KEYCLOAK_ADMIN_URL || 'http://localhost:8090',
      realm: config?.realm || process.env.REACT_APP_KEYCLOAK_REALM || 'hrms-saas',
      adminUsername: config?.adminUsername || '',
      adminPassword: config?.adminPassword || '',
      clientId: config?.clientId || 'admin-cli',
    };

    this.httpClient = axios.create({
      baseURL: this.config.baseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Get admin access token from Keycloak
   * Uses master realm for admin authentication
   */
  private async getAdminToken(): Promise<string> {
    try {
      const response = await axios.post(
        `${this.config.baseUrl}/realms/master/protocol/openid-connect/token`,
        new URLSearchParams({
          grant_type: 'password',
          client_id: this.config.clientId,
          username: this.config.adminUsername,
          password: this.config.adminPassword,
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      this.accessToken = response.data.access_token;
      return this.accessToken!;
    } catch (error) {
      console.error('Failed to get admin token:', error);
      throw new Error('Failed to authenticate with Keycloak Admin API');
    }
  }

  /**
   * Ensure we have a valid admin token
   */
  private async ensureAuthenticated(): Promise<void> {
    if (!this.accessToken) {
      await this.getAdminToken();
    }
  }

  /**
   * Create a new user in Keycloak with tenant_id
   *
   * CRITICAL: The tenant_id (company_id) MUST be set correctly
   * for Row-Level Security to work in the database.
   *
   * Flow:
   * 1. Backend creates company record in PostgreSQL (gets company_id)
   * 2. Backend calls this method to create user in Keycloak with company_id
   * 3. Keycloak includes company_id in JWT token
   * 4. Backend extracts company_id from JWT and sets RLS context
   *
   * @param request User registration data with tenant_id
   * @returns Created user ID and location
   */
  async createUser(
    request: UserRegistrationRequest
  ): Promise<KeycloakUserCreationResponse> {
    await this.ensureAuthenticated();

    try {
      // Prepare user payload for Keycloak Admin API
      const userPayload = {
        username: request.username,
        email: request.email,
        firstName: request.firstName,
        lastName: request.lastName,
        enabled: request.enabled,
        emailVerified: request.emailVerified,

        // CRITICAL: Set tenant context as user attributes
        // These will be included in JWT token via client mappers
        attributes: {
          company_id: [request.companyId],      // UUID from database
          tenant_id: [request.companyId],        // Same as company_id
          employee_id: request.employeeId ? [request.employeeId] : [],
          user_type: [request.userType],
          phone: request.phone ? [request.phone] : [],
        },

        // Set temporary password
        credentials: [
          {
            type: 'password',
            value: request.password,
            temporary: request.temporary,
          },
        ],

        // Assign realm roles
        realmRoles: request.realmRoles || [request.userType],

        // Required actions (email verification, password update)
        requiredActions: request.requiredActions || ['VERIFY_EMAIL', 'UPDATE_PASSWORD'],
      };

      console.log('📝 Creating user in Keycloak:', {
        username: request.username,
        email: request.email,
        companyId: request.companyId,
        userType: request.userType,
      });

      // Create user via Admin API
      const response = await this.httpClient.post(
        `/admin/realms/${this.config.realm}/users`,
        userPayload,
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
        }
      );

      // Extract user ID from Location header
      const location = response.headers.location;
      const userId = location?.split('/').pop() || '';

      console.log('✅ User created in Keycloak:', { userId, location });

      return {
        userId,
        location,
      };
    } catch (error: any) {
      console.error('❌ Failed to create user in Keycloak:', error.response?.data || error);
      throw new Error(
        `Failed to create user: ${error.response?.data?.errorMessage || error.message}`
      );
    }
  }

  /**
   * Send email verification link to user
   */
  async sendVerificationEmail(userId: string): Promise<void> {
    await this.ensureAuthenticated();

    try {
      await this.httpClient.put(
        `/admin/realms/${this.config.realm}/users/${userId}/send-verify-email`,
        {},
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
        }
      );

      console.log('✅ Verification email sent to user:', userId);
    } catch (error: any) {
      console.error('❌ Failed to send verification email:', error.response?.data || error);
      throw new Error('Failed to send verification email');
    }
  }

  /**
   * Reset user password
   */
  async resetPassword(
    userId: string,
    newPassword: string,
    temporary: boolean = true
  ): Promise<void> {
    await this.ensureAuthenticated();

    try {
      await this.httpClient.put(
        `/admin/realms/${this.config.realm}/users/${userId}/reset-password`,
        {
          type: 'password',
          value: newPassword,
          temporary,
        },
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
        }
      );

      console.log('✅ Password reset for user:', userId);
    } catch (error: any) {
      console.error('❌ Failed to reset password:', error.response?.data || error);
      throw new Error('Failed to reset password');
    }
  }

  /**
   * Disable/Enable user
   */
  async setUserEnabled(userId: string, enabled: boolean): Promise<void> {
    await this.ensureAuthenticated();

    try {
      await this.httpClient.put(
        `/admin/realms/${this.config.realm}/users/${userId}`,
        { enabled },
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
        }
      );

      console.log(`✅ User ${enabled ? 'enabled' : 'disabled'}:`, userId);
    } catch (error: any) {
      console.error('❌ Failed to update user status:', error.response?.data || error);
      throw new Error('Failed to update user status');
    }
  }

  /**
   * Logout user (revoke all sessions)
   */
  async logoutUser(userId: string): Promise<void> {
    await this.ensureAuthenticated();

    try {
      await this.httpClient.post(
        `/admin/realms/${this.config.realm}/users/${userId}/logout`,
        {},
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
        }
      );

      console.log('✅ User logged out (sessions revoked):', userId);
    } catch (error: any) {
      console.error('❌ Failed to logout user:', error.response?.data || error);
      throw new Error('Failed to logout user');
    }
  }

  /**
   * Get user by ID
   */
  async getUser(userId: string): Promise<any> {
    await this.ensureAuthenticated();

    try {
      const response = await this.httpClient.get(
        `/admin/realms/${this.config.realm}/users/${userId}`,
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
        }
      );

      return response.data;
    } catch (error: any) {
      console.error('❌ Failed to get user:', error.response?.data || error);
      throw new Error('Failed to get user');
    }
  }

  /**
   * Search users by attribute (e.g., company_id)
   */
  async searchUsersByAttribute(
    attribute: string,
    value: string
  ): Promise<any[]> {
    await this.ensureAuthenticated();

    try {
      const response = await this.httpClient.get(
        `/admin/realms/${this.config.realm}/users`,
        {
          params: {
            briefRepresentation: false,
            q: `${attribute}:${value}`,
          },
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
        }
      );

      return response.data;
    } catch (error: any) {
      console.error('❌ Failed to search users:', error.response?.data || error);
      throw new Error('Failed to search users');
    }
  }

  /**
   * Get all users for a company (tenant)
   */
  async getUsersByCompanyId(companyId: string): Promise<any[]> {
    return this.searchUsersByAttribute('company_id', companyId);
  }
}

// Export singleton instance
// NOTE: In production, remove admin credentials from frontend
export const keycloakAdminService = new KeycloakAdminService();
