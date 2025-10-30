#!/bin/bash
# ==============================================================================
# View Employees Script
# Displays employee data from the database in a formatted way
# ==============================================================================

CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"
DB_USER="admin"

# Parse command line options
COMPANY_CODE=""
EMPLOYEE_CODE=""
DEPARTMENT=""
SHOW_HIERARCHY=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--company)
            COMPANY_CODE="$2"
            shift 2
            ;;
        -e|--employee)
            EMPLOYEE_CODE="$2"
            shift 2
            ;;
        -d|--department)
            DEPARTMENT="$2"
            shift 2
            ;;
        -h|--hierarchy)
            SHOW_HIERARCHY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --company CODE      Filter by company code"
            echo "  -e, --employee CODE     Show specific employee"
            echo "  -d, --department NAME   Filter by department"
            echo "  -h, --hierarchy         Show reporting hierarchy"
            echo "  -v, --verbose           Show detailed information"
            echo "  --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                          # List all employees"
            echo "  $0 -c ABC-HOLD              # Employees in ABC-HOLD"
            echo "  $0 -e ABCH001               # Show specific employee"
            echo "  $0 -d 'Human Resources'     # Employees in HR dept"
            echo "  $0 -c ABC-HOLD -h           # Show org hierarchy"
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
echo "HRMS SaaS - Employee Data"
echo "=========================================="
echo ""

# Check if container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Database container is not running!"
    echo "   Start it with: ./bin/db-start.sh"
    exit 1
fi

if [ -n "$EMPLOYEE_CODE" ]; then
    # Show specific employee
    echo "👤 Employee Details"
    echo "────────────────────────────────────────"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << EOF
SET row_security = OFF;

SELECT
    '👤 Name:         ' || employee_name ||
    E'\n🆔 Code:         ' || employee_code ||
    E'\n📧 Email:        ' || COALESCE(email, 'N/A') ||
    E'\n📞 Mobile:       ' || COALESCE(mobile_no, 'N/A') ||
    E'\n🏢 Company:      ' || (SELECT company_name FROM company WHERE id = e.company_id) ||
    E'\n💼 Designation:  ' || COALESCE(designation, 'N/A') ||
    E'\n🏛️  Department:   ' || COALESCE(department, 'N/A') ||
    E'\n👔 Type:         ' || employment_type ||
    E'\n📅 Joining Date: ' || to_char(date_of_joining, 'DD-Mon-YYYY') ||
    E'\n💰 Monthly CTC:  ₹' || COALESCE(to_char(monthly_ctc, 'FM999,999,999.00'), 'N/A') ||
    E'\n👨‍💼 Manager:      ' || COALESCE((SELECT employee_name FROM employee WHERE id = e.reporting_manager_id), 'None') ||
    E'\n✅ Status:       ' || CASE WHEN is_active THEN 'Active' ELSE 'Inactive' END ||
    E'\n🗓️  Created:      ' || to_char(created_at, 'YYYY-MM-DD HH24:MI')
FROM employee e
WHERE employee_code = '${EMPLOYEE_CODE}';

-- Show education if exists
\echo ''
\echo '🎓 Education:'
SELECT
    '   • ' || degree || ' in ' || COALESCE(specialization, 'General') ||
    ' from ' || institution || ' (' || year_of_passing::text || ')'
FROM employee_education
WHERE employee_id = (SELECT id FROM employee WHERE employee_code = '${EMPLOYEE_CODE}')
ORDER BY year_of_passing DESC;

-- Show experience if exists
\echo ''
\echo '💼 Work Experience:'
SELECT
    '   • ' || company_name || ' - ' || designation ||
    ' (' || to_char(from_date, 'Mon YYYY') || ' to ' ||
    COALESCE(to_char(to_date, 'Mon YYYY'), 'Present') || ')'
FROM employee_experience
WHERE employee_id = (SELECT id FROM employee WHERE employee_code = '${EMPLOYEE_CODE}')
ORDER BY from_date DESC;

-- Show team members if manager
\echo ''
\echo '👥 Team Members (if manager):'
SELECT
    '   • ' || employee_code || ' - ' || employee_name || ' (' || COALESCE(designation, 'N/A') || ')'
FROM employee
WHERE reporting_manager_id = (SELECT id FROM employee WHERE employee_code = '${EMPLOYEE_CODE}')
ORDER BY employee_name;
EOF

elif [ "$SHOW_HIERARCHY" = true ]; then
    # Show organizational hierarchy
    echo "🌳 Organizational Hierarchy"
    if [ -n "$COMPANY_CODE" ]; then
        echo "Company: ${COMPANY_CODE}"
    fi
    echo "────────────────────────────────────────"

    COMPANY_FILTER=""
    if [ -n "$COMPANY_CODE" ]; then
        COMPANY_FILTER="AND c.company_code = '${COMPANY_CODE}'"
    fi

    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << EOF
