# Public, free textbook release — 2026-10-17 checkpoint

## Latest empty-state / Preview checkpoint

- Preview **dpl_FKGRwChvgRb84vCbuXB2ZgTcuTjN**:
  <https://aiflow-web-canary-a912dehej-cw20208021-9200s-projects.vercel.app/>.
  Default is an empty catalogue, not synthetic sale cards. `?auth=1` is an
  explicitly synthetic 401 UI fixture; it is NOT live authentication validation.
  `?sample=1` remains a clearly labelled synthetic reader fixture only.
- Authenticated empty backend catalogue no longer queries ownership storage
  unnecessarily. Added failure-to-empty and misleading-success regression checks.
  New API code rejects missing item arrays, nonzero prices, invalid IDs and
  malformed acquisition acknowledgements. UI distinguishes401 from list failures.
- UI now checks that a confirmed acquisition appears in refreshed library results
  before opening it; native offline fallback cannot falsely verify a new purchase.
- Focused Python **38 passed**, Flutter public/API/native-store **13 passed**.
  Native mock was explicitly extended with the new owned-catalogue endpoint;
  an additional test checks public+personal merge and account isolation.
- Actual browser390x844 and1280x900: empty message, no purchase buttons; synthetic
  login-required text/action. Images `preview-empty-{390,1280}.png` and
  `preview-auth-required-{390,1280}.png` in this audit's evidence folder. Vercel
  toolbar overlay is not part of the app. Login route behavior is unit-tested,
  not a working login service in this standalone Preview.
- D: final synthetic build67.6s, Flutter3.44.6/Dart3.12.2. Source archive
  `build/temp/public-textbooks-empty-preview-source.tar` SHA-256
  `4638C5ABF1E2F1C4E1A0F9A2680606CC5D45DFA59555806FFC5493BD8938879E`.
  Actual browser HTTP200 JS body **5,046,027 bytes**, SHA-256
  `C6F66A3A6F421D9E0A8A7336DEF68CE93E5847832CFCF80C2DA0EEE97CE28687`,
  identical to local output. Source snapshot includes existing dirty lib code,
  not only the five public-UI files; no claim of clean HEAD reproducibility.
- Upload guard checked69 static files, excluding root API/lib/data/test sources,
  env files, Dart sources and source archives. First guard falsely rejected KaTeX
  asset paths containing `/lib/`; corrected to reject root source directories,
  not licensed packaged font assets. No secret-shaped strings found by the
  limited sbp/sk-bk/sb_secret scan; this is not a comprehensive security audit.
- No API backend, real manuscripts or credentials were uploaded. API client
  transport is mocked to fail on any product request. Observed network buffer
  was truncated; do not report its zero matches as exhaustive traffic evidence.
- Canonical before/after still **dpl_HTYscDjA8dNT521Pjf91UeqJsaF2**.
  No promote/alias commands used. CLI inspect exposes no alias list; a null
  missing field is not proof of `aliases=[]`. Machine evidence is
  `design/student/audits/public-textbooks-empty-preview-proof.json`.

### Why this cannot be promoted or committed as five files alone

The five UI/API files contain pre-existing grading, level-test, auth and layout
changes, not just this feature. Current TextbookStore calls scoped LocalDb APIs;
HEAD `local_db.dart` only has `getString(key)`, `setString(key,value)` and
`delete(key)`, without scope/refresh parameters. Its web/io/stub implementations
are also dirty outside the requested five-file set. Whole-file staging would
include unrelated changes while excluding required dependencies. Those changes
have NOT been silently added or rolled back. Public UI files remain uncommitted.

Production path: review/isolate the required account/storage and reader source
closure first; commit that closure intentionally; build the real app entrypoint
and deploy the API with it; verify authenticated empty catalogue and ordinary
marketplace; then enable only approved source/hash manifest entries. The static
synthetic Preview must NEVER replace the whole student app. Canonical catalogue
load failure cause is still unconfirmed; no live login/DB recovery is claimed.

The user explicitly changed the target from private import to public publication
of ALL newly authored textbooks. Price is fixed server-side at **0 coins**.
This approval does not fabricate teacher/math/rights review results.
No existing books, courses, exams, user records or database were deleted.

## Release gate (not deployed)

Read-only audit found 143 BookData files in the manuscript folder. 136 validate
after explicitly separating author annotations; **7 still fail**. See
`design/student/audits/public-textbooks-validation.json` for exact paths/errors.
There is NO release bundle and NO manuscript publication/import/DB write yet.
The folder audit exits nonzero instead of silently omitting rejected manuscripts.
Release output additionally requires `--approval-manifest` with exact relative
paths, canonical source hashes, publication authorization, cleared rights and
approved teacher review. Only these explicit inputs enter that bundle; unrelated
sibling drafts are never added. Invalid/changed approved inputs block output.
No such fully reviewed release manifest has been supplied or fabricated.

