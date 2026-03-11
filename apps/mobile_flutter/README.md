# GreyEye Mobile

Self-contained Flutter app for vehicle detection and traffic monitoring. All
inference runs on-device using TFLite models — no backend servers required.

## Architecture

The app runs a 5-stage inference pipeline entirely on the phone:

1. **TFLite Detector** (YOLOv8m) — detects vehicles in camera frames
2. **ByteTrack Tracker** — assigns persistent IDs across frames
3. **TFLite Classifier** (EfficientNet-B0) — classifies each vehicle into 12 KICT/MOLIT classes
4. **Temporal Smoother** — stabilises class predictions over time
5. **Line Crossing Detector** — counts vehicles crossing user-defined lines

All traffic data is stored locally in SQLite via Drift. Supabase is used
only for authentication.

## Prerequisites

- Flutter SDK 3.3+
- Xcode (for iOS builds)
- Android Studio or Android SDK (for Android builds)
- TFLite model files in `assets/models/` (see [Exporting models](#exporting-models))

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

The app reads Supabase credentials from the root `.env` file. From the repo
root:

```bash
cp .env.example .env
# Fill in GREYEYE_SUPABASE_URL and GREYEYE_SUPABASE_ANON_KEY
```

### 3. Exporting models

TFLite model files must be placed in `assets/models/` before building. From
the repo root:

```bash
make export-tflite
```

This exports `detector.tflite` and `classifier.tflite` from trained
checkpoints and copies them into `assets/models/`.

### 4. Code generation

After modifying Drift tables, Freezed models, or JSON-serializable classes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Or from the repo root:

```bash
make flutter-codegen
```

## Running

### Emulator or connected device

```bash
flutter run
```

### Specific device

```bash
flutter devices
flutter run -d <device-id>
```

### From the repo root

```bash
make flutter-run
```

## Android-specific notes

### USB debugging

1. Enable Developer Options on the phone
2. Enable USB debugging
3. Trust the computer when prompted

The app is configured to allow cleartext HTTP traffic in development (for
Supabase on local emulators if needed).

## iPhone-specific notes

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the `Runner` target
3. Set a valid Team under Signing & Capabilities
4. Use a unique bundle identifier if needed
5. Trust the developer certificate on the device if prompted

Then:

```bash
flutter run -d <iphone-device-id>
```

## Testing

```bash
flutter test

# With coverage
flutter test --coverage
```

## Building

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

Or from the repo root:

```bash
make flutter-build
```

## Project structure

```
lib/
├── core/
│   ├── inference/           # On-device TFLite pipeline
│   │   ├── detector.dart    #   YOLOv8m detection + NMS
│   │   ├── classifier.dart  #   EfficientNet-B0 classification
│   │   ├── tracker.dart     #   ByteTrack multi-object tracker
│   │   ├── temporal_smoother.dart
│   │   ├── line_crossing.dart
│   │   ├── inference_pipeline.dart  # Orchestrator
│   │   └── inference_isolate.dart   # Background isolate wrapper
│   ├── database/            # Drift/SQLite schema and DAOs
│   │   ├── tables.dart      #   Table definitions
│   │   ├── database.dart    #   Database class
│   │   └── daos/            #   Data access objects
│   ├── network/             # API client (minimal, auth-related)
│   ├── router/              # GoRouter navigation
│   └── constants/           # App-wide constants
├── features/
│   ├── auth/                # Login, register (Supabase Auth)
│   ├── sites/               # Site management (local SQLite)
│   ├── camera/              # Camera management (local SQLite)
│   ├── roi/                 # ROI editor, counting lines
│   ├── monitor/             # Live camera feed with detection overlay
│   ├── analytics/           # Charts and aggregated traffic data
│   ├── onboarding/          # Quick setup wizard
│   └── settings/            # App settings
└── main.dart
```

## Key dependencies

| Package | Purpose |
|---------|---------|
| `tflite_flutter` | TFLite model inference |
| `camera` | Live camera feed |
| `image` | Frame preprocessing (resize, normalize) |
| `drift` + `sqlite3_flutter_libs` | Local SQLite database |
| `supabase_flutter` | Authentication only |
| `fl_chart` | Analytics charts |
| `csv` / `pdf` / `share_plus` | On-device export and sharing |
| `flutter_riverpod` | State management |
| `go_router` | Routing |

## Troubleshooting

**App crashes on launch:**
- Ensure TFLite model files exist in `assets/models/`
- Run `make export-tflite` from the repo root

**Login fails:**
- Check that `.env` has valid Supabase credentials
- Verify the Supabase project is accessible

**Detection is slow or inaccurate:**
- Ensure you are using release mode (`flutter run --release`) for best
  inference performance
- The inference pipeline runs on a background isolate; debug mode adds
  significant overhead

**Build fails on iOS:**
- Open `ios/Runner.xcworkspace` in Xcode and fix signing first
- Run `pod install` in the `ios/` directory if CocoaPods are out of date

**Code generation errors after editing tables:**
- Run `dart run build_runner build --delete-conflicting-outputs`
