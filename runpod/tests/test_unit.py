"""No-GPU unit tests — calibration parser, HSV state machine, plate
normalizer, crop hash. Runs in seconds on any machine with cv2 + numpy.
"""
from __future__ import annotations

import json

import pytest

from conftest import requires_cv2, requires_integration_stack, requires_numpy


pytestmark = pytest.mark.unit


# ===========================================================================
# calibration.parse_calibration
# ===========================================================================
class TestCalibration:
    def test_empty_input_returns_defaults(self):
        from calibration import parse_calibration

        cal = parse_calibration(None)
        assert cal.tasks_enabled == {"vehicles", "pedestrians"}
        assert cal.tripwire.y_ratio == pytest.approx(0.60)
        assert cal.speed is None
        assert cal.transit is None
        assert cal.traffic_light is None
        assert cal.lpr.enabled is False

    def test_invalid_json_falls_back_to_defaults(self):
        from calibration import parse_calibration

        cal = parse_calibration("{not json}")
        assert cal.tasks_enabled == {"vehicles", "pedestrians"}

    def test_tripwire_override(self):
        from calibration import parse_calibration

        cal = parse_calibration(json.dumps({"tripwire": {"y_ratio": 0.75}}))
        assert cal.tripwire.y_ratio == pytest.approx(0.75)

    def test_full_speed_config(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                "source_quad": [[0, 0], [100, 0], [100, 100], [0, 100]],
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.3, 0.7],
            },
        })
        cal = parse_calibration(raw)
        assert "speed" in cal.tasks_enabled
        assert cal.speed is not None
        assert len(cal.speed.source_quad) == 4
        assert cal.speed.real_world_m == {"width": 3.5, "length": 20.0}

    def test_invalid_speed_disables_task(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                "source_quad": [[0, 0], [1, 1]],  # needs 4 points
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.3, 0.7],
            },
        })
        cal = parse_calibration(raw)
        assert cal.speed is None
        assert "speed" not in cal.tasks_enabled

    def test_transit_requires_three_polygon_points(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "transit"],
            "transit": {
                "stop_polygon": [[0, 0], [10, 10]],  # only 2 points
                "max_capacity": 20,
                "doors": [],
            },
        })
        cal = parse_calibration(raw)
        assert cal.transit is None
        assert "transit" not in cal.tasks_enabled

    def test_traffic_light_roi_validates_four_numbers(self):
        from calibration import parse_calibration

        good = json.dumps({
            "tasks_enabled": ["vehicles", "traffic_light"],
            "traffic_light": {"roi": [10, 20, 100, 100]},
        })
        cal = parse_calibration(good)
        assert cal.traffic_light is not None
        assert cal.traffic_light.roi == [10, 20, 100, 100]

        bad = json.dumps({
            "tasks_enabled": ["vehicles", "traffic_light"],
            "traffic_light": {"roi": [10, 20, 100]},
        })
        cal = parse_calibration(bad)
        assert cal.traffic_light is None
        assert "traffic_light" not in cal.tasks_enabled

    def test_output_video_default_false(self):
        from calibration import parse_calibration

        cal = parse_calibration(None)
        assert cal.output_video is False

    def test_output_video_toggle(self):
        import json
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles"],
            "output_video": True,
        })
        cal = parse_calibration(raw)
        assert cal.output_video is True

    def test_lpr_disabled_drops_from_tasks(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "lpr"],
            "lpr": {"enabled": False},
        })
        cal = parse_calibration(raw)
        assert cal.lpr.enabled is False
        assert "lpr" not in cal.tasks_enabled

    def test_count_lines_parsed(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles"],
            "count_lines": {
                "in": [[0.10, 0.50], [0.90, 0.50]],
                "out": [[0.10, 0.80], [0.90, 0.80]],
            },
        })
        cal = parse_calibration(raw)
        assert cal.count_lines is not None
        assert cal.count_lines.in_line == [[0.10, 0.50], [0.90, 0.50]]
        assert cal.count_lines.out_line == [[0.10, 0.80], [0.90, 0.80]]

    def test_count_lines_missing_returns_none(self):
        from calibration import parse_calibration

        cal = parse_calibration(json.dumps({"tasks_enabled": ["vehicles"]}))
        assert cal.count_lines is None

    def test_count_lines_malformed_falls_back(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles"],
            "count_lines": {"in": [[0.1, 0.5]], "out": [[0.1, 0.8], [0.9, 0.8]]},
        })
        cal = parse_calibration(raw)
        assert cal.count_lines is None  # in line missing second point

    def test_speed_lines_xy_parsed(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                "source_quad": [[0, 0], [100, 0], [100, 100], [0, 100]],
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.3, 0.7],
                "lines_xy": [
                    [[0.10, 0.30], [0.90, 0.35]],
                    [[0.05, 0.70], [0.95, 0.75]],
                ],
            },
        })
        cal = parse_calibration(raw)
        assert cal.speed is not None
        assert cal.speed.lines_xy is not None
        assert cal.speed.lines_xy[0] == [[0.10, 0.30], [0.90, 0.35]]
        assert cal.speed.lines_xy[1] == [[0.05, 0.70], [0.95, 0.75]]

    def test_speed_lines_xy_invalid_disables_speed(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                "source_quad": [[0, 0], [100, 0], [100, 100], [0, 100]],
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.3, 0.7],
                "lines_xy": [[[0.1, 0.3]]],  # only 1 line, missing second pt
            },
        })
        cal = parse_calibration(raw)
        assert cal.speed is None
        assert "speed" not in cal.tasks_enabled


