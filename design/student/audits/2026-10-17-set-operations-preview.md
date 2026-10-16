# setOperations checkpoint

## Scope and source

- D: `Upstudy-hotfix`, branch `hotfix`, feature commit `475e4634f1d44c59c74fedb73841327ce6320a90`.
- Source asset `html-244e439259c143b2`, HTML SHA-256 `E485B82083D57703F0A3E4C4EAE8A3E344A1873F2F31AC5C891E355F3E24C70C`. Full source render/events inspected; no timer/network/drag in this source.
- Original BookData SHA-256 `B612420AB6AD328FC8DD083AA835E5848C4E3FF0216C6C9F5A9F8BBD53333C9D`; frozen private candidate `1E4F96E769B479EDFAC23FBF36E8EF4AC6254F07C4D679665D12C0E8ACFA67D1`.
- Native V2 adds twelve checkboxes, four operations, diagram membership/region/result readouts and existing quiz kind. Original blocks/sections stay; pending review/publication is not changed. See `deploy/vercel/BOOK_SET_OPERATIONS.md` for bounds, state, source differences and migration CLI.
- Python focused checks **167 passed**, Flutter **14 passed**, scoped analyze **0 issues**, independent code review no defect found. Initial missing foundation import and three analysis infos were corrected before the repeated pass; those failed runs are not passes.

## First synthetic Preview — REJECTED visual gate

- Deployment `dpl_6KxPAad4ZKryKvLko7G6fiCc7QAz`:
  https://aiflow-web-canary-h7xjjwcbx-cw20208021-9200s-projects.vercel.app/
- Build Flutter 3.44.6 / Dart 3.12.2, release/no-pub/no-wasm-dry-run/no-web-resources-cdn, 123.9s. All **299** exported lib files matched feature commit; original package configuration restored byte-for-byte.
- Local/actual browser JS **5,763,184 bytes**, SHA-256 **`0ac33acde8869afd132b57f26db48b04eed535f2c7647eda34ffe2391e4a5432`**. HTTP200 JavaScript, disk cache false, service worker false. Evidence `evidence/2026-10-17-set-operations/preview-browser-bundle.json`. Static upload 69 files, no API/manuscripts/private handler.
- Actual 390×844: remove 3 from A -> intersection {}; union {1,2,3,4,5}; difference {1,2}; complement {3,4,5,6}. Keyboard Enter reset restores initial {3}. Actual 1280×900: all six checked into both sets -> all six displayed inside intersection. Synthetic fixed-case quiz gives wrong/correct authored feedback; captured at both sizes.
- Actual private candidate loopback: before p2/3 is text only; candidate activity p3/6, quiz p4/6. Changing A/operation updates results, resize keeps membership, exact source-case quiz reports 1 as the counterexample. Local original/old Dart/new Dart screenshots stay ignored under `build/temp/set-operations-private-evidence/`; no manuscript upload.
- **Independent visual review FAILED**: complement highlighted all U, including A. Correct result text is not correct region rendering. `preview-complement-390.png` and private complement capture are rejected evidence, not successful parity. Follow-up `rejected-difference-390.png` shows A-minus-B's overlap is correctly white; that related operation did not reproduce the complement defect.
- Fix: explicit source-style white A mask for complement, avoiding the faulty web rectangle-minus-circle hole. Add raster exclusion regression and rerun browser verification on a fresh build/deployment. Corrected Preview verification remains pending until recorded below.
- The pre-fix native raster check passed despite the actual web failure. Native raster tests do not reproduce this web-specific result and cannot replace corrected browser captures. Added four-operation region-pixel coverage remains a regression guard, not proof of a failing-then-passing native reproduction.

## Production boundary

Rechecked after first Preview: canonical canary remains `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`, JS **7,133,766 bytes**, SHA-256 `7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`. No alias command, product DB write, price/ownership/approval change. Neither this synthetic Preview nor private local loading proves real DB durability or whole-app clean-source release. Existing font warning remains.

This is one bounded two-set case, not full relation diagrams/all 106 sources/production publication. Inventory must not promote this case to reader-verified completion until the corrected visual gate passes. Next bounded source already read: coordinatePoint (`html-3050dd8407807a29`), same reviewed SHA4235767C…, real companion `중등수학_좌표와순서쌍_BookData_시범.json`, target `ms1-coordinate-experiment`; native integer drag/keys/manual stages already exist, but source-specific migration and actual candidate/Preview proof remain to do. Calculus derivative source hash47A9F6CF… also inspected for later work; timed approach and reduced-motion behavior are not implemented by setOperations.

## Corrected build and Preview (supersedes rejected visual evidence)

Audit-file updates initially failed exact-line patch matching; failed patches were not applied, and narrower file-specific patches succeeded. This was document editing, not a runtime/test/deployment pass or product mutation.

- Fix commit **`201691d639e1a17f0a0de64f22526b39c0f60e43`**, pushed to hotfix. Only painter/key and four-region raster tests changed; no API/data contract change.
- Repeated Python **167 passed**, Flutter **18 passed**, focused painter/test analyze **0 issues**. Four raster tests sample A-only/B-only/intersection/outside for all operations. The old native test's pass is preserved above: only actual web recheck establishes this correction.
- Exact 299-file library snapshot matched fix commit before D: build. Same pinned toolchain/flags; **86.8s**; package config restored. Existing Cupertino font warning unchanged.
- Corrected output `build/set-operations-fixed-preview`, static upload directory `build/temp/set-operations-fixed-static-deploy`, 69 synthetic files only.
- New deployment **`dpl_DwXpZmr6UD59MRfjbQhdASYQpd3u`**:
  https://aiflow-web-canary-4tyy1vtn9-cw20208021-9200s-projects.vercel.app/
- Corrected local and actual browser JS **5,763,257 bytes**, SHA-256 **`8a4133008703444f1375d5bb176bb4c1fc30026bda8c0fb3adce71816f73f0e0`**. HTTP200 `application/javascript`, disk cache false, service worker false. New evidence file **`fixed-preview-browser-bundle.json`**, not the previous deployment's proof.
- All `fixed-*` public screenshots were captured from this new unique deployment: mobile390×844 complement and quiz; desktop1280×900 complement and difference. A interior/intersection are white for complement, B-only/outside-A highlighted. Difference still excludes overlap. Actual clicks rechecked all four results, reset and fixed-case quiz correct feedback.
- Actual unchanged private candidate loaded from loopback9013 using the corrected compiled build. `dart-fixed-complement-390.png` proves the same A-hole correction in the real manuscript reader; candidate JSON digest unchanged, old source/explanations retained. Private images remain local-only.
- Desktop/mobile screenshots include reader scrolling: content outside its viewport is not removed from the document. No full-HTML pixel parity, touch gesture, real DB persistence or production publish claim.
- Independent corrected-image review passed: A-only/intersection white, U-minus-A amber on mobile/desktop/private candidate; difference excludes overlap; controls/text readable. This is visual review, not an independent interaction/network test. Corrected actual manuscript evidence additionally includes `dart-fixed-complement-1280.png` and `dart-fixed-quiz-{390,1280}.png`, showing original book title/context and exact source-case feedback in the corrected compiled reader. These are separate local-only files, not the public synthetic screenshots.
- After corrected Preview, canonical deployment ID and JS size/hash were rechecked unchanged against the production values above. Curated inventory now records 2 private local reader candidates / 104 unreviewed / 0 public; all nine broader families remain open. Updated inventory/source/set tests **14 passed**, including cross-check of corrected deployment ID, JS SHA, status, MIME and cache flags against the new evidence JSON.
