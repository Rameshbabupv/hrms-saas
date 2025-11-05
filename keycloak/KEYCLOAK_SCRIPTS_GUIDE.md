# Keycloak Management Scripts Guide

## Overview

This guide documents the Keycloak management scripts that handle PostgreSQL dependency management for proper service startup, shutdown, and restart operations.

**Last Updated:** November 5, 2025
**Location:** `/keycloak/scripts/`

---

## Quick Reference

```bash
# Start services (PostgreSQL + Keycloak)
./scripts/start-keycloak.sh

# Check status
./scripts/status-keycloak.sh

# Restart Keycloak only
./scripts/restart-keycloak.sh

# Restart both services
./scripts/restart-keycloak.sh --with-db

# Stop Keycloak only
./scripts/stop-keycloak.sh

# Stop both services
./scripts/stop-keycloak.sh --with-db
```

---

## Prerequisites

### Required Services
- **Podman machine** must be running
- **PostgreSQL container** (`nexus-postgres-dev`) - Keycloak's database backend
- **Keycloak container** (`nexus-keycloak-dev`)

### Dependencies
Keycloak **requires** PostgreSQL to be running before it can start. The scripts handle this dependency automatically.

---

## Script Details

### 1. start-keycloak.sh

**Purpose:** Start both PostgreSQL and Keycloak services with proper dependency handling.

**Usage:**
```bash
./start-keycloak.sh
```

**What it does:**
1. Checks if Podman machine is running (starts it if needed)
2. Checks PostgreSQL container status
3. Starts PostgreSQL if not running
4. Waits for PostgreSQL to be ready (`pg_isready` check)
5. Starts Keycloak container
6. Waits for Keycloak to respond (HTTP health check)
7. Displays status of both services

**Output Example:**
```
========================================
  Starting Keycloak Service (with DB)
========================================

[INFO] Checking Podman machine status...
[SUCCESS] Podman machine is already running
[INFO] Checking PostgreSQL container...
[INFO] Starting PostgreSQL container...
[SUCCESS] PostgreSQL container started
[INFO] Waiting for PostgreSQL to be ready...
[SUCCESS] PostgreSQL is ready!

[INFO] Checking Keycloak container...
[INFO] Starting Keycloak container...
[SUCCESS] Keycloak container started
[INFO] Waiting for Keycloak to be ready...
[SUCCESS] Keycloak is ready!

========================================
  Services Status
========================================

[INFO] PostgreSQL Status:
NAMES               STATUS        PORTS
nexus-postgres-dev  Up 8 seconds  0.0.0.0:5432->5432/tcp

[INFO] Keycloak Status:
NAMES               STATUS        PORTS
nexus-keycloak-dev  Up 5 seconds  0.0.0.0:8090->8080/tcp

[SUCCESS] All services are running!

Access Points:
  • Keycloak Admin: http://localhost:8090/admin
  • Keycloak Realm: hrms-saas
  • Admin Credentials: admin/secret
  • PostgreSQL: localhost:5432
```

**Features:**
- Automatic PostgreSQL dependency detection
- Health checks with retry logic (15 retries for PostgreSQL, 30 for Keycloak)
- Graceful handling of already-running containers
- Colored output for easy status identification

---

### 2. stop-keycloak.sh

**Purpose:** Stop Keycloak service and optionally PostgreSQL.

**Usage:**
```bash
# Stop Keycloak only (PostgreSQL keeps running)
./stop-keycloak.sh

# Stop both Keycloak and PostgreSQL
./stop-keycloak.sh --with-db
```

**What it does:**
1. Checks and stops Keycloak container
2. Optionally stops PostgreSQL if `--with-db` flag is provided
3. Displays final status of both services

**Default Behavior (without --with-db):**
- Stops Keycloak only
- Leaves PostgreSQL running for faster next startup

**With --with-db Flag:**
- Stops both Keycloak and PostgreSQL
- Useful for complete shutdown or when PostgreSQL needs restart

**Output Example:**
```
==================================
  Stopping Keycloak Service
==================================

[INFO] Checking Keycloak container status...
[INFO] Stopping Keycloak container...
[SUCCESS] Keycloak container stopped

==================================
  Services Status
==================================

[INFO] PostgreSQL Status:
NAMES               STATUS        PORTS
nexus-postgres-dev  Up 2 minutes  0.0.0.0:5432->5432/tcp

[INFO] Keycloak Status:
NAMES               STATUS                   PORTS
nexus-keycloak-dev  Exited (0) 2 seconds ago

[SUCCESS] Keycloak has been stopped (PostgreSQL is still running)
```

---

### 3. restart-keycloak.sh

**Purpose:** Restart Keycloak service and optionally PostgreSQL.

**Usage:**
```bash
# Restart Keycloak only (recommended for config changes)
./restart-keycloak.sh

# Restart both PostgreSQL and Keycloak
./restart-keycloak.sh --with-db
```

**What it does:**

