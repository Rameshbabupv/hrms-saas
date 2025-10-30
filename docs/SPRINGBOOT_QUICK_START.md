# HRMS SaaS - Spring Boot Quick Start Guide

## 🚀 5-Minute Setup Guide

This is a quick reference for getting started. For detailed documentation, see the other guides.

---

## 📋 Prerequisites

```bash
# Required
- Java 17 or higher
- Maven 3.9+
- Docker & Docker Compose
- Git

# Check versions
java -version
mvn -version
docker --version
docker-compose --version
```

---

## ⚡ Quick Start

### **1. Start Infrastructure (2 minutes)**

```bash
# Clone repository (if not already done)
git clone <repository-url>
cd hrms-saas-backend

# Start PostgreSQL and Keycloak
docker-compose up -d postgres keycloak

# Wait for services to be healthy (check logs)
docker-compose logs -f keycloak
# Wait for: "Keycloak started"
```

### **2. Configure Keycloak (2 minutes)**

```bash
# Access Keycloak: http://localhost:8090
# Login: admin / admin

# Create Realm "hrms-saas"
# Create Client "hrms-web-app" (public client)
# Add redirect URIs: http://localhost:3000/*

# Add Client Mappers:
# - tenant_id (User Attribute → tenant_id)
# - user_type (User Attribute → user_type)
# - company_name (User Attribute → company_name)
```

### **3. Start Spring Boot (1 minute)**

```bash
# Option A: Run with Maven
mvn clean spring-boot:run

# Option B: Build and run JAR
mvn clean package -DskipTests
java -jar target/hrms-saas-backend-1.0.0-SNAPSHOT.jar

# Option C: Docker
docker-compose up -d backend
```

### **4. Verify Setup**

```bash
# Check Spring Boot health
curl http://localhost:8081/actuator/health

# Expected:
# {"status":"UP"}

# Check GraphiQL
# Open: http://localhost:8081/graphiql
```

---

## 🧪 Test Sign-Up Flow

### **1. Start React App**

```bash
cd ../reactapp
npm install
npm start

# Opens: http://localhost:3000
```

### **2. Create Account**

```
1. Click "Create New Account"
2. Fill form:
   - Company: Systech
   - Name: Babu Ramesh
   - Email: babu@systech.com
   - Password: Systech@Pass2024!
3. Click "Create Account"
4. Check console logs for tenant_id (e.g., a3b9c8d2e1f4)
```

### **3. Verify in Database**

```bash
docker-compose exec postgres psql -U hrms_user -d hrms_saas_db

# Check company created
SELECT tenant_id, company_name, email, status FROM company_master;

# Exit
\q
```

### **4. Manually Verify Email in Keycloak**

```
1. Go to: http://localhost:8090
2. Users → babu@systech.com
3. Set "Email verified" = ON
4. Save
```

### **5. Login and Test**

```
1. React app: http://localhost:3000
2. Click "Sign In with Keycloak"
3. Login: babu@systech.com / Systech@Pass2024!
4. Should see dashboard
```

---

## 📝 Key Endpoints

### **REST API (Public)**
```bash
POST http://localhost:8081/api/v1/auth/signup
POST http://localhost:8081/api/v1/auth/resend-verification
GET  http://localhost:8081/api/v1/auth/check-email?email=test@example.com
```

### **GraphQL (Protected)**
```bash
POST http://localhost:8081/graphql
Headers: Authorization: Bearer <JWT_TOKEN>

Query Example:
{
  "query": "{ currentCompany { tenantId companyName email } }"
}
```

---

## 🔑 Key Concepts

### **Tenant ID (NanoID)**
```
Format: 12-character lowercase alphanumeric
Example: a3b9c8d2e1f4

Used for:
- Database primary key (company_master.tenant_id)
- PostgreSQL RLS (Row-Level Security)
- JWT token claim
- Multi-tenant isolation
```

### **JWT Token Claims**
```json
{
  "tenant_id": "a3b9c8d2e1f4",
  "user_type": "company_admin",
  "company_name": "Systech",
  "email": "babu@systech.com"
}
```

### **Request Flow**
```
1. React sends GraphQL query with JWT
2. Spring Security validates JWT
3. TenantFilter extracts tenant_id
4. Sets PostgreSQL: SET app.current_tenant = 'a3b9c8d2e1f4'
5. RLS policy filters query results
6. Returns only tenant's data
```

---

## 🐛 Common Issues

### **Issue: Keycloak Connection Refused**
```bash
# Check Keycloak is running
docker-compose ps keycloak

# Restart
docker-compose restart keycloak
```

