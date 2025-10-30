#!/bin/bash
# ==============================================================================
# View Companies Script
# Displays company data from the database in a formatted way
# ==============================================================================

CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"
DB_USER="admin"

# Parse command line options
SHOW_HIERARCHY=false
COMPANY_CODE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--hierarchy)
            SHOW_HIERARCHY=true
            shift
            ;;
        -c|--code)
            COMPANY_CODE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --hierarchy    Show corporate hierarchy view"
            echo "  -c, --code CODE    Show specific company by code"
            echo "  -v, --verbose      Show detailed information"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      # List all companies"
            echo "  $0 -h                   # Show hierarchy view"
            echo "  $0 -c ABC-HOLD          # Show specific company"
            echo "  $0 -c ABC-HOLD -v       # Show detailed company info"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "HRMS SaaS - Company Data"
echo "=========================================="
echo ""

# Check if container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Database container is not running!"
    echo "   Start it with: ./bin/db-start.sh"
    exit 1
fi

if [ -n "$COMPANY_CODE" ]; then
    # Show specific company
    if [ "$VERBOSE" = true ]; then
        echo "🏢 Detailed Company Information"
        echo "────────────────────────────────────────"
        podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << EOF
SET row_security = OFF;

SELECT
    '🏢 Company:     ' || company_name ||
    E'\n📋 Code:        ' || company_code ||
    E'\n🏛️  Type:        ' || company_type ||
    E'\n📊 Level:       ' || hierarchy_level::text ||
    E'\n👥 Employees:   ' || (SELECT COUNT(*)::text FROM employee WHERE company_id = c.id) ||
    E'\n📧 Email:       ' || COALESCE(email, 'N/A') ||
    E'\n📞 Phone:       ' || COALESCE(phone, 'N/A') ||
    E'\n🌍 City:        ' || COALESCE(city, 'N/A') ||
    E'\n🗓️  Created:     ' || to_char(created_at, 'YYYY-MM-DD HH24:MI') ||
    E'\n💼 Subscription: ' || subscription_plan ||
    E'\n👤 Max Emp:     ' || max_employees::text ||
    E'\n🏢 Group:       ' || COALESCE(corporate_group_name, 'N/A')
FROM company c
WHERE company_code = '${COMPANY_CODE}';

-- Show parent if exists
SELECT
    E'\n👆 Parent:      ' || c.company_name || ' (' || c.company_code || ')'
FROM company c
WHERE id = (SELECT parent_company_id FROM company WHERE company_code = '${COMPANY_CODE}');

-- Show subsidiaries if exists
\echo ''
\echo '📁 Subsidiaries:'
SELECT
    '   • ' || company_name || ' (' || company_code || ') - ' ||
    (SELECT COUNT(*)::text FROM employee WHERE company_id = c.id) || ' employees'
FROM company c
WHERE parent_company_id = (SELECT id FROM company WHERE company_code = '${COMPANY_CODE}')
ORDER BY company_name;

-- Show employees summary
\echo ''
\echo '👥 Employees by Department:'
SET row_security = OFF;
SELECT
    '   • ' || COALESCE(department, 'No Department') || ': ' || COUNT(*)::text || ' employees'
FROM employee
WHERE company_id = (SELECT id FROM company WHERE company_code = '${COMPANY_CODE}')
GROUP BY department
ORDER BY COUNT(*) DESC;
EOF
    else
        # Simple view
        podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << EOF
SET row_security = OFF;
\pset border 2
SELECT
    company_code as "Code",
    company_name as "Company Name",
    company_type as "Type",
    COALESCE(city, '-') as "City",
    (SELECT COUNT(*)::text FROM employee WHERE company_id = c.id) as "Employees",
    subscription_plan as "Plan"
FROM company c
WHERE company_code = '${COMPANY_CODE}';
EOF
    fi

elif [ "$SHOW_HIERARCHY" = true ]; then
    # Show hierarchy view
    echo "🌳 Corporate Hierarchy View"
    echo "────────────────────────────────────────"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << 'EOF'
SET row_security = OFF;

-- Parent companies
\echo '🏛️  PARENT COMPANIES:'
SELECT
    '  ' || company_code || ' - ' || company_name ||
    ' (' || (SELECT COUNT(*)::text FROM company WHERE parent_company_id = c.id) || ' subsidiaries, ' ||
    (SELECT COUNT(*)::text FROM employee WHERE company_id = c.id) || ' employees)'
FROM company c
WHERE parent_company_id IS NULL AND company_type IN ('holding', 'independent')
ORDER BY company_name;

\echo ''

-- Subsidiaries grouped by parent
SELECT
    '  └── ' || c.company_code || ' - ' || c.company_name ||
    ' (' || (SELECT COUNT(*)::text FROM employee WHERE company_id = c.id) || ' employees)' ||
    E'\n      Parent: ' || p.company_code || ' - ' || p.company_name
FROM company c
JOIN company p ON c.parent_company_id = p.id
WHERE c.company_type = 'subsidiary'
ORDER BY p.company_name, c.company_name;
EOF

else
    # List all companies (default)
    echo "📋 All Companies"
    echo "────────────────────────────────────────"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << 'EOF'
SET row_security = OFF;
\pset border 2

SELECT
    company_code as "Code",
    company_name as "Company Name",
    company_type as "Type",
    CASE
        WHEN hierarchy_level = 1 THEN '🏛️  Parent'
        WHEN hierarchy_level = 2 THEN '  └─ Sub'
        ELSE '-'
    END as "Level",
    COALESCE(city, '-') as "City",
    (SELECT COUNT(*)::text FROM employee WHERE company_id = c.id) as "👥 Emp",
    subscription_plan as "Plan",
    CASE
        WHEN status = 'active' THEN '✅'
        WHEN status = 'inactive' THEN '⏸️'
        ELSE '❌'
    END as "Status"
FROM company c
ORDER BY
    CASE WHEN parent_company_id IS NULL THEN 0 ELSE 1 END,
    parent_company_id,
    company_name;
EOF
fi

echo ""
echo "────────────────────────────────────────"
echo "💡 Tips:"
echo "   ./bin/view-companies.sh -h              # Show hierarchy"
echo "   ./bin/view-companies.sh -c ABC-HOLD     # View specific company"
echo "   ./bin/view-companies.sh -c ABC-HOLD -v  # Detailed view"
echo ""
