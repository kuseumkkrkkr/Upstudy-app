# BookData author compatibility checkpoint — 2026-10-17

## Scope and approval boundary

- Worktree: `D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix`, branch `hotfix`.
- Source folder was read only: `D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-app\docs\advanced-generation-vault\07 Data\교재 원고`.
- Earlier 143-file audit is historical. The current snapshot contains 150 matching BookData JSON files. No frozen complete 143-file manifest exists in that earlier report; do not claim an identical source set.
- No content review, copyright clearance or publication approval is inferred from compatibility. No manuscript is bundled in Preview. No prices, ownership, database records or production aliases were changed in this checkpoint.

## Implemented compatibility

- Preserve `standard` block type in Python validation and Dart serialization/rendering, rather than reject it or fall back to a paragraph identity.
- Accept at most 64 tags (80 characters each), retaining all 48 tags in the combined 2015 draft. Source size remains capped at 512 KiB.
- Support four-labelled-piece `area-model`: formula, piece labels and caption remain visible. It is explicitly a schematic, not a length-proportional geometry proof. No author dimensions are invented.
- Author preparation upgrades only an omitted schema declaration when registered V2 activities exist. An explicit V1 still fails; unknown activities still fail. The migration is recorded in source metadata and can be reversed exactly.
- Original Markdown/JSON files are never rewritten. Existing author annotations, including pending review, remain metadata rather than becoming approval.

## Verification and remaining blockers

- Python focused tests: 32 passed (one existing Starlette/httpx deprecation warning).
- Python private audit: 150 inspected, 148 exact author reconstructions passed, 2 blocked.
- Dart model corpus test: all 148 passing runtime books preserved their supplied fields through native `BookData.fromJson` → `toCreateJson`, then a second stable round-trip. This is not visual review of every page.
- Reader source changes are selectively staged over HEAD; the large unrelated working-reader diff is preserved and excluded.
- Initial synthetic release build succeeded (61.9 seconds). Initial independent screenshot review found the long formula's final term clipped on mobile. That iteration is not accepted as final; horizontal formula access was added for revalidation.

Remaining source files:

| File | Exact failure | Why not silently accepted |
| --- | --- | --- |
| `미적분Ⅰ_극대극소와그래프개형_BookData_시범.json` | `graph.parameter: invalid or duplicate identifier` | The slider id is `x`, reserved for the independent graph coordinate. `safe_graph_math.dart` evaluates `x` from the plotted coordinate, not the parameter map; accepting it would expose a slider that does not drive the intended observation. |
| `수학Ⅱ_도함수부호와증감_BookData_시범.json` | Same | The same `x` collision occurs in both section and page graphs. Do not drop the slider, rewrite expressions to a constant curve, or merely weaken reserved-name validation. A separately modelled observation cursor is not implemented in this checkpoint. |

The previously reported malformed quiz file has changed in the author folder and now passes; do not attribute its author-side repair to this importer patch. Four newly added V2 activity files omitted a schema version and pass through the recorded missing-version migration.

## Reproduction

Run the D: worktree guard in the same PowerShell shell first.

```powershell
python -m pytest tests/test_bookdata_author_compatibility.py tests/test_textbook_import.py tests/test_public_textbooks.py -q
python -m tools.audit_bookdata_roundtrip '<author folder above>' --report build/temp/bookdata-roundtrip-audit.json --private-fixture build/temp/bookdata-private-fixture.json
$env:BOOKDATA_PRIVATE_FIXTURE = '<D: worktree>/build/temp/bookdata-private-fixture.json'
flutter test --no-pub --packages=.dart_tool/graph-staged-packages.json test/bookdata_author_compatibility_test.dart test/bookdata_corpus_roundtrip_test.dart
```

The audit intentionally exits 1 with blockers while writing their exact evidence. Private fixture stays in ignored `build/temp`; never copy it to web assets, Git or a deployment.

## Responsibility / variable reference

