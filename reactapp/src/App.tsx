/**
 * Main App Component for HRMS SaaS
 *
 * Multi-tenant application with Keycloak authentication and Row-Level Security
 */

import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useNavigate } from 'react-router-dom';
import { AuthProvider, useAuth, useTenant } from './contexts/AuthContext';
import { UserRegistration } from './components/auth/UserRegistration';
import { SignUp } from './components/auth/SignUp';
import { EmailVerification } from './components/auth/EmailVerification';
import './App.css';

/**
 * Login Page Component
 */
const LoginPage: React.FC = () => {
  const navigate = useNavigate();
  const { login, error } = useAuth();
  const [loginError, setLoginError] = React.useState<string | null>(null);

  const handleLogin = async () => {
    try {
      setLoginError(null);
      await login();
    } catch (err: any) {
      setLoginError(err.message || 'Login failed');
    }
  };

  const handleSignUp = () => {
    navigate('/signup');
  };

  return (
    <div style={styles.loginContainer}>
      <div style={styles.loginCard}>
        <h1 style={styles.loginTitle}>🏢 HRMS SaaS Platform</h1>
        <p style={styles.loginSubtitle}>Multi-Tenant Human Resource Management System</p>

        <div style={styles.featureList}>
          <h3>Features</h3>
          <ul style={styles.features}>
            <li>🔐 Secure Keycloak Authentication</li>
            <li>🏢 Multi-Tenant Data Isolation (RLS)</li>
            <li>👥 User & Employee Management</li>
            <li>📊 Company Master & Reporting</li>
            <li>🔒 Role-Based Access Control</li>
          </ul>
        </div>

        {(error || loginError) && (
          <div style={styles.errorMessage}>
            ⚠️ {error || loginError}
          </div>
        )}

        <button onClick={handleLogin} style={styles.loginButton}>
          🔑 Sign In with Keycloak
        </button>

        <div style={styles.divider}>
          <span style={styles.dividerText}>or</span>
        </div>

        <button onClick={handleSignUp} style={styles.signupButton}>
          ✨ Create New Account
        </button>

        <div style={styles.signupInfo}>
          <p style={styles.signupText}>
            New to HRMS SaaS? Sign up to create your company account and start managing your HR operations.
          </p>
        </div>

        <div style={styles.configInfo}>
          <small>
            <strong>Configuration:</strong><br />
            Realm: {process.env.REACT_APP_KEYCLOAK_REALM}<br />
            Client: {process.env.REACT_APP_KEYCLOAK_CLIENT}<br />
            Environment: {process.env.NODE_ENV}
          </small>
        </div>
      </div>
    </div>
  );
};

/**
 * Dashboard Component
 */
const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const { companyName, companyCode, tenantId, isParentCompany } = useTenant();

  return (
    <div style={styles.dashboard}>
      <h2>📊 Dashboard</h2>

      <div style={styles.infoCard}>
        <h3>👤 User Information</h3>
        <p><strong>Name:</strong> {user?.firstName} {user?.lastName}</p>
        <p><strong>Email:</strong> {user?.email}</p>
        <p><strong>Username:</strong> {user?.username}</p>
        <p><strong>Role:</strong> {user?.userType}</p>
        <p><strong>Roles:</strong> {user?.roles.join(', ')}</p>
      </div>

      <div style={styles.tenantCard}>
        <h3>🏢 Tenant Context (for Row-Level Security)</h3>
        <p><strong>Company:</strong> {companyName || 'N/A'}</p>
        <p><strong>Company Code:</strong> {companyCode || 'N/A'}</p>
        <p><strong>Tenant ID:</strong> <code>{tenantId}</code></p>
        <p><strong>Parent Company:</strong> {isParentCompany ? '✅ Yes' : '❌ No'}</p>
        <div style={styles.warningBox}>
          <strong>⚠️ Important:</strong> This tenant_id is automatically included in JWT tokens
          and used by the backend to enforce Row-Level Security (RLS) in PostgreSQL.
        </div>
      </div>

      <div style={styles.statsCard}>
        <h3>📈 Quick Stats</h3>
        <div style={styles.statsGrid}>
          <div style={styles.statItem}>
            <div style={styles.statValue}>-</div>
            <div style={styles.statLabel}>Employees</div>
          </div>
          <div style={styles.statItem}>
            <div style={styles.statValue}>-</div>
            <div style={styles.statLabel}>Departments</div>
          </div>
          <div style={styles.statItem}>
            <div style={styles.statValue}>-</div>
            <div style={styles.statLabel}>Active Users</div>
          </div>
        </div>
        <p style={styles.comingSoon}>🚧 Full dashboard coming soon...</p>
      </div>
    </div>
  );
};

