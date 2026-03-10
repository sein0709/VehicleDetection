-- Migration 004: vehicle_crossings with dedup constraint
-- Traceability: DM-6, DM-7
-- This is the event-sourced source of truth for all traffic counts.

CREATE TABLE vehicle_crossings (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id             UUID NOT NULL,
    site_id            UUID NOT NULL,
    camera_id          UUID NOT NULL,
    line_id            UUID NOT NULL,
    track_id           TEXT NOT NULL,
    crossing_seq       INT NOT NULL DEFAULT 1,
    class12            SMALLINT NOT NULL CHECK (class12 BETWEEN 1 AND 12),
    confidence         REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
    direction          TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    model_version      TEXT NOT NULL,
    frame_index        INT NOT NULL,
    speed_estimate_kmh REAL,
    bbox               JSONB,
    offline_upload     BOOLEAN NOT NULL DEFAULT false,
    timestamp_utc      TIMESTAMPTZ NOT NULL,
    ingested_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_crossing_dedup
        UNIQUE (camera_id, line_id, track_id, crossing_seq)
);

COMMENT ON TABLE vehicle_crossings IS 'Event-sourced crossing records — source of truth (DM-6, DM-7)';
