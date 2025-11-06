# PostgreSQL Database Management Scripts

Comprehensive scripts for managing the HRMS SaaS PostgreSQL database container.

## 🚀 Quick Start

```bash
# Start the database
./db-start.sh

# Check status
./db-status.sh

# Stop the database
./db-stop.sh

# Restart the database
./db-restart.sh
```

---

## 📋 Scripts Overview

### 1. db-start.sh
**Purpose**: Starts the PostgreSQL container for HRMS SaaS.

**Features**:
- ✅ Auto-detects Podman or Docker
- ✅ Checks if container exists
- ✅ Offers to create container if not found
- ✅ Waits for PostgreSQL to be ready (with retry logic)
- ✅ Shows database information and connection details
- ✅ Color-coded output for better readability

**Usage**:
```bash
./db-start.sh
```

**Output Example**:
```
==========================================
Starting HRMS SaaS PostgreSQL Database
==========================================
Container Runtime: podman

✅ Container 'nexus-postgres-dev' is already running

==========================================
Database Information
==========================================
Database: hrms_saas
Version:  PostgreSQL 16.x
Size:     50 MB

Container Status:
NAMES                  STATUS         PORTS
nexus-postgres-dev     Up 5 minutes   0.0.0.0:5432->5432/tcp

Active Connections: 2

✅ Database is ready!

Connection Details:
   Host:     localhost
   Port:     5432
   Database: hrms_saas
   User:     hrms_app (password: HrmsApp@2025)
```

---

### 2. db-stop.sh
**Purpose**: Stops the PostgreSQL container gracefully.

**Features**:
- ✅ Auto-detects Podman or Docker
- ✅ Checks for active database connections
- ✅ Prompts for confirmation if connections exist
- ✅ Graceful shutdown with 10-second timeout
- ✅ Shows final container status

**Usage**:
```bash
./db-stop.sh
```

**Output Example**:
```
==========================================
Stopping HRMS SaaS PostgreSQL Database
==========================================

🔍 Checking for active database connections...
⚠️  Warning: There are 3 active connection(s) to the database
   These connections will be terminated when the container stops.

Do you want to continue? [y/N]
y
🛑 Stopping container 'nexus-postgres-dev'...
✅ Database stopped successfully

Container Status:
NAMES                  STATUS
nexus-postgres-dev     Exited (0) 2 seconds ago

To start the database again, run:
   ./bin/db-start.sh
```

---

### 3. db-restart.sh
**Purpose**: Restarts the PostgreSQL container.

**Features**:
- ✅ Executes stop and start in sequence
- ✅ Validates script existence
- ✅ Shows progress for each step
- ✅ 3-second wait between stop and start
- ✅ Error handling for both operations

**Usage**:
```bash
./db-restart.sh
```

**Output Example**:
```
==========================================
Restarting HRMS SaaS PostgreSQL Database
==========================================

Step 1/2: Stopping database...
==========================================
🛑 Stopping container 'nexus-postgres-dev'...
✅ Database stopped successfully
✅ Stop completed

⏳ Waiting 3 seconds before restart...

Step 2/2: Starting database...
==========================================
🚀 Starting container 'nexus-postgres-dev'...
⏳ Waiting for PostgreSQL to be ready...
✅ PostgreSQL is ready and accepting connections

==========================================
✅ Database restarted successfully!
==========================================
```

---

### 4. db-status.sh
**Purpose**: Shows comprehensive database status and statistics.

**Features**:
- ✅ Container runtime detection
- ✅ Container and database status
- ✅ Database size and version
- ✅ Active connections count
- ✅ Data summary (companies, employees, etc.)
- ✅ Row-Level Security (RLS) status
- ✅ Performance metrics (cache hit ratio)
- ✅ Recent activity (last audit log, active queries)
- ✅ Top 5 tables by disk usage
- ✅ Connection details

**Usage**:
```bash
./db-status.sh
```

