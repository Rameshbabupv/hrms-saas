#!/bin/bash
# ==============================================================================
# Database Start Script
# Starts the PostgreSQL container for HRMS SaaS
# ==============================================================================

set -e

CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"

echo "=========================================="
echo "Starting HRMS SaaS PostgreSQL Database"
echo "=========================================="
echo ""

# Check if container exists
if ! podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '${CONTAINER_NAME}' not found!"
    echo "   Please create the container first."
    exit 1
fi

# Check if already running
if podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "✅ Container '${CONTAINER_NAME}' is already running"
else
    echo "🚀 Starting container '${CONTAINER_NAME}'..."
    podman start ${CONTAINER_NAME}

    # Wait for PostgreSQL to be ready
    echo "⏳ Waiting for PostgreSQL to be ready..."
    sleep 3

    # Check if database is accessible
    if podman exec ${CONTAINER_NAME} pg_isready -U admin -d ${DB_NAME} > /dev/null 2>&1; then
        echo "✅ PostgreSQL is ready and accepting connections"
    else
        echo "⚠️  PostgreSQL started but not ready yet, waiting..."
        sleep 2
        if podman exec ${CONTAINER_NAME} pg_isready -U admin -d ${DB_NAME} > /dev/null 2>&1; then
            echo "✅ PostgreSQL is now ready"
        else
            echo "❌ Error: PostgreSQL is not responding"
            exit 1
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Database Information"
echo "=========================================="
podman exec ${CONTAINER_NAME} psql -U admin -d ${DB_NAME} -c "\l ${DB_NAME}" 2>/dev/null | grep ${DB_NAME} || true
echo ""
echo "Container Status:"
podman ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "✅ Database is ready!"
echo "   Connection: localhost:5432"
echo "   Database: ${DB_NAME}"
echo "   User: hrms_app"
echo ""
echo "Quick Commands:"
echo "   ./bin/db-status.sh     - Check database status"
echo "   ./bin/db-connect.sh    - Connect to database"
echo "   ./bin/db-stop.sh       - Stop database"
echo ""
