# BookData V2 backend Preview — not a production cutover

2026-10-16. No content/student DB writes, imports, deletes or alias changes.

## Actual route and version boundary

- Canonical deployment `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2` already has authenticated
  `POST /textbooks/import`. Its deployed validator accepts V1 only; it has no
  `api/book_activity.py`. Do not infer the private import route is absent from
  Flutter `createTextbook()` deliberately throwing501.
- Frozen hotfix `b310fd112e0b3e1e92f0b571d5ecd586bbe54a76` accepts V2 and the five
  native activities: quiz, steps, parabolaDistance, discreteExperiment,
  statisticsEstimator. Import owner/digest ID, unique insert and persisted-result
  checks remain server-owned. These source checks do not prove live DB storage.
- Flutter `importTextbookSource` and `TextbookStore.importSource` remain broader
  uncommitted integration work. The synthetic client transport test3 passed and
  scoped analyze passed against that working tree, not the clean product source.

## Immutable deployment inputs

Guarded D: hotfix root; Git archive includes only committed `api`, `public`,
`data/content`, `vercel.json`, `.vercelignore`, `requirements.txt`, `.python-version`.
No `.env`, private credentials/manuscript, uncommitted fixture, dirty Dart or
untracked pyproject.toml included. Preview dry-run82files/76,536,472 bytes.

Git `core.autocrlf=true` initially produced CRLF archive bytes despite matching Git
blobs. Nothing from that archive was deployed. Recreated with
`git -c core.autocrlf=false archive` into ignored `build/temp/backend-v2-b310fd1-lf`.
Tar SHA256 `9D6CC60C28789751E10169B6F8851CA1519AF337BD4502B5C4D73879D3B4E07A`.

Standard Preview only, no --prod/promote/alias:

- Deployment `dpl_GFBfMHiDTwN1aNJLCfK1KChjmgZi`, READY, target=null, alias=[].
- https://aiflow-web-canary-31vkwdtxi-cw20208021-9200s-projects.vercel.app
- meta.sourceCommit=b310fd112e0b3e1e92f0b571d5ecd586bbe54a76,
  previewKind=backend-v2-readonly. Python3.12, requirements install, build2s.
- Local archived public and actual authenticated-browser main.dart.js response:
  7,157,176 bytes, SHA256
  `DA4910F2C02651760008559AE811B3B4AEB7780BF5090136404C975FC447F849`.
  This reuses the existing committed artifact; it is NOT a new clean Flutter
  product rebuild and does not include the later statistics UI change.

Deployed source file bytes were retrieved through the owner deployment API and
matched the exact LF archive:

| File | Bytes | SHA256 |
|---|---:|---|
| api/index.py |276744|6A42BF7A729F89F3380A85D4712E532BDF29F3472427F5AA3657CD7F33071FE4|
| api/textbook_import.py |12406|468BA6EE237DD56DF57C381259087C82C7A45C388E0F7424D120A783C5F498AC|
| api/book_activity.py |5188|4E23C192C0D7E5FA269F57F5E6686191A83CDC993E5E120F8901108A9F207174|

## Verification and remaining gates

- Real browser boots existing public; GET /textbooks renders
  `Bearer token required`. No student login/token or import submitted.
- /openapi.json returns text/html with flutter_bootstrap.js, not schema: Vercel
  catch-all routes it to the SPA. Local FastAPI TestClient GET /openapi.json is200
  and includes POST /textbooks/import. These are deliberately distinct checks;
  remote OpenAPI discovery has NOT passed. No routing/security change made.
- Focused Python tests76 passed, existing Starlette/httpx deprecation warning1.
- Preview environment variable list is empty. Production secrets were not copied.
  Authenticated V2 persistence and multi-connection DB idempotency remain untested.
- Canonical alias readback still `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`, not this
  Preview. Existing student/public data remain unchanged.
- Screenshots: `design/student/audits/evidence/2026-10-16-book-activity-capabilities/`
  backend-v2-preview-boot.png and backend-v2-openapi-spa.png. Boot is not design
  parity proof; existing public button glyph rendering is not certified here.

## Minimal committed session signal repair (separate from deployed archive)

Committed reader already listens to ApiClient.sessionChanges but old committed
ApiClient did not expose it. Added only ValueNotifier/getter and notifications
after credential restore/set/clear, plus test helpers. Not the dirty auth queue,
session scope, storage, grading or social API changes.

Function/variable responsibilities: `sessionChanges: ValueListenable<int>` is
process-local monotonic invalidation, not a user ID; credential methods publish
after updating in-memory token, so listeners see current auth state. Readers
discard account-local state. No new persistence/server side effects.

Two synthetic tests cover anonymous→login→different account→logout and one-time
persisted-token restore. Passed against both HEAD archive plus only this patch
(package URI override, guarded root cwd) and the working API. Existing dependency
configuration was reused, so this is not a full clean product build. Test loading
initially instantiated HTTP outside test zone; moved singleton initialization
into setUp and reran successfully. Existing Flutter auth concurrency work remains
unreviewed and is not certified by these focused tests.

### Exact committed HEAD recheck

Session compatibility commit `16719565cf8d98b79d59d11580b6662c1e6ece15` was pushed
and remote hotfix SHA read back equal. Initial remote push was rejected without
ref movement; one normal retry succeeded, no force push or branch switch.

Fresh HEAD lib/test archive plus the package URI override reran session tests2
successfully. `bookdata_import_preservation_test.dart` failed at compilation:

- BookWidget.bookLoader test seam is absent from committed reader.
- Exam mixins reference undeclared `_focusedQuestionIndex`,
  `_focusedExamQuestionKey`, `_examQuestionsMarkedForReview`, `_timerVisible`
  and `_CompactExamViewAction`. Their dirty working declarations were not added.
- HEAD arena/social source imports web_socket_channel, but current reused dirty
  package configuration omits it. This is a dependency-configuration mismatch,
  not proof HEAD pubspec lacks the dependency. No dependency files overwritten.

`flutter --help --verbose` and `flutter build web --help --verbose` expose
`--packages`, `--target` (entry file) and `--output` (output directory), but no
`--project-dir`, `-C` or equivalent project-directory option. Earlier SDK source
inspection demonstrated web Dart2JS uses the root package configuration despite
the global override; an archive entry filename is not source-closure proof.
Under the required root shell cwd, no clean full product web build was performed
or deployed. No SDK edit, package-config overwrite, alternate branch/worktree or
new dirty-source product build was used to bypass that limitation. Next work is
to reconcile those minimal reader/exam prerequisites and an approved reproducible
full-product build path; the backend Preview remains intermediate only.
