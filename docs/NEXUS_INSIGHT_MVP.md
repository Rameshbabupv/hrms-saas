# NEXUS Insight - Observability & Admin Portal
## SaaS HRMS MVP - Monitoring & Management Platform

**Document Version:** 1.0
**Date:** 2025-10-29
**Platform Name:** NEXUS Insight
**Target:** Simple, practical MVP for launch

---

## 🎯 What is NEXUS Insight?

**NEXUS Insight** is the admin and observability portal for NEXUS HRMS SaaS platform. It provides:
- Platform team: Monitor all tenants, system health, support tools
- Tenant admins: View their own logs, performance, compliance reports
- Simple, focused, gets the job done

---

## 🏗️ Architecture (Simple!)

```
┌─────────────────────────────────────────────────────┐
│           NEXUS HRMS (Main App)                     │
│       React + Spring Boot + PostgreSQL              │
└─────────────────────────────────────────────────────┘
                        │
                        │ Same database
                        ▼
┌─────────────────────────────────────────────────────┐
│         NEXUS Insight (Admin Portal)                │
│       React + Spring Boot + PostgreSQL              │
│            + Grafana (embedded)                     │
└─────────────────────────────────────────────────────┘
```

**Key Decisions:**
- ✅ Separate React app (different domain: `admin.nexus-hrms.com`)
- ✅ Separate Spring Boot service (different port)
- ✅ **Same PostgreSQL database** (queries audit tables directly)
- ✅ Separate Keycloak realm (`nexus-insight-realm`)
- ✅ Grafana for system metrics (open-source, self-hosted)

---

## 👥 MVP Roles (Keep it Simple)

### **Role 1: Platform Admin (Your Team)**
**Access:**
- ✅ View all tenants
- ✅ System health dashboard (Grafana)
- ✅ All audit logs (across tenants)
- ✅ Impersonate any tenant (with audit trail)
- ✅ Security events (all tenants)

**Use Cases:**
- Monitor system uptime
- Troubleshoot customer issues
- Investigate security incidents
- Generate compliance reports

---

### **Role 2: Tenant Admin (Customer HR/IT Admin)**
**Access:**
- ✅ Own tenant only (enforced by RLS)
- ✅ Audit logs (own company)
- ✅ User activity logs
- ✅ Security events (own company)
- ✅ Export compliance reports

**Use Cases:**
- See who changed employee data
- GDPR compliance reporting
- Investigate failed logins
- Download audit logs for compliance

---

### **Role 3: End User (Future - Phase 2)**
**Access:**
- ✅ Own activity only
- ✅ Download own data (GDPR)

**Use Cases:**
- See my login history
- Export my personal data

---

## 📊 MVP Features (Minimal, Focused)

### **Module 1: Dashboard (Platform Admin Only)**

```
┌─────────────────────────────────────────────────────┐
│  NEXUS Insight - System Overview                    │
├─────────────────────────────────────────────────────┤
│  ✅ System Status: HEALTHY                          │
│  👥 Active Tenants: 45                              │
│  📊 Total Employees: 12,450                         │
│  🚀 API Requests (24h): 1.2M                        │
│                                                      │
│  [View Tenants] [System Metrics] [Audit Logs]      │
└─────────────────────────────────────────────────────┘
```

**Implementation:** Simple React dashboard with Material-UI cards

---

### **Module 2: Tenant List (Platform Admin Only)**

```
┌─────────────────────────────────────────────────────┐
│  Tenants                                  [+ Add]    │
├─────────────────────────────────────────────────────┤
│  🟢 ABC Corp          245 employees    ACTIVE       │
│     Created: 2025-01-15    [View Logs] [Impersonate]│
│                                                      │
│  🟢 XYZ Industries    580 employees    ACTIVE       │
│     Created: 2025-03-20    [View Logs] [Impersonate]│
│                                                      │
│  🔴 Test Company      5 employees      SUSPENDED    │
│     Created: 2025-10-01    [View Logs] [Reactivate] │
└─────────────────────────────────────────────────────┘
```

**Data Source:** Query `company` table, show counts from `employee` table

---

### **Module 3: Audit Log Viewer (Both Roles)**

```
┌─────────────────────────────────────────────────────┐
│  Audit Logs - Filters: [Date] [User] [Table] [Action]│
├─────────────────────────────────────────────────────┤
│  2025-10-29 14:30:25  john.doe@abc.com              │
│  UPDATE employee (ID: 123e4567...)                  │
│  Changed: salary                                     │
│  Old: $50,000 → New: $55,000                        │
│  [View Details]                                      │
├─────────────────────────────────────────────────────┤
│  2025-10-29 14:25:10  jane.smith@abc.com            │
│  INSERT employee (ID: 234f5678...)                  │
│  Created new employee: Alice Johnson                │
│  [View Details]                                      │
└─────────────────────────────────────────────────────┘
```

