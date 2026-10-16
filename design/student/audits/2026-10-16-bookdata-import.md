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

## Live verification checkpoint

- First deployment `dpl_2GkUBpSPoYa9vtzwBA82MFUKgQsW`; SHA `38A5A0D9136A4EA5922B2E18BC3F7D133D5FE7C414486FBF56E7FF32F1C74C1E` matched D build. Browser selected the original JSON and typed the expected digest, then used the actual save button.
- Private import succeeded for the existing test account. Book ID `ad2f7179-c671-55d0-8815-c3fd0f3ad8da`. No administrator/public publish call made.
- Browser refresh -> server `/user/storage/textbook_library_v1` 200 -> same book in chooser -> body cache GET 200 -> reader reopened. Stored structure: 1 chapter, 3 explicit pages, 1 supplementary section; metadata/digest preserved.
- Exhaustive source-field projection of the real server-returned cached body matched normalized original SHA `32415ECC0B9C1EDB2546B2567B487213B306BDE511A4E25C8B5C45B9DEA0BADA`. Defaults added by BookData are excluded, **no original fields excluded**. Raw original file SHA is separately recorded above.
- All 6 rendered segments were visited: opening, graph experiment, verification/misconception, practice/hints/answer/checklist, chapter intro, supplementary derivation/graph.
- Real `/serverchat/message` request included current page title/text, book ID, graph expression and initial p settings, `mode:socratic`, `ephemeral:true`. It did not attach the whole book. Response **502**, retry also failed. Vercel sanitized logs: upstream HTTP403/application-json/Cloudflare. Official Kiln error documentation says 403 means suspended/revoked key (including archived project). Exact credential state is unverified. No key/permission changes made. **Tutor response NOT passed**.
- First live graph card was too short (192px), clipping controls. Increased room for graph minimum/toolbar/parameter controls. Second deployment `dpl_9ggB6rYs14xjNYsEcKADB3pZsXdU`, URL `https://aiflow-web-canary-am5b2dl4m-cw20208021-9200s-projects.vercel.app`, alias canonical canary. Local/candidate/alias SHA `B200054F5F68F2CB935F5936B1E33F59DF43BF9739035AAA73BD2658555DC3AB`, 7,132,539 bytes.
- Actual 390x844 emulation: graph and parameter control visible; keyboard changes p 2 -> 1.5 -> 1 update native slider value and SVG. Sandbox still required; runtime attribute audit pending.
- Browser viewport capability did not apply requested size (actual 358x668, DPR1.25). Those JPEGs **are not** 390x844 evidence despite provisional filenames. Corrected via CDP Emulation, independently measured innerWidth/innerHeight/DPR, and Page.captureScreenshot exact clip. PNG `reader-graph-after-390.png` and `reader-graph-p1-390.png` are actual 390x844 evidence.
- Actual 1280x900 revealed page/body mismatch after resize (also observed on subsequent desktop navigation). Added failing regression, then PageController onAttach restoration with keepPage false. Resize + desktop previous/next checks now pass in widgets (4 tests). New build and live retest required; current alias does **not** include this correction yet.
- Tutor route now also binds to captured reader session/epoch, replacing private context when account changes. Additional session-change check pending execution.

## Source provenance limits

- New files/model/validator checkpoint `6aea3bf89ca8130c98c0a25256e9e209312c0cb8` is committed. API client/store/reader/graph integration overlaps substantial preexisting dirty changes; those are not blindly committed. Therefore **source HEAD alone cannot reproduce the current bundle**.
- Local-only source snapshot (no manuscript) `build/temp/bookdata-source-snapshot.tar`, SHA `563EA29F0D88EB972491EF9A4CDDD1B03D4B2740D0E518FA6BFD045CA9CFFB01`, captures second build state. Tracked overlay SHA `5752A27EEA39B4B3AE05AEACA0862DEF39E9DADC377D50538FAD6E5B8E6F33BF`. Later viewport/session fix is not in that snapshot.
- Required remaining work: final session/desktop regression, fresh final build/deploy/hash/actual 390+1280 tests, selective source integration review/commits, live idempotent reimport, runtime sandbox verification. Kiln credential resolution is an external dependency, not a reason to report tutor success.
