# AIFlow Graph API

`AIFlow Graph` is a math-only graph workspace with curated CSAT examples, file-explorer style formula loading, variable-driven practice controls, and a minimal graph viewport.

## Scope

This session currently targets:

- single-variable function graphs such as `sin(x)`, `x^2-1`, `sqrt(9-x^2)`, `log(x)`, and `ln(x)`
- coordinate line plots
- scatter plots
- parameterized practice graphs such as `a*(x-h)^2+k`, `m*(x-x1)+y1`, and `A*sin(B*x+C)+D`
- formula and example discovery through the concept file explorer modal
- curated subject examples for:
  - `수학 상`
  - `수학 하`
  - `수학 1`
  - `수학 2`
  - `미적분`
  - `기하`
  - `확률과통계`

Out of scope:

- full Desmos expression grammar
- folders, notes, regressions
- persistent saved graph documents
- arbitrary symbolic transformations

## Public Dart API

Use these value objects to describe a graph scene before building HTML:

```dart
const document = AiFlowGraphDocument(
  items: [
    AiFlowGraphItem(
      id: 'expr-1',
      type: AiFlowGraphItemType.function,
      label: 'y = sin(x)',
      colorHex: '#2F7CF6',
      enabled: true,
      expression: 'a*sin(b*x)+c',
    ),
  ],
  settings: AiFlowGraphSettings(
    showAxes: true,
    showGrid: true,
    lockViewport: false,
    degreeMode: false,
    viewport: AiFlowGraphViewport(
      left: -8,
      right: 8,
      top: 8,
      bottom: -8,
    ),
    parameters: [
      AiFlowGraphParameter(
        id: 'a',
        label: '진폭 a',
        value: 1,
        min: -4,
        max: 4,
        step: 0.25,
      ),
      AiFlowGraphParameter(
        id: 'b',
        label: '주기 계수 b',
        value: 1,
        min: 0.25,
        max: 4,
        step: 0.25,
      ),
      AiFlowGraphParameter(
        id: 'c',
        label: '상하 이동 c',
        value: 0,
        min: -4,
        max: 4,
        step: 0.25,
      ),
    ],
  ),
);

final html = buildAiFlowGraphHtml(document);
```

## Data Contract

`AiFlowGraphDocument`

- `items`: ordered list of renderable graph items
- `settings`: graph-level display and interaction flags

`AiFlowGraphItem`

- `id`: stable client id
- `type`: `function`, `line`, or `scatter`
- `label`: editor label
- `colorHex`: stroke color in `#RRGGBB`
- `enabled`: whether the item is rendered
- `expression`: function text when `type == function`
- `xValues`, `yValues`: numeric series when `type == line` or `scatter`

`AiFlowGraphSettings`

- `showAxes`: show or hide axes
- `showGrid`: show or hide grid
- `lockViewport`: disable pan and zoom interactions
- `degreeMode`: use degree-based trig evaluation
- `viewport`: initial and reset bounds
- `parameters`: practice variables injected into expression evaluation

`AiFlowGraphViewport`

- `left`, `right`, `top`, `bottom`: numeric bounds

`AiFlowGraphParameter`

- `id`: expression variable name such as `a`, `m`, `h`, `k`, `mu`, or `sigma`
- `label`: student-facing slider label
- `value`: current numeric value
- `min`, `max`: slider bounds
- `step`: slider interval

## Expression Validation

Use `validateAiFlowExpression()` before applying direct user input.

Current normalization rules:

- strips leading `y =`
- normalizes `PI` to `pi`
- normalizes `E` to `e`
- accepts `^` for powers
- treats `log(x)` as base-10
- treats `ln(x)` as natural logarithm
- accepts supplied parameter values through `parameters`

Validation is sample-based and is used to guarantee that curated modal examples render without runtime input failures.

```dart
final result = validateAiFlowExpression(
  'a*(x-h)^2+k',
  parameters: {
    'a': 1,
    'h': 0,
    'k': 0,
  },
);
```

## Subject Catalog API

`aiFlowGraphCatalog` exposes per-subject bundles:

- `subject`
- `overview`
- `formulaSearchTip`
- `sourceLabel`
- `sourceUrl`
- `formulas`
- `examples`

`AiFlowGraphFormulaSummary`

- `title`
- `formula`: LaTeX source shown through the formula renderer in the explorer
- `summary`

`AiFlowGraphExample`

- `id`
- `subject`
- `unit`
- `title`
- `summary`
- `searchTerms`
- `sourceLabel`
- `sourceUrl`
- `document`

Examples can include `settings.parameters`. When present, the student editor shows practice sliders and rebuilds the graph continuously as values change.

Helper lists:

- `aiFlowGraphExampleSubjects`
- `aiFlowGraphExamples`

## Renderer Behavior

- Only the graph and zoom controls are shown in the viewport.
- Initial view and reset view both use `settings.viewport`.
- Wheel and pinch zoom are enabled unless the viewport is locked.
- Zoom sensitivity is reduced with `factorX` and `factorY` set to `1.08`.
- Parameter ids are injected into the JSXGraph expression scope before each function is sampled.
- Platform views are kept stable across updates to avoid repeated mouse tracker assertions.

## Student Editor Behavior

- The info modal is a pure file explorer: subject/unit tree, formula files, example files, and a detail pane.
- Formula text in the modal is rendered as LaTeX instead of plain text.
- Subject guide cards, search command hints, and source summary blocks are intentionally hidden from the student modal.
- The editor can add a new expression even after every existing expression has been deleted.
- Function inputs include a calculator keypad for common graphing tokens such as `sqrt()`, `sin()`, `cos()`, `tan()`, `log()`, `ln()`, powers, parentheses, and operators.

## Formula Extraction Tip

Do not read the entire `s11_teacher/lib/models/concept_textbooks.dart` file for formula discovery.

Extract only inline math fragments wrapped by `$...$`:

```powershell
rg -o '\$[^\$]+\$' 's11_teacher\lib\models\concept_textbooks.dart' -n
```

This is the intended way to discover search seeds such as:

- `$A(x_1, y_1)$`
- `$m$`
- `$y-y_1=m(x-x_1)$`

## Sources Used For Subject Summaries

- `수학 상`, `수학 하`: `https://mathbang.net/699`, `https://mathbang.net/443`, `https://mathbang.net/454`
- `수학 1`: `https://mathbang.net/724`
- `수학 2`: `https://mathcloud.tistory.com/7`
- `미적분`: `https://mathcloud.tistory.com/12`
- `기하`: `https://mathcloud.tistory.com/14`
- `확률과통계`: `https://mathcloud.tistory.com/13`, `https://mathbang.net/112`
- zoom option reference: `https://jsxgraph.org/docs/symbols/JXG.Board.html`

## Integration Notes

- Web uses a persistent `iframe` with `srcdoc` updates.
- Native uses a persistent `InAppWebView` and `loadData()`.
- The renderer depends on `https://jsxgraph.org/distrib/jsxgraphcore.js`.
- Keep all file I/O in UTF-8.
