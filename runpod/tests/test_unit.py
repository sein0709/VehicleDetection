"""No-GPU unit tests — calibration parser, HSV state machine, plate
normalizer, crop hash. Runs in seconds on any machine with cv2 + numpy.
"""
from __future__ import annotations

import json

import pytest

from conftest import requires_cv2, requires_numpy


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

    def test_lpr_disabled_drops_from_tasks(self):
        from calibration import parse_calibration

        raw = json.dumps({
            "tasks_enabled": ["vehicles", "lpr"],
            "lpr": {"enabled": False},
        })
        cal = parse_calibration(raw)
        assert cal.lpr.enabled is False
        assert "lpr" not in cal.tasks_enabled


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
