-- Migration 002: sites with geography/geofence, cameras with source_type
-- Traceability: FR-2.1, FR-2.2, FR-2.3, FR-3.1, FR-3.2, FR-3.3, FR-3.4

-- ============================================================
-- sites
-- ============================================================
CREATE TABLE sites (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name                  TEXT NOT NULL,
    address               TEXT,
    location              GEOGRAPHY(Point, 4326),
    geofence              JSONB,
    timezone              TEXT NOT NULL DEFAULT 'Asia/Seoul',
    status                TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    active_config_version INT NOT NULL DEFAULT 1,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by            UUID REFERENCES users(id)
);

CREATE INDEX idx_sites_org_id ON sites(org_id);
CREATE INDEX idx_sites_status ON sites(org_id, status);

COMMENT ON TABLE sites IS 'Survey locations with geofence (FR-2.1, FR-2.2, FR-2.3)';

-- ============================================================
-- cameras
-- ============================================================
CREATE TABLE cameras (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id               UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    org_id                UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name                  TEXT NOT NULL,
    source_type           TEXT NOT NULL CHECK (source_type IN ('smartphone', 'rtsp', 'onvif')),
    rtsp_url              TEXT,
    settings              JSONB NOT NULL DEFAULT '{
        "target_fps": 10,
        "resolution": "1920x1080",
        "night_mode": false,
        "classification_mode": "full_12class"
    }',
    status                TEXT NOT NULL DEFAULT 'offline'
                          CHECK (status IN ('online', 'degraded', 'offline', 'archived')),
    active_config_version INT NOT NULL DEFAULT 1,
    last_seen_at          TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_cameras_site_id ON cameras(site_id);
CREATE INDEX idx_cameras_org_id ON cameras(org_id);
CREATE INDEX idx_cameras_status ON cameras(org_id, status);

COMMENT ON TABLE cameras IS 'Camera sources per site (FR-3.1, FR-3.2, FR-3.3, FR-3.4)';