**Without --with-db:**
1. Stops Keycloak container
2. Ensures PostgreSQL is running (starts if needed)
3. Waits for PostgreSQL to be ready
4. Starts Keycloak
5. Waits for Keycloak health check

**With --with-db:**
1. Stops Keycloak container
2. Stops PostgreSQL container
3. Waits briefly (2 seconds)
4. Starts PostgreSQL
5. Waits for PostgreSQL to be ready
6. Starts Keycloak
7. Waits for Keycloak health check

**When to Use:**
- **Without flag:** After Keycloak configuration changes, realm updates
- **With --with-db:** After PostgreSQL updates, complete environment refresh

**Output Example:**
```
========================================
  Restarting Keycloak Service
========================================

[INFO] Checking Podman machine status...
[SUCCESS] Podman machine is already running
[INFO] Stopping Keycloak container...
[SUCCESS] Keycloak container stopped
[INFO] Checking PostgreSQL status...
[SUCCESS] PostgreSQL is already running
[INFO] Starting Keycloak container...
[SUCCESS] Keycloak container started
[INFO] Waiting for Keycloak to be ready...
[SUCCESS] Keycloak is ready!

[SUCCESS] Keycloak has been restarted!
```

---

### 4. status-keycloak.sh

**Purpose:** Check status of both PostgreSQL and Keycloak services.

**Usage:**
```bash
./status-keycloak.sh
```

**What it checks:**
1. Podman machine status
2. PostgreSQL container status
3. PostgreSQL connection readiness (`pg_isready`)
4. Keycloak container status
5. Keycloak HTTP health check
6. Realm accessibility

**Output Example:**
```
=================================================
  Keycloak & PostgreSQL Service Status
=================================================

Podman Machine Status:
[✓] Podman machine is running

PostgreSQL Container Status:
[✓] PostgreSQL container is running

NAMES               STATUS        PORTS
nexus-postgres-dev  Up 5 minutes  0.0.0.0:5432->5432/tcp
[✓] PostgreSQL is accepting connections

Keycloak Container Status:
[✓] Keycloak container is running

NAMES               STATUS        PORTS
nexus-keycloak-dev  Up 5 minutes  0.0.0.0:8090->8080/tcp

Keycloak Health Check:
[✓] Keycloak is responding (HTTP 302)

Realm Configuration:
[✓] Realm 'hrms-saas' is accessible

Access Information:
  • Admin Console: http://localhost:8090/admin
  • Realm: hrms-saas
  • Credentials: admin/secret

Realm Endpoints:
  • Token: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token
  • JWKS: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs
  • Userinfo: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/userinfo

Management Scripts:
  • Start: ./start-keycloak.sh (starts both PostgreSQL and Keycloak)
  • Stop: ./stop-keycloak.sh [--with-db]
  • Restart: ./restart-keycloak.sh [--with-db]
  • Status: ./status-keycloak.sh
  • Setup: ./setup-keycloak.sh
  • Test: ./test-token.sh

  Note: Use --with-db flag to also stop/restart PostgreSQL
```

---

## Service Dependencies

### Dependency Chain
```
Podman Machine
    ↓
PostgreSQL Container (nexus-postgres-dev)
    ↓
Keycloak Container (nexus-keycloak-dev)
```

### Why PostgreSQL is Required
- Keycloak uses PostgreSQL as its database backend
- Stores realm configuration, users, clients, tokens
- Without PostgreSQL, Keycloak cannot function

### Health Checks

**PostgreSQL:**
- Command: `pg_isready -U postgres`
- Timeout: 30 seconds (15 retries × 2 seconds)
- Purpose: Ensures database accepts connections

**Keycloak:**
- Method: HTTP request to `http://localhost:8090/`
- Expected: HTTP 200 or 302
- Timeout: 60 seconds (30 retries × 2 seconds)
- Purpose: Ensures Keycloak web server is responding

---

## Common Workflows

### 1. Daily Development Start

```bash
cd /path/to/keycloak/scripts

# Start all services
./start-keycloak.sh

# Verify everything is running
./status-keycloak.sh
```

### 2. Configuration Changes

```bash
# After changing Keycloak realm/client settings
./restart-keycloak.sh

# After changing PostgreSQL settings
./restart-keycloak.sh --with-db
```

### 3. End of Day Shutdown

```bash
# Stop Keycloak only (faster next startup)
./stop-keycloak.sh

# Or stop everything
./stop-keycloak.sh --with-db
```

### 4. Troubleshooting

```bash
# Check what's running
./status-keycloak.sh

# Restart both services for clean state
./restart-keycloak.sh --with-db

# Check logs if issues persist
podman logs nexus-postgres-dev
podman logs nexus-keycloak-dev
```

---

## Container Information

### PostgreSQL Container
- **Name:** `nexus-postgres-dev`
- **Image:** `postgres:16`
- **Port:** `5432` (mapped to host `5432`)
- **User:** `postgres`
- **Database:** Keycloak database

### Keycloak Container
- **Name:** `nexus-keycloak-dev`
- **Image:** `keycloak:latest`
- **Port:** `8080` (mapped to host `8090`)
- **Admin:** `admin` / `secret`
- **Realm:** `hrms-saas`

