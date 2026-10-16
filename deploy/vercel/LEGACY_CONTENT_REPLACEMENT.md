# Legacy course/exam/problem-set replacement: preparation only

Date2026-10-16; source checkpoint `7b36e0ed0b42793caff251f422601022cf2b6769`.
**Content writes/deletes/restores, student mutations and alias changes:0.**
New replacement DB has not been accepted for cutover. This is a runbook, not an
approved/executed migration, backup, new retirement feature or deploy.

## Counts and evidence limits

| Source | Course | Exam | Problem set | Meaning |
|---|---:|---:|---:|---|
| Last authenticated live observation earlier in this task |81|85|166|332 active;7 archived other rows,339 merged rows; historical only |
| Current local `_build_marketplace_catalog` read-only import |81|85|166|332 unique seed IDs, NOT current live counts |
| This audit live count refresh |unknown|unknown|unknown|Existing encrypted local admin read credential returned401 |

No new admin login was attempted: login increments its database attempt counter.
Do not interpret the local credential401 as proof the application's Supabase
connection is broken. A valid already-authenticated admin GET session or an
approved read-only SQL connection is required. Live FK/trigger/RLS introspection
also remains pending; repository migrations alone cannot certify the deployed DB.

## Actual source and reference model

| Location | Data / reference | Preservation |
|---|---|---|
| `api/index.py::_build_marketplace_catalog` | Cold-start bundled seed,332 IDs | Deleting DB rows alone resurrects seed content |
| `data/content/ui-test-20261008.json` | Alternate seed only if `STUDENT_UI_TEST_CONTENT=true` | Separate from store/service demo flags; preserve textbook section |
| Separate admin Supabase `public.canary_content` | PK `id`; JSON `payload.kind`, `asset_id`, `problem_ids`; version/archived | Stored overrides/tombstones, not three physical product tables |
| Admin `canary_content_changes` | `(actor,request_key)` receipts, before_payload, content_id | Append-only audit; `content_id` has no FK in source migration |
| Student `canary_user_kv`, key `marketplace_owned` | JSON object keyed by listing ID, with progress/status/completed | All ownership/progress retained unchanged |
| Same KV, `course_enrollment_order` | JSON asset-ID list | Preserve ordering; not a content-table FK |
| Same KV, `solve_history.*` | quest_id, codebase_id, seed, correctness/tags | Does not necessarily contain full original question text; preserve resolver |
| Same KV, `textbook.private.*`, `level_test.v2.*`, all other keys | Private books, sessions/results and unrelated user data | Entire student KV table is outside cleanup scope |
| Student rating/level-test/OX/arena/OCR tables | Separate functional data | No cleanup or schema replacement |
| `data/content/question-bank-v1.sqlite` | Read-only immutable canonical question snapshot | Keep old IDs/question meanings for history and old references |

Local seed:166 problem sets have empty `asset_id` by design; the other166 nonempty
asset IDs are unique. Always target nonempty **listing IDs**, and explicitly map
asset aliases; never filter/delete by empty asset ID. `product_catalog.json` was
not identified as the332-item seed source in this API path; do not delete it or
unrelated authoring sources on name similarity.

Local SQLite verified with `mode=ro&immutable=1`, `PRAGMA query_only=ON`:
tables `quest_header`(3111 rows), `quest_info`, `quest_data`, `solve_step`,
`sqlite_sequence`. The last three question tables reference `quest_header` with
`ON DELETE NO ACTION`, not cascade. `api/question_bank.py` hard-checks SHA256 and
row count; replacing the file alone causes failures. No SQLite modifications.

| Local evidence | SHA256 |
|---|---|
| question-bank-v1.sqlite |A0FF8D47A4207802A25FB17B2534B8E65EAD0C8D5F352E81DE35BB7DC2EBD009|
| ui-test-20261008.json |5DA318DEF60A0018592AD8A53A3ECFED7AAFB8FB44974FDDB7197FD8CF5B46FB|
| supabase_content_admin.sql |DF852558A40199601560BB6E637FFBEC488C86B3C2F98D48302152D4F3C0577C|
| supabase_auth.sql |D24CEBDF2E01E39B794B06416412EEE90770B24B7D651BBFAAA0E7ACE1F35335|

## Deletion and archive semantics: source-verified, live schema unverified

- Admin content `updated_by` and audit `actor` reference admin account IDs with
  default `NO ACTION`. No course/exam/problem-set FK into the other project.
  Other live constraints/triggers must still be inspected before any cutover.
- Student KV `user_id -> canary_users.user_id ON DELETE CASCADE`: **never delete
  users**, call `delete_all_canary_users`, truncate KV, or drop/replace this schema.
- Rating `user_tag_rating -> user_rating ON DELETE CASCADE`; OX `created_by ->
  canary_users ON DELETE SET NULL`: these tables/accounts are not cleanup targets.
- `DELETE /admin/api/content/{id}?version=N` is actually archive, preserving
  payload and incrementing version. JWT+API key+idempotency key required.
- `admin_write_content` serializes request key/content ID via advisory locks,
  checks version, writes override+receipt in one transaction. Same request key
  replays; changed fingerprint/version conflicts must stop, not generate new keys.
- Archive hides public catalogue/acquisition only. `_effective_catalog(true)` is
  used by enrolled courses, owned materials and exams; `_find_catalog_listing`
  defaults to including archived items. Existing owned learning remains readable.
  Archive is therefore NOT full removal from student UI or all direct routes.
- Physical DELETE of admin overrides removes tombstones and can reveal bundled
  seeds again. Per-ID HTTP transactions are NOT an atomic332-item operation.
- PUT rejects changed kind/question list on a published ID; use new release IDs.
  Existing PUT publishes immediately, so PUT-then-archive is NOT safe draft staging.

