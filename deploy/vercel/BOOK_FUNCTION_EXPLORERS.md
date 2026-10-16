# Bounded function explorers and provenance compatibility

## Contracts

Three V2 kinds use a numeric `explorer` object, never arbitrary formulas, HTML or JavaScript. Original author model/view definitions were read in the Upstudy-app reference checkout; implementation is adapted into the existing hotfix activity slot and reader-session state, not copied wholesale from that branch.

| kind | fixed formula | exact payload keys |
| --- | --- | --- |
| radicalFunctionExplorer | y=sqrt(a*x+b)+c | a_values, initial_a, min_b, max_b, b_step, initial_b, min_c, max_c, c_step, initial_c |
| rationalFunctionExplorer | y=a/(x-h)+k | a_values, initial_a, min_h, max_h, h_step, initial_h, min_k, max_k, k_step, initial_k |
| logarithmPowerExplorer | y=a^x, inverse reading log_a(y)=x | bases, initial_base, min_exponent, max_exponent, initial_exponent, step |

- Every key is required; unknown root/nested keys, missing fields, booleans/string numerics, duplicate choices, non-finite or out-of-range values reject. V1 still rejects activities.
- Coefficient choices: 2..6, absolute value .1..5; initial must be a choice. b/c/h/k endpoints and initial bounded +/-10. Step >0 and <=1; 1..400 integer divisions; initial lies on the declared grid. These are explicit safety bounds, not executable author expressions.
- Power bases: 2..8 distinct values >0, <=100, not within 1e-9 of 1. Exponent range within -4..4, same grid rule. All base/end-exponent results must be finite within 1e-6..1e6. No overflow/underflow substitute value is displayed.
- `BookFunctionExplorer` has immutable numeric fields and enum `BookFunctionKind`; `valueAt` returns null for negative radicands, poles or nonfinite outputs. `toJson` restores each original kind's field names.
- Reader dropdown/sliders update formula/readouts and manually guided graph. Changing a control resets the guide; reset restores authored defaults and hides hints. All guide steps are manual; no autoplay, timer or external request. Hints show authored hints where supplied, otherwise bounded fixed-formula guidance.
- Same book/activity/full-definition reader-session restoration uses existing BookActivityKeyScope. Definition change resets controls/guide/hint. No disk, server, student grade or OVR writes.
- Deliberate corrections relative to the reference views: rational h is horizontal translation, not vertical; radical formula has no extraneous closing brace; graph window follows valid declared ranges/translation rather than clamping a selected value into an unrelated fixed window. Rounded readouts use approximation signs. Do not claim exact historical HTML pixel parity.

## Provenance metadata

Importer/create contracts were independently committed as `c83cdb0` and `2d41372`. `candidate_standard_codes` is optional (max32 strings, each <=80 chars) at book/chapter level, not an alias for confirmed `standard_codes`. `source_html_reference` is optional chapter filename token <=240 chars, nonempty, not dot/dotdot and containing no slash/backslash/colon. It is never fetched, linked or executed.

BookData/BookChapter now preserve these fields in parse/create/serialize paths. Absent and explicit empty lists remain distinct. Migration no longer strips chapter candidate codes into side annotations: they remain explicit runtime metadata, while other existing author annotations/review states remain in source_metadata. Reconstructing the original from runtime+annotations must still equal the input. No publication approval is derived from these names.

## Responsibilities / state

| symbol | responsibility / lifetime |
| --- | --- |
| validate_explorer | Server numeric contract check; returns unchanged validated object or ValueError, no I/O |
| BookFunctionExplorer.fromJson / toJson | Typed exact-key decoding/encoding; FormatException on bad data, immutable lifetime of definition |
| valueAt(x, coefficient, u, v) | Fixed formula evaluation; numeric coordinates, null outside domain, no author evaluator |
| coefficient | Authored choice (a or base); screen/session state |
| u / v | b,c or h,k; power u is exponent and v unused; source units, bounded sliders |
| stage / hint | Manual guide index0..3 / hint visibility; reader session only |
| _FunctionPainter | Finite sampled curve with domain/pole breaks and clipped plot; redraw on controls/guide/theme/definition change |
| _readCandidateCodes / _readSourceHtmlReference | Dart named provenance validation; no network/storage/approval side effect |

## Verification boundaries

Synthetic fixture `test/fixtures/function_explorers.json` is safe for a unique static Preview; actual manuscript payloads and source HTML remain loopback/private only. Product requests are mocked and reader persistence disabled in the QA harness. This is not the product app or a canary promotion.

Run guarded Python validation/migration tests, Dart positive/negative/roundtrip/widget tests, full current author corpus audit and `bookdata_private_corpus_roundtrip_test.dart` with the ignored generated runtime fixture. The private test skips without that local fixture; a skipped test is not corpus verification. Actual browser screenshots and bundle hash must be recorded separately.
