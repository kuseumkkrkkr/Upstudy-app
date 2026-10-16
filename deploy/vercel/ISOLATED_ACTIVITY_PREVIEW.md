# Isolated activity Preview — intermediate proof only

## Exact scope

Synthetic mean/proportion/dice activities using the committed native renderer.
No actual manuscript, BookWidget, product router, auth, API, learner database,
grading or OVR. This does **not** complete student-app integration or final release.
Visible UI says synthetic QA, not the student app/real textbook, no server save.

## Source, build and artifact

- Guarded D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix, hotfix only.
  Source checkpoint `aaf65ac3c3a70f0321ccb5ca66799930484686ac`, pushed.
- Isolated test1 passed, scoped analyze2:0. Initial lazy-footer NoElement was
  fixed by fixed navigation; unused test import warning was removed, then rerun.
- `flutter build web --release --no-pub --no-wasm-dry-run --no-web-resources-cdn --target=tool/book_activity_isolated_preview.dart --output=build/native-statistics-preview`
  passed39.0s, Flutter3.44.6/Dart3.12.2. Existing Cupertino font warning remains.
- main.dart.js2628909 bytes, local and authenticated-browser response SHA256
  **FD8BFEF7E5846D21BBDF684ABC68DD6535F31A0F34B87F0ED1AB24E7C0417291**.
- Dart2JS depfile `.dart_tool/flutter_build/3559090f54268a6ba1032cafbe90aecb/dart2js.d`
  contains exactly7 application Dart files: entrypoint,3 models,3 widget files.
  All match HEAD. `tool/verify_isolated_activity_bundle.py` asserts this closure;
  `design/student/audits/isolated-activity-source-proof.json` records Git blobs.
  No teacher-reader/exam/API/actual BookWidget app source is in the closure.
- Whole checkout and project dependency configuration are NOT clean. The unrelated
  pubspec/lock delta removes unused web_socket/channel; source-closure verification
  is narrower than clean full-project reproducibility. Never call this a clean
  student-product build or promote it. Existing dirty files were not overwritten.
- Generated static output copied into ignored build/temp/isolated-activity-deploy.
  Dry-run69files: no API/env/private defines/DB/manuscript. Runtime library assets
  and license notices remain; no original HTML/BookData manuscript shipped.
  Product public/ and its bundle were NOT replaced.

## Actual deployment and browser

- Preview READY **dpl_9qgMeVi3y2vH4ShEAapeUiXhXEbN**:
  https://aiflow-web-canary-r5ob0dtfh-cw20208021-9200s-projects.vercel.app
- Standard `vercel deploy build/temp/isolated-activity-deploy --project prj_afZeXnKZMYbAOFH9G50YcCjImvCq --scope cw20208021-9200s-projects --yes --format=json`.
  No --prod/promote/domain commands. Deployment API confirms target=null,
  aliases=[], meta.featureSource=aaf65ac3..., previewKind=isolated-synthetic-activity.
- Real browser entered4,8,12 ->8.0000, revealed hint; navigated proportion3/10
  ->30.00%, dice10 draws ->6/10=.600, counts1/3/3/1/0/2. Returned through previous
  activities; mean input/result/hint retained and survived390x844 ->1280x900.
  New local session changed0->1 and cleared values/result/hint to defaults.
  Console error log0 in that run. This is not live student auth/persistence QA.
- Observed48 network requests:0 product API requests. Origins were this static
  Preview, vercel.live toolbar, fonts.gstatic.com fallback fonts. No offline-only
  or zero-network claim; no student/secret data entered.
- Captures in `design/student/audits/evidence/2026-10-16-book-activity-capabilities/`:
  isolated-preview-mean-390.png, isolated-preview-proportion-390.png,
  isolated-preview-dice-390.png, isolated-preview-mean-1280.png,
  isolated-preview-reset-1280.png.

## Canonical unchanged, real product blocker retained

Before and after, canonical aiflow-web-canary.vercel.app and generated secondary
aiflow-web-canary-cw20208021-9200s-projects.vercel.app both point to the prior
aiflow-web-canary-hvv457edo-cw20208021-9200s-projects.vercel.app
(dpl_HTYscDjA8dNT521Pjf91UeqJsaF2). Canonical JS7133766 bytes SHA256
7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8.
No aliases, student records, content catalogue or DB were changed.

Actual product prerequisites remain distinct:

1. Committed ApiClient.sessionChanges is missing; required by reader account-
   change cleanup. The dirty API includes a broader auth/session persistence
   implementation plus unrelated social/grading changes; do not mass-stage it.
2. BookWidget.bookLoader is a missing test seam, not a production network API.
   The default production loader should retain real TextbookStore ownership.
3. Committed createTextbook deliberately throws501 textbook_create_unavailable;
   getTextbook GET is connected. Current dirty TextbookStore/API add actual
   create/import and per-session cache contracts. Those need separate review/tests.
4. Clean reader imports pull server_chat/exam libraries whose committed mixins
   reference missing _focusedQuestionIndex/_focusedExamQuestionKey/
   _examQuestionsMarkedForReview/_timerVisible. These are unrelated exam source
   dependencies; do not fix by copying broad dirty files into a feature commit.
5. Clean archive tests fail before running (two files). The root-CWD Flutter
   package override affects native-assets/test but web Dart2JS hardcodes root
   package_config (SDK targets/web.dart196); depfile proved a seemingly successful
   archive app build used dirty sources. It is not a clean-release workaround.

Exact failing reader command (guarded root, archive79af and local package config
prepared as documented in BOOK_ACTIVITY_EXPERIMENT_RELEASE.md):

```powershell
& .\tools\verify-hotfix-worktree.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter --packages=build/temp/clean-79af/package_config.root-mapped.json test --concurrency=1 --no-pub build/temp/clean-79af/test/book_discrete_experiment_test.dart build/temp/clean-79af/test/book_activity_v2_test.dart
```

Diagnostic-only web command, which must NOT be mistaken for clean output:

```powershell
flutter --packages=build/temp/clean-79af/package_config.root-mapped.json build web --release --no-pub --no-wasm-dry-run --target=build/temp/clean-79af/lib/main.dart --output=build/clean-79af-web --dart-define=API_BASE_URL=https://aiflow-web-canary.vercel.app --dart-define=STUDENT_SERVICES_DEMO=true --dart-define=STUDENT_STORE_DEMO=true
```

Archive source is immutable git79af; original dirty lib/package config was not
overwritten. The second command's app.dep/dart2js.d reveals root source paths;
the test command reports archived source locations and the missing contracts.
Smallest next prerequisite: owner-reviewed commits for the necessary reader/auth/
store and exam-library contract dependencies, plus a guard-compliant full-product
build whose complete application-source closure matches those commits. Then real
product Preview auth/import/BookWidget verification before any canonical promotion.
This intermediate static result does not remove that active blocker or complete
the original goal. Required teacher/rights gates remain for manuscript publication.
