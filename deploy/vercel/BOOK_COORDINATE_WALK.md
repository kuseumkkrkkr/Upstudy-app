# BookData V2 coordinateWalk — explicit swap/playback kind

## Source checked, not executed or published

Entire original `중학교수학_2015개정_순서쌍과좌표_체험형.html` read; inventory
`html-7bbc2e50f5387d53` file SHA256 rechecked:
`FFF800DF2A8542E610A9D2DE1CC2CCBB041EF72EFD793829FEB1718C8DB0DE40`.
Initial target(-3,2), integer x/y-5..5, point drag/arrow keys, swap(x,y), reset,
blue horizontal/orange vertical dashed route and Element.animate1500ms
ease-in-out from origin ->(x,0) at offset.5 ->(x,y). Source reduced-motion uses1ms.
The static timed_callbacks signal is false because this is Web Animations API,
not setTimeout/setInterval; it must not be interpreted as no animation.

Source has no pause or concurrent-animation cancellation; native adds pause,
single controller, target-edit cancellation, offscreen/background suspension and
non-autoplay restore. Reduced motion reaches the target immediately with route
and text equivalent, rather than scheduling even a1ms animated frame.
Source's independent quiz/hint/exercise still need explicit reviewed companion
blocks. Inventory status stays source_review_required_not_ported, all106 assets
retained; this is not manuscript approval or full appearance/behavior parity.

## Contract / migration

```json
{"type":"activity","activity":{
 "id":"coordinate-walk","kind":"coordinateWalk","prompt":"목표점으로 이동해 보세요.",
 "x":-3,"y":2,"duration_ms":1500,"hints":["가로 이동 뒤 세로로 이동합니다."]
}}
```

- New explicit registered kind in schema_version2, not a hidden coordinatePoint
  flag. JSON schema `book_coordinate_walk.schema.json`, Python and Dart validators
  require integer tokens x,y-5..5 and exact1500ms. Unknown fields, imported timers/
  progress/running state, callbacks, HTML, JSX, arbitrary easing/durations rejected.
- Existing coordinatePoint JSON/canonical optional defaults and graph types keep
  their prior parse/serialize behavior. coordinatePoint rejects duration_ms.
- No executable author source or new transport endpoint. Import validation runs
  before persistence, owner/source-SHA idempotency contract unchanged. V1 activity
  rejection and old-reader unknown-kind rejection are retained; never flatten.
- Both compatible API validator and renderer must be deployed before real new-
  kind import. No actual manuscript migration/import/publication in this batch.

## Runtime behavior and responsibility/state index

| Name | Input/result/lifetime |
|---|---|
| walkDurationMs | Validated author constant1500; no user timer overrides |
| _walk/_configureWalk | At most one owned Flutter AnimationController per walk widget; no Timer/JS callback |
| _toggleWalk | Start/resume or pause; zero-delay vertical-only scroll, guarded post-frame forward |
| _startEpoch/_pendingStart | Cancels stale pending starts on repeated click/pause/edit/reset/deactivate/dispose |
| _displayPoint | Curves.easeInOut time ->horizontal then vertical offset; target remains immutable definition/current user target |
| _stopWalk/_changePoint | Stop current playback, invalidate pending starts; target edit/swap clears old route/progress |
| _plotVisible/_tick | Stop when plot leaves viewport, repaint bounded native scene; no network or storage |
| didChangeDependencies | Stop on TickerMode/route hiding; reduced motion stops ticking and reaches target |
| lifecycle/deactivate/dispose | Suspend or dispose ticker; resume never implicitly autoplays |
| walk_visible/walk_progress | Reader-local definition-fingerprinted snapshot; remount restores paused position, never running callback |

Play/pause/swap/reset are above the plot so mobile users can see controls and
motion together. Target point remains keyboard/drag adjustable; editing interrupts
old playback. Current fractional moving position is separate from target/axis/
quadrant text. Dashed route is native drawing. Reset returns authored target,
progress0/no path/no hints. Reduced-motion enabled during playback completes
without a lingering ticker. No autoplay, external requests, exam score/OVR write
or disk/server activity persistence.

## Verification and remaining source families

New backend15 tests: strict fixed duration/coordinate types, forbidden code/state,
schema and lossless old coordinatePoint/new walk import. Focused backend total130
passed (existing Starlette/httpx warning1). New Flutter4 tests cover distinct
kind round-trip, pause/resume and absent-frame pause restore,1500ms completion,
swap/reset/arrow controls, reduced-motion initial and mid-play, duplicate start
epoch cancellation, hidden ticker and disposal without transient callbacks.
Golden is paused play at20% with existing NotoSansKR. Full regression/Preview
results are recorded below when actually run; source manuscript is not deployed.

Next boundaries: cartesian_point_drag now has grid point plus explicit bounded
walk/swap; general curve constraints remain. parameter_dependent_metrics remains
rightTriangle only; vector_transformations awaits the reviewed2u/-2u correction;
conics_3d_distance remains elementary parabola only. set_relation_diagrams,
algebra_area_partitions, calculus_scenes are unimplemented. timed_statistical_
trajectories is NOT solved by this coordinate walk: probability curves/playback
need a separate contract. adaptive_socratic_sequences still requires reviewed
branching/provider behavior, not static quiz/steps. All106 whole-asset migrations
and author/teacher/rights gates remain distinct from these reusable8 kinds.

## Browser Preview verification

2026-10-17 (Asia/Seoul), committed implementation `4855c1dfd18ac5a71ca7ad6f22ab0a8fa5f1f9c9`:

- Vercel deployment `dpl_8BsKJ29CiQ5MD7YbNviZ6RGYRxCy`, target `preview`, status `Ready`, no production promotion requested. URL: <https://aiflow-web-canary-jgbuxrwhg-cw20208021-9200s-projects.vercel.app>.
- Opened the protected Preview in the authenticated in-app browser. Screenshot checked the actual BookWidget page. Clicked `이동 시작` and observed the moving point and dashed L path; clicked `좌표 순서 바꾸기` and observed (-3,2) change to (2,-3); clicked `처음 위치로` and observed (-3,2) restored. Unit tests additionally cover pause/resume, reduced motion, remount, visibility and lifecycle cleanup.
- Browser DevTools `Network.getResponseBody` for the loaded `/main.dart.js` returned 4,983,652 bytes and SHA-256 `5713FF5DF66360210BC6304B16969DD6F3E39F377F37684594BB5262BE25FD73`, equal to the local release build. Unauthenticated PowerShell requests receive Vercel protection HTML; that response is not the app bundle and was not used for comparison.
- This is a synthetic in-memory integration Preview. It has no product import or server persistence, and does not establish teacher/rights review or textbook readiness.
