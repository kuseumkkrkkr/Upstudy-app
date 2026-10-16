# Coordinate source compatibility checkpoint

## Scope and verification state

- D: hotfix only. Initial feature commit `7f41095f43e96c4d79140e9f11824de4489472b8`.
- Source asset `html-3050dd8407807a29`; complete source and companion provenance/behavior contract: [BOOK_DISCLOSURE.md](../../../deploy/vercel/BOOK_DISCLOSURE.md).
- Original source, original BookData, and converted candidate remain private local inputs. Static remote harness contains synthetic content only. No publication, pricing, ownership, API authorization or canary alias changes.
- Python focused suite: 176 passed. Flutter broad focused suite: 24 passed again after independent hint-context correction (`52b1e6b`); scoped analyzer 0 issues. Graph/security/coordinate/disclosure focused suite: 9 passed, analyzer 0 issues (`06c60b7`). Final build/browser evidence remains required; this is not yet a completed deployment record.
- Independent review found authored coordinate hints absent from the first context getter. Corrected to include all authored activity hints, with a regression assertion. Other-page context remains excluded. This does not establish live AI response success.

## Current corpus audit (read only)

`python -m tools.audit_bookdata_roundtrip <private author root> --report build/temp/bookdata-roundtrip-current-20261017.json`: **187 files, 182 passed, 5 blocked**. These are serialization/validation results, not rendering, curriculum, rights or publication approval.

| Blocked input | Reason |
| --- | --- |
| 공통수학2_2022개정_무리함수그래프탐구_Batch1_BookData_V2_시범.json | unsupported registered activity kind |
| 공통수학2_2022개정_유리함수그래프탐구_Batch1_BookData_V2_시범.json | chapter `source_html_reference` unsupported |
| 수학Ⅰ_2015개정_지수로그누락기준_Batch2_BookData_V2_시범.json | unsupported registered activity kind |
| 수학상_2015개정_초안/수학(상)_2015개정_태그분권_통합BookData_초안.json | book `candidate_standard_codes` unsupported |
| 수학하_2015개정_초안/수학(하)_2015개정_태그분권_통합BookData_초안.json | book `candidate_standard_codes` unsupported |

Geometry 2015 supplementary Batch2 (tangents), Batch3 (vectors/lines/circles), Batch4 (spatial relations) all passed this serializer audit. Review/rights remain pending; no approval state changed.

Current hotfix `api/book_activity.py` and Dart activity model do not register `radicalFunctionExplorer` or `logarithmPowerExplorer` (verified exact-file search). Reports of implementations in a different checkout are leads to inspect, not evidence that the current build supports them. Preserve strict unknown-field/kind rejection; do not discard metadata to force a pass.

## Initial remaining gate (resolved below except production closure)

1. Finish current build, then test and rebuild the independently corrected hint context from an exact committed snapshot.
2. Exercise local source/original/candidate at 390 and 1280; save HTML / Dart-before / Dart-after captures. Verify drag, keys, reset, manual stages, hint, independent quiz and reversible disclosure.
3. Unique synthetic static Preview only, authenticate normally, verify actual response JS byte count/hash and rendered controls. Independent visual review and evidence commit follow.
4. Do not increment the existing 2/106 source verification count until these checks pass. Production remains unmodified: live-source closure still differs from clean HEAD.
5. Next: inspect bounded explorer implementations and preserve provenance metadata losslessly, with positive and negative validation/roundtrip tests.

## Graph defect found by actual original reader

Original companion graph rendered an empty-grid notice despite valid retained singleton A/B scatter declarations. JSXGraph required `points.length >= 2` for both lines and scatter; canvas treated singleton lines inconsistently. Both paths now require scatter >=1, line >=2. Original data is not rewritten or flattened. Commit `06c60b7` adds synthetic roundtrip and executes trusted generated JS with in-memory board/canvas doubles: A(-2,3), B(3,-2) must render, empty scatter and singleton line must not. These doubles are separate from actual browser proof, still required. First blank original screenshot remains private historical evidence, not a successful result.

