#!/bin/bash
# ==============================================================================
# Database Status Script
# Shows comprehensive status of the PostgreSQL database
# ==============================================================================

CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"
DB_USER="admin"

echo "=========================================="
echo "HRMS SaaS Database Status"
echo "=========================================="
echo ""

# Check if container exists
if ! podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container Status: NOT FOUND"
    echo "   Container '${CONTAINER_NAME}' does not exist"
    exit 1
fi

# Container status
echo "📦 Container Status:"
if podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "   ✅ Running"
    CONTAINER_RUNNING=true
else
    echo "   ❌ Stopped"
    CONTAINER_RUNNING=false
fi

# Container details
echo ""
echo "📊 Container Details:"
podman ps -a --filter "name=${CONTAINER_NAME}" --format "   Name:    {{.Names}}\n   Status:  {{.Status}}\n   Ports:   {{.Ports}}\n   Image:   {{.Image}}"

if [ "$CONTAINER_RUNNING" = true ]; then
    echo ""
    echo "🔌 Database Connection:"
    if podman exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} > /dev/null 2>&1; then
        echo "   ✅ PostgreSQL is ready and accepting connections"
    else
        echo "   ⚠️  PostgreSQL is not responding"
    fi

    echo ""
    echo "💾 Database Information:"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "
        SELECT
            '   Database:        ' || current_database() ||
            E'\n   Version:         ' || version() ||
            E'\n   Size:            ' || pg_size_pretty(pg_database_size(current_database())) ||
            E'\n   Active Conns:    ' || (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database())::text ||
            E'\n   Tables:          ' || (SELECT count(*)::text FROM pg_tables WHERE schemaname = 'public') ||
            E'\n   Extensions:      ' || (SELECT string_agg(extname, ', ') FROM pg_extension WHERE extname NOT IN ('plpgsql'))
    " 2>/dev/null

    echo ""
    echo "📈 Data Summary:"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "
        SET row_security = OFF;
        SELECT
            'Companies' as category,
            COUNT(*)::text as count
        FROM company
        UNION ALL
        SELECT 'Employees', COUNT(*)::text FROM employee
        UNION ALL
        SELECT 'Departments', COUNT(*)::text FROM department_master
        UNION ALL
        SELECT 'Designations', COUNT(*)::text FROM designation_master
        UNION ALL
        SELECT 'Audit Logs', COUNT(*)::text FROM audit_log
        UNION ALL
        SELECT 'Change History', COUNT(*)::text FROM data_change_history;
    " 2>/dev/null | sed 's/^/   /'

    echo ""
    echo "🔐 RLS Status:"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "
        SELECT
            tablename as table,
            CASE WHEN rowsecurity THEN '✅ Enabled' ELSE '❌ Disabled' END as rls_status
        FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename IN ('company', 'employee', 'department_master', 'designation_master')
        ORDER BY tablename;
    " 2>/dev/null | sed 's/^/   /'

else
    echo ""
    echo "⚠️  Database is not running. Start it with:"
    echo "   ./bin/db-start.sh"
fi

echo ""
echo "=========================================="
echo ""
