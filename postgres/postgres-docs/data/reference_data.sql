-- ================================================================
-- Reference Data: Departments and Designations
--
-- Purpose: Master data shared across all tenants/companies
-- Usage: Run this in ALL environments (DEV, QA, PROD)
--
-- Note: These are shared master records (is_shared_master = true)
--       Individual companies can also create their own dept/designations
-- ================================================================

-- ================================================================
-- DEPARTMENT MASTER DATA
-- ================================================================
INSERT INTO department_master (id, department_code, department_name, department_description, is_shared_master, status, created_at, updated_at) VALUES
('11111111-1111-1111-1111-111111111111', 'TECH', 'Technology', 'Information Technology and Software Development', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('22222222-2222-2222-2222-222222222222', 'HR', 'Human Resources', 'People Operations and Talent Management', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('33333333-3333-3333-3333-333333333333', 'FIN', 'Finance', 'Financial Operations and Accounting', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('44444444-4444-4444-4444-444444444444', 'OPS', 'Operations', 'Business Operations and Administration', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('55555555-5555-5555-5555-555555555555', 'SALES', 'Sales & Marketing', 'Sales, Marketing and Business Development', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('66666666-6666-6666-6666-666666666666', 'CSERV', 'Customer Service', 'Customer Support and Relations', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('77777777-7777-7777-7777-777777777777', 'PROD', 'Production', 'Manufacturing and Production', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('88888888-8888-8888-8888-888888888888', 'QA', 'Quality Assurance', 'Quality Control and Testing', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('99999999-9999-9999-9999-999999999999', 'RND', 'Research & Development', 'Research, Innovation and Development', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ADMIN', 'Administration', 'General Administration', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- ================================================================
-- DESIGNATION MASTER DATA
-- Level 1 = C-Suite (highest)
-- Level 2 = VP/Director
-- Level 3 = Manager
-- Level 4 = Team Lead/Supervisor
-- Level 5 = Individual Contributor
-- Level 6 = Junior/Entry Level
-- ================================================================
INSERT INTO designation_master (id, designation_code, designation_name, designation_level, designation_description, is_shared_master, status, created_at, updated_at) VALUES
-- C-Suite (Level 1)
('d0000001-0000-0000-0000-000000000001', 'CEO', 'Chief Executive Officer', 1, 'Chief Executive Officer', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000002-0000-0000-0000-000000000002', 'CTO', 'Chief Technology Officer', 1, 'Chief Technology Officer', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000003-0000-0000-0000-000000000003', 'CFO', 'Chief Financial Officer', 1, 'Chief Financial Officer', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000004-0000-0000-0000-000000000004', 'COO', 'Chief Operating Officer', 1, 'Chief Operating Officer', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000005-0000-0000-0000-000000000005', 'CHRO', 'Chief Human Resources Officer', 1, 'Chief Human Resources Officer', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

-- VP/Director Level (Level 2)
('d0000006-0000-0000-0000-000000000006', 'VP', 'Vice President', 2, 'Vice President', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000007-0000-0000-0000-000000000007', 'DIR', 'Director', 2, 'Director', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000008-0000-0000-0000-000000000008', 'AVP', 'Assistant Vice President', 2, 'Assistant Vice President', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

-- Manager Level (Level 3)
('d0000009-0000-0000-0000-000000000009', 'GM', 'General Manager', 3, 'General Manager', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000010-0000-0000-0000-000000000010', 'MGR', 'Manager', 3, 'Manager', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000011-0000-0000-0000-000000000011', 'AMGR', 'Assistant Manager', 3, 'Assistant Manager', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

-- Team Lead/Supervisor (Level 4)
('d0000012-0000-0000-0000-000000000012', 'TL', 'Team Lead', 4, 'Team Lead', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000013-0000-0000-0000-000000000013', 'LEAD', 'Lead', 4, 'Technical or Project Lead', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000014-0000-0000-0000-000000000014', 'SUP', 'Supervisor', 4, 'Supervisor', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

-- Individual Contributors (Level 5)
('d0000015-0000-0000-0000-000000000015', 'SENG', 'Senior Engineer', 5, 'Senior Engineer/Specialist', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000016-0000-0000-0000-000000000016', 'ENG', 'Engineer', 5, 'Engineer/Analyst', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000017-0000-0000-0000-000000000017', 'SPEC', 'Specialist', 5, 'Domain Specialist', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000018-0000-0000-0000-000000000018', 'EXEC', 'Executive', 5, 'Executive (non-management)', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

-- Junior/Entry Level (Level 6)
('d0000019-0000-0000-0000-000000000019', 'JENG', 'Junior Engineer', 6, 'Junior Engineer/Associate', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000020-0000-0000-0000-000000000020', 'ASSOC', 'Associate', 6, 'Associate', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000021-0000-0000-0000-000000000021', 'INTERN', 'Intern', 6, 'Intern/Trainee', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0000022-0000-0000-0000-000000000022', 'TRAINEE', 'Trainee', 6, 'Trainee', true, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- ================================================================
-- Verification Query (optional - comment out for production)
-- ================================================================
-- SELECT 'Departments Loaded:', COUNT(*) FROM department_master WHERE is_shared_master = true;
-- SELECT 'Designations Loaded:', COUNT(*) FROM designation_master WHERE is_shared_master = true;
