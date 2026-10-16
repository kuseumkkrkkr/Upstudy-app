# Private BookData V2 remote creation checkpoint

## Traced contract

- Guarded checkout: `D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix`, `hotfix`; starting HEAD `c9890de494d46d0360604b1ef711a5119b179584`.
- The separate author checkout's reported empty-map stub is not the current hotfix contract. Hotfix HEAD had an explicit Flutter `501 textbook_create_unavailable` stub; its server already implemented `POST /textbooks`, `POST /textbooks/import`, list and owner-scoped read.
- `TextbookStore.create` → `BookData.toCreateJson` → `ApiClient.createTextbook` → authenticated `POST /textbooks` → validated private KV record → response `textbook_id` → reader `GET /textbooks/{id}`. This patch connects the committed Flutter method, not the unrelated dirty session/cache rewrite.
- `/textbooks` accepts structured BookData V1/V2 (512 KiB max), including full nested pages, graphs, supported activities, chapter tags and standard codes; root tags allow 64, matching the strict importer. Unknown publication/owner/price/review fields are rejected.
- `/textbooks/import` remains the exact UTF-8 source/hash import contract. Import and structured create use separate identity namespaces; neither grants publication eligibility.

## Safety and retry behavior

- `_current_user` verifies an HS256 product JWT with the server's `OMJ_JWT_SECRET`; owner is never accepted from JSON. Server-side Supabase Data API uses a service-role credential, not a client key.
- Structured creation now hashes canonical validated payload (sorted JSON keys, defaulted request fields) and uses owner + digest for a stable UUID. Same owner/content retries return the winning stored record; changed content creates another private draft. This is content-based deduplication, not an arbitrary client idempotency-key API.
- Unique `(user_id,key)` + `resolution=ignore-duplicates` prevents replacement of the winner/progress. Response is returned only after stored hash verification. Failure to verify persistence returns 503, not a local-success fallback.
- Generic `/user/storage/{key}` GET/PUT/DELETE now rejects `textbook.private.*` and `textbook.public.owned.*` (case-insensitive), preventing bypass of book validation/acquisition through generic KV writes.
- Flutter captures token and session generation and rejects late create results after account changes; empty successful responses are rejected. No unrelated dirty `ApiSessionScope` infrastructure was imported into the checkpoint.
- Public release remains deployment-owned and separate. Approval manifest now requires explicit `math_review_status=approved` in addition to publication approval, cleared rights, teacher approval, exact path and source SHA. Release entries retain those approvals, and runtime bundle loading rejects missing/pending approvals or mismatched original SHA. Client metadata cannot publish a draft.
- Existing `deploy/vercel/supabase_auth.sql:25` defines the KV composite primary key; lines 33–35 enable RLS, revoke anon/authenticated access and grant service-role access. This is source inspection, **not live RLS confirmation**. No SQL migration was run.

## Focused evidence

- Python: 48 passed (`test_textbook_create_contract`, `test_textbook_import`, `test_public_textbooks`, `test_bookdata_author_compatibility`, `test_graph_math_security`). One existing Starlette/httpx deprecation warning.
- Flutter selected-index library snapshot: 7 passed (`textbook_create_api_contract_test`, `bookdata_author_compatibility_test`). Includes authenticated POST, full V2 response, empty-result rejection and late-session rejection.
- Focused analysis of the selected-index API client and create contract test: no issues. Whole-application analysis was not run.
- In-memory route concurrency: 24 concurrent create calls, one stored record; progress survives retry; another owner's read returns 404 and create gets a different ID. **Not PostgreSQL multi-connection or 200-session load evidence.**
- Initial snapshot compilation failed because an unstaged method depended on uncommitted session types. Fixed by staging an independent token/generation guard against HEAD; subsequent seven tests and release web build passed. Failed runs were not counted as passes.
- D: release build target: `build/temp/textbook_create_preview.dart`; output `build/textbook-create-preview`; explicit `--dart-define=API_BASE_URL=` keeps requests same-origin. Generated package configuration restored byte-for-byte after build. Cupertino font declaration warning remains; no icon-font completeness claim.
- Preview `main.dart.js`: 5,749,370 bytes, SHA-256 `34C2DB6082BD0DCBA0A3775BEA8CDDD422DC5EEF29E33E05E567AF049A46E1DE`. This is a local synthetic build, not a Vercel deployment hash.
- Local Preview: `http://127.0.0.1:9007/`, loopback-only FastAPI with synthetic auth override and in-memory `Storage`; no Supabase access, real credentials or real author manuscripts. Server module: `build/temp/serve_textbook_create_preview.py`.
- Browser controls exercised: save/open → real local `POST /textbooks` 201 → `GET /textbooks/b6c7095c-1de6-58a8-9088-973770c59ead` 200; repeat button returns same ID; graph coefficient `a` 1→1.5; desktop next page → quiz answer 2 → correct feedback; mobile/desktop render captures.
- Captures: `evidence/2026-10-17-textbook-create/saved-390.png`, `retried-graph-390.png`, `quiz-correct-390.png`, `quiz-correct-1280.png`.
- The synthetic wrapper is not a redesign of the product editor or proof of full HTML parity. The mobile quiz page was verified after desktop navigation; a mobile swipe transition was not tested.

