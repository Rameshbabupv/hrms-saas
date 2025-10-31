/**
 * Sign-Up Service
 *
 * Handles customer registration API calls to backend
 * Backend creates:
 * - Company record with unique tenant_id
 * - Keycloak user with company_id attribute
 * - Sends verification email
 */

import axios, { AxiosInstance } from 'axios';
import type { SignUpRequest, SignUpResponse, EmailVerificationStatus } from '../types/signup.types';

/**
 * Sign-Up Service Configuration
 */
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8081';

/**
 * Sign-Up API Service
 */
class SignUpService {
  private httpClient: AxiosInstance;

  constructor() {
    this.httpClient = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 30000, // 30 seconds
    });
  }

  /**
   * Create new customer account
   *
   * Backend process:
   * 1. Validate email uniqueness
   * 2. Generate 12-char NanoID for tenant_id
   * 3. Create company_master record with tenant_id
   * 4. Create Keycloak user with tenant_id attribute
   * 5. Send email verification
   * 6. Return response with tenantId and userId
   *
   * SECURITY: Backend extracts tenant_id from JWT for RLS
   * Client never provides tenant_id
   */
  async createCustomer(request: SignUpRequest): Promise<SignUpResponse> {
    try {
      console.log('📝 Creating customer account:', {
        email: request.email,
        companyName: request.companyName,
        firstName: request.firstName,
        lastName: request.lastName,
      });

      const response = await this.httpClient.post<SignUpResponse>(
        '/api/v1/auth/signup',
        request
      );

      console.log('✅ Customer account created successfully:', {
        tenantId: response.data.tenantId,
        userId: response.data.userId,
        requiresEmailVerification: response.data.requiresEmailVerification,
      });

      // Store tenantId in localStorage for future reference
      if (response.data.tenantId) {
        localStorage.setItem('tenantId', response.data.tenantId);
      }

      return response.data;
    } catch (error: any) {
      console.error('❌ Customer sign-up failed:', error);

      // Extract error message from response
      const errorMessage = error.response?.data?.message
        || error.response?.data?.error
        || error.message
        || 'Sign-up failed. Please try again.';

      // Handle specific error cases
      if (error.response?.status === 409) {
        throw new Error('Email address already exists. Please use a different email or sign in.');
      }

      if (error.response?.status === 400) {
        // Check if it's a validation error with field details
        if (error.response?.data?.fields) {
          const fieldErrors = Object.values(error.response.data.fields).join(', ');
          throw new Error(fieldErrors);
        }
        throw new Error(errorMessage);
      }

      if (error.response?.status === 503) {
        throw new Error('Service temporarily unavailable. Please try again later.');
      }

      throw new Error(errorMessage);
    }
  }

  /**
   * Resend email verification
   *
   * @param email User email address
   */
  async resendVerificationEmail(email: string): Promise<{ success: boolean; message: string }> {
    try {
      console.log('📧 Resending verification email to:', email);

      const response = await this.httpClient.post<{ success: boolean; message: string }>(
        '/api/v1/auth/resend-verification',
        { email }
      );

      console.log('✅ Verification email resent successfully');

      return response.data;
    } catch (error: any) {
      console.error('❌ Failed to resend verification email:', error);

      const errorMessage = error.response?.data?.message
        || error.response?.data?.error
        || error.message
        || 'Failed to resend verification email. Please try again.';

      throw new Error(errorMessage);
    }
  }

  /**
   * Verify email with token
   *
   * @param token Verification token from email link
   */
  async verifyEmail(token: string): Promise<EmailVerificationStatus> {
    try {
      console.log('🔍 Verifying email with token');

      const response = await this.httpClient.get<EmailVerificationStatus>(
        `/api/v1/auth/verify-email?token=${token}`
      );

      console.log('✅ Email verified successfully');

      return response.data;
    } catch (error: any) {
      console.error('❌ Email verification failed:', error);

      const errorMessage = error.response?.data?.message
        || error.response?.data?.error
        || error.message
        || 'Email verification failed. The link may be expired or invalid.';

      throw new Error(errorMessage);
    }
  }

  /**
   * Check if email is available
   *
   * @param email Email to check
   * @returns true if available, false if already exists
   */
  async checkEmailAvailability(email: string): Promise<boolean> {
    try {
      const response = await this.httpClient.get<{ available: boolean }>(
        `/api/v1/auth/check-email?email=${encodeURIComponent(email)}`
      );

      return response.data.available;
    } catch (error: any) {
      console.error('Failed to check email availability:', error);
      // Return true on error to allow user to proceed
      return true;
    }
  }

  /**
   * Check if company name is available
   *
   * @param companyName Company name to check
   * @returns true if available, false if already exists
   */
  async checkCompanyNameAvailability(companyName: string): Promise<boolean> {
    try {
      const response = await this.httpClient.get<{ available: boolean }>(
        `/api/v1/auth/check-company?name=${encodeURIComponent(companyName)}`
      );

      return response.data.available;
    } catch (error: any) {
      console.error('Failed to check company name availability:', error);
      // Return true on error to allow user to proceed
      return true;
    }
  }
}

// Export singleton instance
export const signupService = new SignUpService();

// Export class for testing
export default SignUpService;
