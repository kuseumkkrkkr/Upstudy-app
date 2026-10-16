# polynomialArea: synthetic Preview verification

## Release identity

- Source commit: `42d81aedd376bfa032a1e5af74eb4adcc5506ce2`, guarded D: `Upstudy-hotfix`, branch `hotfix`.
- All 297 exported library files matched this commit before the build. Flutter 3.44.6 / Dart 3.12.2; release, no-pub, no-wasm-dry-run, no-web-resources-cdn. Target: `tools/qa/polynomial_area_preview.dart`.
- Final output: `build/polynomial-area-final-preview`; static staging: `build/temp/polynomial-area-static-deploy`. 69 uploaded files, no API, manuscript JSON, source archive or credentials. Existing CupertinoIcons font warning remains; full font parity is not claimed.
- Deployment: `dpl_Dsonb44LLYcr94YVF4iJP4VKQc83`.
- Preview: https://aiflow-web-canary-2maqb5knj-cw20208021-9200s-projects.vercel.app/
- JS: **5,757,385 bytes**, SHA-256 **`18ad0dc02274a37445b11362209048afad8df481cf864a1dfed2bef7cae81570`**.
- Browser Network response: HTTP 200, `application/javascript`, disk cache false, service worker false. Actual response bytes match local compilation, not merely the URL/READY status. Machine-readable evidence: `evidence/2026-10-17-polynomial-area/preview-browser-bundle.json`.
- Unauthenticated HTTP clients receive **Login – Vercel** HTML at both normal and query-suffixed JS URLs. That HTTP 200 is not a bundle match. Existing Preview protection was not disabled; verification used the already authenticated browser. No fallback/asset mapping defect was established.

## Executed checks

| Scope | Observed result |
| --- | --- |
| Synthetic mobile 390×844 | Initial a=3,b=2 → x²+5x+6; keyboard Enter a=4; b button to 8 → x²+12x+32; increment disabled at upper bound; reset restores 3,2. |
| Inner reader scroll | Disclaimer and reset become fully visible; no permanent footer loss. |
| Synthetic desktop 1280×900 | Activity, static partition diagram, TOC and next-page control render. Top and scrolled captures are distinguished. |
| Authored synthetic quiz | 7 produces the supplied incorrect feedback, 8 produces “정답입니다.”. Correct feedback captured at both viewports; no score/OVR or AI request. |
| Existing graph regression | Actual Tab/Shift+Tab keyboard navigation focuses the iframe range. Right changes x=1→1.1: f=-0.19, f′=-1.8; after mobile resize Right changes x=1.2: f=-0.36, f′=-1.6. Both graph and readouts update. |
| Graph isolation | Actual iframe `sandbox=allow-scripts`, `referrerpolicy=no-referrer`. No allow-same-origin. |
| Existing root regression | Eight increment clicks change n=1→9, displayed √9=3 and number-line marker. |
| Actual private manuscript candidate | Frozen candidate A60A3C… loaded only through loopback port 9011, p10/30. Long TOC titles now wrap in growing rows without the previous overlap. Original source and private screenshots not uploaded. |
| Independent visual reviewer | Five captures reviewed read-only; TOC overlap resolved, equation/diagram/controls/quiz readable, mobile footer accessible via scroll. Image review does not substitute for interaction tests. |

Early locator input to the fractional iframe timed out; coordinate wrapper rejected its input. Raw key injection was unsupported. Those attempts are not passes. Ordinary Tab/Shift+Tab/Right navigation subsequently succeeded; no script-set values or synthetic DOM change events were used. Touch-swipe gestures and every pointer route remain unverified.

## Repeatable checks

```powershell
python -m pytest tests/test_book_polynomial_area.py tests/test_book_right_triangle.py tests/test_book_coordinate_point.py tests/test_book_coordinate_walk.py tests/test_book_statistics_estimator.py tests/test_book_activity_v2.py tests/test_square_root_number_line.py tests/test_public_textbooks.py tests/test_textbook_import.py tests/test_book_activity_source_inventory.py tests/test_book_activity_curated_inventory.py -q
flutter test --no-pub --no-test-assets --packages=.dart_tool/graph-staged-packages.json test/book_polynomial_area_test.dart test/book_square_root_number_line_test.dart test/textbook_create_api_contract_test.dart test/bookdata_author_compatibility_test.dart
```

- Python **156 passed**, one existing Starlette/httpx deprecation warning.
- Flutter **12 passed** after the fixed-frame TOC pump update. Geometry assertions unchanged; the test waits for layout rather than unrelated animation quiescence.
- Earlier focused analyze passed; whole-app analyze/tests and 200-way real DB concurrency are not claimed.
- The package snapshot routing and build wrapper are local helpers; they restore the original package configuration byte-for-byte after build. No concurrent Flutter commands ran during that build.

## Production and content boundaries

- Rechecked existing canary: `dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`; JS **7,133,766 bytes**, SHA-256 **`7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`**. Unchanged after Preview deployment. No alias command executed.
- HEAD/working `public/main.dart.js` is a different old bundle (`DA4910F2…`). Promoting the synthetic harness or a stripped clean-HEAD full app would not preserve the current live UI. First reconcile the live source closure and selectively reviewed dependencies; do not replace production to manufacture deployment completion.
- Live Supabase read-only metadata evidence: KV RLS true; anon/authenticated direct access false/false; service SELECT/INSERT true/true; primary key (user_id,key). This is not actual API durability/concurrency proof.
- No publication approval, ownership, price, manuscript body, product DB or security permissions changed. Synthetic quiz is not real AI grading.
- Historical inventory remains **1/106 private candidate locally verified, 105 unreviewed, 0 publicly published/production verified**. Nine unsupported families remain open. This checkpoint is not completion of the full interaction migration or commercial readiness.

## Evidence / resume

- Public synthetic captures under `evidence/2026-10-17-polynomial-area/`: `preview-before-390.png`, `preview-after-initial-390.png`, `preview-after-a4-b8-scrolled-390.png`, `preview-after-top-1280.png`, quiz/graph/root regression captures.
- Private original HTML / old Dart / candidate Dart comparisons stay under ignored `build/temp/polynomial-private-evidence/`. `dart-after-toc-fixed-1280.png` supersedes the earlier TOC-overlap image. Frozen original JSON SHA `2AD04504…`, candidate `A60A3C43…`; later author edits are separate snapshots.
- Next bounded task: reconcile the deployed app source closure before full-app candidate promotion; choose the next exact source/hash from the interaction-family backlog. Do not mark unrelated sources complete or publish pending manuscripts.
