-- ================================================================
-- V5: Create Master Data Tables
-- Description: Department and Designation masters with group sharing support
-- Date: 2025-11-06
-- ================================================================

-- Department Master
CREATE TABLE IF NOT EXISTS department_master (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Owner company (who created this department)
    owner_company_id UUID NOT NULL REFERENCES company(id) ON DELETE CASCADE,

    -- Department details
    department_code VARCHAR(20) NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Sharing settings
    is_shared BOOLEAN DEFAULT false,
    shared_with_group VARCHAR(200),

    -- Audit
    status status_type DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,

    CONSTRAINT uk_dept_code_owner UNIQUE (owner_company_id, department_code)
);

CREATE INDEX IF NOT EXISTS idx_dept_owner ON department_master(owner_company_id);
CREATE INDEX IF NOT EXISTS idx_dept_shared ON department_master(is_shared, shared_with_group);
CREATE INDEX IF NOT EXISTS idx_dept_status ON department_master(status);

COMMENT ON TABLE department_master IS 'Department master with group sharing capability';
COMMENT ON COLUMN department_master.is_shared IS 'Can other group companies use this department?';

-- Designation Master
CREATE TABLE IF NOT EXISTS designation_master (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Owner company
    owner_company_id UUID NOT NULL REFERENCES company(id) ON DELETE CASCADE,

    -- Designation details
    designation_code VARCHAR(20) NOT NULL,
    designation_name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Sharing settings
    is_shared BOOLEAN DEFAULT false,
    shared_with_group VARCHAR(200),

    -- Audit
    status status_type DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,

    CONSTRAINT uk_desig_code_owner UNIQUE (owner_company_id, designation_code)
);

CREATE INDEX IF NOT EXISTS idx_desig_owner ON designation_master(owner_company_id);
CREATE INDEX IF NOT EXISTS idx_desig_shared ON designation_master(is_shared, shared_with_group);
CREATE INDEX IF NOT EXISTS idx_desig_status ON designation_master(status);

COMMENT ON TABLE designation_master IS 'Designation master with group sharing capability';
COMMENT ON COLUMN designation_master.is_shared IS 'Can other group companies use this designation?';
