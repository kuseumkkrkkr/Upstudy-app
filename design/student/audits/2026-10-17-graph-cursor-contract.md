# Graph observation cursor and square-root activity — 2026-10-17

## Contract and scope

- Worktree/branch: guarded D: `Upstudy-hotfix`, `hotfix`. Implementation commit: `35da8e9` (full SHA in Preview proof). Unrelated dirty work remains preserved.
- Two original `x` collisions are resolved through an explicit reversible author-preparation migration, not relaxed reserved names. Only `id: x`, exact `label: 관찰 위치 x`, and an absent role qualify. Ambiguous labels, existing cursor/name collisions and unknown roles still reject.
- Canonical parameter: `id: observed_x`, `role: observationX`, with the exact original label/default/range/step. Every migrated parameter's original object and path are retained in metadata. Both documents have section and page copies: four migrations total.
- `role` is either omitted/`coefficient` (legacy behavior) or `observationX` (at most one per graph). Observation identifiers cannot be used as formula coefficients. The arithmetic coordinate `x` remains reserved and expressions remain byte-for-byte unchanged.
- The shared web/native HTML builder evaluates each enabled function at the selected x, renders a coloured point, and publishes an accessible x/y readout. Out-of-range/non-finite points are not drawn. The canvas fallback uses the same observation helper and retained live slider values; cold CDN failure now initializes the payload before fallback rendering.
- Structured tutor observations retain the optional role, but remain untrusted reference values, never grading or ownership evidence.
- `squareRootNumberLine`: registered V2 activity, required integer `min: 1`, `max: 25`; unknown fields/bools/floats/other bounds reject. Dart serialization preserves the payload and the reader renders an integer n slider plus √n on a 0..5 number line. This activity does not submit grades or change OVR.

## Frozen corpus verification

- Original 150-file manifest: every input SHA unchanged, **150/150** exact reconstruction passes after migration.
- Expanded frozen 152-file manifest: **152/152** exact reconstruction passes; includes the new square-root activity. No source files modified.
- The folder continued growing during work. Separate inventory captured **153** files: **152** pass, one newer file blocks with `graph.expression: unknown identifier`:
  `중등수학_2015개정_함수그래프_부분초안/중등수학_2015개정_함수그래프_BookData_V2_시범.json`.
  That new file is not part of the frozen 152-file success claim. Do not weaken expression validation to include it.
- Focused Python tests: **60 passed**. An opt-in local FastAPI test imported and reloaded every canonical book through `/textbooks/import` and `/textbooks/{id}` using an in-memory storage double; no real Supabase writes occurred. A synthetic public catalogue/acquisition/reader test retained the square-root activity. These are not real-DB load-test evidence.
- Actual generated JS executed with DOM/JSXGraph/canvas test doubles: cursor -1 → .5 changes cubic point `(−1,2)` → `(.5,−1.375)`, quadratic point to `(.5,1.25)` and derivative point to `(.5,−3)`, while sampled curve coordinates remain identical. Both main and fallback rendering paths pass. No native-device runtime result is claimed.
- Flutter corpus test recursively checks supplied fields/list ordering through `BookData` serialization. The observation role, activity payloads, pages, graphs and labels are included, not counted as optional losses.

## Reproduction

After the same-shell D: worktree guard:

```powershell
python -m tools.audit_bookdata_roundtrip '<author root>' --baseline-manifest design/student/audits/bookdata-author-roundtrip-2026-10-17.json --report build/temp/bookdata-cursor-baseline150-audit.json --private-fixture build/temp/bookdata-cursor-baseline150-private-fixture.json
$env:BOOKDATA_PRIVATE_FIXTURE = '<D: worktree>/build/temp/bookdata-cursor-frozen152-private-fixture.json'
python -m pytest tests/test_bookdata_corpus_private_import.py tests/test_bookdata_author_compatibility.py tests/test_textbook_import.py tests/test_public_textbooks.py tests/test_tutor_graph_context.py tests/test_graph_math_security.py tests/test_graph_observation_cursor.py tests/test_square_root_number_line.py -q
flutter test --no-pub --packages=.dart_tool/graph-staged-packages.json test/bookdata_corpus_roundtrip_test.dart test/graph_parameter_observation_test.dart test/jsx_graph_html_security_test.dart test/graph_observation_renderer_test.dart test/book_square_root_number_line_test.dart test/bookdata_author_compatibility_test.dart
```

Freeze the expanded corpus with `bookdata-cursor-frozen152-manifest.json`; it is a compatibility manifest, **not** a publication approval. Private fixture stays in ignored `build/temp`, never web assets/Git/deployment.

## Responsibility / variable reference

| Symbol | Input/output and responsibility | State / failure |
| --- | --- | --- |
| `migrate_observation_sliders(book)` | Prepared copy → exact-path/original-parameter migration records; expressions unchanged | Mutates only the copied book; collision rejects; never sets review/rights flags |
| `AiFlowGraphParameter.role` | Optional API/source string, default `coefficient`; `observationX` retained through `copyWith`/JSON | Document lifetime; importer/observed-value validators restrict role and count |
| `observationPoint(settings, evaluator)` | Selected runtime x + unchanged evaluator → finite `{x,y}` or null | Pure observation, shared JSXGraph/canvas; no evaluation of author JS |
| `updateObservationReadout(payload)` | Enabled function metadata → text-only accessible coordinate readout | DOM `textContent`, never HTML injection; unknown point reports undefined |
| `BookSquareRootNumberLineView._n` | Local integer 1..25, slider input; `sqrt(n)` computes marker/readout | Widget memory only; no database or grading writes |
| `audit(root, baseline)` | Optional prior path/hash manifest freezes exact inputs, excluding newly added siblings | Hash drift blocks; source is read only; output is compatibility evidence only |

