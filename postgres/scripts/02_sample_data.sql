-- ================================================================
-- Sample Test Data for HRMS SaaS
-- ================================================================

-- Insert parent company (ABC Group)
INSERT INTO company (
    company_name, company_code, email, phone,
    city, state, country,
    pan_no, gstin_no,
    company_type, is_parent, corporate_group_name,
    subscription_plan, max_employees, is_trial,
    subscription_paid_by, share_masters_with_group,
    hierarchy_level
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
    true,
    1
);

-- Get the parent company ID for use in child inserts
DO $$
DECLARE
    abc_parent_id UUID;
BEGIN
    SELECT id INTO abc_parent_id FROM company WHERE company_code = 'ABC-HOLD';

    -- Insert ABC Manufacturing (subsidiary)
    INSERT INTO company (
        company_name, company_code, email, phone,
        city, state, country,
        pan_no, gstin_no,
        parent_company_id, company_type, corporate_group_name,
        subscription_plan, max_employees,
        subscription_paid_by, billing_company_id,
        inherit_masters_from_parent, hierarchy_level
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
        abc_parent_id,
        'subsidiary',
        'ABC Group',
        'enterprise',
        200,
        'parent',
        abc_parent_id,
        true,
        2
    );

    -- Insert ABC Services (subsidiary)
    INSERT INTO company (
        company_name, company_code, email, phone,
        city, state, country,
        pan_no, gstin_no,
        parent_company_id, company_type, corporate_group_name,
        subscription_plan, max_employees,
        subscription_paid_by, billing_company_id,
        inherit_masters_from_parent, hierarchy_level
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
        abc_parent_id,
        'subsidiary',
        'ABC Group',
        'enterprise',
        150,
        'parent',
        abc_parent_id,
        true,
        2
    );
END $$;

-- Insert independent company (for comparison)
INSERT INTO company (
    company_name, company_code, email, phone,
    city, state, country,
    pan_no, gstin_no,
    company_type, corporate_group_name,
    subscription_plan, max_employees, is_trial,
    hierarchy_level
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
    true,
    1
);

-- Insert shared departments for ABC Group
DO $$
DECLARE
    abc_holding_id UUID;
BEGIN
    SELECT id INTO abc_holding_id FROM company WHERE company_code = 'ABC-HOLD';

    INSERT INTO department_master (
        owner_company_id, department_code, department_name,
        is_shared, shared_with_group
    ) VALUES
        (abc_holding_id, 'HR', 'Human Resources', true, 'ABC Group'),
        (abc_holding_id, 'IT', 'Information Technology', true, 'ABC Group'),
        (abc_holding_id, 'FIN', 'Finance', true, 'ABC Group'),
        (abc_holding_id, 'OPS', 'Operations', true, 'ABC Group'),
        (abc_holding_id, 'MKT', 'Marketing', true, 'ABC Group');
END $$;

-- Insert shared designations for ABC Group
DO $$
DECLARE
    abc_holding_id UUID;
BEGIN
    SELECT id INTO abc_holding_id FROM company WHERE company_code = 'ABC-HOLD';

    INSERT INTO designation_master (
        owner_company_id, designation_code, designation_name,
        is_shared, shared_with_group
    ) VALUES
        (abc_holding_id, 'CEO', 'Chief Executive Officer', true, 'ABC Group'),
        (abc_holding_id, 'CFO', 'Chief Financial Officer', true, 'ABC Group'),
        (abc_holding_id, 'CTO', 'Chief Technology Officer', true, 'ABC Group'),
        (abc_holding_id, 'MGR', 'Manager', true, 'ABC Group'),
        (abc_holding_id, 'EXEC', 'Executive', true, 'ABC Group'),
        (abc_holding_id, 'ASST', 'Assistant', true, 'ABC Group');
END $$;

