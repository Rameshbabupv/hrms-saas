# HRMS SaaS Database Setup Status

**Date:** 2025-10-30
**DBA:** Claude (AI Assistant)
**Database:** hrms_saas
**PostgreSQL Version:** 16
**Container:** nexus-postgres-dev

---

## ✅ Completed Tasks

### 1. Database Creation
- ✅ **Database:** `hrms_saas` created successfully
- ✅ **Encoding:** UTF8
- ✅ **Locale:** en_US.utf8
- ✅ **Status:** Running on localhost:5432

### 2. User Management
- ✅ **Application User:** `hrms_app` created
- ✅ **Password:** `HrmsApp@2025`
- ✅ **Permissions:** Full privileges on `hrms_saas` database
- ✅ **Schema Access:** Granted on public schema
- ✅ **Default Privileges:** Configured for tables and sequences

### 3. Extensions
- ✅ **uuid-ossp** (version 1.1) - For UUID generation
- ✅ **pgcrypto** (version 1.3) - For encryption functions

### 4. Schema Deployment
#### Core Tables (6 tables)
- ✅ `company` - Tenant/customer master with corporate hierarchy support
- ✅ `employee` - Employee master with multi-tenant isolation
- ✅ `department_master` - Shared department master data
- ✅ `designation_master` - Shared designation master data
- ✅ `employee_education` - Employee education history
- ✅ `employee_experience` - Employee work experience

#### Audit Tables (6 tables)
- ✅ `audit_log` - General audit logging
- ✅ `user_activity_log` - User login/logout tracking
- ✅ `api_audit_log` - API request/response logging
- ✅ `data_change_history` - Detailed before/after snapshots
- ✅ `security_event_log` - Security events tracking
- ✅ `compliance_audit_trail` - GDPR/SOC2 compliance audit

**Total Tables:** 12

###5. Custom Types (ENUMs)
- ✅ `status_type` - active, inactive, deleted
- ✅ `gender_type` - male, female, other
- ✅ `employment_type` - permanent, contract, consultant, intern, temporary
- ✅ `marital_status_type` - single, married, divorced, widowed
- ✅ `company_type` - holding, subsidiary, independent
- ✅ `subscription_paid_by` - self, parent, external
- ✅ `audit_action` - INSERT, UPDATE, DELETE, SELECT, TRUNCATE
- ✅ `event_severity` - INFO, WARNING, ERROR, CRITICAL
- ✅ `event_category` - AUTHENTICATION, AUTHORIZATION, DATA_ACCESS, etc.

### 6. Row-Level Security (RLS)
#### RLS Policies Created
- ✅ `employee_tenant_isolation` - Users see own company + subsidiaries
- ✅ `employee_tenant_modification` - Users can only modify own company
- ✅ `company_tenant_isolation` - Users see own + subsidiaries + parent
- ✅ `department_access` - Users see own + shared departments
- ✅ `designation_access` - Users see own + shared designations

#### RLS Status
| Table | RLS Enabled | Policies |
|-------|-------------|----------|
| company | ✅ Yes | 1 policy |
| employee | ✅ Yes | 2 policies |
| department_master | ✅ Yes | 1 policy |
| designation_master | ✅ Yes | 1 policy |

### 7. Helper Functions
- ✅ `set_current_tenant(tenant_id)` - Set tenant context for RLS
- ✅ `get_employee_count(tenant_id, include_subs)` - Get employee count
- ✅ `get_subsidiary_companies(parent_id)` - Get subsidiaries
- ✅ `is_parent_company(company_id)` - Check if company is parent
- ✅ `get_corporate_group_summary(group_name)` - Group statistics
- ✅ `update_timestamp()` - Auto-update timestamps
- ✅ `validate_company_hierarchy()` - Enforce 2-level hierarchy
- ✅ `log_audit_entry()` - Manual audit logging
- ✅ `log_data_change_history()` - Detailed change tracking
- ✅ `purge_old_audit_logs()` - Cleanup old audit data
- ✅ `get_audit_statistics()` - Audit statistics

### 8. Indexes
**Total Indexes Created:** 40+ indexes for performance optimization

Key indexes on:
- company_id (for tenant filtering)
- employee_code, email (for lookups)
- status, is_active (for filtering)
- Audit timestamps (for log queries)
- Foreign keys (for joins)

---

## ⚠️ Known Issues

### Issue #1: Audit Trigger Function Type Mismatch
**Status:** 🔴 **CRITICAL - Blocking Data Loading**

**Problem:**
- The audit trigger function `trigger_audit_log()` has a type casting issue
- It passes `TG_TABLE_NAME` (type: `name`) to `log_audit_entry()` which expects `VARCHAR`
- This causes all INSERT/UPDATE/DELETE operations on company, employee, department_master, and designation_master to fail

**Error Message:**
```
ERROR:  function log_audit_entry(name, uuid, audit_action, jsonb, jsonb, unknown) does not exist
HINT:  No function matches the given name and argument types. You might need to add explicit type casts.
```

**Impact:**
- ❌ Cannot insert companies
- ❌ Cannot insert employees
- ❌ Cannot insert master data
- ❌ Sample data loading fails

**Root Cause:**
- The audit schema SQL file creates triggers that reference `TG_TABLE_NAME` without proper type casting
- When we try to fix it, the old trigger function persists even after DROP/CREATE

**Workaround:**
1. Drop all audit triggers temporarily:
   ```sql
   DROP TRIGGER IF EXISTS audit_company_changes ON company;
   DROP TRIGGER IF EXISTS audit_employee_changes ON employee;
   DROP TRIGGER IF EXISTS audit_department_changes ON department_master;
   DROP TRIGGER IF EXISTS audit_designation_changes ON designation_master;
   ```

