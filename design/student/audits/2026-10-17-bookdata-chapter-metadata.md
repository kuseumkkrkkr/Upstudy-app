# BookData chapter metadata checkpoint

- Scope: importer and native BookData round-trip compatibility only. No pricing, permissions, production publication, database writes or canary alias changes.
- Source checkout: guarded D: Upstudy-hotfix, hotfix; starting HEAD `48668051f4c04ab7f3b9af39896819ea1f342545`.
- Preserve chapter `tags` and `standard_codes` independently of book tags. Server limits: 64 tags / 32 standard codes, each at most 80 characters. Absent values remain empty; serialized empty lists are omitted.

## Validation

- Current local author inventory: 166 files, 165 importer/reconstruction passes, 1 blocked. This inventory is not the historical frozen 152-file snapshot; author files have changed.
- Local in-memory API/security regression tests: 61 passed (one existing Starlette/httpx deprecation warning).
- Native Flutter corpus/model/renderer/widget tests: 12 passed, using the selected-index library snapshot and current private 165-book fixture.
- Private report: `build/temp/bookdata-chapter-metadata-audit.json`, SHA-256 `B31DD47B2CB3C7668EDE5672D492983EA4D96F9CAA729853390F9DEBA07FD812`.
- Private fixture: `build/temp/bookdata-chapter-metadata-private-fixture.json`, SHA-256 `742C04F7986F4B505D9C1852C9BED75A159A7B44425B8281B2B203C21383F046`. Not committed or uploaded.

## Remaining blocker / next task

- `중등수학_2015개정_함수그래프_부분초안/중등수학_2015개정_함수그래프_BookData_V2_시범.json`, source SHA-256 `594e4a7315b9c17a1f7d923679f29cf53e6158799d27648838671e00f170071d`.
- `/chapters/5/pages/1/blocks/1/graph/items/0/expression` uses `a*x^2`, but its graph settings declare no coefficient `a`. Strict parser reports `graph.expression: unknown identifier`.
- Author generator `tool/build_middle_school_linear_functions_2015_candidate.py` supplies the expression without parameters. Author must specify the intended coefficient default/range/step and regenerate; do not invent those values in the importer or disable identifier validation.
- Cross-thread author contact awaits direct human authorization. Source tree remains read-only.
- After correction: inspect exact new hash and parameter settings; rerun import/reconstruction and native BookData corpus tests; exercise the actual activity locally and a copyright-safe synthetic equivalent in a new Preview. Current checkpoint does not claim new browser verification or deployment.
- Publication still requires per-file rights and teacher approval. Compatibility passes do not grant publication eligibility.

## Responsibility map

| Code | Responsibility / lifecycle |
| --- | --- |
| `validate_book` | Validate optional chapter metadata at the server input boundary; reject oversized lists/strings. |
| `BookChapter.tags`, `standardCodes` | Immutable author-supplied chapter metadata, loaded from JSON for the book lifetime. |
| `BookChapter.fromJson` / `toJson` | Read and preserve chapter metadata through runtime serialization; no network or storage side effects. |

Unrelated dirty work, including the pre-existing AppDrawer deletion, is preserved.