**Output Example**:
```
==========================================
HRMS SaaS Database Status
==========================================
Container Runtime: podman

📦 Container Status:
   ✅ Running

📊 Container Details:
   Name:    nexus-postgres-dev
   Status:  Up 2 hours
   Ports:   0.0.0.0:5432->5432/tcp
   Image:   postgres:16

🔌 Database Connection:
   ✅ PostgreSQL is ready and accepting connections

💾 Database Information:
   Database:        hrms_saas
   Version:         PostgreSQL 16.4
   Size:            50 MB
   Active Conns:    2
   Max Conns:       100
   Tables:          12
   Indexes:         40
   Extensions:      uuid-ossp

📈 Data Summary:
   Companies:           4
   Employees:           8
   Departments:         5
   Designations:        6
   Audit Logs:          0
   Security Events:     0
   Change History:      0

🔐 Row-Level Security Status:
   company                   ✅ Enabled
   department_master         ✅ Enabled
   designation_master        ✅ Enabled
   employee                  ✅ Enabled

⚡ Performance Metrics:
   Cache Hit Ratio:     99.85%
   Transactions:        1523
   Temp Files:          0

🔍 Recent Activity:
   Last Audit Log:      No records
   Active Queries:      0

💽 Disk Usage by Table:
    table_name          | size
   ---------------------+--------
    public.employee     | 128 kB
    public.company      | 64 kB
    public.audit_log    | 32 kB
    ...

🔗 Connection Details:
   Host:     localhost
   Port:     5432
   Database: hrms_saas
   Admin:    admin / admin
   App User: hrms_app / HrmsApp@2025

==========================================

Quick Commands:
   ./bin/db-stop.sh          - Stop database
   ./bin/db-restart.sh       - Restart database
   ./bin/db-connect.sh       - Connect to database
   ./bin/view-companies.sh   - View company data
   ./bin/view-employees.sh   - View employee data
```

---

## 🔧 Configuration

All scripts use these default settings:

```bash
CONTAINER_NAME="nexus-postgres-dev"
DB_NAME="hrms_saas"
DB_USER="admin"
POSTGRES_VERSION="16"
POSTGRES_PORT="5432"
```

To change these values, edit the variables at the top of each script.

---

## 🐳 Container Runtime Support

The scripts automatically detect and support both:
- **Podman** (preferred)
- **Docker** (fallback)

Detection logic:
```bash
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
fi
```

---

## 🎨 Color Coding

Scripts use color-coded output for better readability:

- 🔴 **Red** (`\033[0;31m`): Errors and failures
- 🟢 **Green** (`\033[0;32m`): Success messages
- 🟡 **Yellow** (`\033[1;33m`): Warnings
- 🔵 **Blue** (`\033[0;34m`): Information
- 🔵 **Cyan** (`\033[0;36m`): Highlights

---

## ⚠️ Prerequisites

### For Podman:
```bash
# macOS
brew install podman

# Initialize and start Podman machine
podman machine init
podman machine start

# Verify
podman ps
```

### For Docker:
```bash
# macOS
brew install --cask docker

# Or download Docker Desktop from:
# https://www.docker.com/products/docker-desktop

# Verify
docker ps
```

---

## 🚨 Troubleshooting

### Issue: "Neither Podman nor Docker found!"

**Solution**:
```bash
# Install Podman (recommended)
brew install podman
podman machine init
podman machine start
```

---

### Issue: "Container 'nexus-postgres-dev' not found"

**Solution 1**: Let the script create it automatically
```bash
./db-start.sh
# Answer 'y' when prompted
```

**Solution 2**: Create manually
```bash
podman run -d \
    --name nexus-postgres-dev \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=admin \
    -e POSTGRES_DB=hrms_saas \
    -p 5432:5432 \
    -v postgres-data:/var/lib/postgresql/data \
    postgres:16
```

---

### Issue: "PostgreSQL is not responding"

**Check logs**:
```bash
podman logs nexus-postgres-dev
# or
docker logs nexus-postgres-dev
```

**Common causes**:
1. Container just started (wait a few seconds)
2. Port 5432 already in use
3. Insufficient resources

