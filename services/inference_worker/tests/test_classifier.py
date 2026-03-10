"""Tests for Stage 3: 12-Class Vehicle Classification."""

from __future__ import annotations

import numpy as np
import pytest

from inference_worker.models import ClassPrediction
from inference_worker.stages.classifier import (
    StubClassifierBackend,
    VehicleClassifier,
    apply_coarse_fallback,
    _softmax,
)
from shared_contracts.enums import VehicleClass12
from shared_contracts.geometry import BoundingBox


@pytest.fixture
def classifier(classifier_settings):
    return VehicleClassifier(classifier_settings, backend=StubClassifierBackend())


class TestSoftmax:
    def test_sums_to_one(self):
        x = np.array([1.0, 2.0, 3.0])
        s = _softmax(x)
        assert abs(s.sum() - 1.0) < 1e-6

    def test_preserves_order(self):
        x = np.array([1.0, 5.0, 3.0])
        s = _softmax(x)
        assert s[1] > s[2] > s[0]


class TestCoarseFallback:
    def test_high_confidence_no_fallback(self):
        pred = ClassPrediction(
            class12=VehicleClass12.C05_SINGLE_3_AXLE,
            probabilities=[0.0] * 4 + [0.8] + [0.0] * 7,
            confidence=0.8,
            crop_bbox=BoundingBox(x=0.1, y=0.1, w=0.2, h=0.2),
        )
        result = apply_coarse_fallback(pred, threshold=0.4)
        assert result.class12 == VehicleClass12.C05_SINGLE_3_AXLE

    def test_low_confidence_triggers_fallback(self):
        probs = [0.0] * 12
        probs[0] = 0.3  # C01 car group: 0.3
        probs[1] = 0.05  # C02 bus group: 0.05
        probs[2] = 0.05  # truck group members: 0.05 each
        pred = ClassPrediction(
            class12=VehicleClass12.C01_PASSENGER_MINITRUCK,
            probabilities=probs,
            confidence=0.3,
            crop_bbox=BoundingBox(x=0.1, y=0.1, w=0.2, h=0.2),
        )
        result = apply_coarse_fallback(pred, threshold=0.4)
        assert result.class12 == VehicleClass12.C01_PASSENGER_MINITRUCK
        assert result.confidence >= 0.3


class TestVehicleClassifier:
    def test_stub_returns_predictions(self, classifier, small_frame):
        bboxes = [
            BoundingBox(x=0.1, y=0.1, w=0.3, h=0.3),
            BoundingBox(x=0.5, y=0.5, w=0.2, h=0.2),
        ]
        preds = classifier.classify_crops(small_frame, bboxes)
        assert len(preds) == 2
        for p in preds:
            assert len(p.probabilities) == 12
            assert abs(sum(p.probabilities) - 1.0) < 1e-4

    def test_empty_bboxes(self, classifier, small_frame):
        preds = classifier.classify_crops(small_frame, [])
        assert preds == []

    def test_disabled_mode(self, classifier_settings, small_frame):
        classifier_settings.mode = "disabled"
        classifier = VehicleClassifier(classifier_settings, backend=StubClassifierBackend())
        bboxes = [BoundingBox(x=0.1, y=0.1, w=0.2, h=0.2)]
        preds = classifier.classify_crops(small_frame, bboxes)
        assert len(preds) == 1
        assert preds[0].confidence == 0.0

    def test_custom_backend(self, classifier_settings, small_frame):
        class DeterministicBackend:
            def classify_batch(self, crops):
                n = crops.shape[0]
                logits = np.zeros((n, 12), dtype=np.float32)
                logits[:, 1] = 5.0  # C02_BUS dominant
                return logits

        classifier = VehicleClassifier(
            classifier_settings, backend=DeterministicBackend()
        )
        bboxes = [BoundingBox(x=0.1, y=0.1, w=0.3, h=0.3)]
        preds = classifier.classify_crops(small_frame, bboxes)
        assert len(preds) == 1
        assert preds[0].class12 == VehicleClass12.C02_BUS
