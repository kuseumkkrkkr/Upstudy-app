# Source HTML capability preservation ledger

Scope:106 source assets inventoried at `1c28c3038c0eac48de5f3e6bd2581dbf7d486b24`.
`design/student/audits/book-activity-source-inventory.json` records every relative
path, source/script SHA, control bounds, event names and review status. No original
HTML/JS is copied into the app or executed by an activity renderer.

## Interpretation

-106 distinct inline script hashes; source signals: randomness2, pointer events2,
  timers13, reduced-motion references86. Signals may include dead code/comments;
  they are NOT behavior tests or proof a renderer supports an asset.
- All106 remain **not_ported** until explicit manuscript mapping, full behavior
  conversion and UI verification. Implementing a reusable capability does not
  automatically migrate an HTML asset or approve publication.
- JSON activity IDs are authored IDs unique within a book. Inventory `html-*`
  IDs identify source paths; neither is an executable asset URL. No automatic
  asset-ID linking, arbitrary HTML embed, JS callbacks, network requests or eval.
- Original sources remain in the author's repository. Exact book/product/page
  mapping is unresolved until an explicit source/tag index is supplied; do not
  infer2015/2022 or a product from a filename alone.

## Manually read script evidence / remaining features

| Asset | Actual behavior read | Native status / gap |
|---|---|---|
| `html-4f713a1ae26d9f06` 中2-2 probability experiment | Uniform die roll, even-event count, n, relative frequency, last result, reset | New `discreteExperiment` preserves this functional family; author migration/full-page parity still pending |
| `html-361c3fa29514eca0` statistical probability | Event is face6; cumulative curve vs1/6,10–1000 requested trials, capped5000, interval play/stop/add, reduced-motion handling, steps/hints/quiz | Discrete sampling/counting only is reusable; trajectory plot, timed run/stop and connected scene are NOT yet ported |
| `html-a10eb6a3240af7e0` Pythagoras | a/b range inputs1–12; sqrt(a²+b²) numeric result | New bounded `rightTriangle` preserves controls/calculation; proportional native diagram is an addition, author migration/approval still pending; see `BOOK_RIGHT_TRIANGLE.md` |
| `html-002d8074c7ebb2fb` vector sum/scalar | Mode selection, component inputs, stage-dependent arrows, result length, adaptive question sequence with wrong-count hint and500ms advance | Missing vector scene and adaptive Socratic sequence. Content issue sent to author; not eligible for blind conversion |
| `html-3a28d8d04e3fa616` parabola | p/x controls, focal/directrix equality, explicit playback, steps and two checks | Existing `parabolaDistance`/quiz/steps can represent parts, but original V1 pages are not auto-converted; source itself has no direct point dragging |

Vector content issue: question compares α=2 to−2 but marks a doubled length;
2u and−2u have equal lengths and opposite directions. Author must clarify the
comparison/choices. Renderer must not encode the erroneous answer as mathematics.
Do not silently alter original author files here.

## Remaining implementation families (not claimed supported)

- Cartesian direct point dragging and keyboard movement: source pointers in
  `html-3050dd8407807a29` and `html-7bbc2e50f5387d53` read fully. New
  `coordinatePoint` covers the first source's bounded grid-point/keyboard/step
  interaction. The second source's timed animation/swap is not implemented;
  source-specific full manuscript migration/review remains pending.
- Parameter-dependent metrics/number lines/algebra and invalid-domain feedback;
  current graph sliders alone do not reproduce connected numeric results.
- Vector transformations, lengths/dot products, translated arrows and staged
  diagrams; conics and3D projected-distance construction.
- Set membership/relation diagrams, inequalities, prime-factor steps, polynomial
  area partitions, sequence bars, calculus secants/tangents and integral regions.
- Timed trajectories and playback stop/resume; adaptive Socratic dialogue and
  multi-field/dynamic-answer checks. Existing independent quiz/steps blocks are
  NOT equivalent replacements for these connected interactions.

## New registered type: `discreteExperiment`

```json
{"type":"activity","activity":{
  "id":"even-dice","kind":"discreteExperiment","prompt":"Observe the event frequency",
  "hints":["Compare event count with total trials."],
  "experiment":{
    "outcomes":[
      {"label":"1 (odd)","weight":1,"success":false},
      {"label":"2 (even)","weight":1,"success":true},
      {"label":"3 (odd)","weight":1,"success":false},
      {"label":"4 (even)","weight":1,"success":true},
      {"label":"5 (odd)","weight":1,"success":false},
      {"label":"6 (even)","weight":1,"success":true}
    ],"max_trials":10000,"batch_sizes":[1]
  }
}}
```

- V2 only. Common id/prompt/hints bounds remain unchanged. Nested `experiment`
  permits only `outcomes`, `max_trials`, `batch_sizes`; no learner counters or RNG
  seed may be imported from JSON.
- Outcomes2–32, unique nonempty label<=120 chars; weight finite0..1e6, default1,
  positive total; success is strictly boolean. Zero-weight outcomes never draw.
- Max trials integer1..100000, default10000; batch list1–4 unique integers,
  each1..min(1000,max_trials), default[1]. Last batch clamps to remaining trials.
  These explicit ceilings differ from an unlimited prototype; do not call that
  unlimited behavior pixel/behavior parity. Review budgets before raising caps.
  Optional values mean omitted; explicit null is rejected on server and client.
- `BookDiscreteExperiment.fromJson/toJson` and Python `validate_activity` preserve
  only the definition. `sample(Random)` advances local RNG; no remote sampling,
  OCR, chat, grading, score/OVR or student-record write.
