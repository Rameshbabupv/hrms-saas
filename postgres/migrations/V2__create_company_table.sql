-- ================================================================
-- V2: Create Company Table
-- Description: Company master with corporate hierarchy support (max 2 levels)
-- Date: 2025-11-06
-- ================================================================

CREATE TABLE IF NOT EXISTS company (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Basic Info
    company_name VARCHAR(200) NOT NULL,
    company_code VARCHAR(20) NOT NULL UNIQUE,

    -- Corporate Hierarchy
    parent_company_id UUID REFERENCES company(id) ON DELETE RESTRICT,
    company_type company_type DEFAULT 'independent',
    corporate_group_name VARCHAR(200),
    is_parent BOOLEAN DEFAULT false,
    hierarchy_level INTEGER DEFAULT 1,  -- 1 = parent/independent, 2 = subsidiary

    -- Contact Details
    email VARCHAR(100),
    phone VARCHAR(20),
    website VARCHAR(200),

    -- Address
    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'India',
    pincode VARCHAR(10),

    -- Legal/Compliance (Indian context)
    pan_no VARCHAR(10),
    gstin_no VARCHAR(15),
    tan_no VARCHAR(10),
    cin_no VARCHAR(21),

    -- PF/ESI Settings
    pf_number VARCHAR(50),
    esi_number VARCHAR(50),
    pf_enabled BOOLEAN DEFAULT false,
    esi_enabled BOOLEAN DEFAULT false,

    -- Subscription/SaaS Fields
    subscription_plan VARCHAR(50) DEFAULT 'free',
    max_employees INTEGER DEFAULT 10,
    subscription_start_date DATE,
    subscription_end_date DATE,
    is_trial BOOLEAN DEFAULT true,

    -- Flexible Billing
    subscription_paid_by subscription_paid_by DEFAULT 'self',
    billing_company_id UUID REFERENCES company(id) ON DELETE SET NULL,

    -- Shared Master Data Settings
    share_masters_with_group BOOLEAN DEFAULT false,
    inherit_masters_from_parent BOOLEAN DEFAULT false,

    -- Audit Fields
    status status_type DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,

    -- Constraints
    CONSTRAINT chk_hierarchy_level CHECK (hierarchy_level IN (1, 2)),
    CONSTRAINT chk_parent_not_self CHECK (parent_company_id != id),
    CONSTRAINT chk_holding_is_parent CHECK (
        (company_type = 'holding' AND is_parent = true) OR
        (company_type != 'holding')
    )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_company_status ON company(status);
CREATE INDEX IF NOT EXISTS idx_company_code ON company(company_code);
CREATE INDEX IF NOT EXISTS idx_company_subscription ON company(subscription_plan, subscription_end_date);
CREATE INDEX IF NOT EXISTS idx_company_parent ON company(parent_company_id);
CREATE INDEX IF NOT EXISTS idx_company_group ON company(corporate_group_name);
CREATE INDEX IF NOT EXISTS idx_company_billing ON company(billing_company_id);
CREATE INDEX IF NOT EXISTS idx_company_type ON company(company_type);

-- Comments
COMMENT ON TABLE company IS 'Tenant companies with corporate hierarchy support (max 2 levels)';
COMMENT ON COLUMN company.parent_company_id IS 'Reference to parent company for subsidiaries';
COMMENT ON COLUMN company.hierarchy_level IS '1=parent/independent, 2=subsidiary';
COMMENT ON COLUMN company.subscription_paid_by IS 'Who pays the subscription: self, parent, or external';