# ===========================================================================
# Calibration.resolve_ratio_coords — mobile-side ratio support
# ===========================================================================
class TestRatioCoordResolve:
    """The mobile UI builds calibration JSON before the upload completes,
    so it can't know the video resolution. It sends normalized coordinates
    in [0..1] which the pipeline scales to pixels at video-load time.
    """

    def test_speed_quad_ratios_become_pixels(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                "source_quad": [
                    [0.30, 0.60], [0.70, 0.60], [0.85, 0.95], [0.15, 0.95],
                ],
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.45, 0.75],
            },
        })
        cal = parse_calibration(raw)
        cal.resolve_ratio_coords(width=1920, height=1080)
        assert cal.speed is not None
        assert cal.speed.source_quad == [
            [pytest.approx(576.0), pytest.approx(648.0)],
            [pytest.approx(1344.0), pytest.approx(648.0)],
            [pytest.approx(1632.0), pytest.approx(1026.0)],
            [pytest.approx(288.0), pytest.approx(1026.0)],
        ]

    def test_pixel_coords_pass_through_unchanged(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                "source_quad": [[100, 200], [800, 200], [950, 700], [50, 700]],
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.45, 0.75],
            },
        })
        cal = parse_calibration(raw)
        cal.resolve_ratio_coords(width=1280, height=720)
        assert cal.speed is not None
        assert cal.speed.source_quad == [
            [100.0, 200.0], [800.0, 200.0], [950.0, 700.0], [50.0, 700.0],
        ]

    def test_idempotent_after_first_call(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "traffic_light"],
            "traffic_light": {"roi": [0.45, 0.05, 0.10, 0.15]},
        })
        cal = parse_calibration(raw)
        cal.resolve_ratio_coords(width=1920, height=1080)
        first = list(cal.traffic_light.lights[0].roi)
        cal.resolve_ratio_coords(width=1920, height=1080)
        assert list(cal.traffic_light.lights[0].roi) == first

    def test_transit_polygon_door_and_bus_zone_all_scale(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "transit"],
            "transit": {
                "stop_polygon": [
                    [0.0, 0.7], [1.0, 0.7], [1.0, 1.0], [0.0, 1.0],
                ],
                "bus_zone_polygon": [
                    [0.1, 0.5], [0.9, 0.5], [0.9, 0.9], [0.1, 0.9],
                ],
                "max_capacity": 30,
                "doors": [{"line": [[0.0, 0.85], [1.0, 0.85]]}],
            },
        })
        cal = parse_calibration(raw)
        cal.resolve_ratio_coords(width=1280, height=720)
        assert cal.transit is not None
        assert cal.transit.stop_polygon[0] == [pytest.approx(0.0), pytest.approx(504.0)]
        assert cal.transit.stop_polygon[2] == [pytest.approx(1280.0), pytest.approx(720.0)]
        assert cal.transit.bus_zone_polygon[0] == [
            pytest.approx(128.0), pytest.approx(360.0),
        ]
        assert cal.transit.doors[0]["line"] == [
            [pytest.approx(0.0), pytest.approx(612.0)],
            [pytest.approx(1280.0), pytest.approx(612.0)],
        ]

    def test_traffic_light_roi_ratios_round_to_int(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "traffic_light"],
            "traffic_lights": [
                {"label": "main", "roi": [0.45, 0.05, 0.10, 0.15]},
                {"label": "left", "roi": [200, 50, 80, 120]},
            ],
        })
        cal = parse_calibration(raw)
        cal.resolve_ratio_coords(width=1920, height=1080)
        assert cal.traffic_light is not None
        assert cal.traffic_light.lights[0].roi == [864, 54, 192, 162]
        # Pixel-space ROI passed through unchanged.
        assert cal.traffic_light.lights[1].roi == [200, 50, 80, 120]

    def test_resolves_when_no_engines_configured(self):
        from calibration import parse_calibration

        cal = parse_calibration(None)
        cal.resolve_ratio_coords(width=1920, height=1080)

    def test_count_lines_ratios_become_pixels(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles"],
            "count_lines": {
                "in": [[0.10, 0.50], [0.90, 0.50]],
                "out": [[0.10, 0.80], [0.90, 0.80]],
            },
        })
        cal = parse_calibration(raw)
        cal.resolve_ratio_coords(width=1920, height=1080)
        assert cal.count_lines is not None
        assert cal.count_lines.in_line == [
            [pytest.approx(192.0), pytest.approx(540.0)],
            [pytest.approx(1728.0), pytest.approx(540.0)],
        ]
        assert cal.count_lines.out_line == [
            [pytest.approx(192.0), pytest.approx(864.0)],
            [pytest.approx(1728.0), pytest.approx(864.0)],
        ]

    def test_speed_lines_xy_ratios_become_pixels(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "speed"],
            "speed": {
                "source_quad": [
                    [0.30, 0.60], [0.70, 0.60], [0.85, 0.95], [0.15, 0.95],
                ],
                "real_world_m": {"width": 3.5, "length": 20.0},
                "lines_y_ratio": [0.45, 0.75],
                "lines_xy": [
                    [[0.10, 0.45], [0.90, 0.50]],
                    [[0.05, 0.75], [0.95, 0.80]],
                ],
            },
        })
        cal = parse_calibration(raw)
        cal.resolve_ratio_coords(width=1920, height=1080)
        assert cal.speed is not None and cal.speed.lines_xy is not None
        assert cal.speed.lines_xy[0] == [
            [pytest.approx(192.0), pytest.approx(486.0)],
            [pytest.approx(1728.0), pytest.approx(540.0)],
        ]
        assert cal.speed.lines_xy[1] == [
            [pytest.approx(96.0), pytest.approx(810.0)],
            [pytest.approx(1824.0), pytest.approx(864.0)],
        ]