### **Issue: JWT Missing tenant_id**
```bash
# Check user attributes in Keycloak
# Users → babu@systech.com → Attributes
# Should have: tenant_id = a3b9c8d2e1f4

# Check client mappers
# Clients → hrms-web-app → Client scopes → Mappers
# Should have: tenant_id mapper
```

### **Issue: RLS Not Working**
```bash
# Check RLS is enabled
docker-compose exec postgres psql -U hrms_user -d hrms_saas_db
\d+ employees
# Should show: "Row security enabled"

# Check policy exists
SELECT * FROM pg_policies WHERE tablename = 'employees';
```

### **Issue: Build Fails**
```bash
# Clean Maven cache
mvn clean
rm -rf ~/.m2/repository

# Rebuild
mvn clean install
```

---

## 📁 Project Structure

```
hrms-saas-backend/
├── src/main/java/com/systech/hrms/
│   ├── config/           # Security, GraphQL, DB config
│   ├── controller/       # REST controllers
│   ├── graphql/          # GraphQL resolvers
│   ├── service/          # Business logic
│   ├── repository/       # JPA repositories
│   ├── entity/           # JPA entities
│   ├── dto/              # Data transfer objects
│   ├── security/         # Tenant filter, context
│   ├── exception/        # Custom exceptions
│   └── util/             # NanoID generator
│
├── src/main/resources/
│   ├── application.yml
│   ├── db/migration/     # Flyway SQL scripts
│   └── graphql/
│       └── schema.graphqls
│
├── docker-compose.yml
├── Dockerfile
└── pom.xml
```

---

## 🎯 Next Steps

1. **Read Full Documentation:**
   - `SPRINGBOOT_ARCHITECTURE.md` - Architecture overview
   - `SPRINGBOOT_IMPLEMENTATION_GUIDE.md` - Code examples
   - `SPRINGBOOT_REST_API.md` - REST API details
   - `SPRINGBOOT_GRAPHQL.md` - GraphQL implementation
   - `SPRINGBOOT_DOCKER_DEPLOYMENT.md` - Deployment guide

2. **Implement Business Logic:**
   - Create Department service
   - Create User service
   - Add more GraphQL resolvers
   - Implement business rules

3. **Add Features:**
   - Email service (SMTP)
   - File upload (S3, local storage)
   - Reporting (Jasper, PDFBox)
   - Notifications (WebSocket, SSE)

4. **Testing:**
   - Unit tests (JUnit, Mockito)
   - Integration tests (Testcontainers)
   - GraphQL tests
   - End-to-end tests

5. **Production:**
   - Configure CI/CD
   - Set up monitoring
   - Configure logging
   - Security hardening

---

## 📚 Documentation Index

| Document | Description |
|----------|-------------|
| `SPRINGBOOT_ARCHITECTURE.md` | High-level architecture, database schema, security |
| `SPRINGBOOT_IMPLEMENTATION_GUIDE.md` | Config files, entities, repositories, services |
| `SPRINGBOOT_REST_API.md` | REST endpoints, DTOs, exception handling |
| `SPRINGBOOT_GRAPHQL.md` | GraphQL schema, resolvers, queries, mutations |
| `SPRINGBOOT_DOCKER_DEPLOYMENT.md` | Docker Compose, Keycloak setup, testing |
| `SPRINGBOOT_QUICK_START.md` | This file - quick reference |

---

## 🔗 Important URLs

| Service | URL | Purpose |
|---------|-----|---------|
| React App | http://localhost:3000 | Frontend |
| Spring Boot | http://localhost:8081 | Backend API |
| GraphiQL | http://localhost:8081/graphiql | GraphQL playground |
| Keycloak | http://localhost:8090 | Auth server |
| PostgreSQL | localhost:5432 | Database |

---

## 📞 Support

For issues or questions:
1. Check troubleshooting sections in docs
2. Review Docker Compose logs
3. Check Spring Boot logs
4. Verify Keycloak configuration

---

## ✅ Checklist

**Initial Setup:**
- [ ] Java 17+ installed
- [ ] Maven installed
- [ ] Docker installed
- [ ] PostgreSQL running (docker-compose)
- [ ] Keycloak running (docker-compose)
- [ ] Keycloak realm created (hrms-saas)
- [ ] Keycloak client created (hrms-web-app)
- [ ] Client mappers configured (tenant_id, user_type)

**Development:**
- [ ] Spring Boot starts without errors
- [ ] Flyway migrations run successfully
- [ ] Can access GraphiQL
- [ ] React app connects to backend
- [ ] Sign-up creates company and user
- [ ] Login redirects to Keycloak
- [ ] JWT contains tenant_id
- [ ] GraphQL queries work with JWT
- [ ] RLS filters data correctly

**Ready for Development!** 🎉
