# BookData V2 native activity contract

Status: partial native support; integration Preview boot verified, clean-source
release blocked. `BOOK_ACTIVITY_EXPERIMENT_RELEASE.md` distinguishes artifacts.

## Native experiment and responsive reader follow-up

- `discreteExperiment` is implemented, not a future-placeholder type. Contract
  and per-source gaps: `BOOK_ACTIVITY_CAPABILITIES.md`. Python55 passed;
  Flutter11 passed with concurrency1; seven scoped Dart files analyze clean.
- Actual candidate source SHA256 `6F20989F43BD809CE7C825636696A9DB293F8C589F5DE63B5F083027C64BDF7E`
  loaded locally through BookData into the real BookWidget (24 source pages,
  37 split reader pages). No student API write or manuscript publication.
- Found/fixed multipage responsive teardown losing local activity state.
  Reader-local snapshots check book/activity/definition; clear on account/book
  replacement, die with reader. No disk/server/timer/RNG serialization.
  At34/37, Enter produced6, count1, even1/1=1.000; first hint retained through
  1280x900 ->390x844 ->1280x900. Reset cleared counters/hints. At33/37,
  1/3 answer, explanation and hint also survived both directions.
  `candidate-reader-after-390.png` / `candidate-reader-after-1280.png` and
  `candidate-quiz-after-390.png` under the capabilities evidence folder record it.
  Earlier key-only failed capture was superseded, not counted as a pass.
- Full106-source migration, all-page visual parity, live PostgreSQL persistence
  and load tests remain incomplete. Do not promote unreviewed manuscripts.

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
- Same-payload model recreation now retains local answers/interaction state;
  changed activity content still resets. Regression test rebuilds a typed model
  and checks feedback survives. Native browser QA is separate from live imports.
- V2 create/list/detail storage is also covered by the fake-store endpoint test;
  unknown create fields are rejected rather than silently dropped. Python31
  passed after this addition. New model/widget/preview/test analysis: zero issues.
- `tool/book_activity_preview.dart` is a separate local QA entrypoint with
  synthetic data, not a production route/import or a real learner record.
- Existing course/exam/problem-set deletion remains0 pending student-record
  scope and replacement readiness. Textbooks/level-test/user accounts untouched.

## Final local-only verification

- Native activity state is kept alive when its lazy-list/page parent scrolls it
  out of view. Route disposal still discards the local state; nothing is saved
  to student DB. Added actual2400px list scroll-out/back regression.
- Final Python43 tests passed, including import/create ownership and graph/auth
  regressions (20 pre-existing test/deprecation warnings). Final V2 Flutter7
  tests passed; five scoped Dart files analyze with zero issues. These are
  focused checks, NOT full-app analyze/test or a real DB200-connection test.
- Final frozen source release build succeeded in255.1s on Flutter3.44.6,
  Dart3.12.2, D: hotfix. Existing Cupertino font warning remains; no font copied.
- Synthetic real browser: ArrowRight changes p2→2.5; both distances become4.10.
  Choice2 yields correct feedback, hint is revealed, fraction1/2 grades correct,
  step1→2 works. Verified390×844→1280×900 retains answers, hint and step.
  Additional844×390 screenshot confirms narrow-height scrolling layout.
- Proof images under `design/student/audits/evidence/2026-10-16-bookdata-import/`:
  `activity-v2-final-answers-390.png`, `activity-v2-final-answers-1280.png`,
  `activity-v2-final-landscape-844.png`. These show the separate synthetic native
  widget harness, NOT production UI, HTML visual parity or live DB persistence.
  Earlier `activity-v2-local-answers-390.png` captured a pre-fix reset and is NOT
  a successful answer-proof image. Initial/fixed geometry captures are local QA.
- Private new 중학수학2-2 V2 manuscript SHA256
  `85EB8724D4095D2BB0E41D3CA143183DC32E831ABB0983CF28F8E53486AA51C3`
  passed native BookData model round-trip with4 activities. Its actual24-page
  rendered parity, teacher/rights review and server publication remain undone.
  Source was not copied into this repository or uploaded.
- Temporary browser viewport override, QA tab and local9133 server cleaned up.
  No further deployment or alias promotion after candidate1 hold.

Final code checkpoint: `55fdbb616ae4fba7b8048aee0ecac1892aa5d51d`.
Local `public/main.dart.js`7149884 bytes, SHA256
`A31C64AE83873141DCE1942F969C2A4CAA75D001A05A33B9D77B0CE38D96F2BD`.
This final bundle has NOT been deployed. Local source snapshot
`build/temp/activity-v2-final-source.tar`, SHA256
`357230D5218E32F5DEFC20149805BA0417927E2DE5032A63F2B17E4023C31AE0`.
It includes existing dirty integration dependencies and excludes env/credential
files; source checkpoint alone does not reproduce the full working-tree build.
Next: review preview-only deployment settings before another candidate; then
test candidate backend V2 storage with an authorized test account. Do not promote
candidate1 or substitute local synthetic UI evidence for that server check.

## Read-only preview configuration audit (2026-10-16)

- Starting HEAD and origin/hotfix both `e9028f9da180835d642863d49c09ebdf81341e5d`;
  existing166 tracked dirty files retained. No app/runtime changes in this audit.
- `vercel env ls`:14 encrypted variables, all Production only. Explicit
  `vercel env ls preview`: zero variables. No values pulled or copied.