# ===========================================================================
# tasks_light.TrafficLightEngine  (HSV state machine)
# ===========================================================================
@requires_cv2
@requires_numpy
class TestTrafficLight:
    def _solid(self, bgr: tuple[int, int, int], w: int = 64, h: int = 64):
        import numpy as np

        img = np.zeros((h, w, 3), dtype=np.uint8)
        img[:, :] = bgr
        return img

    def _engine(self):
        from calibration import TrafficLightCfg, TrafficLightEntry
        from tasks_light import TrafficLightEngine

        return TrafficLightEngine(
            cfg=TrafficLightCfg(
                lights=[TrafficLightEntry(roi=[0, 0, 64, 64], label="main")]
            )
        )

    def test_red_solid_classified_as_red(self):
        engine = self._engine()
        frame = self._solid((0, 0, 255))  # BGR red
        state, _ = engine.update(frame, timestamp_s=0.0)
        assert state == "red"

    def test_green_solid_classified_as_green(self):
        engine = self._engine()
        frame = self._solid((0, 255, 0))  # BGR green
        state, _ = engine.update(frame, timestamp_s=0.0)
        assert state == "green"

    def test_black_frame_is_unknown_and_offers_vlm_crop(self):
        engine = self._engine()
        frame = self._solid((0, 0, 0))
        state, ambiguous = engine.update(frame, timestamp_s=0.0)
        assert state == "unknown"
        assert ambiguous is not None  # first unknown streak offers a crop

    def test_state_transitions_build_timeline(self):
        engine = self._engine()
        engine.update(self._solid((0, 0, 255)), timestamp_s=0.0)   # red
        engine.update(self._solid((0, 0, 255)), timestamp_s=1.0)   # red still
        engine.update(self._solid((0, 255, 0)), timestamp_s=2.0)   # flip to green
        engine.update(self._solid((0, 255, 0)), timestamp_s=3.0)   # green still
        report = engine.report()
        states = [span["state"] for span in report["timeline"]]
        # First span closed (red), second span open (green)
        assert states[0] == "red"
        assert states[-1] == "green"
        assert report["cycles"]["red"]["cycles"] >= 1
        assert report["cycles"]["green"]["cycles"] >= 1


