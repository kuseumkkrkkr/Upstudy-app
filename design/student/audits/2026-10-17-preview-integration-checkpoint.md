# Preview integration checkpoint — 2026-10-17

Production alias is unchanged. The approved order is Preview first, canary only
after source and deployed artifact verification. This is not full parity or
commercial-readiness approval, and does not authorize manuscript publication.

## Source preservation

- `e33c8a9e68077e226617b7e95e48c62508a999e7` pins only the 75 measured
  live-source inputs. See the separate reproduction report for the exact live
  JavaScript match. The earlier pending-approval proposal is historical, not the
  current commit state.
- Five mixed integration files were compared against the immutable live source
  archive rather than treating their entire historical diff as new behavior.
- Native and unsupported LocalDb implementations must implement the same scoped
  interface as the already pinned web implementation. Their narrowly reviewed
  compatibility changes prevent cross-account local-cache access; old unscoped
  records are not migrated to a guessed owner.

## Regressions fixed

| Unit | Contract / lifetime | Verification |
| --- | --- | --- |
| `ApiClient.createTextbook` | Required caller-captured `ApiSessionScope`; forwards it before POST; private creation is not publication | Switching accounts before POST sends no draft request; create contract and late response tests |
| `TextbookStore._stripToLibraryMeta` | Preserves nullable `candidateStandardCodes` without promoting candidates to confirmed codes | null, empty list, nonempty list retained |
| `PublicTextbooksPage._load` | `_loadRequest` invalidates stale catalogue reads; `_epoch` belongs to session/disposal only | Refresh during acquisition no longer strands busy state |
| `PublicTextbooksPage._open` | One pending book at a time; confirmed ownership updates the current row and invalidates older reads | Late catalogue cannot overwrite successful acquisition |

The two catalogue regressions failed before the fix and passed afterward. The
focused catalogue/private-store/create/session suite passed **27 tests**. Scoped
analysis of the catalogue page, native/stub storage, and changed catalogue/create
tests reported **no issues**. These tests use synthetic data and mock transports,
not real DB concurrency or production UI interaction.

The draft race test moved from `tools/qa/canary_create_session_race_test.dart` to
`test/textbook_create_session_race_test.dart` so normal test discovery includes it.
The failure recorded in the earlier preflight remains historical evidence.

Independent read-only review confirmed the catalogue refresh fix; it did not run
the UI. A further reader/tutor/graph/activity/default-origin suite passed **34
tests**, and the explicit empty-base Preview contract passed **1 test**. The
synthetic Python public-book/create/import/tutor suites passed **66 tests** with
one dependency deprecation warning. None is evidence of real-provider delivery.

Reader/chat scoped analysis reported **26 issues** (one unused optional parameter
warning and 25 brace-style infos), with no analyzer errors. It did not pass a
zero-issue gate. Clean-source compilation, Preview API readiness, rendered
interaction, and live bundle verification remain separate pending gates.

## Preview routing

Reuse the existing `--dart-define=API_BASE_URL=` mode for same-origin Preview
frontend/API pairing. Do not point unpromoted API-dependent features at the old
canary API or copy Production-only secrets into Preview. No production alias
promotion is included in this checkpoint.