2. Load sample data

3. Recreate triggers with fixed function

**Permanent Fix Required:**
- Update the audit schema SQL file to include proper type casting: `TG_TABLE_NAME::VARCHAR`
- Test thoroughly before deploying

---

## 📊 Current Database State

### Tables Summary
```sql
-- Run this to see current state:
SELECT
    schemaname,
    tablename,
    rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

### Data Summary
| Category | Count |
|----------|-------|
| Companies | 0 |
| Employees | 0 |
| Departments | 0 |
| Designations | 0 |
| Audit Logs | 2 (sample from audit schema) |

**Note:** No production data loaded yet due to trigger issue.

---

## 🎯 Next Steps

### Immediate Priority
1. ✅ Document current state (this file)
2. ⏳ Fix audit trigger function
3. ⏳ Load sample test data
4. ⏳ Test RLS policies with different tenant contexts
5. ⏳ Verify multi-tenant isolation

### Short-term Tasks
1. Create database maintenance scripts
2. Set up automated backup procedures
3. Create monitoring queries/views
4. Write troubleshooting runbooks
5. Document connection strings for backend team

### Testing Checklist
- [ ] Insert data for multiple companies
- [ ] Test RLS: Parent can see subsidiaries
- [ ] Test RLS: Subsidiary cannot see siblings
- [ ] Test RLS: Independent companies are isolated
- [ ] Test shared master data access
- [ ] Test employee reporting hierarchy
- [ ] Test audit logging (after trigger fix)
- [ ] Test performance with 1000+ employees
- [ ] Test backup and restore procedures

---

## 📁 Files Created

### Scripts Directory
```
/Users/rameshbabu/data/projects/systech/hrms-saas/postgres/scripts/
├── 01_create_employee_table.sql     - Employee table creation (fixed)
├── 02_sample_data.sql                - Complex sample data (has issues)
└── 03_simple_sample_data.sql         - Simplified sample data
```

### Documentation
```
/Users/rameshbabu/data/projects/systech/hrms-saas/postgres/docs/
├── CLAUDE.md                         - DBA role and responsibilities
├── DATABASE_SETUP_STATUS.md          - This file
├── DBA_NOTES.md                      - Complete DBA guide
├── KEYCLOAK_IMPLEMENTATION_GUIDE.md  - Keycloak setup
├── SPRINGBOOT_NOTES.md               - Backend integration guide
├── saas_mvp_schema_v2_with_hierarchy.sql  - Main schema
└── saas_mvp_audit_schema.sql         - Audit schema
```

---

## 🔗 Connection Information

### For Backend Team (Spring Boot)

**Database Connection:**
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/hrms_saas
spring.datasource.username=hrms_app
spring.datasource.password=HrmsApp@2025
spring.datasource.driver-class-name=org.postgresql.Driver
```

**CRITICAL - Tenant Context:**
Every API request MUST execute:
```sql
SELECT set_current_tenant('<company_id_from_jwt>');
```

This enables Row-Level Security to automatically filter data by tenant.

### For Direct Database Access

**Admin Access (Full Access):**
```bash
podman exec -it nexus-postgres-dev psql -U admin -d hrms_saas
```

**Application User Access:**
```bash
podman exec -it nexus-postgres-dev psql -U hrms_app -d hrms_saas
```

**From Host Machine:**
```bash
psql -h localhost -p 5432 -U hrms_app -d hrms_saas
# Password: HrmsApp@2025
```

---

## 🛠️ Quick Commands

### Check Database Health
```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('hrms_saas'));

-- Table sizes
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Connection count
SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'hrms_saas';
```

### Test RLS Policies
```sql
-- Set tenant context
SELECT set_current_tenant('<company_uuid>');

-- Query should only return data for that tenant
SELECT * FROM employee;
SELECT * FROM company;
```

### Disable RLS (Admin Only - For Testing)
```sql
SET row_security = OFF;
SELECT * FROM company;  -- See all companies
SET row_security = ON;
```

---

## 📈 Performance Metrics (Target)

| Metric | Target | Current |
|--------|--------|---------|
| Query Response Time (p95) | < 100ms | Not measured yet |
| Database Connections | < 50 | 1 (idle) |
| Table Bloat | < 20% | N/A (new database) |
| Index Usage | > 95% | Not measured yet |

---

## 🔐 Security Checklist

- [x] Database created with secure encoding
- [x] Application user created with limited privileges
- [x] Row-Level Security enabled on core tables
- [x] RLS policies configured for multi-tenancy
- [x] Audit logging schema deployed
- [ ] Audit triggers working (blocked by type issue)
- [ ] SSL/TLS enabled for connections (TODO)
- [ ] Password rotation policy defined (TODO)
- [ ] Backup encryption enabled (TODO)

---

## 📞 Support

**DBA:** Claude (AI Assistant)
**Documentation:** See `/Users/rameshbabu/data/projects/systech/hrms-saas/postgres/docs/`
**Issues:** Document in this file or create new MD files

---

## 📝 Change Log

### 2025-10-30 - Initial Setup
- Created fresh `hrms_saas` database
- Deployed V2 schema with corporate hierarchy support
- Deployed comprehensive audit schema (6 tables)
- Created `hrms_app` application user
- Enabled required PostgreSQL extensions
- Configured Row-Level Security policies
- Identified and documented audit trigger issue
- Created setup documentation

---

**Last Updated:** 2025-10-30
**Next Review:** After audit trigger fix and sample data loading

---

**End of Document**
