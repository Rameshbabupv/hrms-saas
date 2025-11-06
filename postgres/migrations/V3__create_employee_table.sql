-- ================================================================
-- V3: Create Employee Table
-- Description: Employee master with tenant isolation
-- Date: 2025-11-06
-- ================================================================

CREATE TABLE IF NOT EXISTS employee (
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

    -- Reporting Structure
    reporting_manager_id UUID REFERENCES employee(id) ON DELETE SET NULL,

    -- Compensation
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

    -- Document URLs
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_employee_company ON employee(company_id);
CREATE INDEX IF NOT EXISTS idx_employee_status ON employee(status);
CREATE INDEX IF NOT EXISTS idx_employee_active ON employee(is_active);
CREATE INDEX IF NOT EXISTS idx_employee_code ON employee(employee_code);
CREATE INDEX IF NOT EXISTS idx_employee_email ON employee(email);
CREATE INDEX IF NOT EXISTS idx_employee_joining_date ON employee(date_of_joining);
CREATE INDEX IF NOT EXISTS idx_employee_manager ON employee(reporting_manager_id);

-- Comments
COMMENT ON TABLE employee IS 'Employee master with strict tenant isolation';
COMMENT ON COLUMN employee.company_id IS 'CRITICAL: Tenant isolation key';
COMMENT ON COLUMN employee.reporting_manager_id IS 'Manager must be in same company';
