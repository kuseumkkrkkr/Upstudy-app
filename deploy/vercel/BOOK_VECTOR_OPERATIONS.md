# BookData V2: plane vector operations

`vectorOperation` ports the bounded plane-vector activities found in the two indexed geometry HTML demos (`html-002d8074c7ebb2fb`, `html-5f1d5700e9fa1fc1`). It is a native Flutter reader interaction. Source HTML/JavaScript is not loaded or executed.

## Contract

```json
{
  "id": "vector-1",
  "kind": "vectorOperation",
  "prompt": "Explore the operation",
  "hints": [],
  "operation": "scalar",
  "ux": 1,
  "uy": -1,
  "vx": 2,
  "vy": 1,
  "alpha": 0.5
}
```

- `operation`: `add`, `subtract`, or `scalar`.
- Vector components are integers in `[-4, 4]`.
- `alpha` is a finite half-step in `[-2, 2]`.
- JSON Schema: `book_vector_operation.schema.json`; Python and Dart validators also enforce the same bounds.
- Reader sliders change the values; four guided stages show the arrows; hints are progressive.
- A pause/remount within the same reader can restore the current definition, stage, and hint count. No student record, grade, or remote persistence is written.
- The feature covers 2D addition, subtraction, and real scalar multiplication. It does not cover matrices, basis transformations, affine maps, or 3D vectors.

## Status

Registered in the Python import validator and Dart `BookActivity` model. Focused tests and scoped analyzer pass. The cumulative synthetic BookWidget preview is [`https://aiflow-web-canary-r4bwrt9l9-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-r4bwrt9l9-cw20208021-9200s-projects.vercel.app), deployment `dpl_EUk9KVpNSFmsiTvCBiRzbhX4pemW`; browser-loaded `main.dart.js` SHA-256 matched the local bundle: `E41E10F8A9F602D935461B10E97A21170BA7119AC64BBD4B786F90574CF429E1`. The preview changes the operation dropdown and displays `(3, 0)`. Its API routes are intentionally disabled. This verifies a synthetic preview, not manuscript migration or production publication. The capability ledger remains authoritative for the latest state.
