-- ================================================================
-- V1: Initialize Extensions and Enums
-- Description: Setup UUID extension and common enums for HRMS system
-- Date: 2025-11-06
-- ================================================================

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Common enums
CREATE TYPE status_type AS ENUM ('active', 'inactive', 'deleted');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE employment_type AS ENUM ('permanent', 'contract', 'consultant', 'intern', 'temporary');
CREATE TYPE marital_status_type AS ENUM ('single', 'married', 'divorced', 'widowed');
CREATE TYPE company_type AS ENUM ('holding', 'subsidiary', 'independent');
CREATE TYPE subscription_paid_by AS ENUM ('self', 'parent', 'external');

-- Add comments
COMMENT ON EXTENSION "uuid-ossp" IS 'UUID generation functions';
COMMENT ON TYPE status_type IS 'Generic status for records';
COMMENT ON TYPE employment_type IS 'Employee contract types';
COMMENT ON TYPE company_type IS 'Corporate hierarchy types';