/**
 * Header Component
 */
const Header: React.FC = () => {
  const { user, logout, isCompanyAdmin, isHRUser } = useAuth();
  const { companyName } = useTenant();

  return (
    <header style={styles.header}>
      <div style={styles.headerContent}>
        <div style={styles.logo}>
          <h1 style={styles.logoText}>🏢 HRMS SaaS</h1>
          <p style={styles.companyTag}>{companyName}</p>
        </div>

        <nav style={styles.nav}>
          <Link to="/" style={styles.navLink}>Dashboard</Link>
          {(isCompanyAdmin() || isHRUser()) && (
            <Link to="/register-user" style={styles.navLink}>Register User</Link>
          )}
        </nav>

        <div style={styles.userInfo}>
          <div style={styles.userAvatar}>
            {user?.firstName?.charAt(0)}{user?.lastName?.charAt(0)}
          </div>
          <div style={styles.userDetails}>
            <div style={styles.userName}>{user?.firstName} {user?.lastName}</div>
            <div style={styles.userRole}>{user?.userType}</div>
          </div>
          <button onClick={logout} style={styles.logoutButton}>
            Logout
          </button>
        </div>
      </div>
    </header>
  );
};

/**
 * App Content (Protected and Public Routes)
 */
const AppContent: React.FC = () => {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return (
      <div style={styles.loading}>
        <div style={styles.spinner}></div>
        <h2>Loading HRMS SaaS Platform...</h2>
        <p>Initializing authentication...</p>
      </div>
    );
  }

  return (
    <Routes>
      {/* Public routes */}
      <Route path="/signup" element={<SignUp />} />
      <Route path="/email-verification" element={<EmailVerification />} />

      {/* Protected routes */}
      {isAuthenticated ? (
        <>
          <Route path="/" element={
            <div style={styles.app}>
              <Header />
              <main style={styles.main}>
                <Dashboard />
              </main>
              <footer style={styles.footer}>
                <p>© 2025 HRMS SaaS Platform - Multi-Tenant HRMS Solution</p>
              </footer>
            </div>
          } />
          <Route path="/register-user" element={
            <div style={styles.app}>
              <Header />
              <main style={styles.main}>
                <UserRegistration />
              </main>
              <footer style={styles.footer}>
                <p>© 2025 HRMS SaaS Platform - Multi-Tenant HRMS Solution</p>
              </footer>
            </div>
          } />
        </>
      ) : (
        <Route path="*" element={<LoginPage />} />
      )}
    </Routes>
  );
};

/**
 * Main App Component
 */
function App() {
  return (
    <AuthProvider>
      <Router>
        <AppContent />
      </Router>
    </AuthProvider>
  );
}

