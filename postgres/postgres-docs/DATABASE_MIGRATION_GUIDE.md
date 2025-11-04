# Database Migration Guide: DEV → QA → PROD

**Purpose**: Comprehensive guide for recreating database instances across environments while maintaining consistency, data integrity, and repeatability.

---

## 📋 Overview

This guide covers the complete process of creating new database instances (QA, PROD, DR) from your existing DEV setup. The approach ensures:
- ✅ **Repeatability**: Same process works across all environments
- ✅ **Version Control**: All schema changes tracked in Git
- ✅ **Data Consistency**: Reference data synchronized
- ✅ **Zero Downtime**: Migration strategies for production
- ✅ **Rollback Safety**: Ability to revert changes

---

## 🏗️ Architecture Overview

### Current Setup (DEV)
```
Container: nexus-postgres-dev
Port: 5432
Database: hrms_saas
User: admin / hrms_app
Schemas: 12 tables (6 core + 6 audit)
```

### Proposed Multi-Environment Setup
```
DEV:  nexus-postgres-dev   → Port 5432  → hrms_saas_dev
QA:   nexus-postgres-qa    → Port 5433  → hrms_saas_qa
PROD: nexus-postgres-prod  → Port 5434  → hrms_saas_prod
```

---

## 🎯 Best Practices for Database Portability

### 1. **Version-Controlled Schema Management**
✅ **Use SQL migration scripts** (already in place)
- `postgres-docs/schemas/saas_mvp_schema_v2_with_hierarchy.sql`
- `postgres-docs/schemas/saas_mvp_audit_schema.sql`

✅ **Add migration tool** (recommended: Flyway, already in Spring Boot)
```xml
<!-- In springboot/pom.xml -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
```

### 2. **Separate Data Types**

| Data Type | Management Strategy | Example |
|-----------|-------------------|---------|
| **Schema Objects** | SQL scripts in Git | Tables, indexes, RLS policies |
| **Reference Data** | SQL seed scripts | Departments, designations |
| **Test Data** | Separate seed files | Sample companies, employees |
| **Production Data** | Backup/restore or replication | Real customer data |

### 3. **Environment-Specific Configuration**
Use environment variables for:
- Database credentials
- Container names
- Port numbers
- Connection strings

---

## 🚀 Step-by-Step: Creating QA Database

### **Phase 1: Container Setup**

#### Step 1.1: Create QA Container
```bash
#!/bin/bash
# File: bin/create-qa-container.sh

CONTAINER_NAME="nexus-postgres-qa"
DB_NAME="hrms_saas_qa"
DB_USER="admin"
DB_PASS="admin123"  # Use secrets management in production
APP_USER="hrms_app"
APP_PASS="hrms_app123"
PORT="5433"

echo "Creating PostgreSQL QA container..."

podman run -d \
  --name ${CONTAINER_NAME} \
  -e POSTGRES_USER=${DB_USER} \
  -e POSTGRES_PASSWORD=${DB_PASS} \
  -e POSTGRES_DB=${DB_NAME} \
  -p ${PORT}:5432 \
  -v pgdata-qa:/var/lib/postgresql/data \
  docker.io/library/postgres:16

echo "Waiting for PostgreSQL to start..."
sleep 5

# Create application user
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "CREATE USER ${APP_USER} WITH PASSWORD '${APP_PASS}';"

podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${APP_USER};"

echo "✅ QA database container created successfully!"
echo "   Connection: localhost:${PORT}"
echo "   Database: ${DB_NAME}"
```

#### Step 1.2: Verify Container
```bash
podman ps | grep nexus-postgres-qa
podman exec nexus-postgres-qa pg_isready -U admin -d hrms_saas_qa
```

---

### **Phase 2: Schema Migration**

#### Step 2.1: Apply Core Schema
```bash
#!/bin/bash
# File: bin/apply-schema-qa.sh

CONTAINER_NAME="nexus-postgres-qa"
DB_NAME="hrms_saas_qa"
DB_USER="admin"

echo "=========================================="
echo "Applying Database Schema to QA"
echo "=========================================="

# 1. Apply core schema (tables, enums, constraints)
echo "Step 1/3: Applying core schema..."
podman exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} < \
  postgres-docs/schemas/saas_mvp_schema_v2_with_hierarchy.sql

if [ $? -eq 0 ]; then
    echo "✅ Core schema applied successfully"
else
    echo "❌ Core schema failed"
    exit 1
fi

# 2. Apply audit schema
echo "Step 2/3: Applying audit schema..."
podman exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} < \
  postgres-docs/schemas/saas_mvp_audit_schema.sql

if [ $? -eq 0 ]; then
    echo "✅ Audit schema applied successfully"
else
    echo "❌ Audit schema failed"
    exit 1
fi

# 3. Grant permissions to application user
echo "Step 3/3: Granting permissions..."
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hrms_app;"

podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hrms_app;"

echo "✅ Schema migration completed successfully!"
echo ""
echo "Verify with: ./bin/db-status.sh qa"
```