- Authenticated GET project metadata: `autoAssignCustomDomains=true`, preview
  protection `all_except_custom_domains`. Project domain list contains canonical
  `aiflow-web-canary.vercel.app` with no branch/custom-environment binding.
  These settings were NOT changed. A project production target ID is not proof
  of where a specific custom alias points; alias listing still shows `hvv457edo`.
- Standard CLI preview is `vercel deploy` without `--prod`, using its unique URL.
  Official references: [environments](https://vercel.com/docs/deployments/environments),
  [CLI deploy](https://vercel.com/docs/cli/deploy),
  [environment variable scopes](https://vercel.com/docs/environment-variables).
  Standard preview routing is available; a functioning isolated storage/auth
  environment is NOT currently configured. No deployment attempted this audit.
- Existing `public` is prebuilt with canonical `API_BASE_URL`, not preview-ready:
  a plain upload would send V2 UI requests to the old canary backend. Runtime
  Vercel environment variables do not rewrite Dart `String.fromEnvironment`.
- Future preview web build must explicitly use its own API origin. Empty
  `--dart-define=API_BASE_URL=` builds relative HTTP URLs without modifying product
  defaults. `http` BrowserClient forwards request URI strings to browser fetch;
  URI-builder test below checks no canonical host is inserted. Actual preview
  browser transport/storage is still unverified. Do not repurpose that web-only
  configuration as a native/mobile server URL.
- Missing independent Preview configuration:
  `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` from an approved isolated test DB;
  an independent `OMJ_JWT_SECRET`; a test account belonging to that DB.
  CORS must match the test origin if cross-origin requests are intentionally used.
  Same-origin book QA needs no Kiln/Lightning/administrator secrets.
- Do NOT copy Production DB/key/JWT into Preview, reuse the admin-only database,
  create a new resource/access grant without authorization, or pretend instance-
  local memory/SQLite is durable serverless storage. No production manuscript
  uploads, user changes, legacy deletion, domain writes or alias operations.
- Blocker is missing configured isolated storage/auth resources, not a proven
  Vercel permission denial: read-only CLI/API access succeeded. Required resource
  source/authorization must be supplied before create/list/detail live writes.
- Validation command: `flutter test --no-pub --dart-define=API_BASE_URL= test/api_contract_isolated_preview_test.dart`.
  Passed1 test. Default `test/api_contract_test.dart` separately passed1 test;
  neither default origin nor OCR origin changed. Re-ran private import/V2
  Python tests31 passed. This is URI-builder proof only, not deployed behavior
  or persistence proof. The preview-specific test is explicitly inapplicable
  (skipped) under a nonempty/default production origin configuration.
- Rechecked local bundle `A31C64AE...`, canonical served bundle `7F54EE14...`.
  Final local code/build/browser evidence above remains valid; no source rebuild
  is needed for documentation/configuration tests alone.

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
| `discreteExperiment` (integration Preview only, not promoted) | Nested finite-outcome definition, weights/event flags, bounded trial batches | Actual local sampling/counts/frequency/reset; see `BOOK_ACTIVITY_CAPABILITIES.md` for the full contract, focused tests and pending asset migrations |
| `statisticsEstimator` (local reader verified, not deployed) | `statistics` mean values or proportion counts; strict bounded input | Editable sample estimate/interpretation/variability/reset/hints; contract `BOOK_STATISTICS_ESTIMATOR.md`; no confidence intervals/tests |
| `rightTriangle` (bounded native extension; no production manuscript) | Required integer `a`,`b` in1..12 | Keyboard sliders, live sqrt(a²+b²), proportional diagram, local hints/reset; contract `BOOK_RIGHT_TRIANGLE.md`; broader derived-metric scenes unsupported |
| `coordinatePoint` (bounded native extension; no production manuscript) | Required integer `x`,`y` in-5..5 | Direct point pointer/touch drag, arrow-key movement, sliders, quadrant/axis/origin, three movement stages; `BOOK_COORDINATE_POINT.md`; not arbitrary JSX |
| `coordinateWalk` (separate bounded kind; no production manuscript) | Integer `x`,`y` in-5..5 and exact `duration_ms:1500` | Swap, horizontal/vertical walk, pause/resume/reset, reduced-motion and paused reader restore; `BOOK_COORDINATE_WALK.md` |
| `vectorOperation` (bounded plane operations; no production manuscript) | `operation` add/subtract/scalar; components -4..4; `alpha` half steps -2..2 | Interactive arrows, guided stages, formula and hints; `BOOK_VECTOR_OPERATIONS.md` |
| `vectorInnerProduct` (bounded plane activity; no production manuscript) | Magnitudes 1..5; included angle 0..180 in 15-degree steps | Projection diagram, sign prediction, guided derivation and hints; `BOOK_VECTOR_INNER_PRODUCT.md` |

Common: `id` nonempty max80, unique in book; `prompt` nonempty max2000;
optional `hints` at most8 strings max2000. No asset IDs, author JavaScript,
arbitrary formulas, HTML or remote execution. Other subject-specific geometry
needs another reviewed registered kind; this contract does not claim all
standalone HTML interactions are supported.

## State and safety

- `_answer`, `_choice`, `_feedback`, `_step`, `_hints`, `_p`, `_x` belong to the
  reader session only. Reset clears them; reader disposal/account or book change
  discards snapshots. Responsive child remount restores them. No disk/server
  learner answer persistence or exam/OVR write.
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