@requires_cv2
@requires_numpy
class TestMultiLight:
    def _multi_engine(self):
        from calibration import TrafficLightCfg, TrafficLightEntry
        from tasks_light import TrafficLightEngine

        return TrafficLightEngine(
            cfg=TrafficLightCfg(lights=[
                TrafficLightEntry(roi=[0, 0, 64, 64], label="main"),
                TrafficLightEntry(roi=[80, 0, 64, 64], label="pedestrian"),
            ])
        )

    def _frame(self, w: int, h: int, rois: dict[tuple[int, int, int, int], tuple[int, int, int]]):
        import numpy as np

        img = np.zeros((h, w, 3), dtype=np.uint8)
        for (x, y, rw, rh), bgr in rois.items():
            img[y:y+rh, x:x+rw] = bgr
        return img

    def test_two_independent_trackers(self):
        eng = self._multi_engine()
        # main = red, pedestrian = green
        frame = self._frame(200, 80, {
            (0, 0, 64, 64):  (0, 0, 255),
            (80, 0, 64, 64): (0, 255, 0),
        })
        eng.update(frame, timestamp_s=0.0)
        report = eng.report()
        assert "traffic_lights" in report
        assert len(report["traffic_lights"]) == 2
        labels = {l["label"] for l in report["traffic_lights"]}
        assert labels == {"main", "pedestrian"}
        by_label = {l["label"]: l for l in report["traffic_lights"]}
        assert by_label["main"]["timeline"][0]["state"] == "red"
        assert by_label["pedestrian"]["timeline"][0]["state"] == "green"

    def test_single_light_keeps_legacy_keys(self):
        from calibration import TrafficLightCfg, TrafficLightEntry
        from tasks_light import TrafficLightEngine

        # Single-light engine still exposes top-level `cycles` and `timeline`
        # so existing clients don't break.
        eng = TrafficLightEngine(
            cfg=TrafficLightCfg(lights=[
                TrafficLightEntry(roi=[0, 0, 64, 64], label="only")
            ])
        )
        import numpy as np
        frame = np.zeros((64, 64, 3), dtype=np.uint8)
        frame[:, :] = (0, 0, 255)
        eng.update(frame, timestamp_s=0.0)
        report = eng.report()
        assert "traffic_lights" in report and len(report["traffic_lights"]) == 1
        assert "cycles" in report and "timeline" in report

    def test_parse_plural_traffic_lights(self):
        import json
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["traffic_light"],
            "traffic_lights": [
                {"label": "main",       "roi": [100, 50, 30, 80]},
                {"label": "left_arrow", "roi": [140, 50, 30, 80]},
                {"label": "pedestrian", "roi": [200, 50, 30, 80]},
            ],
        })
        cal = parse_calibration(raw)
        assert cal.traffic_light is not None
        assert len(cal.traffic_light.lights) == 3
        labels = [lg.label for lg in cal.traffic_light.lights]
        assert labels == ["main", "left_arrow", "pedestrian"]

    def test_parse_legacy_singular_traffic_light(self):
        import json
        from calibration import parse_calibration

        # Legacy shape must still load as a one-entry list with label "main".
        raw = json.dumps({
            "tasks_enabled": ["traffic_light"],
            "traffic_light": {"roi": [10, 10, 30, 80]},
        })
        cal = parse_calibration(raw)
        assert cal.traffic_light is not None
        assert len(cal.traffic_light.lights) == 1
        assert cal.traffic_light.lights[0].label == "main"
        assert cal.traffic_light.lights[0].roi == [10, 10, 30, 80]

    def test_invalid_plural_entry_disables_task(self):
        import json
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["traffic_light"],
            "traffic_lights": [{"label": "main", "roi": [10, 10]}],  # bad ROI
        })
        cal = parse_calibration(raw)
        assert cal.traffic_light is None
        assert "traffic_light" not in cal.tasks_enabled


