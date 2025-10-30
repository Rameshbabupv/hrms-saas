/**
 * Sign-Up Types for HRMS SaaS Customer Registration
 */

/**
 * Sign-Up Request (sent to backend)
 */
export interface SignUpRequest {
  email: string;
  password: string;
  companyName: string;
  firstName: string;
  lastName: string;
  phone?: string;
}

/**
 * Sign-Up Response (from backend)
 */
export interface SignUpResponse {
  success: boolean;
  message: string;
  companyId?: string;
  userId?: string;
  email?: string;
  requiresEmailVerification: boolean;
}

/**
 * Password Strength Result
 */
export interface PasswordStrength {
  score: number; // 0-4
  feedback: string[];
  isStrong: boolean;
}

/**
 * Email Verification Status
 */
export interface EmailVerificationStatus {
  verified: boolean;
  message: string;
}
