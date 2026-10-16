# BookData V2: coordinatePoint — direct manipulation, not a static graph

## Source evidence and scope

Read entire inventory sources `html-3050dd8407807a29`
(`중등수학_좌표와순서쌍_체험형_시범.html`, current SHA256
`4235767CFF3D3BBBEA8585712BE8B3F35FAA791D4DC74E7594A3EA1AED568D9E`)
and `html-7bbc2e50f5387d53` (2015 ordered-pairs prototype).

The first is this batch's source case: integer x,y sliders-5..5, initial(-2,3),
direct circle pointer capture/drag snapped to the grid, arrow keys, quadrant/axis
and directional readout, reset, three manually advanced movement explanations.
The button named animation is NOT timed in this first source. Its separate
multiple-choice/hint/exercise material can be represented with existing quiz,
hint and text blocks; it is not silently discarded or auto-migrated here.

Second source also has coordinate swap and a1500ms reduced-motion-aware walk
animation; neither is claimed implemented by this new kind. No JSX/JSXGraph
dependency is used in either selected source. Native CustomPaint is a bounded
scene representation, not execution of the original script.

Original first source labels(0,0) as y-axis because x==0 is checked first. Native
corrects this to origin explicitly. Native has a48x48 point hit target and adds
authored optional hints/session snapshots; not pixel-identical HTML appearance.
Do not label either whole original manuscript ported/reviewed/published.

## Declarative contract and versioning

```json
{"schema_version":2,"title":"Synthetic coordinates","chapters":[{
 "title":"Explore","pages":[{"id":"p","title":"Move A","template":"experiment",
 "blocks":[{"type":"activity","activity":{
   "id":"point-a","kind":"coordinatePoint","prompt":"점 A를 움직여 보세요.",
   "x":-2,"y":3,"hints":["먼저 가로, 다음 세로입니다."]
 }}]}]}]}
```

- Additive registered BookData V2 kind. Required x,y JSON integer tokens-5..5;
  common bounded nonempty id/prompt and up to8 hints. No imported scene state,
  output/quadrant/step, callback, executable expression, HTML, JS or JSX.
- Structural JSON Schema: `book_coordinate_point.schema.json`. JSON Schema
  mathematically treats2.0 as integer; authoritative Python/Dart validators are
  deliberately stricter and reject decimal tokens for cross-runtime parity.
- Server parse_import validates definitions before persistence; source SHA and
  owner-scoped idempotency route unchanged. No new API/server-side state writes.
- V1 rejects activities, old V2 rejects unknown registered kinds. Deploy compatible
  validator and renderer before real imports; never flatten into a static point
  or discard interaction to force an old reader to accept it.
- Existing graph function/line/scatter/expression/parameter JSON paths unchanged.
  Python contract test checks exact retained graph payload; Dart checks canonical
  V1/V2 round-trip plus all three types, expression and parameter values.
- Migration is explicit source->new V2 authored definition+companion blocks, with
  original/source digest, review, curriculum and rights manifest retained. No
  original overwrite, automatic manuscript rewrite or publication in this batch.

## Parameter, state, output and functions

| Name | Meaning / lifetime / side effects |
|---|---|
| BookCoordinatePoint.fromJson | Strict x/y definition ->immutable point, FormatException on invalid input |
| bounded/move | Internal pointer/key movement ->clamped integer grid coordinate; no formula evaluation |
| quadrant/horizontal/vertical | Derived current point text; origin is distinct from axes, axes not quadrants |
| _point | Current user coordinate; initially definition then drag/key/slider, reader session only |
| _step |0..2; manually cycles live coordinate explanation; never a timer/animation |
| _hints | Revealed hint count; reset/content replacement clears |
| _drag | Plot RenderBox globalToLocal ->grid rounding, y-axis inversion and bounds; only point handle starts drag |
| _key | Arrow key down/repeat ->one cell, handles event to prevent page scroll; other keys ignored |
| _focus/_plot | Disposable FocusNode and current plot key,48px hit target; no focus/RNG/timer exported |
| _PlanePainter | Grid, axes, tick labels, current A label; point handle is a real semantic/focusable widget, not paint-only |
| BookActivityKeyScope | Definition-fingerprinted x/y/step/hints snapshot above responsive shells; reader lifetime only |

Dragging outside the point does not capture the full graph, preserving page
scrolling. Native pan recognizer handles touch/mouse end/cancel. Reset restores
authored coordinate and stage1/no hints. Account/book changes clear reader state;
reload/disposal does not persist it to disk or server.

## Validation and staged boundaries

New backend21 tests:121 valid coordinates, invalid numeric/null/bool/unknown
payloads, forbidden scripts/learner state, structural schema bounds, exact import
and existing V1 graph preservation, V1 activity rejection. Backend focused total
115 passed, existing Starlette/httpx warning1. New Flutter4 tests: strict payload,
quadrants/axes/origin, clamped movement, V1/V2 legacy graph canonical preservation,
both actual touch and mouse drag, key, stage/hint/reset and absent-frame snapshots.
Golden uses existing NotoSansKR font. Scoped analyze5 items:0 issues.
This does not prove deployed backend persistence, full screen-reader usability,
source appearance parity, manuscript approval, clean full app or production use.

## Nine-family implementation sequence (not completion claims)

| Family | Current bounded support | Next independently gated batch |
|---|---|---|
| cartesian_point_drag | coordinatePoint integer grid direct drag/key/stages | Review each curve-constrained scene before extending; no generic onDrag callbacks |
| parameter_dependent_metrics | rightTriangle only | One reviewed derived metric/domain at a time, numeric invariant tests |
| vector_transformations | None | Resolve source2u/-2u equal-length content issue first, then bounded vector scene |
| conics_3d_distance | Existing parabolaDistance p/x and distance view only | Constraint-specific dragging/3D definition and accessible equivalent |
| set_relation_diagrams | None | Source-specific finite-set relation model and operation checks |
| algebra_area_partitions | None | Bounded partitions/number lines/sequence scenes with linked outputs |
| calculus_scenes | None | Review secant/tangent/integral scope and domain math before schema |
| timed_statistical_trajectories | discreteExperiment counts only, no trajectory | Bounded timed curve with play/stop/dispose/reduced-motion tests |
| adaptive_socratic_sequences | Independent quiz/steps are not adaptive dialogue | Explicit reviewed state/branch contract and actual provider/teaching QA |

All106 source assets remain not_ported pending explicit author mapping and full
educational/math/rights review. A reusable seventh kind is not106 published books.
