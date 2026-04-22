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
| F2 | 보행자 이동 카운팅 | ✅ YOLO11n secondary detector + optional ROI polygon | `pipeline.py` (`PEDESTRIAN_CLASS_ID=100`), `pedestrian_zone_editor_screen.dart` |
| F3 | PM/오토바이/킥보드/자전거 2륜차 카운팅 | 🚧 detection wired, output schema TBD | `config.py` (`TWO_WHEELER_CLASS_IDS`) |
| F4 | 속도분석 (두 라인) | ✅ code done, dropped-tracks surfaced in report; needs site calibration | `tasks_speed.py` |
| F5 | 주거시설 상주/방문 (번호판) | ✅ Gemma+EasyOCR + Supabase recurrence-based classification (replaces allowlist) | `ocr.py`, `vlm.py`, `plate_repository.dart`, Supabase: `plate_visits` + `plate_classifications` |
| F6 | 대중교통 승하차 + 밀집도 | ✅ **VLM-per-bus-arrival** boarding/alighting (was heuristic) + density | `tasks_transit.py` (`BusArrival`, `pop_finalized_arrivals`), `vlm.py::BUS_BOARDING` |
| F7 | 신호등 시간계산 | ✅ multi-light + VLM auto-ROI + **first-time wizard with ROI preview dialog** | `tasks_light.py`, `auto_calibration.py`, `server.py::/preview_traffic_light_roi` |

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

Count pedestrians crossing the frame, optionally restricted to an
operator-drawn polygon ROI.

### Today (✅ shipped)
- Secondary `YOLO11n` detector runs in parallel with the vehicle RT-DETR;
  COCO `person` (class 0) is remapped to the unified `PEDESTRIAN_CLASS_ID = 100`
  so the merged `sv.Detections` has one canonical id per category
  (`runpod/config.py`, `runpod/pipeline.py::get_pedestrian_model`).
- Tracker ids are namespace-shifted by `PEDESTRIAN_TRACK_ID_OFFSET = 1_000_000`
  to avoid collisions with vehicle tracker ids.
- Optional **`pedestrian_zone`** polygon (`PedestrianZoneCfg`) — when set,
  pedestrians whose `BOTTOM_CENTER` anchor never lands inside the polygon
  are excluded from the report total. Mobile editor:
  `pedestrian_zone_editor_screen.dart` (reuses `CalibrationCanvas`).
- `_build_report` exposes `report["pedestrian"] = {roi_used, roi_excluded}`
  so operators can see how many tracks the filter removed.

### Gaps
- Per-15-min counts inside the ROI (currently aggregate only). Tracked but
  not in scope for the current phase.

### Effort
Done. Future work (per-15-min table) is **S**.

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

Read Korean plates and classify each plate as *resident* or *visitor* based
on **recurrence across analysis runs** (a plate that appears across ≥ N
distinct jobs at a site is a resident; one-offs are visitors).

### Today (✅ shipped)
- OCR stack: `vlm.py::PLATE_OCR` (Gemma, plate bbox + text in one call) +
  `ocr.py::EasyOcrVerifier` (Korean+English secondary pass on the Gemma
  crop). Triggered per tracked vehicle when `calibration.lpr.enabled=true`.
- **Server stops classifying.** `pipeline._build_report` no longer matches
  against an inline allowlist. Each per-plate record now carries
  `{text|text_hash, source, first_seen_s, last_seen_s, dwell_seconds, category: "unknown"}`
  so the mobile client owns the classification.
- **Supabase schema** (migration `lpr_plate_visits_and_classifications`):
  - `plate_visits` — one row per (analysis run, plate). Org-scoped RLS
    mirrors the existing `sites` policies.
  - `plate_classifications` — denormalized verdict per `(site, plate)`,
    refreshed via the `refresh_plate_classification(_site, _plate, _threshold)`
    Postgres function (default threshold = **3 distinct jobs**).
- **`PlateRepository`** (`apps/mobile_flutter/lib/features/sites/services/plate_repository.dart`):
  inserts the run's visits, calls the refresh RPC per plate, fetches the
  site's all-time totals, and returns a per-plate `categories` map +
  `SitePlateTotals`. The screen swaps the in-memory plates with the new
  categories and shows a "site total: X resident / Y visitor" subtitle.
- **xlsx export** includes a 번호판 sheet with per-plate rows + this-run
  + all-time totals.

### Gaps
- Plate retention policy still needs a written sign-off — `docs/06-security-and-compliance.md` should reference the new tables explicitly.
- No benchmark dataset for Korean plate OCR accuracy on this camera angle.
- The threshold (`3 distinct jobs`) is hardcoded in the repository's
  `_defaultResidentThresholdJobs`. A future iteration could surface it as a
  per-site setting.

### Effort
Done. Privacy/policy review is the only remaining work item.

---

## F6 — 대중교통 승하차 + 밀집도

At a bus stop, count **승차 (boarding)** and **하차 (alighting)** per
arrival event and report **밀집도 (density)** as a rolling percentage.

