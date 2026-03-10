-- Migration 007: config_versions, audit_logs, data_retention_policies, shared_report_links
-- Traceability: FR-2.4, FR-1.4, SEC-17, DM-3, DM-5, NFR-13, FR-8.4

-- ============================================================
-- config_versions
-- ============================================================
CREATE TABLE config_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    entity_type     TEXT NOT NULL CHECK (entity_type IN ('site', 'camera', 'roi_preset')),
    entity_id       UUID NOT NULL,
    version_number  INT NOT NULL,
    config_snapshot JSONB NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_by      UUID REFERENCES users(id),
    rollback_from   UUID REFERENCES config_versions(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_config_version UNIQUE (entity_type, entity_id, version_number)
);

CREATE INDEX idx_config_versions_entity ON config_versions(entity_type, entity_id);
CREATE INDEX idx_config_versions_active ON config_versions(entity_type, entity_id)
    WHERE is_active = true;

COMMENT ON TABLE config_versions IS 'Immutable config snapshots for rollback (FR-2.4)';

-- ============================================================
-- audit_logs (append-only)
-- ============================================================
CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL,
    user_id     UUID,
    action      TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   UUID,
    old_value   JSONB,
    new_value   JSONB,
    ip_address  INET,
    user_agent  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_org_id ON audit_logs(org_id, created_at DESC);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at DESC);

COMMENT ON TABLE audit_logs IS 'Immutable audit trail — append only (FR-1.4, SEC-17)';

-- Enforce immutability: prevent UPDATE and DELETE on audit_logs
CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_logs is append-only: UPDATE and DELETE are prohibited';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_logs_immutable
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();

-- ============================================================
-- data_retention_policies
-- ============================================================
CREATE TABLE data_retention_policies (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    data_type      TEXT NOT NULL CHECK (data_type IN (
                       'vehicle_crossings', 'aggregates', 'alert_events',
                       'audit_logs', 'media', 'exports'
                   )),
    retention_days INT NOT NULL CHECK (retention_days > 0),
    auto_delete    BOOLEAN NOT NULL DEFAULT false,
    last_purge_at  TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_retention_policy UNIQUE (org_id, data_type)
);

COMMENT ON TABLE data_retention_policies IS 'Per-org data retention rules (DM-3, DM-5, NFR-13)';

-- ============================================================
-- shared_report_links
-- ============================================================
CREATE TABLE shared_report_links (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),
    token      TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
    scope      JSONB NOT NULL,
    filters    JSONB NOT NULL DEFAULT '{}',
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_shared_report_links_token ON shared_report_links(token);
CREATE INDEX idx_shared_report_links_expires ON shared_report_links(expires_at);

COMMENT ON TABLE shared_report_links IS 'Tokenized read-only report links (FR-8.4)';
