/**
 * Keycloak Authentication Service for HRMS SaaS
 *
 * Handles:
 * - User authentication with Keycloak
 * - JWT token management
 * - Tenant context extraction from JWT
 * - Row-Level Security (RLS) support
 *
 * Based on: KEYCLOAK_IMPLEMENTATION_GUIDE.md
 */

// @ts-ignore - Keycloak types compatibility
import Keycloak from 'keycloak-js';
import type {
  KeycloakTokenParsed,
  AuthUser,
  AuthResponse,
  TenantContext,
} from '../types/auth.types';

// Keycloak configuration
const keycloakConfig = {
  url: process.env.REACT_APP_KEYCLOAK_URL || 'http://localhost:8090',
  realm: process.env.REACT_APP_KEYCLOAK_REALM || 'hrms-saas',
  clientId: process.env.REACT_APP_KEYCLOAK_CLIENT || 'hrms-web-app',
};

// Initialize Keycloak instance
const keycloak = new Keycloak(keycloakConfig) as any;

/**
 * Keycloak Authentication Service
 */
export class KeycloakAuthService {
  private keycloak: any;
  private initialized = false;

  constructor() {
    this.keycloak = keycloak;
  }

  /**
   * Initialize Keycloak
   * @returns Promise<boolean> - true if authenticated
   */
  async init(): Promise<boolean> {
    if (this.initialized) {
      return this.keycloak.authenticated || false;
    }

    try {
      console.log('🔐 Initializing Keycloak with config:', {
        url: keycloakConfig.url,
        realm: keycloakConfig.realm,
        clientId: keycloakConfig.clientId,
      });

      const authenticated = await this.keycloak.init({
        onLoad: 'check-sso',
        checkLoginIframe: false,
        pkceMethod: 'S256', // Use PKCE for security
        // Handle auth code callback from Keycloak redirect
        // This will automatically exchange the code for tokens
        flow: 'standard',
      });

      this.initialized = true;
      console.log('✅ Keycloak initialized successfully. Authenticated:', authenticated);

      // Set up automatic token refresh
      this.keycloak.onTokenExpired = () => {
        console.log('Token expired, refreshing...');
        this.refreshToken().catch(err => {
          console.error('Failed to refresh token:', err);
          this.logout();
        });
      };

      // Log tenant context on successful authentication
      if (authenticated && this.keycloak.tokenParsed) {
        const tokenParsed = this.keycloak.tokenParsed as KeycloakTokenParsed;
        console.log('🔐 Authenticated with tenant context:', {
          companyId: tokenParsed.company_id,
          tenantId: tokenParsed.tenant_id,
          userType: tokenParsed.user_type,
        });
      }

      return authenticated;
    } catch (error) {
      console.error('❌ Failed to initialize Keycloak:', error);
      console.error('Make sure Keycloak is running at:', keycloakConfig.url);
      console.error('And realm exists:', keycloakConfig.realm);

      // Mark as initialized even on error to prevent infinite loops
      this.initialized = true;
      return false;
    }
  }

  /**
   * Login user - redirects to Keycloak login page
   */
  async login(): Promise<void> {
    if (!this.initialized) {
      console.warn('⚠️ Keycloak not initialized yet, attempting to initialize...');
      try {
        await this.init();
      } catch (error) {
        console.error('❌ Failed to initialize Keycloak before login:', error);
        throw new Error('Keycloak initialization failed. Please check if Keycloak server is running.');
      }
    }

    try {
      console.log('🔑 Redirecting to Keycloak login...');
      await this.keycloak.login({
        redirectUri: window.location.origin,
      });
    } catch (error) {
      console.error('❌ Login failed:', error);
      throw new Error('Login failed. Please check Keycloak configuration.');
    }
  }

  /**
   * Logout user - clears session and redirects
   */
  async logout(): Promise<void> {
    if (!this.initialized) {
      throw new Error('Keycloak not initialized');
    }

    try {
      // Clear local storage
      localStorage.removeItem('tenant_id');
      localStorage.removeItem('company_id');
      localStorage.removeItem('access_token');

      await this.keycloak.logout({
        redirectUri: window.location.origin,
      });
    } catch (error) {
      console.error('Logout failed:', error);
      throw new Error('Logout failed');
    }
  }

