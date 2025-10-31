# HRMS SaaS - Spring Boot Documentation Index

## 📚 Complete Documentation for Spring Boot Developers

This folder contains comprehensive documentation for implementing the HRMS SaaS backend using Spring Boot, GraphQL, Keycloak, and PostgreSQL.

---

## 📖 Documentation Files

### **Setup & Configuration**

### **1. [SPRINGBOOT_QUICK_START.md](./SPRINGBOOT_QUICK_START.md)** ⭐ START HERE
**5-minute quick start guide**
- Prerequisites and setup
- Quick infrastructure start
- Test sign-up flow
- Common issues and troubleshooting
- Key endpoints and concepts

**Best for:** Getting up and running quickly

---

### **2. [EMAIL_SETUP_CHECKLIST.md](./EMAIL_SETUP_CHECKLIST.md)** 📧 REQUIRED FOR EMAIL
**5-minute email setup guide**
- Gmail App Password generation
- Keycloak SMTP configuration
- Test email verification
- Common issues and solutions

**Best for:** Quick email verification setup

---

### **3. [EMAIL_SETUP_GUIDE.md](./EMAIL_SETUP_GUIDE.md)** 📧 DETAILED EMAIL GUIDE
**Complete email configuration documentation**
- Gmail, SendGrid, Mailgun, AWS SES setup
- Production considerations
- Email templates customization
- Troubleshooting guide
- Security best practices

**Best for:** Production email setup and troubleshooting

---

### **Architecture & Design**

---

### **4. [SPRINGBOOT_ARCHITECTURE.md](./SPRINGBOOT_ARCHITECTURE.md)**
**System architecture and design**
- High-level architecture diagrams
- Multi-tenant design with NanoID
- Authentication and authorization flow
- Database schema with RLS policies
- Security concepts
- Project structure
- Maven dependencies

**Best for:** Understanding the overall system design

---

### **3. [SPRINGBOOT_IMPLEMENTATION_GUIDE.md](./SPRINGBOOT_IMPLEMENTATION_GUIDE.md)**
**Configuration and core implementation**
- application.yml configuration
- Security configuration (JWT, OAuth2)
- Tenant context management
- NanoID generator
- Entity classes (JPA)
- Repository layer
- Filter implementations

**Best for:** Implementing core backend features

---

### **4. [SPRINGBOOT_REST_API.md](./SPRINGBOOT_REST_API.md)**
**REST API for authentication**
- Sign-up endpoint implementation
- Email verification
- DTOs (Data Transfer Objects)
- Controller layer
- Service layer with rollback strategy
- Keycloak Admin API integration
- Exception handling
- Global error handler

**Best for:** Implementing user signup and authentication

---

### **5. [SPRINGBOOT_GRAPHQL.md](./SPRINGBOOT_GRAPHQL.md)**
**GraphQL API for business operations**
- Complete GraphQL schema
- Query resolvers (employees, departments, company)
- Mutation resolvers (create, update, delete)
- Service layer implementation
- GraphQL security
- Error handling
- Testing with GraphiQL
- Example queries and mutations

**Best for:** Implementing business logic with GraphQL

---

### **6. [SPRINGBOOT_DOCKER_DEPLOYMENT.md](./SPRINGBOOT_DOCKER_DEPLOYMENT.md)**
**Docker Compose and deployment**
- Complete docker-compose.yml
- Dockerfile for Spring Boot
- Database initialization scripts
- Environment configuration
- Keycloak configuration steps
- Complete testing workflow
- Troubleshooting guide
- Production deployment checklist
- Monitoring and logging

**Best for:** Local development setup and deployment

---

## 🎯 Quick Navigation

### **I'm new to the project:**
1. Start with [SPRINGBOOT_QUICK_START.md](./SPRINGBOOT_QUICK_START.md)
2. Read [SPRINGBOOT_ARCHITECTURE.md](./SPRINGBOOT_ARCHITECTURE.md)
3. Set up environment using [SPRINGBOOT_DOCKER_DEPLOYMENT.md](./SPRINGBOOT_DOCKER_DEPLOYMENT.md)

### **I need to implement signup:**
1. Read [SPRINGBOOT_REST_API.md](./SPRINGBOOT_REST_API.md)
2. Check [SPRINGBOOT_IMPLEMENTATION_GUIDE.md](./SPRINGBOOT_IMPLEMENTATION_GUIDE.md) for config

### **I need to implement business logic:**
1. Read [SPRINGBOOT_GRAPHQL.md](./SPRINGBOOT_GRAPHQL.md)
2. Review entity/service patterns in [SPRINGBOOT_IMPLEMENTATION_GUIDE.md](./SPRINGBOOT_IMPLEMENTATION_GUIDE.md)

### **I need to deploy:**
1. Follow [SPRINGBOOT_DOCKER_DEPLOYMENT.md](./SPRINGBOOT_DOCKER_DEPLOYMENT.md)

---

## 🔑 Key Technologies

- **Spring Boot 3.2.1** - Application framework
- **Spring Security** - OAuth2 Resource Server
- **Spring GraphQL** - GraphQL API
- **Spring Data JPA** - Database access
- **PostgreSQL 16** - Database with Row-Level Security
- **Keycloak 23** - Identity and Access Management
- **Flyway** - Database migrations
- **NanoID** - Tenant ID generation
- **Docker Compose** - Local development
- **Maven** - Build tool

---

## 📊 Architecture Summary

