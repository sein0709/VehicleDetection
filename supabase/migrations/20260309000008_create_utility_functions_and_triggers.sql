-- Migration 008: Utility functions and triggers
-- - updated_at auto-update trigger
-- - 15-minute bucket computation function
-- - Single active ROI preset enforcement trigger

-- ============================================================
-- Auto-update updated_at on row modification
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_sites_updated_at
    BEFORE UPDATE ON sites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_cameras_updated_at
    BEFORE UPDATE ON cameras
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_alert_rules_updated_at
    BEFORE UPDATE ON alert_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_data_retention_updated_at
    BEFORE UPDATE ON data_retention_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 15-minute bucket start computation (IMMUTABLE for index use)
-- ============================================================
CREATE OR REPLACE FUNCTION bucket_start_15m(ts TIMESTAMPTZ)
RETURNS TIMESTAMPTZ AS $$
    SELECT date_trunc('hour', ts)
        + INTERVAL '15 minutes' * FLOOR(EXTRACT(MINUTE FROM ts) / 15);
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION bucket_start_15m IS 'Assigns a timestamp to its 15-minute bucket (hour-aligned: :00, :15, :30, :45)';

-- ============================================================
-- Enforce single active ROI preset per camera
-- The partial unique index prevents multiple active presets,
-- and this trigger deactivates the previous one on activation.
-- ============================================================
CREATE OR REPLACE FUNCTION deactivate_other_roi_presets()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_active = true THEN
        UPDATE roi_presets
        SET is_active = false
        WHERE camera_id = NEW.camera_id
          AND id != NEW.id
          AND is_active = true;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_roi_preset_single_active
    BEFORE INSERT OR UPDATE OF is_active ON roi_presets
    FOR EACH ROW
    WHEN (NEW.is_active = true)
    EXECUTE FUNCTION deactivate_other_roi_presets();
