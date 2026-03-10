-- GreyEye Development Seed Data
-- Populates the local database with a demo organization, users (one per role),
-- a sample site with geofence, a camera, ROI preset with counting lines,
-- config versions, and default retention policies.
--
-- Usage: supabase db reset  (applies migrations + seed)
-- NOTE: This file runs AFTER all migrations. Never run in production.

-- ============================================================
-- 1. Demo Organization
-- ============================================================
INSERT INTO organizations (id, name, slug, settings) VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'GreyEye Demo Org',
    'greyeye-demo',
    '{"default_timezone": "Asia/Seoul", "classification_mode": "full_12class"}'
);

-- ============================================================
-- 2. Users — one per RBAC role
-- ============================================================
INSERT INTO users (id, org_id, email, name, role) VALUES
    ('b0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001',
     'admin@greyeye.dev', '김관리자', 'admin'),

    ('b0000000-0000-0000-0000-000000000002',
     'a0000000-0000-0000-0000-000000000001',
     'operator@greyeye.dev', '이운영자', 'operator'),

    ('b0000000-0000-0000-0000-000000000003',
     'a0000000-0000-0000-0000-000000000001',
     'analyst@greyeye.dev', '박분석가', 'analyst'),

    ('b0000000-0000-0000-0000-000000000004',
     'a0000000-0000-0000-0000-000000000001',
     'viewer@greyeye.dev', '최열람자', 'viewer');

-- ============================================================
-- 3. Sample Site — 강남역 교차로
-- ============================================================
INSERT INTO sites (id, org_id, name, address, location, geofence, timezone, created_by) VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    '강남역 교차로',
    '서울특별시 강남구 강남대로 396',
    ST_SetSRID(ST_MakePoint(127.0276, 37.4979), 4326)::GEOGRAPHY,
    '{
        "type": "Polygon",
        "coordinates": [[[127.0270, 37.4975], [127.0282, 37.4975], [127.0282, 37.4983], [127.0270, 37.4983], [127.0270, 37.4975]]]
    }',
    'Asia/Seoul',
    'b0000000-0000-0000-0000-000000000001'
);

-- ============================================================
-- 4. Sample Camera — smartphone type
-- ============================================================
INSERT INTO cameras (id, site_id, org_id, name, source_type, settings) VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    '남측 진입로 카메라',
    'smartphone',
    '{"target_fps": 10, "resolution": "1920x1080", "night_mode": false, "classification_mode": "full_12class"}'
);

-- ============================================================
-- 5. Sample ROI Preset with Counting Lines
-- ============================================================
INSERT INTO roi_presets (id, camera_id, org_id, name, roi_polygon, lane_polylines, is_active, created_by) VALUES (
    'e0000000-0000-0000-0000-000000000001',
    'd0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    '평일 기본',
    '{"type": "Polygon", "coordinates": [[[0.1, 0.2], [0.9, 0.2], [0.9, 0.95], [0.1, 0.95], [0.1, 0.2]]]}',
    '[{"name": "1차로", "points": [{"x": 0.3, "y": 0.2}, {"x": 0.3, "y": 0.95}]}]',
    true,
    'b0000000-0000-0000-0000-000000000002'
);

INSERT INTO counting_lines (id, preset_id, camera_id, org_id, name, start_point, end_point, direction, direction_vector, sort_order) VALUES
    ('f0000000-0000-0000-0000-000000000001',
     'e0000000-0000-0000-0000-000000000001',
     'd0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001',
     '남북 통행선',
     '{"x": 0.2, "y": 0.5}',
     '{"x": 0.8, "y": 0.5}',
     'inbound',
     '{"dx": 0.0, "dy": -1.0}',
     1),

    ('f0000000-0000-0000-0000-000000000002',
     'e0000000-0000-0000-0000-000000000001',
     'd0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001',
     '북남 통행선',
     '{"x": 0.2, "y": 0.6}',
     '{"x": 0.8, "y": 0.6}',
     'outbound',
     '{"dx": 0.0, "dy": 1.0}',
     2);

-- ============================================================
-- 6. Initial Config Versions (site + camera + ROI preset)
-- ============================================================
INSERT INTO config_versions (org_id, entity_type, entity_id, version_number, config_snapshot, is_active, created_by) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'site',
     'c0000000-0000-0000-0000-000000000001', 1,
     '{"name": "강남역 교차로", "address": "서울특별시 강남구 강남대로 396", "timezone": "Asia/Seoul", "status": "active"}',
     true, 'b0000000-0000-0000-0000-000000000001'),

    ('a0000000-0000-0000-0000-000000000001', 'camera',
     'd0000000-0000-0000-0000-000000000001', 1,
     '{"name": "남측 진입로 카메라", "source_type": "smartphone", "settings": {"target_fps": 10, "resolution": "1920x1080", "night_mode": false, "classification_mode": "full_12class"}}',
     true, 'b0000000-0000-0000-0000-000000000001'),

    ('a0000000-0000-0000-0000-000000000001', 'roi_preset',
     'e0000000-0000-0000-0000-000000000001', 1,
     '{"name": "평일 기본", "is_active": true, "counting_lines": 2}',
     true, 'b0000000-0000-0000-0000-000000000002');

-- ============================================================
-- 7. Default Data Retention Policies
-- ============================================================
INSERT INTO data_retention_policies (org_id, data_type, retention_days, auto_delete) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'vehicle_crossings', 90, true),
    ('a0000000-0000-0000-0000-000000000001', 'aggregates', 730, false),
    ('a0000000-0000-0000-0000-000000000001', 'alert_events', 365, false),
    ('a0000000-0000-0000-0000-000000000001', 'audit_logs', 1095, false),
    ('a0000000-0000-0000-0000-000000000001', 'media', 30, true),
    ('a0000000-0000-0000-0000-000000000001', 'exports', 30, true);

-- ============================================================
-- 8. Sample Alert Rule
-- ============================================================
INSERT INTO alert_rules (id, org_id, site_id, camera_id, name, condition_type, condition_params, severity, channels, recipients, cooldown_minutes) VALUES (
    'aa000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'd0000000-0000-0000-0000-000000000001',
    '강남역 혼잡 경보',
    'congestion',
    '{"threshold": 200, "window_minutes": 15}',
    'warning',
    ARRAY['push', 'email'],
    ARRAY['b0000000-0000-0000-0000-000000000001'::UUID],
    15
);

-- ============================================================
-- 9. Sample Audit Log Entry
-- ============================================================
INSERT INTO audit_logs (org_id, user_id, action, entity_type, entity_id, new_value) VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    'create',
    'site',
    'c0000000-0000-0000-0000-000000000001',
    '{"name": "강남역 교차로"}'
);
