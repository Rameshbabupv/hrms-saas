-- ================================================================
-- SaaS HRMS MVP: Audit Schema
-- PostgreSQL Database Schema for Comprehensive Audit Logging
--
-- Version: 1.0
-- Date: 2025-10-29
-- Purpose: Track all data changes, user actions, and system events
--
-- Audit Strategy:
-- 1. audit_log - General audit log for all table changes
-- 2. user_activity_log - User login/logout and session tracking
-- 3. api_audit_log - API request/response logging
-- 4. data_change_history - Detailed before/after snapshots
-- 5. security_event_log - Security-related events
-- ================================================================

-- Prerequisites: Main schema (saas_mvp_schema_v2_with_hierarchy.sql) must be deployed first

-- ================================================================
-- ENUMS for Audit
-- ================================================================

CREATE TYPE audit_action AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'SELECT', 'TRUNCATE');
CREATE TYPE event_severity AS ENUM ('INFO', 'WARNING', 'ERROR', 'CRITICAL');
CREATE TYPE event_category AS ENUM ('AUTHENTICATION', 'AUTHORIZATION', 'DATA_ACCESS', 'DATA_MODIFICATION', 'SECURITY', 'SYSTEM');

-- ================================================================
-- TABLE: audit_log
-- Purpose: General audit log for all database operations
-- Captures: Who did what, when, and from where
-- ================================================================
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,

    -- When and Who
    audit_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_id UUID,  -- From Keycloak (JWT sub claim)
    username VARCHAR(100),  -- From JWT preferred_username

    -- Tenant Context
    company_id UUID,  -- Which tenant (from session variable)
    tenant_id UUID,   -- Alias for company_id

    -- What Happened
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,  -- ID of the affected record
    action audit_action NOT NULL,

    -- Request Context
    ip_address VARCHAR(50),
    user_agent TEXT,
    session_id VARCHAR(255),
    request_id VARCHAR(100),  -- For tracing across services

    -- Change Details
    old_values JSONB,  -- Before state (for UPDATE/DELETE)
    new_values JSONB,  -- After state (for INSERT/UPDATE)
    changed_fields TEXT[],  -- Array of changed field names

    -- Additional Info
    description TEXT,
    metadata JSONB,  -- Additional context (API endpoint, GraphQL query, etc.)

    -- Performance
    execution_time_ms INTEGER,  -- How long the operation took

    -- Status
    success BOOLEAN DEFAULT true,
    error_message TEXT
);

-- Indexes for audit_log
CREATE INDEX idx_audit_log_timestamp ON audit_log(audit_timestamp DESC);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_company ON audit_log(company_id);
CREATE INDEX idx_audit_log_table ON audit_log(table_name);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_session ON audit_log(session_id);
CREATE INDEX idx_audit_log_request ON audit_log(request_id);

-- Partition audit_log by month for better performance
-- Enable after data grows
-- ALTER TABLE audit_log PARTITION BY RANGE (audit_timestamp);

-- ================================================================
-- TABLE: user_activity_log
-- Purpose: Track user login, logout, and session activities
-- ================================================================
CREATE TABLE user_activity_log (
    id BIGSERIAL PRIMARY KEY,

    -- Timestamp
    activity_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,

    -- User Info
    user_id UUID NOT NULL,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(100),

    -- Tenant Context
    company_id UUID NOT NULL,
    company_code VARCHAR(20),

    -- Activity Type
    activity_type VARCHAR(50) NOT NULL,  -- 'LOGIN', 'LOGOUT', 'TOKEN_REFRESH', 'PASSWORD_CHANGE', 'PROFILE_UPDATE'
    activity_status VARCHAR(20) NOT NULL,  -- 'SUCCESS', 'FAILED', 'BLOCKED'

    -- Session Info
    session_id VARCHAR(255),
    keycloak_session_id VARCHAR(255),

    -- Request Context
    ip_address VARCHAR(50),
    user_agent TEXT,
    device_type VARCHAR(50),  -- 'desktop', 'mobile', 'tablet'
    browser VARCHAR(100),
    os VARCHAR(100),
    location_country VARCHAR(100),
    location_city VARCHAR(100),

    -- Security Flags
    is_suspicious BOOLEAN DEFAULT false,
    risk_score INTEGER,  -- 0-100, higher = riskier

    -- Failure Details (for failed logins)
    failure_reason TEXT,
    login_attempt_count INTEGER,

    -- Additional Info
    metadata JSONB
);

