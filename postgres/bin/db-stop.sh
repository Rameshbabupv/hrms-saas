#!/bin/bash
# ==============================================================================
# Database Stop Script
# Stops the PostgreSQL container for HRMS SaaS
# ==============================================================================

set -e

CONTAINER_NAME="nexus-postgres-dev"

echo "=========================================="
echo "Stopping HRMS SaaS PostgreSQL Database"
echo "=========================================="
echo ""

# Check if container exists
if ! podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '${CONTAINER_NAME}' not found!"
    exit 1
fi

# Check if running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "⚠️  Container '${CONTAINER_NAME}' is already stopped"
    exit 0
fi

echo "🛑 Stopping container '${CONTAINER_NAME}'..."
podman stop ${CONTAINER_NAME}

echo "✅ Database stopped successfully"
echo ""
