# Database Administrator (DBA) Notes
## SaaS HRMS MVP - Company Master & Employee Master

**Document Version:** 1.0
**Date:** 2025-10-29
**Schema Version:** V2 (with Corporate Hierarchy)
**Target Audience:** Database Administrators
**Project:** HRMS SaaS - Company Master & Employee Master MVP

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Database Environment Setup](#database-environment-setup)
3. [Schema Deployment](#schema-deployment)
4. [Multi-Tenancy Configuration](#multi-tenancy-configuration)
5. [Row-Level Security (RLS) Setup](#row-level-security-rls-setup)
6. [Audit Schema and Logging](#audit-schema-and-logging) **← NEW**
7. [Performance Optimization](#performance-optimization)
8. [Backup and Recovery](#backup-and-recovery)
9. [Monitoring and Maintenance](#monitoring-and-maintenance)
10. [Security Considerations](#security-considerations)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Integration Points](#integration-points)

---

## 1. Executive Summary

### Project Overview
SaaS HRMS application with multi-tenant architecture supporting corporate hierarchies (parent-subsidiary companies). Maximum 2-level hierarchy allowed.

### Database Platform
- **RDBMS:** PostgreSQL 15+
- **Schema Name:** `hrms_saas` (recommended)
- **Extensions Required:** `uuid-ossp`

### Key Features
- ✅ Multi-tenant data isolation via Row-Level Security (RLS)
- ✅ Corporate hierarchy support (parent → subsidiary, max 2 levels)
- ✅ Shared master data across corporate groups
- ✅ Flexible subscription billing (parent or subsidiary pays)
- ✅ Consolidated reporting (parent sees all subsidiaries)

### Core Tables
| Table | Purpose | Records (Est.) | Critical for RLS |
|-------|---------|----------------|------------------|
| `company` | Tenant/customer master | 100-1000 | ✅ Yes |
| `employee` | Employee master | 10K-100K | ✅ Yes |
| `employee_education` | Education history | 20K-200K | No |
| `audit_log` | General audit logging | 1M-10M | No |
| `user_activity_log` | Login/logout tracking | 100K-1M | No |
| `data_change_history` | Detailed change history | 500K-5M | No |
| `employee_experience` | Work experience | 20K-200K | No |
| `department_master` | Shared departments | 100-500 | ✅ Yes |
| `designation_master` | Shared designations | 50-200 | ✅ Yes |

---

## 2. Database Environment Setup

### 2.1 PostgreSQL Installation

**Minimum Version:** PostgreSQL 15.0
**Recommended Version:** PostgreSQL 16.x (latest stable)

**Installation (Ubuntu/Debian):**
```bash
# Add PostgreSQL repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update

# Install PostgreSQL 16
sudo apt-get install -y postgresql-16 postgresql-contrib-16

# Verify installation
psql --version
```

**Installation (RHEL/CentOS):**
```bash
# Install PostgreSQL repository
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Disable built-in PostgreSQL module
sudo dnf -qy module disable postgresql

# Install PostgreSQL 16
sudo yum install -y postgresql16-server postgresql16-contrib

# Initialize and start
sudo /usr/pgsql-16/bin/postgresql-16-setup initdb
sudo systemctl enable postgresql-16
sudo systemctl start postgresql-16
```

### 2.2 PostgreSQL Configuration

**File:** `/etc/postgresql/16/main/postgresql.conf` (Debian) or `/var/lib/pgsql/16/data/postgresql.conf` (RHEL)

**Recommended Settings for Production:**

```ini
# CONNECTIONS
max_connections = 200                   # For SaaS workload
superuser_reserved_connections = 3

# MEMORY
shared_buffers = 4GB                    # 25% of RAM
effective_cache_size = 12GB             # 75% of RAM
work_mem = 16MB                         # Per-operation memory
maintenance_work_mem = 512MB            # For VACUUM, CREATE INDEX

# CHECKPOINTING
checkpoint_completion_target = 0.9
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB

# QUERY TUNING
random_page_cost = 1.1                  # For SSD storage
effective_io_concurrency = 200          # For SSD storage

# LOGGING
log_destination = 'csvlog'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000       # Log slow queries (>1s)
log_line_prefix = '%m [%p] %u@%d '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on

# ROW LEVEL SECURITY (Critical for Multi-Tenancy)
row_security = on

# AUTOVACUUM (Important for SaaS)
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 30s
```

**Apply changes:**
```bash
sudo systemctl restart postgresql-16
```

### 2.3 Create Database and User

```sql
-- Connect as postgres superuser
sudo -u postgres psql

-- Create database
CREATE DATABASE hrms_saas
    WITH ENCODING 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Create application user
CREATE USER hrms_app WITH PASSWORD 'STRONG_PASSWORD_HERE';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE hrms_saas TO hrms_app;

-- Connect to the database
\c hrms_saas

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO hrms_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO hrms_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO hrms_app;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO hrms_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO hrms_app;
```

### 2.4 Enable Required Extensions

```sql
-- Connect to hrms_saas database
\c hrms_saas

-- Enable UUID extension (required)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify extension
SELECT * FROM pg_extension WHERE extname = 'uuid-ossp';

-- Optional: Enable pgcrypto for additional encryption
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Optional: Enable pg_stat_statements for query monitoring
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

---

## 3. Schema Deployment

### 3.1 Deploy Schema V2

**File Location:** `nexus-backend/saas_mvp_schema_v2_with_hierarchy.sql`

**Deployment Steps:**

```bash
# 1. Verify PostgreSQL is running
sudo systemctl status postgresql-16

# 2. Navigate to schema directory
cd /path/to/project/nexus-backend

# 3. Deploy schema as hrms_app user
psql -U hrms_app -d hrms_saas -f saas_mvp_schema_v2_with_hierarchy.sql

# 4. Verify deployment
psql -U hrms_app -d hrms_saas -c "\dt"  # List tables
psql -U hrms_app -d hrms_saas -c "\df"  # List functions
```

**Expected Output:**
```
                  List of relations
 Schema |         Name          | Type  |  Owner
--------+-----------------------+-------+----------
 public | company               | table | hrms_app
 public | department_master     | table | hrms_app
 public | designation_master    | table | hrms_app
 public | employee              | table | hrms_app
 public | employee_education    | table | hrms_app
 public | employee_experience   | table | hrms_app
(6 rows)
```

### 3.2 Verify Schema Objects

```sql
-- Connect to database
psql -U hrms_app -d hrms_saas

-- Check table count
SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';
-- Expected: 6 tables

-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND rowsecurity = true;
-- Expected: company, employee, department_master, designation_master

-- Check custom types
SELECT typname FROM pg_type WHERE typtype = 'e' ORDER BY typname;
-- Expected: company_type, employment_type, gender_type, marital_status_type, status_type, subscription_paid_by

-- Check functions
SELECT proname FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
AND proname LIKE '%tenant%' OR proname LIKE '%company%';
-- Expected: set_current_tenant, get_employee_count, get_subsidiary_companies, etc.

-- Check indexes
SELECT tablename, indexname FROM pg_indexes
WHERE schemaname = 'public' ORDER BY tablename, indexname;
-- Expected: 20+ indexes
```

### 3.3 Verify Sample Data

```sql
-- Check companies
SELECT company_code, company_name, company_type, parent_company_id, corporate_group_name
FROM company
ORDER BY hierarchy_level, company_name;
-- Expected: 4 companies (1 parent + 2 subsidiaries + 1 independent)

-- Check employees
SELECT COUNT(*) FROM employee;
-- Expected: 4 employees

-- Check departments
SELECT department_code, department_name, is_shared, shared_with_group
FROM department_master;
-- Expected: 3 departments (HR, IT, Finance)

-- Check designations
SELECT designation_code, designation_name, is_shared, shared_with_group
FROM designation_master;
-- Expected: 3 designations (CEO, Manager, Executive)
```

---

## 4. Multi-Tenancy Configuration

### 4.1 Understanding Tenant Context

**Key Concept:** Each database session must set `app.current_tenant_id` to enforce Row-Level Security.

**Session Variable:**
```sql
-- Set tenant context (company UUID)
SELECT set_current_tenant('550e8400-e29b-41d4-a716-446655440000');

-- Verify current tenant
SHOW app.current_tenant_id;
```

### 4.2 Application-Level Integration

**Spring Boot Approach (Backend team will implement):**
```sql
-- Backend will call this for every request
SELECT set_config('app.current_tenant_id', '<company_id_from_jwt>', false);
```

**IMPORTANT:**
- The `false` parameter makes the setting session-local (not transaction-local)
- Setting is cleared when connection is returned to pool
- **DBA NOTE:** Monitor for queries without tenant context set

### 4.3 Test Multi-Tenancy Isolation

```sql
-- Test 1: Set context to ABC Holdings (parent)
SELECT set_current_tenant((SELECT id FROM company WHERE company_code = 'ABC-HOLD'));

-- Should see: ABC-HOLD, ABC-MFG, ABC-SRV (parent + subsidiaries)
SELECT company_code, company_name FROM company ORDER BY company_code;

-- Should see: All employees from ABC Holdings + subsidiaries
SELECT employee_code, employee_name,
       (SELECT company_code FROM company WHERE id = employee.company_id) as company
FROM employee
ORDER BY employee_code;

-- Test 2: Set context to ABC Manufacturing (subsidiary)
SELECT set_current_tenant((SELECT id FROM company WHERE company_code = 'ABC-MFG'));

-- Should see: ABC-HOLD (parent), ABC-MFG (self) - NOT ABC-SRV (sibling)
SELECT company_code, company_name FROM company ORDER BY company_code;

-- Should see: Only ABC-MFG employees (NOT parent's employees)
SELECT employee_code, employee_name FROM employee;

-- Test 3: Set context to Demo Tech (independent)
SELECT set_current_tenant((SELECT id FROM company WHERE company_code = 'DEMO001'));

-- Should see: Only DEMO001
SELECT company_code, company_name FROM company;

-- Should see: Only Demo Tech employees
SELECT employee_code, employee_name FROM employee;
```

**Expected Results:**
- ✅ Parent can see all subsidiaries and their employees (READ ONLY via RLS)
- ✅ Parent can MODIFY only own employees (enforced by modification policy)
- ✅ Subsidiary can see parent info (for reporting) but NOT parent's employees
- ✅ Subsidiary CANNOT see sibling subsidiaries
- ✅ Independent company sees ONLY own data

---

## 5. Row-Level Security (RLS) Setup

### 5.1 RLS Policies Overview

| Table | Policy Name | Type | Purpose |
|-------|-------------|------|---------|
| `employee` | `employee_tenant_isolation` | SELECT | Parent can see subsidiaries' employees |
| `employee` | `employee_tenant_modification` | INSERT/UPDATE/DELETE | Can only modify own company |
| `company` | `company_tenant_isolation` | SELECT | See own + parent + subsidiaries |
| `department_master` | `department_access` | SELECT | See own + shared from group |
| `designation_master` | `designation_access` | SELECT | See own + shared from group |

### 5.2 Verify RLS Policies

```sql
-- List all RLS policies
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Check if RLS is enabled on critical tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

### 5.3 Disable RLS for Superuser (Emergency Access)

```sql
-- ONLY for emergency maintenance - DO NOT USE IN APPLICATION CODE
SET SESSION AUTHORIZATION postgres;  -- Switch to superuser
SET row_security = off;              -- Disable RLS for this session

-- Perform emergency query/update
SELECT * FROM employee;  -- See ALL employees across ALL tenants

-- Re-enable RLS
SET row_security = on;
RESET SESSION AUTHORIZATION;
```

**WARNING:**
- RLS bypass should ONLY be used by DBAs for maintenance
- Log all RLS bypass sessions
- Never give RLS bypass access to application users

---

## 6. Audit Schema and Logging

### 6.1 Overview

Comprehensive audit logging is critical for SaaS applications to ensure:
- **Compliance:** GDPR, SOC2, HIPAA requirements
- **Security:** Detect and investigate suspicious activities
- **Debugging:** Troubleshoot issues by understanding what changed
- **Accountability:** Track who did what and when

**Audit Schema File:** `saas_mvp_audit_schema.sql`

### 6.2 Audit Tables

#### Core Audit Tables

| Table | Purpose | Estimated Records | Retention |
|-------|---------|-------------------|-----------|
| `audit_log` | General audit for all table changes | 1M-10M | 1 year |
| `user_activity_log` | Login/logout, session tracking | 100K-1M | 1 year |
| `api_audit_log` | API requests/responses | 5M-50M | 90 days |
| `data_change_history` | Detailed before/after snapshots | 500K-5M | 7 years |
| `security_event_log` | Security violations, suspicious activity | 10K-100K | Permanent |
| `compliance_audit_trail` | GDPR, SOC2 compliance events | 50K-500K | 7 years |

### 6.3 Deploy Audit Schema

**Step 1: Deploy Main Schema First**
```bash
psql -U hrms_app -d hrms_saas -f saas_mvp_schema_v2_with_hierarchy.sql
```

**Step 2: Deploy Audit Schema**
```bash
psql -U hrms_app -d hrms_saas -f saas_mvp_audit_schema.sql
```

**Step 3: Verify Audit Tables**
```sql
-- Check audit tables exist
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename LIKE '%audit%' OR tablename LIKE '%log%'
ORDER BY tablename;

-- Expected output:
-- api_audit_log
-- audit_log
-- compliance_audit_trail
-- data_change_history
-- security_event_log
-- user_activity_log
```

### 6.4 Automatic Audit Triggers

The audit schema automatically creates triggers on core tables:

```sql
-- Triggers are automatically created for:
company
employee
department_master
designation_master
```

**How It Works:**
1. Any INSERT/UPDATE/DELETE on these tables triggers `trigger_audit_log()`
2. Function logs entry to `audit_log` table
3. For `company` and `employee`, also logs to `data_change_history`
4. Captures before/after values as JSONB

**Verify Triggers:**
```sql
SELECT
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    proname AS function_name
FROM pg_trigger
JOIN pg_proc ON pg_trigger.tgfoid = pg_proc.oid
WHERE tgname LIKE 'audit%'
ORDER BY table_name;
```

### 6.5 Manual Audit Logging

**For Custom Events (called from application):**

```sql
-- Example: Log a manual audit entry
SELECT log_audit_entry(
    'employee',                          -- table_name
    '660e8400-e29b-41d4-a716-446655440001'::UUID,  -- record_id
    'UPDATE'::audit_action,              -- action
    '{"salary": 50000}'::JSONB,          -- old_values
    '{"salary": 55000}'::JSONB,          -- new_values
    'Salary increment approved by HR'    -- description
);

-- Example: Log detailed data change history
SELECT log_data_change_history(
    'employee',
    '660e8400-e29b-41d4-a716-446655440001'::UUID,
    'UPDATE'::audit_action,
    '{"employee_name": "John Doe", "salary": 50000}'::JSONB,  -- before snapshot
    '{"employee_name": "John Doe", "salary": 55000}'::JSONB,  -- after snapshot
    'Annual salary review'  -- reason
);
```

### 6.6 User Activity Logging

**Backend team must log user activities:**

```sql
-- Log successful login
INSERT INTO user_activity_log (
    user_id, username, email, company_id, company_code,
    activity_type, activity_status, session_id,
    ip_address, user_agent, device_type
) VALUES (
    '<user-uuid>',
    'john.doe@company.com',
    'john.doe@company.com',
    '<company-uuid>',
    'DEMO001',
    'LOGIN',
    'SUCCESS',
    '<session-uuid>',
    '192.168.1.100',
    'Mozilla/5.0...',
    'desktop'
);

-- Log failed login
INSERT INTO user_activity_log (
    user_id, username, company_id,
    activity_type, activity_status,
    ip_address, failure_reason, login_attempt_count
) VALUES (
    NULL,  -- user_id unknown for failed login
    'john.doe@company.com',
    '<company-uuid>',
    'LOGIN',
    'FAILED',
    '192.168.1.100',
    'Invalid password',
    3  -- 3rd failed attempt
);
```

### 6.7 Security Event Logging

**Log security violations:**

```sql
-- Example: Unauthorized tenant access attempt
INSERT INTO security_event_log (
    severity, category, event_type, event_description,
    user_id, username, company_id, ip_address,
    was_blocked, potential_damage
) VALUES (
    'CRITICAL',
    'AUTHORIZATION',
    'CROSS_TENANT_ACCESS_ATTEMPT',
    'User tried to access employee data from different tenant',
    '<user-uuid>',
    'john.doe@company.com',
    '<company-uuid>',
    '192.168.1.100',
    true,  -- RLS blocked the attempt
    'HIGH'
);

-- Example: SQL injection attempt
INSERT INTO security_event_log (
    severity, category, event_type, event_description,
    ip_address, was_blocked, detection_method
) VALUES (
    'CRITICAL',
    'SECURITY',
    'SQL_INJECTION_ATTEMPT',
    'Malicious SQL detected in query parameter',
    '192.168.1.100',
    true,
    'Input validation filter'
);
```

### 6.8 Query Audit Logs

**Recent Changes to Employees:**
```sql
SELECT
    audit_timestamp,
    username,
    action,
    changed_fields,
    description
FROM audit_log
WHERE table_name = 'employee'
ORDER BY audit_timestamp DESC
LIMIT 20;
```

**Failed Login Attempts:**
```sql
SELECT
    activity_timestamp,
    username,
    ip_address,
    failure_reason,
    login_attempt_count
FROM user_activity_log
WHERE activity_type = 'LOGIN' AND activity_status = 'FAILED'
ORDER BY activity_timestamp DESC;
```

**Security Events (Unresolved):**
```sql
SELECT
    event_timestamp,
    severity,
    event_type,
    event_description,
    username,
    ip_address
FROM security_event_log
WHERE status != 'RESOLVED'
ORDER BY severity DESC, event_timestamp DESC;
```

**Data Change History for Specific Record:**
```sql
SELECT
    change_timestamp,
    username,
    change_type,
    version_number,
    changed_fields->>'field_name' AS changed_values
FROM data_change_history
WHERE table_name = 'employee'
AND record_id = '<employee-uuid>'
ORDER BY version_number DESC;
```

**API Performance (Slow Queries):**
```sql
SELECT
    request_timestamp,
    endpoint_path,
    graphql_operation_name,
    execution_time_ms,
    response_status_code
FROM api_audit_log
WHERE execution_time_ms > 1000  -- Queries taking > 1 second
ORDER BY execution_time_ms DESC
LIMIT 50;
```

### 6.9 Audit Maintenance

**Purge Old Audit Logs (Run Monthly):**

```sql
-- Purge logs older than 1 year (365 days)
SELECT * FROM purge_old_audit_logs(365);

-- Output shows rows deleted per table:
-- table_name              | rows_deleted
-- -----------------------|-------------
-- audit_log              | 1,234,567
-- user_activity_log      | 456,789
-- api_audit_log          | 5,678,901
-- data_change_history    | 0 (archived instead)
```

**Schedule via cron:**
```bash
# Monthly on 1st day at 2 AM
0 2 1 * * psql -U hrms_app -d hrms_saas -c "SELECT * FROM purge_old_audit_logs(365);"
```

**Get Audit Statistics:**
```sql
SELECT * FROM get_audit_statistics();

-- Output:
-- metric_name                      | metric_value
-- --------------------------------|-------------
-- Total Audit Logs                | 5,432,100
-- Audit Logs (Last 30 Days)       | 234,567
-- User Activities (Last 30 Days)  | 12,345
-- API Calls (Last 30 Days)        | 1,234,567
-- Security Events (Open)          | 23
-- Data Changes (Last 30 Days)     | 45,678
```

### 6.10 Compliance Audit Trail

**For GDPR/SOC2 compliance:**

```sql
-- Example: Log data export request (GDPR Art. 20 - Right to Data Portability)
INSERT INTO compliance_audit_trail (
    compliance_type, requirement_id,
    event_category, event_description,
    subject_type, subject_id, subject_name,
    actor_user_id, actor_username,
    company_id, data_categories, legal_basis
) VALUES (
    'GDPR',
    'GDPR-Art-20',
    'DATA_EXPORT',
    'Employee requested export of personal data',
    'EMPLOYEE',
    '<employee-uuid>',
    'John Doe',
    '<user-uuid>',
    'john.doe@company.com',
    '<company-uuid>',
    ARRAY['personal_info', 'employment_data', 'payroll_data'],
    'data_subject_request'
);

-- Example: Log data deletion (GDPR Art. 17 - Right to Erasure)
INSERT INTO compliance_audit_trail (
    compliance_type, requirement_id,
    event_category, event_description,
    subject_type, subject_id, subject_name,
    actor_user_id, actor_username,
    company_id, data_scope,
    deletion_date
) VALUES (
    'GDPR',
    'GDPR-Art-17',
    'DATA_DELETION',
    'Employee data deleted upon request',
    'EMPLOYEE',
    '<employee-uuid>',
    'John Doe',
    '<admin-uuid>',
    'admin@company.com',
    '<company-uuid>',
    'Complete employee record and associated data',
    CURRENT_TIMESTAMP
);
```

### 6.11 Backend Integration Points

**Backend team must integrate audit logging:**

**1. User Activity (Spring Boot Filter):**
```java
// After successful login
jdbcTemplate.update(
    "INSERT INTO user_activity_log (user_id, username, company_id, activity_type, activity_status, ip_address, session_id) " +
    "VALUES (?, ?, ?, 'LOGIN', 'SUCCESS', ?, ?)",
    userId, username, companyId, ipAddress, sessionId
);
```

**2. API Audit (Spring Boot Interceptor):**
```java
// Log all GraphQL requests
jdbcTemplate.update(
    "INSERT INTO api_audit_log (request_id, user_id, company_id, endpoint_path, graphql_operation_name, " +
    "request_timestamp, execution_time_ms, response_status_code) " +
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    requestId, userId, companyId, path, operationName, timestamp, executionTime, statusCode
);
```

**3. Security Events (on RLS violation):**
```java
// When RLS blocks unauthorized access
jdbcTemplate.update(
    "INSERT INTO security_event_log (severity, category, event_type, event_description, " +
    "user_id, company_id, ip_address, was_blocked) " +
    "VALUES ('CRITICAL', 'AUTHORIZATION', 'RLS_VIOLATION', ?, ?, ?, ?, true)",
    description, userId, companyId, ipAddress
);
```

### 6.12 Monitoring Audit Tables

**Table Sizes:**
```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
AND (tablename LIKE '%audit%' OR tablename LIKE '%log%')
ORDER BY size_bytes DESC;
```

**Growth Rate (check weekly):**
```sql
-- Inserts per day
SELECT
    DATE(audit_timestamp) AS audit_date,
    COUNT(*) AS records_created
FROM audit_log
WHERE audit_timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY DATE(audit_timestamp)
ORDER BY audit_date DESC;
```

**Alert if growth is abnormal:**
```sql
-- If > 100K audit logs per day, investigate
SELECT COUNT(*) AS todays_audit_logs
FROM audit_log
WHERE audit_timestamp > CURRENT_TIMESTAMP - INTERVAL '1 day';
```

### 6.13 Audit Best Practices

**DO:**
- ✅ Log all authentication events (success and failure)
- ✅ Log all data modifications (INSERT/UPDATE/DELETE)
- ✅ Log security violations immediately
- ✅ Include context (user, tenant, IP, timestamp)
- ✅ Purge old logs regularly (balance retention vs storage)
- ✅ Monitor audit table growth
- ✅ Test audit log restoration periodically

**DON'T:**
- ❌ Log sensitive data in plain text (passwords, tokens)
- ❌ Skip logging for "minor" changes
- ❌ Allow users to delete their own audit logs
- ❌ Disable triggers in production
- ❌ Ignore audit log errors
- ❌ Store audit logs indefinitely without archiving

### 6.14 Audit Compliance Checklist

For compliance audits (SOC2, ISO27001, GDPR):

- [ ] All user authentication events logged
- [ ] All data access logged (SELECT queries via application)
- [ ] All data modifications logged (INSERT/UPDATE/DELETE)
- [ ] Security events logged and monitored
- [ ] Audit logs retained per compliance requirements (1-7 years)
- [ ] Audit logs are tamper-proof (append-only, no user deletion)
- [ ] Regular audit log reviews scheduled (weekly/monthly)
- [ ] Audit log backup and recovery tested
- [ ] Compliance-specific events logged (GDPR data exports, deletions)
- [ ] Audit log access restricted to authorized personnel

---

## 7. Performance Optimization

### 7.1 Index Strategy

**All indexes are created by the schema file. Verify they exist:**

```sql
-- Check index coverage
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

**Critical Indexes (verify these exist):**

**Company Table:**
```sql
idx_company_parent          -- For hierarchy queries
idx_company_group           -- For corporate group filtering
idx_company_billing         -- For subscription billing
idx_company_type            -- For company type filtering
```

**Employee Table:**
```sql
idx_employee_company        -- For tenant filtering (MOST CRITICAL)
idx_employee_active         -- For active employee queries
idx_employee_manager        -- For reporting hierarchy
```

### 6.2 Query Performance Monitoring

**Enable pg_stat_statements:**
```sql
-- Add to postgresql.conf
shared_preload_libraries = 'pg_stat_statements'

-- Restart PostgreSQL
sudo systemctl restart postgresql-16

-- Create extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slow queries
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### 6.3 VACUUM and ANALYZE

**Auto-vacuum is enabled by default. Monitor it:**

```sql
-- Check last vacuum/analyze times
SELECT
    schemaname,
    relname,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY relname;

-- Manual VACUUM if needed
VACUUM ANALYZE company;
VACUUM ANALYZE employee;

-- Full VACUUM (locks table - do during maintenance window)
VACUUM FULL ANALYZE employee;
```

**Schedule weekly VACUUM:**
```bash
# Add to cron (run as postgres user)
# Every Sunday at 2 AM
0 2 * * 0 /usr/bin/psql -U postgres -d hrms_saas -c "VACUUM ANALYZE;"
```

### 6.4 Connection Pooling

**Recommendation:** Use PgBouncer for connection pooling.

**Install PgBouncer:**
```bash
sudo apt-get install pgbouncer  # Debian/Ubuntu
sudo yum install pgbouncer      # RHEL/CentOS
```

**Configure:** `/etc/pgbouncer/pgbouncer.ini`
```ini
[databases]
hrms_saas = host=localhost port=5432 dbname=hrms_saas

[pgbouncer]
listen_addr = 127.0.0.1
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
server_lifetime = 3600
server_idle_timeout = 600
```

**Application Connection String:**
```
jdbc:postgresql://localhost:6432/hrms_saas
```

---

## 7. Backup and Recovery

### 7.1 Backup Strategy

**Full Backup (Daily):**
```bash
#!/bin/bash
# /opt/backups/backup_hrms.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/hrms_saas"
RETENTION_DAYS=30

# Create backup directory
mkdir -p $BACKUP_DIR

# Full database backup
pg_dump -U postgres -d hrms_saas -F c -f "$BACKUP_DIR/hrms_saas_full_$DATE.dump"

# Compress backup
gzip "$BACKUP_DIR/hrms_saas_full_$DATE.dump"

# Delete old backups (older than 30 days)
find $BACKUP_DIR -name "*.dump.gz" -mtime +$RETENTION_DAYS -delete

# Upload to S3 (optional)
# aws s3 cp "$BACKUP_DIR/hrms_saas_full_$DATE.dump.gz" s3://your-bucket/backups/
```

**Schedule via cron:**
```bash
# Daily at 1 AM
0 1 * * * /opt/backups/backup_hrms.sh >> /var/log/hrms_backup.log 2>&1
```

**Incremental Backup (WAL Archiving):**
```ini
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /opt/wal_archive/%f && cp %p /opt/wal_archive/%f'
```

### 7.2 Restore Procedures

**Full Restore:**
```bash
# Stop application
sudo systemctl stop spring-boot-app

# Drop and recreate database
sudo -u postgres psql -c "DROP DATABASE hrms_saas;"
sudo -u postgres psql -c "CREATE DATABASE hrms_saas;"

# Restore from backup
pg_restore -U postgres -d hrms_saas /opt/backups/hrms_saas/hrms_saas_full_20250129.dump

# Restart application
sudo systemctl start spring-boot-app
```

**Point-in-Time Recovery (PITR):**
```bash
# Restore base backup
pg_restore -U postgres -d hrms_saas /opt/backups/base_backup.dump

# Create recovery.conf
cat > /var/lib/postgresql/16/main/recovery.conf << EOF
restore_command = 'cp /opt/wal_archive/%f %p'
recovery_target_time = '2025-01-29 14:30:00'
EOF

# Start PostgreSQL (will apply WAL files)
sudo systemctl start postgresql-16
```

### 7.3 Test Restore Regularly

```bash
# Monthly restore test (on separate test server)
# 1. Restore latest backup to test server
# 2. Verify table counts match production
# 3. Run application smoke tests
# 4. Document test results
```

---

## 8. Monitoring and Maintenance

### 8.1 Database Monitoring

**Key Metrics to Monitor:**

```sql
-- 1. Database Size
SELECT
    pg_size_pretty(pg_database_size('hrms_saas')) AS database_size;

-- 2. Table Sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 3. Active Connections
SELECT
    COUNT(*) AS total_connections,
    COUNT(*) FILTER (WHERE state = 'active') AS active,
    COUNT(*) FILTER (WHERE state = 'idle') AS idle
FROM pg_stat_activity
WHERE datname = 'hrms_saas';

-- 4. Long-Running Queries
SELECT
    pid,
    now() - query_start AS duration,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle' AND query_start < now() - interval '5 minutes'
ORDER BY duration DESC;

-- 5. Blocking Queries
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- 6. Cache Hit Ratio (should be > 99%)
SELECT
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit) as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

### 8.2 Automated Monitoring Script

**Create:** `/opt/scripts/monitor_hrms_db.sh`

```bash
#!/bin/bash
# Database Health Check Script

DB_NAME="hrms_saas"
EMAIL="dba@company.com"
THRESHOLD_CONNECTIONS=180  # 90% of max_connections (200)

# Check connections
CONN_COUNT=$(psql -U postgres -d $DB_NAME -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$DB_NAME';")

if [ $CONN_COUNT -gt $THRESHOLD_CONNECTIONS ]; then
    echo "WARNING: High connection count: $CONN_COUNT" | mail -s "HRMS DB Alert" $EMAIL
fi

# Check for long-running queries
LONG_QUERIES=$(psql -U postgres -d $DB_NAME -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE state != 'idle' AND query_start < now() - interval '10 minutes';")

if [ $LONG_QUERIES -gt 0 ]; then
    echo "WARNING: $LONG_QUERIES long-running queries detected" | mail -s "HRMS DB Alert" $EMAIL
fi

# Check database size (alert if > 100GB)
DB_SIZE_MB=$(psql -U postgres -d $DB_NAME -t -c "SELECT pg_database_size('$DB_NAME') / 1024 / 1024;")
if [ $DB_SIZE_MB -gt 102400 ]; then
    echo "WARNING: Database size: ${DB_SIZE_MB}MB exceeds 100GB" | mail -s "HRMS DB Alert" $EMAIL
fi
```

**Schedule:**
```bash
# Every 15 minutes
*/15 * * * * /opt/scripts/monitor_hrms_db.sh
```

### 8.3 Maintenance Tasks

**Weekly:**
- Review slow query log
- Check table bloat
- Verify backups are successful
- Review connection pool metrics

**Monthly:**
- Review and update statistics (ANALYZE)
- Check index usage and remove unused indexes
- Test restore procedure
- Review disk space growth trends

**Quarterly:**
- Full VACUUM (during maintenance window)
- Review and optimize slow queries
- Capacity planning review
- Security audit

---

## 9. Security Considerations

### 9.1 Database Security Checklist

- ✅ **Encryption at rest:** Enable PostgreSQL data directory encryption
- ✅ **Encryption in transit:** Require SSL for all connections
- ✅ **Strong passwords:** Enforce complex passwords for DB users
- ✅ **Least privilege:** Application user has only necessary permissions
- ✅ **Audit logging:** Enable pgaudit extension
- ✅ **RLS enabled:** Row-Level Security enforced on all tenant tables
- ✅ **Firewall rules:** Restrict PostgreSQL port (5432) to application servers only

### 9.2 SSL Configuration

**Enable SSL in postgresql.conf:**
```ini
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
```

**Require SSL in pg_hba.conf:**
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
hostssl hrms_saas       hrms_app        0.0.0.0/0               md5
hostssl hrms_saas       postgres        127.0.0.1/32            md5
```

### 9.3 Audit Logging (pgaudit)

**Install pgaudit:**
```bash
sudo apt-get install postgresql-16-pgaudit
```

**Configure:**
```ini
# postgresql.conf
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'write, ddl'
pgaudit.log_catalog = off
pgaudit.log_relation = on
pgaudit.log_statement_once = on
```

**Verify:**
```sql
CREATE EXTENSION pgaudit;
SHOW pgaudit.log;
```

### 9.4 Sensitive Data Encryption

**Encrypt sensitive columns (PAN, Aadhaar, Bank Account):**

```sql
-- Example: Encrypt PAN number
-- Backend team will implement application-level encryption
-- DBA ensures pgcrypto extension is available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Test encryption (for verification only)
SELECT
    pgp_sym_encrypt('ABCDE1234F', 'encryption_key') AS encrypted,
    pgp_sym_decrypt(pgp_sym_encrypt('ABCDE1234F', 'encryption_key'), 'encryption_key') AS decrypted;
```

**Note:** Application-level encryption is preferred. Backend team will handle encryption/decryption.

---

## 10. Troubleshooting Guide

### 10.1 Common Issues

#### Issue 1: RLS Blocking Queries

**Symptom:** Application getting no results or errors like "permission denied"

**Diagnosis:**
```sql
-- Check if tenant context is set
SHOW app.current_tenant_id;
-- If empty or null, RLS will block queries

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'employee';
```

**Solution:**
```sql
-- Ensure application calls this at start of each request
SELECT set_current_tenant('<company_uuid>');
```

#### Issue 2: Slow Queries

**Symptom:** Queries taking > 1 second

**Diagnosis:**
```sql
-- Check query plan
EXPLAIN ANALYZE
SELECT * FROM employee WHERE company_id = '550e8400-e29b-41d4-a716-446655440000';

-- Check missing indexes
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'employee'
ORDER BY abs(correlation) DESC;
```

**Solution:**
- Add missing indexes
- Run VACUUM ANALYZE
- Review query plan and optimize

#### Issue 3: Connection Exhaustion

**Symptom:** "FATAL: too many connections"

**Diagnosis:**
```sql
-- Check connection count
SELECT COUNT(*) FROM pg_stat_activity;

-- Check idle connections
SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'idle';
```

**Solution:**
- Increase `max_connections` in postgresql.conf
- Implement connection pooling (PgBouncer)
- Fix connection leaks in application code

#### Issue 4: Disk Space Full

**Symptom:** "ERROR: could not extend file: No space left on device"

**Diagnosis:**
```bash
df -h  # Check disk space
du -sh /var/lib/postgresql/16/main  # Check DB directory size
```

**Solution:**
```sql
-- Find largest tables
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Clean up old data (if applicable)
DELETE FROM employee_education WHERE created_at < now() - interval '5 years';
VACUUM FULL;
```

### 10.2 Emergency Procedures

**Kill Long-Running Query:**
```sql
-- Find query PID
SELECT pid, query_start, state, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Terminate query
SELECT pg_terminate_backend(12345);  -- Replace with actual PID
```

**Kill All Connections (Emergency Maintenance):**
```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'hrms_saas' AND pid <> pg_backend_pid();
```

---

## 11. Integration Points

### 11.1 Backend Team Integration

**Backend team needs:**

1. **Database Connection Details:**
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/hrms_saas
spring.datasource.username=hrms_app
spring.datasource.password=<password>
spring.datasource.driver-class-name=org.postgresql.Driver
```

2. **Tenant Context Function:**
```java
// Backend must call this for every request
jdbcTemplate.execute("SELECT set_current_tenant('" + companyId + "')");
```

3. **Helper Functions Available:**
- `get_employee_count(tenant_id, include_subsidiaries)` - Get employee count
- `get_subsidiary_companies(parent_id)` - List subsidiaries
- `is_parent_company(company_id)` - Check if company is parent
- `get_corporate_group_summary(group_name)` - Group statistics

### 11.2 Keycloak Integration

**Keycloak user attributes must map to database:**

| Keycloak Attribute | Database Column | Table |
|--------------------|-----------------|-------|
| `company_id` | `id` | `company` |
| `employee_id` | `id` | `employee` |
| `email` | `email` | `employee` |

**DBA Action Required:**
- No direct integration needed
- Backend team handles user sync from Keycloak to database

### 11.3 Monitoring Tools Integration

**Recommended Tools:**
- **pgAdmin:** GUI for database management
- **Grafana + Prometheus:** Metrics visualization
- **ELK Stack:** Log aggregation and analysis

**Export Metrics:**
```sql
-- Create monitoring view
CREATE OR REPLACE VIEW v_database_metrics AS
SELECT
    (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'hrms_saas') AS total_connections,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'hrms_saas' AND state = 'active') AS active_connections,
    (SELECT COUNT(*) FROM company WHERE status = 'active') AS active_companies,
    (SELECT COUNT(*) FROM employee WHERE status = 'active') AS active_employees,
    pg_database_size('hrms_saas') AS database_size_bytes;

-- Grant read access to monitoring user
GRANT SELECT ON v_database_metrics TO monitoring_user;
```

---

## Appendix

### A. Database Schema Diagram

```
company (Parent Table - Multi-Tenancy Root)
├── parent_company_id (self-referencing FK)
├── billing_company_id (FK to company)
└── employee (1:N relationship)
    ├── company_id (FK - CRITICAL for RLS)
    ├── reporting_manager_id (self-referencing FK)
    ├── employee_education (1:N)
    └── employee_experience (1:N)

department_master
└── owner_company_id (FK to company)

designation_master
└── owner_company_id (FK to company)
```

### B. Contact Information

| Role | Contact | Purpose |
|------|---------|---------|
| Spring Boot Team Lead | <backend-lead-email> | Tenant context, JPA queries |
| Keycloak Team Lead | <keycloak-lead-email> | User attribute mapping |
| DevOps Lead | <devops-lead-email> | Server provisioning, SSL certs |
| Security Team | <security-lead-email> | Encryption, audit logs |

### C. Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-29 | Claude Code | Initial DBA documentation for V2 schema |

---

**End of DBA Notes**

For questions or clarifications, contact the project DBA or backend team lead.
