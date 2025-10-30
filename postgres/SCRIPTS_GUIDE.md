# Database Scripts - Quick Guide

## 📁 Available Scripts

All scripts are located in the `bin/` directory and are executable.

---

## 🛠️ Database Management

### 1. Start Database
```bash
./bin/db-start.sh
```
**What it does:**
- Starts the PostgreSQL container
- Waits for database to be ready
- Shows connection information
- Displays quick commands

**Use when:**
- Starting work for the day
- After system restart
- Database has been stopped

---

### 2. Stop Database
```bash
./bin/db-stop.sh
```
**What it does:**
- Gracefully stops PostgreSQL container
- Confirms successful stop

**Use when:**
- Ending work for the day
- Need to free up system resources
- Before system maintenance

---

### 3. Restart Database
```bash
./bin/db-restart.sh
```
**What it does:**
- Stops database
- Waits 2 seconds
- Starts database again

**Use when:**
- After configuration changes
- Database is not responding
- Need fresh connection pool

---

### 4. Check Status
```bash
./bin/db-status.sh
```
**What it does:**
- Shows container status (running/stopped)
- Shows database connection status
- Shows database size and version
- Shows data summary (counts)
- Shows RLS status

**Use when:**
- Want to check if database is running
- Need database statistics
- Troubleshooting issues

---

### 5. Connect to Database
```bash
./bin/db-connect.sh           # Connect as admin (default)
./bin/db-connect.sh hrms_app  # Connect as application user
```
**What it does:**
- Opens interactive psql session
- Shows helpful tips
- Allows running SQL queries

**Use when:**
- Need to run custom SQL queries
- Testing queries
- Database maintenance
- Troubleshooting

**Useful psql commands:**
```
\dt              List all tables
\d table_name    Describe a table
\l               List all databases
\q               Quit
\timing on       Show query execution time
```

---

## 📊 Data Viewing Scripts

### 6. View Companies
```bash
./bin/view-companies.sh [OPTIONS]
```

**Options:**
- No options: List all companies in table format
- `-h` or `--hierarchy`: Show corporate hierarchy tree
- `-c CODE` or `--code CODE`: Show specific company
- `-v` or `--verbose`: Show detailed information (use with -c)

**Examples:**
```bash
# List all companies
./bin/view-companies.sh

# Show hierarchy
./bin/view-companies.sh -h

# View specific company
./bin/view-companies.sh -c ABC-HOLD

# Detailed view
./bin/view-companies.sh -c ABC-HOLD -v
```

**What you'll see:**
- Company code and name
- Type (holding/subsidiary/independent)
- Hierarchy level
- City and location
- Employee count
- Subscription plan
- Status (active/inactive)

---

### 7. View Employees
```bash
./bin/view-employees.sh [OPTIONS]
```

**Options:**
- No options: List all employees
- `-c CODE` or `--company CODE`: Filter by company
- `-e CODE` or `--employee CODE`: Show specific employee
- `-d NAME` or `--department NAME`: Filter by department
- `-h` or `--hierarchy`: Show organizational hierarchy
- `-v` or `--verbose`: Show detailed information

**Examples:**
```bash
# List all employees
./bin/view-employees.sh

# Filter by company
./bin/view-employees.sh -c ABC-HOLD

# View specific employee
./bin/view-employees.sh -e ABCH001

# Filter by department
./bin/view-employees.sh -d "Human Resources"

# Show org hierarchy
./bin/view-employees.sh -h

# Org chart for specific company
./bin/view-employees.sh -c ABC-HOLD -h

# Combined filters
./bin/view-employees.sh -c ABC-HOLD -d "Human Resources"
```

**What you'll see:**
- Employee code and name
- Company
- Designation and department
- Employment type
- Joining date
- Active status
- For specific employee: education, experience, team members

---

## 🎯 Common Usage Scenarios

### Morning Routine
```bash
# Start database
./bin/db-start.sh

# Check everything is okay
./bin/db-status.sh

# Quick data check
./bin/view-companies.sh
./bin/view-employees.sh -c ABC-HOLD
```

### Check Corporate Structure
```bash
# View hierarchy
./bin/view-companies.sh --hierarchy

# View specific parent company with subsidiaries
./bin/view-companies.sh -c ABC-HOLD -v

# See org chart
./bin/view-employees.sh -c ABC-HOLD --hierarchy
```

### Employee Management
```bash
# List all employees in a company
./bin/view-employees.sh -c ABC-HOLD

# Check HR department
./bin/view-employees.sh -d "Human Resources"

# View employee details
./bin/view-employees.sh -e ABCH001

# See who reports to whom
./bin/view-employees.sh -h
```

