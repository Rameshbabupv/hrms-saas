-- ================================================================
-- Fix Audit Trigger Type Casting Issue
-- This script drops and recreates the audit trigger function with proper type casting
-- ================================================================

-- Step 1: Drop function with CASCADE (will drop all dependent triggers)
DROP FUNCTION IF EXISTS public.trigger_audit_log() CASCADE;

-- Step 2: Recreate the function with proper type casting
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

    -- Log audit entry with explicit type cast - THIS IS THE FIX
    PERFORM log_audit_entry(
        TG_TABLE_NAME::VARCHAR,  -- Cast name type to VARCHAR
        COALESCE(NEW.id, OLD.id),
        v_action,
        v_old_values,
        v_new_values,
        'Automatic audit log from trigger'
    );

    -- Log data change history (for important tables)
    IF TG_TABLE_NAME IN ('company', 'employee') THEN
        PERFORM log_data_change_history(
            TG_TABLE_NAME::VARCHAR,  -- Cast name type to VARCHAR
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

-- Step 3: Recreate all audit triggers
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

-- Step 4: Verify the fix
SELECT 'Audit trigger function fixed and triggers recreated' AS status;

-- Show triggers created
SELECT
    c.relname AS table_name,
    t.tgname AS trigger_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
AND t.tgname LIKE 'audit_%'
ORDER BY c.relname, t.tgname;