**Data Source:** Query `audit_log` table
**RLS:** Tenant Admin sees only `WHERE company_id = :currentTenantId`

---

### **Module 4: User Activity (Both Roles)**

```
┌─────────────────────────────────────────────────────┐
│  User Activity - Last 30 Days                       │
├─────────────────────────────────────────────────────┤
│  Username          Last Login      Total Logins  Status│
│  john.doe          2025-10-29      145         ✅ Active│
│  jane.smith        2025-10-29      89          ✅ Active│
│  bob.jones         2025-10-15      12          ⚠️ Inactive│
└─────────────────────────────────────────────────────┘
```

**Data Source:** Query `user_activity_log` table

---

### **Module 5: Security Events (Both Roles)**

```
┌─────────────────────────────────────────────────────┐
│  Security Events - Last 7 Days                      │
├─────────────────────────────────────────────────────┤
│  🔴 CRITICAL  2025-10-29 10:30                      │
│  RLS Violation Attempt - user: unknown@test.com    │
│  Action: BLOCKED                                    │
│  [View Details]                                      │
├─────────────────────────────────────────────────────┤
│  🟡 WARNING   2025-10-28 15:45                      │
│  5 Failed Login Attempts - user: john.doe          │
│  Action: Account temporarily locked                │
│  [View Details]                                      │
└─────────────────────────────────────────────────────┘
```

**Data Source:** Query `security_event_log` table

---

### **Module 6: System Metrics (Platform Admin Only - Grafana)**

```
Embed Grafana dashboards for:
- CPU/Memory/Disk usage
- Database connection pool
- API response times
- Error rates
```

**Implementation:**
- Grafana running on `localhost:3000`
- Spring Boot exposes `/actuator/prometheus`
- Prometheus scrapes metrics
- Grafana visualizes

---

## 🔐 Access Control (Keycloak Configuration)

### **Keycloak Realm: `nexus-insight-realm`**

**Roles:**
```
1. platform-admin    (Your DevOps/Support team)
2. tenant-admin      (Customer HR/IT admins)
```

**User Attributes (JWT Claims):**
```json
{
  "sub": "user-uuid",
  "email": "admin@abc.com",
  "company_id": "550e8400-e29b-41d4-a716-446655440000",
  "roles": ["tenant-admin"],
  "tenant_name": "ABC Corp"
}
```

**RLS Enforcement in Spring Boot:**
```java
// TenantContextFilter.java
String role = jwt.getClaim("roles");
String companyId = jwt.getClaim("company_id");

if (role.contains("platform-admin")) {
    // No RLS filter - see all tenants
} else if (role.contains("tenant-admin")) {
    // Set RLS: SELECT set_current_tenant(companyId)
    jdbcTemplate.execute("SELECT set_current_tenant('" + companyId + "')");
}
```

---

## 🗄️ Database Schema (Already Done!)

**Tables Used:**
- `audit_log` - General audit logs
- `user_activity_log` - Login/logout tracking
- `security_event_log` - Security incidents
- `api_audit_log` - API performance (future)
- `compliance_audit_trail` - GDPR tracking (future)
- `company` - Tenant list
- `employee` - Employee counts

**All tables already have RLS policies from `saas_mvp_audit_schema.sql`**

---

## 🚀 MVP Implementation Plan (2-3 Weeks)

### **Week 1: Backend Setup**
```
✅ Day 1-2: Spring Boot Admin Service
   - New Spring Boot project: nexus-insight-service
   - PostgreSQL connection (reuse same database)
   - Keycloak integration (nexus-insight-realm)
   - RLS filter implementation

✅ Day 3-4: GraphQL/REST APIs
   - GET /tenants (platform admin only)
   - GET /audit-logs?filters
   - GET /user-activity?filters
   - GET /security-events?filters
   - POST /impersonate/:tenantId (platform admin only)

✅ Day 5: Testing
   - Unit tests for RLS enforcement
   - Integration tests for APIs
```

---

### **Week 2: Frontend Development**
```
✅ Day 1-2: React App Setup
   - Create React 18 app (Vite)
   - Material-UI v5
   - Keycloak integration (@react-keycloak/web)
   - Apollo Client for GraphQL

✅ Day 3-4: Pages
   - Dashboard page (platform admin)
   - Tenant list page (platform admin)
   - Audit log viewer (both roles)
   - User activity page (both roles)
   - Security events page (both roles)

✅ Day 5: Styling & UX
   - Dark mode support
   - Responsive design
   - Loading states
```

