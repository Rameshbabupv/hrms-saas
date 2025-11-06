# Complete Schema Application Guide

## 📋 Overview

This guide explains how to apply the complete HRMS SaaS database schema to your PostgreSQL database.

---

## 🎯 Current Status

Your database currently has:
- ✅ **Spring Boot Schema** (via Flyway migrations)
  - `company_master` table - Managed by Spring Boot
  - `flyway_schema_history` - Migration tracking
  - 2 companies registered

- ❌ **Complete HRMS Schema** (Not yet applied)
  - 6 Core business tables
  - 6 Audit & compliance tables
  - Row-Level Security (RLS) policies

---

## 🗂️ What Will Be Applied

### Core Business Tables (6)

1. **company** - Multi-tenant company master with corporate hierarchy
   - Support for parent-subsidiary relationships
   - Corporate group management
   - Flexible subscription billing

2. **employee** - Complete employee information
   - Personal details
   - Employment information
   - Statutory compliance (PAN, Aadhaar, PF, ESI)
   - Banking details
   - Document URLs

3. **employee_education** - Education history
   - Degree, institution, specialization
   - Year of passing, percentage

4. **employee_experience** - Work experience
   - Previous employers
   - Designations and responsibilities

5. **department_master** - Shared departments
   - Corporate group sharing support
   - Owner company tracking

6. **designation_master** - Shared designations
   - Corporate group sharing support
   - Owner company tracking

### Audit & Compliance Tables (6)

1. **audit_log** - General audit logging
   - WHO, WHAT, WHEN, WHERE tracking
   - Old and new values
   - Request tracing

2. **user_activity_log** - User session tracking
   - Login/logout events
   - Device and location information
   - Session duration

3. **api_audit_log** - API request tracking
   - Endpoint and method
   - Response times
   - GraphQL operation tracking

4. **data_change_history** - Detailed change snapshots
   - Complete before/after snapshots
   - Version tracking
   - Approval workflow support

5. **security_event_log** - Security violations
   - Failed login attempts
   - Unauthorized access
   - SQL injection attempts

6. **compliance_audit_trail** - GDPR/SOC2 compliance
   - Data export tracking
   - Consent management
   - Data deletion tracking

### Additional Features

- **Row-Level Security (RLS)** policies for all core tables
- **Helper function**: `set_current_tenant(tenant_uuid UUID)`
- **40+ Indexes** for performance
- **Custom enums** for status, gender, employment type, etc.
- **Complete constraints** for data integrity

---

## 🚀 Quick Start

### Option 1: Use the Script (Recommended)

```bash
# 1. Make sure database is running
./bin/db-start.sh

# 2. Apply the complete schema
./bin/apply-complete-schema.sh

# 3. Verify the schema
./bin/db-status.sh
```

### Option 2: Manual Application

```bash
# 1. Apply core schema
cat postgres-docs/schemas/saas_mvp_schema_v2_with_hierarchy.sql | \
  podman exec -i nexus-postgres-dev psql -U admin -d hrms_saas

# 2. Apply audit schema
cat postgres-docs/schemas/saas_mvp_audit_schema.sql | \
  podman exec -i nexus-postgres-dev psql -U admin -d hrms_saas

# 3. Optional: Load sample data
cat scripts/02_sample_data.sql | \
  podman exec -i nexus-postgres-dev psql -U admin -d hrms_saas
```

---

## 📊 Script Features

The `apply-complete-schema.sh` script provides:

✅ **Pre-flight Checks**
- Verifies container is running
- Checks database accessibility
- Validates schema files exist

✅ **Automatic Backup**
- Creates timestamped backup before applying
- Stored in `/tmp/hrms_saas_backup_YYYYMMDD_HHMMSS.sql`

✅ **Step-by-Step Application**
- Core schema (v2 with hierarchy)
- Audit schema
- Optional sample data

✅ **Error Handling**
- Detailed error messages
- Shows last 20 lines on failure
- Provides rollback instructions

✅ **Status Reports**
- Before and after table counts
- RLS status for all tables
- Complete table listing

---