-- Indexes for user_activity_log
CREATE INDEX idx_user_activity_timestamp ON user_activity_log(activity_timestamp DESC);
CREATE INDEX idx_user_activity_user ON user_activity_log(user_id);
CREATE INDEX idx_user_activity_company ON user_activity_log(company_id);
CREATE INDEX idx_user_activity_type ON user_activity_log(activity_type);
CREATE INDEX idx_user_activity_status ON user_activity_log(activity_status);
CREATE INDEX idx_user_activity_session ON user_activity_log(session_id);
CREATE INDEX idx_user_activity_ip ON user_activity_log(ip_address);
CREATE INDEX idx_user_activity_suspicious ON user_activity_log(is_suspicious) WHERE is_suspicious = true;

-- ================================================================
-- TABLE: api_audit_log
-- Purpose: Track all API requests and responses
-- For debugging, performance monitoring, and security
-- ================================================================
CREATE TABLE api_audit_log (
    id BIGSERIAL PRIMARY KEY,

    -- Timestamp
    request_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    response_timestamp TIMESTAMP WITH TIME ZONE,

    -- Request ID (for correlation)
    request_id VARCHAR(100) NOT NULL UNIQUE,
    trace_id VARCHAR(100),  -- For distributed tracing

    -- User Info
    user_id UUID,
    username VARCHAR(100),

    -- Tenant Context
    company_id UUID,

    -- Request Details
    http_method VARCHAR(10),  -- GET, POST, PUT, DELETE
    endpoint_path TEXT,
    query_params JSONB,

    -- GraphQL Specific (if applicable)
    graphql_operation_type VARCHAR(20),  -- 'query', 'mutation', 'subscription'
    graphql_operation_name VARCHAR(100),
    graphql_query TEXT,
    graphql_variables JSONB,

    -- Request Headers
    request_headers JSONB,
    user_agent TEXT,
    ip_address VARCHAR(50),

    -- Request Body
    request_body JSONB,
    request_size_bytes INTEGER,

    -- Response Details
    response_status_code INTEGER,
    response_body JSONB,
    response_size_bytes INTEGER,

    -- Performance
    execution_time_ms INTEGER,
    database_time_ms INTEGER,

    -- Errors
    has_error BOOLEAN DEFAULT false,
    error_type VARCHAR(100),
    error_message TEXT,
    error_stack_trace TEXT,

    -- Additional Context
    metadata JSONB
);

-- Indexes for api_audit_log
CREATE INDEX idx_api_audit_timestamp ON api_audit_log(request_timestamp DESC);
CREATE INDEX idx_api_audit_request_id ON api_audit_log(request_id);
CREATE INDEX idx_api_audit_trace_id ON api_audit_log(trace_id);
CREATE INDEX idx_api_audit_user ON api_audit_log(user_id);
CREATE INDEX idx_api_audit_company ON api_audit_log(company_id);
CREATE INDEX idx_api_audit_endpoint ON api_audit_log(endpoint_path);
CREATE INDEX idx_api_audit_method ON api_audit_log(http_method);
CREATE INDEX idx_api_audit_status ON api_audit_log(response_status_code);
CREATE INDEX idx_api_audit_errors ON api_audit_log(has_error) WHERE has_error = true;
CREATE INDEX idx_api_audit_graphql_op ON api_audit_log(graphql_operation_name);
CREATE INDEX idx_api_audit_slow_queries ON api_audit_log(execution_time_ms) WHERE execution_time_ms > 1000;

