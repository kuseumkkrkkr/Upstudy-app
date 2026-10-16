# Untagged recursive BookData: conservative curriculum candidate audit

This audit covers the 43 recursive BookData files that lack an exact official standard token in `curriculum_version`/standard fields or tags in the scope inventory. It records candidate links only; it does not add tags or change source content. A candidate link is not a coverage claim, approval, eligibility decision, or release authorization.

## Method and limits

- For the 29 explicitly tagged 2015 `수학(상)/(하)` drafts, candidate codes come from the separate [`2015_HIGH_SCHOOL_MATH_CONTENT_AUDIT.md`](2015_HIGH_SCHOOL_MATH_CONTENT_AUDIT.md), which maps integrated chapter topics to the official 2015 standards. Individual draft files do not themselves establish the exact code. Partial matches remain flagged.
- Five other files explicitly name 2015 and have a strong subject/topic candidate. The code was checked against local official 2015 Appendix 8 extraction (`work/official-curriculum/2015_appendix8_math.txt`); course placement and page completeness still need review where stated.
- Files without explicit edition evidence are left unresolved, even when a filename or subject title resembles a known course.
- No code tags were written into these files. Applying any candidate tags should follow page-level math and curriculum review; do not convert these links into verified coverage.

## Results

- Candidate link recorded: 31 files (includes partial and review-pending links).
- No direct match in the current 2015 상·하 audit: 3 files.
- Edition/criterion unresolved: 9 files.

