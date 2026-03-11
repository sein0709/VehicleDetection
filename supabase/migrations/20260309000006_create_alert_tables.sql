-- Migration 006: alert_rules and alert_events
-- Traceability: FR-7.1, FR-7.3, FR-7.4

-- ============================================================
-- alert_rules
-- ============================================================
CREATE TABLE alert_rules (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id          UUID REFERENCES sites(id) ON DELETE CASCADE,
    camera_id        UUID REFERENCES cameras(id) ON DELETE SET NULL,
    name             TEXT NOT NULL,
    condition_type   TEXT NOT NULL
                     CHECK (condition_type IN (
                         'congestion', 'speed_drop', 'stopped_vehicle',
                         'heavy_vehicle_share', 'camera_offline', 'count_anomaly'
                     )),
    condition_config JSONB NOT NULL DEFAULT '{}'::JSONB,
    severity         TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    channels         JSONB NOT NULL DEFAULT '[]'::JSONB,
    recipients       JSONB NOT NULL DEFAULT '[]'::JSONB,
    cooldown_minutes INT NOT NULL DEFAULT 15,
    enabled          BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by       UUID REFERENCES users(id)
);

CREATE INDEX idx_alert_rules_org_id ON alert_rules(org_id);
CREATE INDEX idx_alert_rules_scope ON alert_rules(org_id, site_id, camera_id) WHERE enabled = true;

COMMENT ON TABLE alert_rules IS 'Alert rule definitions (FR-7.1)';

-- ============================================================
-- alert_events
-- ============================================================
CREATE TABLE alert_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id         UUID NOT NULL REFERENCES alert_rules(id) ON DELETE CASCADE,
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    camera_id       TEXT,
    site_id         TEXT,
    status          TEXT NOT NULL DEFAULT 'triggered'
                    CHECK (status IN ('triggered', 'acknowledged', 'assigned', 'resolved', 'suppressed')),
    severity        TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    message         TEXT NOT NULL,
    context         JSONB DEFAULT '{}',
    acknowledged_by UUID REFERENCES users(id),
    assigned_to     UUID REFERENCES users(id),
    triggered_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged_at TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ,
    resolved_by     UUID REFERENCES users(id)
);

CREATE INDEX idx_alert_events_org_id ON alert_events(org_id);
CREATE INDEX idx_alert_events_status ON alert_events(org_id, status);
CREATE INDEX idx_alert_events_rule_id ON alert_events(rule_id);
CREATE INDEX idx_alert_events_triggered_at ON alert_events(org_id, triggered_at DESC);

COMMENT ON TABLE alert_events IS 'Alert lifecycle events (FR-7.3, FR-7.4)';
