# Instructions for Claude to Setup Keycloak in QA Box

This document contains instructions that can be provided to Claude Code (or any AI assistant) to automatically set up Keycloak in a QA environment.

## Context for Claude

You are setting up Keycloak for the HRMS SaaS multi-tenant platform in a QA environment. All configuration files, scripts, and documentation are provided in this directory.

## Prerequisites Check

First, verify the QA box has:
- Docker or Podman installed
- Minimum 4GB RAM
- 20GB available disk space
- Network access to pull container images
- Ports 5432, 8090, 8091 available

## Step-by-Step Setup Instructions

### 1. Prepare the Deployment Directory

```bash
# Create deployment directory
mkdir -p ~/hrms-keycloak-qa
cd ~/hrms-keycloak-qa

# Copy all files from the docs directory:
# - docker-compose.yml
# - .env.example
# - qa-scripts/ (entire directory with all scripts)
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# The .env file needs these values updated:
# - POSTGRES_PASSWORD: Set a secure password (generate with: openssl rand -base64 32)
# - KEYCLOAK_ADMIN_PASSWORD: Set a secure admin password
# - KEYCLOAK_HOSTNAME: Set to QA server hostname or IP
# - PGADMIN_EMAIL: Set admin email
# - PGADMIN_PASSWORD: Set pgAdmin password
# - REDIRECT_URIS: Update with actual QA application URLs
# - WEB_ORIGINS: Update with actual QA application URLs
```

### 3. Make Scripts Executable

```bash
chmod +x qa-scripts/*.sh
```

### 4. Deploy Services

For Docker Compose:
```bash
./qa-scripts/deploy-with-docker-compose.sh start
```

For Podman:
```bash
./qa-scripts/deploy-with-podman.sh start
```

**Wait for services to be ready** (30-60 seconds). You can check status with:
```bash
./qa-scripts/deploy-with-docker-compose.sh status
```

### 5. Configure Keycloak Realm

```bash
# This script will create:
# - hrms-saas realm
# - hrms-web-app client
# - 5 roles (super_admin, company_admin, hr_user, manager, employee)
# - 7 custom JWT mappers
# - Configuration file: keycloak-qa-config.env

./qa-scripts/setup-qa.sh
```

### 6. Verify Installation

```bash
# Check all services are running
./qa-scripts/deploy-with-docker-compose.sh status

# Test Keycloak is accessible
curl -f http://localhost:8090/

# Test database connection
docker exec hrms-postgres-qa pg_isready -U admin
```

### 7. Access and Test

- **Keycloak Admin Console**: http://[qa-server]:8090/admin
  - Username: admin
  - Password: [from .env file]

- **Keycloak Realm**: http://[qa-server]:8090/realms/hrms-saas

- **pgAdmin**: http://[qa-server]:8091
  - Email: [from .env file]
  - Password: [from .env file]

### 8. Save Configuration

After running `setup-qa.sh`, a file named `keycloak-qa-config.env` will be created. This file contains:
- Client ID
- Client Secret (important!)
- All endpoint URLs
- Configuration for Spring Boot
- Configuration for React

**Important**: Save this file securely and provide it to the development team.

## Expected Result

After successful setup, you should have:

✅ **Services Running**:
- PostgreSQL on port 5432
- Keycloak on port 8090
- pgAdmin on port 8091

✅ **Keycloak Configuration**:
- Realm: `hrms-saas`
- Client: `hrms-web-app` (with client secret)
- Roles: super_admin, company_admin, hr_user, manager, employee
- JWT Mappers: company_id, tenant_id, employee_id, user_type, company_code, company_name, phone

✅ **Persistent Storage**:
- All data stored in named volumes
- Data persists across restarts

✅ **Configuration File**:
- `keycloak-qa-config.env` created with all settings

## Verification Steps

Run these commands to verify everything is working:

```bash
# 1. Check all containers are running
docker ps | grep hrms

# 2. Check volumes exist
docker volume ls | grep hrms

# 3. Verify Keycloak responds
curl -s http://localhost:8090/ | grep -q "Keycloak" && echo "Keycloak OK"

# 4. Verify database is accessible
docker exec hrms-postgres-qa psql -U admin -d hrms_keycloak_qa -c "SELECT 1;" && echo "Database OK"

# 5. Verify realm exists
curl -s http://localhost:8090/realms/hrms-saas | grep -q "hrms-saas" && echo "Realm OK"
```

## Common Issues and Solutions

### Issue: Services won't start

**Check**:
```bash
# View logs
./qa-scripts/deploy-with-docker-compose.sh logs

# Check if ports are in use
sudo lsof -i :8090
sudo lsof -i :5432
sudo lsof -i :8091
```