| Recursive source BookData | Classification | Candidate official code(s) | Evidence / limitation |
|---|---|---|---|
| `고등수학_기하_평면벡터내적_BookData_V2_시범.json` | 2015 candidate; page/course review pending | 12기하02-04 | 2015 tag + inner-product chapter title; official 2015 criteria are locally extracted. Candidate only. |
| `고등수학_확률과통계_이항분포_BookData_시범.json` | Unresolved | — | Edition is not established; a 2022-scope reference tag is not edition evidence. |
| `공통수학2_유리함수_BookData_시범.json` | Unresolved | — | Tag explicitly says edition comparison pending. |
| `공통수학2_집합과명제_BookData_시범.json` | Unresolved | — | Edition is not established; product/topic title alone is insufficient. |
| `대수_등비수열_BookData_시범.json` | Unresolved | — | Standard mapping and edition are both pending. |
| `미적분_2015개정_수열의극한_BookData_시범.json` | 2015 candidate; page/course review pending | 12미적01-01 | 2015 tag + sequence-limit topic. Do not extend to 01-02 without page evidence. |
| `수학Ⅱ_2015개정_정적분과넓이_BookData_시범.json` | 2015 candidate; page/course review pending | 12미적03-05 | 2015 tag and area-under-curve activity; this is an adjacent calculus criterion, not a Math II code. Verify course placement. |
| `수학Ⅱ_도함수부호와증감_BookData_시범.json` | Unresolved | — | Tag says 2015 candidate, not confirmed edition; code not compared. |
| `수학상_2015개정_초안/수학상_2015개정_거리와중점_BookData_초안.json` | 2015 상·하 topic candidate | 10수학02-01; 10수학02-02 | 02-02 is partial: current source title only covers distance/midpoint, not internal/external division points. |
| `수학상_2015개정_초안/수학상_2015개정_근과계수의관계_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-08 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_나머지정리와인수정리_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-03 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_다항식의덧셈과뺄셈_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-01 | Partial scope: title names addition/subtraction while official criterion says arithmetic operations. |
| `수학상_2015개정_초안/수학상_2015개정_도형의이동_BookData_초안.json` | 2015 상·하 topic candidate | 10수학02-08; 10수학02-09 | 02-09 is partial: verify which symmetry cases are actually covered. |
| `수학상_2015개정_초안/수학상_2015개정_무리방정식_BookData_초안.json` | No direct candidate | — | No direct topic match in the current 41-code 상·하 audit; do not infer a code from adjacent coverage. |
| `수학상_2015개정_초안/수학상_2015개정_복소수_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-05 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_복소수범위의이차방정식_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-06; 10수학01-07 | Topic/title candidate for roots/discriminant; verify both concepts in pages. |
| `수학상_2015개정_초안/수학상_2015개정_분수방정식_BookData_초안.json` | No direct candidate | — | No direct topic match in the current 41-code 상·하 audit; do not infer a code from adjacent coverage. |
| `수학상_2015개정_초안/수학상_2015개정_삼차방정식_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-12 | Partial: official criterion includes cubic and quartic equations; this file is cubic only. |
| `수학상_2015개정_초안/수학상_2015개정_연립이차방정식_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-13 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_연립일차부등식_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-14 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_원의방정식_BookData_초안.json` | 2015 상·하 topic candidate | 10수학02-06 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_원의접선_BookData_초안.json` | 2015 상·하 topic candidate | 10수학02-07 | Topic/title candidate; verify line-circle position relation coverage. |
| `수학상_2015개정_초안/수학상_2015개정_이차방정식과이차함수_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-09; 10수학01-10; 10수학01-11 | 01-10/11 are partial candidates in the existing audit; this source may cover only equation/graph relation. |
| `수학상_2015개정_초안/수학상_2015개정_이차부등식_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-16 | Partial: official criterion also includes relation to quadratic functions and simultaneous quadratic inequalities. |
| `수학상_2015개정_초안/수학상_2015개정_인수분해_BookData_초안.json` | 2015 상·하 topic candidate | 10수학01-04 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_직선과원의위치관계_BookData_초안.json` | 2015 상·하 topic candidate | 10수학02-07 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_직선의방정식_BookData_초안.json` | 2015 상·하 topic candidate | 10수학02-03 | Topic/title match; still needs page-level and math review. |
| `수학상_2015개정_초안/수학상_2015개정_평행수직직선_BookData_초안.json` | 2015 상·하 topic candidate | 10수학02-04 | Topic/title match; still needs page-level and math review. |
| `수학하_2015개정_초안/수학하_2015개정_경우의수기본원리_BookData_초안.json` | 2015 상·하 topic candidate | 10수학05-01 | Topic/title candidate; verify both sum and product rules in pages. |
| `수학하_2015개정_초안/수학하_2015개정_명제와조건_BookData_초안.json` | 2015 상·하 topic candidate | 10수학03-04 | Partial: quantified statements (“all/some”) are not evidenced in existing page audit. |
| `수학하_2015개정_초안/수학하_2015개정_무리함수_BookData_초안.json` | 2015 상·하 topic candidate | 10수학04-05 | Topic/title candidate; verify domain and graph requirements. |
| `수학하_2015개정_초안/수학하_2015개정_순열_BookData_초안.json` | 2015 상·하 topic candidate | 10수학05-02 | Topic/title match; still needs page-level and math review. |
| `수학하_2015개정_초안/수학하_2015개정_여집합과차집합_BookData_초안.json` | No direct candidate | — | No direct topic match in the current 41-code 상·하 audit; do not infer a code from adjacent coverage. |
| `수학하_2015개정_초안/수학하_2015개정_유리함수_BookData_초안.json` | 2015 상·하 topic candidate | 10수학04-04 | Topic/title candidate; verify full criterion scope. |
| `수학하_2015개정_초안/수학하_2015개정_조합_BookData_초안.json` | 2015 상·하 topic candidate | 10수학05-03 | Topic/title match; still needs page-level and math review. |
| `수학하_2015개정_초안/수학하_2015개정_집합의합집합과교집합_BookData_초안.json` | 2015 상·하 topic candidate | 10수학03-03 | Topic/title candidate; page-level completeness remains unverified. |
| `수학하_2015개정_초안/수학하_2015개정_함수의뜻_BookData_초안.json` | 2015 상·하 topic candidate | 10수학04-01 | Topic/title match; still needs page-level and math review. |
| `중등수학_연립일차방정식_BookData_시범.json` | Unresolved | — | Edition comparison pending. |
| `중등수학_정수의덧셈과뺄셈_BookData_시범.json` | Unresolved | — | Edition comparison pending. |
| `중등수학_제곱근과제곱_개념서_BookData_시범.json` | Unresolved | — | Edition comparison pending. |
| `중등수학_좌표와순서쌍_BookData_시범.json` | Unresolved | — | Edition comparison pending. |
| `확률과통계_2015개정_이항분포_BookData_시범.json` | 2015 candidate; page/course review pending | 12확통03-03 | 2015 tag + binomial-distribution topic. Candidate only. |
| `확률과통계_2015개정_조건부확률_BookData_시범.json` | 2015 candidate; page/course review pending | 12확통02-05 | 2015 tag + conditional-probability topic. Candidate only. |

## Next review steps

1. Inspect each linked source page and decide whether the candidate is full-topic, partial-topic, or a false match.
2. Confirm course placement for the 2015 definite-integral sample; its candidate is `12수학Ⅱ03-05` in the official 2015 `수학Ⅱ` criteria.
3. Resolve edition/source evidence for the nine unresolved files before assigning any standard code.
4. Keep teacher approval, independent math review, rights clearance, and runtime compatibility as separate release gates.
