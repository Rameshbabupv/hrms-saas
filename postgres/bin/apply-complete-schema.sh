#!/bin/bash
# ==============================================================================
# Apply Complete Schema Script
# Applies the comprehensive HRMS SaaS schema to the database
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"
DB_USER="admin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="${SCRIPT_DIR}/../postgres-docs/schemas"

# Detect container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo -e "${RED}❌ Error: Neither Podman nor Docker found!${NC}"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║              HRMS SaaS - Complete Schema Application                         ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${BLUE}Container Runtime: ${CONTAINER_CMD}${NC}"
echo ""

# Check if container is running
if ! ${CONTAINER_CMD} ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Error: Container '${CONTAINER_NAME}' is not running!${NC}"
    echo ""
    echo "Start the database first:"
    echo "   ./db-start.sh"
    exit 1
fi

# Check if database is accessible
if ! ${CONTAINER_CMD} exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Database is not accessible!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Database is accessible${NC}"
echo ""

# Show current schema status
echo "📊 Current Database Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CURRENT_TABLES=$(${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';" 2>/dev/null | xargs)
echo "   Current Tables: ${CURRENT_TABLES}"

CURRENT_COMPANIES=$(${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT count(*) FROM company_master;" 2>/dev/null | xargs)
echo "   Current Companies: ${CURRENT_COMPANIES}"
echo ""

# Check schema files
echo "📁 Checking Schema Files:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCHEMA_V2="${SCHEMA_DIR}/saas_mvp_schema_v2_with_hierarchy.sql"
AUDIT_SCHEMA="${SCHEMA_DIR}/saas_mvp_audit_schema.sql"
SAMPLE_DATA="${SCRIPT_DIR}/../scripts/02_sample_data.sql"

if [ ! -f "$SCHEMA_V2" ]; then
    echo -e "${RED}❌ Schema file not found: $SCHEMA_V2${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Core schema found:${NC} saas_mvp_schema_v2_with_hierarchy.sql"

if [ ! -f "$AUDIT_SCHEMA" ]; then
    echo -e "${RED}❌ Audit schema file not found: $AUDIT_SCHEMA${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Audit schema found:${NC} saas_mvp_audit_schema.sql"

if [ -f "$SAMPLE_DATA" ]; then
    echo -e "${GREEN}✅ Sample data found:${NC} 02_sample_data.sql"
    HAS_SAMPLE_DATA=true
else
    echo -e "${YELLOW}⚠️  Sample data not found${NC} (optional)"
    HAS_SAMPLE_DATA=false
fi
echo ""

# Warning about existing data
echo -e "${YELLOW}⚠️  WARNING:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "This will apply the complete schema to your database."
echo ""
echo "The schema includes:"
echo "   • 6 Core Business Tables (company, employee, departments, etc.)"
echo "   • 6 Audit & Compliance Tables"
echo "   • Row-Level Security (RLS) policies"
echo "   • Indexes and constraints"
echo ""
echo "Note: The 'company_master' table from Spring Boot will remain."
echo "      The new 'company' table is for the legacy schema."
echo ""
echo "Current data (${CURRENT_COMPANIES} companies) will be preserved."
echo ""
echo -e "${CYAN}Do you want to continue? [y/N]${NC}"
read -r response

if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo "🚀 Starting Schema Application..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create backup first
BACKUP_FILE="/tmp/hrms_saas_backup_$(date +%Y%m%d_%H%M%S).sql"
echo -e "${BLUE}Step 1/4: Creating backup...${NC}"
if ${CONTAINER_CMD} exec ${CONTAINER_NAME} pg_dump -U ${DB_USER} ${DB_NAME} > "$BACKUP_FILE" 2>/dev/null; then
    BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
    echo -e "${GREEN}✅ Backup created: $BACKUP_FILE ($BACKUP_SIZE)${NC}"
else
    echo -e "${RED}❌ Backup failed!${NC}"
    exit 1
fi
echo ""

# Apply core schema
echo -e "${BLUE}Step 2/4: Applying core schema (v2 with hierarchy)...${NC}"
if cat "$SCHEMA_V2" | ${CONTAINER_CMD} exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Core schema applied successfully${NC}"
else
    echo -e "${RED}❌ Core schema application failed!${NC}"
    echo ""
    echo "Attempting to show error details..."
    cat "$SCHEMA_V2" | ${CONTAINER_CMD} exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} 2>&1 | tail -20
    echo ""
    echo "You can restore from backup:"
    echo "   cat $BACKUP_FILE | ${CONTAINER_CMD} exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME}"
    exit 1
fi
echo ""

# Apply audit schema
echo -e "${BLUE}Step 3/4: Applying audit schema...${NC}"
if cat "$AUDIT_SCHEMA" | ${CONTAINER_CMD} exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Audit schema applied successfully${NC}"
else
    echo -e "${RED}❌ Audit schema application failed!${NC}"
    echo ""
    echo "Core schema is applied, but audit tables may be missing."
    echo "You can try applying audit schema manually:"
    echo "   cat $AUDIT_SCHEMA | ${CONTAINER_CMD} exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME}"
fi
echo ""

# Apply sample data (optional)
if [ "$HAS_SAMPLE_DATA" = true ]; then
    echo -e "${BLUE}Step 4/4: Loading sample data...${NC}"
    echo -e "${CYAN}Do you want to load sample data? [y/N]${NC}"
    read -r load_sample

    if [[ "$load_sample" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        if cat "$SAMPLE_DATA" | ${CONTAINER_CMD} exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Sample data loaded successfully${NC}"
        else
            echo -e "${YELLOW}⚠️  Sample data loading failed (non-critical)${NC}"
        fi
    else
        echo "   Skipped sample data loading"
    fi
else
    echo -e "${BLUE}Step 4/4: Sample data not available (skipped)${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show final status
echo "📊 Final Database Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FINAL_TABLES=$(${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';" 2>/dev/null | xargs)
echo "   Total Tables: ${FINAL_TABLES}"

# List all tables
echo ""
echo "   Tables Created:"
${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "
    SELECT
        tablename,
        CASE
            WHEN rowsecurity THEN '✅ RLS Enabled'
            ELSE '   No RLS'
        END as security
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename NOT LIKE 'flyway%'
    ORDER BY tablename;
" 2>/dev/null | sed 's/^/   /'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✅ Schema application completed successfully!${NC}"
echo ""
echo "📝 Next Steps:"
echo "   1. View database status:"
echo "      ${BLUE}./db-status.sh${NC}"
echo ""
echo "   2. View companies:"
echo "      ${BLUE}./view-companies.sh${NC}"
echo ""
echo "   3. View employees (if sample data loaded):"
echo "      ${BLUE}./view-employees.sh${NC}"
echo ""
echo "   4. Backup location:"
echo "      ${BLUE}${BACKUP_FILE}${NC}"
echo ""
