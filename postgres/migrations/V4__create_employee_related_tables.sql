-- ================================================================
-- V4: Create Employee Related Tables
-- Description: Employee education and experience tables
-- Date: 2025-11-06
-- ================================================================

-- Employee Education
CREATE TABLE IF NOT EXISTS employee_education (
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

CREATE INDEX IF NOT EXISTS idx_education_employee ON employee_education(employee_id);

COMMENT ON TABLE employee_education IS 'Employee education/qualification details';

-- Employee Experience
CREATE TABLE IF NOT EXISTS employee_experience (
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

CREATE INDEX IF NOT EXISTS idx_experience_employee ON employee_experience(employee_id);

COMMENT ON TABLE employee_experience IS 'Employee previous work experience';
