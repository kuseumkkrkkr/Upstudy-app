# Public, free textbook release — 2026-10-17 checkpoint

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
