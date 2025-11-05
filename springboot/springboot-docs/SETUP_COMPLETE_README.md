# Keycloak Setup Complete - HRMS SaaS

**Date:** October 30, 2025
**Status:** ✅ Automated Setup Completed
**Realm:** hrms-saas
**Keycloak URL:** http://localhost:8090

---

## 🎉 What Has Been Configured

### 1. Realm Configuration
- ✅ **Realm Name:** `hrms-saas`
- ✅ **Display Name:** HRMS SaaS Platform
- ✅ **Login Settings:** Configured (email login, password reset, remember me)
- ✅ **Token Lifespan:** 30 minutes access token, 1 hour SSO session
- ✅ **Security:** Brute force protection enabled (5 failed attempts)

### 2. Client Configuration
- ✅ **Client ID:** `hrms-web-app`
- ✅ **Client Type:** Confidential (OpenID Connect)
- ✅ **Client UUID:** `c86500ff-9171-41f9-94a8-874455925c71`
- ✅ **Client Secret:** `AhuaZRTwH4wsXHFrmMEciDjo1Kc8aS0M`
- ✅ **Authentication Flow:** Standard Flow + Direct Access Grants enabled
- ✅ **Redirect URIs:** localhost:3000, localhost:3001 configured for development

### 3. Custom JWT Mappers (7 mappers created)
All mappers configured to add custom claims to access tokens:

| Mapper Name | Claim Name | Purpose |
|-------------|------------|---------|
| company_id | company_id | Tenant UUID for RLS filtering |
| tenant_id | tenant_id | Same as company_id (alias) |
| employee_id | employee_id | Employee UUID from database |
| user_type | user_type | User role category |
| company_code | company_code | Company code for display |
| company_name | company_name | Company name for display |
| phone | phone | User phone number |

### 4. Realm Roles (5 roles created)
| Role Name | Description |
|-----------|-------------|
| super_admin | Super administrator with access to all tenants |
| company_admin | Company administrator with full access to their tenant |
| hr_user | HR user with employee management access |
| manager | Manager with team data access |
| employee | Regular employee with self-service access |

### 5. Test Users Created
| Username | Password | Role | Company ID |
|----------|----------|------|------------|
| admin@testcompany.com | TestAdmin@123 | company_admin | 550e8400-e29b-41d4-a716-446655440000 |
| john.doe@testcompany.com | TestUser@123 | employee | 550e8400-e29b-41d4-a716-446655440000 |

---

## ⚠️ IMPORTANT: Manual Step Required

Due to Keycloak User Profile restrictions, user attributes need to be added manually through the Admin Console.

### Steps to Add User Attributes:

1. **Open Keycloak Admin Console:**
   ```
   URL: http://localhost:8090/admin
   Username: admin
   Password: secret
   ```

2. **Navigate to Users:**
   - Select Realm: `hrms-saas` (top-left dropdown)
   - Click "Users" in left sidebar
   - Click "View all users"

3. **Update Employee User (john.doe@testcompany.com):**
   - Click on the user
   - Go to "Attributes" tab
   - Click "Add attribute" for each of the following:

   | Key | Value |
   |-----|-------|
   | company_id | 550e8400-e29b-41d4-a716-446655440000 |
   | tenant_id | 550e8400-e29b-41d4-a716-446655440000 |
   | employee_id | 660e8400-e29b-41d4-a716-446655440001 |
   | user_type | employee |
   | company_code | TEST001 |
   | company_name | Test Company Ltd |
   | phone | +91-9876543210 |

   - Click "Save"

4. **Update Admin User (admin@testcompany.com):**
   - Click on the user
   - Go to "Attributes" tab
   - Click "Add attribute" for each of the following:

   | Key | Value |
   |-----|-------|
   | company_id | 550e8400-e29b-41d4-a716-446655440000 |
   | tenant_id | 550e8400-e29b-41d4-a716-446655440000 |
   | user_type | company_admin |
   | company_code | TEST001 |
   | company_name | Test Company Ltd |

   - Click "Save"

---

## 🧪 Testing JWT Token Generation

After adding user attributes, test token generation:

```bash
cd scripts
./test-token.sh employee
```

**Expected Output:**
- ✅ Access token obtained
- ✅ Custom claims present (company_id, tenant_id, employee_id, user_type)
- ✅ Realm roles visible
- ✅ Token refresh works

**Test Commands:**
```bash
# Test employee user
./test-token.sh employee

# Test admin user
./test-token.sh admin

# Test custom user
./test-token.sh username@domain.com
```

---

## 📁 Generated Files

### Configuration Files
- `config/keycloak-config.env` - Environment variables for backend integration
- `config/test-users.txt` - Test user credentials
- `config/tokens-*.json` - Sample JWT tokens (after testing)

### Scripts
- `scripts/setup-keycloak.sh` - Main setup script
- `scripts/create-mappers.sh` - Custom JWT mapper creation
- `scripts/create-test-users.sh` - Test user creation
- `scripts/test-token.sh` - JWT token testing
- `scripts/run-all.sh` - Complete automated setup

---

## 🔗 Integration Information

### For Backend Team (Spring Boot)

**Environment Variables:**
```properties
# Keycloak Server
KEYCLOAK_URL=http://localhost:8090
KEYCLOAK_REALM=hrms-saas
KEYCLOAK_CLIENT_ID=hrms-web-app
KEYCLOAK_CLIENT_SECRET=AhuaZRTwH4wsXHFrmMEciDjo1Kc8aS0M

# JWT Validation
KEYCLOAK_JWKS_URL=http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs
KEYCLOAK_ISSUER=http://localhost:8090/realms/hrms-saas

# Admin API (for user provisioning)
KEYCLOAK_ADMIN_USERNAME=admin
KEYCLOAK_ADMIN_PASSWORD=secret
KEYCLOAK_ADMIN_CLIENT_ID=admin-cli
```

