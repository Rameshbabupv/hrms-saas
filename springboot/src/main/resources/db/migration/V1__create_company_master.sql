-- ============================================
-- V1: Create Company Master Table
-- ============================================
-- Description: Master table for all companies (tenants) in the HRMS SaaS platform
-- Author: Systech Team
-- Date: 2025-10-31
-- Tenant Strategy: NanoID-based (12-char lowercase alphanumeric)

-- ============================================
-- 1. CREATE COMPANY_MASTER TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS company_master (
    tenant_id VARCHAR(21) PRIMARY KEY,  -- NanoID: 12 chars (VARCHAR(21) for safety margin)
    company_name VARCHAR(255) NOT NULL,
    company_code VARCHAR(50),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    address TEXT,
    status VARCHAR(30) DEFAULT 'PENDING_ACTIVATION',  -- PENDING_ACTIVATION, PENDING_EMAIL_VERIFICATION, ACTIVE, SUSPENDED, INACTIVE
    subscription_plan VARCHAR(50) DEFAULT 'FREE',     -- FREE, BASIC, PROFESSIONAL, ENTERPRISE
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(100),

    -- Constraints
    CONSTRAINT company_name_min_length CHECK (LENGTH(company_name) >= 2),
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ============================================
-- 2. CREATE INDEXES
-- ============================================
CREATE INDEX idx_company_email ON company_master(email);
CREATE INDEX idx_company_status ON company_master(status);
CREATE INDEX idx_company_subscription ON company_master(subscription_plan);

-- ============================================
-- 3. ADD COMMENTS
-- ============================================
COMMENT ON TABLE company_master IS 'Master table for all companies (tenants) in HRMS SaaS platform';
COMMENT ON COLUMN company_master.tenant_id IS 'NanoID: 12-char unique identifier for tenant isolation (e.g., a3b9c8d2e1f4)';
COMMENT ON COLUMN company_master.company_name IS 'Official company name';
COMMENT ON COLUMN company_master.company_code IS 'Optional user-defined company code';
COMMENT ON COLUMN company_master.email IS 'Primary email address (unique across platform)';
COMMENT ON COLUMN company_master.status IS 'Account status: PENDING_ACTIVATION, PENDING_EMAIL_VERIFICATION, ACTIVE, SUSPENDED, INACTIVE';
COMMENT ON COLUMN company_master.subscription_plan IS 'Subscription plan: FREE, BASIC, PROFESSIONAL, ENTERPRISE';
COMMENT ON COLUMN company_master.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN company_master.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN company_master.created_by IS 'Email of user who created this company';

-- ============================================
-- 4. CREATE UPDATE TRIGGER FOR updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_company_master_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_company_master_timestamp
    BEFORE UPDATE ON company_master
    FOR EACH ROW
    EXECUTE FUNCTION update_company_master_timestamp();

-- ============================================
-- Migration Complete
-- ============================================
