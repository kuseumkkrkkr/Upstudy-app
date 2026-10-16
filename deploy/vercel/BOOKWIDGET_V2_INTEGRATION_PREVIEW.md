# Actual BookWidget V2 integration Preview — dirty source, synthetic only

2026-10-17. This is live UI integration evidence, NOT clean-commit release or
production textbook publication. No external manuscript, student data, real
credential, authenticated import, DB write, catalogue deletion or alias change.

## Build and source boundary

- Guarded D: Upstudy-hotfix root, hotfix checkpoint
  `fc7d4eeece54494af0313b8a0985d4069f8a3ee5`; working source deliberately dirty.
- Temporary entry `build/temp/bookwidget_v2_integration_preview.dart` constructs
  synthetic V2 BookData: mean, choice quiz, proportion, explanatory prose.
  Three authored pages paginate into five actual reader pages.
- Uses actual `BookWidget`, not an isolated BookActivity replacement.
  `persistenceEnabled=false`, injected loader returns that synthetic book only.
  Synthetic in-memory identity satisfies the reader's local session scope; it is
  NOT a valid login. ApiClient's injected MockClient rejects product requests
  locally. Reader chat/bookmark/finish are not live-service QA or supported demo
  actions; do not remove those network guards to imply production completion.
- Fixed footer explicitly identifies synthetic QA/uncommitted UI/no server save.
  No BOOK_QA_JSON defines, actual candidate JSON or private manuscript uploaded.
- `flutter analyze --no-pub <entry>`:0 issues. Existing real-reader V2/statistics
  focused widget tests10 passed serially in working source.
- `flutter build web --release --no-pub --no-wasm-dry-run --no-web-resources-cdn
  --target=build/temp/bookwidget_v2_integration_preview.dart
  --output=build/bookwidget-v2-integration-preview`:66.6s, success. Existing
  Cupertino font warning remains; this is not whole-product design certification.
- Dart2JS depfile reports188 application sources,71 modified relative to HEAD,
  including actual BookWidget and temporary entry. Machine evidence
  `design/student/audits/bookwidget-v2-integration-proof.json` lists the closure.
  No private candidate/authoring source path found. Whole checkout is NOT clean.
- Ignored source snapshot `build/temp/bookwidget-v2-integration-source.tar` SHA256
  `97607D24104B9D7F7A5FE7BB81E9A59A0215942B7C818B6B82A31466C94F576C`.
  HEAD alone cannot reproduce this integration build. Snapshot is a checkpoint,
  not an approved source release. `public/` was not replaced.

## Static deployment and actual browser

- READY `dpl_EVUVNQuK8BzD3HeNfrUBibyvUMPQ`:
  https://aiflow-web-canary-qkk76kt2d-cw20208021-9200s-projects.vercel.app
- Standard Preview target=null, alias=[], meta.previewKind=
  dirty-synthetic-bookwidget-v2. No --prod/promote/alias command.
- Dry-run69 files: static bundle+static vercel.json only. No api/, data/, lib/,
  tests, env or Dart source uploaded. Existing public runtime/font assets remain.
- Local output and real authenticated-browser main.dart.js response both
  4,957,831 bytes, SHA256
  `9F81DE2B95EEDCCFDA3703DBEDA328C841FC28DBAA85BA9FCA2AFA16500E007D`.
- Browser network observation after intentional reload:49 requests,0 product API
  routes. Origins: this Preview, vercel.live toolbar, fonts.gstatic.com fallback.
  This is not offline-only or no-network. Observed console error entries0.

| Actual manipulation | Result |
|---|---|
| 390x844 next page to mean; edit2,4,12; estimate; hint |6.0000, sample size3, hint visible |
| Resize390x844 ->1280x900 | Page2/5, input/result/hint retained |
| Page3 quiz: choose2, confirm | Incorrect feedback; no server grading |
| Reveal hint, choose4, confirm | Correct feedback and hint; input selectable |
| Resize1280x900 ->390x844 | Page3/5, choice4/result/hint retained after frame settles |
| Mobile TOC ->proportion | TOC closes, page5/5, back/forward boundaries intact |
| Estimate3/10 and reveal hint |30.00%, correct denominator explanation |
| Resize390x600, actual wheel inside page | Lower warning/hint/disclaimer accessible; navigation remains fixed |
| Enter11 with sample size10; confirm | Actionable error, old30% result removed |
| Resize1280x900; reset then estimate | Returns3/10 ->30%, clears prior error/hint |
| TOC ->mean then next | Prior2,4,12,6.0000 and hint retained after other pages |

Captures in `design/student/audits/evidence/2026-10-16-book-activity-capabilities/`:
`bookwidget-v2-mean-390.png`, `bookwidget-v2-mean-1280.png`,
`bookwidget-v2-quiz-390.png`, `bookwidget-v2-quiz-1280.png`,
`bookwidget-v2-proportion-390.png`, `bookwidget-v2-proportion-1280.png`,
`bookwidget-v2-proportion-short-scroll.png`, `bookwidget-v2-invalid-1280.png`.
They are synthetic integration screenshots, not HTML/Dart parity or deployed
student-content evidence. Temporary device metrics cleared after verification.

## Missing functions / remaining implementation boundary

| Area | Current support | Next scope, not claimed complete |
|---|---|---|
| V2 native activities | quiz, steps, parabolaDistance, discreteExperiment, statisticsEstimator(mean/proportion) | Source-specific scenes must map to validated definitions and be reviewed;106 inventoried HTML assets remain not_ported |
| JSX graph | Existing graph renderer/slider path; separate earlier candidate QA | Native graph metrics, direct point dragging/keyboard, number lines and derived results need explicit schema/renderer; no arbitrary script execution |
| Connected math experiences | Bounded dice counts/local sampling; elementary parabola distances | Vector/conic/3D, sets/relations, algebra areas, calculus, timed probability trajectories and adaptive connected Socratic sequences remain unsupported families |
| Chatbot | Reader has page-context action; earlier working tests cover context | This Preview blocks API calls. Real provider response/Socratic quality not verified here; do not call a static steps block a Socratic chatbot |
| Activity state | Reader-lifetime snapshots survive page/breakpoint remount | No cross-device/disk/server answer persistence; disposal/reload ends this local session |
| Import API | Canonical private import exists V1-only; b310fd1 backend Preview supports V2 validators | V2 backend not promoted; Preview auth/DB environment absent, live authenticated persistence/idempotency gate untested |
| Flutter publishing | Working import adapter exists | Adapter/store/account-bound storage are broader dirty integration; not yet clean committed product closure |
| Product build | Narrow session notifier committed/pushed | Clean reader bookLoader seam and exam field/enum prerequisites, dependency configuration and approved clean root-cwd build path remain unresolved |

Next safe rollout: select a manuscript only after author explicitly supplies
rights/review status and immutable source digest; validate all blocks against the
actual V2 backend/client, reject unsupported scenes rather than flatten silently;
resolve clean integration prerequisites; perform authorized private staged import
and persistence/ownership/idempotency QA before production candidate promotion.
This static Preview must never replace the real student app or canonical alias.

Read-only authoring-thread checkpoint inspection still reports independent
teacher/math review and rights decisions pending. Its14 schema-valid BookData
candidates are not14 production-approved textbooks; no real manuscript was
imported or promoted based on that status.