---

## Script Features

### Error Handling
- All scripts use `set -e` to exit on errors
- Graceful handling of already-running containers
- Clear error messages with suggestions

### Color Coding
- **Green (SUCCESS):** Operation completed successfully
- **Blue (INFO):** Informational messages
- **Yellow (WARNING):** Non-critical warnings
- **Red (ERROR):** Critical errors requiring attention

### Retry Logic
- PostgreSQL: 15 retries × 2 seconds = 30 seconds max wait
- Keycloak: 30 retries × 2 seconds = 60 seconds max wait
- Prevents premature failure during slow startups

---

## Troubleshooting

### Issue: "Podman machine is not running"
**Solution:**
```bash
podman machine start podman-machine-default
# Or use the start script which does this automatically
./start-keycloak.sh
```

### Issue: "PostgreSQL container not found"
**Cause:** Container doesn't exist
**Solution:**
```bash
# Verify container exists
podman ps -a | grep postgres

# If missing, you need to create the PostgreSQL container first
# Check your Docker Compose or container creation scripts
```

### Issue: "Keycloak did not start within expected time"
**Possible Causes:**
1. PostgreSQL not ready
2. Port 8090 already in use
3. Insufficient resources

**Solutions:**
```bash
# Check PostgreSQL
podman exec nexus-postgres-dev pg_isready -U postgres

# Check port availability
lsof -i :8090

# Check logs
podman logs nexus-keycloak-dev

# Try restart with both services
./restart-keycloak.sh --with-db
```

### Issue: "PostgreSQL is running but not yet ready"
**Cause:** PostgreSQL starting up
**Solution:** Wait a few more seconds, or restart:
```bash
./restart-keycloak.sh --with-db
```

---

## Best Practices

### 1. Starting Services
- Always use `./start-keycloak.sh` instead of `podman start` directly
- This ensures proper dependency order and health checks

### 2. Stopping Services
- During development, stop Keycloak only to save startup time:
  ```bash
  ./stop-keycloak.sh
  ```
- For overnight/weekend, stop both:
  ```bash
  ./stop-keycloak.sh --with-db
  ```

### 3. Restarting Services
- For Keycloak config changes: `./restart-keycloak.sh`
- For database changes: `./restart-keycloak.sh --with-db`
- For unknown issues: `./restart-keycloak.sh --with-db` (clean slate)

### 4. Regular Checks
```bash
# Quick health check
./status-keycloak.sh

# Verify realm accessibility
curl http://localhost:8090/realms/hrms-saas
```

---

## Integration with Other Scripts

### Setup Scripts
```bash
# Initial setup (run once)
./setup-keycloak.sh     # Creates realm and client
./create-mappers.sh     # Creates JWT mappers
./create-test-users.sh  # Creates test users
```

### Testing Scripts
```bash
# Test JWT token generation
./test-token.sh employee
./test-token.sh admin
```

### Recommended Workflow
```bash
# 1. Start services
./start-keycloak.sh

# 2. Check status
./status-keycloak.sh

# 3. Run setup (if needed)
./setup-keycloak.sh

# 4. Test tokens
./test-token.sh employee
```

---

## Environment Variables

The scripts use these container names. If you need to customize:

```bash
# In each script, modify these:
POSTGRES_CONTAINER="nexus-postgres-dev"
KEYCLOAK_CONTAINER="nexus-keycloak-dev"
PODMAN_MACHINE="podman-machine-default"
```

---

## Access Points

### Keycloak Admin Console
- **URL:** http://localhost:8090/admin
- **Username:** `admin`
- **Password:** `secret`
- **Realm:** `hrms-saas`

### PostgreSQL Database
- **Host:** `localhost`
- **Port:** `5432`
- **User:** `postgres`
- **Connection:** `psql -h localhost -p 5432 -U postgres`

### Keycloak Realm Endpoints
- **Base:** `http://localhost:8090/realms/hrms-saas`
- **Token:** `http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token`
- **JWKS:** `http://localhost:8090/realms/hrms-saas/protocol/openid-connect/certs`
- **Userinfo:** `http://localhost:8090/realms/hrms-saas/protocol/openid-connect/userinfo`

---

## Summary

The Keycloak management scripts provide a robust solution for managing the Keycloak and PostgreSQL service lifecycle with proper dependency handling:

1. **start-keycloak.sh** - Intelligent startup with dependency checks
2. **stop-keycloak.sh** - Flexible shutdown with optional database stop
3. **restart-keycloak.sh** - Smart restart with optional full reset
4. **status-keycloak.sh** - Comprehensive health monitoring

All scripts include:
- Automatic dependency management
- Health checks with retry logic
- Clear, colored output
- Helpful error messages
- Consistent user experience

**Key Improvement:** PostgreSQL dependency is now automatically handled, ensuring Keycloak never tries to start without its required database.

---

**Maintained by:** Development Team
**Version:** 2.0
**Date:** November 5, 2025
