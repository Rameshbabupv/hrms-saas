# PostgreSQL Database - Quick Start Guide

## 🚀 First Time Setup (One-Time)

```bash
# 1. Start Podman machine (macOS only)
podman machine start

# 2. Verify runtime is ready
./check-runtime.sh

# 3. Start database (will create container if needed)
./db-start.sh
# Answer 'y' if prompted to create container

# 4. Check status
./db-status.sh
```

---

## ⚡ Daily Usage

```bash
# Start database
./db-start.sh

# Check status
./db-status.sh

# Stop database
./db-stop.sh

# Restart database
./db-restart.sh
```

---

## 📊 Quick Commands

```bash
# Check if Podman/Docker is ready
./check-runtime.sh

# View comprehensive database status
./db-status.sh

# View companies
./view-companies.sh

# View employees
./view-employees.sh

# Connect to database (interactive psql)
./db-connect.sh
```

---

## 🔗 Connection Details

**For Scripts:**
- All scripts connect automatically

**For Applications:**
```properties
Host:     localhost
Port:     5432
Database: hrms_saas
Admin:    admin / admin
App User: hrms_app / HrmsApp@2025
```

**JDBC URL:**
```
jdbc:postgresql://localhost:5432/hrms_saas
```

---

## 🐳 Container Management

```bash
# View all containers
podman ps -a

# View logs
podman logs nexus-postgres-dev

# Shell access
podman exec -it nexus-postgres-dev bash

# Direct psql access
podman exec -it nexus-postgres-dev psql -U admin -d hrms_saas
```

---

## 🚨 Troubleshooting

### Podman Machine Not Running
```bash
podman machine start
./check-runtime.sh
```

### Container Not Found
```bash
./db-start.sh
# Answer 'y' to create
```

### Database Not Responding
```bash
./db-restart.sh
```

### Port Already in Use
```bash
lsof -i :5432  # Check what's using port
```

---

## 📚 Documentation

- **README.md** - Complete guide (530+ lines)
- **SCRIPTS_SUMMARY.md** - What's been created
- **QUICK_START.md** - This file
- **../README.md** - Database overview
- **../postgres-docs/** - Complete documentation

---

## ✅ Status Check

Run this to verify everything is ready:
```bash
./check-runtime.sh && ./db-status.sh
```

Expected output:
- ✅ Podman/Docker is ready
- ✅ Container is running
- ✅ Database is accessible
- ✅ Data loaded (4 companies, 8 employees)

---

**Last Updated**: November 5, 2025