## Publication and operational boundary

- No real author manuscript uploaded in Preview. Synthetic generic polynomials and root activity only.
- No product API, DB secret, provider call, pricing or ownership mutation, author-content publication, or production alias promotion.
- Rights/content review remain unestablished unless a separate explicit publication manifest supplies that evidence. Passing 152 imports is not permission to publish them.
- Full HTML layout parity, physical mobile/native execution and real PostgreSQL concurrency remain separate work; do not infer them from this checkpoint.

## Browser checkpoint and visual repair

- Initial Preview (`dpl_7sfTMbCL1QF91iiGbXBpx4ucxGRA`) browser bundle HTTP 200 / 5,746,751 bytes / SHA-256 `31E19204A05CBA1D7BBD232C0451E46C374B58F658A80D49D3A61EE9B37FB4E9` matched the local build.
- Mobile cubic observation: actual slider keyboard input -1 → -.9 → -.8, readout 2 → 1.971 → 1.888. DOM SVG path data was identical before/after -.9 → -.8; point ellipse coordinates moved from `(99.2,75.594...)` to `(102.4,76.635...)`.
- Mobile quadratic/derivative: actual click selected x=2, showing f(x)=-1 and f′(x)=0.
- Legacy coefficient regression: actual click a=1 → 2 changed SVG curve path data, unlike the observation-only cursor. The roles are not conflated.
- Root activity: actual keyboard input n=1 → 2 changed √n from 1 to ≈1.414 and moved the number-line marker. Initial native range semantics exposed default 50 before focus. A numeric formatter alone **did not fix** that browser-observed issue; it is not attributed to prose formatting as a proven cause. Final workaround excludes the misleading inner slider semantics/focus and supplies bounded, labelled 44px −/+ buttons with a live n/root readout. Pointer users keep the visual slider. Revalidation of the buttons, initial value and endpoint is required; prior iterations are not accepted accessibility evidence.
- Independent visual inspection found overlapping inline function names and a root slider value popup covering the permanent readout. Final repair moves function descriptions to an external wrapping, one-function-per-line legend and removes the redundant popup. No formula or label is discarded.
- Approved HTML SHA-256 remains `EF8F6E40D01B099631C1940628E623A6113E1ADA68CFF3DEC0F1F89DEFCD0868`. Its graph tool was actually opened; the quadratic/line example populated `x^2-1` and `2*x-1`, and typing `x^2-4` returned to “탐색 중”. Captures are stored alongside Preview evidence. That HTML tool has no observation cursor or root-number-line activity; it is a behavior baseline, not an invented 1:1 pixel reference for these extensions.
- A native keyboard attempt on the quadratic iframe twice failed to deliver the key; current DOM focus/geometry was inspected and actual range click succeeded. No page state was injected or UI test bypassed.

## Accepted bounded Preview result

- Source pushed: `92df7349dd7f591ef46e9dcdd88dbd0b8f6d9f7e` (includes `35da8e9` contracts and `6b406f3` legends). Exact index snapshot: **296 library files** match this commit, with line endings normalized; no unrelated dirty source included.
- Final source-closure archive (library files, synthetic entry and package routing; not a fully pinned environment): `build/temp/bookdata-cursor-accessible-source.tar`, SHA-256 `F552E11BDC54BC6D216AE9D6D4861A6C4BB45A4680BD1E5BB8DD9615BAF63928`.
- Final D: release build succeeded in **61.2 seconds**; temporary package config restored byte-for-byte. Existing CupertinoIcons font warning remains; no font redistribution was added.
- Python **60 passed**; final Flutter **11 passed** with the frozen 152-book fixture; four-file focused analyze **no issues**. These are scoped checks, not all-project analyze/test completion.
- Final [synthetic Preview](https://aiflow-web-canary-7j7zn7yie-cw20208021-9200s-projects.vercel.app/): deployment `dpl_7yhbxbU9MbNDwFnuGbjzKaYKSXMj`, target Preview, 69 allowlisted static files. No author manuscript, API backend, private fixture or source archive uploaded.
- Browser-observed `main.dart.js`: HTTP **200**, **5,747,926 bytes**, SHA-256 `6BEC002AB669EA98A0CDF721BE3F53F2C5C841A6B490E477C60E8BEF67DB0993`, exactly matching D: build.
- Final computer-use checks: initial n=1 exposes a disabled decrease button and enabled increase button, no native range/default 50; Enter on increase gives n=2, √2≈1.414; 23 further real clicks reach n=25 and disable increase. A real pointer click on the visible slider selects n=13, √13≈3.606. Desktop Enter also gives n=2. DOM measurements confirm both adjustment buttons are **44×44 logical px**.
- Final quadratic range click gives x=2 with f(x)=-1 and derivative 0. Function legend is outside the plot. Independent visual review of the final 390×844 and 1280×900 captures found no remaining overlap/clipping in this bounded component; root values 1/2/13/25 and endpoint point at 5 remain visible. PNG review is not the evidence for keyboard/a11y actions; the recorded browser actions are.
- Evidence: `evidence/2026-10-17-graph-cursor/final-*.png` is the final accepted set. Earlier files in the folder are explicitly historical/rejected iterations, not final parity proofs. `html-graph-*.png` documents the separate approved graph-tool behavior baseline.
- Last read-only production alias check remains `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`; no promotion. Actual product DB writes, provider calls, author-content publications and price/ownership changes: **0**.
- Remaining beyond this checkpoint: new 153rd draft expression error, full HTML parity, native-device execution, actual DB load/integrity testing, and explicit publication eligibility. The two original reserved-x source collisions and the new square-root activity importer/reader mismatch are resolved for the frozen 152-file set.
