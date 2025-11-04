# Keycloak QA Deployment Guide for HRMS SaaS

This guide provides complete instructions for deploying Keycloak in your QA environment with persistent data storage and the same HRMS SaaS configuration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Methods](#deployment-methods)
4. [Configuration](#configuration)
5. [Setup Instructions](#setup-instructions)
6. [Verification](#verification)
7. [Backup and Restore](#backup-and-restore)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- Docker or Podman installed
- Minimum 4GB RAM
- 20GB available disk space
- Linux/Unix-based system (Ubuntu 20.04+, RHEL 8+, or macOS)
- Network access to pull images from quay.io and docker.io

### Required Tools

```bash
# Docker/Podman
docker --version  # or podman --version

# Docker Compose (if using Docker)
docker-compose --version

# jq for JSON processing
jq --version

# curl for API calls
curl --version
```

## Architecture Overview

The deployment consists of three main components:

1. **PostgreSQL 16** - Database for Keycloak
   - Port: 5432
   - Volume: `pgdata-qa` → `/var/lib/postgresql/data`

2. **Keycloak (latest)** - Identity and Access Management
   - Port: 8090 (mapped from 8080)
   - Volume: `keycloak-data-qa` → `/opt/keycloak/data`

3. **pgAdmin 4** - PostgreSQL Management UI
   - Port: 8091 (mapped from 80)
   - Volume: `pgadmin-data-qa` → `/var/lib/pgadmin`

## Deployment Methods

### Method 1: Docker Compose (Recommended)

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    container_name: hrms-postgres-qa
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-secret}
      POSTGRES_DB: hrms_keycloak_qa
    volumes:
      - pgdata-qa:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - hrms-network-qa
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d hrms_keycloak_qa"]
      interval: 10s
      timeout: 5s
      retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: hrms-keycloak-qa
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD:-secret}
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/hrms_keycloak_qa
      KC_DB_USERNAME: admin
      KC_DB_PASSWORD: ${POSTGRES_PASSWORD:-secret}
      KC_HOSTNAME: ${KEYCLOAK_HOSTNAME:-localhost}
      KC_HOSTNAME_STRICT: false
      KC_HTTP_ENABLED: true
      KC_PROXY: edge
    volumes:
      - keycloak-data-qa:/opt/keycloak/data
    ports:
      - "8090:8080"
      - "8443:8443"
    networks:
      - hrms-network-qa
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    command: start-dev
    healthcheck:
      test: ["CMD-SHELL", "exec 3<>/dev/tcp/localhost/8080 && echo -e 'GET /health/ready HTTP/1.1\\r\\nHost: localhost\\r\\n\\r\\n' >&3 && cat <&3 | grep -q '200 OK'"]
      interval: 30s
      timeout: 10s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: hrms-pgadmin-qa
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL:-admin@hrms.com}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD:-secret}
    volumes:
      - pgadmin-data-qa:/var/lib/pgadmin
    ports:
      - "8091:80"
    networks:
      - hrms-network-qa
    restart: unless-stopped

volumes:
  pgdata-qa:
    driver: local
  keycloak-data-qa:
    driver: local
  pgadmin-data-qa:
    driver: local

networks:
  hrms-network-qa:
    driver: bridge
```

### Method 2: Individual Container Commands (Podman/Docker)

Use the provided shell scripts in the `qa-deployment` directory.

## Configuration

### Environment Variables

Create a `.env` file in your deployment directory:

```bash
# PostgreSQL Configuration
POSTGRES_PASSWORD=your_secure_password_here

# Keycloak Configuration
KEYCLOAK_ADMIN_PASSWORD=your_secure_admin_password_here
KEYCLOAK_HOSTNAME=keycloak.yourqa.domain.com

# pgAdmin Configuration
PGADMIN_EMAIL=admin@yourcompany.com
PGADMIN_PASSWORD=your_pgadmin_password_here

# HRMS SaaS Configuration
REALM_NAME=hrms-saas
CLIENT_ID=hrms-web-app
```

### HRMS SaaS Realm Configuration

The setup includes:

- **Realm**: `hrms-saas`
- **Client**: `hrms-web-app`
- **Roles**:
  - `super_admin` - System-wide administrator
  - `company_admin` - Company/tenant administrator
  - `hr_user` - HR management user
  - `manager` - Team manager
  - `employee` - Regular employee (default)
- **Custom JWT Mappers**:
  - `company_id` - Tenant/company identifier
  - `tenant_id` - Tenant identifier
  - `employee_id` - Employee identifier
  - `user_type` - User type classification
  - `company_code` - Company code
  - `company_name` - Company name
  - `phone` - User phone number

## Setup Instructions

### Step 1: Prepare the Environment

```bash
# Create deployment directory
mkdir -p ~/hrms-keycloak-qa
cd ~/hrms-keycloak-qa

# Download deployment files
# (Copy docker-compose.yml, .env, and scripts to this directory)

# Set proper permissions for scripts
chmod +x *.sh
```

### Step 2: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your secure passwords
nano .env  # or vim .env
```

### Step 3: Deploy Services

#### Using Docker Compose:

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f keycloak
```

#### Using Podman/Docker individually:

```bash
# Start services
./start-all.sh

# Or start individually
./start-postgres.sh
./start-keycloak.sh
./start-pgadmin.sh
```

### Step 4: Configure Keycloak Realm

Wait for Keycloak to be fully started (30-60 seconds), then run:

```bash
# Configure HRMS SaaS realm
./setup-keycloak.sh

# Create protocol mappers
./create-mappers.sh

# Create test users (optional for QA)
./create-test-users.sh
```

### Step 5: Verify Installation

```bash
# Check service status
./status-all.sh

# Test token generation
./test-token.sh testuser1 Test@123
```

## Verification

### Health Checks

1. **PostgreSQL**:
   ```bash
   docker exec hrms-postgres-qa pg_isready -U admin
   ```

2. **Keycloak**:
   ```bash
   curl -f http://localhost:8090/health/ready
   ```

3. **Admin Console**:
   - URL: http://your-qa-server:8090/admin
   - Login: admin / [your-password]

### Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Keycloak Admin Console | http://qa-server:8090/admin | admin / [from .env] |
| Keycloak Realm | http://qa-server:8090/realms/hrms-saas | - |
| pgAdmin | http://qa-server:8091 | [from .env] |
| PostgreSQL | qa-server:5432 | admin / [from .env] |

## Backup and Restore

### Backup

```bash
# Backup PostgreSQL data
docker exec hrms-postgres-qa pg_dump -U admin hrms_keycloak_qa > keycloak-backup-$(date +%Y%m%d).sql

# Backup Keycloak data volume
docker run --rm -v keycloak-data-qa:/data -v $(pwd):/backup alpine tar czf /backup/keycloak-data-backup-$(date +%Y%m%d).tar.gz -C /data .

# Backup entire configuration
./backup-all.sh
```

### Restore

```bash
# Restore PostgreSQL
docker exec -i hrms-postgres-qa psql -U admin hrms_keycloak_qa < keycloak-backup-20250104.sql

# Restore Keycloak data volume
docker run --rm -v keycloak-data-qa:/data -v $(pwd):/backup alpine sh -c "cd /data && tar xzf /backup/keycloak-data-backup-20250104.tar.gz"

# Or use restore script
./restore-all.sh keycloak-backup-20250104.sql keycloak-data-backup-20250104.tar.gz
```

## Data Persistence

### Volume Locations

The deployment uses named volumes for data persistence:

- **pgdata-qa**: PostgreSQL database files
- **keycloak-data-qa**: Keycloak data including realm configurations
- **pgadmin-data-qa**: pgAdmin settings and server connections

### Volume Inspection

```bash
# List volumes
docker volume ls | grep qa

# Inspect volume
docker volume inspect keycloak-data-qa

# Find volume mount point
docker volume inspect keycloak-data-qa --format '{{ .Mountpoint }}'
```

## Monitoring

### Container Logs

```bash
# Real-time logs
docker-compose logs -f

# Specific service
docker-compose logs -f keycloak

# Last 100 lines
docker-compose logs --tail=100 keycloak
```

### Resource Usage

```bash
# Container stats
docker stats hrms-keycloak-qa hrms-postgres-qa hrms-pgadmin-qa
```

## Troubleshooting

### Keycloak Won't Start

1. Check PostgreSQL is running:
   ```bash
   docker ps | grep postgres
   ```

2. Check Keycloak logs:
   ```bash
   docker logs hrms-keycloak-qa
   ```

3. Verify database connection:
   ```bash
   docker exec hrms-postgres-qa psql -U admin -d hrms_keycloak_qa -c "SELECT 1;"
   ```

### Cannot Access Admin Console

1. Check Keycloak is running:
   ```bash
   curl http://localhost:8090/
   ```

2. Verify port mapping:
   ```bash
   docker port hrms-keycloak-qa
   ```

3. Check firewall rules:
   ```bash
   sudo ufw status
   sudo firewall-cmd --list-ports
   ```

### Data Lost After Restart

1. Verify volumes are mounted:
   ```bash
   docker inspect hrms-keycloak-qa | jq '.[].Mounts'
   ```

2. Check volume exists:
   ```bash
   docker volume ls | grep keycloak-data-qa
   ```

### Performance Issues

1. Increase container resources:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2'
         memory: 2G
       reservations:
         memory: 1G
   ```

2. Tune PostgreSQL:
   ```yaml
   command: >
     postgres
     -c shared_buffers=256MB
     -c max_connections=200
   ```

## Security Hardening

### Production Recommendations

1. **Use SSL/TLS**:
   - Configure reverse proxy (nginx/Apache)
   - Use Let's Encrypt certificates
   - Enable HTTPS only

2. **Change Default Passwords**:
   ```bash
   # Generate strong passwords
   openssl rand -base64 32
   ```

3. **Network Isolation**:
   - Use internal networks
   - Restrict PostgreSQL access
   - Use firewall rules

4. **Regular Updates**:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

5. **Backup Schedule**:
   - Set up automated backups
   - Test restore procedures
   - Store backups offsite

## Maintenance

### Updates

```bash
# Pull latest images
docker-compose pull

# Recreate containers
docker-compose up -d --force-recreate

# Remove old images
docker image prune -a
```

### Cleanup

```bash
# Stop all services
docker-compose down

# Remove volumes (CAUTION: This deletes all data!)
docker-compose down -v

# Clean up unused resources
docker system prune -a
```

## Integration with HRMS SaaS Application

### Spring Boot Configuration

Add to your `application-qa.yml`:

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://qa-keycloak-server:8090/realms/hrms-saas
          jwk-set-uri: http://qa-keycloak-server:8090/realms/hrms-saas/protocol/openid-connect/certs

keycloak:
  auth-server-url: http://qa-keycloak-server:8090
  realm: hrms-saas
  resource: hrms-web-app
  credentials:
    secret: ${KEYCLOAK_CLIENT_SECRET}
```

### React Application Configuration

Update your `.env.qa`:

```bash
REACT_APP_KEYCLOAK_URL=http://qa-keycloak-server:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app
```

## Support

For issues or questions:

1. Check logs: `docker-compose logs`
2. Review Keycloak documentation: https://www.keycloak.org/documentation
3. Contact DevOps team
4. Create issue in project repository

## Appendix

### Quick Reference Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart Keycloak
docker-compose restart keycloak

# View logs
docker-compose logs -f keycloak

# Access PostgreSQL
docker exec -it hrms-postgres-qa psql -U admin -d hrms_keycloak_qa

# Backup
docker exec hrms-postgres-qa pg_dump -U admin hrms_keycloak_qa > backup.sql

# Restore
docker exec -i hrms-postgres-qa psql -U admin hrms_keycloak_qa < backup.sql
```

### URLs Quick Reference

- Keycloak Admin: http://qa-server:8090/admin
- Keycloak Realm: http://qa-server:8090/realms/hrms-saas
- Token Endpoint: http://qa-server:8090/realms/hrms-saas/protocol/openid-connect/token
- JWKS Endpoint: http://qa-server:8090/realms/hrms-saas/protocol/openid-connect/certs
- pgAdmin: http://qa-server:8091
