# Keycloak QA Quick Start Guide

This guide will help you set up Keycloak for HRMS SaaS in your QA environment in under 10 minutes.

## Prerequisites

- Docker or Podman installed
- 4GB+ RAM available
- Network access to pull images

## Quick Start (Docker Compose - Recommended)

### 1. Prepare Files

```bash
# Create deployment directory
mkdir -p ~/hrms-keycloak-qa
cd ~/hrms-keycloak-qa

# Copy deployment files to this directory:
# - docker-compose.yml
# - .env.example
# - qa-scripts/
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your passwords (use strong passwords!)
nano .env

# Generate secure passwords:
openssl rand -base64 32
```

**Minimum required changes in .env:**
- `POSTGRES_PASSWORD` - Set a secure password
- `KEYCLOAK_ADMIN_PASSWORD` - Set a secure admin password
- `KEYCLOAK_HOSTNAME` - Your QA server hostname (or localhost for testing)
- `PGADMIN_EMAIL` - Your email
- `PGADMIN_PASSWORD` - Set a secure password

### 3. Deploy Services

```bash
# Make scripts executable
chmod +x qa-scripts/*.sh

# Start all services
./qa-scripts/deploy-with-docker-compose.sh start

# Wait for services to be ready (30-60 seconds)
```

### 4. Configure Keycloak

```bash
# Run setup script to create realm, client, and roles
./qa-scripts/setup-qa.sh

# This will:
# ✓ Create hrms-saas realm
# ✓ Configure hrms-web-app client
# ✓ Set up 5 roles (super_admin, company_admin, hr_user, manager, employee)
# ✓ Create custom JWT mappers (company_id, tenant_id, etc.)
# ✓ Save configuration to keycloak-qa-config.env
```

### 5. Verify Installation

```bash
# Check status
./qa-scripts/deploy-with-docker-compose.sh status

# Access admin console
open http://localhost:8090/admin
# Login: admin / [your-password-from-.env]
```

## Quick Start (Podman)

If you prefer using Podman instead of Docker:

```bash
# Deploy with Podman
./qa-scripts/deploy-with-podman.sh start

# Configure Keycloak
./qa-scripts/setup-qa.sh

# Check status
./qa-scripts/deploy-with-podman.sh status
```

## Access Points

After successful deployment:

| Service | URL | Credentials |
|---------|-----|-------------|
| Keycloak Admin | http://your-server:8090/admin | admin / [from .env] |
| Keycloak Realm | http://your-server:8090/realms/hrms-saas | - |
| pgAdmin | http://your-server:8091 | [from .env] |
| PostgreSQL | your-server:5432 | admin / [from .env] |

## Common Commands

### Docker Compose

```bash
# Start services
./qa-scripts/deploy-with-docker-compose.sh start

# Stop services
./qa-scripts/deploy-with-docker-compose.sh stop

# Restart services
./qa-scripts/deploy-with-docker-compose.sh restart

# View status
./qa-scripts/deploy-with-docker-compose.sh status

# View logs
./qa-scripts/deploy-with-docker-compose.sh logs keycloak

# Backup data
./qa-scripts/deploy-with-docker-compose.sh backup

# Update to latest version
./qa-scripts/deploy-with-docker-compose.sh update
```

### Podman

```bash
# Start services
./qa-scripts/deploy-with-podman.sh start

# Stop services
./qa-scripts/deploy-with-podman.sh stop

# Restart services
./qa-scripts/deploy-with-podman.sh restart

# View status
./qa-scripts/deploy-with-podman.sh status
```

## Data Persistence

All data is stored in named volumes:

- **hrms-pgdata-qa** - PostgreSQL database
- **hrms-keycloak-data-qa** - Keycloak data and configurations
- **hrms-pgadmin-data-qa** - pgAdmin settings

Your data will persist across container restarts and updates!

## Integration with HRMS SaaS

### Configuration File

After running `setup-qa.sh`, you'll get a `keycloak-qa-config.env` file with all necessary configuration:

```bash
# View configuration
cat keycloak-qa-config.env
```

### Spring Boot Integration

Add to your `application-qa.yml`:

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://your-qa-server:8090/realms/hrms-saas
          jwk-set-uri: http://your-qa-server:8090/realms/hrms-saas/protocol/openid-connect/certs
```

### React Integration

Update your `.env.qa`:

```bash
REACT_APP_KEYCLOAK_URL=http://your-qa-server:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app
```

## Testing Token Generation

Create a test user via admin console, then test:

```bash
# Test token generation
curl -X POST "http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=hrms-web-app" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "username=testuser" \
  -d "password=testpass" | jq
```

## Troubleshooting

### Services won't start

```bash
# Check logs
./qa-scripts/deploy-with-docker-compose.sh logs

# Check if ports are already in use
sudo lsof -i :8090
sudo lsof -i :5432
```

### Can't access admin console

```bash
# Verify Keycloak is running
curl http://localhost:8090/

# Check firewall
sudo ufw status
```

### Lost admin password

```bash
# Reset admin password
docker exec -it hrms-keycloak-qa /opt/keycloak/bin/kc.sh \
  bootstrap --username admin --password newpassword
```

### Need to reset everything

```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Start fresh
./qa-scripts/deploy-with-docker-compose.sh start
./qa-scripts/setup-qa.sh
```

## Backup and Restore

### Backup

```bash
# Automated backup
./qa-scripts/deploy-with-docker-compose.sh backup

# Backups are stored in: ../backups/
```

### Restore

```bash
# Stop services
./qa-scripts/deploy-with-docker-compose.sh stop

# Restore database
docker exec -i hrms-postgres-qa psql -U admin hrms_keycloak_qa < backup.sql

# Start services
./qa-scripts/deploy-with-docker-compose.sh start
```

## Security Checklist

- [ ] Changed all default passwords in `.env`
- [ ] `.env` file is not committed to git
- [ ] Firewall rules configured (if external access needed)
- [ ] SSL/TLS configured via reverse proxy (for production-like QA)
- [ ] Regular backups scheduled
- [ ] Backup files stored securely
- [ ] Admin console access restricted to authorized IPs

## Next Steps

1. **Create Test Users**: Use admin console to create test users with different roles
2. **Configure Email**: Set up SMTP for email verification (optional for QA)
3. **Custom Themes**: Add company branding (optional)
4. **Integration Testing**: Test with HRMS SaaS applications
5. **Performance Testing**: Load test token generation and validation

## Support

For detailed documentation, see:
- [QA Deployment Guide](./QA_DEPLOYMENT_GUIDE.md) - Complete deployment guide
- [Keycloak Official Docs](https://www.keycloak.org/documentation)

## Configuration Summary

After setup, you'll have:

✅ **Realm**: hrms-saas
✅ **Client**: hrms-web-app (with client secret)
✅ **Roles**: super_admin, company_admin, hr_user, manager, employee
✅ **JWT Mappers**: company_id, tenant_id, employee_id, user_type, company_code, company_name, phone
✅ **Persistent Storage**: All data in named volumes
✅ **Security**: Brute force protection, email verification enabled

Your Keycloak QA environment is ready for HRMS SaaS! 🚀
