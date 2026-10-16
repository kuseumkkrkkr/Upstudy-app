# BookData V2 native activity contract

Status: implemented locally; candidate/browser verification required before release.

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