---

### **Week 3: Observability & Deployment**
```
✅ Day 1-2: Grafana Setup
   - Install Grafana (Docker/Podman)
   - Configure Prometheus
   - Create basic dashboards (CPU, memory, API latency)
   - Embed Grafana in React app (iframe)

✅ Day 3: Security Audit
   - Test RLS policies
   - Test impersonation audit trail
   - Verify JWT validation

✅ Day 4-5: Deployment
   - Podman containers for:
     - nexus-insight-frontend (React, Nginx)
     - nexus-insight-backend (Spring Boot)
     - Grafana + Prometheus
   - DNS: admin.nexus-hrms.com
   - SSL certificates
   - Load testing
```

---

## 📁 Project Structure

```
nexus-backend/
├── nexus-insight-service/          # NEW - Admin service
│   ├── src/main/java/
│   │   └── com/nexus/insight/
│   │       ├── controller/
│   │       │   ├── TenantController.java
│   │       │   ├── AuditLogController.java
│   │       │   └── UserActivityController.java
│   │       ├── service/
│   │       ├── repository/
│   │       ├── security/
│   │       │   ├── TenantContextFilter.java
│   │       │   └── KeycloakConfig.java
│   │       └── InsightApplication.java
│   ├── pom.xml
│   └── application.yml

nexus-frontend/
├── nexus-insight-portal/           # NEW - Admin portal
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Dashboard.tsx
│   │   │   ├── TenantList.tsx
│   │   │   ├── AuditLogs.tsx
│   │   │   ├── UserActivity.tsx
│   │   │   └── SecurityEvents.tsx
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   └── App.tsx
│   ├── package.json
│   └── vite.config.ts
```

---

## 🛠️ Tech Stack (MVP)

### **Frontend**
- React 18.3+
- Material-UI v5 (same as main NEXUS app)
- Apollo Client (GraphQL)
- @react-keycloak/web (SSO)
- Recharts (simple charts)

### **Backend**
- Spring Boot 3.2+
- Spring Data JPA
- GraphQL Java
- Keycloak Spring Security
- PostgreSQL JDBC

### **Observability**
- Grafana 10+ (self-hosted)
- Prometheus 2.45+
- Spring Boot Actuator

### **Infrastructure**
- Podman (containerization)
- Nginx (reverse proxy)
- Let's Encrypt (SSL)

---

## 🔒 Security Checklist

- [ ] Separate Keycloak realm for admin portal
- [ ] RLS policies tested and enforced
- [ ] Impersonation actions logged to `admin_activity_log` (create this table)
- [ ] JWT token validation on every request
- [ ] HTTPS only (no HTTP)
- [ ] CORS configured (only admin.nexus-hrms.com)
- [ ] Rate limiting on sensitive endpoints
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitize inputs)

---

## 📈 Future Enhancements (Post-MVP)

### **Phase 2: Advanced Features (Month 2-3)**
- Alerting (Slack, email notifications)
- API performance tracking (api_audit_log)
- Tenant resource usage dashboard
- Automated compliance reports (scheduled)
- End user "My Activity" page

### **Phase 3: Enterprise Features (Month 4-6)**
- Distributed tracing (Tempo/Jaeger)
- Log aggregation (Loki/ELK)
- Anomaly detection (ML-based)
- Cost analytics per tenant
- Multi-region support

---

## 💡 Key Principles

1. **Simple First:** Query PostgreSQL directly, no complex data pipelines
2. **Reuse Infrastructure:** Same database, same deployment process
3. **Security by Default:** RLS enforced, every action audited
4. **Grafana for Metrics:** Don't reinvent the wheel
5. **Separate Deployment:** Admin portal isolated from main app

---

## 📝 Next Steps

1. **Week 1:** Create Spring Boot `nexus-insight-service`
2. **Week 2:** Create React `nexus-insight-portal`
3. **Week 3:** Setup Grafana + Deploy

---

## 📚 Related Documents

- `saas_mvp_audit_schema.sql` - Audit tables (already created)
- `DBA_NOTES.md` - Database setup guide
- `KEYCLOAK_NOTES.md` - Keycloak configuration
- `SPRINGBOOT_NOTES.md` - Backend development guide
- `REACTAPP_NOTES.md` - Frontend development guide

---

**Ready to build? Let's start with Spring Boot backend skeleton! 🚀**
