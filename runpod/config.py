"""Central config: model IDs, class maps, thresholds, env vars.

Everything that might need a one-line swap on the RunPod pod lives here so
the rest of the codebase imports a single module.
"""
from __future__ import annotations

import os

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
RTDETR_WEIGHTS = os.environ.get(
    "RTDETR_WEIGHTS", "/workspace/runs/rtdetr_v13/weights/best.pt"
)
TRACKER_YAML = os.environ.get(
    "TRACKER_YAML",
    os.path.join(os.path.dirname(__file__), "custom_tracker.yaml"),
)
TEMP_DIR = os.environ.get("TEMP_DIR", "./temp_uploads")

# ---------------------------------------------------------------------------
# Detection / tracking thresholds
# ---------------------------------------------------------------------------
IMGSZ = int(os.environ.get("IMGSZ", "640"))
# CLAHE (Contrast-Limited Adaptive Histogram Equalization) on the L-channel
# of LAB colour space before detection. Lifts shadows in pre-dawn / night
# footage; ≈5 ms/frame CPU overhead. Opt-in via env var because day footage
# doesn't need it and it can amplify sensor noise on already-bright scenes.
LOW_LIGHT_BOOST = os.environ.get("LOW_LIGHT_BOOST", "0") == "1"
CLAHE_CLIP_LIMIT = float(os.environ.get("CLAHE_CLIP_LIMIT", "2.0"))
CLAHE_GRID_SIZE = int(os.environ.get("CLAHE_GRID_SIZE", "8"))
# FRAME_SKIP=2 keeps ByteTrack's IoU matching reliable for traffic up to ~80 km/h
# at 30 fps. FRAME_SKIP=3 was previously dropping fast tracks.
FRAME_SKIP = int(os.environ.get("FRAME_SKIP", "2"))
# Lowered from 0.50 → 0.30 to capture distant / partially-occluded vehicles
# that RT-DETR detects with moderate confidence. ByteTrack's track_low_thresh
# (0.1) keeps the noise floor in check.
DETECT_CONF = float(os.environ.get("DETECT_CONF", "0.30"))

# Mid-band: detections between these bounds trigger a VLM class re-verify.
VLM_REVERIFY_LOW = float(os.environ.get("VLM_REVERIFY_LOW", "0.35"))
VLM_REVERIFY_HIGH = float(os.environ.get("VLM_REVERIFY_HIGH", "0.60"))

# ---------------------------------------------------------------------------
# Vertex AI / Gemma
# ---------------------------------------------------------------------------
VERTEX_PROJECT = os.environ.get("VERTEX_PROJECT", "class-molit")
VERTEX_LOCATION = os.environ.get("VERTEX_LOCATION", "us-central1")
# User-specified model ID. Swap here if the probe call 404s at startup.
VLM_MODEL_ID = os.environ.get("VLM_MODEL_ID", "google/gemma-4-31B-it")
VLM_CONCURRENCY = int(os.environ.get("VLM_CONCURRENCY", "6"))
VLM_TIMEOUT_S = float(os.environ.get("VLM_TIMEOUT_S", "15.0"))
VLM_CIRCUIT_THRESHOLD = int(os.environ.get("VLM_CIRCUIT_THRESHOLD", "5"))
VLM_TEMPERATURE = float(os.environ.get("VLM_TEMPERATURE", "0.1"))

# ---------------------------------------------------------------------------
# Class maps
# ---------------------------------------------------------------------------
# RT-DETR output IDs → MOLIT 12-class names. Verified against best.pt's
# embedded class names (m.names). Note id 0 is labelled "5" in the model
# (string literal — appears to be a dataset-prep duplicate of class_5 / id 9).
# Treat it as MOLIT Class 5 to recover detections that were previously dropped.
VEHICLE_CLASS_NAMES: dict[int, str] = {
    0:  "Class 5 (3-Axle Truck)",   # model label "5" — alias of id 9
    2:  "Class 1 (Passenger/Van)",
    6:  "Class 2 (Bus)",
    7:  "Class 3 (Truck <2.5t)",
    8:  "Class 4 (Truck >=2.5t)",
    9:  "Class 5 (3-Axle Truck)",
    10: "Class 6 (4-Axle Truck)",
    11: "Class 7 (5-Axle Truck)",
    12: "Class 8 (4-Axle Semi-Trailer)",
    13: "Class 9 (4-Axle Full-Trailer)",
    3:  "Class 10 (5-Axle Semi-Trailer)",
    4:  "Class 11 (5-Axle Full-Trailer)",
    5:  "Class 12 (6+ Axle Semi-Trailer)",
}