#### Step 2.2: Verify Schema
```bash
# Check tables
podman exec nexus-postgres-qa psql -U admin -d hrms_saas_qa -c "\dt"

# Count tables
podman exec nexus-postgres-qa psql -U admin -d hrms_saas_qa -c \
  "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public';"

# Expected output: 12 tables (6 core + 6 audit)
```

---

### **Phase 3: Reference Data Migration**

#### Step 3.1: Create Reference Data Script
```bash
# File: postgres-docs/data/reference_data.sql

-- ================================================================
-- Reference Data: Departments and Designations
-- Run this in ALL environments (DEV, QA, PROD)
-- ================================================================

-- Sample Departments (shared across corporate groups)
INSERT INTO department_master (id, department_code, department_name, department_description, is_shared_master, status) VALUES
('11111111-1111-1111-1111-111111111111', 'TECH', 'Technology', 'IT and Software Development', true, 'active'),
('22222222-2222-2222-2222-222222222222', 'HR', 'Human Resources', 'People Operations', true, 'active'),
('33333333-3333-3333-3333-333333333333', 'FIN', 'Finance', 'Financial Operations', true, 'active'),
('44444444-4444-4444-4444-444444444444', 'OPS', 'Operations', 'Business Operations', true, 'active'),
('55555555-5555-5555-5555-555555555555', 'SALES', 'Sales', 'Sales and Marketing', true, 'active');

-- Sample Designations
INSERT INTO designation_master (id, designation_code, designation_name, designation_level, is_shared_master, status) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'CEO', 'Chief Executive Officer', 1, true, 'active'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'CTO', 'Chief Technology Officer', 2, true, 'active'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'MGR', 'Manager', 3, true, 'active'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'LEAD', 'Team Lead', 4, true, 'active'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'ENG', 'Software Engineer', 5, true, 'active'),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'INTERN', 'Intern', 6, true, 'active');
```

#### Step 3.2: Apply Reference Data
```bash
#!/bin/bash
# File: bin/load-reference-data-qa.sh

CONTAINER_NAME="nexus-postgres-qa"
DB_NAME="hrms_saas_qa"
DB_USER="admin"

echo "Loading reference data to QA..."

podman exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} < \
  postgres-docs/data/reference_data.sql

echo "✅ Reference data loaded successfully!"
```

---

### **Phase 4: Test Data (QA Only)**

#### Step 4.1: Create Test Data Script
```bash
# File: postgres-docs/data/test_data_qa.sql

-- ================================================================
-- Test Data for QA Environment
-- DO NOT run in PRODUCTION
-- ================================================================

-- Test Companies
INSERT INTO company (id, company_name, company_code, company_type, tenant_id, status) VALUES
('c0000001-0000-0000-0000-000000000001', 'Test Corp QA', 'TESTQA01', 'independent', 'qa_tenant_001', 'active'),
('c0000002-0000-0000-0000-000000000002', 'Demo Inc QA', 'TESTQA02', 'independent', 'qa_tenant_002', 'active');

-- Test Employees (at least 2 per company)
-- Add employee insert statements here...
```

---

## 🔄 Migration Strategies

### Strategy 1: **Fresh Install** (Recommended for QA)
✅ Best for: QA, UAT, Development environments
✅ Steps:
1. Create new container
2. Apply schema scripts
3. Load reference data
4. Load test data

### Strategy 2: **Backup & Restore** (For Production)
✅ Best for: PROD, DR environments with existing data
✅ Steps:
```bash
# Backup from DEV
podman exec nexus-postgres-dev pg_dump -U admin -d hrms_saas -F c -f /tmp/hrms_backup.dump

# Copy dump file
podman cp nexus-postgres-dev:/tmp/hrms_backup.dump ./backups/

# Restore to QA
podman cp ./backups/hrms_backup.dump nexus-postgres-qa:/tmp/
podman exec nexus-postgres-qa pg_restore -U admin -d hrms_saas_qa /tmp/hrms_backup.dump
```

### Strategy 3: **Schema-Only Migration** (Most Common)
✅ Best for: Promoting schema changes across environments
✅ Steps:
1. Export schema only (no data)
2. Apply to target environment
3. Verify with automated tests

```bash
# Export schema only
podman exec nexus-postgres-dev pg_dump -U admin -d hrms_saas --schema-only -f /tmp/schema.sql

# Apply to QA
podman cp nexus-postgres-dev:/tmp/schema.sql ./
podman exec -i nexus-postgres-qa psql -U admin -d hrms_saas_qa < schema.sql
```