# ===========================================================================
# ocr.normalize_plate
# ===========================================================================
class TestPlateNormalize:
    @pytest.mark.parametrize("raw, expected", [
        ("12가3456", "12가3456"),
        ("12 가 3456", "12가3456"),
        ("  12가3456  ", "12가3456"),
        ("123가4567", "123가4567"),
        ("garbage no plate", "garbage no plate"),
        ("", ""),
    ])
    def test_canonical_forms(self, raw, expected):
        from ocr import normalize_plate

        assert normalize_plate(raw) == expected


class TestClassifyPlate:
    def test_resident_exact_match(self):
        from ocr import classify_plate

        assert classify_plate("12가3456", ["12가3456", "99나0001"]) == "resident"

    def test_visitor_when_missing(self):
        from ocr import classify_plate

        assert classify_plate("34다5678", ["12가3456"]) == "visitor"

    def test_resident_after_normalization(self):
        from ocr import classify_plate

        # Whitespace variations still match a canonical allowlist entry.
        assert classify_plate("12 가 3456", ["12가3456"]) == "resident"

    def test_empty_input_is_unknown(self):
        from ocr import classify_plate

        assert classify_plate("", ["12가3456"]) == "unknown"

    def test_empty_allowlist_defaults_to_visitor(self):
        from ocr import classify_plate

        assert classify_plate("12가3456", []) == "visitor"


class TestHashPlate:
    def test_same_plate_same_hash(self):
        from ocr import hash_plate

        assert hash_plate("12가3456") == hash_plate("12가3456")

    def test_different_plates_different_hashes(self):
        from ocr import hash_plate

        assert hash_plate("12가3456") != hash_plate("99나0001")

    def test_normalization_before_hash(self):
        from ocr import hash_plate

        # Hash must be stable across whitespace variants.
        assert hash_plate("12가3456") == hash_plate("12 가 3456")

    def test_hash_length(self):
        from ocr import hash_plate

        # Default 8-byte prefix = 16 hex chars.
        assert len(hash_plate("12가3456")) == 16

    def test_empty_input(self):
        from ocr import hash_plate

        assert hash_plate("") == ""


class TestLprConfigParsing:
    def test_allowlist_normalized_on_load(self):
        import json
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["lpr"],
            "lpr": {
                "enabled": True,
                # Mix of normalized and whitespace-loose entries
                "allowlist": ["12가3456", "99 나 0001", "  77 다 9999  "],
            },
        })
        cal = parse_calibration(raw)
        assert cal.lpr.enabled is True
        assert cal.lpr.allowlist == ["12가3456", "99나0001", "77다9999"]

    def test_hash_plates_flag_roundtrips(self):
        import json
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["lpr"],
            "lpr": {"enabled": True, "hash_plates": True, "allowlist": []},
        })
        cal = parse_calibration(raw)
        assert cal.lpr.hash_plates is True

    def test_invalid_allowlist_type_falls_back_to_empty(self):
        import json
        from calibration import parse_calibration

        # allowlist must be a list — dict should be rejected gracefully.
        raw = json.dumps({
            "tasks_enabled": ["lpr"],
            "lpr": {"enabled": True, "allowlist": {"not": "a list"}},
        })
        cal = parse_calibration(raw)
        assert cal.lpr.enabled is True
        assert cal.lpr.allowlist == []