## Read-only preflight / reproducible count query

1. Run worktree guard; record root/hotfix/source SHA/dirty diff and live alias ID.
2. Use an authorized SQL connection in each exact project with the corresponding
   `legacy_admin_catalog_readonly.sql` or `legacy_student_records_readonly.sql`.
   Scripts are self-contained repeatable-read, read-only, timeout-bounded and
   rollback-only. Student ownership aggregation needs PostgreSQL12+; report
   parse/permission/schema/timeout failures instead of replacing them with0.
3. Record live public FKs/delete actions, non-internal trigger identities and RLS.
   Review unknown triggers/functions securely; do not print bodies/arguments or
   secrets into audit logs. Source FK evidence is not live SQL evidence.
4. With an existing valid admin session, GET `/admin/api/content` once (read-only).
   Count `items` by `payload.kind` and `archived`. Freeze the full response to an
   access-controlled backup, then an allowlist of old listing ID/kind/asset ID/
   version/payload SHA. Never select "all current rows of this kind" after new
   rows have arrived. Any changed/missing/extra legacy ID needs reconciliation.
5. Admin SQL counts stored overrides only. Effective API data is seed overlaid
   by ID: active = seed IDs without overrides + nonarchived overrides. Do not
   add SQL counts to332 or treat an empty admin table as an empty catalogue.
6. Record per-ID ownership reference counts from student read-only SQL. Detailed
   record digests/exports stay in protected backup, not Git/screenshots. Keep all
   student IDs/values/answers out of public reports. No session-token extraction.

## New DB arrival: gated dry-run -> backup -> transaction -> verify

1. **Receipt gate:** actual file/DB identity, SHA256, schema, exact new IDs,
   subject/type mapping, expected counts, review/rights status and migration owner
   are accepted. Unreviewed samples are not an accepted production replacement.
   Do not execute arbitrary DDL/RPC from a supplied dump. No source has passed
   this gate during this audit.
2. **Dry-run:** isolated preview DB/auth first (currently missing; see
   `BOOK_ACTIVITY_V2.md`). Validate IDs/types, <=50 question IDs per existing admin
   input, canonical question existence, immutable published IDs, asset mappings,
   no account/level-test/private-book/progress/answer targets. Compare exact
   frozen old manifest and proposed new manifest; require no unreviewed cascades.
3. **Backup gate:** approved SQL read access, encrypted consistent admin catalogue
   and receipt exports, preserved schema/permissions, current seed/optional UI
   fixture, old immutable question bank and source/build/alias manifests. Student
   preservation snapshot/digests are protected. Use a verified ignored D: hotfix
   backup path (for example `build/secure-backups/legacy/<runId>`), current-user ACL,
   and approved second safe copy; never commit secrets/dumps. Verify hashes and
   perform restore rehearsal in isolation before any destructive action.
   Admin-account credentials remain untouched; isolated audit restore can seed
   synthetic actors with the preserved reference UUIDs, not production passwords.
4. **Compatibility gate:** current APIs have no draft/release-generation or
   absolute-retired status. These need a separately reviewed additive migration
   and compatible API first; this runbook does not implement them. Keep both
   old/new immutable question versions, and an owner-checked history resolver.
   Existing clients/caches must not bypass retired checks or lose history.
5. **Future admin transaction (pseudocode, NOT available RPC):** acquire one
   release lock; validate expected old manifest versions/hashes and active release
   CAS; validate all staged new IDs; mark only allowlisted old IDs retired; make
   the validated new generation active; append one durable idempotent receipt;
   commit once. Any mismatch rolls back all changes. Sorted ID locking avoids
   conflicting batch lock order. No student DB writes occur in this transaction.
   Cross-project transactions are NOT atomic: do not claim student data changes
   are part of the same commit. Direct table permissions must not be widened.
6. **Route policy:** archive-only withdrawal may retain existing-owner access;
   full retirement needs a central deny-list independent of `include_archived`
   across list/detail/search/purchase/runtime/owned/exam paths. Keep student JSON
   records, but hide retired content. Historical resolution is a separate owner-
   checked read-only path, not a bypass for new enrollment/learning.
7. **Deployment gate:** no deployment/alias permission comes from this document.
   After explicit release approval, validate compatible dual-version code before
   publishing a new generation. Drain/reconcile in-flight legacy writes and test
   cached clients. Real PostgreSQL multi-connection retries/conflicts and200
   sessions remain required; mocks are not proof.
8. **Verification/rollback:** read merged catalogue counts and exact IDs, test old
   direct routes and new owned journeys, verify account/level-test/private-book/
   progress/answer preservation. Account for legitimate concurrent student writes
   when comparing snapshots; unexplained changes stop release. Prefer restoring
   a release pointer and compatible build over deleting imported rows. Never
   delete student data or overwrite old question meanings to "roll back".

## Current blocking conditions / next one task

- Live catalogue count and actual FK/RLS/trigger refresh unavailable with the
  existing local read credential (HTTP401); last live counts remain historical.
- New replacement DB, reviewed ID manifest, isolated DB/auth and tested recovery
  have not been supplied. Archive alone cannot satisfy full-retirement semantics.
- Next safe task: obtain approved read-only metadata access or an already-valid
  admin GET session, run the preflight SQL, freeze exact live IDs/versions/counts.
  This is not approval to log in/write counters, provision new keys, delete,
  archive, restore, import, or change aliases.

Validation: `tests/test_legacy_preflight_readonly.py` statically checks read-only
transaction framing, timeouts, rollback and absence of mutating statements.
Together with existing `tests/test_content_admin.py`:11 tests passed. This does
not validate PostgreSQL execution, actual privileges or live FK/cascade behavior.