SET row_security = OFF;

-- Top level employees (no manager)
\echo '🏛️  TOP LEVEL:'
SELECT
    '  ' || e.employee_code || ' - ' || e.employee_name ||
    ' (' || COALESCE(e.designation, 'N/A') || ') @ ' || c.company_name
FROM employee e
JOIN company c ON e.company_id = c.id
WHERE e.reporting_manager_id IS NULL
${COMPANY_FILTER}
ORDER BY c.company_name, e.employee_name;

\echo ''
\echo '└── REPORTING EMPLOYEES:'
-- Employees with managers
SELECT
    '    ' || e.employee_code || ' - ' || e.employee_name ||
    ' (' || COALESCE(e.designation, 'N/A') || ')' ||
    E'\n        ↳ Reports to: ' || m.employee_name ||
    ' @ ' || c.company_name
FROM employee e
JOIN employee m ON e.reporting_manager_id = m.id
JOIN company c ON e.company_id = c.id
WHERE e.reporting_manager_id IS NOT NULL
${COMPANY_FILTER}
ORDER BY m.employee_name, e.employee_name;
EOF

elif [ -n "$DEPARTMENT" ]; then
    # Filter by department
    echo "🏛️  Department: ${DEPARTMENT}"
    echo "────────────────────────────────────────"

    COMPANY_FILTER=""
    if [ -n "$COMPANY_CODE" ]; then
        echo "Company: ${COMPANY_CODE}"
        COMPANY_FILTER="AND c.company_code = '${COMPANY_CODE}'"
    fi

    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << EOF
SET row_security = OFF;
\pset border 2

SELECT
    e.employee_code as "Code",
    e.employee_name as "Name",
    c.company_code as "Company",
    COALESCE(e.designation, '-') as "Designation",
    to_char(e.date_of_joining, 'DD-Mon-YYYY') as "Joined",
    CASE WHEN e.is_active THEN '✅' ELSE '❌' END as "Active"
FROM employee e
JOIN company c ON e.company_id = c.id
WHERE e.department = '${DEPARTMENT}'
${COMPANY_FILTER}
ORDER BY c.company_name, e.employee_name;
EOF

elif [ -n "$COMPANY_CODE" ]; then
    # Filter by company
    echo "🏢 Company: ${COMPANY_CODE}"
    echo "────────────────────────────────────────"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << EOF
SET row_security = OFF;
\pset border 2

SELECT
    employee_code as "Code",
    employee_name as "Name",
    COALESCE(designation, '-') as "Designation",
    COALESCE(department, '-') as "Department",
    employment_type as "Type",
    to_char(date_of_joining, 'DD-Mon-YYYY') as "Joined",
    CASE WHEN is_active THEN '✅' ELSE '❌' END as "Active"
FROM employee e
WHERE company_id = (SELECT id FROM company WHERE company_code = '${COMPANY_CODE}')
ORDER BY employee_code;

\echo ''
\echo 'Summary:'
SELECT
    'Total: ' || COUNT(*)::text || ' | Active: ' ||
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END)::text || ' | Inactive: ' ||
    SUM(CASE WHEN NOT is_active THEN 1 ELSE 0 END)::text
FROM employee
WHERE company_id = (SELECT id FROM company WHERE company_code = '${COMPANY_CODE}');
EOF

else
    # List all employees
    echo "📋 All Employees"
    echo "────────────────────────────────────────"
    podman exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} << 'EOF'
SET row_security = OFF;
\pset border 2

SELECT
    e.employee_code as "Code",
    e.employee_name as "Name",
    c.company_code as "Company",
    COALESCE(e.designation, '-') as "Designation",
    COALESCE(e.department, '-') as "Department",
    to_char(e.date_of_joining, 'DD-Mon-YYYY') as "Joined",
    CASE WHEN e.is_active THEN '✅' ELSE '❌' END as "✓"
FROM employee e
JOIN company c ON e.company_id = c.id
ORDER BY c.company_code, e.employee_code;

\echo ''
\echo 'Summary by Company:'
SELECT
    c.company_code || ' - ' || c.company_name as "Company",
    COUNT(e.id)::text as "Total",
    SUM(CASE WHEN e.is_active THEN 1 ELSE 0 END)::text as "Active"
FROM company c
LEFT JOIN employee e ON c.id = e.company_id
GROUP BY c.company_code, c.company_name
ORDER BY c.company_code;
EOF
fi

echo ""
echo "────────────────────────────────────────"
echo "💡 Tips:"
echo "   ./bin/view-employees.sh -c ABC-HOLD              # Filter by company"
echo "   ./bin/view-employees.sh -e ABCH001               # View specific employee"
echo "   ./bin/view-employees.sh -d 'Human Resources'     # Filter by department"
echo "   ./bin/view-employees.sh -c ABC-HOLD -h           # Show org chart"
echo ""
