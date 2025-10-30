# Keycloak Setup for HRMS SaaS

**Project:** HRMS SaaS Multi-Tenant Application
**Component:** Authentication & Authorization (Keycloak SSO)
**Setup Date:** October 30, 2025
**Status:** ✅ Configured & Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Directory Structure](#directory-structure)
4. [Service Management](#service-management)
5. [Configuration Details](#configuration-details)
6. [Testing](#testing)
7. [Integration](#integration)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This directory contains the complete Keycloak setup for the HRMS SaaS application, including:

- **Automated setup scripts** for realm, client, and mapper configuration
- **Service management scripts** for starting/stopping Keycloak
- **Test scripts** for validating JWT token generation
- **Configuration files** for backend and frontend integration
- **Comprehensive documentation** for all teams

### What's Been Configured

| Component | Status | Details |
|-----------|--------|---------|
| **Keycloak Realm** | ✅ | `hrms-saas` realm with security settings |
| **Client** | ✅ | `hrms-web-app` (OpenID Connect confidential client) |
| **JWT Mappers** | ✅ | 7 custom mappers for multi-tenant claims |
| **Realm Roles** | ✅ | 5 roles (super_admin, company_admin, hr_user, manager, employee) |
| **Test Users** | ✅ | 2 test users with credentials |
| **Documentation** | ✅ | Complete guides and integration docs |

---

## Quick Start

### Prerequisites

- Podman installed and configured
- Keycloak container running on Podman
- `jq` installed (`brew install jq`)

### Start Keycloak

```bash
cd scripts
./start-keycloak.sh
```

### Check Status

```bash
./status-keycloak.sh
```

### Access Admin Console

- **URL:** http://localhost:8090/admin
- **Username:** `admin`
- **Password:** `secret`
- **Realm:** `hrms-saas`

### Test Token Generation

```bash
./test-token.sh employee
```

### Stop Keycloak

```bash
./stop-keycloak.sh
```

---

## Directory Structure

```
keycloak/
├── README.md                          # This file
├── QUICK_START.md                     # Quick reference guide
│
├── scripts/                           # Executable scripts
│   ├── start-keycloak.sh             # ⭐ Start Keycloak service
│   ├── stop-keycloak.sh              # ⭐ Stop Keycloak service
│   ├── status-keycloak.sh            # ⭐ Check service status
│   ├── setup-keycloak.sh             # Initial realm & client setup
│   ├── create-mappers.sh             # Create custom JWT mappers
│   ├── create-test-users.sh          # Create test users
│   ├── test-token.sh                 # Test JWT token generation
│   ├── fix-user-attributes.sh        # Helper to fix user attributes
│   └── run-all.sh                    # Complete automated setup
│
├── config/                            # Generated configuration files
│   ├── keycloak-config.env           # Environment variables (backend)
│   ├── test-users.txt                # Test user credentials
│   └── tokens-*.json                 # Sample JWT tokens
│
└── docs/                              # Documentation
    ├── SETUP_COMPLETE_README.md      # Complete setup guide
    ├── KEYCLOAK_IMPLEMENTATION_GUIDE.md  # Detailed reference (200+ sections)
    └── KEYCLOAK_NOTES.md             # Quick reference notes
```

---

## Service Management

### Start Keycloak

```bash
cd scripts
./start-keycloak.sh
```

**What it does:**
- Checks if Podman machine is running
- Starts Podman machine if needed
- Starts Keycloak container (`nexus-keycloak-dev`)
- Waits for Keycloak to be ready
- Displays access information

**Output:**
```
Keycloak is running!

Access Points:
  • Admin Console: http://localhost:8090/admin
  • Realm: hrms-saas
  • Credentials: admin/secret
```

### Stop Keycloak

```bash
./stop-keycloak.sh
```

**What it does:**
- Stops the Keycloak container gracefully
- Displays final status

### Check Status

```bash
./status-keycloak.sh
```

**What it does:**
- Checks Podman machine status
- Checks container status
- Verifies Keycloak is responding
- Checks realm accessibility
- Displays access information and endpoints

**Sample Output:**
```
Podman Machine Status:
[✓] Podman machine is running

Keycloak Container Status:
[✓] Keycloak container is running

Keycloak Health Check:
[✓] Keycloak is responding (HTTP 302)

Realm Configuration:
[✓] Realm 'hrms-saas' is accessible
```

---

## Configuration Details

### Realm Information

| Property | Value |
|----------|-------|
| **Realm Name** | hrms-saas |
| **Display Name** | HRMS SaaS Platform |
| **Access Token Lifespan** | 30 minutes |
| **SSO Session Idle** | 1 hour |
| **SSO Session Max** | 10 hours |
| **Brute Force Protection** | Enabled (5 attempts) |

### Client Information

| Property | Value |
|----------|-------|
| **Client ID** | hrms-web-app |
| **Client UUID** | c86500ff-9171-41f9-94a8-874455925c71 |
| **Client Secret** | AhuaZRTwH4wsXHFrmMEciDjo1Kc8aS0M |
| **Client Type** | Confidential (OpenID Connect) |
| **Authentication Flow** | Standard Flow + Direct Access Grants |
| **Redirect URIs** | localhost:3000/*, localhost:3001/* |

### Custom JWT Mappers

These mappers add custom claims to JWT tokens for multi-tenant support:

| Mapper Name | Claim Name | Source | Purpose |
|-------------|------------|--------|---------|
| company_id | company_id | User attribute | Tenant UUID for RLS |
| tenant_id | tenant_id | User attribute | Alias for company_id |
| employee_id | employee_id | User attribute | Employee UUID |
| user_type | user_type | User attribute | Role category |
| company_code | company_code | User attribute | Company code |
| company_name | company_name | User attribute | Company name |
| phone | phone | User attribute | Phone number |

### Realm Roles

| Role | Description | Use Case |
|------|-------------|----------|
| super_admin | System administrator | Platform admins, support team |
| company_admin | Company administrator | HR head, company owner |
| hr_user | HR department user | HR managers, HR executives |
| manager | Team manager | Department managers, team leads |
| employee | Regular employee | All employees (default role) |

### Test Users

| Username | Password | Role | Company ID |
|----------|----------|------|------------|
| admin@testcompany.com | TestAdmin@123 | company_admin | 550e8400-e29b-41d4-a716-446655440000 |
| john.doe@testcompany.com | TestUser@123 | employee | 550e8400-e29b-41d4-a716-446655440000 |

---

## Testing

### Test JWT Token Generation

```bash
cd scripts

# Test employee user (default)
./test-token.sh employee

# Test admin user
./test-token.sh admin

# Test specific user
./test-token.sh username@domain.com
```

### What the Test Does

1. Authenticates user with Keycloak
2. Retrieves access token and refresh token
3. Decodes JWT payload
4. Verifies all custom claims are present
5. Tests token refresh
6. Saves tokens to `config/tokens-*.json`

### Expected Token Claims

```json
{
  "exp": 1698767232,
  "iat": 1698765432,
  "iss": "http://localhost:8090/realms/hrms-saas",
  "aud": "hrms-web-app",
  "sub": "user-uuid",

  "email": "john.doe@testcompany.com",
  "preferred_username": "john.doe@testcompany.com",

  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "employee_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_type": "employee",
  "company_code": "TEST001",
  "company_name": "Test Company Ltd",

  "realm_access": {
    "roles": ["employee"]
  }
}
```

---

## Integration

### Backend Integration (Spring Boot)

**Configuration File:** `config/keycloak-config.env`

```bash
# Source in your application
source config/keycloak-config.env
```

**Key Variables:**
```bash
KEYCLOAK_URL=http://localhost:8090
KEYCLOAK_REALM=hrms-saas
KEYCLOAK_CLIENT_ID=hrms-web-app
KEYCLOAK_CLIENT_SECRET=AhuaZRTwH4wsXHFrmMEciDjo1Kc8aS0M
KEYCLOAK_JWKS_URL=http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs
KEYCLOAK_ISSUER=http://localhost:8090/realms/hrms-saas
```

**Implementation Steps:**
1. Add Spring Boot Keycloak dependencies
2. Configure JWT decoder with JWKS URL
3. Extract `company_id` from JWT claims
4. Set PostgreSQL tenant context
5. Implement user provisioning via Admin API

**Documentation:** See `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md` Section 11

### Frontend Integration (React)

**Configuration:**
```json
{
  "realm": "hrms-saas",
  "url": "http://localhost:8090",
  "clientId": "hrms-web-app"
}
```

**Installation:**
```bash
npm install keycloak-js @react-keycloak/web
```

**Documentation:** See `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md` Section 11

---

## Troubleshooting

### Keycloak Won't Start

**Problem:** Container fails to start

**Solutions:**
```bash
# Check Podman machine
podman machine list
podman machine start podman-machine-default

# Check container logs
podman logs nexus-keycloak-dev

# Restart container
./stop-keycloak.sh
./start-keycloak.sh
```

### Can't Access Admin Console

**Problem:** http://localhost:8090/admin not accessible

**Solutions:**
```bash
# Check if Keycloak is running
./status-keycloak.sh

# Check port mapping
podman ps --filter name=nexus-keycloak-dev

# Verify port 8090 is not in use
lsof -i :8090
```

### Custom Claims Missing from JWT

**Problem:** JWT tokens don't contain company_id, tenant_id, etc.

**Solutions:**
1. Verify user attributes are set in Admin Console
2. Check mappers are configured correctly
3. Verify mappers are set to add claims to access token
4. Test with `./test-token.sh`

**Manual Fix:**
1. Open http://localhost:8090/admin
2. Go to Users → Select user → Attributes tab
3. Add required attributes (see Configuration Details section)

### Authentication Fails

**Problem:** User cannot login

**Possible Causes:**
- User not enabled
- Email not verified (if required)
- Required actions pending
- Wrong password

**Solutions:**
```bash
# Check user status in Admin Console
# Ensure "Enabled" is ON
# Ensure "Email Verified" is ON
# Ensure "Required Actions" is empty
```

### Token Validation Fails in Backend

**Problem:** Backend rejects valid tokens

**Solutions:**
1. Verify JWKS URL is accessible from backend
2. Check issuer claim matches exactly
3. Verify clock sync between servers
4. Check client secret if using confidential client

---

## Important Notes

### Security

- ⚠️ **Production:** Change default admin password (`admin/secret`)
- ⚠️ **Production:** Use HTTPS for Keycloak
- ⚠️ **Client Secret:** Store securely, never in source code
- ⚠️ **Tenant Isolation:** Always extract and validate `company_id` from JWT

### User Attributes

- User attributes must be added manually via Admin Console
- Attributes are required for JWT custom claims
- Without attributes, multi-tenant isolation won't work

### Backup & Recovery

```bash
# Backup Keycloak data
podman exec nexus-keycloak-dev /opt/keycloak/bin/kc.sh export --dir /tmp/keycloak-backup --realm hrms-saas

# Export configuration
podman cp nexus-keycloak-dev:/tmp/keycloak-backup ./backup/
```

---

## Quick Reference Commands

```bash
# Service Management
./scripts/start-keycloak.sh          # Start Keycloak
./scripts/stop-keycloak.sh           # Stop Keycloak
./scripts/status-keycloak.sh         # Check status

# Testing
./scripts/test-token.sh employee     # Test JWT tokens
./scripts/test-token.sh admin        # Test admin user

# Initial Setup (already done)
./scripts/setup-keycloak.sh          # Create realm & client
./scripts/create-mappers.sh          # Create JWT mappers
./scripts/create-test-users.sh       # Create test users
./scripts/run-all.sh                 # Complete automated setup

# Podman Commands
podman ps                            # List running containers
podman logs nexus-keycloak-dev       # View Keycloak logs
podman restart nexus-keycloak-dev    # Restart container
```

---

## Documentation Files

| File | Purpose | When to Read |
|------|---------|--------------|
| `README.md` | Main documentation (this file) | Start here |
| `QUICK_START.md` | Quick reference guide | For quick access |
| `docs/SETUP_COMPLETE_README.md` | Complete setup details | After initial setup |
| `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md` | Detailed reference (200+ sections) | During integration |
| `docs/KEYCLOAK_NOTES.md` | Team-specific quick notes | For daily reference |

---

## Support

### Access Information
- **Admin Console:** http://localhost:8090/admin
- **Credentials:** admin/secret
- **Realm:** hrms-saas

### Useful Links
- **Keycloak Documentation:** https://www.keycloak.org/documentation
- **JWT Decoder:** https://jwt.io
- **Project Docs:** `docs/` directory

### Scripts Location
All management and testing scripts are in: `scripts/`

---

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-30 | 1.0 | Initial automated setup completed |
| 2025-10-30 | 1.1 | Added service management scripts |
| 2025-10-30 | 1.2 | Added comprehensive documentation |

---

**Maintained by:** Platform Team
**Last Updated:** October 30, 2025
**Status:** ✅ Production Ready (after user attribute setup)

---

