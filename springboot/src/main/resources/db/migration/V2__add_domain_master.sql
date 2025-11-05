-- V2__add_domain_master.sql
-- Add domain_master table and update company_master

-- =============================================
-- Create domain_master table
-- =============================================
CREATE TABLE domain_master (
    domain VARCHAR(255) PRIMARY KEY,
    is_public BOOLEAN NOT NULL DEFAULT false,
    is_locked BOOLEAN NOT NULL DEFAULT false,
    registered_tenant_id VARCHAR(21),
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),

    -- Constraints
    CONSTRAINT domain_lowercase CHECK (domain = LOWER(domain)),
    CONSTRAINT fk_domain_tenant FOREIGN KEY (registered_tenant_id)
        REFERENCES company_master(tenant_id) ON DELETE SET NULL
);

-- Index for fast lookups
CREATE INDEX idx_domain_public ON domain_master(is_public);
CREATE INDEX idx_domain_locked ON domain_master(is_locked);
CREATE INDEX idx_domain_tenant ON domain_master(registered_tenant_id);

-- =============================================
-- Add domain column to company_master
-- =============================================
ALTER TABLE company_master
    ADD COLUMN domain VARCHAR(255);

-- Extract domain from existing emails
UPDATE company_master
SET domain = LOWER(SUBSTRING(email FROM '@(.*)$'));

-- =============================================
-- Pre-populate public domains FIRST
-- =============================================
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
    ('yandex.com', true, false)
ON CONFLICT (domain) DO NOTHING;

-- =============================================
-- Populate domain_master for existing companies
-- =============================================
INSERT INTO domain_master (domain, is_public, is_locked, registered_tenant_id)
SELECT DISTINCT
    domain,
    false as is_public,
    true as is_locked,
    tenant_id as registered_tenant_id
FROM company_master
WHERE domain NOT IN (SELECT domain FROM domain_master)
ON CONFLICT (domain) DO NOTHING;

-- Make domain NOT NULL after populating
ALTER TABLE company_master
    ALTER COLUMN domain SET NOT NULL;

-- Add foreign key constraint AFTER populating domain_master
ALTER TABLE company_master
    ADD CONSTRAINT fk_company_domain
    FOREIGN KEY (domain) REFERENCES domain_master(domain);

-- Add index on domain
CREATE INDEX idx_company_domain ON company_master(domain);

-- =============================================
-- Update timestamp trigger for domain_master
-- =============================================
CREATE OR REPLACE FUNCTION update_domain_master_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_domain_master_timestamp
    BEFORE UPDATE ON domain_master
    FOR EACH ROW
    EXECUTE FUNCTION update_domain_master_timestamp();
