# HRMS SaaS - Docker Compose & Deployment Guide

## 📋 Part 5: Docker Compose Setup & Deployment

This document provides Docker Compose configuration and deployment instructions for local development and production.

---

## 🐳 Docker Compose Setup

### **docker-compose.yml** (Root of Spring Boot project)

```yaml
version: '3.8'

services:
  # ============================================
  # PostgreSQL Database
  # ============================================
  postgres:
    image: postgres:16-alpine
    container_name: hrms-postgres
    environment:
      POSTGRES_DB: hrms_saas_db
      POSTGRES_USER: hrms_user
      POSTGRES_PASSWORD: hrms_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - hrms-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U hrms_user -d hrms_saas_db"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ============================================
  # Keycloak
  # ============================================
  keycloak:
    image: quay.io/keycloak/keycloak:23.0.3
    container_name: hrms-keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/hrms_saas_db
      KC_DB_USERNAME: hrms_user
      KC_DB_PASSWORD: hrms_password
      KC_HOSTNAME: localhost
      KC_HOSTNAME_STRICT: false
      KC_HTTP_ENABLED: true
    ports:
      - "8090:8080"
    command:
      - start-dev
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - hrms-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ============================================
  # Spring Boot Backend
  # ============================================
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: hrms-backend
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/hrms_saas_db
      SPRING_DATASOURCE_USERNAME: hrms_user
      SPRING_DATASOURCE_PASSWORD: hrms_password
      SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: http://keycloak:8080/realms/hrms-saas
      SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI: http://keycloak:8080/realms/hrms-saas/protocol/openid-connect/certs
      KEYCLOAK_SERVER_URL: http://keycloak:8080
      KEYCLOAK_REALM: hrms-saas
    ports:
      - "8081:8081"
    depends_on:
      postgres:
        condition: service_healthy
      keycloak:
        condition: service_healthy
    networks:
      - hrms-network
    volumes:
      - ./logs:/app/logs

volumes:
  postgres_data:
    driver: local

networks:
  hrms-network:
    driver: bridge
```

---

## 📦 Dockerfile for Spring Boot

### **Dockerfile** (Root of Spring Boot project)

```dockerfile
# ============================================
# Multi-stage build for Spring Boot
# ============================================

# Stage 1: Build
FROM maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /app

# Copy pom.xml and download dependencies (cached layer)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copy JAR from build stage
COPY --from=build /app/target/hrms-saas-backend-*.jar app.jar

# Create logs directory
RUN mkdir -p /app/logs

# Expose port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8081/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 🚀 Database Initialization

### **init-scripts/01-init-db.sql**

```sql
-- ============================================
-- Database Initialization Script
-- ============================================

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE hrms_saas_db TO hrms_user;

-- Create schema (if needed)
CREATE SCHEMA IF NOT EXISTS public;

COMMENT ON DATABASE hrms_saas_db IS 'HRMS SaaS Multi-Tenant Database';
```

### **init-scripts/02-sample-data.sql** (Optional for testing)

```sql
-- ============================================
-- Sample Data for Testing
-- ============================================

-- Insert sample company (tenant_id: testcompany1)
INSERT INTO company_master (tenant_id, company_name, company_code, email, status, subscription_plan)
VALUES ('testcompany1', 'Test Company Inc', 'TEST001', 'admin@testcompany.com', 'ACTIVE', 'FREE')
ON CONFLICT (tenant_id) DO NOTHING;

-- Insert sample employees
INSERT INTO employees (id, tenant_id, employee_code, first_name, last_name, email, designation, status)
VALUES
    (gen_random_uuid(), 'testcompany1', 'EMP001', 'John', 'Doe', 'john.doe@testcompany.com', 'Software Engineer', 'ACTIVE'),
    (gen_random_uuid(), 'testcompany1', 'EMP002', 'Jane', 'Smith', 'jane.smith@testcompany.com', 'Product Manager', 'ACTIVE')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE company_master IS 'Sample data inserted for testing';
```

---

## 🛠️ Environment Files

### **.env** (Root of Spring Boot project)

```env
# PostgreSQL
POSTGRES_DB=hrms_saas_db
POSTGRES_USER=hrms_user
POSTGRES_PASSWORD=hrms_password

# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin

# Spring Boot
SPRING_PROFILES_ACTIVE=dev
SERVER_PORT=8081
```

---

## 📝 Running the Stack

### **1. Start All Services**

```bash
# Navigate to Spring Boot project root
cd hrms-saas-backend

