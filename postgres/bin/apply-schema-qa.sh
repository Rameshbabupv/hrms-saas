#!/bin/bash
# ==============================================================================
# Apply Database Schema to QA Environment
# Applies all schema files to the QA database
# ==============================================================================

set -e

CONTAINER_NAME="nexus-postgres-qa"
DB_NAME="hrms_saas_qa"
DB_USER="admin"
APP_USER="hrms_app"

SCHEMA_DIR="postgres-docs/schemas"

echo "=========================================="
echo "Applying Database Schema to QA"
echo "=========================================="
echo ""

# Check if container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '${CONTAINER_NAME}' is not running!"
    echo "   Start it with: podman start ${CONTAINER_NAME}"
    exit 1
fi

# Check if schema files exist
if [ ! -d "${SCHEMA_DIR}" ]; then
    echo "❌ Error: Schema directory '${SCHEMA_DIR}' not found!"
    exit 1
fi

echo "Step 1/3: Applying core schema with hierarchy support..."
if [ -f "${SCHEMA_DIR}/saas_mvp_schema_v2_with_hierarchy.sql" ]; then
    podman exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} < \
      ${SCHEMA_DIR}/saas_mvp_schema_v2_with_hierarchy.sql

    if [ $? -eq 0 ]; then
        echo "✅ Core schema applied successfully"
    else
        echo "❌ Core schema failed"
        exit 1
    fi
else
    echo "❌ Core schema file not found!"
    exit 1
fi

echo ""
echo "Step 2/3: Applying audit schema..."
if [ -f "${SCHEMA_DIR}/saas_mvp_audit_schema.sql" ]; then
    podman exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} < \
      ${SCHEMA_DIR}/saas_mvp_audit_schema.sql

    if [ $? -eq 0 ]; then
        echo "✅ Audit schema applied successfully"
    else
        echo "❌ Audit schema failed"
        exit 1
    fi
else
    echo "❌ Audit schema file not found!"
    exit 1
fi

echo ""
echo "Step 3/3: Granting permissions to application user..."
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${APP_USER};"

podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${APP_USER};"

podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_USER};"

podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ${APP_USER};"

echo "✅ Permissions granted successfully"

echo ""
echo "=========================================="
echo "Verifying Schema Application"
echo "=========================================="
echo ""

# Count tables
TABLE_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")

echo "Tables created: ${TABLE_COUNT}"

if [ "${TABLE_COUNT}" -ge 12 ]; then
    echo "✅ Expected number of tables created (12+)"
else
    echo "⚠️  Warning: Expected 12+ tables, found ${TABLE_COUNT}"
fi

echo ""
echo "Table List:"
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "\dt"

echo ""
echo "=========================================="
echo "Schema Migration Completed Successfully!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "  1. Load reference data: ./bin/load-reference-data-qa.sh"
echo "  2. Load test data:      ./bin/load-test-data-qa.sh"
echo "  3. Check status:        ./bin/db-status-qa.sh"
echo ""