**Implementation Tasks:**
1. Add Keycloak Spring Boot Starter dependency
2. Configure JWT token validation using JWKS endpoint
3. Extract `company_id` claim from JWT
4. Set PostgreSQL session variable: `SELECT set_current_tenant(company_id)`
5. Implement user provisioning via Admin API

**Sample Code:**
```java
@Configuration
public class KeycloakConfig {
    @Value("${keycloak.jwks-url}")
    private String jwksUrl;

    @Bean
    public JwtDecoder jwtDecoder() {
        return NimbusJwtDecoder.withJwkSetUri(jwksUrl).build();
    }
}

@Component
public class TenantContextFilter implements Filter {
    public void doFilter(ServletRequest request, ...) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        Jwt jwt = (Jwt) auth.getPrincipal();
        String companyId = jwt.getClaim("company_id");

        // Set PostgreSQL session variable
        jdbcTemplate.execute("SELECT set_current_tenant('" + companyId + "')");

        chain.doFilter(request, response);
    }
}
```

### For Frontend Team (React)

**keycloak.json:**
```json
{
  "realm": "hrms-saas",
  "url": "http://localhost:8090",
  "clientId": "hrms-web-app",
  "ssl-required": "external",
  "public-client": false,
  "confidential-port": 0
}
```

**Installation:**
```bash
npm install keycloak-js @react-keycloak/web
```

**Implementation:**
```javascript
import Keycloak from 'keycloak-js';
import { ReactKeycloakProvider } from '@react-keycloak/web';

const keycloak = new Keycloak({
  url: 'http://localhost:8090',
  realm: 'hrms-saas',
  clientId: 'hrms-web-app'
});

function App() {
  return (
    <ReactKeycloakProvider authClient={keycloak}>
      <YourApp />
    </ReactKeycloakProvider>
  );
}

// Access token
import { useKeycloak } from '@react-keycloak/web';

function Component() {
  const { keycloak } = useKeycloak();

  // Get token for API calls
  const token = keycloak.token;

  // Make API call
  fetch('http://localhost:8081/api/employees', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
}
```

---

## 📊 Token Structure

After adding user attributes, JWT tokens will contain:

```json
{
  "exp": 1698767232,
  "iat": 1698765432,
  "iss": "http://localhost:8090/realms/hrms-saas",
  "aud": "hrms-web-app",
  "sub": "user-uuid",
  "typ": "Bearer",

  "email": "john.doe@testcompany.com",
  "email_verified": true,
  "preferred_username": "john.doe@testcompany.com",
  "given_name": "John",
  "family_name": "Doe",

  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "employee_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_type": "employee",
  "company_code": "TEST001",
  "company_name": "Test Company Ltd",
  "phone": "+91-9876543210",

  "realm_access": {
    "roles": ["employee"]
  }
}
```

---

## 🔐 Security Notes

1. **Client Secret:** The client secret (`AhuaZRTwH4wsXHFrmMEciDjo1Kc8aS0M`) should be stored securely in environment variables, never in source code.

2. **Admin Credentials:** Change the default admin password (`admin/secret`) in production.

3. **SSL/TLS:** In production, Keycloak MUST be served over HTTPS.

4. **Token Validation:** Backend MUST validate JWT signatures using the JWKS endpoint.

5. **Tenant Isolation:** Backend MUST extract `company_id` and enforce Row-Level Security in PostgreSQL.

---

## 🚀 Next Steps

### Immediate Actions:
1. ✅ Add user attributes manually (see above)
2. ✅ Test token generation with `./test-token.sh`
3. ✅ Verify custom claims are present in JWT tokens
4. ✅ Share `config/keycloak-config.env` with backend team
5. ✅ Share `keycloak.json` with frontend team

### Backend Integration:
1. Add Keycloak dependencies to Spring Boot
2. Configure JWT validation
3. Implement tenant context extraction
4. Implement user provisioning API endpoints
5. Test multi-tenant data isolation

### Frontend Integration:
1. Install Keycloak React libraries
2. Configure Keycloak provider
3. Implement login/logout flows
4. Add token to API requests
5. Handle token refresh

### Production Deployment:
1. Setup SSL certificates
2. Configure production redirect URIs
3. Change admin passwords
4. Setup SMTP for email verification
5. Configure backup strategy
6. Setup monitoring and logging

---

## 📞 Support & Documentation

### Admin Console
- URL: http://localhost:8090/admin
- Credentials: admin/secret

### Documentation Files
- `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md` - Complete implementation guide
- `docs/KEYCLOAK_NOTES.md` - Quick reference notes
- `docs/SETUP_COMPLETE_README.md` - This file

### Testing
- Run `./test-token.sh` to validate configuration
- Check `config/tokens-*.json` for sample tokens
- Use https://jwt.io to decode and inspect tokens

### Troubleshooting
- If tokens don't contain custom claims, verify user attributes are set
- If authentication fails, check user is enabled and has no required actions
- If CORS errors occur, verify redirect URIs and web origins in client settings

---

## ✅ Checklist

- [x] Keycloak realm created
- [x] Client configured with secret
- [x] 7 custom JWT mappers created
- [x] 5 realm roles created
- [x] 2 test users created
- [ ] **User attributes added manually** (REQUIRED)
- [ ] Token generation tested
- [ ] Custom claims verified in JWT
- [ ] Backend team notified with credentials
- [ ] Frontend team notified with configuration
- [ ] Production deployment planned

---

**Setup completed by:** Claude Code Automated Scripts
**For questions or issues:** Contact the DevOps/Platform team

---

**End of Document**