-- Insert sample employees across companies
DO $$
DECLARE
    abc_holding_id UUID;
    abc_mfg_id UUID;
    abc_srv_id UUID;
    demo_id UUID;
    ceo_id UUID;
    mgr1_id UUID;
    mgr2_id UUID;
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

    -- ABC Holdings CFO
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_holding_id, 'ABCH002', 'Sunita Mehta', 'sunita.mehta@abcgroup.com', '+91-9876543231',
        '1980-08-25', 'female', 'married',
        '2016-03-15', 'permanent', 'Chief Financial Officer', 'Finance',
        800000.00, 720000.00
    );

    -- ABC Manufacturing Manager
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_mfg_id, 'ABCM001', 'Priya Sharma', 'priya.sharma@abcmfg.com', '+91-9876543232',
        '1985-08-20', 'female', 'single',
        '2018-06-15', 'permanent', 'Manager', 'Human Resources',
        150000.00, 135000.00
    ) RETURNING id INTO mgr1_id;

    -- ABC Manufacturing Executive
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        reporting_manager_id,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_mfg_id, 'ABCM002', 'Vikram Singh', 'vikram.singh@abcmfg.com', '+91-9876543233',
        '1990-12-10', 'male', 'married',
        '2019-08-01', 'permanent', 'Executive', 'Operations',
        mgr1_id,
        100000.00, 90000.00
    );

    -- ABC Services Manager
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_srv_id, 'ABCS001', 'Amit Patel', 'amit.patel@abcservices.com', '+91-9876543234',
        '1988-03-10', 'male', 'married',
        '2020-03-01', 'permanent', 'Manager', 'Information Technology',
        120000.00, 108000.00
    ) RETURNING id INTO mgr2_id;

    -- ABC Services Executive
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        reporting_manager_id,
        monthly_ctc, monthly_gross
    ) VALUES (
        abc_srv_id, 'ABCS002', 'Neha Gupta', 'neha.gupta@abcservices.com', '+91-9876543235',
        '1992-06-18', 'female', 'single',
        '2021-01-15', 'permanent', 'Executive', 'Information Technology',
        mgr2_id,
        90000.00, 81000.00
    );

    -- Demo Company Manager
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        demo_id, 'DEMO001', 'Sunita Reddy', 'sunita.reddy@demotech.com', '+91-9876543236',
        '1987-11-25', 'female', 'married',
        '2021-01-15', 'permanent', 'Manager', 'Operations',
        120000.00, 108000.00
    );

    -- Demo Company Executive
    INSERT INTO employee (
        company_id, employee_code, employee_name, email, mobile_no,
        date_of_birth, gender, marital_status,
        date_of_joining, employment_type, designation, department,
        monthly_ctc, monthly_gross
    ) VALUES (
        demo_id, 'DEMO002', 'Karthik Iyer', 'karthik.iyer@demotech.com', '+91-9876543237',
        '1993-04-08', 'male', 'single',
        '2022-06-01', 'permanent', 'Executive', 'Technology',
        85000.00, 76500.00
    );
END $$;

-- Insert some sample education records
DO $$
DECLARE
    emp_id UUID;
BEGIN
    -- Get Rajesh Kumar's ID
    SELECT id INTO emp_id FROM employee WHERE employee_code = 'ABCH001';

    INSERT INTO employee_education (employee_id, degree, institution, specialization, year_of_passing, percentage)
    VALUES
        (emp_id, 'B.Tech', 'IIT Bombay', 'Computer Science', 1997, 85.50),
        (emp_id, 'MBA', 'IIM Ahmedabad', 'Finance', 2000, 88.20);

    -- Get Priya Sharma's ID
    SELECT id INTO emp_id FROM employee WHERE employee_code = 'ABCM001';

    INSERT INTO employee_education (employee_id, degree, institution, specialization, year_of_passing, percentage)
    VALUES
        (emp_id, 'B.Com', 'Delhi University', 'Human Resources', 2007, 78.40),
        (emp_id, 'MBA', 'Symbiosis', 'HR Management', 2010, 82.10);
END $$;

-- Insert some sample work experience records
DO $$
DECLARE
    emp_id UUID;
BEGIN
    -- Get Rajesh Kumar's ID
    SELECT id INTO emp_id FROM employee WHERE employee_code = 'ABCH001';

    INSERT INTO employee_experience (employee_id, company_name, designation, from_date, to_date, responsibilities)
    VALUES
        (emp_id, 'XYZ Corp', 'Senior Manager', '2005-01-01', '2010-12-31', 'Led technology team of 20+ engineers'),
        (emp_id, 'Tech Solutions Inc', 'Director', '2011-01-01', '2014-12-31', 'Managed multiple product lines');

    -- Get Amit Patel's ID
    SELECT id INTO emp_id FROM employee WHERE employee_code = 'ABCS001';

    INSERT INTO employee_experience (employee_id, company_name, designation, from_date, to_date, responsibilities)
    VALUES
        (emp_id, 'InfoTech Ltd', 'Developer', '2012-06-01', '2016-05-31', 'Full-stack development'),
        (emp_id, 'Digital Services', 'Team Lead', '2016-06-01', '2020-02-28', 'Led development team of 8 members');
END $$;

-- Verification: Show data summary
SELECT 'Companies Created' as info, COUNT(*)::text as count FROM company
UNION ALL
SELECT 'Employees Created', COUNT(*)::text FROM employee
UNION ALL
SELECT 'Departments Created', COUNT(*)::text FROM department_master
UNION ALL
SELECT 'Designations Created', COUNT(*)::text FROM designation_master
UNION ALL
SELECT 'Education Records', COUNT(*)::text FROM employee_education
UNION ALL
SELECT 'Experience Records', COUNT(*)::text FROM employee_experience;
