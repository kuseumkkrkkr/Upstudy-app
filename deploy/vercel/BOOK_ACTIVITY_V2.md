# BookData V2 native activity contract

Status: implemented locally; candidate/browser verification required before release.

## 2026-10-16 checkpoint

- Source checkpoint `8caf0127657798d813c811196d3862b358dd007f` pushed to hotfix.
- Python import/activity tests31 passed (V1/V2 owner isolation and fake-store
  concurrency), V2 Flutter tests5 passed including390/1280 reader, existing
  preservation tests4 passed. New model/widget scoped analyzer: zero issues.
- D: release build succeeded. First candidate `dpl_GA9cePH1LrCu1iNmykjx4RTnj8cD`:
  `https://aiflow-web-canary-yxfo228ug-cw20208021-9200s-projects.vercel.app`.
  Local/candidate bundle7149562 bytes, SHA256
  `D97079B45A265D43A80F3F9CEF82D0BBF7E6344F6F3D042D7B318F0FF7C4EF96`.
  Full dirty source snapshot `build/temp/activity-v2-source.tar`, SHA256
  `C2D82915C4BA11BD99E91A7B16E2E332BEBCA272E7143ADAD686863B2E40446A`.
  Snapshot is local only; HEAD alone is not full runtime reproducibility proof.
- Candidate `/textbooks/import` without credentials returns401. `/openapi.json`
  falls through Vercel routes to the SPA; it is NOT backend schema evidence.
  Candidate frontend still targets canonical API. No live V2 student persistence
  claim; private V1 testing from earlier releases is not a substitute.
- CLI `--prod --skip-domain` unexpectedly assigned the secondary project URL
  `aiflow-web-canary-cw20208021-9200s-projects.vercel.app` to candidate1. Immediately
  restored that URL to the previously verified `hvv457edo` deployment, then
  checked alias listing. No further deployment/promotion until this is resolved.
- Designated canary stayed on `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`, bundle SHA256
  `7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`.
- Browser QA caught unequal axis pixel scales in candidate1's geometry. Fixed
  native drawing and dragging to use the same graph-unit scale on both axes.
  **Candidate1 is superseded and must NOT be promoted.** Fix widget tests5 passed.
- `tool/book_activity_preview.dart` is a separate local QA entrypoint with
  synthetic data, not a production route/import or a real learner record.
- Existing course/exam/problem-set deletion remains0 pending student-record
  scope and replacement readiness. Textbooks/level-test/user accounts untouched.

V1 is the default when `schema_version` is absent. V2 explicitly sets
`schema_version: 2`. Unknown future versions, unregistered kinds, duplicate
activity IDs and executable/unknown fields are rejected at the import boundary.
The importer still verifies the exact source SHA-256 and stores private books by
authenticated owner. This extension does not publish unreviewed manuscripts.

Each activity occupies one indivisible `pages[].blocks[]` entry:

```json
{"type":"activity","activity":{
  "id":"question-1","kind":"quiz","prompt":"Choose an answer",
  "options":["A","B"],"correct_index":1,
  "correct_feedback":"Correct; compare the two distances.",
  "incorrect_feedback":"Compare the distances again.",
  "hints":["What distance must stay equal?"]
}}
```

| Kind | Additional fields and bounds | Native behavior |
|---|---|---|
| `quiz` choices | `options` 2–6 nonempty strings; zero-based integer `correct_index` | Select, missing-answer feedback, deterministic check, retry |
| `quiz` numeric | `answer` finite +/-1e6; optional nonnegative `tolerance`, default 0 | Decimal or single fraction input; rejects NaN/infinity/zero denominator/code |
| both quizzes | required `correct_feedback`, `incorrect_feedback` | No answer exposed before submission; hints revealed one at a time |
| `steps` | `steps` 1–12 nonempty strings | Previous/next, disabled endpoints, reset; one step can be a Socratic question |
| `parabolaDistance` | `p` .5–3; `x` -4–4 | Trusted native `y=x²/(4p)`, draggable P, keyboard-accessible sliders, focus/directrix distances, explicit 5-second play/stop/reset |

Common: `id` nonempty max80, unique in book; `prompt` nonempty max2000;
optional `hints` at most8 strings max2000. No asset IDs, author JavaScript,
arbitrary formulas, HTML or remote execution. Other subject-specific geometry
needs another reviewed registered kind; this contract does not claim all
standalone HTML interactions are supported.

## State and safety

- `_answer`, `_choice`, `_feedback`, `_step`, `_hints`, `_p`, `_x` belong to the
  mounted reader activity only. Reset clears them; disposal/account-driven
  reader removal discards them. No learner answer persistence or exam/OVR write.
- `_p` is focus ordinate, `_x` point abscissa in graph units. Values originate
  from validated author defaults and bounded local controls. Curves and metrics
  are calculated natively; no eval/parser is required.
- `_timer` is explicit playback only, cancelled on stop/reset/manual manipulation,
  inactive route/lifecycle/ticker, reduced motion, update and disposal.
- Reduced motion never moves P automatically. Sliders and textual coordinates
  and distances remain available. Point drag target is48px; the rest of the
  plot does not capture scrolling gestures.
- `BookActivity.fromJson/toJson` validate/round-trip the registered payload.
  `BookData` storage/create/library JSON preserve `schema_version`.
- `migrate_v1_to_v2` validates and deep-copies the author object, only adding the
  version. It never mutates originals, invents answers or auto-converts prose.
  Authoring must explicitly add activities. V1 remains supported unchanged.

## Responsibility map

| Code | Input / result / failure |
|---|---|
| Python `validate_activity` | author payload -> same validated data; ValueError before storage |
| `validate_book` | V1/V2 source -> validated book; enforces version and ID uniqueness |
| `migrate_v1_to_v2` | valid book -> independent V2 copy; source untouched |
| Dart `BookActivity.fromJson` | registered JSON -> immutable typed model; FormatException on unsupported fields/kinds |
| `BookActivity.numericInput` | max80-character local answer -> finite double or null |
| `BookActivityView` `_grade` | selected/typed answer -> local feedback only |
| `_play`, `_stop`, `_reset` | explicit controls -> bounded local animation/state; timer cancelled on exit |
| `_ParabolaPainter` | bounded p/x -> native plot; no network/image/script |

Tests: `tests/test_book_activity_v2.py`, `test/book_activity_v2_test.dart`, plus
existing private import/preservation regressions. Unit/widget results do not
replace live server persistence, actual browser interactions or load testing.
