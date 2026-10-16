# BookData private import — in progress

- Worktree: `D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix`, branch `hotfix`.
- Backend foundation: `8be93ce06a7895236cb2f7eb0dc3d84301886d64`.
- Approved source SHA-256: `B17EA340037C29DE17664082847365F692C4F614BCD874535D7925AD1B5A3823` (6074 bytes). Original stays in the other checkout; not copied or bundled.
- Scope clarification from coordinating chat: unreviewed prototype, **private library only**. Public/admin publication is not authorized. The registered goal's publication wording does not override this restriction.
- Source contains 1 chapter, 3 explicit pages and 1 supplementary section. Reader preserves both; pagination may split dense content. Question/hint/answer blocks are display-only. Independent HTML's point dragging, distance comparison and input grading are not supplied in BookData and are not claimed as preserved.

## Implementation and responsibilities

| Unit | Input / result | State and failure handling |
|---|---|---|
| `parse_import` | Original UTF-8 source and expected SHA; validated original object | Rejects checksum, duplicate keys, unsupported schema, unsafe graph expressions; no evaluation |
| `POST /textbooks/import` | Authenticated owner + source/hash; persisted BookData | Owner/hash UUID, unique insert, retries reuse stored content; no public catalog writes |
| `TextbookImportPage` | Browser JSON selection, optional expected hash; returns saved book | 512 KiB bound; clears source on account change; retry same source after uncertain response |
| `pickBookSource` | Browser file chooser; bytes or cancellation | No extra dependency; size checked before arrayBuffer; handlers cleared |
| `TextbookStore.importSource` | Source/hash and captured session; cached/library book | Checks session around remote/cache writes; reimport preserves known progress |
| `_importBookSource` | Explicit private import action | Captures scope/epoch before route; rechecks before/after reload and before opening reader |
| `_askAboutCurrentPage` | Explicit question action; ephemeral Socratic chat | Only selected rendered page, book/page ID and initial graph settings; labels initial/not live slider values; bounded excerpt marks truncation |
| `compileGraphMath` | Arithmetic expression, allowed parameters; numeric function | Bounded parser and fixed functions; no eval/new Function |
| Graph iframe | Validated graph document | sandbox allow-scripts only; no same-origin; parent event source validated |

| Variable | Meaning / lifetime |
|---|---|
| `_source`, `_hash` | Selected UTF-8 source and SHA; import page memory, cleared on session change |
| `_scope` | Captured owner/session; prevents another account saving the source |
| `_busy`, `_error` | Submission lock and visible retry feedback; page lifetime |
| `sourceSha256` | Server-confirmed digest; BookData and private library metadata |
| `curriculumVersion`, `standardCodes` | Source metadata preserved in body/library serialization |

## Current verification

- `python -m pytest tests/test_textbook_import.py tests/test_graph_math_security.py tests/test_vercel_auth.py -q`: **28 passed**, 20 warnings (synthetic JWT warning among them).
- `flutter test --no-pub test/bookdata_import_preservation_test.dart`: **3 passed**. Checks source metadata/slider roundtrip, explicit-page and supplemental prose, and current-page-only Socratic context.
- New import/picker/parser files scoped analyze: **No issues found**.
- Broader changed-file analyze originally found 72 issues including missing file_picker. Missing dependency was fixed using native browser picker; remaining broader legacy findings have not been cleared or reclassified as passing.
- Fresh D release build started; candidate/alias deployment and actual file import, refresh, slider, tutor response, 390/1280 screenshots are **pending**.
- No new manuscript DB writes or public publication verified yet. Do not report upload complete.

## Next action

Resume the live build process, inspect its exit/log, then synchronize fresh build into public and create a unique canary candidate. Verify bundle hash and actual private import from approved original file before alias promotion. Preserve unrelated dirty source; no branch switching or source copying.
