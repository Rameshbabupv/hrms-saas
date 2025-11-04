# HRMS SaaS - PostgreSQL Database

**Version:** 2.0 (with Corporate Hierarchy)
**PostgreSQL Version:** 16
**Database Name:** hrms_saas
**Container:** nexus-postgres-dev

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Database Management Scripts](#database-management-scripts)
3. [Data Viewing Scripts](#data-viewing-scripts)
4. [Database Schema](#database-schema)
5. [Connection Information](#connection-information)
6. [Common Operations](#common-operations)
7. [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

```bash
# Start the database
./bin/db-start.sh

# Check status
./bin/db-status.sh

# View companies
./bin/view-companies.sh

# View employees
./bin/view-employees.sh

# Connect to database
./bin/db-connect.sh
```

---

## 🛠️ Database Management Scripts

### Start Database
```bash
./bin/db-start.sh
```
- Starts the PostgreSQL container
- Waits for database to be ready
- Shows connection information

### Stop Database
```bash
./bin/db-stop.sh
```
- Gracefully stops the PostgreSQL container

### Restart Database
```bash
./bin/db-restart.sh
```
- Stops and starts the database
- Useful after configuration changes

### Check Status
```bash
./bin/db-status.sh
```
Shows comprehensive information:
- ✅ Container status (running/stopped)
- ✅ Database connection status
- ✅ Database size and statistics
- ✅ Data summary (companies, employees, etc.)
- ✅ RLS status for all tables

### Connect to Database
```bash
./bin/db-connect.sh          # Connect as admin (default)
./bin/db-connect.sh hrms_app # Connect as application user
```
Opens an interactive `psql` session.

---

## 📊 Data Viewing Scripts

### View Companies

#### List All Companies
```bash
./bin/view-companies.sh
```
Shows table with:
- Company code
- Company name
- Type (holding/subsidiary/independent)
- Hierarchy level
- City
- Employee count
- Subscription plan

#### Show Corporate Hierarchy
```bash
./bin/view-companies.sh --hierarchy
# or
./bin/view-companies.sh -h
```
Displays parent-subsidiary relationships in tree format.

#### View Specific Company
```bash
./bin/view-companies.sh --code ABC-HOLD
# or
./bin/view-companies.sh -c ABC-HOLD
```

#### Detailed Company Information
```bash
./bin/view-companies.sh -c ABC-HOLD --verbose
# or
./bin/view-companies.sh -c ABC-HOLD -v
```
Shows:
- Complete company details
- Parent company (if applicable)
- Subsidiaries (if any)
- Employee count by department

### View Employees

#### List All Employees
```bash
./bin/view-employees.sh
```
Shows table with:
- Employee code
- Name
- Company
- Designation
- Department
- Joining date
- Active status

#### Filter by Company
```bash
./bin/view-employees.sh --company ABC-HOLD
# or
./bin/view-employees.sh -c ABC-HOLD
```

#### View Specific Employee
```bash
./bin/view-employees.sh --employee ABCH001
# or
./bin/view-employees.sh -e ABCH001
```
Shows:
- Personal details
- Employment information
- Education records
- Work experience
- Team members (if manager)

#### Filter by Department
```bash
./bin/view-employees.sh --department "Human Resources"
# or
./bin/view-employees.sh -d "Human Resources"
```

#### Show Organizational Hierarchy
```bash
./bin/view-employees.sh --hierarchy
# or
./bin/view-employees.sh -h

# For specific company
./bin/view-employees.sh -c ABC-HOLD -h
```
Shows:
- Top-level employees (no manager)
- Reporting relationships
- Department structure

### Combined Filters
```bash
# Employees in specific company and department
./bin/view-employees.sh -c ABC-HOLD -d "Human Resources"

# Org chart for specific company
./bin/view-employees.sh -c ABC-HOLD --hierarchy
```

---

## 🗂️ Database Schema

### Core Tables (6 tables)

| Table | Description | RLS Enabled |
|-------|-------------|-------------|
| `company` | Tenant/customer master | ✅ Yes |
| `employee` | Employee master | ✅ Yes |
| `department_master` | Shared departments | ✅ Yes |
| `designation_master` | Shared designations | ✅ Yes |
| `employee_education` | Education history | No |
| `employee_experience` | Work experience | No |

### Audit Tables (6 tables)

| Table | Description | Retention |
|-------|-------------|-----------|
| `audit_log` | General audit logging | 1 year |
| `user_activity_log` | Login/logout tracking | 1 year |
| `api_audit_log` | API performance tracking | 90 days |
| `data_change_history` | Detailed change snapshots | 7 years |
| `security_event_log` | Security violations | Permanent |
| `compliance_audit_trail` | GDPR/SOC2 compliance | 7 years |

### Sample Data Loaded

- **4 Companies:**
  - ABC Holdings (parent)
  - ABC Manufacturing (subsidiary)
  - ABC Services (subsidiary)
  - Demo Tech Solutions (independent)

- **8 Employees:** Distributed across all companies
- **5 Departments:** HR, IT, Finance, Operations, Marketing
- **6 Designations:** CEO, CFO, CTO, Manager, Executive, Assistant

---

## 🔗 Connection Information

### For Scripts (Already Configured)
Scripts use these defaults:
- **Container:** nexus-postgres-dev
- **Database:** hrms_saas
- **Admin User:** admin
- **App User:** hrms_app (password: HrmsApp@2025)

### For Backend Applications

**JDBC URL:**
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/hrms_saas
spring.datasource.username=hrms_app
spring.datasource.password=HrmsApp@2025
```

**Direct psql Connection:**
```bash
# From host machine
psql -h localhost -p 5432 -U hrms_app -d hrms_saas

# Inside container
podman exec -it nexus-postgres-dev psql -U hrms_app -d hrms_saas
```

---

## 📖 Common Operations

### Query Examples

#### Count Employees by Company
```sql
SET row_security = OFF;  -- Admin only

SELECT
    c.company_code,
    c.company_name,
    COUNT(e.id) as employee_count
FROM company c
LEFT JOIN employee e ON c.id = e.company_id
GROUP BY c.company_code, c.company_name
ORDER BY c.company_code;
```

#### View Corporate Hierarchy
```sql
SET row_security = OFF;

SELECT
    CASE
        WHEN c.parent_company_id IS NULL THEN '🏛️  ' || c.company_name
        ELSE '  └── ' || c.company_name
    END as company_hierarchy,
    c.company_code,
    COUNT(e.id) as employees
FROM company c
LEFT JOIN employee e ON c.id = e.company_id
GROUP BY c.id, c.company_name, c.company_code, c.parent_company_id
ORDER BY
    COALESCE(c.parent_company_id, c.id),
    c.parent_company_id IS NULL DESC;
```

#### View Reporting Hierarchy
```sql
SET row_security = OFF;

SELECT
    e.employee_code,
    e.employee_name,
    e.designation,
    COALESCE(m.employee_name, 'No Manager') as reports_to,
    c.company_name
FROM employee e
LEFT JOIN employee m ON e.reporting_manager_id = m.id
JOIN company c ON e.company_id = c.id
ORDER BY c.company_name, m.employee_name NULLS FIRST, e.employee_name;
```

### Row-Level Security (RLS)

RLS automatically filters data based on tenant context.

**Set Tenant Context:**
```sql
-- This would normally be done by the backend application
SELECT set_current_tenant('<company_uuid>');

-- Now queries automatically filter by tenant
SELECT * FROM employee;  -- Only sees employees from current tenant
```

**Bypass RLS (Admin Only):**
```sql
SET row_security = OFF;
SELECT * FROM employee;  -- See all employees
SET row_security = ON;
```

### Audit Logs

**View Recent Changes:**
```sql
SELECT
    audit_timestamp,
    username,
    table_name,
    action,
    changed_fields
FROM audit_log
ORDER BY audit_timestamp DESC
LIMIT 20;
```

**View Data Change History:**
```sql
SELECT
    change_timestamp,
    username,
    table_name,
    change_type,
    version_number
FROM data_change_history
WHERE table_name = 'employee'
ORDER BY change_timestamp DESC;
```

---

## 🐛 Troubleshooting

### Database Won't Start

**Check if container exists:**
```bash
podman ps -a | grep nexus-postgres-dev
```

**Check container logs:**
```bash
podman logs nexus-postgres-dev
```

**Restart container:**
```bash
./bin/db-restart.sh
```

### Can't Connect to Database

**Verify container is running:**
```bash
./bin/db-status.sh
```

**Check PostgreSQL is accepting connections:**
```bash
podman exec nexus-postgres-dev pg_isready -U admin -d hrms_saas
```

**Test connection:**
```bash
./bin/db-connect.sh
```

### Scripts Show "Permission Denied"

**Make scripts executable:**
```bash
chmod +x bin/*.sh
```

### RLS Blocking Queries

If you're getting no results when you expect data:

**Option 1: Disable RLS (Admin/DBA only)**
```sql
SET row_security = OFF;
```

**Option 2: Set proper tenant context**
```sql
-- Get a company ID first
SELECT id, company_code FROM company LIMIT 1;

-- Set tenant context
SELECT set_current_tenant('<company_id_from_above>');

-- Now query
SELECT * FROM employee;
```

### Slow Queries

**Check active connections:**
```sql
SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'hrms_saas';
```

**Check table sizes:**
```sql
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

**Analyze slow queries:**
```sql
-- Enable query timing
\timing on

-- Your query here
SELECT * FROM employee WHERE company_id = 'some-uuid';
```

---

## 📁 Directory Structure

```
postgres/
├── README.md                          # This file
├── INDEX.md                           # Documentation index
├── SCRIPTS_GUIDE.md                   # Scripts usage guide
├── bin/                               # Management scripts
│   ├── db-start.sh                   # Start database
│   ├── db-stop.sh                    # Stop database
│   ├── db-restart.sh                 # Restart database
│   ├── db-status.sh                  # Check status
│   ├── db-connect.sh                 # Connect to DB
│   ├── view-companies.sh             # View company data
│   └── view-employees.sh             # View employee data
├── postgres-docs/                     # Database documentation
│   ├── README.md                     # Documentation guide
│   ├── DBA_NOTES.md                  # Complete DBA guide
│   ├── DATABASE_SETUP_STATUS.md      # Setup completion status
│   └── schemas/                      # Database schemas
│       ├── saas_mvp_schema_v1.sql    # Initial schema
│       ├── saas_mvp_schema_v2_with_hierarchy.sql  # Current schema (v2)
│       └── saas_mvp_audit_schema.sql # Audit tables
└── scripts/                           # SQL scripts
    ├── 01_create_employee_table.sql
    ├── 02_sample_data.sql
    ├── 03_simple_sample_data.sql
    └── 04_fix_audit_triggers.sql
```

---

## 🔐 Security Notes

1. **RLS is Enabled:** Multi-tenant data isolation is enforced at database level
2. **Audit Logging:** All changes to company and employee tables are logged
3. **Password Security:** Change default passwords in production
4. **SSL/TLS:** Enable for production deployments
5. **Backup Encryption:** Implement for production

---

## 📞 Support

**DBA:** Claude (AI Assistant)
**Documentation:** See `/postgres-docs` directory
**Issues:** Document in `postgres-docs/DATABASE_SETUP_STATUS.md`
**Complete Guide:** See `postgres-docs/DBA_NOTES.md`

---

## 🎯 Next Steps

### For Development
1. Test RLS policies with different tenant contexts
2. Load more test data
3. Test performance with larger datasets
4. Integrate with backend application

### For Production
1. Change all default passwords
2. Enable SSL/TLS connections
3. Set up automated backups
4. Configure monitoring and alerting
5. Review and adjust audit log retention
6. Implement backup encryption
7. Set up replication for high availability

---

## 📜 License

Internal project for Systech HRMS SaaS

---

**Last Updated:** 2025-10-30
**Database Version:** 2.0 with Corporate Hierarchy
**Status:** ✅ Ready for Development

---

## Quick Reference Card

```bash
# DATABASE MANAGEMENT
./bin/db-start.sh              # Start database
./bin/db-stop.sh               # Stop database
./bin/db-restart.sh            # Restart database
./bin/db-status.sh             # Check status
./bin/db-connect.sh            # Connect to DB

# VIEW COMPANIES
./bin/view-companies.sh        # List all
./bin/view-companies.sh -h     # Show hierarchy
./bin/view-companies.sh -c CODE # View specific

# VIEW EMPLOYEES
./bin/view-employees.sh        # List all
./bin/view-employees.sh -c CODE # Filter by company
./bin/view-employees.sh -e CODE # View specific
./bin/view-employees.sh -h     # Show org chart
```

---

**End of README**
