#!/bin/bash
# ==============================================================================
# Database Status Script - QA Environment
# Shows comprehensive status of the QA PostgreSQL database
# ==============================================================================

set -e

CONTAINER_NAME="nexus-postgres-qa"
DB_NAME="hrms_saas_qa"
DB_USER="admin"

echo "=========================================="
echo "HRMS SaaS QA Database Status"
echo "=========================================="
echo ""

# Check if container exists
if ! podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '${CONTAINER_NAME}' not found!"
    echo "   Create it with: ./bin/create-qa-container.sh"
    exit 1
fi

# Container status
echo "📦 Container Status:"
if podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "   ✅ Running"
    podman ps --filter "name=${CONTAINER_NAME}" --format "   Name: {{.Names}}\n   Status: {{.Status}}\n   Ports: {{.Ports}}"
else
    echo "   ❌ Stopped"
    echo "   Start with: podman start ${CONTAINER_NAME}"
    exit 0
fi

echo ""

# PostgreSQL readiness
echo "🔌 Database Connection:"
if podman exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
    echo "   ✅ PostgreSQL is ready and accepting connections"
else
    echo "   ❌ PostgreSQL is not ready"
    exit 1
fi

echo ""

# Database information
echo "📊 Database Information:"
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "\l ${DB_NAME}" 2>/dev/null | grep ${DB_NAME} || true

echo ""

# Table count
TABLE_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
echo "📋 Tables: ${TABLE_COUNT}"

if [ "${TABLE_COUNT}" -gt 0 ]; then
    echo ""
    echo "Table List:"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "\dt" 2>/dev/null
fi

echo ""

# Row counts for key tables
echo "📈 Record Counts:"
if [ "${TABLE_COUNT}" -gt 0 ]; then
    COMPANY_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
      "SELECT COUNT(*) FROM company;" 2>/dev/null || echo "0")
    EMPLOYEE_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
      "SELECT COUNT(*) FROM employee;" 2>/dev/null || echo "0")
    DEPT_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
      "SELECT COUNT(*) FROM department_master;" 2>/dev/null || echo "0")
    DESIG_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
      "SELECT COUNT(*) FROM designation_master;" 2>/dev/null || echo "0")

    echo "   Companies:    ${COMPANY_COUNT}"
    echo "   Employees:    ${EMPLOYEE_COUNT}"
    echo "   Departments:  ${DEPT_COUNT}"
    echo "   Designations: ${DESIG_COUNT}"
else
    echo "   ⚠️  No tables found - schema not applied yet"
    echo "   Apply schema with: ./bin/apply-schema-qa.sh"
fi

echo ""

# Active connections
echo "🔗 Active Connections:"
CONN_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname = '${DB_NAME}';" 2>/dev/null || echo "0")
echo "   ${CONN_COUNT} active connection(s)"

echo ""

# Database size
echo "💾 Database Size:"
DB_SIZE=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
  "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));" 2>/dev/null || echo "Unknown")
echo "   ${DB_SIZE}"

echo ""
echo "=========================================="
echo "Quick Commands:"
echo "=========================================="
echo "  Apply schema:    ./bin/apply-schema-qa.sh"
echo "  Load ref data:   ./bin/load-reference-data-qa.sh"
echo "  Load test data:  ./bin/load-test-data-qa.sh"
echo "  Connect to DB:   podman exec -it ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME}"
echo "  View logs:       podman logs ${CONTAINER_NAME}"
echo "  Stop container:  podman stop ${CONTAINER_NAME}"
echo ""
