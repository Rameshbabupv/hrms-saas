#!/bin/bash
# ==============================================================================
# Create QA Database Container
# Creates a new PostgreSQL container for QA environment
# ==============================================================================

set -e

CONTAINER_NAME="nexus-postgres-qa"
DB_NAME="hrms_saas_qa"
DB_USER="admin"
DB_PASS="admin123"
APP_USER="hrms_app"
APP_PASS="hrms_app123"
PORT="5433"
VOLUME_NAME="pgdata-qa"

echo "=========================================="
echo "Creating PostgreSQL QA Container"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Container: ${CONTAINER_NAME}"
echo "  Database:  ${DB_NAME}"
echo "  Port:      ${PORT}"
echo "  Volume:    ${VOLUME_NAME}"
echo ""

# Check if container already exists
if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "⚠️  Container '${CONTAINER_NAME}' already exists!"
    read -p "Do you want to remove it and create a new one? (yes/no): " answer
    if [ "$answer" = "yes" ]; then
        echo "🗑️  Removing existing container..."
        podman stop ${CONTAINER_NAME} 2>/dev/null || true
        podman rm ${CONTAINER_NAME}
        podman volume rm ${VOLUME_NAME} 2>/dev/null || true
        echo "✅ Old container removed"
    else
        echo "❌ Aborted. Container already exists."
        exit 1
    fi
fi

echo "🚀 Creating PostgreSQL container..."
podman run -d \
  --name ${CONTAINER_NAME} \
  -e POSTGRES_USER=${DB_USER} \
  -e POSTGRES_PASSWORD=${DB_PASS} \
  -e POSTGRES_DB=${DB_NAME} \
  -p ${PORT}:5432 \
  -v ${VOLUME_NAME}:/var/lib/postgresql/data \
  docker.io/library/postgres:16

echo "⏳ Waiting for PostgreSQL to start..."
sleep 5

# Wait for PostgreSQL to be ready
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if podman exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
        echo "✅ PostgreSQL is ready!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Waiting... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Error: PostgreSQL failed to start in time"
    exit 1
fi

echo ""
echo "👤 Creating application user..."
podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "CREATE USER ${APP_USER} WITH PASSWORD '${APP_PASS}';" 2>/dev/null || echo "   User may already exist"

podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \
  "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${APP_USER};" 2>/dev/null

echo "✅ Application user created"

echo ""
echo "=========================================="
echo "QA Database Container Created Successfully!"
echo "=========================================="
echo ""
echo "Connection Details:"
echo "  Host:     localhost"
echo "  Port:     ${PORT}"
echo "  Database: ${DB_NAME}"
echo "  Admin:    ${DB_USER}/${DB_PASS}"
echo "  App User: ${APP_USER}/${APP_PASS}"
echo ""
echo "Next Steps:"
echo "  1. Apply schema:         ./bin/apply-schema-qa.sh"
echo "  2. Load reference data:  ./bin/load-reference-data-qa.sh"
echo "  3. Load test data:       ./bin/load-test-data-qa.sh"
echo "  4. Check status:         ./bin/db-status-qa.sh"
echo ""
echo "Quick Test:"
echo "  podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c '\\dt'"
echo ""
