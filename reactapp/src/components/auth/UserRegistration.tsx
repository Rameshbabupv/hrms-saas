/**
 * User Registration Component for HRMS SaaS
 *
 * Creates Keycloak users with tenant_id (company_id) for Row-Level Security
 *
 * Features:
 * - Register employees with tenant context
 * - Automatic tenant_id assignment from logged-in user's context
 * - Role selection (company_admin, hr_user, manager, employee)
 * - Email verification workflow
 *
 * Security Note:
 * This component should only be accessible to company_admin and hr_user roles
 */

import React, { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { keycloakAdminService } from '../../services/keycloak-admin.service';
import type { UserRegistrationRequest } from '../../types/auth.types';

interface UserRegistrationFormData {
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  phone: string;
  password: string;
  confirmPassword: string;
  userType: 'company_admin' | 'hr_user' | 'manager' | 'employee';
  employeeId?: string;
}

export const UserRegistration: React.FC = () => {
  const { tenantContext, isCompanyAdmin, isHRUser } = useAuth();

  const [formData, setFormData] = useState<UserRegistrationFormData>({
    username: '',
    email: '',
    firstName: '',
    lastName: '',
    phone: '',
    password: '',
    confirmPassword: '',
    userType: 'employee',
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Check authorization
  if (!isCompanyAdmin() && !isHRUser()) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>
          <h3>⛔ Access Denied</h3>
          <p>You don't have permission to create users.</p>
          <p>Only Company Admins and HR Users can register new employees.</p>
        </div>
      </div>
    );
  }

  // Validate tenant context
  if (!tenantContext || !tenantContext.companyId) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>
          <h3>⚠️ Tenant Context Missing</h3>
          <p>Unable to determine your company (tenant) context.</p>
          <p>Please logout and login again.</p>
        </div>
      </div>
    );
  }

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>
  ) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    setError(null);
  };

  const validateForm = (): string | null => {
    if (!formData.username || !formData.email || !formData.firstName || !formData.lastName) {
      return 'Please fill in all required fields';
    }

    if (!formData.email.includes('@')) {
      return 'Please enter a valid email address';
    }

    if (formData.password.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (formData.password !== formData.confirmPassword) {
      return 'Passwords do not match';
    }

    return null;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Validate form
    const validationError = validateForm();
    if (validationError) {
      setError(validationError);
      return;
    }

    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      // Prepare registration request with tenant_id
      const registrationRequest: UserRegistrationRequest = {
        username: formData.email, // Use email as username
        email: formData.email,
        firstName: formData.firstName,
        lastName: formData.lastName,
        phone: formData.phone || undefined,

        // CRITICAL: Assign tenant context from logged-in user
        companyId: tenantContext.companyId,

        // Optional: Link to employee record if created
        employeeId: formData.employeeId || undefined,

        // User classification
        userType: formData.userType,

        // Credentials
        password: formData.password,
        temporary: true, // User must change password on first login

        // Account settings
        enabled: true,
        emailVerified: false, // Will be verified via email link

        // Required actions
        requiredActions: ['VERIFY_EMAIL', 'UPDATE_PASSWORD'],

        // Realm roles
        realmRoles: [formData.userType],
      };

      console.log('📝 Creating user with tenant context:', {
        email: formData.email,
        companyId: tenantContext.companyId,
        companyName: tenantContext.companyName,
        userType: formData.userType,
      });

      // Create user in Keycloak
      const result = await keycloakAdminService.createUser(registrationRequest);

      console.log('✅ User created successfully:', result);

      // Send verification email
      await keycloakAdminService.sendVerificationEmail(result.userId);

      setSuccess(
        `✅ User created successfully!\n\n` +
        `User ID: ${result.userId}\n` +
        `Email: ${formData.email}\n` +
        `Company: ${tenantContext.companyName || tenantContext.companyId}\n\n` +
        `📧 Verification email has been sent to ${formData.email}\n` +
        `The user must verify their email and change their password on first login.`
      );

      // Reset form
      setFormData({
        username: '',
        email: '',
        firstName: '',
        lastName: '',
        phone: '',
        password: '',
        confirmPassword: '',
        userType: 'employee',
      });

    } catch (err: any) {
      console.error('❌ User registration failed:', err);
      setError(err.message || 'Failed to create user. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <h2 style={styles.title}>👥 Register New User</h2>

        <div style={styles.tenantInfo}>
          <h4>🏢 Tenant Context</h4>
          <p><strong>Company:</strong> {tenantContext.companyName || tenantContext.companyId}</p>
          <p><strong>Company Code:</strong> {tenantContext.companyCode || 'N/A'}</p>
          <p style={styles.infoText}>
            ℹ️ New user will be assigned to your company for Row-Level Security (RLS)
          </p>
        </div>

        {error && (
          <div style={styles.errorMessage}>
            ❌ {error}
          </div>
        )}

        {success && (
          <div style={styles.successMessage}>
            {success.split('\n').map((line, i) => (
              <div key={i}>{line}</div>
            ))}
          </div>
        )}

        <form onSubmit={handleSubmit} style={styles.form}>
          <div style={styles.formGroup}>
            <label style={styles.label}>Email (Username) *</label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              placeholder="user@company.com"
              style={styles.input}
              required
            />
          </div>

          <div style={styles.formRow}>
            <div style={styles.formGroup}>
              <label style={styles.label}>First Name *</label>
              <input
                type="text"
                name="firstName"
                value={formData.firstName}
                onChange={handleInputChange}
                placeholder="John"
                style={styles.input}
                required
              />
            </div>

            <div style={styles.formGroup}>
              <label style={styles.label}>Last Name *</label>
              <input
                type="text"
                name="lastName"
                value={formData.lastName}
                onChange={handleInputChange}
                placeholder="Doe"
                style={styles.input}
                required
              />
            </div>
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label}>Phone Number</label>
            <input
              type="tel"
              name="phone"
              value={formData.phone}
              onChange={handleInputChange}
              placeholder="+1-555-0123"
              style={styles.input}
            />
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label}>User Role *</label>
            <select
              name="userType"
              value={formData.userType}
              onChange={handleInputChange}
              style={styles.select}
              required
            >
              <option value="employee">Employee (Regular User)</option>
              <option value="manager">Manager (Team Lead)</option>
              <option value="hr_user">HR User (HR Department)</option>
              {isCompanyAdmin() && (
                <option value="company_admin">Company Admin (Full Access)</option>
              )}
            </select>
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label}>Employee ID (Optional)</label>
            <input
              type="text"
              name="employeeId"
              value={formData.employeeId || ''}
              onChange={handleInputChange}
              placeholder="UUID of employee record (if already created)"
              style={styles.input}
            />
            <small style={styles.helpText}>
              If employee record exists in database, enter the UUID here
            </small>
          </div>

          <div style={styles.formRow}>
            <div style={styles.formGroup}>
              <label style={styles.label}>Temporary Password *</label>
              <input
                type="password"
                name="password"
                value={formData.password}
                onChange={handleInputChange}
                placeholder="Minimum 8 characters"
                style={styles.input}
                required
                minLength={8}
              />
            </div>

            <div style={styles.formGroup}>
              <label style={styles.label}>Confirm Password *</label>
              <input
                type="password"
                name="confirmPassword"
                value={formData.confirmPassword}
                onChange={handleInputChange}
                placeholder="Re-enter password"
                style={styles.input}
                required
              />
            </div>
          </div>

          <div style={styles.infoBox}>
            <strong>📧 Post-Registration Process:</strong>
            <ul style={{ margin: '8px 0', paddingLeft: '20px' }}>
              <li>User will receive email verification link</li>
              <li>User must verify email address</li>
              <li>User must change password on first login</li>
              <li>User will be assigned to company: <strong>{tenantContext.companyName}</strong></li>
            </ul>
          </div>

          <button
            type="submit"
            style={{
              ...styles.button,
              ...(loading ? styles.buttonDisabled : {}),
            }}
            disabled={loading}
          >
            {loading ? '⏳ Creating User...' : '✅ Create User'}
          </button>
        </form>
      </div>
    </div>
  );
};

