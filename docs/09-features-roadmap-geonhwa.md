# GreyEye — Geonhwa PoC Features Roadmap

Planning doc for the seven-feature sprint. Each feature section answers:
*what it does*, *what exists today*, *what's missing*, *approach*, *blockers*,
*effort*. Grounded in the current repo state, not aspiration.

Reference files:
- Pipeline: `runpod/pipeline.py`, `runpod/server.py`
- Per-task modules: `runpod/tasks_speed.py`, `runpod/tasks_transit.py`, `runpod/tasks_light.py`, `runpod/ocr.py`, `runpod/vlm.py`
- Calibration: `runpod/calibration.py`, `scripts/seodang_calibration.json`
- Mobile: `apps/mobile_flutter/lib/features/sites/`

Legend: ✅ done · 🚧 partial · ❌ not started

---

## 0. Feature Index

| # | Feature (KR) | Status | Lives in |
|---|---|---|---|
| F1 | 차종별 인식영상 (가로/3G/4G/회전) | 🚧 3G validated, others untested | `pipeline.py` + per-site calibration |
| F2 | 보행자 이동 카운팅 | ❌ blocked — no pedestrian class in `best.pt` | needs detector change |
| F3 | PM/오토바이/킥보드/자전거 2륜차 카운팅 | 🚧 detection wired, output schema TBD | `config.py` (`TWO_WHEELER_CLASS_IDS`) |
| F4 | 속도분석 (두 라인) | ✅ code done, needs site calibration | `tasks_speed.py` |
| F5 | 주거시설 상주/방문 (번호판) | 🚧 Gemma+EasyOCR wired, resident allowlist TBD | `ocr.py`, `vlm.py` |
| F6 | 대중교통 승하차 + 밀집도 | 🚧 counting wired, head-based density TBD | `tasks_transit.py` |
| F7 | 신호등 시간계산 | ✅ code done, needs per-site ROI | `tasks_light.py` |

---

## F1 — 차종별 인식영상 (가로, 3G, 4G, 회전)

Count and classify vehicles across four road topologies:
- **가로** — straight road (section count)
- **3G** — 3-way intersection (validated on Seodang; +34-36% overcount in pre-dawn test clip)
- **4G** — 4-way intersection
- **회전** — roundabout

### Today
Single pipeline with pluggable calibration:
- Tripwire (directional through-traffic) — good for **가로**
- `sv.PolygonZone` with boundary-crossing filter + `MIN_TRACK_OBSERVATIONS` phantom kill — validated for **3G** (Seodang)
- BoT-SORT tracker + RT-DETR (`best.pt`) — 21-class map in `config.py`

### Gaps
| Item | Why it matters |
|---|---|
| 4G calibration template | 4-way needs a polygon that excludes the centre *or* a cross-shaped zone so through+turn traffic is deduped cleanly |
| 회전 (roundabout) strategy | A single polygon over the roundabout overcounts (vehicles can loop). Need an **entry-line count per approach**, not a polygon |
| Per-road-type calibration presets | `scripts/{straight,3way,4way,roundabout}_calibration_template.json` — each site inherits from these |
| Ground-truth harness generalized | `scripts/measure_accuracy.py` is currently Seodang-specific. Parameterize xls sheet + clip directory |

### Approach
1. Add a `road_type` field to calibration JSON (`straight|3way|4way|roundabout`)
2. For `straight`: use tripwire LineZone only; no polygon
3. For `roundabout`: require **N entry LineZones** (one per approach). Count unique tids per LineZone, sum across. Reject tids that appear on >1 entry (U-turn / stayed inside).
4. Add 4 calibration templates under `scripts/templates/`
5. Extend the harness to parameterize per-site ground truth (xls sheet index + video directory)

### Blockers
- Test clips for 가로/4G/회전 + matching ground truth. Ask stakeholders for one 5-min clip per road type.

### Effort
**M** — ~2 days for the four template variants + one day for the harness generalization, plus ground-truth validation runs (25 min CPU each unless we move to GPU).