On context-fixed pre-graph build, actual private candidate checks passed: keyboard movement to origin, reset back to A(-2,3), independent B quiz incorrect/correct feedback, details open, retained open state after 1280-to-390 resize, and close. Earlier pre-context build also verified actual direct drag A(-1,3) to A(2,-1), stage2 text follows changed y and fixed C hint. Final build must recheck after graph fix; no cross-build proof substitution.

## Final local and unique synthetic Preview verification

- Feature chain included in final build: `7f41095` → `52b1e6b` → **`06c60b759b005534b464c738a6e6d87306d8e915`**. All 299 exported library files matched HEAD; generated package config restored byte-for-byte after build. All build/temporary files stayed on D:.
- Root Preview: https://aiflow-web-canary-5obgs9007-cw20208021-9200s-projects.vercel.app/
- Deployment **`dpl_FdY7zwvejJtVNHvQYbtKLWKiX6Sp`**, source `06c60b7`; **synthetic harness only, not the product app and not a real manuscript publication**. No API deployed, product requests mocked, persistence disabled. No canary alias command issued.
- Actual browser response: 200 `application/javascript`, **5,764,824 bytes**, SHA-256 **`2111c1d49503f877fe0cfe3ab847488ea583818c049dbf51054d6e89e6f78489`**. Disk cache false, service worker false. Actual local reader response had identical bytes/hash. Proof: `evidence/2026-10-17-coordinate-source/preview-browser-bundle.json` (root URL, source commit, deployment, screenshot filenames included).
- Remote actual controls at 390: drag A(-2,3) to (2,-1), then focused Right key to (3,-1); scroll to controls, stage2 and hint, reset to initial A/stage1 with hint hidden. At 1280: quiz answer4 produces correct feedback; disclosure opens; resize to390 retains open body; close removes it from the settled tree.
- Final private candidate actual checks: mobile drag to (2,-1), scroll to manually advance stage2 then3, fixed C axis hint, reset after scrolling into view, independent B correct feedback, disclosure open/resize/close. Original and converted-candidate static graphs display both A(-2,3) and B(3,-2) at390/1280; no empty-grid notice. No actual browser touch-device event claim (mouse drag at mobile viewport; unit tests separately cover touch).
- Offscreen semantic clicks did not always execute: after observing unchanged state, scrolled the paper until the control was visible and re-ran the action. Only observed changed output is counted. Mobile mouse page swipe did not advance; desktop page buttons were used. These checks do not establish full mobile touch navigation/accessibility parity.
- Independent verifier examined 11 final images: no new visual defect; both static points visible, synthetic controls and disclosure readable. Photos alone could not prove private lower controls accessible; actual scroll/click checks above supply that separate evidence.
- Source inventory now **3/106 private candidates locally verified**, **103 still source-review-required**, **0 published/production-verified**. This is bounded functional verification, not HTML pixel parity, curriculum/rights approval, real AI grading, persistence or 200-user load proof.

### Images

Public synthetic only, under `design/student/audits/evidence/2026-10-17-coordinate-source/`:
`preview-drag-390.png`, `preview-controls-390.png`, `preview-quiz-1280.png`, `preview-disclosure-1280.png`, `preview-disclosure-390.png`.

Actual manuscript remains ignored/local, under absolute directory `D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix/build/temp/coordinate-source-private-evidence/`:

- Three-way comparison: `html-initial-390.png` / historical `dart-before-390.png` / final `dart-fixed-point-390.png`.
- Final source/preserved graph: `dart-fixed-original-scatter-390.png`, `dart-fixed-original-scatter-1280.png`, `dart-fixed-candidate-scatter-390.png`, `dart-fixed-candidate-scatter-1280.png`.
- Final interactions: `dart-fixed-controls-390.png`, `dart-fixed-quiz-1280.png`, `dart-fixed-disclosure-390.png`.

### Next one task

Resolve the five corpus blockers above losslessly: inspect exact bounded explorer definitions in the author app, compare current hotfix models/validators, port only required typed definitions/renderers and positive/negative tests; preserve source/candidate metadata explicitly rather than dropping it. Fresh corpus roundtrip and actual reader evidence remain required. Keep original review/rights pending flags. Production promotion remains blocked on the pre-existing live-source closure mismatch; do not replace the live app with this harness.