| Symbol | Responsibility, inputs and output | Side effects / failure |
| --- | --- | --- |
| `prepare(source)` schema migration | Missing version + explicit registered activity → validated V2 runtime; annotation records the omitted declaration | Copies input; explicit invalid version/activity rejects; no publication |
| `audit(root)` | Read matching author files, reconstruct author JSON from runtime plus annotations, return per-file hashes/status and private runtime fixture | Reads only source; detects source changes; errors remain blocked records |
| `BookAreaModelPieces.labels` | Exactly four author labels, row-major reading order; widget-lifetime immutable input | Renders schematic; wrong count shows an explicit message, not partial pieces |
| Corpus `preserved(before, after, location)` | Recursively require all supplied content fields/list order; allow omitted empty optional defaults | Test-only assertion includes file/field path; never changes expected source |
| `BOOKDATA_PRIVATE_FIXTURE` | Local path to private audit fixture for opt-in corpus test | Not compiled into Preview; absent value skips only the local corpus test explicitly |

## Next bounded work

1. Model a separate observation cursor for the two `x` collision documents, with explicit migration, reconstruction tests and actual slider/curve browser checks. Keep the reserved variable protections.
2. Keep tutorial/tutor common-shell rail and bottom-navigation differences open; the earlier standalone body restyle did not prove full HTML parity.
3. Only a separately approved, hash-frozen publication manifest can produce a release bundle. Current eligible publication count remains unestablished; no production content deployment is claimed.

## Final bounded Preview checkpoint

- Source commits pushed to `origin/hotfix`: `01e02ebbc5bc2e9e7e4421fd76aecb7ebd88410a` (compatibility) and `d62084ebd6c2dbd6eb8b58cd986effaf3b68aac6` (mobile formula scroll and regression test).
- Focused Flutter tests: **4 passed**, including all 148 private runtime books and an actual positive horizontal scroll offset in the reader. Focused analyze: **no issues**. Neither replaces full-app testing or 150-book visual review.
- Exact staged-source release build succeeded in **93.9 seconds**. All **295** exported `lib` files matched the final source commit, line endings normalized. The temporary package configuration was restored byte-for-byte after the build.
- Source closure archive (295 library files + synthetic entry + package routing, not a complete pinned environment): `build/temp/bookdata-compatibility-source.tar`, SHA-256 `0132895E3A534B2063C2A14635C35CD2C892FC93B2B1BE4065A0ED4A2FC5B4C3`.
- Final independent Preview: [synthetic reader](https://aiflow-web-canary-je7trn7h5-cw20208021-9200s-projects.vercel.app/), deployment `dpl_AjJRV2ktg99kMnx5mTafTKhEZJp1`. Static file allowlist: **69** files; no API/data sources, author fixture, Dart source, credentials or source archive uploaded.
- `main.dart.js`: **5,738,960 bytes**, SHA-256 `709D7910D84B4F9E32F84251CA01A90DD61974BD80414B913C5D5370D70216B2`. Browser-observed HTTP **200**, identical size/hash.
- Computer-use: opened the Preview, enabled accessibility with keyboard, inspected the named formula group, scrolled its real mobile area horizontally, then captured 390×844 and 1280×900. Temporary viewport and cache overrides were restored.
- Independent visual reviewer confirmed: mobile end capture exposes the final `+ ab`; desktop shows the complete formula; all four labels, learning criterion and captions remain readable. Initial mobile capture remains scrollable rather than shrinking type. This is not full HTML parity.
- Evidence under `evidence/2026-10-17-bookdata-compatibility/`: `preview-390.png` is the rejected first iteration; `preview-final-390.png`, `preview-final-formula-end-390.png` and `preview-final-1280.png` are the accepted bounded component check.
- Production alias read-only recheck: `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`, unchanged. No promotion performed. Actual AI calls **0**, DB writes **0**, publication bundles **0** in this checkpoint.
- The existing CupertinoIcons font warning remains in the build log; no new font assets were copied or licensed rights assumed.