---

## F2 — 보행자 이동 카운팅

Count pedestrians crossing the frame.

### Today
**Not functional.** The trained `best.pt` has **no pedestrian class** (verified: `m.names` shows 21 classes, none of them `person`). `config.py` has `PEDESTRIAN_CLASS_ID = -1` as a sentinel so the code doesn't crash but always returns 0.

### Gaps
Everything. The detector can't see pedestrians.

### Approach — three viable paths
| Path | Pros | Cons |
|---|---|---|
| **A. Add pedestrian labels to the RT-DETR training set + retrain** | Single-model simplicity, matches existing deployment | Multi-week labelling + training |
| **B. Run a secondary YOLO detector in parallel for person/bike (COCO classes 0, 1, 3)** | Fast — `yolo11n.pt` is already in the repo. Decoupled from vehicle model. | Second inference pass (~2-3× CPU, negligible on GPU) |
| **C. Use Gemma on sampled frames** | No extra model file | Slow + quota-expensive for per-frame counting |

### Recommendation — **Path B**
Dual-model pipeline: RT-DETR for vehicles, YOLO11n for person+bike+motorcycle. Merge `sv.Detections` from both. Tracker sees the union.

### Blockers
- Weights for `yolo11n.pt` already in repo root. Just wire a second `YOLO()` call.
- Need to decide confidence threshold for people (typically lower than vehicles — 0.25 is reasonable).

### Effort
**S** — ~1 day to wire a second detector and a merge step. Unit tests straightforward.

---

## F3 — PM / 오토바이 / 킥보드 / 자전거 2륜차 카운팅

Count two-wheelers, broken out by sub-type.

### Today
- `best.pt` has `bike` (id 1), `motorcycle` (id 15), `personal_mobility` (id 16)
- `config.py::TWO_WHEELER_CLASS_IDS = {1, 15, 16}` — all three are tracked
- `vehicle_breakdown` in the report lumps them into `motorcycles` counter (id 15 + 16) and `bicycles` (id 1)

### Gaps
| Item | Fix |
|---|---|
| 킥보드 (kick-scooter) not split from other personal mobility | The `personal_mobility` class is a catch-all. Split would need either training-set relabelling OR Gemma classifier over detections → kick-scooter vs e-bike vs Segway |
| Current report lumps id 15 + id 16 | Split in the report schema |
| No 2-wheeler dashboard in mobile UI | Add a section under the vehicle breakdown |

### Approach
1. Split `motorcycles` from `personal_mobility` in `_build_report` output
2. Add a `two_wheeler_breakdown` section to the JSON report:
   ```json
   "two_wheeler_breakdown": {
     "bicycle": 3,
     "motorcycle": 7,
     "personal_mobility": 2
   }
   ```
3. Mobile: extend `video_analysis_remote_result.dart` with an optional two-wheeler breakdown renderer
4. Optional: Gemma sub-classifier (bicycle vs kick-scooter vs e-bike) as a per-track VLM call — only fires if detector class is `bicycle` or `personal_mobility`

### Blockers
None for base counting. 킥보드 split needs either training data or Gemma prompt.

### Effort
**S** — half a day to refactor schema + add mobile rendering. +1 day if we add Gemma sub-classifier.

---

## F4 — 속도분석 (라인 두군데)

Speed measurement via perspective warp + two LineZones.

### Today
Fully coded in `tasks_speed.py`:
- `cv2.getPerspectiveTransform` for image→world mapping (supervision's `ViewTransformer` doesn't exist in 0.27)
- Two `sv.LineZone` instances at configurable Y ratios
- Per-track entry/exit frame recorded → `km/h = (distance_m / elapsed_s) × 3.6`
- Schema: `{vehicles_measured, avg_kmh, min_kmh, max_kmh, per_track}`

