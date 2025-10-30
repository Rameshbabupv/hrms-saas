-- Simple sample data without complex logic
-- Set row security off for admin user
SET row_security = OFF;

-- Insert companies one by one
INSERT INTO company (
    company_name, company_code, email, phone, city, state, country,
    pan_no, gstin_no, company_type, is_parent, corporate_group_name,
    subscription_plan, max_employees, is_trial, subscription_paid_by,
    share_masters_with_group, hierarchy_level
) VALUES (
    'ABC Holdings Pvt Ltd', 'ABC-HOLD', 'info@abcgroup.com', '+91-9876543210',
    'Mumbai', 'Maharashtra', 'India', 'ABCDE1234F', '27ABCDE1234F1Z5',
    'holding', true, 'ABC Group', 'enterprise', 500, false, 'self', true, 1
),
(
    'Demo Tech Solutions Pvt Ltd', 'DEMO001', 'info@demotech.com', '+91-9876543220',
    'Chennai', 'Tamil Nadu', 'India', 'DEMO01234I', '33DEMO1234I1Z5',
    'independent', false, NULL, 'basic', 50, true, 'self', false, 1
);

-- Verify companies
SELECT COUNT(*) as company_count, array_agg(company_code) as codes FROM company;

-- Get parent company ID for subsidiaries
DO $$
DECLARE
    parent_id UUID;
BEGIN
    SELECT id INTO parent_id FROM company WHERE company_code = 'ABC-HOLD';

    INSERT INTO company (
        company_name, company_code, email, phone, city, state, country,
        pan_no, gstin_no, parent_company_id, company_type, corporate_group_name,
        subscription_plan, max_employees, subscription_paid_by, billing_company_id,
        inherit_masters_from_parent, hierarchy_level
    ) VALUES (
        'ABC Manufacturing Pvt Ltd', 'ABC-MFG', 'info@abcmfg.com', '+91-9876543211',
        'Bangalore', 'Karnataka', 'India', 'ABCMF1234G', '29ABCMF1234G1Z5',
        parent_id, 'subsidiary', 'ABC Group', 'enterprise', 200, 'parent',
        parent_id, true, 2
    ),
    (
        'ABC Services Pvt Ltd', 'ABC-SRV', 'info@abcservices.com', '+91-9876543212',
        'Pune', 'Maharashtra', 'India', 'ABCSV1234H', '27ABCSV1234H1Z5',
        parent_id, 'subsidiary', 'ABC Group', 'enterprise', 150, 'parent',
        parent_id, true, 2
    );
END $$;

-- Final verification
SELECT COUNT(*) as total_companies, array_agg(company_code ORDER BY company_code) as codes FROM company;
