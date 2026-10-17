# Parametric reader compatibility — local synthetic QA

Scope: D: `Upstudy-hotfix`, `hotfix`; no Supabase, production alias, private
manuscript publication, or other-branch source copying. This is an independent
implementation; `e4d11e0` / `aa12ec0` are not incorporated commits. Their original
2015 manuscript package has not been verified by this synthetic fixture.

## Graph interface

`type: "parametric"` adds `xExpression`, `yExpression` (arithmetic in `t`),
finite `tMin < tMax` within ±1e9, and optional `traceParameterId` referencing a
coefficient slider in `settings.parameters`. A coefficient named `t` is rejected
for this graph type. Trace slider bounds must lie inside the domain. Existing
function/line/scatter wire fields remain unchanged. The reader parses and
serializes these fields; the generic graph editor has no parametric authoring UI.

| Unit / field | Responsibility, input, output and lifetime |
| --- | --- |
| `AiFlowGraphItem` new optional fields | Authored expressions/domain/trace ID; immutable book model, JSON and copy preserved |
| `compileGraphMath(..., variableName)` | Existing bounded arithmetic parser; default `x`, parametric calls use `t`; no eval/Function |
| `parametricGraph(item, settings)` | Produces sampled finite segments and optional runtime `{t,x,y,slope}`; no storage or author-model mutation |
| `traceParameterId` / `parameterValues` | Authored slider reference and iframe-local current numeric value; updates on actual slider input |
| `validate_expression(..., variable)` | Server AST allowlist, default `x`; parametric `t` validates both coordinate expressions |
| `validate_graph` | Rejects unsupported code, nonfinite/bool bounds, unknown/out-of-domain trace references |

JSXGraph and canvas fallback consume the same sampled segments, trace point and
readout. Slope uses bounded finite differences, is labelled approximate and
rounded to three decimal places. Near-zero dx/dt shows `정의되지 않음`, never a
fabricated zero or infinity. Sampling is bounded at 401 points; jumps over two
viewport spans split segments. This prevents the tested `1/(t-0.003)` asymptote
bridge, **not arbitrary symbolic continuity certification** or exact geometry.

## Existing activity reuse

The existing `parabolaDistance` activity already covers basic
`y=x²/(4p)` point dragging, p/x sliders, focus/directrix distances and drawn
segments. Existing `quiz` covers fixed numeric/fraction/tolerance and choice
answers. Dynamic answers linked to current drag values, expression grading,
translated/rotated general parabolas remain separate unimplemented contracts.
No duplicate parabola activity was added.

## Checks so far

- Flutter graph/parser/security/reader/activity focused suite: **18 passed**.
- Six changed graph/QA files scoped analysis: **no issues** after fixing one new
  harness brace-style info. This is not full-repository analyze approval.
- Python parametric/import regression suite: **32 passed**, one existing
  dependency deprecation warning.
- Node executes the actual shared JS: u=1 gives (1,2), slope≈2; u=2 gives
  (4,10), slope≈3.25; u=0 yields undefined slope. Bad expressions/ranges rejected.
- Read-only independent review confirmed boundaries and the asymptote guard;
  it did not execute the UI.

Pending: committed-source QA build, loopback actual BookWidget slider operation,
390/1280 screenshots, emitted bundle/fixture hashes and console inspection.
This synthetic extension has no equivalent approved HTML fixture; captures are
functional evidence, not HTML/before/after three-way design parity.

### First actual-browser failure and QA-only fix

The first 85849b4 build (JS `8d996a6c7f20c0f87ead5b51b44de46504931d6d68f692a1df50231d8dd62f49`)
booted but correctly showed the private reader's login-required state. It is
**rejected as graph UI evidence**. `persistenceEnabled:false` disables saving,
not the private reader's session requirement; the initially suspected missing
book identifier alone was not the cause.

The loopback-only harness now supplies a fixed local book ID and the existing
`setTokenForTest` in-memory non-JWT identity, with all product HTTP requests still
mock-blocked. No production reader/authentication code changed; the identity is
not persisted and disappears when the QA app is reloaded/closed. A new actual
BookWidget smoke test verifies the graph card appears, no login-required notice,
and zero product requests. It passed; live slider verification remains pending
until the corrected release bundle is rebuilt and inspected.

Serve the compiled web directory with a static server, and copy the committed
fixture to its root as `synthetic-parametric-reader.json`. Flutter SPA fallback
HTML is not an acceptable JSON response. The QA entry is
`tools/qa/parametric_reader_preview.dart`; only host `127.0.0.1` is accepted.

### Working reader and responsive state regression

The 7d85b19 build (`d888efd4a471efe7701bfc8a28bdd64ef0b88b0cfabe9ea42a1326dbe3a0e155`,
5,108,400 bytes) matched the actual browser response, no cache/service worker.
The served JSON was application/json with SHA-256
`f49d51176664eb30eadad8aa93ed9db77166700a99dc4ddd9e96cdfde34f86ed`.
Actual keyboard slider input produced u=1 → (1,2), slope≈2; u=2 → (4,10),
slope≈3.25; u=0 → (0,0), undefined slope. Mobile screenshots were saved.

Resizing to desktop then recreated the iframe and reset u to 1. This is not a
responsive-state pass. The reader now seeds a new iframe using a validated
renderer-only copy of current-page observations; authored values are untouched,
and the existing page/book/session clearing and source-bound callbacks remain.
`graphWithObservedParameters` rejects invalid observations and returns the
original document in that case. The focused graph/smoke/account-overlay rerun
passed **9 tests**; helper/test scoped analysis reported no issues. Corrected
bundle and actual resize verification remain pending until the next rebuild.

