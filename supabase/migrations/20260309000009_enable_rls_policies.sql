-- Migration 009: Row-Level Security policies
-- Enforces multi-tenant data isolation at the database level.
-- Traceability: FR-1.2, SEC-2

-- ============================================================
-- Helper: extract org_id from Supabase Auth JWT
-- NOTE: Uses public schema because auth schema is restricted on hosted Supabase
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.schemata
        WHERE schema_name = 'auth'
    ) THEN
        EXECUTE 'CREATE SCHEMA auth';
        EXECUTE $fn$
            CREATE FUNCTION auth.jwt() RETURNS JSONB AS $inner$
                SELECT COALESCE(
                    NULLIF(current_setting('request.jwt.claims', true), ''),
                    '{"app_metadata": {}}'
                )::JSONB;
            $inner$ LANGUAGE sql STABLE
        $fn$;
    END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.get_org_id() RETURNS UUID AS $$
    SELECT (auth.jwt() -> 'app_metadata' ->> 'org_id')::UUID;
$$ LANGUAGE sql STABLE;

-- Helper: extract role from Supabase Auth JWT
CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS TEXT AS $$
    SELECT auth.jwt() -> 'app_metadata' ->> 'role';
$$ LANGUAGE sql STABLE;

-- ============================================================
-- Enable RLS on all tenant-scoped tables
-- ============================================================
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE cameras ENABLE ROW LEVEL SECURITY;
ALTER TABLE roi_presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE counting_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_crossings ENABLE ROW LEVEL SECURITY;
ALTER TABLE agg_vehicle_counts_15m ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE config_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_retention_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_report_links ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- organizations: users can only see their own org
-- ============================================================
CREATE POLICY org_select ON organizations
    FOR SELECT USING (id = public.get_org_id());

CREATE POLICY org_update ON organizations
    FOR UPDATE USING (id = public.get_org_id() AND public.get_user_role() = 'admin')
    WITH CHECK (id = public.get_org_id());

-- ============================================================
-- users: org-scoped access
-- ============================================================
CREATE POLICY users_select ON users
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY users_insert ON users
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() = 'admin'
    );

CREATE POLICY users_update ON users
    FOR UPDATE USING (org_id = public.get_org_id() AND public.get_user_role() = 'admin')
    WITH CHECK (org_id = public.get_org_id());

CREATE POLICY users_delete ON users
    FOR DELETE USING (org_id = public.get_org_id() AND public.get_user_role() = 'admin');

-- ============================================================
-- sites: all roles can read, admin/operator can write
-- ============================================================
CREATE POLICY sites_select ON sites
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY sites_insert ON sites
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

CREATE POLICY sites_update ON sites
    FOR UPDATE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    ) WITH CHECK (org_id = public.get_org_id());

CREATE POLICY sites_delete ON sites
    FOR DELETE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() = 'admin'
    );

-- ============================================================
-- cameras: all roles can read, admin/operator can write
-- ============================================================
CREATE POLICY cameras_select ON cameras
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY cameras_insert ON cameras
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

CREATE POLICY cameras_update ON cameras
    FOR UPDATE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    ) WITH CHECK (org_id = public.get_org_id());

CREATE POLICY cameras_delete ON cameras
    FOR DELETE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

-- ============================================================
-- roi_presets: all roles can read, admin/operator can write
-- ============================================================
CREATE POLICY roi_presets_select ON roi_presets
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY roi_presets_insert ON roi_presets
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

CREATE POLICY roi_presets_update ON roi_presets
    FOR UPDATE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    ) WITH CHECK (org_id = public.get_org_id());

CREATE POLICY roi_presets_delete ON roi_presets
    FOR DELETE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

-- ============================================================
-- counting_lines: all roles can read, admin/operator can write
-- ============================================================
CREATE POLICY counting_lines_select ON counting_lines
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY counting_lines_insert ON counting_lines
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

CREATE POLICY counting_lines_update ON counting_lines
    FOR UPDATE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    ) WITH CHECK (org_id = public.get_org_id());

CREATE POLICY counting_lines_delete ON counting_lines
    FOR DELETE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

-- ============================================================
-- vehicle_crossings: org-scoped read, service-role insert
-- No FK constraints on this high-volume table for write perf.
-- ============================================================
CREATE POLICY vc_select ON vehicle_crossings
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY vc_insert ON vehicle_crossings
    FOR INSERT WITH CHECK (org_id = public.get_org_id());

-- ============================================================
-- agg_vehicle_counts_15m: org-scoped read, service-role insert/update
-- ============================================================
CREATE POLICY agg_select ON agg_vehicle_counts_15m
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY agg_insert ON agg_vehicle_counts_15m
    FOR INSERT WITH CHECK (org_id = public.get_org_id());

CREATE POLICY agg_update ON agg_vehicle_counts_15m
    FOR UPDATE USING (org_id = public.get_org_id())
    WITH CHECK (org_id = public.get_org_id());

-- ============================================================
-- alert_rules: all roles can read, admin/operator can write
-- ============================================================
CREATE POLICY alert_rules_select ON alert_rules
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY alert_rules_insert ON alert_rules
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

CREATE POLICY alert_rules_update ON alert_rules
    FOR UPDATE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    ) WITH CHECK (org_id = public.get_org_id());

CREATE POLICY alert_rules_delete ON alert_rules
    FOR DELETE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator')
    );

-- ============================================================
-- alert_events: all roles can read, admin/operator/analyst can update
-- ============================================================
CREATE POLICY alert_events_select ON alert_events
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY alert_events_insert ON alert_events
    FOR INSERT WITH CHECK (org_id = public.get_org_id());

CREATE POLICY alert_events_update ON alert_events
    FOR UPDATE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator', 'analyst')
    ) WITH CHECK (org_id = public.get_org_id());

-- ============================================================
-- config_versions: org-scoped read/write
-- ============================================================
CREATE POLICY config_versions_select ON config_versions
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY config_versions_insert ON config_versions
    FOR INSERT WITH CHECK (org_id = public.get_org_id());

-- ============================================================
-- audit_logs: admin-only read, service-role insert
-- ============================================================
CREATE POLICY audit_logs_select ON audit_logs
    FOR SELECT USING (
        org_id = public.get_org_id()
        AND public.get_user_role() = 'admin'
    );

CREATE POLICY audit_logs_insert ON audit_logs
    FOR INSERT WITH CHECK (org_id = public.get_org_id());

-- ============================================================
-- data_retention_policies: admin-only
-- ============================================================
CREATE POLICY retention_select ON data_retention_policies
    FOR SELECT USING (
        org_id = public.get_org_id()
        AND public.get_user_role() = 'admin'
    );

CREATE POLICY retention_insert ON data_retention_policies
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() = 'admin'
    );

CREATE POLICY retention_update ON data_retention_policies
    FOR UPDATE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() = 'admin'
    ) WITH CHECK (org_id = public.get_org_id());

CREATE POLICY retention_delete ON data_retention_policies
    FOR DELETE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() = 'admin'
    );

-- ============================================================
-- shared_report_links: org-scoped, admin/operator/analyst can create
-- ============================================================
CREATE POLICY shared_links_select ON shared_report_links
    FOR SELECT USING (org_id = public.get_org_id());

CREATE POLICY shared_links_insert ON shared_report_links
    FOR INSERT WITH CHECK (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator', 'analyst')
    );

CREATE POLICY shared_links_delete ON shared_report_links
    FOR DELETE USING (
        org_id = public.get_org_id()
        AND public.get_user_role() IN ('admin', 'operator', 'analyst')
    );
