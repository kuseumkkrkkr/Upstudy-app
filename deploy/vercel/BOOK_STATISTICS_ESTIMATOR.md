# statisticsEstimator contract

Status: locally implemented; actual candidate reader/browser verified.
Clean-source release remains blocked, not deployed. Not a complete curriculum/
106-source migration or published textbook.

The author review identified an actual-tool gap in mean/proportion estimation;
quiz/prose alone does not supply editable computation. This registered V2 block
computes sample estimates with explicit interpretation and sample variability.
It does not assert that an arbitrary sample represents a population.

```json
{"type":"activity","activity":{
  "id":"sample-mean","kind":"statisticsEstimator",
  "prompt":"Edit the sample and interpret the estimate",
  "hints":["Would a different representative sample give the same value?"],
  "statistics":{"mode":"mean","sample_values":[2,4,6]}
}}
```

Alternative: `statistics:{"mode":"proportion","successes":3,"trials":10}`.
Common id/prompt/hints bounds are unchanged. Mean values1..200 finite numbers
within±1e6; proportion trials integer1..100000 and successes integer0..trials.
Unknown/mixed fields, bool-as-number, nulls, scripts, answers/learner state,
confidence interval and inference settings are rejected before storage.

UI: mean numbers separated by comma/whitespace; proportion has two integer
inputs. Estimate explicitly on button press; editing hides prior results.
Invalid input clears prior estimate and gives actionable feedback. Reset restores
author defaults and clears estimate/hints/error. Hints reveal in authored order.
Mean result rounds to4decimal places, proportion percentage to2decimal places;
the rounding and formula are labeled. Sample variability/representativeness
warning always remains visible; no certainty or population-value claim.

No confidence intervals, significance tests, simulated sampling, OCR, chat,
grading, OVR/level, HTTP or learner server/disk writes. This deterministic tool
does not replace a simulation or a connected statistical trajectory asset.

| Responsibility | Inputs / results / effects |
|---|---|
| Python validate_activity | bounded declarative statistics definition -> same value, raises before storage |
| BookStatisticsEstimator.fromJson/toJson | strict immutable typed model round trip, FormatException on invalid payload |
| _calculate | current text -> validated sample mean or proportion; local estimate/error only |
| _changed | input edit -> removes stale estimate/error, preserves edited raw input |
| _reset | user reset or changed definition -> author defaults, no result/hints |
| didChangeDependencies/build | reader book/activity/definition-keyed snapshot restore/save, no persistence |

| State | Source / units / lifetime |
|---|---|
| samples/successes/trials | validated author definition; numbers/counts, immutable |
| _values/_trials controllers | local user text; disposed on activity removal |
| _estimate | computed arithmetic mean or ratio, null before valid explicit estimate |
| _sampleCount | count of input values or trials,0 when no valid current estimate |
| _feedback/_hints | local validation message/revealed hint count, reset with activity |
| reader snapshots | input, result, count, feedback, hints only; cleared on book/account change/reader disposal |

Browser verification is not the clean-release or live-storage gate.

Focused local verification: Python78 passed including new21 strict statistics
checks plus owner-scoped fake-store import/create/list/detail/retry regression.
Flutter15 passed serially including new4 estimator checks; five scoped Dart
files analyze clean. These tests use the integration working source, not a
clean release or live PostgreSQL persistence.
The new actual multipage reader test also verifies edited mean input/result/hint
through desktop/mobile/back, different book reset and account-change removal.

Actual authoring candidate input (not published):
`확률과통계_2022개정_확률통계누락8단원_Batch3_BookData_V2_시범.json`,
45735bytes, SHA256 `45CC9070270D74D21E9AF92F2748CAC80E150CA3CF9D5B0AEF0DFC1148C46DBC`,
40source pages. `ps0307-practice` contains `ps0307-estimate-mean`
([8,9,10,10,11,12]) and `ps0307-estimate-proportion` (28/50), authored hints.
Local-only full candidate is passed through ignored statistics-reader-defines.json
to the existing QA reader entrypoint; no server upload or learner write.

Actual browser QA used the complete candidate in BookWidget, not a stand-alone
card. The40source pages produce58reader pages. ps0307-practice is split into
plain exercise53, quiz54, mean55 and proportion56; each activity stays indivisible.
Both estimators do not overflow a single mobile page stacked together.

- Mean55/58: source sample computed10.0000; real keyboard replaced input with
  `2, 4, 12`, old result disappeared, explicit estimate computed6.0000/n3.
  First hint shown;1280x900 ->390x844 ->1280x900 retained input/result/hint.
- Proportion56/58: source28/50 computed56.00%; mobile keyboard edited30,
  computed60.00%, first hint shown.390x844 ->1280x900 retained input/result/hint.
  51/50 produced an actionable error and no stale estimate. Reset removed hint/
  error; next estimate returned28/50=56.00%, confirmed in pixels.
- At390x844 inputs/buttons/result/interpretation are accessible. At390x600,
  real wheel scroll exposed the lower warning/hint/disclaimer while navigation
  stayed fixed and30/50 remained intact. No full-device keyboard/screen-reader
  certification is inferred from responsive viewport tests.
- Automation caveat: Flutter's DOM-mirror fill appended to existing input;
  actual Control+A + typed keys replaced it correctly. After programmatic reset,
  the DOM mirror briefly still reported51 while pixels showed28 and calculation
  correctly returned56%. Do not use stale DOM mirror values as numeric evidence.
- Captures under `design/student/audits/evidence/2026-10-16-book-activity-capabilities/`:
  statistics-mean-390/1280.png; statistics-proportion-390-top/1280.png;
  statistics-proportion-short-scroll.png; statistics-reset-1280.png.
  They are local integration QA, not screenshots of a published manuscript.

Image SHA256: mean390 `D4D493F7ADB45010453A32A63CC6AC47D4F7C7E3BDADD4DF9AD12388CF87143F`;
mean1280 `DAB1C72C2558C963F1C8B4E0088CAD5D9E679F8BDDA1624AB95B47396BEA793C`;
proportion390 `1517AED6C286F043A4FBE3C06C38DE8FDD37B6F22CF7D25354892D718345037B`;
proportion1280 `1DAC4F8C0018210D80329A8BA194FD926E4C66FB65D0A9C03AE483C98116A550`;
short scroll `DC420E0D7C39F0DEF51FC333F8217644D837C222D4B3D80B694BC4B32E4E706D`;
reset `E7EA3E1D1B0D11891E2F20688E15DD91B2BA2CADFC54DACB5CB42A706360DBFB`.

Deployment boundary: no new statistics release bundle/Preview has been produced.
The earlier Preview contains the previous experiment code only. Its integration
source includes unrelated dirty dependencies and is explicitly not promotable.
Clean archive-reader tests exposed missing committed bookLoader/sessionChanges
and exam mixin fields. Flutter's Dart2JS target also ignores global package-config
override (SDK web.dart196); an apparently successful archive build still used
dirty root files per depfile. See BOOK_ACTIVITY_EXPERIMENT_RELEASE.md. Do not
substitute that bundle or teacher-reader/user edits for a clean verified release.
