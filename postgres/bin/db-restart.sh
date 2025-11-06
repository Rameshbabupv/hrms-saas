#!/bin/bash
# ==============================================================================
# Database Restart Script
# Restarts the PostgreSQL container for HRMS SaaS
# Supports both Podman and Docker
# ==============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Restarting HRMS SaaS PostgreSQL Database"
echo "=========================================="
echo ""

# Check if scripts exist
if [ ! -f "${SCRIPT_DIR}/db-stop.sh" ]; then
    echo -e "${RED}❌ Error: db-stop.sh not found!${NC}"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/db-start.sh" ]; then
    echo -e "${RED}❌ Error: db-start.sh not found!${NC}"
    exit 1
fi

# Step 1: Stop the database
echo -e "${BLUE}Step 1/2: Stopping database...${NC}"
echo "=========================================="
if "${SCRIPT_DIR}/db-stop.sh"; then
    echo -e "${GREEN}✅ Stop completed${NC}"
else
    echo -e "${RED}❌ Stop failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⏳ Waiting 3 seconds before restart...${NC}"
sleep 3
echo ""

# Step 2: Start the database
echo -e "${BLUE}Step 2/2: Starting database...${NC}"
echo "=========================================="
if "${SCRIPT_DIR}/db-start.sh"; then
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ Database restarted successfully!${NC}"
    echo "=========================================="
    echo ""
else
    echo -e "${RED}❌ Start failed${NC}"
    exit 1
fi
