-- ================================================================
-- SaaS HRMS MVP: Schema V2 - With Corporate Hierarchy Support
-- PostgreSQL Database Schema
--
-- Version: 2.0
-- Date: 2025-10-29
-- Changes from V1:
--   + Added corporate hierarchy (parent-child companies, max 2 levels)
--   + Added flexible subscription management (parent or child pays)
--   + Added shared master data support for group companies
--   + Enhanced RLS policies for parent-can-see-children access
--   + Added group admin vs company admin role support
--
-- Design Philosophy: Simple 2-level hierarchy for MVP
-- Multi-tenancy: Shared database with enhanced tenant context
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Common enums
CREATE TYPE status_type AS ENUM ('active', 'inactive', 'deleted');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE employment_type AS ENUM ('permanent', 'contract', 'consultant', 'intern', 'temporary');
CREATE TYPE marital_status_type AS ENUM ('single', 'married', 'divorced', 'widowed');
CREATE TYPE company_type AS ENUM ('holding', 'subsidiary', 'independent');
CREATE TYPE subscription_paid_by AS ENUM ('self', 'parent', 'external');

-- ================================================================
-- COMPANY MASTER (Enhanced with Hierarchy)
-- Each company can be a parent or child (max 2 levels)
-- ================================================================
CREATE TABLE company (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Basic Info
    company_name VARCHAR(200) NOT NULL,
    company_code VARCHAR(20) NOT NULL UNIQUE,

    -- Corporate Hierarchy (NEW in V2)
    parent_company_id UUID REFERENCES company(id) ON DELETE RESTRICT,
    company_type company_type DEFAULT 'independent',
    corporate_group_name VARCHAR(200),  -- "ABC Group", "XYZ Group"
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

    -- Subscription/SaaS Fields (Enhanced in V2)
    subscription_plan VARCHAR(50) DEFAULT 'free',
    max_employees INTEGER DEFAULT 10,
    subscription_start_date DATE,
    subscription_end_date DATE,
    is_trial BOOLEAN DEFAULT true,

    -- NEW: Flexible Billing
    subscription_paid_by subscription_paid_by DEFAULT 'self',
    billing_company_id UUID REFERENCES company(id) ON DELETE SET NULL,  -- Who pays the bill

    -- Shared Master Data Settings (NEW in V2)
    share_masters_with_group BOOLEAN DEFAULT false,  -- Share dept, designation, etc. with group companies
    inherit_masters_from_parent BOOLEAN DEFAULT false,  -- Use parent's master data

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

-- Indexes for company
CREATE INDEX idx_company_status ON company(status);
CREATE INDEX idx_company_code ON company(company_code);
CREATE INDEX idx_company_subscription ON company(subscription_plan, subscription_end_date);
CREATE INDEX idx_company_parent ON company(parent_company_id);
CREATE INDEX idx_company_group ON company(corporate_group_name);
CREATE INDEX idx_company_billing ON company(billing_company_id);
CREATE INDEX idx_company_type ON company(company_type);

-- ================================================================
-- EMPLOYEE MASTER (No changes - employees stay in one company)
-- ================================================================
CREATE TABLE employee (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- TENANT ISOLATION (CRITICAL for SaaS)
    company_id UUID NOT NULL REFERENCES company(id) ON DELETE CASCADE,

    -- Employee ID & Basic Info
    employee_code VARCHAR(50) NOT NULL,
    employee_name VARCHAR(200) NOT NULL,
    email VARCHAR(100),
    personal_email VARCHAR(100),
    mobile_no VARCHAR(20),
    emergency_contact VARCHAR(20),

    -- Personal Details
    date_of_birth DATE,
    gender gender_type,
    marital_status marital_status_type,
    blood_group VARCHAR(10),

    -- Address
    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'India',
    pincode VARCHAR(10),

    -- Employment Details
    date_of_joining DATE NOT NULL,
    date_of_confirmation DATE,
    employment_type employment_type DEFAULT 'permanent',
    designation VARCHAR(100),
    department VARCHAR(100),

    -- Reporting Structure (within same company)
    reporting_manager_id UUID REFERENCES employee(id) ON DELETE SET NULL,

    -- Compensation (Simple for MVP)
    monthly_ctc DECIMAL(12, 2),
    monthly_gross DECIMAL(12, 2),

    -- Statutory Details
    pan_no VARCHAR(10),
    aadhaar_no VARCHAR(12),
    uan_no VARCHAR(12),
    pf_number VARCHAR(50),
    esi_number VARCHAR(50),

    -- Bank Details
    bank_name VARCHAR(100),
    bank_account_no VARCHAR(50),
    bank_ifsc_code VARCHAR(11),
    bank_branch VARCHAR(100),

    -- Document URLs (Store S3/Cloud paths)
    photo_url VARCHAR(500),
    aadhaar_url VARCHAR(500),
    pan_url VARCHAR(500),
    resume_url VARCHAR(500),

    -- Employment Status
    is_active BOOLEAN DEFAULT true,
    date_of_exit DATE,
    exit_reason TEXT,

    -- Audit Fields
    status status_type DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,

    -- Constraints
    CONSTRAINT uk_employee_code_company UNIQUE (company_id, employee_code),
    CONSTRAINT uk_employee_email_company UNIQUE (company_id, email),
    CONSTRAINT chk_manager_same_company CHECK (
        reporting_manager_id IS NULL OR
        (SELECT company_id FROM employee WHERE id = reporting_manager_id) = company_id
    )
);

-- Indexes for employee
CREATE INDEX idx_employee_company ON employee(company_id);
CREATE INDEX idx_employee_status ON employee(status);
CREATE INDEX idx_employee_active ON employee(is_active);
CREATE INDEX idx_employee_code ON employee(employee_code);
CREATE INDEX idx_employee_email ON employee(email);
CREATE INDEX idx_employee_joining_date ON employee(date_of_joining);
CREATE INDEX idx_employee_manager ON employee(reporting_manager_id);

-- ================================================================
-- EMPLOYEE EDUCATION (No changes from V1)
-- ================================================================
CREATE TABLE employee_education (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employee(id) ON DELETE CASCADE,

    degree VARCHAR(100),
    institution VARCHAR(200),
    specialization VARCHAR(100),
    year_of_passing INTEGER,
    percentage DECIMAL(5, 2),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_education_employee ON employee_education(employee_id);

-- ================================================================
-- EMPLOYEE EXPERIENCE (No changes from V1)
-- ================================================================
CREATE TABLE employee_experience (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employee(id) ON DELETE CASCADE,

    company_name VARCHAR(200),
    designation VARCHAR(100),
    from_date DATE,
    to_date DATE,
    responsibilities TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_experience_employee ON employee_experience(employee_id);

-- ================================================================
-- SHARED MASTER DATA: DEPARTMENT (NEW in V2)
-- Departments can be shared across group companies
-- ================================================================
CREATE TABLE department_master (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Owner company (who created this department)
    owner_company_id UUID NOT NULL REFERENCES company(id) ON DELETE CASCADE,

    -- Department details
    department_code VARCHAR(20) NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Sharing settings
    is_shared BOOLEAN DEFAULT false,  -- Can other group companies use this?
    shared_with_group VARCHAR(200),   -- "ABC Group" - which group can use this

    -- Audit
    status status_type DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,

    CONSTRAINT uk_dept_code_owner UNIQUE (owner_company_id, department_code)
);

CREATE INDEX idx_dept_owner ON department_master(owner_company_id);
CREATE INDEX idx_dept_shared ON department_master(is_shared, shared_with_group);
CREATE INDEX idx_dept_status ON department_master(status);

-- ================================================================
-- SHARED MASTER DATA: DESIGNATION (NEW in V2)
-- Designations can be shared across group companies
-- ================================================================
CREATE TABLE designation_master (
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

CREATE INDEX idx_desig_owner ON designation_master(owner_company_id);
CREATE INDEX idx_desig_shared ON designation_master(is_shared, shared_with_group);
CREATE INDEX idx_desig_status ON designation_master(status);

-- ================================================================
-- ROW LEVEL SECURITY (RLS) - Enhanced for Hierarchy
-- Critical for SaaS: Ensures data isolation with parent-can-see-children
-- ================================================================

-- Enable RLS on employee table
ALTER TABLE employee ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see employees from their own company OR subsidiary companies
CREATE POLICY employee_tenant_isolation ON employee
    USING (
        -- See own company's employees
        company_id = current_setting('app.current_tenant_id', true)::uuid
        OR
        -- OR see subsidiary employees if current user is from parent company
        company_id IN (
            SELECT id FROM company
            WHERE parent_company_id = current_setting('app.current_tenant_id', true)::uuid
        )
    );

-- Policy for INSERT/UPDATE/DELETE: Can only modify own company (not subsidiaries)
CREATE POLICY employee_tenant_modification ON employee
    FOR ALL
    USING (company_id = current_setting('app.current_tenant_id', true)::uuid)
    WITH CHECK (company_id = current_setting('app.current_tenant_id', true)::uuid);

-- Enable RLS on company table
ALTER TABLE company ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own company and subsidiaries
CREATE POLICY company_tenant_isolation ON company
    USING (
        -- See own company
        id = current_setting('app.current_tenant_id', true)::uuid
        OR
        -- OR see subsidiaries
        parent_company_id = current_setting('app.current_tenant_id', true)::uuid
        OR
        -- OR see parent company (for reporting)
        id = (SELECT parent_company_id FROM company WHERE id = current_setting('app.current_tenant_id', true)::uuid)
    );

-- Enable RLS on department_master
ALTER TABLE department_master ENABLE ROW LEVEL SECURITY;

-- Policy: Can see own departments OR shared departments from group
CREATE POLICY department_access ON department_master
    USING (
        owner_company_id = current_setting('app.current_tenant_id', true)::uuid
        OR
        (is_shared = true AND shared_with_group = (
            SELECT corporate_group_name FROM company
            WHERE id = current_setting('app.current_tenant_id', true)::uuid
        ))
    );

-- Enable RLS on designation_master
ALTER TABLE designation_master ENABLE ROW LEVEL SECURITY;

-- Policy: Can see own designations OR shared designations from group
CREATE POLICY designation_access ON designation_master
    USING (
        owner_company_id = current_setting('app.current_tenant_id', true)::uuid
        OR
        (is_shared = true AND shared_with_group = (
            SELECT corporate_group_name FROM company
            WHERE id = current_setting('app.current_tenant_id', true)::uuid
        ))
    );

-- ================================================================
-- HELPER FUNCTIONS (Enhanced for Hierarchy)
-- ================================================================

-- Function to set current tenant context
CREATE OR REPLACE FUNCTION set_current_tenant(tenant_id UUID)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_tenant_id', tenant_id::text, false);
END;
$$ LANGUAGE plpgsql;

-- Function to get employee count for a company (including subsidiaries)
CREATE OR REPLACE FUNCTION get_employee_count(tenant_id UUID, include_subsidiaries BOOLEAN DEFAULT false)
RETURNS INTEGER AS $$
DECLARE
    emp_count INTEGER;
BEGIN
    IF include_subsidiaries THEN
        -- Count employees in this company and all subsidiaries
        SELECT COUNT(*) INTO emp_count
        FROM employee
        WHERE (company_id = tenant_id OR company_id IN (
            SELECT id FROM company WHERE parent_company_id = tenant_id
        ))
        AND status = 'active' AND is_active = true;
    ELSE
        -- Count only this company's employees
        SELECT COUNT(*) INTO emp_count
        FROM employee
        WHERE company_id = tenant_id AND status = 'active' AND is_active = true;
    END IF;

    RETURN emp_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get all subsidiary companies
CREATE OR REPLACE FUNCTION get_subsidiary_companies(parent_id UUID)
RETURNS TABLE(
    company_id UUID,
    company_name VARCHAR,
    company_code VARCHAR,
    employee_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.company_name,
        c.company_code,
        get_employee_count(c.id, false) as employee_count
    FROM company c
    WHERE c.parent_company_id = parent_id
    AND c.status = 'active';
END;
$$ LANGUAGE plpgsql;

-- Function to check if company is parent
CREATE OR REPLACE FUNCTION is_parent_company(company_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    has_children BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM company
        WHERE parent_company_id = company_id
    ) INTO has_children;

    RETURN has_children;
END;
$$ LANGUAGE plpgsql;

-- Function to get corporate group summary
CREATE OR REPLACE FUNCTION get_corporate_group_summary(group_name VARCHAR)
RETURNS TABLE(
    total_companies INTEGER,
    total_employees INTEGER,
    active_subscriptions INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT c.id)::INTEGER as total_companies,
        COUNT(DISTINCT e.id)::INTEGER as total_employees,
        COUNT(DISTINCT CASE
            WHEN c.subscription_end_date > CURRENT_DATE THEN c.id
        END)::INTEGER as active_subscriptions
    FROM company c
    LEFT JOIN employee e ON e.company_id = c.id AND e.status = 'active'
    WHERE c.corporate_group_name = group_name
    AND c.status = 'active';
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate hierarchy constraints
CREATE OR REPLACE FUNCTION validate_company_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    parent_level INTEGER;
BEGIN
    -- If this is a subsidiary, check parent level
    IF NEW.parent_company_id IS NOT NULL THEN
        SELECT hierarchy_level INTO parent_level
        FROM company WHERE id = NEW.parent_company_id;

        -- Parent must be level 1
        IF parent_level != 1 THEN
            RAISE EXCEPTION 'Only level 1 companies can have subsidiaries. Max 2 levels allowed.';
        END IF;

        -- Set this company as level 2
        NEW.hierarchy_level := 2;
        NEW.company_type := 'subsidiary';
        NEW.is_parent := false;

        -- Inherit corporate group name from parent
        SELECT corporate_group_name INTO NEW.corporate_group_name
        FROM company WHERE id = NEW.parent_company_id;
    ELSE
        -- Independent or holding company (level 1)
        NEW.hierarchy_level := 1;
        IF NEW.company_type = 'holding' THEN
            NEW.is_parent := true;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER company_updated_at
    BEFORE UPDATE ON company
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER employee_updated_at
    BEFORE UPDATE ON employee
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER validate_hierarchy
    BEFORE INSERT OR UPDATE ON company
    FOR EACH ROW
    EXECUTE FUNCTION validate_company_hierarchy();

-- ================================================================
-- SAMPLE DATA (Enhanced with Hierarchy)
-- ================================================================

-- Insert parent company (ABC Group)
INSERT INTO company (
    company_name, company_code, email, phone,
    city, state, country,
    pan_no, gstin_no,
    company_type, is_parent, corporate_group_name,
    subscription_plan, max_employees, is_trial,
    subscription_paid_by, share_masters_with_group
) VALUES (
    'ABC Holdings Pvt Ltd',
    'ABC-HOLD',
    'info@abcgroup.com',
    '+91-9876543210',
    'Mumbai',
    'Maharashtra',
    'India',
    'ABCDE1234F',
    '27ABCDE1234F1Z5',
    'holding',
    true,
    'ABC Group',
    'enterprise',
    500,
    false,
    'self',
    true
) RETURNING id AS abc_parent_id \gset

-- Insert ABC Manufacturing (subsidiary)
INSERT INTO company (
    company_name, company_code, email, phone,
    city, state, country,
    pan_no, gstin_no,
    parent_company_id,
    subscription_plan, max_employees,
    subscription_paid_by, billing_company_id,
    inherit_masters_from_parent
) VALUES (
    'ABC Manufacturing Pvt Ltd',
    'ABC-MFG',
    'info@abcmfg.com',
    '+91-9876543211',
    'Bangalore',
    'Karnataka',
    'India',
    'ABCMF1234G',
    '29ABCMF1234G1Z5',
    :'abc_parent_id',
    'enterprise',
    200,
    'parent',
    :'abc_parent_id',
    true
);

-- Insert ABC Services (subsidiary)
INSERT INTO company (
    company_name, company_code, email, phone,
    city, state, country,
    pan_no, gstin_no,
    parent_company_id,
    subscription_plan, max_employees,
    subscription_paid_by, billing_company_id,
    inherit_masters_from_parent
) VALUES (
    'ABC Services Pvt Ltd',
    'ABC-SRV',
    'info@abcservices.com',
    '+91-9876543212',
    'Pune',
    'Maharashtra',
    'India',
    'ABCSV1234H',
    '27ABCSV1234H1Z5',
    :'abc_parent_id',
    'enterprise',
    150,
    'parent',
    :'abc_parent_id',
    true
);

-- Insert independent company (for comparison)
INSERT INTO company (
    company_name, company_code, email, phone,
    city, state, country,
    pan_no, gstin_no,
    company_type, corporate_group_name,
    subscription_plan, max_employees, is_trial
) VALUES (
    'Demo Tech Solutions Pvt Ltd',
    'DEMO001',
    'info@demotech.com',
    '+91-9876543220',
    'Chennai',
    'Tamil Nadu',
    'India',
    'DEMO01234I',
    '33DEMO1234I1Z5',
    'independent',
    NULL,
    'basic',
    50,
    true
);

-- Insert shared departments for ABC Group
INSERT INTO department_master (
    owner_company_id, department_code, department_name,
    is_shared, shared_with_group
)
SELECT
    id, 'HR', 'Human Resources', true, 'ABC Group'
FROM company WHERE company_code = 'ABC-HOLD'
UNION ALL
SELECT
    id, 'IT', 'Information Technology', true, 'ABC Group'
FROM company WHERE company_code = 'ABC-HOLD'
UNION ALL
SELECT
    id, 'FIN', 'Finance', true, 'ABC Group'
FROM company WHERE company_code = 'ABC-HOLD';

-- Insert shared designations for ABC Group
INSERT INTO designation_master (
    owner_company_id, designation_code, designation_name,
    is_shared, shared_with_group
)
SELECT
    id, 'CEO', 'Chief Executive Officer', true, 'ABC Group'
FROM company WHERE company_code = 'ABC-HOLD'
UNION ALL
SELECT
    id, 'MGR', 'Manager', true, 'ABC Group'
FROM company WHERE company_code = 'ABC-HOLD'
UNION ALL
SELECT
    id, 'EXEC', 'Executive', true, 'ABC Group'
FROM company WHERE company_code = 'ABC-HOLD';

-- Insert sample employees across companies
DO $$
DECLARE
    abc_holding_id UUID;
    abc_mfg_id UUID;
    abc_srv_id UUID;
    demo_id UUID;
    ceo_id UUID;
BEGIN
    -- Get company IDs
    SELECT id INTO abc_holding_id FROM company WHERE company_code = 'ABC-HOLD';
    SELECT id INTO abc_mfg_id FROM company WHERE company_code = 'ABC-MFG';
    SELECT id INTO abc_srv_id FROM company WHERE company_code = 'ABC-SRV';
    SELECT id INTO demo_id FROM company WHERE company_code = 'DEMO001';

    -- ABC Holdings CEO
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_holding_id, 'ABCH001', 'Rajesh Kumar', 'rajesh.kumar@abcgroup.com', '+91-9876543230',
        '1975-05-15', 'male', 'married',
        '2015-01-01', 'permanent', 'Chief Executive Officer', 'Management',
        1000000.00, 900000.00
    ) RETURNING id INTO ceo_id;

    -- ABC Manufacturing Manager
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_mfg_id, 'ABCM001', 'Priya Sharma', 'priya.sharma@abcmfg.com', '+91-9876543231',
        '1985-08-20', 'female', 'single',
        '2018-06-15', 'permanent', 'Manager', 'Human Resources',
        150000.00, 135000.00
    );

    -- ABC Services Executive
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_srv_id, 'ABCS001', 'Amit Patel', 'amit.patel@abcservices.com', '+91-9876543232',
        '1992-03-10', 'male', 'married',
        '2020-03-01', 'permanent', 'Executive', 'Information Technology',
        100000.00, 90000.00
    );

    -- Demo Company Employee
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        demo_id, 'DEMO001', 'Sunita Reddy', 'sunita.reddy@demotech.com', '+91-9876543233',
        '1990-11-25', 'female', 'married',
        '2021-01-15', 'permanent', 'Manager', 'Operations',
        120000.00, 108000.00
    );
END $$;

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- View corporate hierarchy
-- SELECT
--     c.company_code,
--     c.company_name,
--     c.company_type,
--     c.hierarchy_level,
--     p.company_name as parent_company,
--     c.corporate_group_name,
--     get_employee_count(c.id, false) as direct_employees,
--     CASE WHEN c.is_parent THEN get_employee_count(c.id, true) END as total_group_employees
-- FROM company c
-- LEFT JOIN company p ON c.parent_company_id = p.id
-- WHERE c.status = 'active'
-- ORDER BY c.corporate_group_name, c.hierarchy_level, c.company_name;

-- View subsidiaries for a parent
-- SELECT * FROM get_subsidiary_companies(
--     (SELECT id FROM company WHERE company_code = 'ABC-HOLD')
-- );

-- View corporate group summary
-- SELECT * FROM get_corporate_group_summary('ABC Group');

-- View employees across group (parent perspective)
-- SELECT
--     e.employee_code,
--     e.employee_name,
--     c.company_name,
--     e.designation,
--     e.department,
--     e.monthly_ctc
-- FROM employee e
-- JOIN company c ON e.company_id = c.id
-- WHERE c.corporate_group_name = 'ABC Group'
-- AND e.status = 'active'
-- ORDER BY c.hierarchy_level, c.company_name, e.employee_code;

-- View shared master data
-- SELECT
--     d.department_code,
--     d.department_name,
--     c.company_name as owner_company,
--     d.is_shared,
--     d.shared_with_group
-- FROM department_master d
-- JOIN company c ON d.owner_company_id = c.id
-- WHERE d.status = 'active'
-- ORDER BY d.shared_with_group, d.department_code;

-- Test RLS: Parent can see subsidiaries
-- SELECT set_current_tenant((SELECT id FROM company WHERE company_code = 'ABC-HOLD'));
-- SELECT
--     c.company_code,
--     c.company_name,
--     COUNT(e.id) as employee_count
-- FROM company c
-- LEFT JOIN employee e ON c.id = e.company_id
-- GROUP BY c.id, c.company_code, c.company_name
-- ORDER BY c.hierarchy_level;

-- Test RLS: Subsidiary cannot see siblings
-- SELECT set_current_tenant((SELECT id FROM company WHERE company_code = 'ABC-MFG'));
-- SELECT company_code, company_name FROM company WHERE status = 'active';
-- -- Should only see: ABC-HOLD (parent) and ABC-MFG (self), NOT ABC-SRV
