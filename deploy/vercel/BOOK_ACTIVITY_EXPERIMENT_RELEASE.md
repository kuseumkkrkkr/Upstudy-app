# Native experiment release evidence

## Source and local verification

- D: guarded hotfix only; source checkpoint `79af5fbd9cd7ee54a5cfac77df74670d6751f729`, pushed and remote SHA verified.
- Python55 passed (one existing Starlette deprecation warning); Flutter11 passed
  with concurrency1, including absent-frame remount, actual reader responsive
  counters/hints/quiz feedback and book replacement reset. Scoped analyze7:0.
- Actual candidate 24-page JSON SHA `6F20989F43BD809CE7C825636696A9DB293F8C589F5DE63B5F083027C64BDF7E`:
  locally rendered at33/37 and34/37. No candidate manuscript/server write.
- Actual screenshot hashes (under `design/student/audits/evidence/2026-10-16-book-activity-capabilities/`):
  - `candidate-reader-after-390.png`: `0616E1B1C0A568788666B7998D29AEB3E20F59F192E170AE033957050E25609B`.
  - `candidate-reader-after-1280.png`: `3A0EEAD63DA79106FE8FBD036AB9804A9B0EB469D8A28A95E36322D463CCD2C0`.
  - `candidate-quiz-after-390.png`: `1B4B10ABB9F1C7BAB32A062A8E34B1B6E2C5D80CCE4A4323915E18568227FED0`.
- Complete working source snapshot (local only, excludes env/credentials/cache):
  `build/temp/discrete-experiment-source.tar`, SHA256
  `516B3FCE0C6B0E91CA3485407222DA24AE1D2E96A1A007A1A999D025A0AF0E85`.
  Existing unrelated dirty source remains uncommitted; HEAD alone does not
  reproduce the complete integration build. This is explicitly not a clean-tree release.

## Frozen release build

- Flutter3.44.6 / Dart3.12.2, Node24.18.0, VercelCLI56.5.0.
- `flutter build web --release --no-pub`, API_BASE_URL canonical canary;
  STUDENT_SERVICES_DEMO=true, STUDENT_STORE_DEMO=true. Final build149.7s passed.
  Existing missing Cupertino font warning remains; not an all-warning-free build.
- Generated build/web synchronized to public. main.dart.js7157176 bytes,
  SHA256 `DA4910F2C02651760008559AE811B3B4AEB7780BF5090136404C975FC447F849`.
- Previous public bundle `A31C64AE83873141DCE1942F969C2A4CAA75D001A05A33B9D77B0CE38D96F2BD`;
  canonical served bundle before deployment `7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`.
- Dry-run inspected119 files; no private credentials, reader-defines JSON or
  candidate manuscript included. build/tool/design/source assets are excluded
  by .vercelignore. Public contains app runtime, not the local QA entrypoint.

## Deployment gates

- Standard Preview READY `dpl_B7eo2ZPyR5TypsehzHG3seFdvwwW`:
  https://aiflow-web-canary-8mgr29ja9-cw20208021-9200s-projects.vercel.app
  target=null, aliases=[] from deployment API. GitRef/GitSha/GitDirty fields
  were unavailable in the inspected metadata; not asserted from missing values.
  Public artifact commit `36e48ffd5bae7d162ab23b2d6ee9e71d706b5dd2`, pushed.
- Real authenticated browser booted the current AIFlow welcome UI. CDP network
  main.dart.js response body7157176 bytes SHA256
  `DA4910F2C02651760008559AE811B3B4AEB7780BF5090136404C975FC447F849`,
  exactly matching local public. Capture `preview-boot.png` in capabilities evidence.
  This verifies code bundle/boot, not remote manuscript UI or live persistence.
- Unauthenticated HttpClient followed Preview protection to an HTML200 response
  (333927 bytes), NOT JavaScript. Its different hash is not a deployed-bundle
  mismatch; only authenticated browser network bytes were used as bundle proof.
- Alias listing after Preview still maps canonical and secondary project URL to
  `aiflow-web-canary-hvv457edo-cw20208021-9200s-projects.vercel.app`.
  Canonical main.dart.js remains7133766 bytes SHA256
  `7F54EE1424F0982D6C2F461C4744EAADD7954602487576F9C08ECA2E9DB340B8`.
  No aliases were changed by this Preview deployment.
- Preview has no independent DB/JWT environment configuration. No Production
  secrets copied. Build-time API URL still points canonical; Preview API storage
  cannot be claimed verified. Never promote an env-empty Preview to Production.
- Production/canary code release is authorized, but earlier --prod --skip-domain
  unexpectedly changed a secondary generated alias. Resolve domain assignment
  behavior or report that exact blocker before repeating the production path.
- All106 source HTML migrations, full parity, actual PostgreSQL concurrency,
  live V2 private persistence and teacher/rights review remain incomplete.
  Legacy deletion0; student records unchanged; manuscripts not published.
