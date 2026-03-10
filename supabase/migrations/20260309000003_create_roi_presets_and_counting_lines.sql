-- Migration 003: roi_presets and counting_lines with normalized geometry
-- Traceability: FR-4.4, FR-2.4, FR-5.6

-- ============================================================
-- roi_presets
-- ============================================================
CREATE TABLE roi_presets (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    camera_id      UUID NOT NULL REFERENCES cameras(id) ON DELETE CASCADE,
    org_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name           TEXT NOT NULL,
    roi_polygon    JSONB NOT NULL,
    lane_polylines JSONB DEFAULT '[]',
    is_active      BOOLEAN NOT NULL DEFAULT false,
    version        INT NOT NULL DEFAULT 1,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by     UUID REFERENCES users(id)
);

CREATE INDEX idx_roi_presets_camera_id ON roi_presets(camera_id);
CREATE UNIQUE INDEX idx_roi_presets_active ON roi_presets(camera_id) WHERE is_active = true;

COMMENT ON TABLE roi_presets IS 'ROI configurations per camera (FR-4.4, FR-2.4)';
COMMENT ON INDEX idx_roi_presets_active IS 'Ensures at most one active preset per camera';

-- ============================================================
-- counting_lines
-- ============================================================
CREATE TABLE counting_lines (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    preset_id        UUID NOT NULL REFERENCES roi_presets(id) ON DELETE CASCADE,
    camera_id        UUID NOT NULL REFERENCES cameras(id) ON DELETE CASCADE,
    org_id           UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name             TEXT NOT NULL,
    start_point      JSONB NOT NULL,
    end_point        JSONB NOT NULL,
    direction        TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound', 'bidirectional')),
    direction_vector JSONB NOT NULL,
    sort_order       INT NOT NULL DEFAULT 0
);

CREATE INDEX idx_counting_lines_preset_id ON counting_lines(preset_id);
CREATE INDEX idx_counting_lines_camera_id ON counting_lines(camera_id);

COMMENT ON TABLE counting_lines IS 'Directional counting lines within ROI presets (FR-5.6)';
