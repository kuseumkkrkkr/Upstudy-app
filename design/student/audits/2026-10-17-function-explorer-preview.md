# Function explorer / metadata compatibility checkpoint

## Current verified scope (not production publication)

- D: hotfix only. Previous coordinate checkpoint `75afcd7` remains unchanged.
- Strict importer metadata: `c83cdb0`; create API root candidate codes: `2d41372` (other auditor's commits). Typed activities/reader/migration: **`040a20cb052fb5520913539fb19c36e34f8f91cd`**.
- Original five blocked files now pass the read-only Python compatibility audit; latest current corpus **187/187 passed, 0 blocked**. Full Dart preservation test also checked all **187** generated runtime books (not skipped). This verifies serialization/validation and preservation, not all pages' rendering, curriculum, rights, approvals or live persistence.
- Three function kinds were absent in the guarded hotfix even though present in the author-app reference. Original first-error failures named radical and log; rational was hidden behind its chapter provenance failure, not an independently passing activity. Registered all three exact numeric contracts, never a generic fallback.
- Current source normalization/audit records remain ignored: `build/temp/bookdata-explorers-final-20261017.json`; full actual runtime payloads `build/temp/bookdata-explorers-private-runtime.json`. Never upload those private inputs.

| Original blocked input | Current reason handled | Current normalized source SHA-256 |
| --- | --- | --- |
| 공통수학2_2022개정_무리함수그래프탐구_Batch1_BookData_V2_시범.json | typed radical explorer | 79a542162e7e532a4b4b4aa0e2e194e4c4ef8e36a78b87de8f297cd5addfea56 |
| 공통수학2_2022개정_유리함수그래프탐구_Batch1_BookData_V2_시범.json | filename provenance plus typed rational explorer | 8d15645c5ba6188ea5857bca32392a58926b28fb23ba433600cf7d89b9bc2cf4 |
| 수학Ⅰ_2015개정_지수로그누락기준_Batch2_BookData_V2_시범.json | typed power/log explorer | 451aa92e20d06573501127428fd16a4f4373478e7c8c99930e6a95006b30487c |
| 수학상_2015개정_초안/수학(상)_2015개정_태그분권_통합BookData_초안.json | candidate metadata; subsequent tag overflow fixed in author source, not by loosening importer | 12fba22989a725d80a3f5c8c316ba994758426630eaea715808ce12938a74dac |
| 수학하_2015개정_초안/수학(하)_2015개정_태그분권_통합BookData_초안.json | candidate metadata | c2588819c0920b28ec5da74fa1643cf3394a4ab06906276f2df7a599e8fec58d |

First intermediate audit was 186/187: math-upper then failed book.tags >64. The author input changed from historical normalized SHA `baca8a60541b2b8bce4abe31acf7c701025c9ec6989983e88ccae19da2d61328` to the above current snapshot. Current actual file has 54 tags, 25 candidate codes and 0 `candidate-standard:` tag tokens. No author source file was changed in this checkout. Do not retroactively treat the earlier source hash as passing or broaden the tag cap.

## Focused checks

- Initial Python validation/import/public gate suite:57 passed. Expanded prior regression suite:200 passed before two additional huge-integer/bool cases; final new explorer suite22 passed. Re-run totals should be distinguished, not added together.
- Flutter broad selected regression:14 passed before added negative test. Latest explorer + actual private corpus:6 passed including 187-book loop. Scoped analyzer0 after correcting newly added lint statements. Independent code reviewer found no concrete math/domain/pole/state/metadata defect; not a runtime review.
- New metadata migration retains candidate codes in runtime rather than stripping them to annotations; source_metadata still retains other review/provenance annotations. Full source reconstruction remained exact. Absent vs empty candidate arrays are distinct; candidate codes never become confirmed standard_codes.
- Tests and renderer contract: [BOOK_FUNCTION_EXPLORERS.md](../../../deploy/vercel/BOOK_FUNCTION_EXPLORERS.md).

## Browser / deployment gate (corrected synthetic Preview verified)

New QA harness `tools/qa/function_explorer_preview.dart` loads synthetic JSON remotely and real manuscripts on loopback only. All product requests mocked; reader persistence disabled. Remote static staging must include only synthetic fixture and exact fresh build, not APIs/private handlers/private inputs. No alias promotion permitted while live-source closure remains unresolved.

Source HTML rational/power were read fully and locally rendered; mobile original screenshots are ignored under `build/temp/function-explorer-private-evidence/`. No matching radical HTML exists in the inspected author tree; do not invent one. These are comparisons of bounded declared activities, not full historical HTML-source ports. Existing source-family inventory stays3/106 until broader source behavior is separately verified.

Actual 040a20c reader controls were exercised at390/1280 on private loopback inputs and separately on a synthetic-only Preview. Observed coefficient/base changes, domain/asymptote/power readouts, manual guides, hints, power reset, and synthetic resize/reentry restore. This does not establish full keyboard/screen-reader accessibility or every private activity's reset behavior.

Synthetic Preview `dpl_EsYZ6iSYPVMNjmaJig46vq5byn1n`: https://aiflow-web-canary-g31y3bzrs-cw20208021-9200s-projects.vercel.app/ . Actual browser response JS:5,780,578 bytes, SHA-256 `3d3bd19269b19a991934acc61e74e57d6d496a27a4de7adfc6b4db60f4034315`; synthetic fixture SHA-256 `ed69e4db18d0a9f2a7ae3977e60f32d63af78b356f81fe913b429846499ed084`. No API/private manuscript upload or production alias promotion.

Independent visual inspection rejected the power plot endpoint marker: its center lies on the curve clipping boundary, so half the marker is hidden. Preserve the old Preview and `evidence/2026-10-17-function-explorers/preview-power-endpoint-before-1280.png` as failure evidence. A corrected build needs fresh images and response hashes; old captures must not be reused as corrected evidence.

Latest selected regression run: Python202 passed (one upstream Starlette/httpx deprecation warning); Flutter16 passed, including all187 private runtime books. Before the visual fix, the separate endpoint raster regression failed both minimum and maximum exponent checks, matching the actual screenshot. Initial raster test execution stalled under the fake async clock; image conversion was moved into tester.runAsync before this meaningful failing run. After moving restore immediately after the curve path, endpoint2 + explorer5 tests passed (7 total); scoped analyzer0. Independent read-only code review found no concrete save/restore, marker, guide or raster-test defect. Fresh Preview verification is recorded below.

### Corrected build and actual browser evidence

- Fix committed/pushed: `eb5d5d97027f45d91d96362039f7b14cd2a6689f`; all301 exported library files matched that HEAD. D: release build succeeded. A prior interrupted build left generated package routing; the known original config was restored after matching the temporary config hash, then rebuilt with byte-for-byte finally restoration. No unrelated Flutter process was stopped.
- New synthetic-only Preview: `dpl_4o7iNFV69qen4aogmSCyuFnPFCpX`, https://aiflow-web-canary-armuxdj2c-cw20208021-9200s-projects.vercel.app/ . Actual loaded JS5,780,627 bytes, SHA-256 `a83958d02bf753116bc88e2964a87a3167ff7ee8c185d64abada2882326f05d8`, matched local. Fixture SHA unchanged. Both actual responses HTTP200; no disk cache or service worker response.
- Three native pages rendered at1280. Power maximum/minimum markers are full circles at1280; minimum guide and maximum also checked at390. Actual slider selected-2 produced0.25/inverse-2, manual stage1 and hint worked, reset restored base2/exponent2/stage0/hint-off. Resize retained selected state. Fresh images use `fixed-` prefix; old Preview/images remain rejected history, not substituted as fixed proof.
- Independent screenshot review confirmed the endpoint correction and found no new marker/guide overlap. This is a limited visual/functional gate, not all-accessibility or all-source parity. Initial accessibility placeholder click did not enable semantics; pressing Enter did. Slider semantics still expose stale numeric/disabled values despite working pointer/readouts; full keyboard/screen-reader support remains unverified.
- Current-build private manuscript browser recheck was not performed; those real inputs were exercised on040a20c locally, separately from this new synthetic Preview. No private source/handler/API upload, DB write, content publication, price/ownership/approval change or product alias promotion.
- Evidence: `evidence/2026-10-17-function-explorers/fixed-preview-browser-bundle.json` and its listed fixed PNGs. Known pre-existing Cupertino font declaration warning persists; build success does not resolve that warning.

## Product canary boundary rechecked after deployment request

User explicitly chose Preview first, product canary only after source consistency verification. No promotion was attempted.

Direct current alias JS response: HTTP200, application/javascript,7,133,766 bytes, SHA-256 `7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`. Guarded checkout public bundle: `DA4910F2C02651760008559AE811B3B4AEB7780BF5090136404C975FC447F849`. These differ. Do not overwrite the product alias with an unmatched bundle or with the synthetic QA harness. Subsequent lineage inspection identified DA4910 as a later unpromoted build, not an older artifact. Product source closure and content-publication approvals remain separate unresolved gates; see 2026-10-17-canary-source-closure.md.
