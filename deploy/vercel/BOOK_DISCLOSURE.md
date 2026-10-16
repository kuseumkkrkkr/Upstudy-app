# BookData V2 disclosure and coordinate source mapping

`{"id":"details","kind":"disclosure","prompt":"Summary","content":"Plain text body","hints":[]}`

- Existing V2 activity slot; no schema bump or V1 acceptance. Required nonempty `content` ≤2,000 characters; common prompt/id/hint bounds unchanged. Reject unknown/executable fields and wrong content types, never silently drop them.
- Existing Flutter ExpansionTile provides reversible open/close and expanded semantics. Body and optional hints render as ordinary Text, not author HTML/JS/Markdown or embedded execution. Hints are revealed together with the body.
- `BookActivity.disclosureContent`: immutable text from server/source, serialized only for this kind. No changes to older activity JSON.
- Existing `_step` stores 0=closed/1=open; BookActivityKeyScope fingerprints complete definition and book/activity identity for reader-session restore. Changed definition resets state and changes ExpansionTile key. No student/OVR/disk/server write. Nonempty hints remain visible in the revealed body.
- This is plain-text details only, not arbitrary nested rich media, forms, adaptive pedagogy or executable markup.
- `BookPage.contextText` preserves prior page text extraction order and includes disclosure body/hints in the current page's search/tutor definition context. The reader delegates its existing extractor to this getter; other pages and learner runtime state are not included. This is authored page context, not a claim that a live AI response succeeded. Mixed uncommitted reader integration is preserved; only this delegation hunk enters the candidate snapshot.

## Reviewed coordinate source

- Asset `html-3050dd8407807a29`, HTML SHA `4235767CFF3D3BBBEA8585712BE8B3F35FAA791D4DC74E7594A3EA1AED568D9E`. Complete source and companion read; original source has integer sliders -5..5, initial A=(-2,3), pointer capture/drag, arrows, reset, three manually advanced stages, a fixed B=(3,-2) quiz, C=(-4,0) hint, and reversible details exercise. No timed movement in this source; a button name is not evidence of a timer.
- Companion `중등수학_좌표와순서쌍_BookData_시범.json`, inspected SHA `BEC3409AFBDA2F556D8CB9E1B3B782173914FBD945E2BA06C8D19D70F3D4AAF6`. Original graph is a static A/B scatter reference, not the interactive source behavior.
- `python -m tools.migrate_coordinate_point --source-book <original> --source-html <reviewed HTML> --output build/temp/<new>.json` explicitly inserts existing coordinatePoint + fixed-case quiz + disclosure after the lead of `ms1-coordinate-experiment`. Original scatter/blocks/pages/sections/review annotations are retained, not flattened/replaced. Static graph remains a fixed reference rather than following moved A.
- `definitions` contains only reviewed bounded declarations, never author scripts. C hint explicitly remains a separate fixed case. Quiz does not depend on current A. Details preserve the two independent exercises and answers with open/close behavior; not an always-visible or step-only substitute.
- `migrate` validates original first, hashes both original inputs itself, upgrades to V2 explicitly, rejects changed HTML hash or conflicting/incomplete existing insertion, and records publication=false. CLI guarded D: hotfix, exclusive-create ignored output, no author edits or public bundle.
- Existing coordinate renderer's deliberate corrections remain: (0,0) is origin rather than y-axis; reset clears manual stage/hints; 48px point handle and scroll behavior. These are not exact pixel reproduction. See BOOK_COORDINATE_POINT.md for drag/snapping/semantics contract.

## QA boundaries

Remote `tools/qa/coordinate_source_preview.dart` has synthetic point/quiz/disclosure only; actual manuscript loads only on loopback. Mock product requests are blocked and persistence is disabled. Actual private candidate/source and synthetic Preview are separate evidence sets. New validator support must be deployed in a compatible API candidate before any real import; current production support is not inferred from unit tests or a static Preview.

Initial migration regression fixture lacked mandatory graph.settings and was rejected; the synthetic fixture was corrected to the existing graph schema, not the validator. No failed test is counted as passed. Focused execution and actual screenshot/bundle evidence must be recorded separately before source inventory promotion.
