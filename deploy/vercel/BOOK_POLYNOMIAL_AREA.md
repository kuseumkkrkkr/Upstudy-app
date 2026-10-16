# BookData V2: polynomialArea

## Reviewed source / contract

- Source asset: `html-d2b300ca0f76adab`, `중학수학3-1_2022개정_통합시범/중학수학3-1_2022개정_다항식넓이모형_체험형_시범.html`.
- Current SHA-256: `9FC6663E58368D8DD25D4AE9E2DEA8D9EED0DA10D9C702BE72689460550046EF`. The older 106-asset inventory is historical, not proof this hash was ported.
- Actual HTML has two integer range controls `a,b=1..8`, initial `3,2`; displays `x²+(a+b)x+ab`. Its SVG is **static**, with a rectangle `(25,25,110,90)` partitioned at `x=80,y=70` in a 240×150 viewBox. It has no piece dragging, geometric measurement, timer, AI, network call or grading. Do not claim these missing behaviors were present in this source.
- Actual companion BookData experiment page `ms31-22-polynomial-product-experiment` only instructs users to open the external HTML. This patch adds an explicit native candidate; it does not replace interaction with text.

```json
{"type":"activity","activity":{"id":"example","kind":"polynomialArea","prompt":"Compare the expansion","a":3,"b":2,"hints":[]}}
```

- Existing schema-version-2 activity slot and BookActivity dispatch are reused. `a,b` must be JSON integers 1..8; reject booleans, strings, decimals, null, unknown executable/answer fields. V1 activities still reject.
- Native preserves the controls, exact integer coefficients and static partition geometry. Permanent value/readout text plus 44px decrease/increase controls provide the keyboard/accessibility path; the slider still supports pointer input. No arbitrary author HTML/JS or math evaluation is accepted.
- A reset button and schematic disclaimer are explicit native additions. The reader's existing bounded vertical scroll keeps all content accessible on smaller pages. This is behavioral parity for one source, **not whole-book pixel parity**.

## Migration / storage boundaries

- `python -m tools.migrate_polynomial_area --source-book <original> --source-html <reviewed HTML> --output build/temp/<new-private-candidate>.json`.
- Guarded D: hotfix only; output is an exclusive-create file under ignored `build/temp`. Originals are never rewritten. Any changed HTML hash requires re-review.
- Exactly one matching experiment-page ID is required. Existing blocks/order/review metadata remain intact; a registered activity is inserted after the first block. Repeating the same definition is idempotent; a conflicting existing activity fails. There is no guessed migration from unrelated static visuals or HTML script transpilation.
- Original BookData SHA, HTML SHA, page ID, kind and `publication_approved:false` remain under `metadata.native_activity_migrations`. `prepare` preserves author metadata as source annotations and validates runtime content. This is not a review approval.
- `migrate(source, html_source)` accepts the original JSON text and HTML bytes, not caller-supplied hashes. Both provenance digests are computed from those inputs; duplicate/nonfinite/invalid original JSON rejects before transformation. A changed JSON source changes the recorded digest.
- Authenticated structured create and exact-source import both validate/persist/return the activity through their existing owner-scoped paths. Tests exercise both in-memory routes, read-after-write and V1 rejection. No new database schema, student answer persistence, price or publication path is introduced.
- Definition uses existing immutable BookActivity two-integer fields (`legA/legB` internally) and serializes the original `a/b` keys. Learner state is session-only and definition-bound via BookActivityKeyScope, not included in source JSON or grades/OVR.

## Functions / variables

| Unit | Responsibility / lifecycle |
| --- | --- |
| `validate_activity` / `BookActivity.fromJson/toJson` | Same strict domain on server/native; preserve registered definition; reject unknown fields. |
| `BookPolynomialAreaView` / `_AreaState` | Definition → local `_a/_b` → exact sum/product text; restore only matching reader definition; reset on definition change. |
| `_control` | Pointer slider or bounded 44px buttons → one integer local update; no network. |
| `_AreaPainter` | Same source viewBox/partition lines at every coefficient; no inferred proportional geometry. |
| `migrate` | Copy exact candidate, preserve original blocks/reviews, append registered activity and source hashes; no public eligibility. |
| Reader TOC row | Minimum height, rather than fixed height, allows long real chapter titles to wrap without overlapping adjacent rows. |

## Verification limits

- Source HTML, actual private pre/post candidate, and synthetic external Preview are separate evidence sets. Actual manuscript body/screenshots stay in ignored D: temporary files, never in Git/static upload.
- Broader drag/measurement/3D/sets/calculus families remain open. `polynomialArea` is not a generic algebra engine or full HTML converter.
- PostgreSQL metadata/RLS read-only evidence is separate from actual API persistence/concurrency testing. A synthetic Preview is not production readiness or content publication.