---

## 🛠️ Automation Scripts

### Script 1: Environment Manager
```bash
#!/bin/bash
# File: bin/db-environment.sh

ENV=$1  # dev, qa, prod

case $ENV in
  dev)
    export CONTAINER_NAME="nexus-postgres-dev"
    export DB_PORT="5432"
    export DB_NAME="hrms_saas_dev"
    ;;
  qa)
    export CONTAINER_NAME="nexus-postgres-qa"
    export DB_PORT="5433"
    export DB_NAME="hrms_saas_qa"
    ;;
  prod)
    export CONTAINER_NAME="nexus-postgres-prod"
    export DB_PORT="5434"
    export DB_NAME="hrms_saas_prod"
    ;;
  *)
    echo "Usage: $0 {dev|qa|prod}"
    exit 1
    ;;
esac

echo "Environment: $ENV"
echo "Container: $CONTAINER_NAME"
echo "Port: $DB_PORT"
echo "Database: $DB_NAME"
```

### Script 2: Schema Migration Runner
```bash
#!/bin/bash
# File: bin/migrate-schema.sh

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: $0 {dev|qa|prod}"
  exit 1
fi

source bin/db-environment.sh $ENV

echo "Migrating schema to $ENV environment..."

# Apply all migration scripts in order
for migration_file in postgres-docs/schemas/*.sql; do
  echo "Applying: $migration_file"
  podman exec -i ${CONTAINER_NAME} psql -U admin -d ${DB_NAME} < "$migration_file"
done

echo "✅ Migration completed!"
```

---

## 📊 Verification Checklist

After creating QA database, verify:

- [ ] **Container Running**: `podman ps | grep nexus-postgres-qa`
- [ ] **Connection Works**: `podman exec nexus-postgres-qa pg_isready -U admin -d hrms_saas_qa`
- [ ] **12 Tables Created**: Check with `\dt` in psql
- [ ] **RLS Policies Active**: `SELECT * FROM pg_policies;`
- [ ] **Reference Data Loaded**: Check department_master and designation_master
- [ ] **Permissions Granted**: Application user can CRUD
- [ ] **Port Accessible**: Connect from application on port 5433

---

## 🔐 Security Best Practices

1. **Never commit credentials** to Git
   - Use `.env` files (in `.gitignore`)
   - Use secret management tools (Vault, AWS Secrets Manager)

2. **Different credentials per environment**
   ```bash
   DEV:  admin/admin123 (ok for local)
   QA:   admin/[strong-password]
   PROD: admin/[vault-managed-password]
   ```

3. **Network isolation**
   - DEV: localhost only
   - QA: VPN or internal network
   - PROD: Private subnet, no direct access

4. **Backup encryption**
   ```bash
   pg_dump ... | gpg --encrypt --recipient ops@company.com > backup.sql.gpg
   ```

---

## 📈 Monitoring & Maintenance

### Regular Tasks
```bash
# Weekly: Backup QA database
./bin/backup-database.sh qa

# Monthly: Refresh QA with production-like data
./bin/refresh-qa-from-prod.sh

# Daily: Monitor connection pool
podman exec nexus-postgres-qa psql -U admin -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname = 'hrms_saas_qa';"
```

---

## 🆘 Troubleshooting

### Issue 1: Container won't start
```bash
# Check logs
podman logs nexus-postgres-qa

# Restart podman machine (macOS)
podman machine stop
podman machine start
```

### Issue 2: Schema errors during migration
```bash
# Rollback: Drop and recreate database
podman exec nexus-postgres-qa psql -U admin -c "DROP DATABASE hrms_saas_qa;"
podman exec nexus-postgres-qa psql -U admin -c "CREATE DATABASE hrms_saas_qa;"
# Re-run migration scripts
```

### Issue 3: Permission denied errors
```bash
# Re-grant all permissions
podman exec nexus-postgres-qa psql -U admin -d hrms_saas_qa -c \
  "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO hrms_app;"
```

---

## 🎯 Quick Start Commands

```bash
# Create QA environment (complete setup)
./bin/create-qa-environment.sh

# Apply schema to QA
./bin/migrate-schema.sh qa

# Load reference data
./bin/load-reference-data.sh qa

# Load test data (QA only)
./bin/load-test-data.sh qa

# Verify QA setup
./bin/verify-environment.sh qa
```

---

## 📚 Related Documentation

- [DBA_NOTES.md](./DBA_NOTES.md) - Database administration guide
- [DATABASE_SETUP_STATUS.md](./DATABASE_SETUP_STATUS.md) - Setup progress tracking
- [schemas/README.md](./schemas/README.md) - Schema documentation

---

**Last Updated**: 2025-11-04
**Maintained By**: Database Team
**Questions**: See DBA_NOTES.md or contact DevOps