```
┌─────────────┐
│  React App  │ (Port 3000)
└──────┬──────┘
       │ REST (Auth) + GraphQL (Business)
       ▼
┌─────────────────────┐
│  Spring Boot API    │ (Port 8081)
│  - REST: /api/v1/*  │
│  - GraphQL: /graphql│
└──────┬──────┬───────┘
       │      │
       ▼      ▼
┌──────────┐ ┌──────────┐
│ Keycloak │ │PostgreSQL│
│(Port 8090)│ │(Port 5432)│
└──────────┘ └──────────┘
```

---

## 🎯 Core Concepts

### **Multi-Tenancy with NanoID**
- Each company is a tenant
- Tenant identified by 12-char NanoID (e.g., `a3b9c8d2e1f4`)
- Stored in PostgreSQL and Keycloak
- Used for Row-Level Security (RLS)

### **Authentication Flow**
1. User signs up via React app
2. Spring Boot generates NanoID tenant_id
3. Creates company in PostgreSQL
4. Creates user in Keycloak with tenant_id attribute
5. User logs in via Keycloak
6. Receives JWT with tenant_id claim
7. All requests filtered by RLS using tenant_id

### **Security Layers**
1. **Spring Security** - JWT validation
2. **TenantFilter** - Extract tenant_id from JWT
3. **PostgreSQL RLS** - Row-level data isolation
4. **Keycloak** - User authentication and authorization

---

## 📝 Key Files to Implement

### **Essential Configuration:**
```
src/main/resources/
├── application.yml              # Main config
├── db/migration/
│   ├── V1__create_company_master.sql
│   ├── V2__create_employees.sql
│   └── V5__enable_rls.sql
└── graphql/
    └── schema.graphqls          # GraphQL schema
```

### **Essential Java Classes:**
```
src/main/java/com/systech/hrms/
├── config/
│   ├── SecurityConfig.java      # JWT & OAuth2
│   └── GraphQLConfig.java
├── security/
│   ├── TenantContext.java       # ThreadLocal tenant storage
│   └── TenantFilter.java        # Extract tenant from JWT
├── controller/auth/
│   └── SignUpController.java    # POST /api/v1/auth/signup
├── service/
│   ├── SignUpService.java       # Signup business logic
│   └── KeycloakAdminService.java# Keycloak integration
├── graphql/resolver/
│   ├── EmployeeQueryResolver.java
│   └── EmployeeMutationResolver.java
└── util/
    └── NanoIdGenerator.java     # Generate tenant IDs
```

---

## 🔗 Testing Credentials

### **From React App Testing:**
```
Email: babu@systech.com
Password: Systech@Pass2024!
Tenant ID: (auto-generated, e.g., a3b9c8d2e1f4)
```

### **Keycloak Admin:**
```
URL: http://localhost:8090
Username: admin
Password: admin
```

### **PostgreSQL:**
```
Host: localhost:5432
Database: hrms_saas_db
Username: hrms_user
Password: hrms_password
```

---

## 🐛 Common Issues

### **Keycloak Not Starting**
```bash
docker-compose logs keycloak
docker-compose restart keycloak
```

### **JWT Missing tenant_id**
- Check Keycloak user attributes
- Check client mappers in hrms-web-app
- Verify mapper names match exactly: `tenant_id`, `user_type`

### **RLS Not Filtering Data**
```sql
-- Check RLS is enabled
\d+ employees
-- Should show: "Row security enabled"

-- Check policy exists
SELECT * FROM pg_policies WHERE tablename = 'employees';
```

### **Build Fails**
```bash
mvn clean install
# Check Java version: java -version (should be 17+)
```

---

## 📞 Support Resources

- **Spring Boot Docs:** https://docs.spring.io/spring-boot/
- **Spring GraphQL:** https://docs.spring.io/spring-graphql/
- **Keycloak Docs:** https://www.keycloak.org/documentation
- **PostgreSQL RLS:** https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- **NanoID:** https://github.com/aventrix/jnanoid

---

## ✅ Implementation Checklist

### **Phase 1: Setup (Day 1)**
- [ ] Review all documentation
- [ ] Set up development environment
- [ ] Start Docker services (postgres, keycloak)
- [ ] Configure Keycloak realm and client
- [ ] Create Spring Boot project structure
- [ ] Configure application.yml
- [ ] Run Flyway migrations

### **Phase 2: Core Features (Day 2-3)**
- [ ] Implement SecurityConfig
- [ ] Implement TenantFilter and TenantContext
- [ ] Implement NanoIdGenerator
- [ ] Create entity classes
- [ ] Create repository interfaces
- [ ] Implement KeycloakAdminService

### **Phase 3: REST API (Day 4)**
- [ ] Implement SignUpController
- [ ] Implement SignUpService
- [ ] Test signup flow end-to-end
- [ ] Verify tenant_id in JWT
- [ ] Test RLS with multiple tenants

### **Phase 4: GraphQL (Day 5-6)**
- [ ] Define GraphQL schema
- [ ] Implement query resolvers
- [ ] Implement mutation resolvers
- [ ] Test with GraphiQL
- [ ] Integrate with React app

### **Phase 5: Testing & Polish (Day 7)**
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Test multi-tenant isolation
- [ ] Documentation review
- [ ] Production deployment prep

---

## 🎉 You're Ready!

All documentation is complete and ready for your Spring Boot developer. The architecture is designed for:

✅ **Multi-tenancy** - Complete data isolation
✅ **Security** - Keycloak OAuth2/JWT + PostgreSQL RLS
✅ **Scalability** - Microservices-ready architecture
✅ **Developer Experience** - Clear docs, quick setup
✅ **Production Ready** - Docker, monitoring, logging

**Start with:** [SPRINGBOOT_QUICK_START.md](./SPRINGBOOT_QUICK_START.md)

Good luck! 🚀