**Fix**:
```bash
# Check if port is in use
lsof -i :5432

# Restart container
./db-restart.sh
```

---

### Issue: "Cannot connect to Podman socket"

**Solution**:
```bash
# Start Podman machine
podman machine start

# Verify
podman machine list
```

---

### Issue: Active connections prevent shutdown

**Force stop** (only if necessary):
```bash
# Terminate active connections first
podman exec nexus-postgres-dev psql -U admin -d hrms_saas -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'hrms_saas' AND pid <> pg_backend_pid();"

# Then stop
./db-stop.sh
```

---

## 📝 Script Maintenance

### Making Scripts Executable
```bash
chmod +x bin/*.sh
```

### Viewing Script Logs
All scripts output to stdout/stderr. To save output:
```bash
./db-start.sh 2>&1 | tee db-start.log
```

### Testing Scripts
```bash
# Test all scripts
./db-start.sh
./db-status.sh
./db-stop.sh
./db-restart.sh
./db-status.sh
```

---

## 🔒 Security Notes

### Default Credentials (Development Only)
- **Admin**: `admin` / `admin`
- **App User**: `hrms_app` / `HrmsApp@2025`

⚠️ **WARNING**: Change these credentials for production!

### Production Recommendations
1. Use strong, randomly generated passwords
2. Enable SSL/TLS connections
3. Restrict network access (firewall rules)
4. Use secrets management (Vault, AWS Secrets Manager)
5. Enable PostgreSQL authentication logging
6. Regular security audits

---

## 📊 Performance Tips

### Monitor Database Performance
```bash
# Run status frequently
watch -n 5 ./db-status.sh

# Check slow queries
podman exec nexus-postgres-dev psql -U admin -d hrms_saas -c \
  "SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

### Optimize Database
```bash
# Connect and run maintenance
./db-connect.sh

# Inside psql:
VACUUM ANALYZE;
REINDEX DATABASE hrms_saas;
```

---

## 🔗 Related Scripts

Other database management scripts in this directory:

- `db-connect.sh` - Interactive psql connection
- `view-companies.sh` - View company data and hierarchy
- `view-employees.sh` - View employee data and org chart
- `create-qa-container.sh` - Create QA environment container
- `apply-schema-qa.sh` - Apply schema to QA environment
- `load-reference-data-qa.sh` - Load reference data to QA

---

## 📚 Additional Resources

### Documentation
- Main README: `../README.md`
- Database Schema: `../postgres-docs/DBA_NOTES.md`
- Setup Guide: `../postgres-docs/DATABASE_SETUP_STATUS.md`

### PostgreSQL Documentation
- Official Docs: https://www.postgresql.org/docs/16/
- Container Security: https://www.postgresql.org/docs/16/ssl-tcp.html

### Container Documentation
- Podman: https://docs.podman.io/
- Docker: https://docs.docker.com/

---

## ✅ Testing Checklist

Before deploying to production:

- [ ] Scripts run successfully on macOS
- [ ] Scripts run successfully on Linux
- [ ] Container auto-creation works
- [ ] Podman support verified
- [ ] Docker support verified
- [ ] Status script shows all metrics
- [ ] Stop script handles active connections
- [ ] Restart script completes successfully
- [ ] Error messages are clear
- [ ] Color output works in terminal
- [ ] Production credentials configured

---

## 🎯 Quick Reference

```bash
# Essential Commands
./db-start.sh              # Start database
./db-status.sh             # Check status
./db-stop.sh               # Stop database
./db-restart.sh            # Restart database

# Data Viewing
./view-companies.sh        # View companies
./view-employees.sh        # View employees

# Database Access
./db-connect.sh            # Interactive psql

# Container Management
podman ps                  # List running containers
podman logs nexus-postgres-dev  # View logs
podman exec -it nexus-postgres-dev bash  # Shell access
```

---

**Last Updated**: November 5, 2025
**Version**: 2.0
**Maintained By**: Development Team
