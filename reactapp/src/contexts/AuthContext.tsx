/**
 * Authentication Context for HRMS SaaS
 *
 * Provides:
 * - User authentication state
 * - Tenant context (company_id, tenant_id) for RLS
 * - Role-based access control helpers
 * - Token management
 *
 * Usage:
 * ```tsx
 * const { user, tenantContext, isAuthenticated } = useAuth();
 * console.log('Company ID for RLS:', tenantContext?.companyId);
 * ```
 */

import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { authService } from '../services/keycloak.service';
import type { AuthUser, TenantContext } from '../types/auth.types';

interface AuthContextType {
  // Authentication state
  isAuthenticated: boolean;
  loading: boolean;
  error: string | null;

  // User and tenant information
  user: AuthUser | null;
  tenantContext: TenantContext | null;

  // Tokens
  accessToken: string | null;

  // Actions
  login: () => Promise<void>;
  logout: () => Promise<void>;

  // Role checks
  hasRole: (role: string) => boolean;
  hasGroup: (group: string) => boolean;
  isSuperAdmin: () => boolean;
  isCompanyAdmin: () => boolean;
  isHRUser: () => boolean;

  // Tenant helpers
  getCompanyId: () => string | null;
  getTenantId: () => string | null;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<AuthUser | null>(null);
  const [tenantContext, setTenantContext] = useState<TenantContext | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!initialized) {
      setInitialized(true);
      initializeAuth();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /**
   * Initialize authentication
   */
  const initializeAuth = async () => {
    try {
      setLoading(true);
      setError(null);
      console.log('🔐 Initializing Keycloak authentication...');

      const authenticated = await authService.init();

      if (authenticated) {
        console.log('✅ User authenticated');
        updateAuthState();
      } else {
        console.log('ℹ️ User not authenticated');
      }
    } catch (error: any) {
      console.error('❌ Authentication initialization failed:', error);
      setError(error.message || 'Failed to initialize authentication');
    } finally {
      setLoading(false);
    }
  };

  /**
   * Update authentication state from Keycloak
   */
  const updateAuthState = () => {
    try {
      const currentUser = authService.getUser();
      const currentTenantContext = authService.getTenantContext();
      const token = authService.getToken();

      if (currentUser && currentTenantContext) {
        setUser(currentUser);
        setTenantContext(currentTenantContext);
        setAccessToken(token);
        setIsAuthenticated(true);

        console.log('👤 User:', {
          username: currentUser.username,
          email: currentUser.email,
          userType: currentUser.userType,
        });

        console.log('🏢 Tenant Context (for RLS):', {
          companyId: currentTenantContext.companyId,
          tenantId: currentTenantContext.tenantId,
          companyName: currentTenantContext.companyName,
        });
      } else {
        console.error('⚠️ Failed to extract user or tenant context from token');
        setIsAuthenticated(false);
      }
    } catch (error) {
      console.error('❌ Failed to update auth state:', error);
      setIsAuthenticated(false);
    }
  };

  /**
   * Login user
   */
  const login = async () => {
    try {
      setLoading(true);
      setError(null);
      await authService.login();
      // State will be updated after redirect
    } catch (error: any) {
      console.error('Login failed:', error);
      setError(error.message || 'Login failed');
      throw error;
    } finally {
      setLoading(false);
    }
  };

  /**
   * Logout user
   */
  const logout = async () => {
    try {
      setLoading(true);
      await authService.logout();

      // Clear state
      setIsAuthenticated(false);
      setUser(null);
      setTenantContext(null);
      setAccessToken(null);
    } catch (error) {
      console.error('Logout failed:', error);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  /**
   * Check if user has a specific realm role
   */
  const hasRole = (role: string): boolean => {
    return authService.hasRole(role);
  };

  /**
   * Check if user belongs to a specific group
   */
  const hasGroup = (group: string): boolean => {
    return authService.hasGroup(group);
  };

  /**
   * Check if user is super admin
   */
  const isSuperAdmin = (): boolean => {
    return authService.isSuperAdmin();
  };

  /**
   * Check if user is company admin
   */
  const isCompanyAdmin = (): boolean => {
    return authService.isCompanyAdmin();
  };

  /**
   * Check if user is HR user
   */
  const isHRUser = (): boolean => {
    return authService.isHRUser();
  };

  /**
   * Get company ID (for RLS)
   * CRITICAL: Use this when making API calls that need tenant context
   */
  const getCompanyId = (): string | null => {
    return tenantContext?.companyId || null;
  };

  /**
   * Get tenant ID (for RLS)
   * CRITICAL: Use this when making API calls that need tenant context
   */
  const getTenantId = (): string | null => {
    return tenantContext?.tenantId || null;
  };

  const value: AuthContextType = {
    isAuthenticated,
    loading,
    error,
    user,
    tenantContext,
    accessToken,
    login,
    logout,
    hasRole,
    hasGroup,
    isSuperAdmin,
    isCompanyAdmin,
    isHRUser,
    getCompanyId,
    getTenantId,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

/**
 * Custom hook to use auth context
 * @throws Error if used outside AuthProvider
 */
export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

/**
 * Custom hook to get tenant context
 * Useful for components that only need tenant info
 */
export const useTenant = () => {
  const { tenantContext, getCompanyId, getTenantId } = useAuth();

  return {
    tenantContext,
    companyId: getCompanyId(),
    tenantId: getTenantId(),
    companyName: tenantContext?.companyName,
    companyCode: tenantContext?.companyCode,
    isParentCompany: tenantContext?.isParentCompany || false,
    canViewSubsidiaries: tenantContext?.canViewSubsidiaries || false,
  };
};
