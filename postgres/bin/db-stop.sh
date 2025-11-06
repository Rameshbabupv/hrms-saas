#!/bin/bash
# ==============================================================================
# Database Stop Script
# Stops the PostgreSQL container for HRMS SaaS
# Supports both Podman and Docker
# ==============================================================================

set -e

# Configuration
CONTAINER_NAME="nexus-postgres-dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect container runtime (Podman or Docker)
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo -e "${RED}❌ Error: Neither Podman nor Docker found!${NC}"
    exit 1
fi

echo "=========================================="
echo "Stopping HRMS SaaS PostgreSQL Database"
echo "=========================================="
echo ""

# Check if container exists
if ! ${CONTAINER_CMD} ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Error: Container '${CONTAINER_NAME}' not found!${NC}"
    exit 1
fi

# Check if running
if ! ${CONTAINER_CMD} ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}⚠️  Container '${CONTAINER_NAME}' is already stopped${NC}"
    exit 0
fi

# Check for active connections
echo "🔍 Checking for active database connections..."
ACTIVE_CONNS=$(${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U admin -d hrms_saas -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'hrms_saas' AND pid != pg_backend_pid();" 2>/dev/null | xargs || echo "0")

if [ "$ACTIVE_CONNS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: There are ${ACTIVE_CONNS} active connection(s) to the database${NC}"
    echo "   These connections will be terminated when the container stops."
    echo ""
    echo "Do you want to continue? [y/N]"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

echo "🛑 Stopping container '${CONTAINER_NAME}'..."

# Graceful shutdown with timeout
STOP_TIMEOUT=10
if ${CONTAINER_CMD} stop -t ${STOP_TIMEOUT} ${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Database stopped successfully${NC}"
else
    echo -e "${RED}❌ Error: Failed to stop container${NC}"
    exit 1
fi

echo ""
echo "Container Status:"
${CONTAINER_CMD} ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
echo ""
echo "To start the database again, run:"
echo "   ./bin/db-start.sh"
echo ""
