-- =============================================
-- DISPATCH V1: App Compatibility Migration
-- Contract-level version compatibility for blocking outdated clients
-- =============================================

-- =============================================
-- APP_COMPAT TABLE
-- Stores minimum compatible app versions and migration requirements
-- =============================================
CREATE TABLE IF NOT EXISTS app_compat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,                -- 'ios', 'macos', 'android', 'web'
    min_version TEXT NOT NULL,             -- Semantic version: '1.0.0'
    current_version TEXT NOT NULL,         -- Latest available version
    migration_required BOOLEAN DEFAULT FALSE,
    force_update BOOLEAN DEFAULT FALSE,    -- If true, block until updated
    deprecated_at TIMESTAMPTZ,             -- When this version was deprecated
    notes TEXT,                            -- Human-readable notes about changes
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for platform lookup (primary query pattern)
CREATE INDEX IF NOT EXISTS idx_app_compat_platform ON app_compat(platform);

-- RLS: All authenticated users can read (they need to check compat)
ALTER TABLE app_compat ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_compat_read" ON app_compat;
CREATE POLICY "app_compat_read" ON app_compat FOR SELECT TO authenticated
USING (true);

-- Only service role can modify (admin-only via Supabase dashboard or API)
DROP POLICY IF EXISTS "app_compat_admin_write" ON app_compat;
CREATE POLICY "app_compat_admin_write" ON app_compat FOR ALL TO service_role
USING (true);

-- Updated_at trigger
DROP TRIGGER IF EXISTS update_app_compat_updated_at ON app_compat;
CREATE TRIGGER update_app_compat_updated_at
    BEFORE UPDATE ON app_compat
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- INITIAL DATA
-- Set up initial version compatibility records
-- =============================================
INSERT INTO app_compat (platform, min_version, current_version, notes)
VALUES ('ios', '1.0.0', '1.0.0', 'Initial V1 release')
ON CONFLICT DO NOTHING;

-- =============================================
-- HELPER FUNCTION
-- Check if a client version is compatible
-- Usage: SELECT check_version_compat('ios', '1.0.0')
-- Returns: JSON { compatible: bool, min_version: string, current_version: string, force_update: bool }
-- =============================================
CREATE OR REPLACE FUNCTION check_version_compat(
    p_platform TEXT,
    p_client_version TEXT
)
RETURNS JSON AS $$
DECLARE
    v_record app_compat%ROWTYPE;
    v_client_parts INTEGER[];
    v_min_parts INTEGER[];
    v_compatible BOOLEAN := TRUE;
BEGIN
    -- Get the compat record for this platform
    SELECT * INTO v_record FROM app_compat WHERE platform = p_platform LIMIT 1;

    IF NOT FOUND THEN
        -- No compat record means no restrictions
        RETURN json_build_object(
            'compatible', TRUE,
            'min_version', NULL,
            'current_version', NULL,
            'force_update', FALSE,
            'message', 'No compatibility record found'
        );
    END IF;

    -- Parse version strings into arrays (assumes semver: X.Y.Z)
    v_client_parts := string_to_array(p_client_version, '.')::INTEGER[];
    v_min_parts := string_to_array(v_record.min_version, '.')::INTEGER[];

    -- Compare versions (major.minor.patch)
    IF v_client_parts[1] < v_min_parts[1] THEN
        v_compatible := FALSE;
    ELSIF v_client_parts[1] = v_min_parts[1] THEN
        IF v_client_parts[2] < v_min_parts[2] THEN
            v_compatible := FALSE;
        ELSIF v_client_parts[2] = v_min_parts[2] THEN
            IF COALESCE(v_client_parts[3], 0) < COALESCE(v_min_parts[3], 0) THEN
                v_compatible := FALSE;
            END IF;
        END IF;
    END IF;

    RETURN json_build_object(
        'compatible', v_compatible,
        'min_version', v_record.min_version,
        'current_version', v_record.current_version,
        'force_update', v_record.force_update AND NOT v_compatible,
        'migration_required', v_record.migration_required,
        'message', CASE
            WHEN NOT v_compatible AND v_record.force_update THEN 'Update required. Please update to continue.'
            WHEN NOT v_compatible THEN 'Update available. Please update for the best experience.'
            ELSE 'App is up to date.'
        END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_version_compat(TEXT, TEXT) TO authenticated;

-- =============================================
-- VERIFICATION
-- =============================================
-- Test the function:
-- SELECT check_version_compat('ios', '1.0.0');
-- SELECT check_version_compat('ios', '0.9.0');