### Database Maintenance
```bash
# Check status before maintenance
./bin/db-status.sh

# Stop for backup
./bin/db-stop.sh
# (perform backup)

# Restart after changes
./bin/db-restart.sh

# Verify everything is working
./bin/db-status.sh
```

### Troubleshooting
```bash
# Check if database is running
./bin/db-status.sh

# Restart if issues
./bin/db-restart.sh

# Connect for manual investigation
./bin/db-connect.sh

# In psql:
SET row_security = OFF;  -- Admin only
SELECT * FROM company;   -- Check data
\q                        -- Exit
```

---

## 💡 Tips and Tricks

### 1. Quick Status Check
```bash
# One-liner to check everything
./bin/db-status.sh | grep -E "✅|❌|Running|Stopped"
```

### 2. Export Company Data
```bash
# Connect and export
./bin/db-connect.sh << 'EOF'
\copy (SELECT * FROM company) TO '/tmp/companies.csv' CSV HEADER
\q
EOF
```

### 3. Count Records Quickly
```bash
./bin/db-connect.sh << 'EOF'
SET row_security = OFF;
SELECT
    'Companies' as table, COUNT(*) FROM company
UNION ALL
SELECT 'Employees', COUNT(*) FROM employee;
\q
EOF
```

### 4. View Recent Changes
```bash
./bin/db-connect.sh << 'EOF'
SELECT
    table_name,
    action,
    audit_timestamp,
    username
FROM audit_log
ORDER BY audit_timestamp DESC
LIMIT 10;
\q
EOF
```

### 5. Check Database Size
```bash
./bin/db-status.sh | grep "Size:"
```

---

## 🔧 Script Maintenance

### Make Scripts Executable (if needed)
```bash
chmod +x bin/*.sh
```

### Update Scripts
Scripts are located in:
```
/Users/rameshbabu/data/projects/systech/hrms-saas/postgres/bin/
```

Edit with your favorite editor:
```bash
vim bin/db-status.sh
# or
nano bin/view-companies.sh
```

---

## ⚠️ Important Notes

1. **RLS is Enabled:** The scripts automatically disable RLS for viewing data. In production, ensure proper tenant context is set.

2. **Admin Access:** All view scripts connect as `admin` user with full access. Be careful with modifications.

3. **Container Name:** Scripts use `nexus-postgres-dev` container name. If your container has a different name, update the `CONTAINER_NAME` variable in each script.

4. **Database Name:** Scripts use `hrms_saas` database. If different, update the `DB_NAME` variable.

5. **Heredoc Output:** Some terminal emulators may not display heredoc output correctly. If you see empty results, try running queries directly with `db-connect.sh`.

---

## 🐛 Troubleshooting Scripts

### Script Shows "Permission Denied"
```bash
chmod +x bin/*.sh
```

### Script Can't Find Container
Check container name:
```bash
podman ps -a
```
Update `CONTAINER_NAME` in scripts if different.

### No Output from View Scripts
Try direct query:
```bash
./bin/db-connect.sh
# Then run query manually
SET row_security = OFF;
SELECT * FROM company;
```

### Script Hangs
- Check if container is running: `podman ps`
- Check database is ready: `podman exec nexus-postgres-dev pg_isready`
- Check logs: `podman logs nexus-postgres-dev`

---

## 📞 Getting Help

### Script Help
All scripts support `--help`:
```bash
./bin/view-companies.sh --help
./bin/view-employees.sh --help
```

### Database Help
```bash
# Connect and get help
./bin/db-connect.sh
# Then in psql:
\?              # Help on psql commands
\h SELECT       # Help on SQL commands
```

---

## 📝 Script Locations

```
bin/
├── db-start.sh          # Start database
├── db-stop.sh           # Stop database
├── db-restart.sh        # Restart database
├── db-status.sh         # Check status
├── db-connect.sh        # Connect to DB
├── view-companies.sh    # View company data
└── view-employees.sh    # View employee data
```

---

**Last Updated:** 2025-10-30
**Database Version:** 2.0 with Corporate Hierarchy

---

## Quick Reference Card

```bash
# START/STOP
./bin/db-start.sh              # Start
./bin/db-stop.sh               # Stop
./bin/db-restart.sh            # Restart
./bin/db-status.sh             # Status
./bin/db-connect.sh            # Connect

# COMPANIES
./bin/view-companies.sh        # List all
./bin/view-companies.sh -h     # Hierarchy
./bin/view-companies.sh -c CODE # Specific
./bin/view-companies.sh -c CODE -v # Detailed

# EMPLOYEES
./bin/view-employees.sh        # List all
./bin/view-employees.sh -c CODE # By company
./bin/view-employees.sh -e CODE # Specific
./bin/view-employees.sh -d DEPT # By department
./bin/view-employees.sh -h     # Org chart
```

---

**End of Scripts Guide**
