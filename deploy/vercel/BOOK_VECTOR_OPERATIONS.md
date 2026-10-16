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
- Reader sliders change the values; four guided stages show the arrows; hints are progressive.
- A pause/remount within the same reader can restore the current definition, stage, and hint count. No student record, grade, or remote persistence is written.
- The feature covers 2D addition, subtraction, and real scalar multiplication. It does not cover matrices, basis transformations, affine maps, or 3D vectors.

## Status

Registered in the Python import validator and Dart `BookActivity` model. Focused checks passed (22 Python cases, 8 Flutter cases, scoped analyzer clean). A synthetic BookWidget preview was deployed to [`https://aiflow-web-canary-p4y8qq92y-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-p4y8qq92y-cw20208021-9200s-projects.vercel.app), deployment `dpl_3zefUAqnaVcpNAw2rnajnHWbNU2z`; browser-loaded `main.dart.js` SHA-256 matched the local bundle: `01C91B16F6D83277A762E34B789EDE18731473C96F7E595096C03B7EB911D36E`. The preview runs the dropdown from scalar to addition and displays `(3, 0)`. Its API routes are intentionally disabled. This verifies the synthetic preview, not manuscript migration or production publication. The capability ledger remains authoritative for the latest state.
