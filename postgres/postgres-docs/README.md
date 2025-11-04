# PostgreSQL Database Documentation

This directory contains all database-related documentation and schemas for the HRMS SaaS platform.

## 📁 Directory Structure

```
postgres-docs/
├── README.md                       # This file
├── DBA_NOTES.md                   # Comprehensive DBA guide
├── DATABASE_SETUP_STATUS.md       # Setup completion status
└── schemas/                       # Database schemas
    ├── saas_mvp_schema_v1.sql     # Initial schema (v1)
    ├── saas_mvp_schema_v2_with_hierarchy.sql  # Current schema with hierarchy (v2)
    └── saas_mvp_audit_schema.sql  # Audit tables schema
```

## 📚 Documentation Files

### DBA_NOTES.md
**Comprehensive Database Administrator Guide**

Contents:
- Complete schema documentation
- Table structures and relationships
- Row-Level Security (RLS) policies
- Audit logging implementation
- Maintenance procedures
- Backup and recovery strategies
- Performance optimization tips
- Troubleshooting guide

**When to read**: Essential reference for DBAs and backend developers working with the database.

### DATABASE_SETUP_STATUS.md
**Database Setup Progress and Status**

Contents:
- Setup completion checklist
- Current database version
- Migration history
- Known issues and resolutions
- Environment configuration
- Testing status

**When to read**: Check current database state and setup progress.

## 🗂️ Schema Files

### saas_mvp_schema_v1.sql
**Initial Database Schema (v1)**

Features:
- Basic multi-tenant structure
- Company and employee tables
- Department and designation masters
- Simple relationships

**Status**: Historical reference, superseded by v2

### saas_mvp_schema_v2_with_hierarchy.sql
**Current Schema with Corporate Hierarchy (v2)** ⭐

Features:
- ✅ Multi-tenant architecture with RLS
- ✅ Corporate hierarchy (parent/subsidiary companies)
- ✅ Employee management with reporting hierarchy
- ✅ Department and designation masters
- ✅ Advanced relationships and constraints
- ✅ Optimized indexes
- ✅ Helper functions for tenant context

**Status**: **ACTIVE** - This is the current production schema

Tables included:
- `company` (6 columns + audit)
- `employee` (16 columns + audit)
- `department_master` (shared reference)
- `designation_master` (shared reference)
- `employee_education` (education history)
- `employee_experience` (work experience)

### saas_mvp_audit_schema.sql
**Audit and Compliance Tables**

Features:
- ✅ 6 audit tables for comprehensive logging
- ✅ Automatic triggers for data changes
- ✅ GDPR and SOC2 compliance support
- ✅ Retention policies
- ✅ Security event tracking

Tables included:
- `audit_log` (general audit logging)
- `user_activity_log` (login/logout tracking)
- `api_audit_log` (API performance)
- `data_change_history` (detailed snapshots)
- `security_event_log` (security violations)
- `compliance_audit_trail` (compliance tracking)

**Status**: **ACTIVE** - Applied to production database

## 🔗 Related Documentation

### In Parent Directory (`/postgres`)
- **README.md** - Main PostgreSQL setup guide
  - Quick start commands
  - Database management scripts
  - Connection information
  - Common operations

- **SCRIPTS_GUIDE.md** - Management scripts documentation
  - Script usage examples
  - Command reference
  - Troubleshooting

- **INDEX.md** - Complete documentation index

### Scripts (`/postgres/scripts`)
- `01_create_employee_table.sql` - Initial employee table
- `02_sample_data.sql` - Sample test data
- `03_simple_sample_data.sql` - Minimal test data
- `04_fix_audit_triggers.sql` - Audit trigger fixes

### Management Tools (`/postgres/bin`)
- `db-start.sh` - Start database container
- `db-stop.sh` - Stop database container
- `db-restart.sh` - Restart database
- `db-status.sh` - Check database status
- `db-connect.sh` - Connect via psql
- `view-companies.sh` - View company data
- `view-employees.sh` - View employee data

## 🚀 Quick Reference

### To Apply Current Schema
```bash
# Start database
cd /postgres
./bin/db-start.sh

# Apply v2 schema with hierarchy
./bin/db-connect.sh
\i postgres-docs/schemas/saas_mvp_schema_v2_with_hierarchy.sql

# Apply audit schema
\i postgres-docs/schemas/saas_mvp_audit_schema.sql
```

### To View Documentation
```bash
# DBA guide
less postgres-docs/DBA_NOTES.md

# Setup status
less postgres-docs/DATABASE_SETUP_STATUS.md

# View schemas
less postgres-docs/schemas/saas_mvp_schema_v2_with_hierarchy.sql
```

## 📊 Schema Version History

| Version | File | Date | Status | Notes |
|---------|------|------|--------|-------|
| v1.0 | saas_mvp_schema_v1.sql | Oct 29 | Deprecated | Initial schema |
| v2.0 | saas_mvp_schema_v2_with_hierarchy.sql | Oct 29 | **Active** | Added hierarchy |
| Audit | saas_mvp_audit_schema.sql | Oct 29 | **Active** | Audit tables |

## 🔐 Security Notes

**Row-Level Security (RLS)**:
- All tenant-specific tables have RLS enabled
- Automatic filtering by tenant_id
- Context set via `set_current_tenant()` function
- Admin bypass available with `SET row_security = OFF`

**Audit Logging**:
- All changes to company and employee tables logged
- Automatic triggers capture INSERT/UPDATE/DELETE
- Change history preserved with snapshots
- Security events tracked separately

## 🎯 For Different Roles

### For DBAs
Start with: **DBA_NOTES.md** - Complete database administration guide

### For Backend Developers
1. Review schema: **saas_mvp_schema_v2_with_hierarchy.sql**
2. Understand RLS: **DBA_NOTES.md** (RLS section)
3. Check audit requirements: **saas_mvp_audit_schema.sql**

### For DevOps
1. Database setup: **../README.md** (parent directory)
2. Check status: **DATABASE_SETUP_STATUS.md**
3. Management scripts: **../SCRIPTS_GUIDE.md**

### For QA/Testing
1. Quick start: **../README.md**
2. Sample data: **../scripts/02_sample_data.sql**
3. Verification: Use `./bin/view-companies.sh` and `./bin/view-employees.sh`

## 📞 Support

**Questions about**:
- Schema design → See **DBA_NOTES.md**
- Setup issues → See **DATABASE_SETUP_STATUS.md**
- Scripts usage → See **../SCRIPTS_GUIDE.md**
- Quick operations → See **../README.md**

## 🔄 Schema Update Process

When updating the schema:

1. **Create new version** (e.g., v3):
   ```bash
   cp postgres-docs/schemas/saas_mvp_schema_v2_with_hierarchy.sql \
      postgres-docs/schemas/saas_mvp_schema_v3_description.sql
   ```

2. **Document changes** in the file header

3. **Update this README** with new version info

4. **Test thoroughly** before marking as active

5. **Update DATABASE_SETUP_STATUS.md**

## 📝 Notes

- All schemas include comments for documentation
- Foreign key relationships are clearly defined
- Indexes are created for performance
- Audit triggers are automatic
- RLS policies are declarative

---

**Last Updated**: 2025-11-04
**Current Schema Version**: v2.0 with Corporate Hierarchy
**Database**: PostgreSQL 16
**Status**: ✅ Production Ready

---

**Navigation**:
- [Main PostgreSQL README](../README.md)
- [Scripts Guide](../SCRIPTS_GUIDE.md)
- [Documentation Index](../INDEX.md)