### Gaps
| Item | Fix |
|---|---|
| No site calibration done | Needs 4 pixel points on a known real-world rectangle (e.g., lane markings) per site |
| Validation against ground truth | No test site with ground-truth speeds. Need a radar-gun or GPS-tracked vehicle sample |
| Edge case: vehicle misses second line | Currently silently skipped. Should be logged |
| Mobile UI | Speed results currently not surfaced in the Flutter app |

### Approach
1. Write a tiny calibration-helper script: load first frame, click 4 points on-screen, output JSON to stdin → merged into the multipart `calibration` field
2. Add a `scripts/speed_calibration_helper.py`
3. Mobile: add a speed section to the analysis result screen
4. Log dropped tracks (`logger.debug("track %s did not cross second line", tid)`) so operators can tighten the second-line position

### Blockers
- Need a site where someone's willing to measure real-world distance between two road markings
- Need a validation sample (radar gun or GPS-tracked vehicle)

### Effort
**S** for the calibration helper + logging. **M** for end-to-end validation runs.

---

## F5 — 주거시설 상주/방문 (차량번호판 인식)

For residential driveways, read Korean plates, classify each plate as *resident* (on allowlist) or *visitor*.

### Today
OCR stack is built:
- `vlm.py` — Gemma does plate detection + OCR in a single call (returns bbox + text)
- `ocr.py` — EasyOCR(`ko`, `en`) as a secondary verifier on the Gemma-returned plate crop
- Triggered per tracked vehicle when `calibration.lpr.enabled=true`
- Korean plate normalizer regex: `(\d{2,3})([가-힣])(\d{4})`

### Gaps
| Item | Fix |
|---|---|
| **Resident allowlist storage** | Needs a table (likely Supabase based on existing repo setup). Site admins upload resident plate list per facility |
| **Resident/visitor tagging in the report** | Compare extracted plate against allowlist; add `{plate_text, category: "resident"|"visitor", seen_at: ts}` |
| **Plate privacy handling** | Plates are PII. Need retention/encryption policy. Coordinate with `docs/06-security-and-compliance.md` |
| **Daytime validation** | Gemma plate reads have not been benchmarked against ground truth |
| **EasyOCR gpu=True on CPU build** | Currently `easyocr.Reader(..., gpu=True)` fails on Mac. Already gated in `ocr.py`, but ensure `OCR_USE_GPU` env var controls this cleanly |

### Approach
1. Data model: add `residential_plates` table (fields: `site_id`, `plate_text`, `resident_name`, `added_at`)
2. Calibration extends: `lpr: {enabled, residential_only, allowlist_source: "supabase"|"inline", allowlist: [...]}`
3. Report adds `plates: [{track_id, text, source, category}]`
4. Mobile: new screen for managing resident plate list per site
5. Privacy review per security doc — hash plate text for storage if policy requires

### Blockers
- Legal / compliance review on plate storage
- Supabase schema changes (need DBA sign-off)
- No benchmark dataset for Korean plate OCR accuracy on this camera angle

### Effort
**M** — ~3 days for backend + schema + privacy review + mobile UI. Core pipeline is done.

---

## F6 — 대중교통 승하차 + 밀집도

At a bus stop:
- Count **승차 (boarding)** and **하차 (alighting)** separately, each tagged visually with a different colour
- Compute **밀집도 (density)** as a percentage, visualised with a circle marker on each detected head

### Today
`tasks_transit.py`:
- `sv.PolygonZone` for the bus-stop footprint (counts persons inside)
- `sv.LineZone` per door for boarding/alighting counts
- Density = `count_inside / max_capacity × 100`
- Report schema: `{peak_count, avg_density_pct, boarding, alighting, samples: [...]}`