## Responsibility / state map

| Unit | Inputs / output | State and failure behavior |
| --- | --- | --- |
| `ApiClient.createTextbook` | BookData JSON → saved map with ID | Authenticated POST; session change/invalid response throws; invalidate list cache after success. |
| `create_textbook` | Bounded structured request + authenticated owner → persisted book | Strict schema/graph/activity validation; insert-only content identity; 422 invalid, 409 identity conflict, 503 unavailable/unverified write. |
| `canonical`, `digest`, `textbook_id` | Validated payload → UTF-8 SHA-256 → owner-scoped UUID | Request-local; digest and ID stored with winner; not published or used as approval. |
| `approved_files` / `build` | Server-owned path/hash/approval manifest → release entries | Pending or missing reviews fail closed; annotations do not imply approval. |
| `public_textbooks.books` | Deployment-owned bundle → validated catalogue | Cached after approval/identity checks; invalid bundle raises rather than publishing. |

## Still unverified / next step

- Live PostgreSQL unique constraint/RLS/grants, real authenticated Supabase persistence, server restarts and multi-connection concurrency remain unverified. Do not call this production-ready from mocks or the local Preview.
- No production deployment, canary alias change, pricing change, real publication, user-data deletion or separate author-tree edit occurred.
- The previously recorded undeclared `a*x^2` author manuscript remains a separate source blocker; this synthetic graph declares its own coefficient and is not a correction of that manuscript.
- Before deployment: confirm live storage policy/constraint, run real DB owner-isolation/retry tests, then build the full product from an intentionally reviewed source snapshot. Preserve all unrelated dirty changes, including the old drawer deletion.

## Curriculum-review gate follow-up (2026-10-17)

- `curriculum_review_status=approved` is now independently required by both `approved_files` and deployment bundle validation; teacher/math review does not imply curriculum approval. Older manifests/bundles missing the field fail closed and must be explicitly reviewed, not auto-upgraded.
- The builder copies the curriculum approval into deployment-owned `source_metadata.approval`, with the exact approved original source SHA. Original reviewer, reviewed-at and source-version evidence in author `metadata` remains unchanged under `source_metadata.annotations.book.metadata`; it is not promoted to a trusted approval or added to private draft APIs. The existing original/runtime hashes still distinguish the reviewed input from normalized runtime content.
- Regression cases cover missing/pending curriculum approval at build and runtime, source metadata claiming approval without a manifest, preservation of synthetic reviewer/version/time evidence, and source hash drift. These checks preserve attestations; they do not independently establish a reviewer's identity or perform curriculum review.
- Focused Python regressions: 30 passed (`test_public_textbooks`, `test_textbook_create_contract`, `test_bookdata_author_compatibility`), one existing Starlette/httpx deprecation warning. No Flutter rebuild is necessary for this server/tool-only follow-up.
- No content bundle, database mutation, browser/UI change or deployment was performed for this follow-up.