## ⚠️ Important Considerations

### Data Preservation

- **company_master table**: Will remain untouched (Spring Boot managed)
- **Existing companies**: Your 2 registered companies will be preserved
- **Flyway history**: Migration tracking table remains

### Schema Coexistence

The complete schema adds new tables alongside the existing Spring Boot tables:

```
Current:                    After Application:
├── company_master         ├── company_master (Spring Boot)
└── flyway_schema_history  ├── flyway_schema_history
                           ├── company (Legacy schema)
                           ├── employee
                           ├── employee_education
                           ├── employee_experience
                           ├── department_master
                           ├── designation_master
                           ├── audit_log
                           ├── user_activity_log
                           ├── api_audit_log
                           ├── data_change_history
                           ├── security_event_log
                           └── compliance_audit_trail
```

### RLS Policies

Row-Level Security will be enabled on:
- `company`
- `employee`
- `department_master`
- `designation_master`

**Note**: `company_master` (Spring Boot table) does not have RLS by default.

---

## 🔍 Verification

After applying the schema, verify with:

### Check Table Count
```bash
podman exec nexus-postgres-dev psql -U admin -d hrms_saas -c "
  SELECT count(*) as total_tables
  FROM pg_tables
  WHERE schemaname = 'public';
"
```

Expected: **14 tables** (12 new + 2 existing)

### Check RLS Status
```bash
podman exec nexus-postgres-dev psql -U admin -d hrms_saas -c "
  SELECT
    tablename,
    CASE WHEN rowsecurity THEN 'Enabled' ELSE 'Disabled' END as rls
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY tablename;
"
```

### Check Sample Data (if loaded)
```bash
podman exec nexus-postgres-dev psql -U admin -d hrms_saas -c "
  SET row_security = OFF;
  SELECT
    (SELECT count(*) FROM company) as companies,
    (SELECT count(*) FROM employee) as employees,
    (SELECT count(*) FROM department_master) as departments,
    (SELECT count(*) FROM designation_master) as designations;
"
```

---

## 🔄 Rollback

If something goes wrong, restore from the automatic backup:

```bash
# Find the backup file
ls -lh /tmp/hrms_saas_backup_*.sql

# Restore from backup
cat /tmp/hrms_saas_backup_20250105_143022.sql | \
  podman exec -i nexus-postgres-dev psql -U admin -d hrms_saas
```

---

## 📝 Step-by-Step Walkthrough

### Step 1: Pre-Application Check

```bash
# Check database is running
./bin/db-status.sh

# Should show:
# - Container: Running
# - Database: Accessible
# - Tables: 2
# - Companies: 2
```

### Step 2: Run the Script

```bash
./bin/apply-complete-schema.sh
```

**Expected prompts:**
1. Warning about schema application → Answer `y`
2. Load sample data? → Answer `y` or `n`

**Expected output:**
```
✅ Backup created: /tmp/hrms_saas_backup_20250105_143022.sql (7.5K)
✅ Core schema applied successfully
✅ Audit schema applied successfully
✅ Sample data loaded successfully (if chosen)

Total Tables: 14
```

### Step 3: Verify Application

```bash
# Check comprehensive status
./bin/db-status.sh

# View companies (if sample data loaded)
./bin/view-companies.sh

# View employees (if sample data loaded)
./bin/view-employees.sh
```

---

## 🎯 Sample Data

If you choose to load sample data, you'll get:

### Companies (4)
1. **ABC Holdings** - Holding company (parent)
2. **ABC Manufacturing** - Subsidiary of ABC Holdings
3. **ABC Services** - Subsidiary of ABC Holdings
4. **Demo Tech Solutions** - Independent company

### Employees (8)
- 2 employees in ABC Holdings
- 3 employees in ABC Manufacturing
- 2 employees in ABC Services
- 1 employee in Demo Tech Solutions

### Departments (5)
- Human Resources
- Information Technology
- Finance & Accounts
- Operations
- Marketing & Sales

### Designations (6)
- CEO (Chief Executive Officer)
- CFO (Chief Financial Officer)
- CTO (Chief Technology Officer)
- Manager
- Executive
- Assistant

