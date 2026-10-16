# BookData V2: plane-vector inner product

`vectorInnerProduct` ports the bounded plane-vector magnitude/angle activity from source asset `html-2a9ff578cf62178d`. It uses native Flutter controls and rendering; it does not load the source HTML or execute its JavaScript.

```json
{
  "id": "inner-product-1",
  "kind": "vectorInnerProduct",
  "prompt": "각도와 크기를 바꾸며 내적의 부호를 예상하세요.",
  "hints": [],
  "u_length": 3,
  "v_length": 4,
  "angle_deg": 60
}
```

- Vector magnitudes are integers from 1 through 5.
- Included angle is 0–180 degrees in 15-degree steps.
- JSON Schema: `book_vector_inner_product.schema.json`; Python and Dart validators also enforce the same bounds.
- The reader shows vectors, signed projection, inner-product value, sign-prediction feedback, three guided stages, progressive hints, and reset.
- Practice state remains local to the reader session; it is not submitted for exam grading or score/level updates.
- Migration of source manuscript activities and production publication are pending. This kind does not represent 3D products, arbitrary equations, or basis transformations.

Validation: 25 Python activity tests and 10 Flutter activity tests passed; scoped Dart analysis reported no issues. A cumulative synthetic BookWidget preview is deployed at [`https://aiflow-web-canary-r4bwrt9l9-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-r4bwrt9l9-cw20208021-9200s-projects.vercel.app), deployment `dpl_EUk9KVpNSFmsiTvCBiRzbhX4pemW`. The browser-loaded bundle SHA-256 equals the local build: `E41E10F8A9F602D935461B10E97A21170BA7119AC64BBD4B786F90574CF429E1`. The actual BookWidget displayed the 60-degree sign quiz and accepted “양수”; the next stage showed signed projection 2.00. Preview API routes are disabled. This is synthetic UI evidence, not a migrated manuscript or production publication.
