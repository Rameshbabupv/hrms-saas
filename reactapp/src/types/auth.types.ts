/**
 * Authentication and Multi-Tenant Types for HRMS SaaS
 *
 * These types match the JWT token structure from Keycloak
 * as defined in KEYCLOAK_IMPLEMENTATION_GUIDE.md
 */

/**
 * JWT Token Payload from Keycloak
 * Includes standard OIDC claims + custom claims for multi-tenancy
 */
export interface KeycloakTokenParsed {
  // Standard OIDC claims
  exp: number;
  iat: number;
  jti: string;
  iss: string;
  aud: string;
  sub: string;
  typ: string;
  azp: string;
  session_state: string;
  acr: string;
  scope: string;
  sid: string;
  email_verified: boolean;
  preferred_username: string;
  given_name: string;
  family_name: string;
  email: string;

  // Realm roles
  realm_access?: {
    roles: string[];
  };

  // Custom claims for multi-tenancy (configured in Keycloak client mappers)
  company_id: string;      // UUID - Required for RLS
  tenant_id: string;       // UUID - Same as company_id (alias for clarity)
  employee_id?: string;    // UUID - Optional (only for employees)
  user_type: 'super_admin' | 'company_admin' | 'hr_user' | 'manager' | 'employee';
  company_code?: string;   // Optional - Display code (e.g., "DEMO001")
  company_name?: string;   // Optional - Display name (e.g., "Demo Tech Solutions")
  phone?: string;          // Optional - User phone number

  // Groups (if using Keycloak groups)
  groups?: string[];
}

/**
 * Authenticated User Information
 */
export interface AuthUser {
  // Keycloak user ID
  id: string;

  // Basic user info
  username: string;
  email: string;
  emailVerified: boolean;
  firstName: string;
  lastName: string;
  phone?: string;

  // Multi-tenant context (CRITICAL for RLS)
  companyId: string;      // Must be set for Row-Level Security
  tenantId: string;       // Alias for companyId
  employeeId?: string;    // Only for employee users

  // User classification
  userType: 'super_admin' | 'company_admin' | 'hr_user' | 'manager' | 'employee';

  // Company context
  companyCode?: string;
  companyName?: string;

  // Roles and permissions
  roles: string[];
  groups?: string[];

  // Account status
  enabled: boolean;
}

/**
 * Tenant Context
 * Used throughout the app to ensure data isolation
 */
export interface TenantContext {
  companyId: string;
  tenantId: string;
  companyCode?: string;
  companyName?: string;
  userType: string;
  isParentCompany: boolean;
  canViewSubsidiaries: boolean;
}

/**
 * Authentication Response from Keycloak
 */
export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  idToken: string;
  expiresIn: number;
  refreshExpiresIn: number;
  user: AuthUser;
  tenantContext: TenantContext;
}

/**
 * User Registration Request
 * For creating new users via Keycloak Admin API
 */
export interface UserRegistrationRequest {
  // Basic Info
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  phone?: string;

  // Tenant Assignment (CRITICAL)
  companyId: string;
  employeeId?: string;
  userType: 'company_admin' | 'hr_user' | 'manager' | 'employee';

  // Password
  password: string;
  temporary: boolean;

  // Account Status
  enabled: boolean;
  emailVerified: boolean;

  // Required Actions
  requiredActions?: ('VERIFY_EMAIL' | 'UPDATE_PASSWORD' | 'UPDATE_PROFILE')[];

  // Roles
  realmRoles?: string[];
}

/**
 * Keycloak Admin API User Creation Response
 */
export interface KeycloakUserCreationResponse {
  userId: string;
  location: string;
}

/**
 * Company Information (from database)
 */
export interface Company {
  id: string;
  companyCode: string;
  companyName: string;
  companyType: 'HOLDING' | 'SUBSIDIARY' | 'INDEPENDENT';
  parentCompanyId?: string;
  corporateGroupName?: string;
  email: string;
  phone?: string;
  city?: string;
  state?: string;
  country?: string;
  isActive: boolean;
}

/**
 * Employee Information (from database)
 */
export interface Employee {
  id: string;
  companyId: string;
  employeeCode: string;
  employeeName: string;
  email: string;
  mobileNo?: string;
  designation?: string;
  department?: string;
  dateOfJoining: string;
  employmentType: 'PERMANENT' | 'CONTRACT' | 'CONSULTANT' | 'INTERN' | 'TEMPORARY';
  isActive: boolean;
  keycloakUserId?: string;
}
