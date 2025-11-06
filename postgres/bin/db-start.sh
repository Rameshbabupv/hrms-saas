#!/bin/bash
# ==============================================================================
# Database Start Script
# Starts the PostgreSQL container for HRMS SaaS
# Supports both Podman and Docker
# ==============================================================================

set -e

# Configuration
CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"
DB_USER="admin"
POSTGRES_VERSION="16"
POSTGRES_PORT="5432"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect container runtime (Podman or Docker)
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo -e "${RED}❌ Error: Neither Podman nor Docker found!${NC}"
    echo "   Please install Podman or Docker first."
    exit 1
fi

echo "=========================================="
echo "Starting HRMS SaaS PostgreSQL Database"
echo "=========================================="
echo -e "${BLUE}Container Runtime: ${CONTAINER_CMD}${NC}"
echo ""

# Check if container exists
if ! ${CONTAINER_CMD} ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Error: Container '${CONTAINER_NAME}' not found!${NC}"
    echo ""
    echo "Would you like to create it now? [y/N]"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo ""
        echo "🚀 Creating PostgreSQL container..."
        ${CONTAINER_CMD} run -d \
            --name ${CONTAINER_NAME} \
            -e POSTGRES_USER=${DB_USER} \
            -e POSTGRES_PASSWORD=admin \
            -e POSTGRES_DB=${DB_NAME} \
            -p ${POSTGRES_PORT}:5432 \
            -v postgres-data:/var/lib/postgresql/data \
            postgres:${POSTGRES_VERSION}

        echo -e "${GREEN}✅ Container created successfully${NC}"
        sleep 5
    else
        echo "Exiting. Please create the container manually."
        exit 1
    fi
fi

# Check if already running
if ${CONTAINER_CMD} ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}✅ Container '${CONTAINER_NAME}' is already running${NC}"
else
    echo "🚀 Starting container '${CONTAINER_NAME}'..."
    ${CONTAINER_CMD} start ${CONTAINER_NAME}

    # Wait for PostgreSQL to be ready with retry logic
    echo "⏳ Waiting for PostgreSQL to be ready..."
    MAX_RETRIES=10
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        sleep 2
        if ${CONTAINER_CMD} exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
            echo -e "${GREEN}✅ PostgreSQL is ready and accepting connections${NC}"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo -n "."
        fi
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo ""
        echo -e "${RED}❌ Error: PostgreSQL is not responding after ${MAX_RETRIES} attempts${NC}"
        echo "   Check logs with: ${CONTAINER_CMD} logs ${CONTAINER_NAME}"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "Database Information"
echo "=========================================="

# Get database size and info
DB_SIZE=$(${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));" 2>/dev/null | xargs || echo "N/A")
PG_VERSION=$(${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT version();" 2>/dev/null | head -1 | xargs || echo "N/A")

echo "Database: ${DB_NAME}"
echo "Version:  ${PG_VERSION}"
echo "Size:     ${DB_SIZE}"
echo ""
echo "Container Status:"
${CONTAINER_CMD} ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check for active connections
ACTIVE_CONNS=$(${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '${DB_NAME}';" 2>/dev/null | xargs || echo "0")
echo "Active Connections: ${ACTIVE_CONNS}"

echo ""
echo -e "${GREEN}✅ Database is ready!${NC}"
echo ""
echo "Connection Details:"
echo "   Host:     localhost"
echo "   Port:     ${POSTGRES_PORT}"
echo "   Database: ${DB_NAME}"
echo "   User:     hrms_app (password: HrmsApp@2025)"
echo ""
echo "Quick Commands:"
echo "   ./bin/db-status.sh        - Check detailed status"
echo "   ./bin/db-connect.sh       - Connect to database"
echo "   ./bin/db-stop.sh          - Stop database"
echo "   ./bin/db-restart.sh       - Restart database"
echo "   ./bin/view-companies.sh   - View company data"
echo "   ./bin/view-employees.sh   - View employee data"
echo ""
