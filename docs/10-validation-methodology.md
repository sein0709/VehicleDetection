# GreyEye — Validation Methodology

How to measure GreyEye's production readiness per feature, per site. This is
the operator's playbook — the companion to `09-features-roadmap-geonhwa.md`
(which is the developer roadmap).

---

## 1. Data you need to collect per site

| Feature | Ground truth | Collection effort |
|---|---|---|
| F1 Vehicle classification + counting | Manual vehicle count per direction, per 15-min slot (Korean MOLIT 12-class shape, like the existing Bundang xls) | 1 observer × 4 h per site |
| F2 Pedestrian counting | Manual pedestrian tally per slot | Can share observer with F1 |
| F3 2-wheeler counting | Per-type tally: 자전거 / 오토바이 / PM-킥보드 | Same as above |
| F4 Speed | GPS-logged vehicle OR radar gun reading, synchronised to clip timestamp | ≥ 10 measurements per site, mixed speeds |
| F5 LPR | Manually transcribed plates from the same clip, with timestamps | ≥ 30 plates per site (mix of residents/visitors) |
| F6 Transit | Manual tally of boarding vs alighting events, density snapshots | 1 observer × 2 h at the actual stop |
| F7 Traffic light | Stopwatch-logged cycle times (red/green/yellow) per light head | 1 observer × 30 min per signal |

Without this data, accuracy numbers are either guesses or code-level sanity
checks — not production-ready signals.

---

## 2. Run the harness

The batch harness lives at `scripts/measure_accuracy.py`. For a single clip
run, see the command docs at the top of the file. For cross-clip validation:

```bash
# Single clip (same as M4 example)
.venv/bin/python scripts/measure_accuracy.py \
    --site scripts/sites/seodang.json --clip 07:00

# Batch: iterates every 15 min across the morning peak, prints per-clip
# report plus an aggregate at the end.
.venv/bin/python scripts/measure_accuracy.py \
    --site scripts/sites/seodang.json \
    --clips '07:00,07:15,07:30,07:45,08:00,08:15,08:30,08:45'

# Fast-iteration mode (~5 min CPU per clip instead of 25)
.venv/bin/python scripts/measure_accuracy.py \
    --clip 07:00 --trim-seconds 60
```

### Results cache

Pipeline reports land in `scripts/.measure_cache/{site}__{clip}__{cal_tag}.json`.
Subsequent runs with the same calibration reuse the cache — iterate fast on
the comparison logic without burning CPU on pipeline re-runs.

Delete the cache to force a fresh run:
```bash
rm -rf scripts/.measure_cache
```

---

## 3. Onboarding a new site

New test sites (not Seodang) need:

1. **Videos in a directory** — filenames must start with `HH.MM.SS-` so
   `find_clip()` can locate them by time. Example:
   `08.00.00-08.05.00[camera-A].mp4`.

2. **A ground-truth source**. Today only `bundang_xls` is supported
   (3-direction manual counts, 8 columns per direction). Add support for
   more formats by:
   - Adding a new `type` string in `scripts/sites/<name>.json`
   - Adding a `_parse_<type>(cfg)` function in `measure_accuracy.py`
   - Registering it in `parse_ground_truth()`

3. **A site JSON** — copy `scripts/sites/seodang.json` and edit:
   ```json
   {
     "name": "bundang_hyoja",
     "display_name": "효자촌사거리",
     "road_type": "4way",
     "video_dir": "/mnt/clips/bundang_hyoja",
     "calibration_default": "scripts/bundang_hyoja_calibration.json",
     "ground_truth": {
       "type": "bundang_xls",
       "path": "/mnt/clips/bundang_hyoja/manual_counts.xls",
       "sheet": "1",
       "slot_minutes": 15,
       "direction_starts": [1, 9, 17]
     }
   }
   ```

4. **A calibration JSON** — produced by running
   `scripts/calibration_studio.py` against one representative frame.
   Start from the right road-type template:
   - `scripts/templates/straight_template.json`
   - `scripts/templates/3way_template.json`
   - `scripts/templates/4way_template.json`
   - `scripts/templates/roundabout_template.json`
   - `scripts/templates/bus_stop_template.json`
   - `scripts/templates/residential_template.json`

---

## 4. Interpreting the output

### Per-clip report
```
========================================================================
Clip:   07.00.00-07.05.00[R][0@0][0].mp4
Slot:   07:00-07:15 (×0.333 for 300s clip)
Method: intersection_polygon
========================================================================
BUCKET                   PREDICTED       TRUTH      DIFF     DIFF%
------------------------------------------------------------------------
small_passenger                204         148       +56      +38%
small_bus                        0           4        -4     -100%
large_bus                        7           5        +1      +20%
...
------------------------------------------------------------------------
TOTAL                          223         166       +57  +34%
```

- **DIFF% ±20%** per bucket — acceptable for a PoC demo
- **DIFF% > 40%** on a major class — flag for calibration or training fix
- **`small_bus -100%`** pattern across every clip → detector-training gap
  (not a calibration issue)
- **TOTAL DIFF% > 50%** → counting bug, not classification; re-visit
  polygon / tripwire / tracker configuration

