# BookData V2 registered activity: rightTriangle

## Source and bounded scope

Actual source read fully, with current hash verified against inventory:
`html-a10eb6a3240af7e0`,
`중학수학2-2_2022개정_통합시범/중학수학2-2_2022개정_피타고라스정리_체험형_시범.html`,
SHA256 `E8662454327247D3406A8BAA5780F40DF3BDC40825BD5B4FC58BAEA838B305E6`.
Source controls a,b integer sliders1..12, initial6,8; live sqrt(a*a+b*b) to2
decimals. Its SVG triangle is static, with right-angle marker. No chat, graph
library, timer, random sampling, external script, grading or saved answers.
Original explicitly says teacher review pending; this implementation is NOT
permission to publish that manuscript. Inventory remains not_ported.

Native implements those bounded controls/calculation and a proportional
right-triangle diagram, keyboard sliders, text equivalent, live result, reset and
optional authored hints. Proportional geometry/reset/hints are native additions,
not claims of pixel-identical source HTML. No arbitrary expressions/eval/JS/HTML.

```json
{"type":"activity","activity":{
  "id":"pythagoras-explore","kind":"rightTriangle",
  "prompt":"두 직각변을 바꾸며 빗변을 비교하세요.",
  "a":6,"b":8,"hints":["두 직각변의 제곱의 합을 확인하세요."]
}}
```

## Schema / import / migration policy

- Additive registered kind within existing schema_version2. BookData V1 still
  rejects activity blocks. No silent V1 upgrade, kind fallback or source mutation.
- Both a,b required JSON integers1..12. Reject decimal6.0, booleans, strings,
  null, NaN/infinity/out-of-range/unknown fields, imported c/learner state/scripts.
- Existing common id/prompt/hints limits apply. Python validate_activity and
  Dart BookActivity.fromJson/toJson have the same field/domain contract.
- Import source SHA/owner-idempotency route unchanged; validators run before
  persistence. Old V2 implementations reject this unknown kind: deploy compatible
  backend AND renderer before authoring/publishing books requiring this kind.
- Migration is explicit author mapping from the verified source to a NEW V2
  candidate retaining educational text, review/source metadata and behavior
  requirements in its external manifest. Do not execute or embed source scripts;
  do not overwrite old reviewed/immutable originals or mark106 assets ported.
- Nine broader unsupported families remain. This is only one bounded part of
  parameter_dependent_metrics, not a generic algebra/graph engine.

## Function and variable responsibilities

| Name | Input/result/effects |
|---|---|
| validate_activity rightTriangle branch | Definition ->same validated definition or ValueError; no writes |
| BookActivity.fromJson/toJson | Definition <->immutable legA/legB; no c/user state serialized |
| _TriangleState.build | Local a,b ->sqrt(a²+b²), exact squared equality,2decimal text and diagram |
| slider onChanged | Keyboard/pointer ->integer local leg; rebuild result, no network |
| _reset | Initial definition legs; clears revealed hints |
| _TrianglePainter.paint | Same scale for both legs; right-angle marker and triangle; no interaction/network |
| _a/_b | Positive integer length units,1..12; reader lifetime; source defaults then user slider |
| _hints | Revealed hint count; reader-lifetime snapshot, reset/content replacement clears |

Reader BookActivityKeyScope retains a/b/hints with complete-definition check
through absent frames/breakpoint remount. Book/account replacement/disposal clears
reader state. No disk/server answers, exam score, OVR, OCR or chatbot calls.

## Verification scope

Backend18 new tests cover strict cross-language bounds, forbidden fields, V2
import/hash preservation and V1 rejection. Existing focused backend regression
total94 passed (existing Starlette/httpx warning1). New Flutter definition and
interaction tests cover6/8->10,3/8->8.54, keyboard input, hint, absent-frame restore,
reset. Golden uses existing licensed bundled NotoSansKR and waits for animation
settling; it is a regression baseline, not original HTML appearance parity.
Actual original manuscript and production publication remain unverified/pending.