// Styles
const styles: { [key: string]: React.CSSProperties } = {
  // Loading
  loading: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100vh',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    color: 'white',
  },
  spinner: {
    width: '60px',
    height: '60px',
    border: '6px solid rgba(255, 255, 255, 0.3)',
    borderTop: '6px solid white',
    borderRadius: '50%',
    animation: 'spin 1s linear infinite',
  },

  // Login Page
  loginContainer: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    padding: '20px',
  },
  loginCard: {
    background: 'white',
    borderRadius: '16px',
    padding: '48px',
    maxWidth: '500px',
    boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
    textAlign: 'center',
  },
  loginTitle: {
    margin: '0 0 8px 0',
    fontSize: '36px',
    color: '#333',
  },
  loginSubtitle: {
    margin: '0 0 32px 0',
    fontSize: '16px',
    color: '#666',
  },
  featureList: {
    textAlign: 'left',
    marginBottom: '32px',
  },
  features: {
    listStyle: 'none',
    padding: 0,
    margin: 0,
  },
  loginButton: {
    width: '100%',
    padding: '16px',
    fontSize: '18px',
    fontWeight: '600',
    color: 'white',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'transform 0.2s',
  },
  divider: {
    display: 'flex',
    alignItems: 'center',
    margin: '24px 0',
  },
  dividerText: {
    width: '100%',
    textAlign: 'center',
    color: '#999',
    fontSize: '14px',
    position: 'relative',
  },
  signupButton: {
    width: '100%',
    padding: '16px',
    fontSize: '18px',
    fontWeight: '600',
    color: '#667eea',
    background: 'white',
    border: '2px solid #667eea',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
  signupInfo: {
    marginTop: '16px',
    textAlign: 'center',
  },
  signupText: {
    fontSize: '13px',
    color: '#666',
    margin: 0,
  },
  configInfo: {
    marginTop: '24px',
    padding: '16px',
    background: '#f5f5f5',
    borderRadius: '8px',
    color: '#666',
  },
  errorMessage: {
    background: '#fee',
    color: '#c00',
    padding: '12px',
    borderRadius: '8px',
    margin: '16px 0',
    border: '1px solid #fcc',
    fontSize: '14px',
  },

  // App Layout
  app: {
    display: 'flex',
    flexDirection: 'column',
    minHeight: '100vh',
  },
  header: {
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    color: 'white',
    padding: '16px 32px',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
  },
  headerContent: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    maxWidth: '1400px',
    margin: '0 auto',
  },
  logo: {
    display: 'flex',
    flexDirection: 'column',
  },
  logoText: {
    margin: 0,
    fontSize: '24px',
  },
  companyTag: {
    margin: 0,
    fontSize: '12px',
    opacity: 0.8,
  },
  nav: {
    display: 'flex',
    gap: '24px',
  },
  navLink: {
    color: 'white',
    textDecoration: 'none',
    fontSize: '16px',
    fontWeight: '500',
  },
  userInfo: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  userAvatar: {
    width: '40px',
    height: '40px',
    borderRadius: '50%',
    background: 'rgba(255, 255, 255, 0.2)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: '600',
  },
  userDetails: {
    textAlign: 'left',
  },
  userName: {
    fontSize: '14px',
    fontWeight: '600',
  },
  userRole: {
    fontSize: '12px',
    opacity: 0.8,
  },
  logoutButton: {
    padding: '8px 16px',
    background: 'rgba(255, 255, 255, 0.2)',
    border: '1px solid rgba(255, 255, 255, 0.3)',
    borderRadius: '6px',
    color: 'white',
    cursor: 'pointer',
    fontSize: '14px',
  },

  // Main Content
  main: {
    flex: 1,
    padding: '32px',
    background: '#f8f9fa',
  },
  dashboard: {
    maxWidth: '1200px',
    margin: '0 auto',
  },
  infoCard: {
    background: 'white',
    borderRadius: '12px',
    padding: '24px',
    marginBottom: '24px',
    boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
  },
  tenantCard: {
    background: '#fff3cd',
    border: '2px solid #ffc107',
    borderRadius: '12px',
    padding: '24px',
    marginBottom: '24px',
  },
  warningBox: {
    background: '#fff',
    border: '1px solid #ffc107',
    borderRadius: '8px',
    padding: '12px',
    marginTop: '16px',
    fontSize: '14px',
  },
  statsCard: {
    background: 'white',
    borderRadius: '12px',
    padding: '24px',
    boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '24px',
    marginTop: '16px',
  },
  statItem: {
    textAlign: 'center',
  },
  statValue: {
    fontSize: '36px',
    fontWeight: '700',
    color: '#667eea',
  },
  statLabel: {
    fontSize: '14px',
    color: '#666',
    marginTop: '8px',
  },
  comingSoon: {
    textAlign: 'center',
    color: '#999',
    marginTop: '24px',
  },

  // Footer
  footer: {
    background: '#333',
    color: 'white',
    textAlign: 'center',
    padding: '16px',
    fontSize: '14px',
  },
};

export default App;