### Observation histogram diagnostic
```
Obs hist: {'1-4': 0, '5-12': 5, '13-24': 26, '25-49': 142, '50+': 51}
```
Counts tracks by how many sampled frames they lived. If `5-12` bucket
is >20% of total tracks, ID-switching is the dominant issue; increase
`MIN_TRACK_OBSERVATIONS` or tune the tracker. If most are `25+`, tracks
are legitimate and any remaining overcount is structural (see roadmap
§ F1 "diminishing returns wall" discussion).

### Batch summary
```
START     TOTAL_PRED  TOTAL_TRUTH    DIFF  DIFF%
07:00            223          166     +57   +34%
07:15            198          180     +18   +10%
07:30            205          190     +15    +8%
...
TOTAL            626          536     +90   +17%
```

Cross-clip aggregate is the headline number to bring to stakeholders.

---

## 5. Validation-readiness checklist

Before claiming a feature is production-ready, every row below should show
a "✓":

| Feature | Clips with ground truth | Harness pass | VLM path exercised | Mobile UI confirmed |
|---|---|---|---|---|
| F1 counting + classification | ☐ 5+ clips | ☐ ≤ 20% DIFF | ☐ pod Vertex on | ☐ renders |
| F2 pedestrian | ☐ 3+ clips with people | ☐ ≤ 25% DIFF | n/a | ☐ renders |
| F3 2-wheeler | ☐ 3+ clips | ☐ ≤ 25% DIFF | ☐ sub-class via Gemma (opt) | ☐ renders |
| F4 speed | ☐ 10+ GPS readings | ☐ ≤ 5 km/h MAE | n/a | ☐ renders |
| F5 LPR | ☐ 30+ labeled plates | ☐ ≥ 85% plate recall | ☐ Gemma plate read | ☐ allowlist mgmt |
| F6 transit | ☐ 1 bus stop clip | ☐ ≤ 20% boarding DIFF | ☐ density VLM gate | ☐ annotated video |
| F7 signal timing | ☐ 30 min × 1 signal | ☐ ≤ 2 s cycle MAE | ☐ arrow direction (opt) | ☐ renders |

---

## 6. What's validated today (2026-04-21)

### F1 — counting + classification

| Clip | Lighting | Predicted | Truth (pro-rated) | DIFF% |
|---|---|---|---|---|
| 07:00–07:05 | pre-dawn | 226 | 166 | **+36%** |
| 08:30–08:35 | daylight | 304 | 171 | **+78%** |

Counter-intuitively, daylight **worsened** the overcount. Working theory:

- Pre-dawn: detector is conservative, misses distant / side-lane / small
  vehicles → some legitimate undercount sources balance the polygon's
  over-capture.
- Daylight: detector is sensitive, picks up every car in every lane
  including vehicles in turn pockets and parallel paths that the manual-
  count ground truth excludes (because they don't "pass through" the
  intersection). More tracks enter the polygon, more get past the
  MIN_TRACK_OBSERVATIONS filter.

**Conclusion**: the remaining counting gap is NOT fixed by moving the
pilot to daylight. It's structural — the polygon definition is too
permissive for the semantic the ground truth uses (directional flow vs
total unique tracks). Options:

1. **Per-approach LineZones** instead of a polygon — match the per-direction
   ground-truth semantic exactly. Each approach gets its own counter; total
   = sum of per-approach unique-tid crossings (supervision dedupes).
2. **Tighten the polygon further** to just the central junction square,
   excluding turn pockets and parallel service paths.
3. **Cross-reference with Gemma** — for tracks whose polygon-entry path
   doesn't cross a tripwire, ask VLM "did this vehicle actually pass through
   the intersection, or stay on the periphery?" Cost: +1 VLM call per
   ambiguous track.

### F2 pedestrian (M1 validated functionally)

| Clip | Lighting | Predicted pedestrians |
|---|---|---|
| 07:00–07:05 | pre-dawn | 0 (plausible — empty streets at 7am winter Korea) |
| 08:30–08:35 | daylight | **3** ← YOLO11n dual-model path confirmed working |

No ground truth for pedestrians at Seodang (xls doesn't count them), so
accuracy validation awaits a site with pedestrian manual counts.

### F3 2-wheeler (M2 schema shipped)

| Clip | Motorcycle | Bicycle | Personal Mobility |
|---|---|---|---|
| 07:00 | 1 | 0 | 0 |
| 08:30 | **2** | 0 | 0 |

`two_wheeler_breakdown` JSON section populated as designed. Accuracy
untested; the Seodang xls does not break out 2-wheelers.

### F4 speed / F5 plate / F6 transit / F7 signal timing
- Code paths exist, return well-formed JSON, but no ground-truth data
  has been collected to validate accuracy
- Flagged as "blocked on stakeholder data" in the roadmap open-questions
  section

---

## 7. Customer-demo gate

Go/no-go criteria for a customer demo:

1. **F1 validated on at least one daylight clip** — pre-dawn numbers are
   worst case. Daylight result is what customers will see.
2. **One 4-way or roundabout clip analyzed** — road-type templates exist
   (M4) but have never been run against real data from those topologies.
3. **Vertex auth configured on the pod** — without it, VLM circuit stays
   open and classification improvements are invisible.
4. **One clip with known plate allowlist** — proves resident/visitor split.
5. **Mobile app renders everything the backend emits** — 2-wheeler
   section, transit annotated-video link, plate records.

If any row above is unchecked, demo should be framed as "early PoC with
known gap X" rather than "production-ready".