## Final bounded local result (supersedes the pending rebuild items)

- Code source: `3e52bdd8e747e1326bbc04b5bd2d3d18036eb7e7`, `hotfix`.
- Committed lib snapshot: 312 files verified; D: release build completed in
  64.5 seconds. Package routing restored byte-for-byte afterward.
- Actual browser JS: **5,108,877 bytes**, SHA-256
  `d8447fba9b1ea46db4d5c64bbaf2abc8c07ba59750c47ca70bd2e38553588192`,
  matching local output; HTTP 200, not disk cache/service worker.
- Actual fixture response: HTTP 200 application/json, unchanged SHA-256
  `f49d51176664eb30eadad8aa93ed9db77166700a99dc4ddd9e96cdfde34f86ed`.
- At 390×844, actual iframe input changed u=1→2, point (1,2)→(4,10),
  approximate dy/dx 2→3.25. At u=0, undefined slope is explicitly displayed.
- Mobile u=2 survived transition to 1280×900; desktop u=0 survived transition
  back to 390×844. Original authored initial value remains 1.
- Normal-mode locator click moved the actual range to 0; a real keyboard End
  moved it to 2. With Flutter semantics enabled, pointer locator clicks were
  intercepted by a semantics overlay; keyboard/input interaction worked, but
  accessibility-mode pointer behavior needs manual follow-up. Do not mark full
  accessibility acceptance passed.
- Observed browser console errors: 0. Exploratory raw event history was evicted;
  this is not a complete runtime-event audit. Bundle/JSON hashes were collected
  again from fresh responses. Captured boot responses contained no product API
  response; the synthetic transport blocks all ApiClient product HTTP calls.
  The native smoke test recorded zero product requests. No real DB/AI operation
  or external authentication was performed.
- Browser metrics/cache override restored. Loopback viewer:
  http://127.0.0.1:9017/ . Evidence is under
  `evidence/2026-10-17-parametric-reader/`; `source7d` images/proof retain the
  earlier working-but-resetting build, other images describe the final build.

### Still not accepted

The other task reported a different `parameterRange`/`rawTypeName`/`extensionData`
contract. Those fields were not present in the original hotfix graph model;
this work did not delete them from this worktree or copy another branch's model.
Compatibility with that other contract and its original manuscripts is **not
established**. Current strict import rejects unsupported fields rather than
silently publishing a lossy conversion. Reconcile the actual data contract and
round-trip fixture before any full-corpus compatibility or deployment claim.

No Vercel Preview update, canary promotion, DB write or publication was performed
in this local graph QA phase. Paired Preview/Supabase readiness was not
revalidated in this phase. A final canary download still matched the prior
7,133,766-byte `7f54ee1424f0982d6c2f461c4744eaadd7954602487576f9c08eca2e9db340b8`
bundle. Existing Cupertino font build warning and broader reader
analyzer/style debt are not declared resolved.

## Canonical manuscript compatibility follow-up (local, not deployed)

This supersedes only the earlier `parameterRange` compatibility gap, not the
full-manuscript/publication gate. Input was read as JSON only; no other
checkout's Dart source was used or copied.

- Read-only candidate canonical UTF-8/LF SHA-256:
  `52ce6477321ce3584e495cf9b7ade69c3a6095c3be8592caaf1889558a300de0`.
- 27 chapters / 17 graph blocks: all graph blocks pass strict server validation.
  Whole-book validation still **fails** at `chapter: unsupported fields: unit`.
  This is not an import/publication success; later unsupported structures may
  remain behind that first error. Source was not copied or stored in this repo.
- Canonical `parameterRange: {id,min,max,step}` drives the independent variable
  (`u` in the candidate). Legacy fixed-`t` `tMin/tMax` remains supported.
  Simultaneously supplied aliases must agree. Invalid identifiers, non-finite
  bounds, invalid steps, executable expressions and out-of-domain traces reject.
- Graph document/item/settings/viewport/parameter extension fields are preserved
  as data. Unknown item types retain their wire name and do not become executable
  functions. The UI reports unsupported types; server import still rejects
  unapproved fields/types. Preservation is not execution/publication approval.
- Runtime observation copies preserve extension metadata and author defaults.
  Readout uses the actual independent-variable name rather than always `t`.
- Python graph/import suite: **43 passed**, one existing dependency deprecation
  warning. First focused Flutter suite: **9 passed**, including canonical/unknown
  metadata checks. The expanded candidate/metadata rerun hit Dart compiler
  **out-of-memory**; its result is not a pass. Single-concurrency retry was then
  attempted, then cancelled during compilation under memory pressure (about
  1.1 GB physical/virtual headroom observed). Expanded tests and scoped analysis
  remain pending; no unrelated process was terminated. Do not infer a new
  browser/bundle pass from the prior screenshots.
- Added `tools/qa/check_bookdata_graphs.py`: mandatory expected canonical hash,
  read-only structural audit, zero writes; returns nonzero on book/graph errors.
  `test/fixtures/canonical_parametric_reader.json` is an independent synthetic
  cubic fixture, not the supplied manuscript.

Next: finish the expanded Flutter tests and scoped analysis when memory permits;
build a committed-source local QA bundle and verify canonical slider/readout and
responsive retention in the browser. Keep canary/Preview/Supabase unchanged.