# Start Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f backend
docker-compose logs -f keycloak
docker-compose logs -f postgres
```

### **2. Check Service Health**

```bash
# PostgreSQL
docker-compose exec postgres pg_isready -U hrms_user

# Keycloak
curl http://localhost:8090/health/ready

# Spring Boot
curl http://localhost:8081/actuator/health
```

### **3. Access Services**

| Service | URL | Credentials |
|---------|-----|-------------|
| Keycloak Admin | http://localhost:8090 | admin / admin |
| Spring Boot | http://localhost:8081 | N/A |
| GraphiQL | http://localhost:8081/graphiql | Requires JWT |
| PostgreSQL | localhost:5432 | hrms_user / hrms_password |
| React App | http://localhost:3000 | N/A |

---

## 🔧 Keycloak Configuration

### **1. Create Realm: hrms-saas**

```bash
# Access Keycloak Admin Console: http://localhost:8090
# Login: admin / admin

# Steps:
1. Click "Create Realm"
2. Name: hrms-saas
3. Enabled: ON
4. Click "Create"
```

### **2. Create Client: hrms-web-app**

```bash
# In hrms-saas realm:

1. Click "Clients" → "Create client"
2. Client ID: hrms-web-app
3. Client Protocol: openid-connect
4. Client authentication: OFF (Public client)
5. Authorization: OFF
6. Click "Next"

7. Valid redirect URIs:
   - http://localhost:3000/*
   - http://192.168.1.6:3000/*
8. Web origins:
   - http://localhost:3000
   - http://192.168.1.6:3000
9. Click "Save"
```

### **3. Create Client Mappers (CRITICAL)**

**Add tenant_id mapper:**
```bash
1. Go to Clients → hrms-web-app → Client scopes → hrms-web-app-dedicated
2. Click "Add mapper" → "By configuration" → "User Attribute"
3. Configure:
   - Name: tenant_id
   - User Attribute: tenant_id
   - Token Claim Name: tenant_id
   - Claim JSON Type: String
   - Add to ID token: ON
   - Add to access token: ON
   - Add to userinfo: ON
4. Click "Save"
```

**Add user_type mapper:**
```bash
1. Add mapper → "User Attribute"
2. Configure:
   - Name: user_type
   - User Attribute: user_type
   - Token Claim Name: user_type
   - Claim JSON Type: String
   - Add to ID token: ON
   - Add to access token: ON
3. Click "Save"
```

**Add company_name mapper:**
```bash
1. Add mapper → "User Attribute"
2. Configure:
   - Name: company_name
   - User Attribute: company_name
   - Token Claim Name: company_name
   - Claim JSON Type: String
   - Add to access token: ON
3. Click "Save"
```

---

## 🧪 Testing the Complete Flow

### **1. Sign Up New Customer (React App)**

```bash
# Open React app: http://localhost:3000
# Click "Create New Account"

# Fill form:
- Company Name: Systech
- First Name: Babu
- Last Name: Ramesh
- Email: babu@systech.com
- Password: Systech@Pass2024!
- Confirm Password: Systech@Pass2024!

# Click "Create Account"
```

### **2. Verify Backend Created Data**

```bash
# Check company_master table
docker-compose exec postgres psql -U hrms_user -d hrms_saas_db -c \
  "SELECT tenant_id, company_name, email, status FROM company_master;"

# Should show:
#  tenant_id    | company_name |      email        |        status
# --------------+--------------+-------------------+-----------------------
#  a3b9c8d2e1f4 | Systech      | babu@systech.com  | PENDING_EMAIL_VERIFICATION
```

### **3. Verify Keycloak User**

```bash
# Login to Keycloak: http://localhost:8090
# Go to: Users → View all users
# Find: babu@systech.com
# Check Attributes:
#   - tenant_id: a3b9c8d2e1f4
#   - user_type: company_admin
#   - company_name: Systech
```

### **4. Verify Email and Login**

```bash
# In Keycloak, manually verify email:
1. Users → babu@systech.com
2. Set "Email verified" to ON
3. Click "Save"

# In React app: http://localhost:3000
1. Click "Sign In with Keycloak"
2. Enter: babu@systech.com / Systech@Pass2024!
3. Should redirect to dashboard
```

### **5. Test GraphQL with JWT**

```bash
# Get JWT token from React app (browser DevTools → Application → Local Storage)
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI..."