# Non-vehicle categories.
# RT-DETR's best.pt has no pedestrian class, so pedestrian detection is
# provided by a secondary YOLO11n model (see PEDESTRIAN_YOLO_MODEL below).
# We map YOLO11n's COCO class 0 to ID 100 in our unified class space to
# avoid collision with RT-DETR's id 0 ("class_5" alias).
PEDESTRIAN_CLASS_ID = 100
TWO_WHEELER_CLASS_IDS = {1, 15, 16}             # bike, motorcycle, personal_mobility (all from RT-DETR)

NON_VEHICLE_CLASS_NAMES: dict[int, str] = {
    PEDESTRIAN_CLASS_ID: "Pedestrian",
    1:  "Bicycle",
    15: "Motorcycle",
    16: "Personal Mobility",
}

# ---------------------------------------------------------------------------
# Pedestrian detector (secondary YOLO alongside RT-DETR)
# ---------------------------------------------------------------------------
# best.pt has no person class. YOLO11n (COCO-trained) runs in parallel and
# contributes pedestrian detections only. Set ENABLE_PEDESTRIAN_DETECTOR=0 to
# disable (saves ~50% CPU inference time for vehicle-only runs).
ENABLE_PEDESTRIAN_DETECTOR = os.environ.get("ENABLE_PEDESTRIAN_DETECTOR", "1") == "1"
PEDESTRIAN_YOLO_MODEL = os.environ.get("PEDESTRIAN_YOLO_MODEL", "yolo11n.pt")
PEDESTRIAN_DETECT_CONF = float(os.environ.get("PEDESTRIAN_DETECT_CONF", "0.25"))
# Large offset so pedestrian tracker_ids never collide with vehicle tracker's.
# Each model.track() call has its own tracker state / tid namespace; we
# namespace-shift here to keep the merged sv.Detections uniquely identified.
PEDESTRIAN_TRACK_ID_OFFSET = 1_000_000

# Heavy-truck IDs — tripwire crossings of these trigger Gemma axle check.
HEAVY_TRUCK_IDS: set[int] = {3, 4, 5, 10, 11, 12, 13}

# Master lookup: every ID the pipeline knows about.
ALL_CLASS_NAMES: dict[int, str] = {**VEHICLE_CLASS_NAMES, **NON_VEHICLE_CLASS_NAMES}

VEHICLE_IDS: set[int] = set(VEHICLE_CLASS_NAMES.keys())
NON_VEHICLE_IDS: set[int] = set(NON_VEHICLE_CLASS_NAMES.keys())
TRACKED_IDS: set[int] = VEHICLE_IDS | NON_VEHICLE_IDS

# ---------------------------------------------------------------------------
# Traffic-light HSV ranges (OpenCV hue is 0-179)
# ---------------------------------------------------------------------------
HSV_RED_RANGES = [
    ((0, 120, 100),   (10, 255, 255)),    # low red
    ((160, 120, 100), (179, 255, 255)),   # high red (hue wraps)
]
HSV_GREEN_RANGE = ((40, 80, 80), (85, 255, 255))
HSV_YELLOW_RANGE = ((18, 120, 120), (34, 255, 255))
LIGHT_PIXEL_FRACTION = 0.05  # ≥5% of ROI pixels must match to call a state

# ---------------------------------------------------------------------------
# Track filtering — noise suppression for the polygon-zone count
# ---------------------------------------------------------------------------
# A real vehicle typically stays in frame for ≥0.5 s. We require at least this
# many sampled detections AND cumulative confidence before counting a track.
# Without this filter, ByteTrack's ID switches and transient false positives
# inflate the polygon-zone count ~2× on noisy / low-light footage.
MIN_TRACK_OBSERVATIONS = int(os.environ.get("MIN_TRACK_OBSERVATIONS", "5"))
MIN_TRACK_TOTAL_CONF = float(os.environ.get("MIN_TRACK_TOTAL_CONF", "2.0"))

# ---------------------------------------------------------------------------
# Job lifecycle
# ---------------------------------------------------------------------------
JOB_TTL_SECONDS = int(os.environ.get("JOB_TTL_SECONDS", "3600"))  # reap after 1h
