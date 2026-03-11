# GreyEye Traffic Analysis AI — Document Overview

## 1 Purpose and Scope

This document set defines the complete design of **GreyEye**, a smartphone-first traffic analytics system that detects, tracks, and classifies vehicles passing through a user-designated inspecting area and records counts by 12-type class in 15-minute buckets.

The audience includes developers, architects, QA engineers, and operations staff working on the GreyEye product. Each document traces its content back to the Software Requirements Specification (SRS) using formal requirement IDs (FR-x, NFR-x, SEC-x, DM-x, UI-x).

---

## 2 Document Map

| # | Document | Description |
|---|----------|-------------|
| 00 | [00-overview.md](00-overview.md) | This file — table of contents, glossary, 12-class taxonomy, traceability matrix, conventions |
| 01 | [01-system-architecture.md](01-system-architecture.md) | High-level architecture, deployment topology, monorepo layout, scaling strategy |
| 02 | [02-software-design.md](02-software-design.md) | Backend services, API contracts, event schemas, sequence diagrams |
| 03 | [03-mobile-ui-design.md](03-mobile-ui-design.md) | Flutter app screens, navigation flows, ROI editor UX, analytics UX |
| 04 | [04-database-design.md](04-database-design.md) | Schema, tables, indexes, Supabase vs TimescaleDB options, migration strategy |
| 05 | [05-ai-ml-pipeline.md](05-ai-ml-pipeline.md) | Detection, tracking, classification, training pipeline, model versioning |
| 06 | [06-security-and-compliance.md](06-security-and-compliance.md) | Auth, RBAC, encryption, privacy controls, audit logging |
| 07 | [07-backup-and-recovery.md](07-backup-and-recovery.md) | Backup strategy, RPO/RTO targets, disaster recovery, restore drills |
| 08 | [08-deployment-readiness-checklist.md](08-deployment-readiness-checklist.md) | Current pre-deploy checklist, fixed blockers, and remaining launch risks |

---

## 3 Glossary