---

## 🔗 Integration with Spring Boot

### Two Table Sets

After applying the schema, you'll have two sets of tables:

#### Set 1: Spring Boot Tables (Flyway Managed)
- `company_master` - Your application uses this
- Managed by Flyway migrations
- No RLS policies
- Your existing 2 companies

#### Set 2: Legacy Schema Tables
- `company`, `employee`, etc.
- Complete HRMS schema
- RLS policies enabled
- Optional sample data

### Usage Recommendation

**Option A: Migrate to Legacy Schema**
- Use the `company` table instead of `company_master`
- Benefit from RLS policies
- Corporate hierarchy support
- Requires Spring Boot migration

**Option B: Keep Both**
- Use `company_master` for authentication
- Use legacy tables for HRMS features
- Maintain separate data sets

**Option C: Use Spring Boot Schema Only**
- Don't apply the legacy schema
- Add required tables via Flyway migrations
- Keep everything under Spring Boot control

---

## 🚨 Troubleshooting

### Issue: "Table already exists"

**Cause**: Schema was partially applied before

**Solution**:
```bash
# Check which tables exist
podman exec nexus-postgres-dev psql -U admin -d hrms_saas -c "\dt"

# If you want to reapply, drop existing tables first (CAUTION!)
# Only do this if you're sure!
```

### Issue: "Permission denied"

**Cause**: Script not executable

**Solution**:
```bash
chmod +x bin/apply-complete-schema.sh
```

### Issue: "Container not running"

**Solution**:
```bash
./bin/db-start.sh
```

### Issue: Schema application failed

**Solution**:
1. Check error messages in output
2. Restore from backup:
   ```bash
   cat /tmp/hrms_saas_backup_*.sql | \
     podman exec -i nexus-postgres-dev psql -U admin -d hrms_saas
   ```
3. Review schema file for issues
4. Try manual application

---

## 📚 Additional Resources

### Documentation
- **Complete Schema**: `postgres-docs/schemas/saas_mvp_schema_v2_with_hierarchy.sql`
- **Audit Schema**: `postgres-docs/schemas/saas_mvp_audit_schema.sql`
- **DBA Guide**: `postgres-docs/DBA_NOTES.md`
- **Database README**: `README.md`

### Scripts
- **Apply Schema**: `./bin/apply-complete-schema.sh`
- **View Status**: `./bin/db-status.sh`
- **View Companies**: `./bin/view-companies.sh`
- **View Employees**: `./bin/view-employees.sh`

### Memory Files
- `hrms-saas-database-schema-complete` - Complete reference
- `hrms-saas-development-guide` - Development patterns
- `hrms-saas-springboot-backend` - Backend integration

---

## ✅ Success Checklist

After applying the schema, verify:

- [ ] Database is running
- [ ] Schema script executed without errors
- [ ] Backup file created
- [ ] 14 tables exist (12 new + 2 existing)
- [ ] RLS enabled on core tables
- [ ] Sample data loaded (if chosen)
- [ ] company_master table still has 2 companies
- [ ] `./bin/db-status.sh` shows all tables
- [ ] `./bin/view-companies.sh` works (if sample data)
- [ ] `./bin/view-employees.sh` works (if sample data)

---

## 🎯 Next Steps

After successful schema application:

1. **Review the Schema**
   - Explore tables with `\d table_name`
   - Check RLS policies with `\d+ table_name`
   - Review constraints and indexes

2. **Understand the Data Model**
   - Read `postgres-docs/DBA_NOTES.md`
   - Review `hrms-saas-database-schema-complete` memory

3. **Plan Integration**
   - Decide: Use legacy schema or Spring Boot schema?
   - Plan data migration if needed
   - Update Spring Boot entities

4. **Test Multi-Tenancy**
   - Test RLS policies
   - Verify tenant isolation
   - Test parent-subsidiary access

---

**Last Updated**: November 5, 2025
**Schema Version**: 2.0 (with Corporate Hierarchy)
**Status**: ✅ Ready to Apply