# ===========================================================================
# vlm.VLMPool._crop_hash  (perceptual dedup)
# ===========================================================================
@requires_cv2
@requires_numpy
class TestCropHash:
    def test_same_image_same_hash(self):
        import numpy as np

        from vlm import VLMPool

        pool = VLMPool()
        img = np.random.randint(0, 255, (128, 128, 3), dtype=np.uint8)
        assert pool._crop_hash(img) == pool._crop_hash(img.copy())

    def test_nearly_identical_crops_share_hash(self):
        import numpy as np

        from vlm import VLMPool

        pool = VLMPool()
        img = np.full((128, 128, 3), 120, dtype=np.uint8)
        jittered = img.copy()
        # Tiny pixel perturbation below the >mean bit-threshold → same hash
        jittered[0, 0] = [121, 121, 121]
        assert pool._crop_hash(img) == pool._crop_hash(jittered)

    def test_clearly_different_crops_differ(self):
        import numpy as np

        from vlm import VLMPool

        pool = VLMPool()
        a = np.zeros((128, 128, 3), dtype=np.uint8)
        b = np.full((128, 128, 3), 255, dtype=np.uint8)
        assert pool._crop_hash(a) != pool._crop_hash(b)


# ===========================================================================
# pipeline.SegmentCounter — operator-drawn IN/OUT segment counting
# ===========================================================================
@requires_integration_stack
class TestSegmentCounter:
    """Two arbitrary line segments. A track is counted exactly once after
    crossing BOTH lines, regardless of order. Crossing order tags the
    direction. Skipped when supervision/cv2/numpy aren't installed because
    pipeline.py imports them at module load.
    """

    def _counter(self):
        from pipeline import SegmentCounter

        # IN: vertical line at x=100, OUT: vertical line at x=200.
        return SegmentCounter(
            in_line=[[100.0, 0.0], [100.0, 500.0]],
            out_line=[[200.0, 0.0], [200.0, 500.0]],
        )

    def test_one_crossing_does_not_count(self):
        c = self._counter()
        c.update(tid=1, anchor=(50.0, 100.0), frame_idx=1)
        c.update(tid=1, anchor=(150.0, 100.0), frame_idx=2)  # crosses IN only
        assert 1 not in c.crossed
        assert c.in_crossings == 1
        assert c.out_crossings == 0

    def test_both_crossings_count_once(self):
        c = self._counter()
        c.update(tid=1, anchor=(50.0, 100.0), frame_idx=1)
        c.update(tid=1, anchor=(150.0, 100.0), frame_idx=2)
        c.update(tid=1, anchor=(250.0, 100.0), frame_idx=3)
        assert 1 in c.crossed
        assert c.direction(1) == "in_to_out"
        # Even if the track keeps moving, it stays counted exactly once.
        c.update(tid=1, anchor=(350.0, 100.0), frame_idx=4)
        assert len(c.crossed) == 1

    def test_reverse_direction_tagged(self):
        c = self._counter()
        c.update(tid=2, anchor=(250.0, 100.0), frame_idx=1)
        c.update(tid=2, anchor=(150.0, 100.0), frame_idx=2)  # OUT first
        c.update(tid=2, anchor=(50.0, 100.0), frame_idx=3)   # then IN
        assert 2 in c.crossed
        assert c.direction(2) == "out_to_in"

    def test_multiple_tracks_independent(self):
        c = self._counter()
        c.update(tid=1, anchor=(50.0, 100.0), frame_idx=1)
        c.update(tid=2, anchor=(50.0, 200.0), frame_idx=1)
        c.update(tid=1, anchor=(250.0, 100.0), frame_idx=2)  # tid 1 crosses both
        c.update(tid=2, anchor=(150.0, 200.0), frame_idx=2)  # tid 2 only crosses IN
        assert c.crossed == {1}

    def test_oscillating_track_only_counted_once(self):
        """A track that bounces over the IN line repeatedly without ever
        reaching the OUT line must NOT count — this is the overcount we're
        trying to fix vs. a single tripwire."""
        c = self._counter()
        for i, x in enumerate([50.0, 150.0, 50.0, 150.0, 50.0, 150.0]):
            c.update(tid=7, anchor=(x, 100.0), frame_idx=i + 1)
        assert 7 not in c.crossed