  /**
   * Refresh access token
   */
  async refreshToken(): Promise<boolean> {
    if (!this.initialized) {
      throw new Error('Keycloak not initialized');
    }

    try {
      // Refresh if token expires in next 30 seconds
      const refreshed = await this.keycloak.updateToken(30);

      if (refreshed && this.keycloak.token) {
        // Store updated token
        localStorage.setItem('access_token', this.keycloak.token);
        console.log('Token refreshed successfully');
      }

      return refreshed;
    } catch (error) {
      console.error('Token refresh failed:', error);
      throw new Error('Token refresh failed');
    }
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    return this.keycloak.authenticated || false;
  }

  /**
   * Get current access token
   * CRITICAL: This token contains tenant_id for RLS
   */
  getToken(): string | null {
    const token = this.keycloak.token || null;

    // Store in localStorage for API calls
    if (token) {
      localStorage.setItem('access_token', token);
    }

    return token;
  }

  /**
   * Get authenticated user with tenant context
   * Extracts custom claims from JWT token
   */
  getUser(): AuthUser | null {
    if (!this.keycloak.authenticated || !this.keycloak.tokenParsed) {
      return null;
    }

    const token = this.keycloak.tokenParsed as KeycloakTokenParsed;

    // CRITICAL: Validate required tenant claims
    if (!token.company_id || !token.tenant_id) {
      console.error('⚠️ JWT token missing required tenant claims (company_id, tenant_id)');
      throw new Error('Invalid token: Missing tenant context');
    }

    // Store tenant context in localStorage for RLS
    localStorage.setItem('company_id', token.company_id);
    localStorage.setItem('tenant_id', token.tenant_id);

    const user: AuthUser = {
      // Keycloak user ID
      id: token.sub || '',

      // Basic info
      username: token.preferred_username || '',
      email: token.email || '',
      emailVerified: token.email_verified || false,
      firstName: token.given_name || '',
      lastName: token.family_name || '',
      phone: token.phone,

      // CRITICAL: Tenant context for RLS
      companyId: token.company_id,
      tenantId: token.tenant_id,
      employeeId: token.employee_id,

      // User classification
      userType: token.user_type,

      // Company context
      companyCode: token.company_code,
      companyName: token.company_name,

      // Roles and permissions
      roles: token.realm_access?.roles || [],
      groups: token.groups || [],

      // Account status
      enabled: true,
    };

    return user;
  }

  /**
   * Get tenant context
   * CRITICAL: Used to set PostgreSQL session variable for RLS
   */
  getTenantContext(): TenantContext | null {
    const user = this.getUser();
    if (!user) {
      return null;
    }

    return {
      companyId: user.companyId,
      tenantId: user.tenantId,
      companyCode: user.companyCode,
      companyName: user.companyName,
      userType: user.userType,
      // TODO: Determine from company type in database
      isParentCompany: user.userType === 'super_admin',
      canViewSubsidiaries: user.userType === 'super_admin' || user.userType === 'company_admin',
    };
  }

  /**
   * Get full authentication response
   */
  getAuthResponse(): AuthResponse | null {
    const user = this.getUser();
    const tenantContext = this.getTenantContext();

    if (!user || !tenantContext || !this.keycloak.token || !this.keycloak.refreshToken) {
      return null;
    }

    const token = this.keycloak.tokenParsed as KeycloakTokenParsed;

    return {
      accessToken: this.keycloak.token,
      refreshToken: this.keycloak.refreshToken,
      idToken: this.keycloak.idToken || '',
      expiresIn: token?.exp || 0,
      refreshExpiresIn: this.keycloak.refreshTokenParsed?.exp || 0,
      user,
      tenantContext,
    };
  }

  /**
   * Check if user has a specific realm role
   */
  hasRole(role: string): boolean {
    return this.keycloak.hasRealmRole(role);
  }

  /**
   * Check if user has a specific group
   */
  hasGroup(group: string): boolean {
    const token = this.keycloak.tokenParsed as KeycloakTokenParsed;
    if (token && token.groups) {
      return token.groups.includes(`/${group}`) || token.groups.includes(group);
    }
    return false;
  }

  /**
   * Check if user is super admin
   */
  isSuperAdmin(): boolean {
    return this.hasRole('super_admin');
  }

  /**
   * Check if user is company admin
   */
  isCompanyAdmin(): boolean {
    return this.hasRole('company_admin') || this.isSuperAdmin();
  }

  /**
   * Check if user is HR user
   */
  isHRUser(): boolean {
    return this.hasRole('hr_user') || this.isCompanyAdmin();
  }

  /**
   * Get Keycloak instance (for advanced usage)
   */
  getKeycloakInstance(): any {
    return this.keycloak;
  }
}

// Export singleton instance
export const authService = new KeycloakAuthService();

// Export Keycloak instance for direct access if needed
export default keycloak;
