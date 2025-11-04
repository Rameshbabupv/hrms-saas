# HRMS SaaS Keycloak QA Deployment Documentation

Complete documentation and deployment scripts for setting up Keycloak in QA environment with persistent data storage and HRMS SaaS configuration.

## 📁 Documentation Structure

```
docs/
├── README.md                          # This file - Documentation index
├── QA_QUICKSTART.md                   # Quick start guide (start here!)
├── QA_DEPLOYMENT_GUIDE.md             # Complete deployment guide
├── docker-compose.yml                 # Docker Compose configuration
├── .env.example                       # Environment configuration template
└── qa-scripts/
    ├── setup-qa.sh                    # Keycloak realm and client setup
    ├── deploy-with-docker-compose.sh  # Docker Compose deployment manager
    └── deploy-with-podman.sh          # Podman deployment manager
```

## 🚀 Quick Start

**New to this setup?** Start here: [QA Quick Start Guide](./QA_QUICKSTART.md)

### TL;DR - Get Running in 5 Minutes

```bash
# 1. Copy files to your QA server
mkdir ~/hrms-keycloak-qa && cd ~/hrms-keycloak-qa

# 2. Configure environment
cp .env.example .env
nano .env  # Update passwords and hostname

# 3. Deploy
chmod +x qa-scripts/*.sh
./qa-scripts/deploy-with-docker-compose.sh start

# 4. Configure Keycloak
./qa-scripts/setup-qa.sh

# 5. Access
open http://localhost:8090/admin
```

## 📚 Documentation

### For Quick Setup
- **[QA Quick Start Guide](./QA_QUICKSTART.md)** - Get running in 10 minutes

### For Complete Understanding
- **[QA Deployment Guide](./QA_DEPLOYMENT_GUIDE.md)** - Comprehensive deployment documentation
  - Architecture overview
  - Detailed setup instructions
  - Configuration reference
  - Backup and restore procedures
  - Troubleshooting guide
  - Security hardening
  - Integration with HRMS SaaS

## 🛠 Deployment Scripts

### Docker Compose (Recommended)

```bash
# Start all services
./qa-scripts/deploy-with-docker-compose.sh start

# Stop services
./qa-scripts/deploy-with-docker-compose.sh stop

# View status
./qa-scripts/deploy-with-docker-compose.sh status

# View logs
./qa-scripts/deploy-with-docker-compose.sh logs keycloak

# Backup data
./qa-scripts/deploy-with-docker-compose.sh backup

# Update services
./qa-scripts/deploy-with-docker-compose.sh update
```

### Podman

```bash
# Start all services
./qa-scripts/deploy-with-podman.sh start

# Stop services
./qa-scripts/deploy-with-podman.sh stop

# View status
./qa-scripts/deploy-with-podman.sh status
```

### Keycloak Setup

```bash
# Configure realm, client, roles, and mappers
./qa-scripts/setup-qa.sh

# This creates:
# - hrms-saas realm
# - hrms-web-app client (with secret)
# - 5 roles (super_admin, company_admin, hr_user, manager, employee)
# - 7 custom JWT mappers
# - keycloak-qa-config.env (configuration file)
```

## 🔧 Configuration Files

### docker-compose.yml
Complete Docker Compose configuration with:
- PostgreSQL 16 with persistent storage
- Keycloak (latest) with database backend
- pgAdmin for database management
- Health checks and resource limits
- Network isolation

### .env.example
Environment configuration template with:
- Database credentials
- Keycloak admin credentials
- Hostname configuration
- Security settings
- Integration endpoints

## 📦 What's Included

### Services

| Service | Port | Volume | Purpose |
|---------|------|--------|---------|
| PostgreSQL 16 | 5432 | hrms-pgdata-qa | Keycloak database |
| Keycloak | 8090 | hrms-keycloak-data-qa | Identity & Access Management |
| pgAdmin 4 | 8091 | hrms-pgadmin-data-qa | Database management UI |

### Keycloak Configuration

**Realm**: `hrms-saas`
- Multi-tenant support enabled
- Email verification enabled
- Brute force protection enabled
- Session timeouts configured

**Client**: `hrms-web-app`
- OAuth2/OIDC protocol
- Client secret authentication
- PKCE support
- Configured redirect URIs

**Roles**:
- `super_admin` - System administrator
- `company_admin` - Tenant administrator
- `hr_user` - HR management
- `manager` - Team management
- `employee` - Regular user (default)

**Custom JWT Claims**:
- `company_id` - Tenant identifier
- `tenant_id` - Tenant identifier
- `employee_id` - Employee identifier
- `user_type` - User type classification
- `company_code` - Company code
- `company_name` - Company name
- `phone` - User phone number

## 💾 Data Persistence

All data is stored in Docker/Podman named volumes:

```bash
# List volumes
docker volume ls | grep hrms

# Inspect volume
docker volume inspect hrms-keycloak-data-qa

# Backup volumes
./qa-scripts/deploy-with-docker-compose.sh backup
```

**Volumes**:
- `hrms-pgdata-qa` - PostgreSQL database files
- `hrms-keycloak-data-qa` - Keycloak data and configurations
- `hrms-pgadmin-data-qa` - pgAdmin settings

Data persists across:
- Container restarts
- Container updates
- System reboots

## 🔒 Security Features

- ✅ Brute force protection (5 failures = 15 min lockout)
- ✅ Email verification enabled
- ✅ Strong password policies
- ✅ Session timeout management
- ✅ Remember me functionality
- ✅ SSL/TLS ready (via reverse proxy)
- ✅ Network isolation
- ✅ Persistent data encryption at rest

## 🔗 Integration

### Spring Boot

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://qa-server:8090/realms/hrms-saas
          jwk-set-uri: http://qa-server:8090/realms/hrms-saas/protocol/openid-connect/certs
```

### React

```bash
REACT_APP_KEYCLOAK_URL=http://qa-server:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT_ID=hrms-web-app
```

### Important Endpoints

- **Token**: `http://qa-server:8090/realms/hrms-saas/protocol/openid-connect/token`
- **JWKS**: `http://qa-server:8090/realms/hrms-saas/protocol/openid-connect/certs`
- **UserInfo**: `http://qa-server:8090/realms/hrms-saas/protocol/openid-connect/userinfo`
- **Logout**: `http://qa-server:8090/realms/hrms-saas/protocol/openid-connect/logout`

## 🐛 Troubleshooting

### Quick Fixes

```bash
# Check logs
./qa-scripts/deploy-with-docker-compose.sh logs

# Restart services
./qa-scripts/deploy-with-docker-compose.sh restart

# Check status
./qa-scripts/deploy-with-docker-compose.sh status
```

### Common Issues

1. **Can't access admin console** - Check firewall and port 8090
2. **Services won't start** - Check logs and ensure ports are free
3. **Lost admin password** - Reset via bootstrap command
4. **Data lost** - Check volume mounts and backups

See [QA Deployment Guide](./QA_DEPLOYMENT_GUIDE.md#troubleshooting) for detailed troubleshooting.

## 📊 Monitoring

```bash
# View logs
docker-compose logs -f keycloak

# Container stats
docker stats hrms-keycloak-qa hrms-postgres-qa

# Health check
curl http://localhost:8090/health/ready
```

## 🔄 Maintenance

### Regular Tasks

```bash
# Backup (weekly recommended)
./qa-scripts/deploy-with-docker-compose.sh backup

# Update images (monthly recommended)
./qa-scripts/deploy-with-docker-compose.sh update

# Clean up old resources
./qa-scripts/deploy-with-docker-compose.sh cleanup
```

### Updates

```bash
# Pull latest images
docker-compose pull

# Recreate containers
docker-compose up -d --force-recreate
```

## 📝 Requirements

### System Requirements
- Docker 20+ or Podman 3+
- 4GB RAM minimum
- 20GB disk space
- Linux/Unix-based OS

### Network Requirements
- Access to quay.io (Keycloak image)
- Access to docker.io (PostgreSQL, pgAdmin images)
- Ports 5432, 8090, 8091 available

## 🎯 Use Cases

This deployment is suitable for:
- ✅ QA/Testing environments
- ✅ Development environments
- ✅ Staging environments
- ✅ Demo environments
- ⚠️ Production (with additional hardening)

## 📖 Additional Resources

- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Podman Documentation](https://docs.podman.io/)
- [HRMS SaaS Project Documentation](../../README.md)

## 🤝 Support

For issues or questions:
1. Check [QA Deployment Guide](./QA_DEPLOYMENT_GUIDE.md)
2. Check logs: `./qa-scripts/deploy-with-docker-compose.sh logs`
3. Contact DevOps team
4. Create issue in project repository

## 📋 Checklist for QA Deployment

- [ ] Copy all files to QA server
- [ ] Configure `.env` file with secure passwords
- [ ] Start services: `./qa-scripts/deploy-with-docker-compose.sh start`
- [ ] Run setup: `./qa-scripts/setup-qa.sh`
- [ ] Verify admin console access
- [ ] Create test users
- [ ] Test token generation
- [ ] Configure application integration
- [ ] Set up backup schedule
- [ ] Document configuration details
- [ ] Test complete authentication flow

## 🔐 Security Notes

**IMPORTANT**:
- Never commit `.env` file to version control
- Use strong, unique passwords for all services
- Store client secret securely
- Rotate credentials regularly
- Enable SSL/TLS for external access
- Restrict admin console access
- Regular security updates
- Monitor access logs

## 📄 License

This configuration is part of the HRMS SaaS project.

---

**Ready to deploy?** Start with the [QA Quick Start Guide](./QA_QUICKSTART.md)! 🚀