# ===========================================================================
# Auto-calibration: empty/placeholder geometry blocks accepted as
# "please auto-detect" rather than disabling the task.
# ===========================================================================
class TestAutoCalibrationParse:
    """Mobile's auto-mode submits a transit / traffic_light block with only
    the scalars (max_capacity, label) and no geometry. The parser must
    accept that and the predicates must report it as needing autofill."""

    def test_transit_without_stop_polygon_is_accepted(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["transit", "pedestrians"],
            "transit": {"max_capacity": 25},
        })
        cal = parse_calibration(raw)
        assert cal.transit is not None
        assert cal.transit.max_capacity == 25
        assert cal.transit.stop_polygon == []
        assert cal.transit.doors == []
        assert "transit" in cal.tasks_enabled
        assert cal.transit_needs_autofill() is True

    def test_transit_block_completely_absent_creates_placeholder(self):
        from calibration import parse_calibration

        raw = json.dumps({"tasks_enabled": ["transit", "pedestrians"]})
        cal = parse_calibration(raw)
        # Task enabled but no `transit` key at all → placeholder created so
        # the auto-cal pre-pass has somewhere to write its results.
        assert cal.transit is not None
        assert cal.transit_needs_autofill() is True

    def test_traffic_light_without_roi_is_accepted(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["traffic_light"],
            "traffic_lights": [{"label": "main"}],
        })
        cal = parse_calibration(raw)
        assert cal.traffic_light is not None
        assert len(cal.traffic_light.lights) == 1
        assert cal.traffic_light.lights[0].roi == [0, 0, 0, 0]
        assert cal.traffic_light_needs_autofill() is True

    def test_full_geometry_does_not_need_autofill(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["transit", "traffic_light"],
            "transit": {
                "stop_polygon": [[0, 0], [1, 0], [1, 1], [0, 1]],
                "max_capacity": 30,
                "doors": [{"line": [[0, 0.5], [1, 0.5]]}],
                "bus_zone_polygon": [[0, 0], [1, 0], [1, 0.5], [0, 0.5]],
            },
            "traffic_light": {"roi": [10, 10, 50, 50]},
        })
        cal = parse_calibration(raw)
        assert cal.transit_needs_autofill() is False
        assert cal.traffic_light_needs_autofill() is False


# ===========================================================================
# TransitEngine.apply_vlm_density_correction — wiring for VLM density
# overrides on crowded scenes.
# ===========================================================================
@requires_integration_stack
class TestTransitDensityCorrection:
    def _engine(self):
        from calibration import TransitCfg
        from tasks_transit import TransitEngine

        cfg = TransitCfg(
            stop_polygon=[[0, 0], [100, 0], [100, 100], [0, 100]],
            max_capacity=20,
            doors=[],
        )
        return TransitEngine(cfg=cfg, frame_w=200, frame_h=200)

    def test_vlm_count_replaces_undercount(self):
        eng = self._engine()
        eng.density_samples.append(
            {"t": 1.0, "count": 3, "density_pct": 15.0},
        )
        eng.peak_count = 3
        eng.apply_vlm_density_correction(timestamp_s=1.0, vlm_count=12)
        # Density sample updated and peak_count clamped upward.
        assert eng.density_samples[0]["count"] == 12
        assert eng.density_samples[0]["density_pct"] == 60.0
        assert eng.density_samples[0]["vlm_corrected"] is True
        assert eng.peak_count == 12

    def test_vlm_count_never_lowers_observed_count(self):
        eng = self._engine()
        # CV path observed 18, VLM (which can also miss occluded heads)
        # claims only 5 — keep the higher CV count.
        eng.density_samples.append(
            {"t": 2.0, "count": 18, "density_pct": 90.0},
        )
        eng.peak_count = 18
        eng.apply_vlm_density_correction(timestamp_s=2.0, vlm_count=5)
        assert eng.density_samples[0]["count"] == 18

    def test_correction_targets_closest_sample_in_time(self):
        eng = self._engine()
        eng.density_samples.extend([
            {"t": 0.5, "count": 2, "density_pct": 10.0},
            {"t": 5.0, "count": 4, "density_pct": 20.0},
            {"t": 9.5, "count": 1, "density_pct": 5.0},
        ])
        eng.apply_vlm_density_correction(timestamp_s=4.8, vlm_count=15)
        assert eng.density_samples[1]["count"] == 15
        assert eng.density_samples[0]["count"] == 2
        assert eng.density_samples[2]["count"] == 1

    def test_no_op_when_no_samples_yet(self):
        eng = self._engine()
        # Should not raise, should not silently invent a sample.
        eng.apply_vlm_density_correction(timestamp_s=1.0, vlm_count=10)
        assert eng.density_samples == []


