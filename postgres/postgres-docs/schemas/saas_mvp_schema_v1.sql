-- ================================================================
-- SaaS HRMS MVP: Simple Schema for Company & Employee Master
-- PostgreSQL Database Schema
--
-- Design Philosophy: Keep it SIMPLE for MVP
-- Multi-tenancy: Shared database with tenant_id pattern
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Common enums
CREATE TYPE status_type AS ENUM ('active', 'inactive', 'deleted');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE employment_type AS ENUM ('permanent', 'contract', 'consultant', 'intern', 'temporary');
CREATE TYPE marital_status_type AS ENUM ('single', 'married', 'divorced', 'widowed');

-- ================================================================
-- COMPANY MASTER (Tenant/Customer)
-- Each company is a separate tenant in the SaaS application
-- ================================================================
CREATE TABLE company (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Basic Info
    company_name VARCHAR(200) NOT NULL,
    company_code VARCHAR(20) NOT NULL UNIQUE,

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
    pan_no VARCHAR(10),              -- PAN Number
    gstin_no VARCHAR(15),             -- GST Number
    tan_no VARCHAR(10),               -- TAN Number
    cin_no VARCHAR(21),               -- Corporate Identification Number

    -- PF/ESI Settings (Optional for MVP)
    pf_number VARCHAR(50),
    esi_number VARCHAR(50),
    pf_enabled BOOLEAN DEFAULT false,
    esi_enabled BOOLEAN DEFAULT false,

    -- Subscription/SaaS Fields
    subscription_plan VARCHAR(50) DEFAULT 'free',  -- free, basic, premium, enterprise
    max_employees INTEGER DEFAULT 10,              -- Subscription limit
    subscription_start_date DATE,
    subscription_end_date DATE,
    is_trial BOOLEAN DEFAULT true,

    -- Audit Fields
    status status_type DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID
);

-- Indexes for company
CREATE INDEX idx_company_status ON company(status);
CREATE INDEX idx_company_code ON company(company_code);
CREATE INDEX idx_company_subscription ON company(subscription_plan, subscription_end_date);

