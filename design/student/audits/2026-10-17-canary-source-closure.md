# Canary source closure — read-only investigation

## Verified live artifact and deployment path

- Guarded checkout: D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix, hotfix at `7cd43f22be2d920818d8bf60fee6a0d4b144523a`.
- Canonical alias resolves to `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`, production/READY, unique URL `aiflow-web-canary-hvv457edo-cw20208021-9200s-projects.vercel.app`.
- Actual live JS:7,133,766 bytes, SHA-256 `7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`. `git show 60565564b4ce58d33cc74bdd1daabe90eb349e50:public/main.dart.js` matches exactly.
- Current checkout AND HEAD public JS: `DA4910F2C02651760008559AE811B3B4AEB7780BF5090136404C975FC447F849`. Its latest artifact commit is `36e48ffd5bae7d162ab23b2d6ee9e71d706b5dd2` (2026-10-16 22:53 KST), later than6056556 (16:30 KST). It is a different, unpromoted artifact, not evidence of an older build. Correct earlier shorthand calling it an older bundle.
- Actual Vercel GET project response: project `prj_afZeXnKZMYbAOFH9G50YcCjImvCq`, framework/buildCommand/outputDirectory/rootDirectory/link all null. Actual deployment gitSource and git metadata fields also null. No linked Git checkout or automatic Flutter build is established by this metadata.
- Root `.vercelignore` excludes lib/web/assets/pubspec/build; explicitly includes public/**. Root vercel.json serves uploaded static files and routes product API paths to api/index.py. This release uploads prebuilt Flutter assets and API source, not the Dart source tree. A Git push alone does not update the service.

## Preserved source and scope classification

Known live-build source archive `build/temp/bookdata-encoding-source-snapshot.tar`:21,381,632 bytes, SHA-256 `1D2B137C4D8B8B730E88CD2EDA2B1E431642714DBA8593CB024AA2959DD10095`,303 regular files. Hash matches the original release record. No env file or private manuscript payload was extracted/uploaded. Source extraction remains ignored under D: build/temp.

All five archived API source files' raw SHA-1 values match the actual Vercel deployment-file UIDs: api/__init__.py, content_admin.py, index.py, question_bank.py, textbook_import.py. This is a source-content comparison, not merely a matching filename. Current .python-version, .vercelignore, pyproject.toml, requirements.txt and vercel.json also match actual deployed UIDs, as do all eight existing deployed data/content inputs. The four additional local data/content files are README.md and three leveltest-expanded-v1 files; existing ignore rules exclude them. Do not turn a future release into a broad content upload or a publication approval.

| Source relation | Count | Meaning |
| --- | ---: | --- |
| Archive differs from current HEAD | 101 | Clean HEAD does not contain the full live source baseline |
| Archive differs from actual working source | 15 | Existing live UI source is mostly still in the D: worktree |
| Working source equals archive, but differs from HEAD | 86 | Baseline candidates only; no staging/commit performed |
| Of the15, working source already equals HEAD | 10 | Reviewed post-release changes already committed |
| Of the15, working source also differs from HEAD | 5 | Mixed live integration and newer local changes require separate review |

The86 baseline candidates are77 modified tracked files and9 untracked files. Categories:3 direct textbook integration,22 shared/runtime dependencies,59 other live student feature files,2 pubspec/lock build-contract files. They are not86 new textbook changes. All equal the preserved live snapshot after CRLF normalization; raw/normalized equality and both SHA-256 values are recorded separately.

Full metadata-only path/status/size/hash/diffstat list: [canary-source-baseline-candidates.json](canary-source-baseline-candidates.json). Diffstats are against current HEAD, not against the live app. Total preexisting dirty status entries:1,250, including these86. Other edits, deleted legacy files, untracked content and files outside this list remain untouched.

### Three direct textbook baseline files

| Path | Current responsibility | Working diff versus live snapshot | Working diff versus HEAD |
| --- | --- | --- | --- |
| lib/features/textbook/textbook.dart | Restricts the exported bookbag entry to BookWidget; exports buildbox/concept-tag entry points | 0; raw SHA-256 identical | +1/-1 |
| lib/sessions/textbook/ui/pages/docx_box.dart | Bookbag, owned exams, bookmarks, private import and reader navigation | 0; raw SHA-256 identical | +1271/-638 |
| lib/sessions/textbook/ui/pages/bookbag_details_page.dart | Bookbag material details, textbook/exam/bookmark kinds, filtering and material sheet | 0; raw SHA-256 identical | Untracked,972 lines |

All three have no committed diff in6056556..current HEAD. They are already-live baseline integration, not the new function explorer/graph/tutor changes. The actual reader book_page.dart is instead one of the five mixed files below. Keeping only these three while building old HEAD routes/shared/auth/UI would not preserve the live app. The other83 include other student features, shared dependencies and build contracts; their mere presence in the archive does not prove each is a compiler dependency. Baseline rebuild and dependency evidence must distinguish required build inputs from preservation context before choosing a minimum release source set.

Measured baseline web dependency list:73 of86 files were compiler inputs (including the physically identical main.dart entry), plus pubspec.yaml and pubspec.lock are build inputs:75 candidates for this specific web/canary-demo-on configuration. The other11 Dart files were not observed in this web compiler dependency list and must not be automatically included merely to empty git status. This is not a universal minimum for native builds, demo-off or other flag configurations. Direct bookbag inputs docx_box.dart and bookbag_details_page.dart were consumed; features/textbook/textbook.dart was not.

## Five mixed files — no automatic merge or overwrite

Read-only three-way experiment: base=6056556 source, ours=current HEAD, theirs=preserved live source. No index/worktree writes.

| File | Conflict regions | Actual working diff vs live snapshot (+/- lines) |
| --- | ---: | ---: |
| api_client.dart | 11 | 62/4 |
| textbook_store.dart | 1 | 28/2 |
| book_page.dart | 3 | 103/22 |
| marketplace_page.dart | 0, but merged bytes do not match working source | 13/2 |
| server_chat_page.dart | 12 | 48/12 |

The large HEAD diffs include preexisting live integration. Comparing against the live snapshot narrows the real post-release changes. Blindly choosing HEAD, the entire worktree, or one side of a merge is not a verified release path. A new untracked public_textbooks_page.dart also belongs to the newer integration and must not be mistaken for a live-baseline file.

## Reproduction experiment and next release gate

- Extracted the verified303 source files to an immutable D: build/temp baseline. Current main.dart, pubspec.yaml/lock and all current assets/web files match that baseline. Existing user source was not replaced.
- First baseline reproduction build failed in Flutter native-assets package-root detection, not in application compilation. Original generated package config was restored byte-for-byte. Added the same checkout-root alias used by the already verified isolated build harness; second build succeeded in111.3s but its7,133,766-byte JS hash was `822AF47B949059E3008B6FC94A4AA637843A684156A2D2780E282AA4E43C8EBF`, not live7F54. Byte size alone is not parity proof. That run selected the physical checkout main entry while imports used the archived package root.
- Repeating with the archived package's own main entry succeeded in103.7s and reproduced **every JS byte**:7,133,766 bytes, SHA-256 **`7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`**. End-of-investigation normal alias response still matches. Entry identity matters to this isolated build recipe; do not substitute the alias-root main entry. No app source file was overwritten, and generated package config was restored byte-for-byte.
- Actual deployment-file comparison:66/68 uploaded public files match raw rebuilt bytes. Two explicit exceptions are .last_build_id and flutter_bootstrap.js. Flutter SDK build_system.dart805-809 writes the former from the output build-directory ID. In the latter, direct comparison found only the generated service-worker nonce (2369212807 vs1096971131) and an empty build descriptor present in the original dry-run-enabled build. SDK targets/web.dart737-742 explicitly generates the nonce with Random, not a content hash. Parsing the JSON build config, removing only empty descriptors, and normalizing only that numeric nonce makes the entire bootstrap equal. This was comparison only: neither output was edited. All active dart2js build descriptors and the service-worker file itself match. Do not describe all68 files as raw byte-identical.
- Toolchain recorded for the original release: Flutter3.44.6, Dart3.12.2, framework ee80f08bbf, engine83675ed276. Build defines: API_BASE_URL=https://aiflow-web-canary.vercel.app, STUDENT_SERVICES_DEMO=true, STUDENT_STORE_DEMO=true; release/no-pub. Reproduction disables the wasm dry run only; it does not change the deployed app/backend.
- Reproduction proof: [canary-source-reproduction-proof.json](canary-source-reproduction-proof.json). Existing live baseline is recoverable and reproducible at runtime-code level; this does not make the current Git HEAD a clean, complete app source. The original code archive is local/ignored, not a source commit.
- Safe path: confirm baseline reproduction; separately review the86 exact-live baseline candidates and five mixed-file integrations; capture required deletions/new dependencies explicitly; build pinned hotfix source; run focused contracts and full-app Preview UI checks; compare static/API manifests; only then consider the product alias. Preserve review/private content gates and an exact rollback artifact.
- The user selected Preview first and canary only after consistency verification. An additional question about recording the86 baseline files is pending; no baseline source was staged, committed or pushed. No new deployment, alias update, DB write, credential change or manuscript publication occurred in this investigation.

Next bounded task: decide the75 observed web baseline inputs (not an automatic86-file commit), review the five mixed-file deltas against the live snapshot, and pin their required new files/deletions explicitly. The existing D: worktree remains untouched while that decision is pending. A different chat's/new branch's API proposal is not part of this source baseline and has not been imported or validated here.

Subsequent read-only preflight pinned the proposed input hashes but found a reproducible pre-write account-transition regression in the newer working createTextbook wrapper. The same diagnostic passes on the verified live source. No source baseline was staged and no new app/API candidate was deployed. See [2026-10-17-canary-review-preflight.md](2026-10-17-canary-review-preflight.md); prior baseline reproduction remains valid and must not be confused with latest-feature release approval.

This report proves artifact lineage and live runtime-code reproduction while identifying the remaining source-integration gap. It does not establish whole-app security,200-session capacity, clean-HEAD reproducibility, latest-feature canary deployment or commercial readiness.