// Inline styles
const styles: { [key: string]: React.CSSProperties } = {
  container: {
    maxWidth: '800px',
    margin: '40px auto',
    padding: '20px',
  },
  card: {
    background: 'white',
    borderRadius: '12px',
    padding: '30px',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.1)',
  },
  title: {
    margin: '0 0 24px 0',
    fontSize: '28px',
    color: '#333',
  },
  tenantInfo: {
    background: '#f0f7ff',
    border: '2px solid #2196F3',
    borderRadius: '8px',
    padding: '16px',
    marginBottom: '24px',
  },
  infoText: {
    fontSize: '14px',
    color: '#666',
    margin: '8px 0 0 0',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '20px',
  },
  formRow: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '16px',
  },
  formGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  label: {
    fontSize: '14px',
    fontWeight: '600',
    color: '#333',
  },
  input: {
    padding: '12px',
    fontSize: '14px',
    border: '2px solid #ddd',
    borderRadius: '8px',
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  select: {
    padding: '12px',
    fontSize: '14px',
    border: '2px solid #ddd',
    borderRadius: '8px',
    outline: 'none',
    backgroundColor: 'white',
  },
  helpText: {
    fontSize: '12px',
    color: '#666',
  },
  infoBox: {
    background: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '8px',
    padding: '16px',
    fontSize: '14px',
  },
  button: {
    padding: '14px 24px',
    fontSize: '16px',
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
  errorMessage: {
    background: '#fee',
    color: '#c00',
    padding: '12px',
    borderRadius: '8px',
    marginBottom: '16px',
    border: '1px solid #fcc',
  },
  successMessage: {
    background: '#efe',
    color: '#060',
    padding: '12px',
    borderRadius: '8px',
    marginBottom: '16px',
    border: '1px solid #cfc',
    whiteSpace: 'pre-wrap',
  },
  errorBox: {
    background: '#fee',
    border: '2px solid #c00',
    borderRadius: '8px',
    padding: '24px',
    textAlign: 'center',
  },
};

export default UserRegistration;