-- ================================================================
-- TABLE: data_change_history
-- Purpose: Detailed history of data changes with full snapshots
-- Use for: Compliance, rollback, "view as of date"
-- ================================================================
CREATE TABLE data_change_history (
    id BIGSERIAL PRIMARY KEY,

    -- When
    change_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,

    -- Who
    user_id UUID NOT NULL,
    username VARCHAR(100) NOT NULL,

    -- Tenant
    company_id UUID NOT NULL,

    -- What Table/Record
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,

    -- Change Type
    change_type audit_action NOT NULL,

    -- Full Snapshots
    before_snapshot JSONB,  -- Complete record before change
    after_snapshot JSONB,   -- Complete record after change

    -- Change Summary
    changed_fields JSONB,  -- { "field_name": { "old": "value1", "new": "value2" } }
    change_reason TEXT,

    -- Version Control
    version_number INTEGER,  -- Incremental version for this record

    -- Request Context
    request_id VARCHAR(100),
    session_id VARCHAR(255),
    ip_address VARCHAR(50),

    -- Metadata
    metadata JSONB,

    -- Retention
    retention_until TIMESTAMP WITH TIME ZONE,  -- When this record can be purged
    is_archived BOOLEAN DEFAULT false
);

-- Indexes for data_change_history
CREATE INDEX idx_data_change_timestamp ON data_change_history(change_timestamp DESC);
CREATE INDEX idx_data_change_user ON data_change_history(user_id);
CREATE INDEX idx_data_change_company ON data_change_history(company_id);
CREATE INDEX idx_data_change_table ON data_change_history(table_name);
CREATE INDEX idx_data_change_record ON data_change_history(table_name, record_id);
CREATE INDEX idx_data_change_version ON data_change_history(table_name, record_id, version_number);
CREATE INDEX idx_data_change_retention ON data_change_history(retention_until) WHERE is_archived = false;

-- ================================================================
-- TABLE: security_event_log
-- Purpose: Track security-related events (suspicious activities, violations)
-- ================================================================
CREATE TABLE security_event_log (
    id BIGSERIAL PRIMARY KEY,

    -- When
    event_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,

    -- Severity
    severity event_severity NOT NULL,
    category event_category NOT NULL,

    -- Event Details
    event_type VARCHAR(100) NOT NULL,  -- 'FAILED_LOGIN', 'UNAUTHORIZED_ACCESS', 'SQL_INJECTION_ATTEMPT', etc.
    event_description TEXT NOT NULL,

    -- User Info (if applicable)
    user_id UUID,
    username VARCHAR(100),

    -- Tenant Context (if applicable)
    company_id UUID,

    -- Request Context
    ip_address VARCHAR(50),
    user_agent TEXT,
    request_path TEXT,

    -- Detection Details
    detection_method VARCHAR(100),  -- 'RLS_VIOLATION', 'INVALID_TOKEN', 'RATE_LIMIT_EXCEEDED'
    detection_rule VARCHAR(255),

    -- Impact Assessment
    was_blocked BOOLEAN DEFAULT false,
    potential_damage VARCHAR(50),  -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'

    -- Response Actions
    action_taken TEXT,  -- What was done about it
    assigned_to VARCHAR(100),  -- Security team member

    -- Status
    status VARCHAR(50) DEFAULT 'OPEN',  -- 'OPEN', 'INVESTIGATING', 'RESOLVED', 'FALSE_POSITIVE'
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT,

    -- Additional Data
    metadata JSONB
);

-- Indexes for security_event_log
CREATE INDEX idx_security_event_timestamp ON security_event_log(event_timestamp DESC);
CREATE INDEX idx_security_event_severity ON security_event_log(severity);
CREATE INDEX idx_security_event_category ON security_event_log(category);
CREATE INDEX idx_security_event_type ON security_event_log(event_type);
CREATE INDEX idx_security_event_user ON security_event_log(user_id);
CREATE INDEX idx_security_event_company ON security_event_log(company_id);
CREATE INDEX idx_security_event_ip ON security_event_log(ip_address);
CREATE INDEX idx_security_event_status ON security_event_log(status) WHERE status != 'RESOLVED';
CREATE INDEX idx_security_event_critical ON security_event_log(severity, event_timestamp DESC)
    WHERE severity IN ('ERROR', 'CRITICAL');