- `_ExperimentState._draw` changes `_counts`/`_trials`/`_successes`/`_last` locally;
  `_reset` clears them and hint index. `_random` lives for the mounted activity;
  reset does not rewind randomness. Recreated equal data and lazy scroll retain
  state; changed content/disposal discards it. No disk/server answer persistence.
- Buttons support keyboard activation; live-region result and textual per-outcome
  counts provide a non-color alternative. No auto-run, timer or animation. This
  type does not supply the other asset's trajectory curve or timed playback.
- Migration is explicit authored data, not JS parsing into executable callbacks.
  Preserve source/tag/asset hashes in the external ledger and add a new V2 file;
  never flatten unsupported parts or overwrite immutable reviewed source.

| Responsibility | Input / return / effects |
|---|---|
| Python `validate_activity` experiment branch | JSON definition -> same validated value; fails before storage |
| `BookDiscreteExperiment.fromJson/toJson` | bounded definition <-> immutable model; FormatException on invalid data |
| `sample(Random)` | RNG -> outcome index; advances local RNG only; zero-weight excluded |
| `_ExperimentState._draw(batch)` | user button -> at most remaining trials; updates local counters/last index |
| `_reset` | user reset/content replacement -> zero counters and no last result; does not rewind RNG |

| State | Source / units / lifetime |
|---|---|
| `outcomes`, `maxTrials`, `batchSizes` | validated author definition; trials/weights; immutable book data |
| `_counts`, `_trials`, `_successes` | local draw calculation, nonnegative integers; mounted activity only |
| `_last` | outcome index,−1 means no result; updated by draw/reset |
| `_hints` | locally revealed hint count; reset with activity |
| `_random` | local process RNG or synthetic test RNG; never imported/exported in JSON |
| Reader `_activityKeys` | one GlobalKey per validated unique activity ID; reader lifetime, cleared on book replacement, no disk/server storage |

`BookActivityKeyScope` owns keys and ephemeral snapshots above breakpoint branches.
Keys alone did NOT fix the actual37-render-page candidate: the new shell first
renders its initial page, then restores page34, after old children have disposed.
Snapshots are updated during local activity builds and restored before the new
activity paints, checked by bookId/activityId and full definition fingerprint.
Only reader lifetime is retained; book replacement/account change clears maps,
reader disposal releases them. This is not process-global/disk/server storage.
Discrete snapshots hold counts/successes/last/hints/trials. Quiz/steps/geometry
hold answer/choice/feedback/step/hints/p/x. Playback timer/elapsed time is NOT
restored: remount stops animation and retains the last displayed coordinates.
RNG is not serialized; later independent random draws continue from a new RNG
if remounted. Counts remain the prior observations, not re-sampled results.

Before-Dart screenshot: no corresponding original native experiment existed;
the prior schema did not support this activity. Do not fabricate a "before"
screen or import a draft into production merely to make one. Source HTML and
native-after captures are separate capability evidence, not full-page parity.

## Focused evidence so far

Actual candidate source checked: `중학수학2-2_2022개정_통합시범/중학수학2-2_2022개정_측정과가능성_BookData_V2_시범.json`,
39765 bytes, SHA256 `6F20989F43BD809CE7C825636696A9DB293F8C589F5DE63B5F083027C64BDF7E`.
It contains24 pages; `ms22-22-probability-practice` / activity
`ms22-discrete-probability-experiment` uses six equally weighted die faces,
even-event flags, single-trial controls, max10000 and two hints.
Original `html-4f713a1ae26d9f06` is
`중학수학2-2_2022개정_통합시범/중학수학2-2_2022개정_확률실험_체험형_시범.html`,
SHA256 `AE7667748C7446E0A8C55110F821615E6A0475108158221AB94144AFB338F39F`.
Its inline script also samples a fair die and counts even results. This is the
same mathematical experiment, not the other face6/trajectory asset. Native
adds a finite cap, per-face counts and hints; labels omit odd/even annotations.
Therefore behavior coverage is partial, not full source appearance parity;
inventory migration status remains not_ported until author mapping/review.
`tool/book_activity_preview.dart?reader=1` accepts local-only `BOOK_QA_JSON`
through `--dart-define-from-file=build/temp/private-activity-qa/reader-defines.json`.
That ignored file contains this complete candidate, never public/Git assets.
Reader uses synthetic identity and persistence=false; it does not test the
real API, authentication, PostgreSQL, ownership, or live persistence.

- Python55 passed: strict bounds/unknown keys/nulls, zero mass, source inventory, fake-store V1/V2
  import/create/owner list/detail and same-source24-request retry checks.
- Flutter11 passed serially: absent-frame remount snapshots, sampling/zero weight, cap15 and10+5 batch clamp, reset,
  scroll-state preservation, mobile keyboard, actual reader reachability and
  actual-reader counts/hints and quiz feedback/hints preserved both directions,
  existing activity regressions. Seven scoped Dart files analyze: zero issues.
- These are not real PostgreSQL load tests or live V2 persistence proof. Isolated
  Preview DB/JWT/test account remain missing. No public/canary deployment is implied.
- Real browser synthetic widget QA:390x844 keyboard Enter ran one trial;
  one10 batch gave11 total, then repeated batches clamped exactly at50.
  Per-outcome counts7/9/12/9/9/4 sum50; even event22/50=.440.
  At1280x900 counts survived resize; reset restored0 and enabled both buttons.
  Captures: `design/student/audits/evidence/2026-10-16-book-activity-capabilities/`
  (`discrete-native-390.png`, `discrete-cap-390.png`, `discrete-cap-1280.png`).
  Source HTML screenshot stays private under `build/temp/private-activity-qa/`;
  prototype draft is not published. These captures are capability QA, not full
  HTML/reader parity or deployed persistence proof.
