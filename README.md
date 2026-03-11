# GreyEye Traffic Analysis AI

Smartphone-first traffic analytics system that detects, tracks, and classifies vehicles using the KICT/MOLIT 12-class taxonomy and records counts in 15-minute buckets. Built as a monorepo with 8 backend microservices, a Flutter mobile app, and a full ML training pipeline.

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Running Locally](#running-locally)
- [Testing](#testing)
- [Linting and Type Checking](#linting-and-type-checking)
- [Docker Builds](#docker-builds)
- [Deployment](#deployment)
- [Observability](#observability)
- [Backup and DR](#backup-and-dr)
- [Load Testing](#load-testing)
- [Mobile App (Flutter)](#mobile-app-flutter)
- [ML Pipeline](#ml-pipeline)
- [Make Targets Reference](#make-targets-reference)
- [Design Documents](#design-documents)

---

## Architecture

```
                    ┌──────────────┐
                    │  Flutter App │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ API Gateway  │  Nginx — TLS, rate limiting, circuit breaker
                    └──────┬───────┘
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────▼──────┐ ┌──────▼──────┐ ┌───────▼───────┐
   │ Auth Service│ │Config Service│ │ Ingest Service│
   └─────────────┘ └─────────────┘ └───────┬───────┘
                                           │ NATS
                                   ┌───────▼───────┐
                                   │Inference Worker│  YOLO + ByteTrack + EfficientNet
                                   └───────┬───────┘
                                           │ NATS
                          ┌────────────────┼────────────────┐
                   ┌──────▼──────┐                   ┌──────▼──────────┐
                   │  Aggregator │                   │Notification Svc │
                   └──────┬──────┘                   └─────────────────┘
                   ┌──────▼──────┐
                   │Reporting API│  Analytics, WebSocket, CSV/PDF export
                   └─────────────┘
```

**Data stores:** PostgreSQL 16, Redis 7, NATS JetStream, S3 (MinIO locally)

## Monorepo Structure

```
greyeye/
├── apps/mobile_flutter/         # Flutter 3.x mobile app (Riverpod + GoRouter)
├── services/                    # Backend microservices (FastAPI)
│   ├── api_gateway/             # Nginx reverse proxy
│   ├── auth_service/            # Authentication & RBAC (4 roles)
│   ├── config_service/          # Site / camera / ROI CRUD with versioning
│   ├── ingest_service/          # Frame upload, heartbeat, backpressure
│   ├── inference_worker/        # Detection → tracking → classification pipeline
│   ├── aggregator/              # 15-min bucket computation, idempotent upsert
│   ├── reporting_api/           # Analytics queries, WebSocket KPI, export
│   └── notification_service/    # Alert rules, evaluation, multi-channel delivery
├── libs/                        # Shared libraries
│   ├── shared_contracts/        # Pydantic models, enums, event schemas
│   ├── db_models/               # SQLAlchemy/Alembic models & migrations
│   ├── observability/           # Structured logging, metrics, tracing
│   └── test_utils/              # Test fixtures & factories
├── ml/                          # Training, evaluation, export, data converters
├── infra/                       # Docker, Helm, Terraform, observability configs
├── tests/loadtest/              # Load and performance tests (Locust + custom)
├── supabase/                    # Database migrations & seed data
└── docs/                        # Design documents (00–07)
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.11+ | Backend services, ML pipeline |
| [uv](https://docs.astral.sh/uv/) | latest | Python package/workspace manager |
| Docker & Compose | 24+ | Local infrastructure, container builds |
| Node.js | (optional) | Only if running frontend tooling |
| Flutter | 3.3+ | Mobile app development |
| Helm | 3.x | Kubernetes deployments |
| Terraform | 1.5+ | Cloud infrastructure provisioning |
| kubectl | 1.29+ | Kubernetes cluster management |
| CUDA toolkit | 12.x | (optional) GPU-accelerated inference |

---

## Getting Started

### 1. Clone and install

```bash
git clone <repo-url> greyeye
cd greyeye

# Install all Python workspace dependencies
make install

# Install with pre-commit hooks (recommended for development)
make install-dev
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env if you need to override defaults (most work out of the box)
```

### 3. Start local infrastructure

```bash
# Start PostgreSQL, Redis, NATS, MinIO
make dev-up
```

This brings up:

| Service | URL | Credentials |
|---------|-----|-------------|
| PostgreSQL | `localhost:5432` | `greyeye` / `greyeye_dev` |
| Redis | `localhost:6379` | — |
| NATS | `localhost:4222` | — |
| NATS Monitor | `http://localhost:8222` | — |
| MinIO API | `http://localhost:9000` | `greyeye` / `greyeye_dev` |
| MinIO Console | `http://localhost:9001` | `greyeye` / `greyeye_dev` |
| API Gateway | `http://localhost:8080` | — |

### 4. Set up the database

```bash
# Apply all Alembic migrations
make migrate

# Load demo organisation, users, sample site + camera
make seed
```

### 5. Bootstrap NATS streams

```bash
# Create all JetStream streams and consumers
make nats-bootstrap

# Verify streams match expected config
make nats-verify
```

---

## Running Locally

Each service can be run individually with `uv run`. They default to the ports shown below:

```bash
# Auth service (port 8001)
cd services/auth_service && uv run uvicorn auth_service.app:app --port 8001 --reload

# Config service (port 8002)
cd services/config_service && uv run uvicorn config_service.app:app --port 8002 --reload

# Ingest service (port 8003)
cd services/ingest_service && uv run uvicorn ingest_service.app:app --port 8003 --reload

# Inference worker (port 8004) — requires GPU for full speed
cd services/inference_worker && uv run python -m inference_worker.worker

# Aggregator (port 8006)
cd services/aggregator && uv run python -m aggregator.app

# Reporting API (port 8005)
cd services/reporting_api && uv run uvicorn reporting_api.app:app --port 8005 --reload

# Notification service (port 8007)
cd services/notification_service && uv run uvicorn notification_service.app:app --port 8007 --reload
```

The API gateway (Nginx) runs on port 8080 via Docker Compose and proxies to all services.

### Observability stack

```bash
# Start Prometheus, Alertmanager, Grafana, Loki, Tempo
make obs-up
```

| Tool | URL | Credentials |
|------|-----|-------------|
| Prometheus | `http://localhost:9090` | — |
| Alertmanager | `http://localhost:9093` | — |
| Grafana | `http://localhost:3000` | `admin` / `greyeye` |
| Loki | `http://localhost:3100` | — |
| Tempo | `http://localhost:3200` | — |

```bash
# Stop observability stack
make obs-down
```

### Tear down

```bash
# Stop containers (preserves data)
make dev-down

# Stop and destroy all volumes (full reset)
make dev-reset
```

---

## Testing

### Unit tests

```bash
# Run unit tests only (excludes integration and slow tests)
make test

# Run with coverage report
make test-cov
```

### All tests (including integration)

```bash
# Requires local infrastructure to be running (make dev-up)
# and explicit opt-in for NATS integration coverage.
RUN_INTEGRATION_TESTS=1 make test-all
```

### Running tests for a specific service

```bash
# Example: auth service tests
uv run pytest services/auth_service/tests/ -v

# Example: inference worker tests
uv run pytest services/inference_worker/tests/ -v

# Example: shared contracts tests
uv run pytest libs/shared_contracts/tests/ -v

# Example: NATS JetStream integration tests
RUN_INTEGRATION_TESTS=1 uv run pytest -m integration \
  libs/shared_contracts/tests/test_nats_integration.py -v
```

### Test markers

Tests are tagged with markers that can be used to filter:

```bash
# Skip integration tests
uv run pytest -m "not integration"

# Only slow tests
uv run pytest -m "slow"

# Only load tests
uv run pytest -m "loadtest"
```

### Test structure

```
libs/shared_contracts/tests/     # Enums, geometry, events, NATS, encryption, privacy
libs/observability/tests/        # Logging, metrics, tracing, sanitization, middleware
services/auth_service/tests/     # Auth routes, RBAC, tokens, user routes
services/config_service/tests/   # Sites, cameras, ROI, config versioning, Redis health
services/ingest_service/tests/   # Frame upload, sessions, heartbeat, NATS/Redis clients
services/inference_worker/tests/ # Detector, tracker, classifier, smoother, line crossing
services/aggregator/tests/       # Accumulator, NATS consumer, Redis publisher, DB
services/reporting_api/tests/    # Analytics routes, reports, export engine
services/notification_service/tests/ # Rule engine, delivery, NATS consumer, alert routes
services/api_gateway/tests/      # Nginx config validation
tests/loadtest/                  # Load and performance test scenarios
```

---

## Linting and Type Checking

```bash
# Lint with ruff (check only)
make lint

# Auto-format with ruff
make format

# Type check with mypy
make typecheck

# Run all static checks (lint + typecheck)
make check
```

Pre-commit hooks run automatically on `git commit` if installed with `make install-dev`. They include:

- **ruff** — linting and formatting
- **mypy** — type checking
- **gitleaks** — secret scanning
- **bandit** — security linting
- **pre-commit-hooks** — YAML/JSON validation, merge conflict detection, private key detection

---

## Docker Builds

```bash
# Build all service images (tagged with current git SHA)
make docker-build

# Build a single service
make docker-build-auth_service

# Push all images to the registry
make docker-push

# Override registry or tag
REGISTRY=my-registry.io/greyeye TAG=v1.0.0 make docker-build
```

Images are built using multi-stage Dockerfiles in `infra/docker/` for minimal image size.

---

## Deployment

### Environments

| Environment | Trigger | URL |
|-------------|---------|-----|
| **Local** | `make dev-up` | `http://localhost:8080` |
| **Staging** | Auto-deploy on `main` after CI passes | `https://api-staging.greyeye.io` |
| **Production** | Manual workflow dispatch with approval | `https://api.greyeye.io` |

### Infrastructure provisioning (Terraform)

```bash
# Bootstrap the Terraform state backend (run once)
make tf-bootstrap

# Plan changes for an environment
TF_ENV=production make tf-plan

# Apply changes
make tf-apply

# Format and validate Terraform files
make tf-fmt
make tf-validate
```

Infrastructure is defined in `infra/terraform/` with modules for VPC, EKS, RDS, ElastiCache, S3, NATS, WAF, KMS, DNS, and DR.

### Helm deployments

```bash
# Lint the umbrella chart
make helm-lint

# Render templates locally (dry-run)
make helm-template

# Render with production values
make helm-template-prod
```

### Deploying to staging

Staging deploys automatically when CI passes on `main`:

1. CI workflow runs lint, typecheck, and tests
2. Docker images are built and pushed to `ghcr.io/greyeye`
3. `deploy-staging.yml` runs Helm upgrade with staging values
4. Smoke tests validate health endpoints and auth flow
5. Automatic rollback on smoke test failure

### Deploying to production

Production requires manual approval:

```bash
# Trigger via GitHub CLI
gh workflow run deploy-production.yml -f image_tag=a1b2c3d

# Or use the full launch orchestrator (includes canary model deploy + burn-in)
gh workflow run production-launch.yml \
  -f image_tag=a1b2c3d \
  -f detector_model_version=detector-v1.0.0 \
  -f detector_model_s3_path=s3://greyeye-models-prod/detector/v1.0.0/model.onnx \
  -f classifier_model_version=classifier-v1.0.0 \
  -f classifier_model_s3_path=s3://greyeye-models-prod/classifier/v1.0.0/model.onnx
```

The production launch workflow runs:

1. **Pre-flight** — Helm lint, image verification, model artifact check, cluster health
2. **Rolling deploy** — `helm upgrade --atomic` with 15-min timeout
3. **Smoke tests** — Health checks, auth flow, site/camera CRUD, analytics endpoints
4. **Canary model deploy** — Detector then classifier, each progressing 10% -> 50% -> 100%
5. **Alerting verification** — Confirms Prometheus rules loaded, no critical alerts firing
6. **24h burn-in** — Automated monitoring with SLO checks every 15 minutes

Rollback is automatic on any failure. See `infra/runbooks/production-launch.md` for the full checklist.

### Canary model deployment

ML models can be deployed independently with progressive rollout:

```bash
gh workflow run canary-model-deploy.yml \
  -f model_version=detector-v2.1.0 \
  -f model_type=detector \
  -f model_s3_path=s3://greyeye-models-prod/detector/v2.1.0/model.onnx \
  -f target_environment=production
```

Each stage (10%, 50%, 100%) includes 5-minute monitoring with automatic rollback on excessive pod restarts.

### Production smoke tests

```bash
# Run comprehensive smoke tests against any environment
API_BASE_URL=https://api.greyeye.io \
SMOKE_TEST_PASSWORD=<password> \
make smoke-test

# Or directly
bash infra/scripts/production-smoke-test.sh --api-url https://api.greyeye.io --password <pw>
```

### 24h burn-in

```bash
# Start full 24h burn-in (checks every 15 min)
make burn-in

# Quick 1h validation (checks every 5 min)
make burn-in-short

# Or via GitHub Actions
gh workflow run burn-in.yml -f duration_hours=24 -f interval_minutes=15
```

---

## Observability

### Dashboards (Grafana)

Six pre-provisioned dashboards in `infra/observability/grafana/dashboards/`:

| Dashboard | Key Metrics |
|-----------|------------|
| System Overview | Service availability, pod health, request rates |
| Inference Pipeline | p95 latency, GPU utilisation, queue depth, error rate |
| Traffic Analytics | Crossing events/min, class distribution, flow rate |
| Database | Connection pool, query latency, replication lag |
| Alerts & Notifications | Delivery success rate, rule evaluation time |
| Backup & DR | Backup freshness, WAL archiving, DR replica lag |

### Alert rules (Prometheus)

Alert rules are defined in `infra/observability/prometheus/rules/`:

- **`service-alerts.yml`** — 30+ rules covering inference, API, gateway, NATS, aggregation, database, Redis, cameras, notifications, and pod health
- **`backup-alerts.yml`** — Backup freshness, WAL archiving, DR replication, restore drill status

### Alertmanager routing

Alerts are routed to PagerDuty and Slack based on severity and team:

| Severity | Channel |
|----------|---------|
| Critical (platform) | PagerDuty platform rotation + Slack `#greyeye-incidents` |
| Critical (ML) | PagerDuty ML rotation + Slack `#greyeye-incidents` |
| Warning | Slack `#greyeye-alerts` |
| Operations | Slack `#greyeye-operations` |

### Checking alerts

```bash
# List firing alerts
make alerts-check

# List loaded rule groups
make alerts-rules
```

---

## Backup and DR

```bash
# Show backup and DR status
make backup-status

# Trigger immediate full backup
make backup-full

# Trigger immediate differential backup
make backup-diff

# Trigger restore drill
make restore-drill

# DR failover (requires confirmation)
make dr-failover

# DR failover dry-run
make dr-failover-dry-run

# DR failback
make dr-failback
```

Backup schedule (production): daily full at 02:00 UTC, differential every 6 hours, continuous WAL archiving. DR standby in `ap-northeast-1` (Tokyo) with cross-region replication.

---

## Load Testing

```bash
# MVP target: 10 cameras @ 10 FPS, 2 min
make loadtest-mvp

# Scale target: 100 cameras @ 10 FPS, 5 min
make loadtest-scale

# Backpressure verification
make loadtest-backpressure

# Latency verification (p95 < 1.5s)
make loadtest-latency

# NATS pipeline throughput
make loadtest-pipeline

# All scenarios
make loadtest-all

# Quick mode (reduced durations, suitable for CI)
make loadtest-quick

# Interactive Locust web UI
make loadtest-locust

# Headless Locust run
make loadtest-locust-headless
```

Load test configuration is in `tests/loadtest/`. See `.env.loadtest.example` for environment variables.

---

## Mobile App (Flutter)

The Flutter app lives in `apps/mobile_flutter/`.

### Prerequisites

- Flutter SDK 3.3+
- Xcode (for iOS builds)
- Android Studio or Android SDK (for Android builds)

### Running

```bash
cd apps/mobile_flutter

# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Run with a specific API endpoint
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

### Testing

```bash
cd apps/mobile_flutter

# Run widget and unit tests
flutter test

# Run with coverage
flutter test --coverage
```

### Building

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

The Flutter CI workflow (`.github/workflows/flutter.yml`) runs analysis, tests, and builds on every push to paths under `apps/mobile_flutter/`.

---

## ML Pipeline

Training, evaluation, and export scripts are in `ml/`.

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
# Run evaluation suite (mAP, per-class F1, confusion matrix)
uv run python -m ml.evaluation.evaluate --model <path> --dataset <path>
```

### Export

```bash
# Export to ONNX + TorchScript with numerical validation
uv run python ml/export/export_onnx.py --checkpoint <path> --output ml/export/output/
```

### Local real-data pilot

Once you have real ONNX artifacts loaded into the inference worker, you can
push a local clip through the running dev stack with:

```bash
uv run python infra/scripts/local_video_eval.py /abs/path/to/video.mp4
```

The script will:
- create or log into a local test user
- create a site and camera
- create an ingest session
- upload sampled JPEG frames from the clip
- poll Redis for live inference state and live KPI bucket data

Current limitation: this repo does not automatically push counting-line config
from the config service into the running inference worker, so bucket/count
results may stay empty even when frame ingestion succeeds.

To scan common local folders for detector/classifier artifacts and wire real
ONNX files into the repo-default paths, use:

```bash
uv run python infra/scripts/prepare_local_models.py \
  --detector /abs/path/to/detector/model.onnx \
  --classifier /abs/path/to/classifier/model.onnx
```

This will validate the ONNX files and link them to:
- `models/detector/model.onnx`
- `models/classifier/model.onnx`

The ML CI workflow (`.github/workflows/ml-pipeline.yml`) validates exports and runs non-GPU tests on every push to `ml/` or `libs/shared_contracts/`.

---

## Make Targets Reference

Run `make help` to see all targets. Full list:

| Target | Description |
|--------|-------------|
| **Environment** | |
| `install` | Install all workspace dependencies with uv |
| `install-dev` | Install deps + pre-commit hooks |
| **Infrastructure** | |
| `dev-up` | Start local dev stack (Postgres, Redis, NATS, MinIO) |
| `dev-down` | Stop and remove containers |
| `dev-reset` | Stop dev stack and destroy all volumes |
| `dev-logs` | Tail logs from all dev stack services |
| `obs-up` | Start observability stack (Prometheus, Alertmanager, Grafana, Loki, Tempo) |
| `obs-down` | Stop observability stack |
| **Quality** | |
| `lint` | Run ruff linter and formatter check |
| `format` | Auto-format code with ruff |
| `typecheck` | Run mypy type checking |
| `check` | Run all static checks (lint + typecheck) |
| **Testing** | |
| `test` | Run unit tests |
| `test-all` | Run all tests; set `RUN_INTEGRATION_TESTS=1` to include NATS integration |
| `test-cov` | Run tests with coverage report |
| **NATS** | |
| `nats-bootstrap` | Create all JetStream streams and consumers |
| `nats-verify` | Verify streams/consumers match expected config |
| `nats-dry-run` | Print stream/consumer definitions (no connection) |
| **Database** | |
| `migrate` | Apply database migrations (Alembic) |
| `migrate-down` | Rollback one migration step |
| `seed` | Load development seed data |
| **Docker** | |
| `docker-build` | Build Docker images for all services |
| `docker-push` | Push all images to registry |
| `docker-build-<svc>` | Build a single service image |
| **Helm** | |
| `helm-lint` | Lint the Helm umbrella chart |
| `helm-template` | Render templates locally (dry-run) |
| `helm-template-prod` | Render with production values |
| **Terraform** | |
| `tf-init` | Initialise Terraform |
| `tf-plan` | Show execution plan (`TF_ENV=production\|staging`) |
| `tf-apply` | Apply changes |
| `tf-destroy` | Destroy all resources (dangerous) |
| `tf-fmt` | Format Terraform files |
| `tf-validate` | Validate configuration |
| `tf-bootstrap` | Bootstrap state backend (run once) |
| **Backup & DR** | |
| `backup-status` | Show backup and DR status report |
| `backup-full` | Trigger immediate full backup |
| `backup-diff` | Trigger immediate differential backup |
| `restore-drill` | Trigger restore drill |
| `dr-failover` | Execute DR failover (dangerous) |
| `dr-failover-dry-run` | Dry-run DR failover |
| `dr-failback` | Execute DR failback (dangerous) |
| `dr-failback-dry-run` | Dry-run DR failback |
| **Load Testing** | |
| `loadtest-mvp` | MVP: 10 cameras @ 10 FPS, 2 min |
| `loadtest-scale` | Scale: 100 cameras @ 10 FPS, 5 min |
| `loadtest-backpressure` | Backpressure verification |
| `loadtest-latency` | Latency verification |
| `loadtest-pipeline` | NATS pipeline throughput |
| `loadtest-all` | All scenarios |
| `loadtest-quick` | All scenarios, reduced durations |
| `loadtest-locust` | Interactive Locust web UI |
| `loadtest-locust-headless` | Headless Locust run |
| **Production Launch** | |
| `smoke-test` | Run production smoke tests |
| `burn-in` | Start 24h burn-in monitor |
| `burn-in-short` | Start 1h burn-in (quick validation) |
| `alerts-check` | Check Prometheus for firing alerts |
| `alerts-rules` | List loaded alert rule groups |
| **Utilities** | |
| `clean` | Remove build artefacts and caches |
| `help` | Show all available targets |

---

## CI/CD Workflows

All workflows are in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push/PR to `main` | Lint, typecheck, unit tests, Docker build |
| `flutter.yml` | Push/PR (mobile paths) | Flutter analyze, test, APK/iOS build |
| `ml-pipeline.yml` | Push/PR (ml paths) | ML lint, tests, export validation |
| `security-scan.yml` | Push/PR + daily schedule | Gitleaks, Bandit, pip-audit, Trivy |
| `infrastructure.yml` | Push/PR (infra paths) | Terraform validate/plan, Helm lint |
| `deploy-staging.yml` | After CI on `main` | Auto-deploy to staging + smoke tests |
| `deploy-production.yml` | Manual dispatch | Production deploy with approval gate |
| `production-launch.yml` | Manual dispatch | Full launch: deploy + canary + burn-in |
| `canary-model-deploy.yml` | Manual dispatch | Progressive ML model rollout |
| `burn-in.yml` | Manual dispatch | Post-deploy burn-in monitor |
| `load-test.yml` | Manual / after staging | Load test scenarios |
| `release.yml` | Tag push (`v*`) | Build release images, GitHub Release |
| `restore-drill.yml` | Monthly schedule / manual | Database restore drill |

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
| `08-deployment-readiness-checklist.md` | Current deployment blockers, pre-deploy gate, and launch risks |

Operational runbooks are in `infra/runbooks/`:

| Runbook | Scope |
|---------|-------|
| `production-launch.md` | Full production launch checklist and procedures |
| `p1-database-breach.md` | P1: Database breach response |
| `p1-compromised-credentials.md` | P1: Compromised credentials |
| `p2-ddos-attack.md` | P2: DDoS attack mitigation |
| `p2-api-key-leak.md` | P2: API key leak response |
| `p3-waf-alert-triage.md` | P3: WAF alert triage |
| `general-secret-rotation.md` | Secret rotation procedures |
