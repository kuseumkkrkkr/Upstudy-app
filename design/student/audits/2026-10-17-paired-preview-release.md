# Paired BookData Preview — 2026-10-17

**Preview deployed; production not promoted. Real authenticated acceptance blocked.**

- URL: https://aiflow-web-canary-n5qif8eif-cw20208021-9200s-projects.vercel.app
- Deployment: `dpl_WkGwc5S69b5sHtYmvpr7emjv61My` (`READY`, target null).
- Source: `074e01a0c51d9c65867e1412f40bf6ae108e7e3a`, pushed to `origin/hotfix`.
- Build: Flutter 3.44.6 / Dart 3.12.2, release, 105.7 seconds, D: output only.
- Defines: `API_BASE_URL=` (same origin), `STUDENT_SERVICES_DEMO=true`,
  `STUDENT_STORE_DEMO=true`.
- All **311 exported lib files** matched committed source; unrelated dirty
  checkout files were not used for package imports. Original package routing was
  restored byte-for-byte after build and tests.
- JavaScript: **7,268,062 bytes**, SHA-256
  `8a388a5b8674db00732ab54d48516c7b89577b9f6319314885652bfd7fdd125b`.
  The actual browser response matched this byte count/hash, HTTP 200, neither
  disk cache nor service worker. `READY` alone was not used as proof.
- Paired deployment includes committed API modules, fresh static output, and
  eight existing live content/admin files plus the measured dependency manifest.
  Exact upload-input hashes are in `paired-preview-release-proof.json`.
  No private manuscripts, new public publication bundle, environment files, or
  credentials were uploaded. No DB data was changed.

## Verification

- Working-tree focused suites: 27 catalogue/create/storage/session tests,
  34 reader/tutor/graph/activity/default-origin tests, 1 explicit Preview-origin
  contract test; all passed. These counts overlap the independent rerun below.
- **32 regressions rerun with package imports bound only to the exported
  committed lib source: all passed.**
- Python public textbook/create/import/tutor suites: 66 passed; one dependency
  deprecation warning. Real DB concurrency and real AI delivery not established.
- Six-file catalogue/storage/create scoped analysis: no issues. Reader/chat
  scoped analysis: one warning, 25 style infos, zero errors; not a clean full
  analyzer gate. Build retained the baseline Cupertino font warning.
- Actual browser at 390×844: login rendered; signup button opened profile step;
  login return worked. At 1280×900: landing and login dialog rendered; dialog
  close worked. No credentials or final signup were submitted.
- `/health`: HTTP 200 JSON. `/health/ready`: HTTP **503** JSON,
  `SUPABASE_URL과 SUPABASE_SERVICE_ROLE_KEY가 필요합니다`.
  Anonymous shell requests encountered Vercel deployment protection; their
  HTTP-200 login HTML was explicitly **not** counted as API success. The above
  API checks used the existing authenticated browser session.

## Production preservation and next step

The production alias still serves 7,133,766-byte JavaScript with SHA-256
`7f54ee1424f0982d6c2f461c4744eaadd7954602487576f9c08eca2e9db340b8`,
unchanged after Preview deployment. The pre-deploy alias API check reported
`dpl_HTYscDjA8dNT521Pjf91UeqJsaF2`. No promote/alias operation was run.

Preview-specific Supabase access is required before real login, library
acquisition, persistence, and tutor acceptance. Production secrets were not
copied or broadened to Preview. Obtain human direction on that access rather
than marking authentication or commercial readiness complete.

Evidence: `evidence/2026-10-17-full-preview/` (mobile login/signup, desktop
landing/login). This is smoke testing, not 86-screen parity or HTML/Dart
three-way comparison proof. Full-source activity ports and new parametric
formats from another checkout are not included or claimed.