### Today (✅ shipped)
- `tasks_transit.py`:
  - `sv.PolygonZone` for the bus-stop footprint (density / peak count).
  - **Bus-arrival event detector**: state machine on `_any_bus_present()`
    transitions a `BusArrival` through `arrival_t → door_crops → departure_t`.
    Up to `MAX_ARRIVAL_CROPS = 12` door-region crops per arrival; on
    departure the pipeline picks `{first, mid, last}` and submits one
    multi-image VLM call.
  - `pop_finalized_arrivals()` lets the pipeline drain just-closed
    arrivals between frames; `finalize_open_arrival()` handles the case
    where the clip ends mid-event.
  - `apply_vlm_boarding(arrival_idx, boarding, alighting, confidence)` is
    routed by `_apply_aux_vlm("bus_boarding", ...)`.
- `vlm.py`:
  - New `VLMTask.BUS_BOARDING` + multi-image prompt that asks Gemma to
    count people moving toward / away from the bus across sequential
    frames.
  - `VLMRequest.extra_images` lets any task ship 1-N additional crops in
    one prompt; `_call_model` encodes each as a separate `Part`.
- Report (`TransitEngine.report`) now ships:
  - `boarding`, `alighting` summed across VLM-applied arrivals (or the
    LineZone fallback when the VLM is unavailable).
  - `arrivals: K` and `source: "vlm" | "linezone_fallback"`.
  - `per_arrival: [{arrival_t, departure_t, boarding, alighting, vlm_applied}]`.
- VLM density correction (`apply_vlm_density_correction`) and auto-
  calibration (`auto_calibration.py::BUS_STOP_LAYOUT`) carry over
  unchanged.
- Mobile: `_TransitCard` shows the source flag and the arrival count.

### Gaps
- Need a labelled bus-stop clip with known boarding/alighting events to
  ground-truth VLM accuracy end-to-end.

### Effort
Done. Validation pass is the next step.

---

## F7 — 신호등 시간계산

Compute red/yellow/green dwell times. Same engine as before — the focus
of this phase was **first-time-operator UX**, since the engine itself was
already production-quality.

### Today (✅ shipped)
- `tasks_light.py`:
  - Multi-light support, HSV state machine, `StateSpan` per transition,
    `cycles + timeline` report shape.
  - VLM auto-ROI (`auto_calibration.py::LIGHT_LAYOUT`) and ambiguous-state
    correction (`LIGHT_STATE` for `unknown` runs).
- **First-time wizard** (this phase):
  - Inline `_LightHelpCard` (3-step explainer) under the auto-light row in
    the task panel.
  - **`POST /preview_traffic_light_roi`** server endpoint that accepts one
    keyframe (multipart upload) and returns the VLM's proposed bbox per
    light head in normalized coords.
  - Mobile "ROI 미리보기" button extracts the keyframe via
    `VideoFrameExtractor`, posts it, and shows the bbox over the keyframe
    in `_LightPreviewDialog`. Operator confirms (keep auto) or jumps into
    `TrafficLightRoiEditorScreen` (manual).

### Gaps
- Arrow signals (좌회전/직진/보행) — HSV can only distinguish hue. A
  per-transition VLM call ("what direction?") is the cheapest fix and is
  trivially layered on top of the existing `LIGHT_STATE` path.
- No ground-truth signal-phase data for any test site.

### Effort
Done.

---

## Cross-cutting concerns

### C1. Calibration workflow
The mobile editor has split per-task screens (count line, speed quad, transit polygons, traffic-light ROI, plate allowlist) with persisted state — `apps/mobile_flutter/lib/features/sites/screens/`. As of this iteration the **default UX is "auto" mode** for the two tasks where the geometry is most painful to pick by hand:

- **Transit (`transit_auto_mode`, default ON):** mobile ships only `max_capacity`. The server's `auto_calibration.autofill_calibration` samples one keyframe and asks Gemma (`VLMTask.BUS_STOP_LAYOUT`) to propose stop polygon, door line, and bus zone. Falls back to a wide-bottom-band default if the VLM is unavailable or returns confidence < `VLM_AUTOCALIBRATE_MIN_CONFIDENCE` (default 0.5).
- **Traffic light (`light_auto_mode`, default ON):** mobile ships only the label. The server VLM proposes a tight bbox per signal head (`VLMTask.LIGHT_LAYOUT`).

Manual mode (the existing per-task editors with full canvas + tap-to-draw) is one toggle away for power users. **Speed** stays manual because metric km/h needs a known scale (lane width / known length) — we added a "Apply preset (1 lane 3.5m × 10m)" button and a perspective-correction explainer card so the editor is at least self-documenting; auto-suggesting speed quads from a single frame is a future iteration that would still need a human-supplied metric measurement.

Every editor (count line, speed, transit manual, traffic light manual, LPR allowlist) now shows an "이 설정은 무엇인가요?" expandable HelpCard explaining what the geometry means and how it feeds the analytics — addresses the previous UX gap where operators saw bare canvases with no context.

The auto-calibration pre-pass runs server-side in `_process` (between `parse_calibration` and `run_pipeline`). Disable in CI/tests by setting `VLM_AUTOCALIBRATE=0`.

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
- **JSON** — primary report shape, every task contributes a section.
- **Annotated MP4** — opt-in via `output_video` / `transit.output_video`;
  served from `GET /video/{job_id}?kind={classified|transit}`.
- **xlsx** — multi-sheet workbook generated client-side. Sheets:
  `결과값` (legacy Korean traffic-count template, kept for back-compat)
  + `요약` + per-feature sheets (`보행자 / 속도 / 대중교통 / 신호등 / 번호판`).
  Builders live under `apps/mobile_flutter/lib/features/sites/services/xlsx/`.

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
