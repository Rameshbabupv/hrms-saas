#!/bin/bash
# ==============================================================================
# Database Restart Script
# Restarts the PostgreSQL container for HRMS SaaS
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Restarting HRMS SaaS PostgreSQL Database"
echo "=========================================="
echo ""

# Stop the database
echo "Step 1: Stopping database..."
${SCRIPT_DIR}/db-stop.sh

echo ""
echo "⏳ Waiting 2 seconds..."
sleep 2
echo ""

# Start the database
echo "Step 2: Starting database..."
${SCRIPT_DIR}/db-start.sh

echo ""
echo "✅ Database restarted successfully!"
echo ""