-- ================================================================
-- EMPLOYEE MASTER
-- Core employee information with multi-tenant isolation
-- ================================================================
CREATE TABLE employee (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- TENANT ISOLATION (CRITICAL for SaaS)
    company_id UUID NOT NULL REFERENCES company(id) ON DELETE CASCADE,

    -- Employee ID & Basic Info
    employee_code VARCHAR(50) NOT NULL,           -- Company-specific employee ID
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

    -- Reporting Structure
    reporting_manager_id UUID REFERENCES employee(id) ON DELETE SET NULL,

    -- Compensation (Simple for MVP)
    monthly_ctc DECIMAL(12, 2),                   -- Monthly Cost to Company
    monthly_gross DECIMAL(12, 2),                 -- Monthly Gross Salary

    -- Statutory Details
    pan_no VARCHAR(10),
    aadhaar_no VARCHAR(12),
    uan_no VARCHAR(12),                           -- Universal Account Number (PF)
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
    CONSTRAINT uk_employee_email_company UNIQUE (company_id, email)
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
-- EMPLOYEE EDUCATION (Optional child table)
-- Store multiple education records per employee
-- ================================================================
CREATE TABLE employee_education (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employee(id) ON DELETE CASCADE,

    degree VARCHAR(100),                          -- B.Tech, MBA, etc.
    institution VARCHAR(200),
    specialization VARCHAR(100),
    year_of_passing INTEGER,
    percentage DECIMAL(5, 2),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_education_employee ON employee_education(employee_id);

-- ================================================================
-- EMPLOYEE EXPERIENCE (Optional child table)
-- Store previous work experience
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
-- ROW LEVEL SECURITY (RLS) for Multi-Tenancy
-- Critical for SaaS: Ensures data isolation between tenants
-- ================================================================

-- Enable RLS on employee table
ALTER TABLE employee ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see employees from their own company
CREATE POLICY employee_tenant_isolation ON employee
    USING (company_id = current_setting('app.current_tenant_id')::uuid);

-- Policy for INSERT/UPDATE/DELETE
CREATE POLICY employee_tenant_modification ON employee
    FOR ALL
    USING (company_id = current_setting('app.current_tenant_id')::uuid)
    WITH CHECK (company_id = current_setting('app.current_tenant_id')::uuid);

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- Function to set current tenant context (call this in your application)
CREATE OR REPLACE FUNCTION set_current_tenant(tenant_id UUID)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_tenant_id', tenant_id::text, false);
END;
$$ LANGUAGE plpgsql;

-- Function to get employee count for a company
CREATE OR REPLACE FUNCTION get_employee_count(tenant_id UUID)
RETURNS INTEGER AS $$
DECLARE
    emp_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO emp_count
    FROM employee
    WHERE company_id = tenant_id AND status = 'active' AND is_active = true;

    RETURN emp_count;
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

-- Apply trigger to company
CREATE TRIGGER company_updated_at
    BEFORE UPDATE ON company
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- Apply trigger to employee
CREATE TRIGGER employee_updated_at
    BEFORE UPDATE ON employee
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- ================================================================
-- SAMPLE DATA (For Testing)
-- ================================================================

-- Insert sample company
INSERT INTO company (
    company_name, company_code, email, phone,
    city, state, country,
    pan_no, gstin_no,
    subscription_plan, max_employees, is_trial
) VALUES (
    'Demo Tech Solutions Pvt Ltd',
    'DEMO001',
    'info@demotech.com',
    '+91-9876543210',
    'Bangalore',
    'Karnataka',
    'India',
    'ABCDE1234F',
    '29ABCDE1234F1Z5',
    'basic',
    50,
    true
);

-- Get the company_id for demo company
DO $$
DECLARE
    demo_company_id UUID;
    manager_id UUID;
BEGIN
    -- Get company ID
    SELECT id INTO demo_company_id FROM company WHERE company_code = 'DEMO001';

    -- Insert CEO (no reporting manager)
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross,
        pan_no, bank_name, bank_account_no, bank_ifsc_code
    ) VALUES (
        demo_company_id, 'EMP001', 'Rajesh Kumar', 'rajesh.kumar@demotech.com', '+91-9876543211',
        '1980-05-15', 'male', 'married',
        '2020-01-01', 'permanent', 'CEO', 'Management',
        500000.00, 450000.00,
        'ABCDE1234A', 'HDFC Bank', '12345678901234', 'HDFC0001234'
    ) RETURNING id INTO manager_id;

    -- Insert Manager reporting to CEO
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        reporting_manager_id,
        monthly_ctc, monthly_gross,
        pan_no, bank_name, bank_account_no, bank_ifsc_code
    ) VALUES (
        demo_company_id, 'EMP002', 'Priya Sharma', 'priya.sharma@demotech.com', '+91-9876543212',
        '1985-08-20', 'female', 'single',
        '2020-06-15', 'permanent', 'HR Manager', 'Human Resources',
        manager_id,
        150000.00, 135000.00,
        'ABCDE1234B', 'ICICI Bank', '98765432109876', 'ICIC0001234'
    );

    -- Insert Developer
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        reporting_manager_id,
        monthly_ctc, monthly_gross,
        pan_no, bank_name, bank_account_no, bank_ifsc_code
    ) VALUES (
        demo_company_id, 'EMP003', 'Amit Patel', 'amit.patel@demotech.com', '+91-9876543213',
        '1992-03-10', 'male', 'married',
        '2021-03-01', 'permanent', 'Senior Developer', 'Technology',
        manager_id,
        100000.00, 90000.00,
        'ABCDE1234C', 'SBI', '11223344556677', 'SBIN0001234'
    );
END $$;

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- View companies
-- SELECT * FROM company;

-- View employees with manager names
-- SELECT
--     e.employee_code,
--     e.employee_name,
--     e.designation,
--     e.department,
--     e.monthly_ctc,
--     m.employee_name as manager_name,
--     c.company_name
-- FROM employee e
-- LEFT JOIN employee m ON e.reporting_manager_id = m.id
-- JOIN company c ON e.company_id = c.id
-- WHERE e.status = 'active'
-- ORDER BY e.employee_code;

-- Get employee count by company
-- SELECT
--     c.company_name,
--     get_employee_count(c.id) as active_employees,
--     c.max_employees as subscription_limit
-- FROM company c
-- WHERE c.status = 'active';