The following require real compatibility work, not weakened validators:

- Two sources contain unsupported visual kinds.
- Algebra contains an unsupported runtime block/activity.
- Calculus I contains old-style inline quiz fields instead of a registered activity.
- Two graphs use reserved independent variable `x` as a slider parameter.
- One combined manuscript exceeds the bounded tags contract.

A process-local immutable manifest is bundled only after all input files pass.
Input raw source remains outside the app checkout. Author metadata is retained
in the release envelope, not misrepresented as runtime content or approved review.
Unknown runtime fields/scripts/JSX are rejected, not executed or stripped.

## API and persistence

| Unit | Input/output and side effects |
|---|---|
| `prepare` / `build` | Read all BookData files, preserve known annotations separately; strict parser/hash; return entries and per-file failures |
| `books` | Read deployment-owned `data/content/published-textbooks.json`; validate source hashes and schemas once; immutable digest IDs |
| `GET /marketplace/textbooks` | Authenticated user; public metadata + their owned flags; never private manuscripts |
| `POST /marketplace/textbooks/{id}/purchase` | Authenticated user + existing immutable ID; insert-only own KV row; no wallet calls; client price/actor ignored |
| `GET /marketplace/textbooks/owned` | Only this user's acquired public metadata, no body payload |
| `GET /textbooks/{id}` | Public body only after same-user acquisition; existing private-book owner boundary preserved |
| `PublicTextbooksPage` | Search, loading/error/retry, 0-coin acquire, duplicate-click lock, actual reader navigation, session/epoch checks |
| `TextbookStore._fetchLibraryMeta` | Merge public acquisitions by ID without the personal ten-item limit; retain local progress; auth/session failures never become empty success |

| State | Source/lifetime |
|---|---|
| `published-<sha256>` | Exact validated runtime content identity, permanent per edition |
| `textbook.public.owned.<id>` | Server-owned per-user acquisition row, unique `(user_id,key)` insert-ignore; retry never overwrites progress or another title |
| `_epoch`, `_busyId` | Page-only generation/request lock; invalidated on session change/dispose |
| `source_metadata` | Original digest, source relative path and annotations; review status unchanged |

200 duplicate HTTP requests / 20 mock workers test insertion idempotency.
This is NOT a real PostgreSQL 200-connection or 5,000-user load test.

## Verification and remaining release work

- Python public/import/auth focused tests: **37 passed**, existing warnings20.
  The integration test also verifies actual application routes reject missing
  authentication, ignore forged actor/price, and enforce reader ownership.
- New public page tests2 passed; native session/store regressions7 passed after
  fixing the known-current-actor offline cache regression (initially1 failed).
- Scoped analyze initially found one missing-braces lint after epoch checks;
  braces added without changing behavior. Final rerun: **No issues found**.
- Current canonical marketplace browser showed a list-load error. Its cause is
  not yet established; no authenticated purchase/save/refresh claim is made.
- D: synthetic Flutter web build succeeded94.2s. Browser clicked the real
  0-coin button, opened actual BookWidget and moved to the second body page.
  All product API requests were blocked by its synthetic harness. Evidence:
  `evidence/2026-10-17-public-textbooks/dart-before-marketplace.png`,
  `dart-after-public-textbooks-synthetic-390.png`,
  `dart-after-public-textbooks-synthetic-1280.png`, `dart-reader-synthetic.png`.
  A second build after square/black button styling succeeded66.4s; new page
  tests2 passed again. Its main.dart.js SHA-256 is
  `E804C0F85B0D371B6E11E18D5AD264AFA087975B34338601CA3852C7E4562CEA`.
  The later braces-only source edit is not claimed part of that build snapshot.
  This is not HTML parity or live acquisition proof. The new catalogue has no
  original HTML scene; no fabricated reference/before image is provided.
- Broader pre-existing dirty ApiClient, TextbookStore and Marketplace changes
  remain separate. A synthetic dirty-tree build is not clean-source production
  provenance and must not replace the student app.
- The public page/API adapter/library integration remain uncommitted UI work,
  because they rely on existing uncommitted session-scope foundations absent
  from HEAD. Only the independently tested backend/publisher checkpoint may be
  committed without those unrelated changes; no mass staging is permitted.
- Next: resolve all7 source/renderer mismatches with lossless explicit mappings;
  rerun full-source audit; freeze a real release manifest; complete API/storage
  and reader tests; build the actual app from a reviewed source closure; verify
  real canary catalogue/acquire/refresh/reader and served-bundle hash. No alias
  promotion until these gates pass. Existing production alias remains unchanged.