# ===========================================================================
# auto_calibration.autofill_calibration — VLM-driven layout fill.
# Stubs the VLM pool so no Vertex AI credentials are required.
# ===========================================================================
@requires_cv2
@requires_numpy
class TestAutoCalibrationFill:
    def _make_video(self, tmp_path, frames: int = 30):
        import cv2
        import numpy as np

        path = str(tmp_path / "auto_cal.mp4")
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(path, fourcc, 10.0, (320, 240))
        # Solid grey frames are enough — the VLM layer is stubbed; we only
        # need the keyframe sampler to return something non-None.
        for _ in range(frames):
            frame = np.full((240, 320, 3), 128, dtype=np.uint8)
            writer.write(frame)
        writer.release()
        return path

    def test_autofill_skipped_when_disabled(self, tmp_path, monkeypatch):
        """VLM_AUTOCALIBRATE=0 disables the pre-pass entirely so CI can
        run without Vertex creds and existing behaviour is preserved."""
        import auto_calibration

        monkeypatch.setattr(auto_calibration, "VLM_AUTOCALIBRATE", False)

        from calibration import parse_calibration

        cal = parse_calibration(json.dumps({
            "tasks_enabled": ["transit"],
            "transit": {"max_capacity": 10},
        }))
        assert cal.transit_needs_autofill() is True
        result = auto_calibration.autofill_calibration("/nonexistent.mp4", cal)
        # Predicate is unchanged; autofill is a no-op.
        assert result is cal
        assert result.transit_needs_autofill() is True

    def test_autofill_uses_vlm_geometry(self, tmp_path, monkeypatch):
        import auto_calibration
        from calibration import parse_calibration

        # Stub the VLM pool: claim available, return canned JSON for the
        # BUS_STOP_LAYOUT request.
        monkeypatch.setattr(auto_calibration, "VLM_AUTOCALIBRATE", True)

        class _FakeFuture:
            def __init__(self, value):
                self._value = value

            def result(self, timeout):
                return self._value

        canned = {
            "bus_zone_polygon": [
                [0.10, 0.50], [0.90, 0.50], [0.90, 0.80], [0.10, 0.80],
            ],
            "door_lines": [
                {"line": [[0.30, 0.70], [0.70, 0.70]]},
            ],
            "stop_polygon": [
                [0.05, 0.60], [0.95, 0.60], [0.95, 0.95], [0.05, 0.95],
            ],
            "confidence": 0.9,
            "notes": "stubbed",
        }

        class _FakePool:
            def is_available(self):
                return True

            def submit(self, req):
                return _FakeFuture(canned)

        monkeypatch.setattr(auto_calibration, "vlm_pool", _FakePool())

        path = self._make_video(tmp_path)
        cal = parse_calibration(json.dumps({
            "tasks_enabled": ["transit"],
            "transit": {"max_capacity": 25},
        }))
        result = auto_calibration.autofill_calibration(path, cal)
        assert result.transit is not None
        assert len(result.transit.stop_polygon) == 4
        assert len(result.transit.doors) == 1
        assert result.transit.bus_zone_polygon is not None
        # Geometry is now in place — predicate flips.
        assert result.transit_needs_autofill() is False

    def test_autofill_falls_back_when_vlm_low_confidence(
        self, tmp_path, monkeypatch,
    ):
        import auto_calibration
        from calibration import parse_calibration

        monkeypatch.setattr(auto_calibration, "VLM_AUTOCALIBRATE", True)

        class _FakeFuture:
            def result(self, timeout):
                return {"confidence": 0.1}  # below threshold

        class _FakePool:
            def is_available(self):
                return True

            def submit(self, req):
                return _FakeFuture()

        monkeypatch.setattr(auto_calibration, "vlm_pool", _FakePool())

        path = self._make_video(tmp_path)
        cal = parse_calibration(json.dumps({
            "tasks_enabled": ["transit"],
            "transit": {"max_capacity": 30},
        }))
        result = auto_calibration.autofill_calibration(path, cal)
        # Falls back to the wide-bottom-band default so the engine still
        # has valid geometry to run.
        assert result.transit is not None
        assert len(result.transit.stop_polygon) >= 3
        assert len(result.transit.doors) >= 1
