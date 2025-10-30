#!/bin/bash
# ==============================================================================
# Database Connection Script
# Opens an interactive psql session to the database
# ==============================================================================

CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"

# Default to admin user
DB_USER="${1:-admin}"

echo "=========================================="
echo "Connecting to HRMS SaaS Database"
echo "=========================================="
echo ""
echo "Database: ${DB_NAME}"
echo "User:     ${DB_USER}"
echo ""
echo "Tips:"
echo "  \\dt              - List all tables"
echo "  \\d table_name    - Describe a table"
echo "  \\l               - List all databases"
echo "  \\q               - Quit"
echo ""
echo "To disable RLS (admin only):"
echo "  SET row_security = OFF;"
echo ""
echo "=========================================="
echo ""

# Check if container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container is not running!"
    echo "   Start it with: ./bin/db-start.sh"
    exit 1
fi

# Connect to database
podman exec -it ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME}
