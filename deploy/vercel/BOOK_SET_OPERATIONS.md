# BookData V2 setOperations

- Reviewed source asset `html-244e439259c143b2`: `공통수학2_집합과명제_체험형_시범.html`, SHA-256 `E485B82083D57703F0A3E4C4EAE8A3E344A1873F2F31AC5C891E355F3E24C70C`.
- Source behavior: U={1,2,3,4,5,6}, initial A={1,2,3}, B={3,4,5}, intersection selected. Twelve membership checkboxes; intersection/union/A-minus-B/complement; highlighted regions, element locations, result and explanatory status update. An independent fixed-case true/false quiz has authored correct/incorrect feedback. No point dragging, timer, AI grading or network.
- Native activity retains those operations and definition-bound reader-session state. Existing registered quiz carries the separate fixed-case question, not a question derived from the learner's current A/B. Reset is a native addition.
- Native diagram uses the same 640×330 universe/circle geometry. Element positions use y=120+22×slot, keeping all six inside their assigned region. Source positions y=105,145,185,225,265,285 can put later elements outside their stated circle: this is an explicit correctness repair, not exact pixel parity. Native universal box has square corners to match existing reader vocabulary; selected regions share amber highlight rather than source operation-specific tints. Membership/result behavior must match; whole HTML visual parity is not claimed.

```json
{"id":"sets","kind":"setOperations","prompt":"Explore sets","universe":[1,2,3,4,5,6],"set_a":[1,2,3],"set_b":[3,4,5],"operation":"intersection","hints":[]}
```

## Contract and responsibilities

| Unit | Input/output and state |
| --- | --- |
| `validate_activity` / `BookSetOperations.fromJson` | Explicit integer universe 1..6; unique member lists drawn from it; four registered operation names. Reject booleans, decimals, unknown/executable keys, invalid membership. |
| `BookSetOperations.result` | Two sets and operation -> sorted universe-order result; no mutation, expressions or I/O. All 4,096 A/B combinations tested for all four operations. |
| `BookActivity.fromJson/toJson` | Existing V2 activity slot, immutable member lists and exact definition round-trip; no new schema version or V1 acceptance. |
| `_SetState` | `_a/_b` local Set<int>, `_operation` local String from definition; checkbox/operation/reset changes; reader-scope restore only for identical complete definition. No student/OVR/server persistence. |
| `_VennPainter` | Copies current sets, computes bounded path intersection/union/difference, renders current memberships. No author SVG/JS execution; Semantics exposes diagram membership/result text. |
| `migrate` | Exact source JSON+reviewed HTML bytes -> private V2 candidate; preserves original blocks/sections/annotations and appends registered activity+quiz. Changed source hash/conflicting partial insertion rejects. |

Checkbox targets are 48×48; operations wrap; results use live semantics. Reader's existing inner scrolling accommodates the full activity; keyboard/pointer verification must be recorded separately from tests.

## Explicit migration

`python -m tools.migrate_set_operations --source-book <original JSON> --source-html <reviewed HTML> --output build/temp/<new-name>.json`

- Guarded D: hotfix only, exclusive-create ignored output, no author changes. Original must pass strict import validation first. Explicit schema upgrade adds no inferred answers: the fixed-case quiz and answers are read from the reviewed HTML.
- Exactly one `common-math-2-sets-experiment` page required. Original lead/question/hint/answer/misconception and sections retained. Added quiz is independent; old explanation is not silently removed.
- Provenance records original JSON digest and exact HTML hash, with `publication_approved:false`. This is not teacher/math/curriculum approval or a public bundle.
- Actual candidate and source screenshots stay local; Preview target contains only synthetic book/quiz. Localhost-only HTTP loader is not a product endpoint or storage test.

## Remaining limits

This is one bounded two-set source, not general relation diagrams, arbitrary universes, symbolic set expressions or all 106 interactive assets. No automatic folder-wide migration or publication. Real database durability/concurrency, commercial readiness and full-app production promotion require separate evidence.
