# Keycloak Import Guide

This guide explains how to import the exported Keycloak data back into a Keycloak instance.

## Import Scripts

Three automated import scripts are provided:

### 1. Complete H2 Database Restore (Recommended for Development)

**Script:** `import-h2-database.sh`

**What it imports:**
- ✅ Complete realm configuration
- ✅ All users with passwords (hashed)
- ✅ All custom attributes
- ✅ All roles, clients, and settings
- ✅ Everything!

**Usage:**
```bash
./import-h2-database.sh
```

**When to use:**
- Development/testing environments
- Quick full restore
- When you need passwords preserved

**Prerequisites:**
- Keycloak container must exist
- Running from the exports directory

---

### 2. Realm Configuration Only

**Script:** `import-realm-config.sh`

**What it imports:**
- ✅ Realm settings
- ✅ 7 OAuth clients with configurations
- ✅ 8 realm roles
- ✅ Protocol mappers (JWT claims)
- ✅ Authentication flows
- ❌ Does NOT import users or passwords

**Usage:**
```bash
./import-realm-config.sh
```

**When to use:**
- Production/QA environments
- When setting up a new Keycloak instance
- When you want to create users manually

**Prerequisites:**
- Keycloak must be running
- Running from the exports directory

---

### 3. Users with Attributes

**Script:** `import-users-with-attributes.sh`

**What it imports:**
- ✅ User profiles (username, email, first name, last name)
- ✅ Custom attributes (company_id, tenant_id, employee_id, etc.)
- ✅ Email verification status
- ❌ Does NOT import passwords

**Usage:**
```bash
./import-users-with-attributes.sh
```

**When to use:**
- After importing realm configuration
- When you need users with custom attributes
- Production/QA environments

**Prerequisites:**
- Realm 'hrms-saas' must already exist
- Keycloak must be running
- Running from the exports directory

---

## Import Strategies

### Strategy 1: Development/Testing (Fastest)
Use complete H2 database restore:

```bash
# One command - everything restored
./import-h2-database.sh
```

**Result:** Complete Keycloak setup with all users and passwords

---

### Strategy 2: Production/QA (Recommended)
Import configuration first, then users:

```bash
# Step 1: Import realm configuration
./import-realm-config.sh

# Step 2: Import users with attributes
./import-users-with-attributes.sh

# Step 3: Set passwords manually or via API
```

**Result:** Clean setup with ability to set new passwords

---

### Strategy 3: Manual Import via Admin Console

1. **Import Realm:**
   - Open Admin Console: http://localhost:8090/admin
   - Click "Create Realm"
   - Upload `hrms-saas-realm-export.json`

2. **Create Users Manually:**
   - Use `hrms-saas-users-detailed.json` as reference
   - Go to Users → Add User
   - Add custom attributes from the JSON file

---

## Exported Files Reference

| File | Size | Contains |
|------|------|----------|
| `hrms-saas-realm-export.json` | 63 KB | Realm config, clients, roles, mappers |
| `hrms-saas-users-detailed.json` | 2.2 KB | 5 users with attributes (NO passwords) |
| `hrms-saas-users.json` | 12 KB | Basic user info |
| `keycloakdb-backup.mv.db` | 1.7 MB | Complete H2 database (WITH passwords) |

---

## Important Notes

### Password Handling

- **JSON exports** do NOT include passwords
- **H2 database** includes passwords (hashed with bcrypt)
- After importing JSON, users must reset passwords

### Custom Attributes Preserved

All custom user attributes are preserved in both:
- `hrms-saas-users-detailed.json`
- `keycloakdb-backup.mv.db`

Attributes included:
- `company_id`
- `tenant_id`
- `employee_id`
- `company_name`
- `company_code`
- `user_type`

### JWT Claims

The realm export includes protocol mappers that add these JWT claims:
- company_id
- tenant_id
- employee_id
- company_name
- company_code

These will be automatically configured after realm import.

---

## Troubleshooting

### Script Fails with "Container not found"
```bash
# Check if container exists
podman ps -a | grep nexus-keycloak-dev

# If not, you need to create the container first
```

### Script Fails with "Keycloak not accessible"
```bash
# Start Keycloak
podman start nexus-keycloak-dev

# Wait a few seconds, then check
curl http://localhost:8090
```

### "Realm already exists" Error
```bash
# Option 1: Delete existing realm via Admin Console
# Option 2: Export current realm first as backup
# Option 3: Skip realm import if configuration is already correct
```

### Users Not Importing
```bash
# Make sure realm was imported first
./import-realm-config.sh

# Then import users
./import-users-with-attributes.sh
```

---

## Verification Steps

After import, verify the setup:

### 1. Check Realm Configuration
```bash
curl -s http://localhost:8090/realms/hrms-saas/.well-known/openid-configuration | jq .
```

### 2. Check Users
- Open: http://localhost:8090/admin/master/console/#/hrms-saas/users
- Verify all 5 users are present
- Check custom attributes for `ramesh.babu@systech.com`

### 3. Test JWT Token
```bash
# Get token for user with attributes
curl -X POST "http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token" \
  -d "client_id=hrms-web-app" \
  -d "username=ramesh.babu@systech.com" \
  -d "password=YOUR_PASSWORD" \
  -d "grant_type=password"

# Decode token and verify claims (company_id, tenant_id, etc.)
```

---

## Quick Reference

```bash
# Complete restore (with passwords)
./import-h2-database.sh

# Production setup
./import-realm-config.sh
./import-users-with-attributes.sh

# Check all files
ls -lh

# View documentation
cat EXPORT_README.md
cat IMPORT_GUIDE.md
```

---

**Need Help?**
- Check `EXPORT_README.md` for export details
- Review script output for specific errors
- Verify Keycloak logs: `podman logs nexus-keycloak-dev`
