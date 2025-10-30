/**
 * Password Strength Validator
 *
 * Validates password strength according to security best practices
 */

import { PasswordStrength } from '../types/signup.types';

/**
 * Validate password strength
 *
 * Requirements:
 * - Minimum 8 characters
 * - At least one uppercase letter
 * - At least one lowercase letter
 * - At least one number
 * - At least one special character
 */
export function validatePasswordStrength(password: string): PasswordStrength {
  const feedback: string[] = [];
  let score = 0;

  // Check length
  if (password.length < 8) {
    feedback.push('Password must be at least 8 characters long');
  } else if (password.length >= 8) {
    score++;
  }

  if (password.length >= 12) {
    score++;
  }

  // Check for uppercase
  if (!/[A-Z]/.test(password)) {
    feedback.push('Include at least one uppercase letter (A-Z)');
  } else {
    score++;
  }

  // Check for lowercase
  if (!/[a-z]/.test(password)) {
    feedback.push('Include at least one lowercase letter (a-z)');
  } else {
    score++;
  }

  // Check for numbers
  if (!/[0-9]/.test(password)) {
    feedback.push('Include at least one number (0-9)');
  } else {
    score++;
  }

  // Check for special characters
  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
    feedback.push('Include at least one special character (!@#$%^&*...)');
  } else {
    score++;
  }

  // Check for common patterns
  const commonPasswords = [
    'password', 'Password123', '12345678', 'qwerty', 'abc123',
    'letmein', 'welcome', 'monkey', 'dragon', 'master'
  ];

  if (commonPasswords.some(common => password.toLowerCase().includes(common))) {
    feedback.push('Avoid common passwords');
    score = Math.max(0, score - 2);
  }

  // Check for sequential characters
  if (/(?:abc|bcd|cde|def|123|234|345|456)/i.test(password)) {
    feedback.push('Avoid sequential characters');
    score = Math.max(0, score - 1);
  }

  const isStrong = score >= 5 && feedback.length === 0;

  if (feedback.length === 0) {
    if (score >= 6) {
      feedback.push('✅ Excellent password strength!');
    } else if (score >= 5) {
      feedback.push('✅ Strong password');
    } else if (score >= 4) {
      feedback.push('⚠️ Good password, but could be stronger');
    }
  }

  return {
    score: Math.min(score, 6),
    feedback,
    isStrong
  };
}

/**
 * Get password strength label
 */
export function getPasswordStrengthLabel(score: number): string {
  if (score <= 2) return 'Weak';
  if (score <= 3) return 'Fair';
  if (score <= 4) return 'Good';
  if (score <= 5) return 'Strong';
  return 'Excellent';
}

/**
 * Get password strength color
 */
export function getPasswordStrengthColor(score: number): string {
  if (score <= 2) return '#d32f2f'; // Red
  if (score <= 3) return '#f57c00'; // Orange
  if (score <= 4) return '#fbc02d'; // Yellow
  if (score <= 5) return '#7cb342'; // Light Green
  return '#388e3c'; // Dark Green
}

/**
 * Validate email format
 */
export function validateEmail(email: string): { valid: boolean; message?: string } {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!email) {
    return { valid: false, message: 'Email is required' };
  }

  if (!emailRegex.test(email)) {
    return { valid: false, message: 'Please enter a valid email address' };
  }

  // Check for common typos in domain
  const domain = email.split('@')[1]?.toLowerCase();

  const typos: Record<string, string> = {
    'gmial.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'yahooo.com': 'yahoo.com',
    'outlok.com': 'outlook.com',
  };

  if (typos[domain]) {
    return {
      valid: true,
      message: `Did you mean ${email.split('@')[0]}@${typos[domain]}?`
    };
  }

  return { valid: true };
}

/**
 * Validate company name
 */
export function validateCompanyName(name: string): { valid: boolean; message?: string } {
  if (!name) {
    return { valid: false, message: 'Company name is required' };
  }

  if (name.length < 2) {
    return { valid: false, message: 'Company name must be at least 2 characters' };
  }

  if (name.length > 100) {
    return { valid: false, message: 'Company name is too long (max 100 characters)' };
  }

  // Check for suspicious patterns
  if (/test|demo|sample|example/i.test(name) && name.length < 10) {
    return {
      valid: true,
      message: 'This looks like a test company name. Is this correct?'
    };
  }

  return { valid: true };
}