| Term | Definition |
|------|-----------|
| **Site** | A real-world location (intersection, gate, road segment) registered for traffic monitoring. Each site has a name, address, map location, and optional geofence polygon. |
| **Camera Source** | A video input — either the smartphone's built-in camera (live capture) or an external RTSP/ONVIF stream. |
| **Inspecting Area** | The region of interest (ROI) polygon drawn on the camera view, combined with one or more counting lines that define where vehicles are counted. |
| **Counting Line** | A directional line segment within the inspecting area. When a vehicle track's centroid crosses this line in the configured direction, a crossing event is emitted. |
| **ROI Preset** | A saved, versioned configuration of the inspecting area (ROI polygon + counting lines + optional lane polylines) for a given camera. Multiple presets per camera are supported (e.g., "weekday", "construction detour"). |
| **Vehicle Track** | A persistent identity (Track ID) assigned to a detected vehicle across consecutive video frames using a multi-object tracker (ByteTrack / OC-SORT). |
| **Crossing Event** | The atomic unit of counting truth. Generated when a tracked vehicle's centroid crosses a counting line in the configured direction. Contains `camera_id`, `line_id`, `track_id`, `class12`, `confidence`, `timestamp`, and `direction`. |
| **15-Minute Bucket** | The primary time aggregation window. `bucket_start = floor(timestamp_utc, 15 min)`. Example: an event at 10:07 UTC falls into the 10:00 bucket; an event at 10:15 falls into the 10:15 bucket. |
| **12-Class Taxonomy** | The KICT/MOLIT standard vehicle classification system used for Korean traffic surveys. See [Section 4](#4-vehicle-type-taxonomy-12-class) for the full table. |
| **KPI** | Key Performance Indicator — derived metrics such as total count, counts by class, flow rate, occupancy, and average speed. |
| **RBAC** | Role-Based Access Control. GreyEye defines four roles: Admin, Operator, Analyst, Viewer. |
| **RLS** | Row-Level Security — Postgres-enforced access policies scoped to organization, site, and camera. |
| **Geofence** | A geographic boundary polygon drawn on a map to define a site's physical extent. |
| **Temporal Smoothing** | A classification stabilization technique that applies majority voting (or EMA) over the last N frames of a track to produce a stable vehicle class label. |
| **Dedup Key** | A composite key (`{camera_id}:{line_id}:{track_id}:{crossing_seq}`) that prevents double-counting a single vehicle crossing. |
| **PII** | Personally Identifiable Information. GreyEye minimizes PII collection by default (no audio, no raw video retention unless explicitly enabled). |
| **SLA** | Service Level Agreement — defines availability and performance commitments. |
| **WAL** | Write-Ahead Log — Postgres mechanism used for continuous backup and point-in-time recovery. |
| **RPO** | Recovery Point Objective — maximum acceptable data loss window (target: ≤ 15 minutes). |
| **RTO** | Recovery Time Objective — maximum acceptable downtime (target: ≤ 2 hours). |
| **ADR** | Architecture Decision Record — a versioned document capturing the context, decision, and consequences of an architectural choice. |

---

## 4 Vehicle Type Taxonomy (12-Class)

GreyEye uses the **KICT/MOLIT 12-class vehicle classification standard** (한국건설기술연구원 / 국토교통부) used in Korean national traffic surveys. This taxonomy is the single authoritative enum (`VehicleClass12`) shared across the mobile UI, API, database, training pipeline, and analytics.

| Class | Korean Name (종) | English Name | Unit Config | Axle Count | Description |
|:-----:|:----------------|:-------------|:------------|:-----------|:------------|
| 1 | 승용차 / 미니트럭 | Passenger car / Mini-truck | Single unit | 2 axles | Sedans, SUVs, mini-trucks, light passenger vehicles |
| 2 | 버스 | Bus | Single unit | 2 axles | City buses, intercity buses, tourist coaches |
| 3 | 1~2.5톤 미만 | Truck (< 2.5 t) | Single unit | 2 axles | Light commercial trucks under 2.5 tonnes |
| 4 | 2.5~8.5톤 미만 | Truck (2.5 t – 8.5 t) | Single unit | 2 axles | Medium commercial trucks, 2.5 to 8.5 tonnes |
| 5 | 1단위 3축 | Single unit, 3-axle | Single unit | 3 axles | Heavy single-unit trucks with 3 axles |
| 6 | 1단위 4축 | Single unit, 4-axle | Single unit | 4 axles | Heavy single-unit trucks with 4 axles |
| 7 | 1단위 5축 | Single unit, 5-axle | Single unit | 5 axles | Heavy single-unit trucks with 5 axles |
| 8 | 2단위 4축 세미 트레일러 | Combination, 4-axle semi-trailer | Combination | 4 axles | Tractor + semi-trailer, 4 axles total |
| 9 | 2단위 4축 풀 트레일러 | Combination, 4-axle full trailer | Combination | 4 axles | Truck + full trailer, 4 axles total |
| 10 | 2단위 5축 세미 트레일러 | Combination, 5-axle semi-trailer | Combination | 5 axles | Tractor + semi-trailer, 5 axles total |
| 11 | 2단위 5축 풀 트레일러 | Combination, 5-axle full trailer | Combination | 5 axles | Truck + full trailer, 5 axles total |
| 12 | 2단위 6축 세미 트레일러 | Combination, 6-axle semi-trailer | Combination | 6 axles | Tractor + semi-trailer, 6 axles total |

**Fallback policy (FR-4.6):** When 12-class classification confidence falls below a configurable threshold, the system outputs either "Unknown" or a coarse fallback class (Car / Bus / Truck / Trailer) depending on site policy.

**Shared enum reference:**

```python
class VehicleClass12(IntEnum):
    C01_PASSENGER_MINITRUCK = 1   # 1종 승용차/미니트럭
    C02_BUS                 = 2   # 2종 버스
    C03_TRUCK_LT_2_5T       = 3   # 3종 1~2.5톤 미만
    C04_TRUCK_2_5_TO_8_5T   = 4   # 4종 2.5~8.5톤 미만
    C05_SINGLE_3_AXLE       = 5   # 5종 1단위 3축
    C06_SINGLE_4_AXLE       = 6   # 6종 1단위 4축
    C07_SINGLE_5_AXLE       = 7   # 7종 1단위 5축
    C08_SEMI_4_AXLE         = 8   # 8종 2단위 4축 세미
    C09_FULL_4_AXLE         = 9   # 9종 2단위 4축 풀
    C10_SEMI_5_AXLE         = 10  # 10종 2단위 5축 세미
    C11_FULL_5_AXLE         = 11  # 11종 2단위 5축 풀
    C12_SEMI_6_AXLE         = 12  # 12종 2단위 6축 세미
```

---

## 5 Requirements Traceability Matrix

The table below maps every SRS requirement to the design document(s) that address it. This is the master cross-reference for verifying that the design covers all specified requirements.

### 5.1 Functional Requirements

| Req ID | Requirement Summary | Design Document(s) |
|--------|--------------------|--------------------|
| **FR-1.1** | User registration / invite via email or SSO | 02-software-design, 06-security-and-compliance |
| **FR-1.2** | Multi-tenant organizations with isolated data | 02-software-design, 04-database-design, 06-security-and-compliance |
| **FR-1.3** | RBAC roles: Admin, Operator, Analyst, Viewer | 02-software-design, 06-security-and-compliance |
| **FR-1.4** | Audit log for permission changes | 02-software-design, 04-database-design, 06-security-and-compliance |
| **FR-2.1** | Create site with name, address, map location | 02-software-design, 03-mobile-ui-design |
| **FR-2.2** | Define geofence polygon on map | 03-mobile-ui-design |
| **FR-2.3** | Multiple analysis zones per site | 02-software-design, 04-database-design |
| **FR-2.4** | Version site configuration with rollback | 02-software-design, 04-database-design |
| **FR-3.1** | Smartphone camera as video source | 02-software-design, 03-mobile-ui-design |
| **FR-3.2** | External camera via RTSP URL | 02-software-design, 03-mobile-ui-design |
| **FR-3.3** | Per-camera settings (FPS, resolution, night mode) | 02-software-design, 03-mobile-ui-design |
| **FR-3.4** | Camera health status reporting | 02-software-design, 03-mobile-ui-design |
| **FR-3.5** | Record-and-upload mode for offline use | 02-software-design |
| **FR-4.1** | ROI editor overlay on video frame | 03-mobile-ui-design |
| **FR-4.2** | Draw/edit ROI polygons, counting lines, lane polylines | 03-mobile-ui-design |
| **FR-4.3** | ROI geometry validation | 03-mobile-ui-design |
| **FR-4.4** | Multiple presets per camera | 02-software-design, 04-database-design |
| **FR-4.5** | Disable classification or force coarse-only mode | 02-software-design, 05-ai-ml-pipeline |
| **FR-4.6** | Low-confidence fallback policy (Unknown / coarse class) | 05-ai-ml-pipeline |
| **FR-5.1** | Vehicle detection with bounding boxes and confidence | 05-ai-ml-pipeline |
| **FR-5.2** | Multi-frame tracking with persistent Track IDs | 05-ai-ml-pipeline |
| **FR-5.3** | 12-class classification with probability scores | 05-ai-ml-pipeline |
| **FR-5.4** | Temporal smoothing for stable class labels | 05-ai-ml-pipeline |
| **FR-5.5** | Per-track attributes (dwell time, trajectory, occlusion) | 05-ai-ml-pipeline |
| **FR-5.6** | Event generation (track start/end, line crossing, stopped, wrong-way) | 02-software-design, 05-ai-ml-pipeline |
| **FR-6.1** | KPI computation (count, flow, occupancy, speed, queue) | 02-software-design, 04-database-design |
| **FR-6.2** | Selectable KPI time windows | 02-software-design, 03-mobile-ui-design |
| **FR-6.3** | Class distribution charts and time-range comparisons | 03-mobile-ui-design |
| **FR-7.1** | Alert rules (congestion, speed drop, stopped vehicle, heavy share, offline) | 02-software-design |
| **FR-7.2** | Alert delivery (in-app, push, email/webhook) | 02-software-design |
| **FR-7.3** | Alert acknowledge / assign / close workflow | 02-software-design, 03-mobile-ui-design |
| **FR-7.4** | Alert history for reporting and audits | 02-software-design, 04-database-design |
| **FR-8.1** | Site dashboard with live tiles and KPI summaries | 03-mobile-ui-design |
| **FR-8.2** | Historical charts (counts, speeds, class mix) | 03-mobile-ui-design |
| **FR-8.3** | Report export (CSV, JSON, PDF) | 02-software-design, 03-mobile-ui-design |
| **FR-8.4** | Shareable read-only report links | 02-software-design |
| **FR-9.1** | Model version tagging on inference results | 05-ai-ml-pipeline |
| **FR-9.2** | Model rollback (admin only) | 05-ai-ml-pipeline |
| **FR-9.3** | Confidence and class distribution drift monitoring | 05-ai-ml-pipeline |
| **FR-9.4** | Hard-example collection for labeling | 05-ai-ml-pipeline |

### 5.2 Non-Functional Requirements

| Req ID | Requirement Summary | Design Document(s) |
|--------|--------------------|--------------------|
| **NFR-1** | Live KPI tile updates every ≤ 2 seconds | 01-system-architecture, 03-mobile-ui-design |
| **NFR-2** | End-to-end inference latency ≤ 1.5 seconds | 01-system-architecture, 05-ai-ml-pipeline |
| **NFR-3** | MVP: 10 cameras / 10 FPS; scale: 100+ cameras | 01-system-architecture |
| **NFR-4** | Auto-reconnect and resume within 30 seconds | 02-software-design |
| **NFR-5** | Backend API availability ≥ 99.5% | 01-system-architecture, 07-backup-and-recovery |
| **NFR-6** | Resilient ingestion under queue backpressure | 02-software-design |
| **NFR-7** | First-time setup ≤ 10 minutes; ≤ 3 taps to critical actions | 03-mobile-ui-design |
| **NFR-8** | Clear error messages with recovery steps | 03-mobile-ui-design |
| **NFR-9** | Containerized components with CI/CD | 01-system-architecture |
| **NFR-10** | Operational metrics (CPU/GPU, queue lag, error rates) | 01-system-architecture |
| **NFR-11** | Feature flags for model rollout and UI experiments | 02-software-design, 05-ai-ml-pipeline |
| **NFR-12** | Support latest major iOS/Android; graceful degradation | 03-mobile-ui-design |
| **NFR-13** | Configurable retention; minimize collection by default | 04-database-design, 06-security-and-compliance |
| **NFR-14** | Data export and deletion at org/site level | 04-database-design, 06-security-and-compliance |

### 5.3 Security Requirements

| Req ID | Requirement Summary | Design Document(s) |
|--------|--------------------|--------------------|
| **SEC-1** | OAuth2/OIDC with short-lived tokens | 06-security-and-compliance |
| **SEC-2** | RBAC enforcement for all resources | 06-security-and-compliance |
| **SEC-3** | Step-up auth for admin actions | 06-security-and-compliance |
| **SEC-4** | TLS 1.2+ for all network traffic | 06-security-and-compliance |
| **SEC-5** | Encryption at rest (KMS-managed) | 06-security-and-compliance |
| **SEC-6** | No hardcoded secrets; OS secure storage | 06-security-and-compliance |
| **SEC-7** | Auth tokens in Keychain/Keystore only | 06-security-and-compliance |
| **SEC-8** | Certificate pinning (optional) | 06-security-and-compliance |
| **SEC-9** | Rooted/jailbroken device detection | 06-security-and-compliance |
| **SEC-10** | No RTSP credentials or tokens in debug logs | 06-security-and-compliance |
| **SEC-11** | Rate limiting and abuse detection | 06-security-and-compliance |
| **SEC-12** | Security event logging | 06-security-and-compliance |
| **SEC-13** | WAF and IDS/IPS support | 06-security-and-compliance |
| **SEC-14** | Audio disabled by default | 06-security-and-compliance |
| **SEC-15** | Raw video storage off by default | 06-security-and-compliance |
| **SEC-16** | Optional face/plate redaction | 06-security-and-compliance |
| **SEC-17** | Immutable audit logs | 06-security-and-compliance, 04-database-design |
| **SEC-18** | Audit log export for compliance | 06-security-and-compliance |
| **SEC-19** | Key rotation and session revocation | 06-security-and-compliance |
| **SEC-20** | Incident response runbooks | 06-security-and-compliance |

### 5.4 Data Management Requirements

| Req ID | Requirement Summary | Design Document(s) |
|--------|--------------------|--------------------|
| **DM-1** | Configuration data in relational DB with backups | 04-database-design, 07-backup-and-recovery |
| **DM-2** | Aggregates in time-series optimized store | 04-database-design |
| **DM-3** | Configurable event retention | 04-database-design |
| **DM-4** | Media off by default; encrypted if enabled | 04-database-design, 06-security-and-compliance |
| **DM-5** | Per-org retention policies and auto-deletion | 04-database-design |
| **DM-6** | Event traceability (timestamps, camera_id, model_version) | 04-database-design, 05-ai-ml-pipeline |
| **DM-7** | Aggregates recomputable from events | 04-database-design |
| **DM-8** | Daily config DB backups with tested restore | 07-backup-and-recovery |
| **DM-9** | DR runbooks with configurable RPO/RTO | 07-backup-and-recovery |

### 5.5 UI Requirements

| Req ID | Requirement Summary | Design Document(s) |
|--------|--------------------|--------------------|
| **UI-1** | Critical actions reachable within ≤ 3 taps from Home | 03-mobile-ui-design |
| **UI-2** | Always-visible live status indicators | 03-mobile-ui-design |
| **UI-3** | Accessibility (dynamic type, screen reader, contrast) | 03-mobile-ui-design |
| **UI-4** | Korean and English localization | 03-mobile-ui-design |

---

## 6 Document Conventions

### 6.1 Heading Hierarchy

- **H1 (`#`)** — Document title (one per file)
- **H2 (`##`)** — Major sections
- **H3 (`###`)** — Subsections
- **H4 (`####`)** — Detail items within subsections

### 6.2 Requirement References

All design sections trace back to SRS requirement IDs using the format `(FR-x.y)`, `(NFR-x)`, `(SEC-x)`, `(DM-x)`, or `(UI-x)`. When a section addresses multiple requirements, they are listed comma-separated: e.g., `(FR-1.2, NFR-13, SEC-2)`.

### 6.3 Diagrams

Architecture, data flow, sequence, ER, and navigation diagrams use **Mermaid** syntax embedded in fenced code blocks. All diagrams include a brief caption or introductory sentence.

### 6.4 Tables

Structured data (API endpoints, role permissions, schema columns, taxonomy) is presented in Markdown tables with a header row and alignment indicators.

### 6.5 Code Blocks

Schema DDL, API examples, configuration snippets, and enum definitions use fenced code blocks with language tags (`sql`, `python`, `dart`, `yaml`, etc.).

### 6.6 Terminology

All documents use the terminology defined in the [Glossary](#3-glossary) consistently. Korean terms are provided alongside English equivalents where relevant for the KICT/MOLIT taxonomy.

---

## 7 Source Documents

| Document | Description |
|----------|-------------|
| [For Agent.docx](../Documents/For%20Agent.docx) | Cursor workflow, context engineering strategy, build phases, production gates |
| [GreyEye SRS.docx](../Documents/GreyEye%20SRS.docx) | Software Requirements Specification — functional, non-functional, UI, security, data management requirements |
| [GreyEye Design.docx](../Documents/GreyEye%20Design.docx) | System architecture, data flow, module design, AI pipeline, database schema, security and backup |
| [GreyEye Tech Stack.docx](../Documents/GreyEye%20Tech%20Stack.docx) | Technology recommendations — Flutter, FastAPI, PyTorch, Postgres, monorepo layout, shared contracts |
| 12종 차종분류 사진표.jpg | KICT/MOLIT 12-class vehicle classification reference chart with photographs |
| 12종 차종분류 체계.docx | 12-class vehicle classification system specification |
| AI Hub 091 Dataset | ~295K annotated vehicle exterior images (training + validation) for pre-training |
