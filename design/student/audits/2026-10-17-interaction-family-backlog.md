# Interactive textbook family ledger

Starting source: D: hotfix `ad4a763`; `origin/hotfix` matched at inspection. The 106-HTML inventory is a historical static inventory, **not** 106 verified ports or the current author-folder count. Current author files may have changed; verify exact hashes before each port. No original author files are edited here.

| Priority | Family | Current bounded support | Remaining status / next evidence |
| --- | --- | --- | --- |
| P1 | Existing graph / number-line regression | Existing observation cursor, safe graph expressions, squareRootNumberLine | Recheck in the same synthetic Preview as polynomialArea; no inference of full graph-source parity. |
| P1 | parameter_dependent_metrics | rightTriangle; new polynomialArea; graph observation readouts | Other formulas/measurements unreviewed. Read exact source render/event paths before choosing a registered payload. |
| P1 | cartesian_point_drag | Integer coordinatePoint/coordinateWalk | Curve constraints and other point dragging remain unported; source/gesture comparison required. |
| P2 | algebra_area_partitions | New polynomialArea: a,b integer 1..8, expansion, source-static partition | Private candidate and local reader verified for one hash only. Other partition HTML and any piece dragging are not covered. |
| P2 | vector_transformations | Add/subtract/scalar and inner product/projection | Matrices, basis/affine changes and 3D remain unsupported. |
| P2 | conics_3d_distance | Existing bounded parabolaDistance | Other conics and 3D distance scenes need explicit source review/contracts. |
| P2 | set_relation_diagrams | No verified native family port | Select/hash one actual HTML and compare controls, set membership and rendering before implementation. |
| P2 | calculus_scenes | Function graphs/cursor only, not complete scenes | Tangent/area/limit scene behaviors remain open; no static-text substitution permitted. |
| P2 | timed_statistical_trajectories | discreteExperiment, statisticsEstimator | Timed trajectories/confidence/hypothesis-test behavior not covered by those kinds. |
| P2 | adaptive_socratic_sequences | Local quiz and steps, not adaptive pedagogy | Adaptive branch rules/history/feedback remain unsupported; avoid claiming that sequential hints are Socratic adaptation. |

Each family remains open until exact source controls, state transitions, bounds, animation/stop behavior, keyboard/pointer operation, definition round-trip and actual reader evidence are recorded. Global `all_sources_ported`, `live_v2_persistence_verified`, `clean_source_release_verified` remain false. No eligible textbook publication is inferred.

Inventory checkpoint: **1/106** explicitly mapped to a private, locally verified candidate; **105/106** retain `source_review_required_not_ported` and unresolved manuscript mapping. **0/106** are marked publicly published/production-verified. Only `html-d2b300ca0f76adab` is updated. Its frozen source-book hash is `2AD04504AE5171561D84D933012393A04E03DA09F30C156FF47B0ACE514714F5`; later author edits are separate snapshots and do not retroactively change this evidence. Preserve curated per-asset verification when regenerating a static inventory; a fresh signal scan is not a behavioral re-review.

## polynomialArea checkpoint

- Schema/model/renderer reuse the existing V2 activity slot. See `deploy/vercel/BOOK_POLYNOMIAL_AREA.md` for exact source hash and limits.
- New explicit private migration preserves all old blocks/reviews and computes both original JSON and HTML hashes from original input bytes/text; callers cannot supply an arbitrary provenance hash. CLI exclusive-create output remains under D: `build/temp`.
- Focused Python regression: 153 passed. Focused Flutter after TOC fix: 12 passed, including full polynomialArea file, round-trip, controls/remount/reset and long TOC row bounds. The independently reported pumpAndSettle timeout did not recur in this run; no expectation was weakened to accept it.
- One initial broader Flutter run failed against an unrelated uncommitted `bookLoader` test contract; this was not counted as a pass. A later asset-manifest copy collision occurred in shared generated assets; no assets/dependencies changed, and rerun with `--no-test-assets` compiled the selected Dart snapshot and passed all 12 tests. Full app test pass is not claimed.
- Independent visual review found a long-title TOC overlap and an ambiguous clipped activity footer. TOC fixed to minimum/variable heights and regression-tested. Actual mobile reader scrolling exposed the complete disclaimer/reset, so the footer was not removed or hidden. Touch-event CDP injection is unavailable; that attempt is not a successful touch-swipe test.
- Actual before/after candidate screenshots and original HTML captures remain private under `build/temp/polynomial-private-evidence`; candidate SHA-256 `A60A3C4328946098B0B02B079D08535A906A0D74BB084928263E642B45C310C7`. No author manuscript or private screenshot is uploaded to Git/Vercel.

## Production boundary observed before deployment

- Production alias: `https://aiflow-web-canary.vercel.app/`, deployment `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`, underlying `aiflow-web-canary-hvv457edo-cw20208021-9200s-projects.vercel.app`, READY.
- Production JS: 7,133,766 bytes, SHA-256 `7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`.
- Local working and HEAD `public/main.dart.js` both hash `DA4910F2C02651760008559AE811B3B4AEB7780BF5090136404C975FC447F849`, not the current production bundle. Deployment inspection exposed no gitCommitRef/gitCommitSha/gitDirty. Do not promote a reconstructed HEAD build as if it preserved the currently live UI without reconciling the base.
- Actual Supabase project `aybqetiydxafeuzudltb`, SQL editor read-only SELECT: KV RLS **true**, anon/authenticated any direct table access **false/false**, service SELECT/INSERT **true/true**, primary key **(user_id, key)**. No user row read or DB write was needed. Cropped metadata-only screenshot retained locally; this does not prove endpoint read/write durability or multi-connection concurrency.
- Initial DSN-based preflight could not establish that configured `DATABASE_URL` targeted this project and deliberately did not connect. Browser SQL supplied the actual project-specific read-only evidence instead.
- Next release gate: deploy only a fixed synthetic Preview first; verify its own source/hash/controls/pages at 390 and 1280, separately from production. Evaluate promotion only after the live-source/UI baseline is reconciled. Keep publication approvals and prices unchanged.

## Synthetic Preview checkpoint

Preview `dpl_Dsonb44LLYcr94YVF4iJP4VKQc83` now has matching local/browser JS hash and actual 390/1280 activity, quiz, graph cursor and root regression evidence. Python 156 / Flutter 12 passed on the repeated focused checks. Actual private manuscript TOC overlap was rechecked fixed. See [Preview report](2026-10-17-polynomial-area-preview.md). Production alias is unchanged; 105 sources, nine broader families, clean full-app release and real persistence/concurrency remain open. Synthetic Preview success does not change those verdicts.
