#!/bin/bash
# ==============================================================================
# Load Reference Data to QA Environment
# Loads department and designation master data
# ==============================================================================

set -e

CONTAINER_NAME="nexus-postgres-qa"
DB_NAME="hrms_saas_qa"
DB_USER="admin"
DATA_FILE="postgres-docs/data/reference_data.sql"

echo "=========================================="
echo "Loading Reference Data to QA"
echo "=========================================="
echo ""

# Check if container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '${CONTAINER_NAME}' is not running!"
    echo "   Start it with: podman start ${CONTAINER_NAME}"
    exit 1
fi

# Check if data file exists
if [ ! -f "${DATA_FILE}" ]; then
    echo "❌ Error: Reference data file '${DATA_FILE}' not found!"
    exit 1
fi

echo "📋 Loading reference data..."
echo "   Departments: 10 records"
echo "   Designations: 22 records"
echo ""

podman exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} < ${DATA_FILE}

if [ $? -eq 0 ]; then
    echo "✅ Reference data loaded successfully"
else
    echo "❌ Reference data loading failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Verifying Reference Data"
echo "=========================================="
echo ""

# Verify departments
DEPT_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
  "SELECT COUNT(*) FROM department_master WHERE is_shared_master = true;")
echo "Departments loaded: ${DEPT_COUNT} (expected: 10)"

# Verify designations
DESIG_COUNT=$(podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
  "SELECT COUNT(*) FROM designation_master WHERE is_shared_master = true;")
echo "Designations loaded: ${DESIG_COUNT} (expected: 22)"

echo ""
echo "Sample Departments:"
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "SELECT department_code, department_name, status FROM department_master WHERE is_shared_master = true LIMIT 5;"

echo ""
echo "Sample Designations:"
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "SELECT designation_code, designation_name, designation_level FROM designation_master WHERE is_shared_master = true ORDER BY designation_level LIMIT 5;"

echo ""
echo "=========================================="
echo "Reference Data Loaded Successfully!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "  1. Load test data: ./bin/load-test-data-qa.sh"
echo "  2. Check status:   ./bin/db-status-qa.sh"
echo ""
