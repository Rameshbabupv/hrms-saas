-- Create employee table without the circular CHECK constraint
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
    CONSTRAINT uk_employee_email_company UNIQUE (company_id, email)
    -- Note: Removed chk_manager_same_company constraint due to circular dependency
    -- This should be enforced at application level
);

-- Indexes for employee
CREATE INDEX idx_employee_company ON employee(company_id);
CREATE INDEX idx_employee_status ON employee(status);
CREATE INDEX idx_employee_active ON employee(is_active);
CREATE INDEX idx_employee_code ON employee(employee_code);
CREATE INDEX idx_employee_email ON employee(email);
CREATE INDEX idx_employee_joining_date ON employee(date_of_joining);
CREATE INDEX idx_employee_manager ON employee(reporting_manager_id);

-- Employee Education table
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

-- Employee Experience table
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

-- Trigger to update updated_at timestamp
CREATE TRIGGER employee_updated_at
    BEFORE UPDATE ON employee
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();
