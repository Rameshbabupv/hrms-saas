# Keycloak Realm Export - hrms-saas

**Export Date:** November 5, 2025  
**Export Time:** 19:59 EST  
**Keycloak Version:** 26.3.4

## Export Contents

This directory contains a complete backup of the Keycloak `hrms-saas` realm including all configuration, users, roles, and custom attributes.

### Files Included

1. **hrms-saas-realm-export.json** (63 KB)
   - Complete realm configuration
   - 7 OAuth clients
   - 8 realm roles
   - Client configurations and scopes
   - Protocol mappers
   - Authentication flows
   - Does NOT include user credentials or user data

2. **hrms-saas-users.json** (12 KB)
   - Basic user information for all 5 users
   - Username, email, enabled status
   - User IDs for reference

3. **hrms-saas-users-detailed.json** (2.2 KB)
   - Complete user data including:
     - User profiles (username, email, first name, last name)
     - Custom attributes (company_id, tenant_id, employee_id, etc.)
     - Email verification status
     - User roles and group memberships
   - **5 Users Total**

4. **keycloakdb-backup.mv.db** (1.7 MB)
   - Direct H2 database backup
   - Contains everything including passwords (hashed)
   - Can be restored by replacing the H2 database file

## Exported Configuration Summary

- **Realm:** hrms-saas
- **Total Users:** 5
- **Total Clients:** 7
- **Total Roles:** 8
- **Groups:** 0

## Users Exported

1. **admin@systech.com** - No custom attributes
2. **admin@testcompany.com** - No custom attributes
3. **alice@techstart.com** - No custom attributes
4. **john.doe@testcompany.com** - No custom attributes
5. **ramesh.babu@systech.com** - Full multi-tenant attributes:
   - company_id: a1lrqfv7lj7h
   - tenant_id: a1lrqfv7lj7h
   - company_name: Systech
   - company_code: SYST001
   - user_type: company_admin

## How to Import

### Option 1: Import Realm Configuration Only
```bash
# Copy realm export to Keycloak container
podman cp hrms-saas-realm-export.json nexus-keycloak-dev:/tmp/

# Import (will NOT include user passwords)
podman exec nexus-keycloak-dev /opt/keycloak/bin/kc.sh import \
  --file /tmp/hrms-saas-realm-export.json
```

### Option 2: Restore H2 Database (Complete Restore)
```bash
# Stop Keycloak
./scripts/stop-keycloak.sh

# Backup current database
podman cp nexus-keycloak-dev:/opt/keycloak/data/h2/keycloakdb.mv.db ./keycloakdb-old.mv.db

# Restore from backup
podman cp keycloakdb-backup.mv.db nexus-keycloak-dev:/opt/keycloak/data/h2/keycloakdb.mv.db

# Start Keycloak
./scripts/start-keycloak.sh
```

### Option 3: Recreate Users with Attributes (Manual)
Use the `hrms-saas-users-detailed.json` file to recreate users via:
- Keycloak Admin Console
- REST API
- Setup scripts

## Important Notes

### Password Export Limitation
- The JSON exports (realm-export, users.json, users-detailed.json) do **NOT** include user passwords
- Passwords are only preserved in the H2 database backup (keycloakdb-backup.mv.db)
- When importing JSON files, you will need to reset user passwords

### Custom Attributes
- User custom attributes (company_id, tenant_id, etc.) are fully exported
- These are preserved in both the users-detailed.json and H2 database backup

### Multi-Tenant Claims
The realm is configured with custom protocol mappers that add JWT claims:
- company_id
- tenant_id
- employee_id
- company_name
- company_code

These mappers are included in the realm export.

## Recommended Restore Strategy

**For Production/QA Deployment:**
1. Use `hrms-saas-realm-export.json` to create the realm configuration
2. Manually recreate users or use REST API with `hrms-saas-users-detailed.json`
3. Set new passwords for all users
4. Verify JWT token claims are working

**For Development/Testing:**
1. Use `keycloakdb-backup.mv.db` to restore everything including passwords
2. This is the fastest option and preserves all data

## Export Commands Used

```bash
# Realm export via REST API
curl -X POST "http://localhost:8090/admin/realms/hrms-saas/partial-export?exportClients=true&exportGroupsAndRoles=true" \
  -H "Authorization: Bearer $TOKEN" \
  -o hrms-saas-realm-export.json

# User export
curl -X GET "http://localhost:8090/admin/realms/hrms-saas/users" \
  -H "Authorization: Bearer $TOKEN" \
  -o hrms-saas-users.json

# Detailed user export (per user)
curl -X GET "http://localhost:8090/admin/realms/hrms-saas/users/{user-id}" \
  -H "Authorization: Bearer $TOKEN"

# H2 database backup
podman cp nexus-keycloak-dev:/opt/keycloak/data/h2/keycloakdb.mv.db ./keycloakdb-backup.mv.db
```

## Next Steps

This export package can be used for:
1. **QA Deployment:** Import realm and recreate users
2. **Backup/Disaster Recovery:** Restore H2 database
3. **Migration:** Move to different Keycloak instance or PostgreSQL
4. **Documentation:** Review configuration and user setup

---
**Generated:** November 5, 2025 by Claude Code
