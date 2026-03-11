# GreyEye Traffic Analysis AI

Local-first, on-device traffic analytics app that detects, tracks, and classifies vehicles using the KICT/MOLIT 12-class taxonomy and records counts in 15-minute buckets. All inference and data storage happen on the smartphone — no backend servers required.

## Table of Contents

- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [ML Pipeline](#ml-pipeline)
- [Flutter App](#flutter-app)
- [Make Targets Reference](#make-targets-reference)
- [Design Documents](#design-documents)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Smartphone (On-Device)                     │
│                                                             │
│   Camera Feed                                               │
│       │                                                     │
│       ▼                                                     │
│   TFLite Detector (YOLOv8m)                                 │
│       │                                                     │
│       ▼                                                     │
│   ByteTrack Tracker ──► TFLite Classifier (EfficientNet-B0) │
│                              │                              │
│                              ▼                              │
│                     Temporal Smoother                        │
│                              │                              │
│                              ▼                              │
│                    Line Crossing Detector                    │
│                              │                              │
│                              ▼                              │
│                     SQLite (via Drift)                       │
│                              │                              │
│                              ▼                              │
│                        Flutter UI                            │
│                   (Charts, Export, ROI)                      │
│                                                             │
└──────────────────────────┬──────────────────────────────────┘
                           │ login / register only
                    ┌──────▼──────┐
                    │Supabase Auth│
                    └─────────────┘
```

The entire inference pipeline runs on a background isolate so the UI stays responsive. Vehicle crossing events are written to a local SQLite database, aggregated into 15-minute buckets, and visualised with `fl_chart`. CSV and PDF exports are generated on-device and shared via the system share sheet.

Supabase is used **only** for authentication (login, registration, token refresh). All traffic data stays on the device.

## Repository Structure

```
greyeye/
├── apps/mobile_flutter/         # Flutter app — UI, on-device inference, local DB
│   ├── lib/core/inference/      #   TFLite pipeline (detect → track → classify → smooth → cross)
│   ├── lib/core/database/       #   Drift/SQLite schema, DAOs, migrations
│   ├── lib/features/            #   Auth, sites, cameras, ROI, monitor, analytics, export
│   └── assets/models/           #   TFLite model files (detector.tflite, classifier.tflite)
├── ml/                          # Training, evaluation, and export scripts (Python)
│   ├── data/                    #   Dataset converters (AI Hub 091, COCO → GreyEye)
│   ├── training/                #   Detector and classifier training
│   ├── evaluation/              #   mAP, per-class F1, confusion matrix
│   ├── export/                  #   ONNX, TorchScript, and TFLite export
│   └── shared_contracts/        #   Enums, geometry, event schemas (reference)
└── docs/                        # Design documents (00–08)
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter | 3.3+ | Mobile app development |
| Xcode | latest | iOS builds |
| Android Studio / SDK | latest | Android builds |
| Python | 3.11+ | ML training and export pipeline |
| [uv](https://docs.astral.sh/uv/) | latest | Python package manager |
| CUDA toolkit | 12.x | (optional) GPU-accelerated ML training |

---

## Getting Started

### 1. Clone and install

```bash
git clone <repo-url> greyeye
cd greyeye

# Install Python dependencies (for ML pipeline)
make install
```

### 2. Configure environment

```bash
cp .env.example .env
# Fill in your Supabase project URL and anon key
```

The `.env` file only needs two values:

| Variable | Purpose |
|----------|---------|
| `GREYEYE_SUPABASE_URL` | Your Supabase project URL |
| `GREYEYE_SUPABASE_ANON_KEY` | Supabase anonymous/public key |

### 3. Export TFLite models

If you have trained detector and classifier checkpoints:

```bash
# Export both models to TFLite and copy to Flutter assets
make export-tflite
```

This produces `detector.tflite` and `classifier.tflite` in `apps/mobile_flutter/assets/models/`.

### 4. Run the Flutter app

```bash
# Get dependencies and run
make flutter-run

# Or manually:
cd apps/mobile_flutter
flutter pub get
flutter run
```

---

## ML Pipeline

Training, evaluation, and export scripts live in `ml/`. These run on a development machine (not on the phone).

### Data preparation

```bash
# Convert AI Hub 091 annotations to GreyEye format
uv run python ml/data/aihub091_to_greyeye.py --input <path> --output ml/data/processed/

# Convert COCO vehicle subset
uv run python ml/data/coco_to_greyeye.py --input <path> --output ml/data/processed/
```

### Training

```bash
# Train detector (YOLO)
uv run python ml/training/train_detector.py --config ml/training/configs/detector.yaml

# Train classifier (EfficientNet-B0)
uv run python ml/training/train_classifier.py --config ml/training/configs/classifier.yaml
```

### Evaluation

```bash
uv run python -m ml.evaluation.evaluate --model <path> --dataset <path>
```

### Export to TFLite

```bash
# Export both models and copy to Flutter assets
make export-tflite

# Export all formats (ONNX, TorchScript, TFLite)
make export-all
```

The `export-tflite` target:
1. Exports the detector checkpoint to TFLite via Ultralytics
2. Exports the classifier checkpoint to TFLite via PyTorch → ONNX → TFLite
3. Copies both `.tflite` files into `apps/mobile_flutter/assets/models/`

Override checkpoint paths or version:

```bash
DETECTOR_CKPT=path/to/best.pt CLASSIFIER_CKPT=path/to/best.pt MODEL_VERSION=v2.0.0 make export-tflite
```

The ML CI workflow (`.github/workflows/ml-pipeline.yml`) validates exports and runs non-GPU tests on every push to `ml/`.

---

## Flutter App

The app lives in `apps/mobile_flutter/`. See [apps/mobile_flutter/README.md](apps/mobile_flutter/README.md) for detailed build and run instructions.

### Quick start

```bash
cd apps/mobile_flutter
flutter pub get
flutter run
```

### Key packages

| Package | Purpose |
|---------|---------|
| `tflite_flutter` | On-device TFLite inference |
| `camera` | Live camera feed |
| `drift` + `sqlite3_flutter_libs` | Local SQLite database |
| `supabase_flutter` | Authentication (login, register) |
| `fl_chart` | Analytics charts |
| `csv` / `pdf` / `share_plus` | On-device CSV/PDF export and sharing |
| `flutter_riverpod` | State management |
| `go_router` | Navigation |

### Code generation

After modifying Drift tables, Freezed models, or JSON-serializable classes:

```bash
make flutter-codegen
```

### Testing

```bash
make flutter-test
```

### Building

```bash
# Release APK
make flutter-build

# Or manually:
cd apps/mobile_flutter
flutter build apk --release      # Android APK
flutter build appbundle --release # Android App Bundle
flutter build ios --release       # iOS
```

---

## Linting and Type Checking

For the ML Python code:

```bash
# Lint with ruff
make lint

# Auto-format
make format

# Type check with mypy
make typecheck

# All static checks
make check
```

---

## Make Targets Reference

Run `make help` to see all targets.

| Target | Description |
|--------|-------------|
| **Environment** | |
| `install` | Install all Python workspace dependencies with uv |
| `install-dev` | Install deps + pre-commit hooks |
| **Quality** | |
| `lint` | Run ruff linter and formatter check |
| `format` | Auto-format code with ruff |
| `typecheck` | Run mypy type checking |
| `check` | Run all static checks (lint + typecheck) |
| **Testing** | |
| `test` | Run ML unit tests |
| `test-all` | Run all tests (including slow) |
| `test-cov` | Run tests with coverage report |
| **ML Export** | |
| `export-tflite` | Export detector + classifier to TFLite, copy to Flutter assets |
| `export-all` | Export to all formats (ONNX, TorchScript, TFLite) |
| **Flutter** | |
| `flutter-run` | Run the Flutter app in debug mode |
| `flutter-build` | Build release APK |
| `flutter-test` | Run Flutter unit tests |
| `flutter-codegen` | Run Drift and other code generation |
| **Utilities** | |
| `clean` | Remove build artefacts and caches |
| `help` | Show all available targets |

---

## Design Documents

Full design specification in `docs/`:

| Document | Description |
|----------|-------------|
| `00-overview.md` | Document map, glossary, 12-class vehicle taxonomy |
| `01-system-architecture.md` | Architecture, deployment topology, scaling strategy |
| `02-software-design.md` | Service design, API contracts, event schemas |
| `03-mobile-ui-design.md` | Flutter app screens, navigation, ROI editor UX |
| `04-database-design.md` | Schema, indexes, RLS policies, migration strategy |
| `05-ai-ml-pipeline.md` | Detection, tracking, classification, training pipeline |
| `06-security-and-compliance.md` | Auth, encryption, privacy, audit logging |
| `07-backup-and-recovery.md` | Backup strategy, RPO/RTO targets, disaster recovery |
| `08-deployment-readiness-checklist.md` | Deployment blockers, pre-deploy gate, launch risks |

> **Note:** Some design documents still reference the original distributed architecture. The app now runs entirely on-device with Supabase Auth only.