-- ================================================================
-- TABLE: compliance_audit_trail
-- Purpose: Specific audit trail for compliance requirements (GDPR, SOC2, etc.)
-- ================================================================
CREATE TABLE compliance_audit_trail (
    id BIGSERIAL PRIMARY KEY,

    -- When
    event_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,

    -- Compliance Framework
    compliance_type VARCHAR(50) NOT NULL,  -- 'GDPR', 'SOC2', 'HIPAA', 'ISO27001'
    requirement_id VARCHAR(100),  -- Specific requirement (e.g., 'GDPR-Art-17' for right to erasure)

    -- Event
    event_category VARCHAR(100) NOT NULL,  -- 'DATA_ACCESS', 'DATA_EXPORT', 'DATA_DELETION', 'CONSENT_CHANGE'
    event_description TEXT NOT NULL,

    -- Subject (whose data was affected)
    subject_type VARCHAR(50),  -- 'EMPLOYEE', 'USER', 'CUSTOMER'
    subject_id UUID,
    subject_name VARCHAR(200),

    -- Actor (who performed the action)
    actor_user_id UUID NOT NULL,
    actor_username VARCHAR(100) NOT NULL,

    -- Tenant
    company_id UUID NOT NULL,

    -- Data Details
    data_categories TEXT[],  -- ['personal_info', 'financial_data', 'health_data']
    data_scope TEXT,  -- What data was affected
    data_snapshot JSONB,  -- Copy of affected data

    -- Legal Basis (for GDPR)
    legal_basis VARCHAR(100),  -- 'consent', 'contract', 'legitimate_interest', etc.
    consent_id UUID,  -- Reference to consent record

    -- Request Context
    request_id VARCHAR(100),
    request_source VARCHAR(100),  -- 'USER_PORTAL', 'ADMIN_PANEL', 'API', 'SUPPORT_TICKET'

    -- Retention
    retention_period VARCHAR(50),  -- '7_years', 'permanent', 'until_consent_revoked'
    can_be_deleted BOOLEAN DEFAULT false,
    deletion_date TIMESTAMP WITH TIME ZONE,

    -- Verification
    verified_by UUID,
    verified_at TIMESTAMP WITH TIME ZONE,

    -- Additional Info
    metadata JSONB
);

-- Indexes for compliance_audit_trail
CREATE INDEX idx_compliance_timestamp ON compliance_audit_trail(event_timestamp DESC);
CREATE INDEX idx_compliance_type ON compliance_audit_trail(compliance_type);
CREATE INDEX idx_compliance_requirement ON compliance_audit_trail(requirement_id);
CREATE INDEX idx_compliance_subject ON compliance_audit_trail(subject_type, subject_id);
CREATE INDEX idx_compliance_actor ON compliance_audit_trail(actor_user_id);
CREATE INDEX idx_compliance_company ON compliance_audit_trail(company_id);
CREATE INDEX idx_compliance_category ON compliance_audit_trail(event_category);
CREATE INDEX idx_compliance_retention ON compliance_audit_trail(retention_period);

-- ================================================================
-- HELPER FUNCTIONS for Audit Logging
-- ================================================================

