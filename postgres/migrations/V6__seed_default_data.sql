-- ================================================================
-- V6: Seed Default Data
-- Description: Insert default/demo company and data for testing
-- Date: 2025-11-06
-- ================================================================

-- Insert default company (idempotent)
INSERT INTO company (
    id,
    company_name,
    company_code,
    company_type,
    email,
    country,
    subscription_plan,
    max_employees,
    is_trial,
    status
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Default Company',
    'DEFAULT',
    'independent',
    'admin@default.local',
    'India',
    'free',
    10,
    true,
    'active'
)
ON CONFLICT (company_code) DO NOTHING;

-- Insert demo departments for default company
INSERT INTO department_master (
    owner_company_id,
    department_code,
    department_name,
    description,
    status
) VALUES
    ('00000000-0000-0000-0000-000000000001', 'IT', 'Information Technology', 'IT and Software Development', 'active'),
    ('00000000-0000-0000-0000-000000000001', 'HR', 'Human Resources', 'Human Resources and Administration', 'active'),
    ('00000000-0000-0000-0000-000000000001', 'FIN', 'Finance', 'Finance and Accounts', 'active'),
    ('00000000-0000-0000-0000-000000000001', 'OPS', 'Operations', 'Operations and Logistics', 'active')
ON CONFLICT (owner_company_id, department_code) DO NOTHING;

-- Insert demo designations for default company
INSERT INTO designation_master (
    owner_company_id,
    designation_code,
    designation_name,
    description,
    status
) VALUES
    ('00000000-0000-0000-0000-000000000001', 'CEO', 'Chief Executive Officer', 'Top Management', 'active'),
    ('00000000-0000-0000-0000-000000000001', 'MGR', 'Manager', 'Department Manager', 'active'),
    ('00000000-0000-0000-0000-000000000001', 'TL', 'Team Lead', 'Team Leader', 'active'),
    ('00000000-0000-0000-0000-000000000001', 'SE', 'Senior Engineer', 'Senior Level', 'active'),
    ('00000000-0000-0000-0000-000000000001', 'JE', 'Junior Engineer', 'Junior Level', 'active')
ON CONFLICT (owner_company_id, designation_code) DO NOTHING;
