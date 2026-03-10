-- Migration 010: Performance indexes for high-volume query patterns
-- Traceability: FR-6.1, FR-6.2, FR-7.4, FR-8.1, FR-9.3, DM-7, SEC-17

-- ============================================================
-- vehicle_crossings indexes
-- This is the highest-volume table. Indexes target:
--   - time-range analytics
--   - per-camera filtering
--   - aggregate recomputation
-- ============================================================

CREATE INDEX idx_vc_camera_time
    ON vehicle_crossings(camera_id, timestamp_utc DESC);

CREATE INDEX idx_vc_org_time
    ON vehicle_crossings(org_id, timestamp_utc DESC);

CREATE INDEX idx_vc_site_time
    ON vehicle_crossings(site_id, timestamp_utc DESC);

CREATE INDEX idx_vc_camera_class_time
    ON vehicle_crossings(camera_id, class12, timestamp_utc DESC);

CREATE INDEX idx_vc_model_version
    ON vehicle_crossings(model_version, timestamp_utc DESC);

-- ============================================================
-- agg_vehicle_counts_15m indexes
-- ============================================================

CREATE INDEX idx_agg_camera_bucket
    ON agg_vehicle_counts_15m(camera_id, bucket_start DESC);

CREATE INDEX idx_agg_org_bucket
    ON agg_vehicle_counts_15m(org_id, bucket_start DESC);

CREATE INDEX idx_agg_camera_class_bucket
    ON agg_vehicle_counts_15m(camera_id, class12, bucket_start DESC);
