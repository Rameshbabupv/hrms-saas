#!/bin/bash
# ==============================================================================
# Database Status Script
# Shows comprehensive status of the PostgreSQL database
# Supports both Podman and Docker
# ==============================================================================

# Configuration
CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"
DB_USER="admin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
echo "HRMS SaaS Database Status"
echo "=========================================="
echo -e "${BLUE}Container Runtime: ${CONTAINER_CMD}${NC}"
echo ""

# Check if container exists
if ! ${CONTAINER_CMD} ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Container Status: NOT FOUND${NC}"
    echo "   Container '${CONTAINER_NAME}' does not exist"
    echo ""
    echo "To create and start the database:"
    echo "   ./bin/db-start.sh"
    exit 1
fi

# Container status
echo "📦 Container Status:"
if ${CONTAINER_CMD} ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "   ${GREEN}✅ Running${NC}"
    CONTAINER_RUNNING=true
else
    echo -e "   ${RED}❌ Stopped${NC}"
    CONTAINER_RUNNING=false
fi

# Container details
echo ""
echo "📊 Container Details:"
${CONTAINER_CMD} ps -a --filter "name=${CONTAINER_NAME}" --format "   Name:    {{.Names}}\n   Status:  {{.Status}}\n   Ports:   {{.Ports}}\n   Image:   {{.Image}}"

if [ "$CONTAINER_RUNNING" = true ]; then
    echo ""
    echo "🔌 Database Connection:"
    if ${CONTAINER_CMD} exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ PostgreSQL is ready and accepting connections${NC}"
        DB_ACCESSIBLE=true
    else
        echo -e "   ${RED}⚠️  PostgreSQL is not responding${NC}"
        DB_ACCESSIBLE=false
    fi

    if [ "$DB_ACCESSIBLE" = true ]; then
        echo ""
        echo "💾 Database Information:"
        ${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "
            SELECT
                '   Database:        ' || current_database() ||
                E'\n   Version:         ' || split_part(version(), ',', 1) ||
                E'\n   Size:            ' || pg_size_pretty(pg_database_size(current_database())) ||
                E'\n   Active Conns:    ' || (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database())::text ||
                E'\n   Max Conns:       ' || current_setting('max_connections') ||
                E'\n   Tables:          ' || (SELECT count(*)::text FROM pg_tables WHERE schemaname = 'public') ||
                E'\n   Indexes:         ' || (SELECT count(*)::text FROM pg_indexes WHERE schemaname = 'public') ||
                E'\n   Extensions:      ' || COALESCE((SELECT string_agg(extname, ', ') FROM pg_extension WHERE extname NOT IN ('plpgsql')), 'None')
        " 2>/dev/null

        echo ""
        echo "📈 Data Summary:"
        ${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -A -F '|' -c "
            SET row_security = OFF;
            SELECT 'Companies', COUNT(*)::text FROM company
            UNION ALL SELECT 'Employees', COUNT(*)::text FROM employee
            UNION ALL SELECT 'Departments', COUNT(*)::text FROM department_master
            UNION ALL SELECT 'Designations', COUNT(*)::text FROM designation_master
            UNION ALL SELECT 'Audit Logs', COUNT(*)::text FROM audit_log
            UNION ALL SELECT 'Security Events', COUNT(*)::text FROM security_event_log
            UNION ALL SELECT 'Change History', COUNT(*)::text FROM data_change_history;
        " 2>/dev/null | awk -F'|' '{printf "   %-20s %s\n", $1 ":", $2}'

        echo ""
        echo "🔐 Row-Level Security Status:"
        ${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -A -F '|' -c "
            SELECT
                tablename,
                CASE WHEN rowsecurity THEN 'Enabled' ELSE 'Disabled' END
            FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename IN ('company', 'employee', 'department_master', 'designation_master')
            ORDER BY tablename;
        " 2>/dev/null | awk -F'|' '{
            status = $2;
            icon = (status == "Enabled") ? "✅" : "❌";
            color = (status == "Enabled") ? "\033[0;32m" : "\033[0;31m";
            printf "   %-25s %s%s %s\033[0m\n", $1, color, icon, status
        }'

        echo ""
        echo "⚡ Performance Metrics:"
        ${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "
            SELECT
                '   Cache Hit Ratio:     ' ||
                ROUND(100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2)::text || '%' ||
                E'\n   Transactions:        ' ||
                (SELECT sum(xact_commit + xact_rollback)::text FROM pg_stat_database WHERE datname = current_database()) ||
                E'\n   Temp Files:          ' ||
                (SELECT count(*)::text FROM pg_stat_database WHERE datname = current_database() AND temp_files > 0)
            FROM pg_stat_database
            WHERE datname = current_database();
        " 2>/dev/null

        echo ""
        echo "🔍 Recent Activity:"
        ${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "
            SET row_security = OFF;
            SELECT
                '   Last Audit Log:      ' ||
                COALESCE(to_char(MAX(audit_timestamp), 'YYYY-MM-DD HH24:MI:SS'), 'No records')
            FROM audit_log
            UNION ALL
            SELECT
                '   Active Queries:      ' ||
                COUNT(*)::text
            FROM pg_stat_activity
            WHERE datname = current_database()
            AND state = 'active'
            AND pid != pg_backend_pid();
        " 2>/dev/null

        echo ""
        echo "💽 Disk Usage by Table:"
        ${CONTAINER_CMD} exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "
            SELECT
                schemaname || '.' || tablename as table_name,
                pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
            FROM pg_tables
            WHERE schemaname = 'public'
            ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
            LIMIT 5;
        " 2>/dev/null | sed 's/^/   /'

        echo ""
        echo "🔗 Connection Details:"
        echo "   Host:     localhost"
        echo "   Port:     5432"
        echo "   Database: ${DB_NAME}"
        echo "   Admin:    admin / admin"
        echo "   App User: hrms_app / HrmsApp@2025"
    fi

else
    echo ""
    echo -e "${YELLOW}⚠️  Database is not running.${NC}"
    echo ""
    echo "To start the database:"
    echo "   ./bin/db-start.sh"
fi

echo ""
echo "=========================================="
echo ""

# Quick action hints
if [ "$CONTAINER_RUNNING" = true ] && [ "$DB_ACCESSIBLE" = true ]; then
    echo "Quick Commands:"
    echo "   ./bin/db-stop.sh          - Stop database"
    echo "   ./bin/db-restart.sh       - Restart database"
    echo "   ./bin/db-connect.sh       - Connect to database"
    echo "   ./bin/view-companies.sh   - View company data"
    echo "   ./bin/view-employees.sh   - View employee data"
    echo ""
fi
