# PostgreSQL Setup from Scratch

## Versions
- **PostgreSQL:** 16.x (container)
- **Podman:** 5.5.2+
- **psql client:** 15.x+ (for local connections)

## Prerequisites

### Install Podman
```bash
# macOS
brew install podman

# Linux (RHEL/Fedora)
sudo dnf install podman

# Linux (Ubuntu/Debian)
sudo apt install podman

# Verify installation
podman --version
```

### Initialize Podman Machine (macOS only)
```bash
podman machine init
podman machine start
```

## Configuration
- **Port:** 5433
- **Database:** hrms_db
- **Admin User:** admin
- **Password:** secret
- **Host:** localhost
- **Container Name:** postgres-hrms

## Setup PostgreSQL Container

```bash
# Pull PostgreSQL image
podman pull postgres:16

# Run PostgreSQL container
podman run -d \
  --name postgres-hrms \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=hrms_db \
  -p 5433:5432 \
  -v postgres-hrms-data:/var/lib/postgresql/data \
  postgres:16

# Verify container is running
podman ps

# Test connection
psql -h localhost -p 5433 -U admin -d hrms_db -c "\conninfo"
```

## Connection String
```
postgresql://admin:secret@localhost:5433/hrms_db
```

## Container Management
```bash
# Stop container
podman stop postgres-hrms

# Start container
podman start postgres-hrms

# Restart container
podman restart postgres-hrms

# Check status
podman ps -a | grep postgres-hrms

# View logs
podman logs postgres-hrms

# Remove container (keeps data volume)
podman rm postgres-hrms

# Remove data volume (WARNING: destroys all data)
podman volume rm postgres-hrms-data
```

## Access Container Shell
```bash
# Enter container as postgres user
podman exec -it postgres-hrms psql -U admin -d hrms_db

# Enter container bash shell
podman exec -it postgres-hrms bash
```

## Notes
- Container uses internal port 5432, mapped to host port 5433
- Data persisted in named volume: `postgres-hrms-data`
- PostgreSQL 16 latest stable version
- Auto-restart: add `--restart=always` to run command if needed