**Solution**: Stop conflicting services or change ports in docker-compose.yml

### Issue: Can't access admin console

**Check**:
```bash
# Verify Keycloak is running
curl http://localhost:8090/

# Check firewall
sudo ufw status
```

**Solution**: Open port 8090 in firewall or configure reverse proxy

### Issue: Keycloak takes too long to start

**This is normal** - Keycloak can take 30-60 seconds to start, especially on first run.

**Check progress**:
```bash
docker logs -f hrms-keycloak-qa
```

### Issue: Setup script fails

**Check**:
- Keycloak is fully started and accessible
- Admin credentials in .env are correct
- jq is installed (`sudo apt-get install jq` or `brew install jq`)

### Issue: Lost admin password

**Reset**:
```bash
docker exec -it hrms-keycloak-qa /opt/keycloak/bin/kc.sh \
  bootstrap --username admin --password new_secure_password
```

## Integration Information

After setup, provide this information to the development team:

### For Spring Boot Backend

Update `application-qa.yml`:
```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://[qa-server]:8090/realms/hrms-saas
          jwk-set-uri: http://[qa-server]:8090/realms/hrms-saas/protocol/openid-connect/certs

keycloak:
  auth-server-url: http://[qa-server]:8090
  realm: hrms-saas
  resource: hrms-web-app
  credentials:
    secret: [from keycloak-qa-config.env]
```

### For React Frontend

Update `.env.qa`:
```bash
REACT_APP_KEYCLOAK_URL=http://[qa-server]:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app
```

### Important Endpoints

- **Token Endpoint**: `http://[qa-server]:8090/realms/hrms-saas/protocol/openid-connect/token`
- **JWKS Endpoint**: `http://[qa-server]:8090/realms/hrms-saas/protocol/openid-connect/certs`
- **UserInfo Endpoint**: `http://[qa-server]:8090/realms/hrms-saas/protocol/openid-connect/userinfo`
- **Logout Endpoint**: `http://[qa-server]:8090/realms/hrms-saas/protocol/openid-connect/logout`

## Backup Instructions

Setup automated backups:

```bash
# Manual backup
./qa-scripts/deploy-with-docker-compose.sh backup

# Setup cron job for daily backups
crontab -e

# Add this line (backs up at 2 AM daily):
0 2 * * * cd ~/hrms-keycloak-qa && ./qa-scripts/deploy-with-docker-compose.sh backup > /dev/null 2>&1
```

## Maintenance Commands

```bash
# View logs
./qa-scripts/deploy-with-docker-compose.sh logs [service_name]

# Restart services
./qa-scripts/deploy-with-docker-compose.sh restart

# Stop services
./qa-scripts/deploy-with-docker-compose.sh stop

# Update to latest versions
./qa-scripts/deploy-with-docker-compose.sh update

# Backup data
./qa-scripts/deploy-with-docker-compose.sh backup
```

## Security Checklist

- [ ] All passwords in .env are strong and unique
- [ ] .env file has restricted permissions (chmod 600 .env)
- [ ] .env file is not committed to version control
- [ ] Client secret is stored securely
- [ ] Firewall configured (if external access needed)
- [ ] SSL/TLS configured via reverse proxy (for production-like QA)
- [ ] Admin console access restricted
- [ ] Backup strategy in place

## Documentation References

- **Quick Start Guide**: `QA_QUICKSTART.md`
- **Complete Deployment Guide**: `QA_DEPLOYMENT_GUIDE.md`
- **Documentation Index**: `README.md`

## Summary

This setup provides:
- Complete Keycloak installation with PostgreSQL backend
- HRMS SaaS realm pre-configured with all necessary settings
- Multi-tenant support via custom JWT claims
- Persistent data storage
- Management tools (pgAdmin)
- Automated deployment and configuration scripts
- Backup capabilities

**Estimated setup time**: 10-15 minutes

**All configuration is the same as the development environment**, ensuring consistency across environments.

---

## For Claude: Quick Execution Checklist

When executing this setup, follow this order:

1. ✅ Verify prerequisites (Docker/Podman, RAM, disk, ports)
2. ✅ Create deployment directory
3. ✅ Copy all files from docs/ to deployment directory
4. ✅ Configure .env file with secure passwords
5. ✅ Make scripts executable (chmod +x)
6. ✅ Deploy services (deploy-with-docker-compose.sh start)
7. ✅ Wait for services to be ready (30-60 seconds)
8. ✅ Run Keycloak setup (setup-qa.sh)
9. ✅ Verify all services are running
10. ✅ Save keycloak-qa-config.env securely
11. ✅ Test admin console access
12. ✅ Provide integration details to team

**Remember**: Always use secure, randomly generated passwords for production-like environments!