-- Function to log audit entry
CREATE OR REPLACE FUNCTION log_audit_entry(
    p_table_name VARCHAR,
    p_record_id UUID,
    p_action audit_action,
    p_old_values JSONB,
    p_new_values JSONB,
    p_description TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_audit_id BIGINT;
    v_user_id UUID;
    v_company_id UUID;
    v_changed_fields TEXT[];
BEGIN
    -- Get current user and tenant from session
    BEGIN
        v_user_id := current_setting('app.current_user_id', true)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;

    BEGIN
        v_company_id := current_setting('app.current_tenant_id', true)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_company_id := NULL;
    END;

    -- Calculate changed fields (for UPDATE)
    IF p_action = 'UPDATE' AND p_old_values IS NOT NULL AND p_new_values IS NOT NULL THEN
        SELECT ARRAY_AGG(key)
        INTO v_changed_fields
        FROM jsonb_each(p_new_values)
        WHERE p_old_values->key IS DISTINCT FROM p_new_values->key;
    END IF;

    -- Insert audit log
    INSERT INTO audit_log (
        user_id,
        company_id,
        tenant_id,
        table_name,
        record_id,
        action,
        old_values,
        new_values,
        changed_fields,
        description
    ) VALUES (
        v_user_id,
        v_company_id,
        v_company_id,
        p_table_name,
        p_record_id,
        p_action,
        p_old_values,
        p_new_values,
        v_changed_fields,
        p_description
    )
    RETURNING id INTO v_audit_id;

    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log data change history with versioning
CREATE OR REPLACE FUNCTION log_data_change_history(
    p_table_name VARCHAR,
    p_record_id UUID,
    p_change_type audit_action,
    p_before_snapshot JSONB,
    p_after_snapshot JSONB,
    p_change_reason TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_history_id BIGINT;
    v_user_id UUID;
    v_company_id UUID;
    v_username VARCHAR;
    v_version_number INTEGER;
    v_changed_fields JSONB;
    v_field_name TEXT;
    v_old_value JSONB;
    v_new_value JSONB;
BEGIN
    -- Get current context
    v_user_id := current_setting('app.current_user_id', true)::UUID;
    v_company_id := current_setting('app.current_tenant_id', true)::UUID;
    v_username := current_setting('app.current_username', true);

    -- Get next version number
    SELECT COALESCE(MAX(version_number), 0) + 1
    INTO v_version_number
    FROM data_change_history
    WHERE table_name = p_table_name AND record_id = p_record_id;

    -- Build changed fields JSON
    IF p_change_type = 'UPDATE' THEN
        v_changed_fields := '{}';
        FOR v_field_name IN SELECT jsonb_object_keys(p_after_snapshot)
        LOOP
            v_old_value := p_before_snapshot->v_field_name;
            v_new_value := p_after_snapshot->v_field_name;

            IF v_old_value IS DISTINCT FROM v_new_value THEN
                v_changed_fields := v_changed_fields || jsonb_build_object(
                    v_field_name,
                    jsonb_build_object('old', v_old_value, 'new', v_new_value)
                );
            END IF;
        END LOOP;
    END IF;

    -- Insert history record
    INSERT INTO data_change_history (
        user_id,
        username,
        company_id,
        table_name,
        record_id,
        change_type,
        before_snapshot,
        after_snapshot,
        changed_fields,
        change_reason,
        version_number,
        retention_until
    ) VALUES (
        v_user_id,
        v_username,
        v_company_id,
        p_table_name,
        p_record_id,
        p_change_type,
        p_before_snapshot,
        p_after_snapshot,
        v_changed_fields,
        p_change_reason,
        v_version_number,
        CURRENT_TIMESTAMP + INTERVAL '7 years'  -- Default retention
    )
    RETURNING id INTO v_history_id;

    RETURN v_history_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- TRIGGERS for Automatic Audit Logging
-- ================================================================

-- Generic trigger function for audit logging
CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    v_old_values JSONB;
    v_new_values JSONB;
    v_action audit_action;
BEGIN
    -- Determine action
    IF TG_OP = 'INSERT' THEN
        v_action := 'INSERT';
        v_old_values := NULL;
        v_new_values := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
        v_old_values := to_jsonb(OLD);
        v_new_values := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_action := 'DELETE';
        v_old_values := to_jsonb(OLD);
        v_new_values := NULL;
    END IF;

    -- Log audit entry
    PERFORM log_audit_entry(
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        v_action,
        v_old_values,
        v_new_values,
        'Automatic audit log from trigger'
    );

    -- Log data change history (for important tables)
    IF TG_TABLE_NAME IN ('company', 'employee') THEN
        PERFORM log_data_change_history(
            TG_TABLE_NAME,
            COALESCE(NEW.id, OLD.id),
            v_action,
            v_old_values,
            v_new_values,
            'Automatic history tracking'
        );
    END IF;

    -- Return appropriate record
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to core tables
CREATE TRIGGER audit_company_changes
    AFTER INSERT OR UPDATE OR DELETE ON company
    FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

CREATE TRIGGER audit_employee_changes
    AFTER INSERT OR UPDATE OR DELETE ON employee
    FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

CREATE TRIGGER audit_department_changes
    AFTER INSERT OR UPDATE OR DELETE ON department_master
    FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

CREATE TRIGGER audit_designation_changes
    AFTER INSERT OR UPDATE OR DELETE ON designation_master
    FOR EACH ROW EXECUTE FUNCTION trigger_audit_log();

-- ================================================================
-- MAINTENANCE FUNCTIONS
-- ================================================================

-- Function to purge old audit logs (run monthly)
CREATE OR REPLACE FUNCTION purge_old_audit_logs(retention_days INTEGER DEFAULT 365)
RETURNS TABLE(table_name TEXT, rows_deleted BIGINT) AS $$
BEGIN
    -- Purge audit_log
    DELETE FROM audit_log
    WHERE audit_timestamp < CURRENT_TIMESTAMP - (retention_days || ' days')::INTERVAL;

    table_name := 'audit_log';
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    RETURN NEXT;

    -- Purge user_activity_log
    DELETE FROM user_activity_log
    WHERE activity_timestamp < CURRENT_TIMESTAMP - (retention_days || ' days')::INTERVAL;

    table_name := 'user_activity_log';
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    RETURN NEXT;

    -- Purge api_audit_log
    DELETE FROM api_audit_log
    WHERE request_timestamp < CURRENT_TIMESTAMP - (retention_days || ' days')::INTERVAL;

    table_name := 'api_audit_log';
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    RETURN NEXT;

    -- Archive (don't delete) data_change_history
    UPDATE data_change_history
    SET is_archived = true
    WHERE change_timestamp < CURRENT_TIMESTAMP - (retention_days || ' days')::INTERVAL
    AND is_archived = false;

    table_name := 'data_change_history (archived)';
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to get audit statistics
CREATE OR REPLACE FUNCTION get_audit_statistics()
RETURNS TABLE(
    metric_name TEXT,
    metric_value BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'Total Audit Logs'::TEXT, COUNT(*)::BIGINT FROM audit_log
    UNION ALL
    SELECT 'Audit Logs (Last 30 Days)', COUNT(*)::BIGINT
        FROM audit_log WHERE audit_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
    UNION ALL
    SELECT 'User Activities (Last 30 Days)', COUNT(*)::BIGINT
        FROM user_activity_log WHERE activity_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
    UNION ALL
    SELECT 'API Calls (Last 30 Days)', COUNT(*)::BIGINT
        FROM api_audit_log WHERE request_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
    UNION ALL
    SELECT 'Security Events (Open)', COUNT(*)::BIGINT
        FROM security_event_log WHERE status != 'RESOLVED'
    UNION ALL
    SELECT 'Data Changes (Last 30 Days)', COUNT(*)::BIGINT
        FROM data_change_history WHERE change_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- SAMPLE AUDIT DATA (for testing)
-- ================================================================

-- Example: Log a user login
INSERT INTO user_activity_log (
    user_id, username, email, company_id, company_code,
    activity_type, activity_status, session_id,
    ip_address, user_agent, device_type
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'john.doe@company.com',
    'john.doe@company.com',
    '550e8400-e29b-41d4-a716-446655440001',
    'DEMO001',
    'LOGIN',
    'SUCCESS',
    'session-uuid-12345',
    '192.168.1.100',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'desktop'
);

-- Example: Log a security event
INSERT INTO security_event_log (
    severity, category, event_type, event_description,
    user_id, username, company_id, ip_address,
    was_blocked, potential_damage
) VALUES (
    'WARNING',
    'AUTHORIZATION',
    'UNAUTHORIZED_ACCESS_ATTEMPT',
    'User attempted to access data from another tenant',
    '550e8400-e29b-41d4-a716-446655440000',
    'john.doe@company.com',
    '550e8400-e29b-41d4-a716-446655440001',
    '192.168.1.100',
    true,
    'HIGH'
);

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- View recent audit logs
-- SELECT
--     audit_timestamp,
--     username,
--     table_name,
--     action,
--     changed_fields,
--     description
-- FROM audit_log
-- ORDER BY audit_timestamp DESC
-- LIMIT 20;

-- View failed login attempts
-- SELECT
--     activity_timestamp,
--     username,
--     ip_address,
--     failure_reason
-- FROM user_activity_log
-- WHERE activity_type = 'LOGIN' AND activity_status = 'FAILED'
-- ORDER BY activity_timestamp DESC;

-- View security events
-- SELECT
--     event_timestamp,
--     severity,
--     event_type,
--     event_description,
--     username,
--     ip_address,
--     status
-- FROM security_event_log
-- WHERE status != 'RESOLVED'
-- ORDER BY event_timestamp DESC;

-- View data change history for a specific record
-- SELECT
--     change_timestamp,
--     username,
--     change_type,
--     version_number,
--     changed_fields
-- FROM data_change_history
-- WHERE table_name = 'employee' AND record_id = '<employee-uuid>'
-- ORDER BY version_number DESC;

-- Get audit statistics
-- SELECT * FROM get_audit_statistics();