# Query current company
curl -X POST http://localhost:8081/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ currentCompany { tenantId companyName email status } }"
  }'

# Response:
# {
#   "data": {
#     "currentCompany": {
#       "tenantId": "a3b9c8d2e1f4",
#       "companyName": "Systech",
#       "email": "babu@systech.com",
#       "status": "ACTIVE"
#     }
#   }
# }
```

---

## 🔍 Troubleshooting

### **1. Keycloak Connection Refused**

```bash
# Check Keycloak is running
docker-compose ps keycloak

# Check Keycloak logs
docker-compose logs keycloak

# Restart Keycloak
docker-compose restart keycloak
```

### **2. PostgreSQL Connection Error**

```bash
# Check PostgreSQL
docker-compose exec postgres pg_isready -U hrms_user

# Check database exists
docker-compose exec postgres psql -U hrms_user -l

# Recreate database
docker-compose down -v
docker-compose up -d
```

### **3. RLS Not Working**

```bash
# Check RLS policies
docker-compose exec postgres psql -U hrms_user -d hrms_saas_db -c \
  "SELECT * FROM pg_policies WHERE tablename = 'employees';"

# Test RLS manually
docker-compose exec postgres psql -U hrms_user -d hrms_saas_db

hrms_saas_db=# SET app.current_tenant = 'a3b9c8d2e1f4';
hrms_saas_db=# SELECT * FROM employees;
```

### **4. JWT Token Missing tenant_id**

```bash
# Check Keycloak user attributes
# Keycloak Admin → Users → babu@systech.com → Attributes

# Check client mappers
# Clients → hrms-web-app → Client scopes → Mappers

# Re-login to get new token
```

---

## 📊 Monitoring & Logs

### **View Logs**

```bash
# All services
docker-compose logs -f

# Specific service with tail
docker-compose logs -f --tail=100 backend

# Filter logs
docker-compose logs backend | grep "ERROR"
```

### **Spring Boot Actuator Endpoints**

```bash
# Health check
curl http://localhost:8081/actuator/health

# Metrics
curl http://localhost:8081/actuator/metrics

# Environment
curl http://localhost:8081/actuator/env
```

---

## 🎯 Production Deployment Checklist

### **Security:**
- [ ] Change default passwords (Keycloak admin, PostgreSQL)
- [ ] Enable HTTPS/TLS
- [ ] Configure proper CORS origins
- [ ] Set up firewall rules
- [ ] Use secrets management (AWS Secrets Manager, HashiCorp Vault)
- [ ] Enable Keycloak security features (bruteforce protection)

### **Database:**
- [ ] Set up PostgreSQL replication
- [ ] Configure automated backups
- [ ] Optimize PostgreSQL configuration
- [ ] Set up monitoring (Prometheus, Grafana)
- [ ] Review and optimize RLS policies

### **Application:**
- [ ] Set SPRING_PROFILES_ACTIVE=prod
- [ ] Configure proper logging levels
- [ ] Set up log aggregation (ELK, CloudWatch)
- [ ] Configure connection pooling
- [ ] Enable production GraphQL introspection settings
- [ ] Set up health checks and readiness probes

### **Keycloak:**
- [ ] Configure production database (not H2)
- [ ] Set up Keycloak clustering (if needed)
- [ ] Configure email provider (SMTP)
- [ ] Set up user session limits
- [ ] Configure password policies
- [ ] Enable two-factor authentication

---

## 📚 Additional Resources

- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Spring GraphQL Documentation](https://docs.spring.io/spring-graphql/docs/current/reference/html/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [PostgreSQL RLS Documentation](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

## 🎉 Summary

You now have complete documentation for:

1. ✅ **Architecture** - Multi-tenant design with NanoID
2. ✅ **Database** - PostgreSQL with RLS policies
3. ✅ **Security** - Keycloak OAuth2/JWT integration
4. ✅ **REST API** - Sign-up and authentication endpoints
5. ✅ **GraphQL** - Business operations API
6. ✅ **Docker** - Complete local development setup
7. ✅ **Testing** - End-to-end testing guide

**Your Spring Boot developer can now:**
- Set up the entire stack with `docker-compose up`
- Implement REST endpoints for authentication
- Implement GraphQL resolvers for business logic
- Test with the React frontend
- Deploy to production

**Generated Password for Testing:**
```
Email: babu@systech.com
Password: Systech@Pass2024!
Tenant ID: (auto-generated 12-char NanoID)
```

Good luck with your HRMS SaaS platform! 🚀
