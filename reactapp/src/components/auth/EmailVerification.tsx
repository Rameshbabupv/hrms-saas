/**
 * Email Verification Component
 *
 * Shown after successful sign-up
 * Displays instructions to check email and verify account
 */

import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { signupService } from '../../services/signup.service';

export const EmailVerification: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const email = (location.state as any)?.email || '';

  const [resending, setResending] = useState(false);
  const [resendSuccess, setResendSuccess] = useState(false);
  const [resendError, setResendError] = useState<string | null>(null);

  const handleResendEmail = async () => {
    if (!email) {
      setResendError('Email address not found. Please return to sign-up page.');
      return;
    }

    setResending(true);
    setResendError(null);
    setResendSuccess(false);

    try {
      // Call backend API to resend verification email
      await signupService.resendVerificationEmail(email);

      console.log('Verification email resent successfully to:', email);
      setResendSuccess(true);
    } catch (err: any) {
      setResendError(err.message || 'Failed to resend email. Please try again.');
    } finally {
      setResending(false);
    }
  };

  const handleBackToLogin = () => {
    navigate('/');
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        {/* Success icon */}
        <div style={styles.iconContainer}>
          <div style={styles.successIcon}>✉️</div>
        </div>

        {/* Header */}
        <div style={styles.header}>
          <h1 style={styles.title}>Check Your Email</h1>
          <p style={styles.subtitle}>
            We've sent a verification link to
          </p>
          <p style={styles.email}>{email}</p>
        </div>

        {/* Instructions */}
        <div style={styles.instructions}>
          <h3 style={styles.instructionsTitle}>What to do next:</h3>
          <ol style={styles.instructionsList}>
            <li style={styles.instructionItem}>
              Check your inbox for an email from HRMS SaaS
            </li>
            <li style={styles.instructionItem}>
              Click the verification link in the email
            </li>
            <li style={styles.instructionItem}>
              Your account will be activated automatically
            </li>
            <li style={styles.instructionItem}>
              Return to the login page and sign in
            </li>
          </ol>
        </div>

        {/* Resend email section */}
        <div style={styles.resendSection}>
          <p style={styles.resendText}>Didn't receive the email?</p>

          {resendSuccess && (
            <div style={styles.successMessage}>
              ✅ Verification email resent successfully!
            </div>
          )}

          {resendError && (
            <div style={styles.errorMessage}>
              ⚠️ {resendError}
            </div>
          )}

          <button
            onClick={handleResendEmail}
            disabled={resending || resendSuccess}
            style={{
              ...styles.resendButton,
              ...(resending || resendSuccess ? styles.buttonDisabled : {}),
            }}
          >
            {resending ? 'Sending...' : resendSuccess ? 'Email Sent!' : 'Resend Email'}
          </button>
        </div>

        {/* Tips */}
        <div style={styles.tips}>
          <h4 style={styles.tipsTitle}>Tips:</h4>
          <ul style={styles.tipsList}>
            <li style={styles.tipItem}>Check your spam or junk folder</li>
            <li style={styles.tipItem}>Make sure you entered the correct email address</li>
            <li style={styles.tipItem}>Wait a few minutes for the email to arrive</li>
          </ul>
        </div>

        {/* Back to login */}
        <div style={styles.footer}>
          <button onClick={handleBackToLogin} style={styles.backButton}>
            ← Back to Login
          </button>
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
    padding: '48px',
    maxWidth: '600px',
    width: '100%',
    boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
  },
  iconContainer: {
    textAlign: 'center',
    marginBottom: '24px',
  },
  successIcon: {
    fontSize: '64px',
    animation: 'bounce 1s ease-in-out',
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
  },
  title: {
    margin: '0 0 16px 0',
    fontSize: '32px',
    color: '#333',
  },
  subtitle: {
    margin: '0 0 8px 0',
    fontSize: '16px',
    color: '#666',
  },
  email: {
    margin: 0,
    fontSize: '18px',
    fontWeight: '600',
    color: '#667eea',
  },
  instructions: {
    background: '#f8f9fa',
    borderRadius: '12px',
    padding: '24px',
    marginBottom: '24px',
  },
  instructionsTitle: {
    margin: '0 0 16px 0',
    fontSize: '18px',
    color: '#333',
  },
  instructionsList: {
    margin: 0,
    paddingLeft: '20px',
  },
  instructionItem: {
    marginBottom: '12px',
    fontSize: '15px',
    color: '#555',
    lineHeight: '1.6',
  },
  resendSection: {
    textAlign: 'center',
    marginBottom: '24px',
    paddingTop: '24px',
    borderTop: '1px solid #e0e0e0',
  },
  resendText: {
    margin: '0 0 16px 0',
    fontSize: '14px',
    color: '#666',
  },
  successMessage: {
    background: '#e8f5e9',
    color: '#2e7d32',
    padding: '12px',
    borderRadius: '8px',
    marginBottom: '16px',
    border: '1px solid #c8e6c9',
    fontSize: '14px',
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
  resendButton: {
    padding: '12px 24px',
    fontSize: '14px',
    fontWeight: '600',
    color: 'white',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'transform 0.2s',
  },
  buttonDisabled: {
    opacity: 0.6,
    cursor: 'not-allowed',
  },
  tips: {
    background: '#fff8e1',
    borderRadius: '12px',
    padding: '20px',
    marginBottom: '24px',
  },
  tipsTitle: {
    margin: '0 0 12px 0',
    fontSize: '16px',
    color: '#f57c00',
  },
  tipsList: {
    margin: 0,
    paddingLeft: '20px',
  },
  tipItem: {
    marginBottom: '8px',
    fontSize: '14px',
    color: '#666',
  },
  footer: {
    textAlign: 'center',
  },
  backButton: {
    padding: '12px 24px',
    fontSize: '14px',
    fontWeight: '600',
    color: '#667eea',
    background: 'white',
    border: '2px solid #667eea',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
};
