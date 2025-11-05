# HRMS SaaS Database Documentation

## Document Information
- **Generated Date**: November 5, 2025
- **Database System**: PostgreSQL 16
- **Container Name**: nexus-postgres-dev
- **Port**: 5432
- **Database User**: admin

---

## Table of Contents
1. [Database Overview](#database-overview)
2. [Schemas](#schemas)
3. [Tables](#tables)
4. [Detailed Table Structures](#detailed-table-structures)
5. [Indexes](#indexes)
6. [Constraints](#constraints)
7. [Database Statistics](#database-statistics)

---

## Database Overview

### Available Databases

| Database Name | Owner | Encoding | Collation  | Character Type |
|---------------|-------|----------|------------|----------------|
| hrms_saas     | admin | UTF8     | en_US.utf8 | en_US.utf8     |
| postgres      | admin | UTF8     | en_US.utf8 | en_US.utf8     |
| template0     | admin | UTF8     | en_US.utf8 | en_US.utf8     |
| template1     | admin | UTF8     | en_US.utf8 | en_US.utf8     |

**Primary Database**: `hrms_saas`

---

## Schemas

### Schema List

| Schema Name | Owner             | Description                |
|-------------|-------------------|----------------------------|
| public      | pg_database_owner | standard public schema     |

**Note**: All application tables are currently in the `public` schema.

---

## Tables

### Table Summary

| Schema | Table Name            | Owner | Purpose                                    |
|--------|-----------------------|-------|--------------------------------------------|
| public | company_master        | admin | Stores company/tenant master information   |
| public | flyway_schema_history | admin | Tracks database migration history (Flyway) |

**Total Tables**: 2

---

## Detailed Table Structures

### 1. company_master

**Purpose**: Master table for managing company/tenant information in the multi-tenant SaaS application.

**Record Count**: 2

#### Columns

| Column Name       | Data Type            | Length | Nullable | Default Value         | Description                           |
|-------------------|----------------------|--------|----------|-----------------------|---------------------------------------|
| tenant_id         | VARCHAR              | 21     | NO       |                       | Primary key, unique tenant identifier |
| company_name      | VARCHAR              | 255    | NO       |                       | Company name (min length enforced)    |
| company_code      | VARCHAR              | 50     | YES      |                       | Optional company code                 |
| email             | VARCHAR              | 255    | NO       |                       | Company email (unique, validated)     |
| phone             | VARCHAR              | 50     | YES      |                       | Contact phone number                  |
| address           | TEXT                 |        | YES      |                       | Company address                       |
| status            | VARCHAR              | 30     | YES      | 'PENDING_ACTIVATION'  | Account status                        |
| subscription_plan | VARCHAR              | 50     | YES      | 'FREE'                | Subscription tier                     |
| created_at        | TIMESTAMP            |        | YES      | now()                 | Record creation timestamp             |
| updated_at        | TIMESTAMP            |        | YES      | now()                 | Last update timestamp                 |
| created_by        | VARCHAR              | 100    | YES      |                       | User who created the record           |

#### Business Rules
- Email must be in valid format (enforced by CHECK constraint)
- Company name must meet minimum length requirement
- Default status is 'PENDING_ACTIVATION' for new companies
- Default subscription plan is 'FREE'
- Timestamps are automatically set

---

### 2. flyway_schema_history

**Purpose**: Internal Flyway table that tracks all database migrations for version control and rollback capabilities.

#### Columns

| Column Name    | Data Type  | Length | Nullable | Default | Description                          |
|----------------|------------|--------|----------|---------|--------------------------------------|
| installed_rank | INTEGER    |        | NO       |         | Primary key, sequential rank         |
| version        | VARCHAR    | 50     | YES      |         | Migration version number             |
| description    | VARCHAR    | 200    | NO       |         | Migration description                |
| type           | VARCHAR    | 20     | NO       |         | Migration type (SQL, JDBC, etc.)     |
| script         | VARCHAR    | 1000   | NO       |         | Script filename                      |
| checksum       | INTEGER    |        | YES      |         | Script checksum for validation       |
| installed_by   | VARCHAR    | 100    | NO       |         | User who ran the migration           |
| installed_on   | TIMESTAMP  |        | NO       | now()   | Migration execution timestamp        |
| execution_time | INTEGER    |        | NO       |         | Execution duration in milliseconds   |
| success        | BOOLEAN    |        | NO       |         | Migration success status             |

---

## Indexes

### company_master Indexes

| Index Name                  | Type   | Columns            | Purpose                                    |
|-----------------------------|--------|--------------------|---------------------------------------------|
| company_master_pkey         | UNIQUE | tenant_id          | Primary key index                           |
| company_master_email_key    | UNIQUE | email              | Ensures email uniqueness across tenants     |
| idx_company_email           | BTREE  | email              | Improves email lookup performance           |
| idx_company_status          | BTREE  | status             | Optimizes queries filtering by status       |
| idx_company_subscription    | BTREE  | subscription_plan  | Optimizes subscription-based queries        |

### flyway_schema_history Indexes

| Index Name                  | Type   | Columns        | Purpose                        |
|-----------------------------|--------|----------------|--------------------------------|
| flyway_schema_history_pk    | UNIQUE | installed_rank | Primary key index              |
| flyway_schema_history_s_idx | BTREE  | success        | Optimizes success status queries|

---

## Constraints

### company_master Constraints

| Constraint Name           | Type        | Column      | Description                                |
|---------------------------|-------------|-------------|--------------------------------------------|
| company_master_pkey       | PRIMARY KEY | tenant_id   | Primary key constraint                     |
| company_master_email_key  | UNIQUE      | email       | Ensures unique email addresses             |
| email_format              | CHECK       | email       | Validates email format                     |
| company_name_min_length   | CHECK       | company_name| Enforces minimum company name length       |
| 2200_16398_1_not_null     | CHECK       | tenant_id   | NOT NULL enforcement                       |
| 2200_16398_2_not_null     | CHECK       | company_name| NOT NULL enforcement                       |
| 2200_16398_4_not_null     | CHECK       | email       | NOT NULL enforcement                       |

### flyway_schema_history Constraints

| Constraint Name          | Type        | Column         | Description                    |
|--------------------------|-------------|----------------|--------------------------------|
| flyway_schema_history_pk | PRIMARY KEY | installed_rank | Primary key constraint         |
| Multiple NOT NULL checks | CHECK       | Various        | NOT NULL enforcement           |

---

## Database Statistics

### General Statistics

- **Total Databases**: 4 (1 application database + 3 system databases)
- **Total Schemas**: 1 (public schema for application)
- **Total Tables**: 2 (1 application table + 1 migration table)
- **Total Indexes**: 7 (5 on company_master + 2 on flyway_schema_history)
- **Total Records**: 2 companies registered

### Storage and Performance

- **Database Encoding**: UTF8
- **Locale**: en_US.utf8
- **PostgreSQL Version**: 16
- **Index Strategy**: B-tree indexes for optimal query performance

---

## Connection Information

### Local Development

```bash
# Using podman exec
podman exec nexus-postgres-dev psql -U admin -d hrms_saas

# Using psql directly (from host)
psql -h localhost -p 5432 -U admin -d hrms_saas
```

### Environment Variables

```
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
POSTGRES_DB=hrms_saas
PGDATA=/var/lib/postgresql/data
```

---

## Multi-Tenant Architecture Notes

The database follows a **shared database with row-level security** approach:

1. **company_master** table serves as the tenant registry
2. Each tenant is identified by a unique `tenant_id`
3. Future tenant-specific data will likely use the `tenant_id` for data isolation
4. Row-Level Security (RLS) may be implemented for enhanced security

---

## Migration Management

The database uses **Flyway** for version-controlled migrations:

- All migrations are tracked in `flyway_schema_history`
- Migration scripts are versioned and checksummed
- Provides rollback capabilities and migration history
- Ensures consistent database state across environments

---

## Future Considerations

Based on the current structure, the following expansions are likely:

1. **Employee Tables**: Employee master, attendance, leave management
2. **Payroll Tables**: Salary structures, payroll processing
3. **Department Tables**: Organizational hierarchy
4. **Audit Tables**: Tracking changes and user actions
5. **Additional Tenant Schemas**: Possible schema-per-tenant approach for larger clients
6. **RLS Policies**: Row-level security implementation for data isolation

---

## Maintenance Commands

### Backup Database
```bash
podman exec nexus-postgres-dev pg_dump -U admin hrms_saas > hrms_saas_backup.sql
```

### Restore Database
```bash
podman exec -i nexus-postgres-dev psql -U admin hrms_saas < hrms_saas_backup.sql
```

### Check Database Size
```sql
SELECT pg_size_pretty(pg_database_size('hrms_saas')) as database_size;
```

### Check Table Sizes
```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## Document Maintenance

This document should be updated whenever:
- New tables are added
- Schema changes are made
- Indexes are added or modified
- Constraints are changed
- Major configuration updates occur

**Last Updated**: November 5, 2025
**Maintained By**: DBA Team
