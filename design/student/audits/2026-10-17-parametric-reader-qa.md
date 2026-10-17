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