### Gaps
| Item | Fix |
|---|---|
| **Person detection** | Same blocker as F2 — `best.pt` has no person class. Wait on F2 (Path B secondary YOLO) |
| **Head-based density** ("머리 동그라미로") | Stakeholder wants the density visual to mark each detected head with a circle, not bounding box. Two options: (a) use the top-center anchor of person bboxes as head position, draw circle; (b) add a head-detection model (e.g., YOLOv8-head). (a) is simpler and usually acceptable |
| **Boarding vs alighting colour differentiation** | Viz concern. `sv.LineZone.trigger()` returns which tids crossed IN vs OUT — we already know direction. Need to annotate output video with different colours per direction |
| **Output video (not just JSON)** | All existing analytics return JSON; bus stop operators want a rendered video with overlays. Needs `sv.BoxAnnotator` + `sv.LineZoneAnnotator` + circle drawing, encoded back to MP4 |
| **Bus vs non-bus on the door LineZone** | Crossings should only count while a bus is present at the stop. Gate boarding counter with a `bus_in_stop_zone` predicate |

### Approach
1. Land F2 Path B first (secondary YOLO for person)
2. Add head-circle rendering: for each person detection inside polygon, draw a circle at `((x1+x2)/2, y1 + 0.1*(y2-y1))`
3. Output video stream: extend pipeline to optionally write an annotated MP4
4. Direction-colour LineZone annotator (green for 승차, red for 하차 — common convention)
5. Bus-presence gating: use the existing vehicle detector. If a track of class_2 (bus) is inside a `bus_stop_polygon` sub-region, gate the door LineZone

### Blockers
- F2 must land first (no person detection)
- Need one test video filmed at a bus stop with known boarding/alighting events for validation

### Effort
**M-L** — ~4 days. Mostly visualization + the bus-presence gate.

---

## F7 — 신호등 시간계산

Compute red/yellow/green dwell times over the clip duration.

### Today
Fully coded in `tasks_light.py`:
- Static ROI (operator specifies in calibration)
- HSV mask per sampled frame, `cv2.inRange` on red (2 ranges), green, yellow
- State machine appends `StateSpan` on transitions
- Report: `{cycles: {red:{cycles, avg_duration_s, total_duration_s}, ...}, timeline: [...]}`
- "Unknown" streak triggers Gemma fallback for state confirmation

### Gaps
| Item | Fix |
|---|---|
| **Per-site ROI** | Operator must pick `[x, y, w, h]` per light per site. No UI yet |
| **Multiple lights** | Real intersections have 2-4 signal heads (main, left-turn, pedestrian). Today we only support one. Extend to array |
| **Arrow signals (좌회전/직진/보행)** | HSV can only distinguish red/yellow/green hues. Directional arrows within the same colour are indistinguishable without a shape classifier or Gemma per-frame |
| **Validation** | No ground-truth signal-phase data for any test site |

### Approach
1. Calibration schema: `traffic_lights: [{label, roi}, {label, roi}, ...]` (array instead of single)
2. Report schema: `{traffic_lights: [{label, cycles, timeline}, ...]}`
3. Arrow detection: optional VLM-per-transition call that asks "what direction is the current signal?" — only fires at state changes (cheap)
4. Calibration helper script similar to F4: load first frame, click ROI per light head

### Blockers
- None technical. Just needs calibration UI and validation clips.

### Effort
**S** — ~1 day for multi-light support + calibration helper.

---

## Cross-cutting concerns

### C1. Calibration workflow
Today operators hand-write JSON. That doesn't scale. Three needs per site:
- 4-point perspective quad (for F4 speed)
- Polygon(s) for F1 (intersection), F6 (bus stop, door lines)
- ROIs for F7 (each signal head)
- Boundary lines for F6 (boarding direction)

**Proposal:** a `scripts/calibration_studio.py` using OpenCV's click-point capture + first-frame display. Exports one JSON per site. Mobile team could wrap this in a web tool later.

### C2. Model coverage gap (pedestrian / head)
F2, F6 are both blocked on the same thing: no pedestrian detection. Picking Path B (secondary YOLO) unblocks both in one move. If the team wants to stay single-model long-term, start labelling people in the next RT-DETR training batch.

### C3. Ground-truth / accuracy measurement
`scripts/measure_accuracy.py` proved its value debugging the Seodang overcount. Extend it for every feature:
- F1: count-per-class vs manual count (current)
- F4: per-track km/h vs radar/GPS ground truth
- F5: plate-read accuracy vs manually-labelled plates
- F6: boarding/alighting counts vs manual tally
- F7: red/green dwell times vs video-annotation ground truth

