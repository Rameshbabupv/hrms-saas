/**
 * Customer Sign-Up Component
 *
 * New customer registration form with:
 * - Email, password, company name validation
 * - Real-time password strength indicator
 * - Email verification required after signup
 */

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  validatePasswordStrength,
  validateEmail,
  validateCompanyName,
  getPasswordStrengthColor,
  getPasswordStrengthLabel,
} from '../../utils/passwordValidator';
import { signupService } from '../../services/signup.service';
import type { SignUpRequest } from '../../types/signup.types';

export const SignUp: React.FC = () => {
  const navigate = useNavigate();

  // Form state
  const [formData, setFormData] = useState<SignUpRequest>({
    email: '',
    password: '',
    companyName: '',
    firstName: '',
    lastName: '',
    phone: '',
  });

  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Validation state
  const [touched, setTouched] = useState({
    email: false,
    password: false,
    confirmPassword: false,
    companyName: false,
    firstName: false,
    lastName: false,
  });

  // Real-time validation
  const emailValidation = validateEmail(formData.email);
  const passwordStrength = validatePasswordStrength(formData.password);
  const companyValidation = validateCompanyName(formData.companyName);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleBlur = (field: keyof typeof touched) => {
    setTouched(prev => ({ ...prev, [field]: true }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    // Mark all fields as touched
    setTouched({
      email: true,
      password: true,
      confirmPassword: true,
      companyName: true,
      firstName: true,
      lastName: true,
    });

    // Validate all fields
    if (!emailValidation.valid) {
      setError(emailValidation.message || 'Invalid email');
      return;
    }

    if (!passwordStrength.isStrong) {
      setError('Password does not meet security requirements');
      return;
    }

    if (formData.password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (!companyValidation.valid) {
      setError(companyValidation.message || 'Invalid company name');
      return;
    }

    if (!formData.firstName.trim() || !formData.lastName.trim()) {
      setError('First name and last name are required');
      return;
    }

    try {
      setLoading(true);

      // Call backend API to create customer account
      const response = await signupService.createCustomer(formData);

      console.log('Sign-up successful:', response);

      // Navigate to email verification page
      if (response.requiresEmailVerification) {
        navigate('/email-verification', {
          state: {
            email: formData.email,
            tenantId: response.tenantId,
            userId: response.userId
          }
        });
      } else {
        // If email verification is not required, redirect to login
        navigate('/', { state: { message: 'Account created successfully. Please sign in.' } });
      }
    } catch (err: any) {
      setError(err.message || 'Sign-up failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        {/* Header */}
        <div style={styles.header}>
          <h1 style={styles.title}>Create Your HRMS Account</h1>
          <p style={styles.subtitle}>Start managing your HR operations today</p>
        </div>

        {/* Error message */}
        {error && (
          <div style={styles.errorMessage}>
            ⚠️ {error}
          </div>
        )}

        {/* Sign-up form */}
        <form onSubmit={handleSubmit} style={styles.form}>
          {/* Company Name */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Company Name *</label>
            <input
              type="text"
              name="companyName"
              value={formData.companyName}
              onChange={handleChange}
              onBlur={() => handleBlur('companyName')}
              style={styles.input}
              placeholder="Acme Corporation"
              required
            />
            {touched.companyName && companyValidation.message && (
              <div style={companyValidation.valid ? styles.infoMessage : styles.validationError}>
                {companyValidation.message}
              </div>
            )}
          </div>

          {/* Name fields */}
          <div style={styles.nameGroup}>
            <div style={styles.formGroup}>
              <label style={styles.label}>First Name *</label>
              <input
                type="text"
                name="firstName"
                value={formData.firstName}
                onChange={handleChange}
                onBlur={() => handleBlur('firstName')}
                style={styles.input}
                placeholder="John"
                required
              />
            </div>

            <div style={styles.formGroup}>
              <label style={styles.label}>Last Name *</label>
              <input
                type="text"
                name="lastName"
                value={formData.lastName}
                onChange={handleChange}
                onBlur={() => handleBlur('lastName')}
                style={styles.input}
                placeholder="Doe"
                required
              />
            </div>
          </div>

          {/* Email */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Email Address *</label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              onBlur={() => handleBlur('email')}
              style={styles.input}
              placeholder="john.doe@company.com"
              required
            />
            {touched.email && emailValidation.message && (
              <div style={emailValidation.valid ? styles.infoMessage : styles.validationError}>
                {emailValidation.message}
              </div>
            )}
          </div>

          {/* Phone (optional) */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Phone Number (Optional)</label>
            <input
              type="tel"
              name="phone"
              value={formData.phone}
              onChange={handleChange}
              style={styles.input}
              placeholder="+1 (555) 123-4567"
            />
          </div>

          {/* Password */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Password *</label>
            <input
              type="password"
              name="password"
              value={formData.password}
              onChange={handleChange}
              onBlur={() => handleBlur('password')}
              style={styles.input}
              placeholder="Create a strong password"
              required
            />

            {/* Password strength indicator */}
            {formData.password && (
              <div style={styles.passwordStrength}>
                <div style={styles.strengthBar}>
                  <div
                    style={{
                      ...styles.strengthBarFill,
                      width: `${(passwordStrength.score / 6) * 100}%`,
                      backgroundColor: getPasswordStrengthColor(passwordStrength.score),
                    }}
                  />
                </div>
                <div style={styles.strengthLabel}>
                  <span style={{ color: getPasswordStrengthColor(passwordStrength.score) }}>
                    {getPasswordStrengthLabel(passwordStrength.score)}
                  </span>
                </div>
              </div>
            )}

            {/* Password feedback */}
            {touched.password && passwordStrength.feedback.length > 0 && (
              <ul style={styles.feedbackList}>
                {passwordStrength.feedback.map((msg, idx) => (
                  <li key={idx} style={styles.feedbackItem}>
                    {msg}
                  </li>
                ))}
              </ul>
            )}
          </div>

          {/* Confirm Password */}
          <div style={styles.formGroup}>
            <label style={styles.label}>Confirm Password *</label>
            <input
              type="password"
              name="confirmPassword"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              onBlur={() => handleBlur('confirmPassword')}
              style={styles.input}
              placeholder="Re-enter your password"
              required
            />
            {touched.confirmPassword && confirmPassword && formData.password !== confirmPassword && (
              <div style={styles.validationError}>
                Passwords do not match
              </div>
            )}
          </div>

          {/* Terms and conditions */}
          <div style={styles.termsContainer}>
            <p style={styles.termsText}>
              By signing up, you agree to our{' '}
              <a href="/terms" style={styles.link}>Terms of Service</a> and{' '}
              <a href="/privacy" style={styles.link}>Privacy Policy</a>
            </p>
          </div>

          {/* Submit button */}
          <button
            type="submit"
            disabled={loading}
            style={{
              ...styles.submitButton,
              ...(loading ? styles.submitButtonDisabled : {}),
            }}
          >
            {loading ? 'Creating Account...' : 'Create Account'}
          </button>
        </form>

        {/* Footer */}
        <div style={styles.footer}>
          <p style={styles.footerText}>
            Already have an account?{' '}
            <a
              href="/"
              onClick={(e) => {
                e.preventDefault();
                navigate('/');
              }}
              style={styles.link}
            >
              Sign In
            </a>
          </p>
        </div>
      </div>
    </div>
  );
};

// Styles
const styles: { [key: string]: React.CSSProperties } = {
  container: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    padding: '20px',
  },
  card: {
    background: 'white',
    borderRadius: '16px',
    padding: '40px',
    maxWidth: '600px',
    width: '100%',
    boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
  },
  title: {
    margin: '0 0 8px 0',
    fontSize: '32px',
    color: '#333',
  },
  subtitle: {
    margin: 0,
    fontSize: '16px',
    color: '#666',
  },
  errorMessage: {
    background: '#fee',
    color: '#c00',
    padding: '12px',
    borderRadius: '8px',
    marginBottom: '16px',
    border: '1px solid #fcc',
    fontSize: '14px',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '20px',
  },
  formGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  nameGroup: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '16px',
  },
  label: {
    fontSize: '14px',
    fontWeight: '600',
    color: '#333',
  },
  input: {
    padding: '12px',
    fontSize: '16px',
    border: '1px solid #ddd',
    borderRadius: '8px',
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  validationError: {
    fontSize: '13px',
    color: '#d32f2f',
  },
  infoMessage: {
    fontSize: '13px',
    color: '#f57c00',
  },
  passwordStrength: {
    marginTop: '8px',
  },
  strengthBar: {
    height: '6px',
    background: '#e0e0e0',
    borderRadius: '3px',
    overflow: 'hidden',
  },
  strengthBarFill: {
    height: '100%',
    transition: 'width 0.3s, background-color 0.3s',
  },
  strengthLabel: {
    marginTop: '4px',
    fontSize: '13px',
    fontWeight: '600',
  },
  feedbackList: {
    margin: '8px 0 0 0',
    padding: '0 0 0 20px',
    fontSize: '13px',
    color: '#666',
  },
  feedbackItem: {
    marginBottom: '4px',
  },
  termsContainer: {
    marginTop: '8px',
  },
  termsText: {
    fontSize: '13px',
    color: '#666',
    textAlign: 'center',
    margin: 0,
  },
  link: {
    color: '#667eea',
    textDecoration: 'none',
    fontWeight: '600',
  },
  submitButton: {
    padding: '14px',
    fontSize: '16px',
    fontWeight: '600',
    color: 'white',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'transform 0.2s',
    marginTop: '8px',
  },
  submitButtonDisabled: {
    opacity: 0.6,
    cursor: 'not-allowed',
  },
  footer: {
    marginTop: '24px',
    textAlign: 'center',
  },
  footerText: {
    fontSize: '14px',
    color: '#666',
    margin: 0,
  },
};
