# Domain Validation - DBA Guide

## Database Schema

### Table: `domain_master`
**Purpose:** Registry of email domains and their ownership status

```sql
CREATE TABLE domain_master (
    domain VARCHAR(255) PRIMARY KEY,
    is_public BOOLEAN NOT NULL DEFAULT false,
    is_locked BOOLEAN NOT NULL DEFAULT false,
    registered_tenant_id VARCHAR(21),
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),

    CONSTRAINT domain_lowercase CHECK (domain = LOWER(domain)),
    CONSTRAINT fk_domain_tenant FOREIGN KEY (registered_tenant_id)
        REFERENCES company_master(tenant_id) ON DELETE SET NULL
);
```

**Columns:**
- `domain` (PK): Email domain in lowercase (e.g., 'systech.com')
- `is_public`: `true` for gmail.com, yahoo.com (allows multiple tenants)
- `is_locked`: `true` when domain is registered to a tenant
- `registered_tenant_id`: Which tenant owns this domain (NULL for public domains)
- `created_at`: When domain was first registered
- `updated_at`: Last modification timestamp

**Indexes:**
```sql
CREATE INDEX idx_domain_public ON domain_master(is_public);
CREATE INDEX idx_domain_locked ON domain_master(is_locked);
CREATE INDEX idx_domain_tenant ON domain_master(registered_tenant_id);
```

### Table: `company_master` (Updated)
**New Column:**
```sql
ALTER TABLE company_master
    ADD COLUMN domain VARCHAR(255) NOT NULL,
    ADD CONSTRAINT fk_company_domain
        FOREIGN KEY (domain) REFERENCES domain_master(domain);

CREATE INDEX idx_company_domain ON company_master(domain);
```

## Data Relationships

```
domain_master (1) ←→ (N) company_master
    ↑
    | (for corporate domains: 1-to-1)
    | (for public domains: 1-to-N)
```

**Example:**
```sql
-- Public domain: Multiple companies allowed
domain_master: { domain: 'gmail.com', is_public: true, is_locked: false }
company_master: { tenant_id: 'abc123', domain: 'gmail.com' }
company_master: { tenant_id: 'def456', domain: 'gmail.com' }  ✓ OK

-- Corporate domain: Single company only
domain_master: { domain: 'systech.com', is_public: false, is_locked: true, registered_tenant_id: 'xyz789' }
company_master: { tenant_id: 'xyz789', domain: 'systech.com' }
company_master: { tenant_id: 'aaa111', domain: 'systech.com' }  ✗ BLOCKED
```

## Pre-Populated Data

**Public Domains:**
```sql
INSERT INTO domain_master (domain, is_public, is_locked) VALUES
    ('gmail.com', true, false),
    ('yahoo.com', true, false),
    ('outlook.com', true, false),
    ('hotmail.com', true, false),
    ('icloud.com', true, false),
    ('protonmail.com', true, false),
    ('aol.com', true, false),
    ('zoho.com', true, false),
    ('mail.com', true, false),
    ('yandex.com', true, false);
```

## Migration History

**V2__add_domain_master.sql:**
1. Create `domain_master` table
2. Add `domain` column to `company_master`
3. Extract domains from existing emails
4. Pre-populate public domains
5. Insert existing corporate domains
6. Add foreign key constraint
7. Create indexes

**Migration Order is Critical:**
- Public domains inserted FIRST
- Then existing company domains
- FK constraint added LAST

## Common Queries

### Check Domain Availability
```sql
SELECT
    domain,
    is_public,
    is_locked,
    registered_tenant_id,
    CASE
        WHEN is_public = true THEN true
        WHEN is_locked = false AND registered_tenant_id IS NULL THEN true
        ELSE false
    END as available
FROM domain_master
WHERE LOWER(domain) = LOWER('example.com');
```

### Find All Public Domains
```sql
SELECT domain
FROM domain_master
WHERE is_public = true
ORDER BY domain;
```

### Find Locked Corporate Domains
```sql
SELECT
    dm.domain,
    dm.registered_tenant_id,
    cm.company_name,
    cm.email
FROM domain_master dm
JOIN company_master cm ON dm.registered_tenant_id = cm.tenant_id
WHERE dm.is_public = false AND dm.is_locked = true
ORDER BY dm.domain;
```

### Check Domain Usage
```sql
SELECT
    domain,
    COUNT(*) as tenant_count
FROM company_master
GROUP BY domain
ORDER BY tenant_count DESC;
```

## Data Integrity Rules

### Rule 1: Domain Lowercase
```sql
CONSTRAINT domain_lowercase CHECK (domain = LOWER(domain))
```
All domains stored in lowercase for consistency.

### Rule 2: Public Domains Cannot Be Locked
Business logic (not DB constraint):
- Public domains: `is_locked = false` always
- Corporate domains: `is_locked = true` when registered

### Rule 3: Referential Integrity
```sql
CONSTRAINT fk_domain_tenant FOREIGN KEY (registered_tenant_id)
    REFERENCES company_master(tenant_id) ON DELETE SET NULL
```
If tenant deleted, domain becomes available again.

## Maintenance Tasks

### Add New Public Domain
```sql
INSERT INTO domain_master (domain, is_public, is_locked)
VALUES ('newpublic.com', true, false);
```

### Unlock Domain (Admin Operation)
```sql
-- Make domain available again
UPDATE domain_master
SET is_locked = false,
    registered_tenant_id = NULL
WHERE domain = 'company.com';
```

### Find Orphaned Domains
```sql
-- Domains registered but no company using them
SELECT dm.*
FROM domain_master dm
LEFT JOIN company_master cm ON dm.domain = cm.domain
WHERE dm.is_public = false
  AND cm.domain IS NULL;
```

## Backup Recommendations

**Critical Tables:**
- `domain_master`: Backup before bulk operations
- `company_master`: Standard backup schedule

**Recovery Scenarios:**
1. **Lost domain_master**: Rebuild from company_master emails
2. **Corrupted locks**: Re-validate from company_master

## Performance Considerations

**Indexes cover:**
- Domain lookups (PK index)
- Public domain filters (`idx_domain_public`)
- Lock status checks (`idx_domain_locked`)
- Tenant lookups (`idx_domain_tenant`)

**Expected Query Performance:**
- Domain availability check: < 5ms
- Tenant domain lookup: < 10ms

## Monitoring Queries

### Daily Stats
```sql
SELECT
    COUNT(*) as total_domains,
    SUM(CASE WHEN is_public THEN 1 ELSE 0 END) as public_domains,
    SUM(CASE WHEN is_locked THEN 1 ELSE 0 END) as locked_domains
FROM domain_master;
```

### Recent Registrations
```sql
SELECT domain, registered_tenant_id, created_at
FROM domain_master
WHERE is_public = false
ORDER BY created_at DESC
LIMIT 10;
```

## Troubleshooting

### Issue: Migration Failed
**Check:**
```sql
SELECT * FROM flyway_schema_history WHERE version = '2';
```

**Fix:**
```sql
DELETE FROM flyway_schema_history WHERE version = '2' AND success = false;
-- Then restart application
```

### Issue: FK Constraint Violation
**Cause:** Domain not in domain_master before inserting company
**Fix:** Ensure domain_master entry exists first

### Issue: Duplicate Domain
**Cause:** Race condition during signup
**Fix:** Application handles via transaction isolation

## Questions?
Contact: Backend Team