Each PoC site should produce a validation report using the harness before stakeholder demo.

### C4. VLM scaling & cost
F1, F3, F5 all make Gemma calls per track. At a busy intersection (~200 vehicles / 5 min), that's 200 calls per clip. At Vertex AI Gemma pricing, a pod processing 24 clips per site per day = ~4800 calls × sites. Needs:
- Cost monitoring dashboard
- Per-request budget cap (circuit-break at N calls/min)
- Gemma result caching across repeat site visits (perceptual hash is already in `vlm.py`)

### C5. Output formats
Today every task returns JSON. F6 wants an annotated MP4. F7 could use a timeline chart. Decide early if we're shipping videos (big payloads) or overlays-as-SVG (lightweight for mobile).

---

## Milestone sequencing

| Milestone | Features | Unblocks | Effort |
|---|---|---|---|
| **M1 — Dual-model foundation** | F2 (Path B: add yolo11n for person) | F6 head-count, F2 ped counting | 1 day |
| **M2 — 2-wheeler schema split + mobile UI** | F3 | Mobile dashboard reports | 0.5 day |
| **M3 — Calibration tooling** | C1 (calibration_studio.py) | F4, F6, F7 per-site deploys | 1-2 days |
| **M4 — Road-type templates + harness generalization** | F1 (straight, 4-way, roundabout) | Multi-site validation | 2 days |
| **M5 — Transit video output + head-circle viz** | F6 | Stakeholder demo | 2 days |
| **M6 — LPR allowlist + privacy review** | F5 | Residential product | 3 days |
| **M7 — Multi-light signal phase** | F7 | Intersection-level timing data | 1 day |
| **M8 — Accuracy validation pass** | Cross-cutting | Go/no-go for customer demo | 3 days |

Critical path: **M1 → M3 → M4 → M8**. F5 (M6) and F7 (M7) are parallelizable.

---

## Open questions (ask stakeholders)

1. **Road types.** Which of 가로 / 4G / 회전 has a stakeholder-provided clip + ground truth? Without one per type, F1 validation is theoretical.
2. **Pedestrian policy.** OK with dual-model (secondary YOLO) or does the spec require single-model (wait for retrained RT-DETR with person labels)?
3. **킥보드 granularity.** Is `personal_mobility` as a single bucket acceptable for MVP, or must we split kick-scooter / e-scooter / Segway?
4. **Speed ground truth.** Will someone measure real-world distances + capture GPS-tracked vehicles at a PoC site?
5. **Resident plate allowlist source.** Supabase-managed, uploaded CSV, or mobile-app-entered?
6. **Privacy/retention.** How long are plate reads stored? Hashed or raw?
7. **Transit output format.** Annotated MP4 (~50 MB / 5 min) acceptable over mobile networks, or timeline JSON + overlay SVG?
8. **VLM budget.** Who owns Vertex AI cost monitoring? Is there a per-site monthly cap?

---

## Current accuracy baseline (as of 2026-04-21)

| Feature | Test site | Result | Gap from production-ready |
|---|---|---|---|
| F1 (3G counting) | Seodang 07:00 clip | +36% overcount | Needs daylight re-test; likely +10-20% range in good light |
| F1 (class breakdown) | Seodang 07:00 | small_bus 0% recall; others +25-40% | VLM on all vehicles (coded but unmeasured — needs pod deploy) |
| F4 (speed) | — | not validated | Needs site calibration + ground truth |
| F5 (plate read) | — | not validated | Needs Korean plate test set |
| F6 (transit) | — | not validated | Needs bus-stop clip |
| F7 (signal timing) | — | not validated | Needs signal-phase ground truth |

Counting accuracy on 3G has converged near an architectural ceiling given pre-dawn low-light footage; daylight testing should meaningfully tighten numbers without further code changes.
