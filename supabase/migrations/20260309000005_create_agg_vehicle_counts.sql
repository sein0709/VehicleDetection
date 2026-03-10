-- Migration 005: agg_vehicle_counts_15m with composite unique constraint
-- Traceability: FR-6.1, DM-2, DM-7
-- Pre-computed 15-minute bucket aggregates derived from vehicle_crossings.

CREATE TABLE agg_vehicle_counts_15m (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    camera_id       UUID NOT NULL,
    line_id         UUID NOT NULL,
    bucket_start    TIMESTAMPTZ NOT NULL,
    class12         SMALLINT NOT NULL CHECK (class12 BETWEEN 1 AND 12),
    direction       TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    count           INT NOT NULL DEFAULT 0,
    sum_confidence  REAL NOT NULL DEFAULT 0.0,
    sum_speed_kmh   REAL NOT NULL DEFAULT 0.0,
    min_speed_kmh   REAL,
    max_speed_kmh   REAL,
    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_agg_bucket
        UNIQUE (camera_id, line_id, bucket_start, class12, direction)
);

COMMENT ON TABLE agg_vehicle_counts_15m IS '15-minute bucket aggregates (FR-6.1, DM-2, DM-7)';
