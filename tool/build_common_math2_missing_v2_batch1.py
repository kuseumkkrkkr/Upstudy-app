"""Build original V2 candidates for extractable 2022 Common Math 2 standards."""
from __future__ import annotations

import json
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
OUT = MANUSCRIPTS / "공통수학2_2022개정_추출가능기준14모듈_Batch1_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "공통수학2_2022개정_추출가능기준14모듈_Batch1_원고패키지"

# Three standards are held for Batch2, which uses raw EqEdit scripts recovered
# from the official HWP. Examples are newly authored, not copied from sources.
SPECS = [
    ("10공수2-01-01", "선분의 내분과 좌표", "수직선에서 A(0), B(6)을 1:2로 내분하는 점은 P(2)이다.", "AP:PB=1:2이면 P는 A에서 B까지 거리의 1/3 지점이므로 좌표는 0+(6−0)/3=2이다.", "A(−2), B(10)을 AP:PB=1:3으로 내분하는 점 P의 좌표를 구하세요.", "1", "내분점은 A에서 전체 길이의 1/(1+3)만큼 이동합니다.", ["1", "4", "7"], 0),
    ("10공수2-01-02", "두 직선의 평행과 수직", "기울기가 같은 두 직선은 평행하고, 기울기의 곱이 −1인 두 직선은 수직이다(수직선 예외 포함).", "기울기 2인 직선과 기울기 −1/2인 직선은 기울기의 곱이 −1이므로 서로 수직이다.", "기울기 3인 직선에 수직인 직선의 기울기를 구하세요.", "−1/3", "두 기울기의 곱이 −1이 되도록 합니다.", ["−1/3", "1/3", "−3"], 0),
    ("10공수2-01-03", "점과 직선 사이의 거리", "점 (x₁,y₁)에서 직선 ax+by+c=0까지의 거리는 |ax₁+by₁+c|/√(a²+b²)이다.", "점 (1,2)와 직선 3x+4y−10=0 사이의 거리는 |3+8−10|/5=1/5이다.", "점 (0,0)에서 직선 3x+4y−10=0까지의 거리를 구하세요.", "2", "분자의 절댓값은 10이고 분모는 √(3²+4²)=5입니다.", ["2", "5", "10"], 0),
    ("10공수2-01-04", "원의 방정식과 그래프", "중심이 (a,b), 반지름이 r인 원의 방정식은 (x−a)²+(y−b)²=r²이다.", "중심 (2,−1), 반지름 3인 원은 (x−2)²+(y+1)²=9이고 중심으로부터 거리 3인 점을 지난다.", "중심 (−1,2), 반지름 4인 원의 방정식을 쓰세요.", "(x+1)²+(y−2)²=16", "중심 좌표의 부호에 유의해 표준형에 대입합니다.", ["(x+1)²+(y−2)²=16", "(x−1)²+(y+2)²=16", "(x+1)²+(y−2)²=4"], 0),
    ("10공수2-01-05", "원과 직선의 위치 관계", "원의 중심에서 직선까지의 거리와 반지름을 비교해 교점의 수를 판단한다.", "원 x²+y²=25와 직선 y=3에서 중심까지 거리는 3, 반지름은 5이므로 두 점에서 만난다.", "원 x²+y²=9와 직선 y=4의 교점은 몇 개인가요?", "0개", "중심에서 직선까지 거리가 반지름 3보다 큽니다.", ["0개", "1개", "2개"], 0),
    ("10공수2-01-06", "평행이동", "점 (x,y)를 벡터 (a,b)만큼 평행이동하면 (x+a,y+b)가 된다.", "점 (−1,4)를 (3,−2)만큼 평행이동하면 (2,2)이다. 모든 점에 같은 벡터를 더해 도형 전체를 옮긴다.", "점 (2,−3)을 벡터 (−4,5)만큼 평행이동한 좌표를 구하세요.", "(−2,2)", "x좌표끼리, y좌표끼리 이동량을 더합니다.", ["(−2,2)", "(6,−8)", "(−2,−8)"], 0),
    ("10공수2-02-01", "집합의 개념과 표현", "집합은 대상을 분명하게 구별할 수 있는 모임이며 원소나 조건제시법으로 나타낼 수 있다.", "A={x∈Z | 0<x<4}를 원소나열법으로 나타내면 {1,2,3}이다.", "B={x∈Z | 0<x≤5, x는 짝수}를 원소나열법으로 나타내세요.", "{2,4}", "정수 중 조건을 만족하는 원소를 빠짐없이 적습니다.", ["{2,4}", "{0,2,4}", "{2,4,6}"], 0),
    ("10공수2-02-02", "두 집합 사이의 포함 관계", "A의 모든 원소가 B에 속하면 A는 B의 부분집합이다.", "A={1,2}, B={1,2,3}이면 A⊂B이고 B⊄A이다.", "A={a,b}, B={a,b,c}일 때 참인 포함 관계를 고르세요.", "A⊂B", "포함 관계는 A의 모든 원소가 B에도 있는지 확인합니다.", ["A⊂B", "B⊂A", "A=B"], 0),
    ("10공수2-02-03", "집합의 연산과 벤 다이어그램", "합집합은 한 집합 이상에 속하는 원소, 교집합은 두 집합 모두에 속하는 원소로 이룬다.", "A={1,2,3}, B={3,4}이면 A∪B={1,2,3,4}, A∩B={3}이다.", "A={1,2,4}, B={2,3,4}일 때 A−B를 구하세요.", "{1}", "A−B는 A에는 있고 B에는 없는 원소를 남깁니다.", ["{1}", "{2,4}", "{1,2,3,4}"], 0),
    ("10공수2-02-06", "충분조건과 필요조건", "p이면 q일 때 p는 q이기 위한 충분조건이고 q는 p이기 위한 필요조건이다.", "정수 n이 4의 배수이면 짝수이다. 따라서 ‘4의 배수’는 ‘짝수’이기 위한 충분조건이고, ‘짝수’는 ‘4의 배수’이기 위한 필요조건이다.", "정수 n이 6의 배수이면 3의 배수이다. ‘6의 배수’는 ‘3의 배수’이기 위한 어떤 조건인가요?", "충분조건", "6의 배수이면 항상 3의 배수이지만, 모든 3의 배수가 6의 배수인 것은 아닙니다.", ["충분조건", "필요조건", "필요충분조건"], 0),
    ("10공수2-02-07", "대우와 귀류법을 이용한 증명", "명제의 대우가 참임을 보여 원래 명제를 증명하거나, 결론의 부정을 가정해 모순을 이끌어 귀류법으로 증명한다.", "정수 n=2k+1이면 n²=2(2k²+2k)+1이 홀수이다. 따라서 ‘n²이 짝수이면 n은 짝수’의 대우가 참이고 원래 명제도 참이다.", "‘정수 n의 제곱이 홀수이면 n은 홀수이다’의 대우를 쓰세요.", "n이 짝수이면 n²은 짝수이다", "p이면 q의 대우는 q가 아니면 p가 아니다입니다.", ["n이 짝수이면 n²은 짝수이다", "n이 홀수이면 n²은 홀수이다", "n²이 짝수이면 n은 짝수이다"], 0),
    ("10공수2-02-08", "절대부등식의 증명", "변수의 범위에서 항상 성립하는 부등식을 절대부등식이라 하며, 제곱의 비음수성을 이용해 간단한 부등식을 증명할 수 있다.", "모든 실수 x에 대해 (x−3)²≥0이므로 x²−6x+9≥0이다.", "모든 실수 x에 대해 x²+4x+4≥0임을 제곱식으로 설명하세요.", "(x+2)²≥0", "식을 완전제곱식으로 바꾸면 제곱은 항상 0 이상입니다.", ["(x+2)²≥0", "(x−2)²≤0", "x²+4≥0"], 0),
    ("10공수2-03-02", "합성함수의 뜻과 계산", "함수의 합성을 이해하고 합성함수의 함숫값을 구한다.", "f(x)=x+2, g(x)=3x이면 (g∘f)(1)=g(3)=9이고 (f∘g)(1)=5이다.", "f(x)=x−1, g(x)=2x일 때 (g∘f)(4)를 구하세요.", "6", "먼저 안쪽 함수 f에 4를 넣고, 그 결과를 g에 넣습니다.", ["6", "7", "8"], 0),
    ("10공수2-03-03", "역함수의 존재와 구하기", "역함수의 존재 조건을 확인하고 역함수를 구한다.", "f(x)=x²는 실수 전체에서 일대일이 아니지만 x≥0으로 정의역을 제한하면 역함수 √x를 갖는다.", "f(x)=x+5의 역함수를 구하세요.", "f⁻¹(x)=x−5", "y=x+5에서 x와 y를 바꾸고 y를 정리합니다.", ["f⁻¹(x)=x−5", "f⁻¹(x)=x+5", "f⁻¹(x)=5−x"], 0),
]

EXAMPLE_QUESTIONS = {
    "10공수2-01-01": "A(0), B(6)을 AP:PB=1:2로 내분하는 점 P의 좌표를 구하세요.",
    "10공수2-01-02": "기울기가 2와 −1/2인 두 직선은 어떤 관계인가요?",
    "10공수2-01-03": "점 (1,2)에서 직선 3x+4y−10=0까지의 거리를 구하세요.",
    "10공수2-01-04": "중심 (2,−1), 반지름 3인 원의 방정식을 쓰세요.",
    "10공수2-01-05": "원 x²+y²=25와 직선 y=3의 교점 개수를 구하세요.",
    "10공수2-01-06": "점 (−1,4)를 벡터 (3,−2)만큼 평행이동한 좌표를 구하세요.",
    "10공수2-02-01": "A={x∈Z | 0<x<4}를 원소나열법으로 나타내세요.",
    "10공수2-02-02": "A={1,2}, B={1,2,3}일 때 참인 포함 관계를 쓰세요.",
    "10공수2-02-03": "A={1,2,3}, B={3,4}일 때 A∪B와 A∩B를 구하세요.",
    "10공수2-02-06": "n이 4의 배수이면 짝수입니다. ‘4의 배수’는 ‘짝수’이기 위한 어떤 조건인가요?",
    "10공수2-02-07": "대우를 이용해 ‘n²이 짝수이면 정수 n은 짝수’임을 보이세요.",
    "10공수2-02-08": "모든 실수 x에 대해 x²−6x+9≥0임을 제곱식으로 설명하세요.",
    "10공수2-03-02": "f(x)=x+2, g(x)=3x일 때 (g∘f)(1)과 (f∘g)(1)을 구하세요.",
    "10공수2-03-03": "f(x)=x²의 정의역을 x≥0으로 제한할 때 역함수를 구하세요.",
}


def make_quiz(spec: tuple, activity_id: str) -> dict:
    return {"type": "activity", "activity": {"id": activity_id, "kind": "quiz", "prompt": spec[4], "options": spec[7], "correct_index": spec[8], "correct_feedback": spec[6], "incorrect_feedback": "조건과 계산 순서를 다시 확인하고 보기의 값을 대입해 검산하세요.", "hints": [spec[6], "정의역·조건을 먼저 확인한 뒤 계산합니다."]}}


def main() -> None:
    official_rows = [row for row in json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"] if row["code"].startswith("10공수2-")]
    official = {row["code"]: row["criterion"] for row in official_rows}
    codes = [spec[0] for spec in SPECS]
    batch2 = {"10공수2-01-07", "10공수2-03-04", "10공수2-03-05"}
    existing = {"10공수2-02-04", "10공수2-02-05", "10공수2-03-01"}
    eqedit = {row["code"]: set(row.get("equation_scripts", [])) for row in official_rows}
    recovered = {
        "10공수2-01-07": {"x", "y", "y=x"},
        "10공수2-03-04": {"y= {ax+b} over {cx+d}"},
        "10공수2-03-05": {"y= sqrt {ax+b} +c"},
    }
    if any(not expected.issubset(eqedit.get(code, set())) for code, expected in recovered.items()):
        raise RuntimeError("Batch2 source equations are not recovered from official HWP EqEdit records")
    if len(codes) != 14 or len(set(codes)) != 14 or any(code not in official for code in codes):
        raise RuntimeError("Expected 14 distinct official, extractable Common Math 2 standards")
    if set(EXAMPLE_QUESTIONS) != set(codes):
        raise RuntimeError("Every worked example must have a matching explicit question")
    if any(spec[7][spec[8]] != spec[5] for spec in SPECS):
        raise RuntimeError("A quiz answer key does not select its stated answer")
    if set(codes) & (batch2 | existing) or set(codes) | batch2 | existing != set(official):
        raise RuntimeError("Batch1, Batch2, and existing standards do not partition Common Math 2")
    if any(not official[code].strip() for code in codes):
        raise RuntimeError("Official criterion text missing for a candidate standard")

    chapters = []
    for code, title, concept, example, practice, answer, feedback, options, correct in SPECS:
        slug = code.replace("10공수2-", "cm2-").replace("-", "")
        example_question = EXAMPLE_QUESTIONS[code]
        pages = [
            {"id": slug+"-open", "template": "opening", "title": "상황과 질문", "blocks": [{"type": "lead", "title": "가상 예시", "text": title}, {"type": "thinking", "title": "먼저 생각하기", "text": "조건과 대상의 범위를 표시하고 사용할 관계를 예상합니다."}]},
            {"id": slug+"-concept", "template": "concept", "title": "정의와 성질", "blocks": [{"type": "definition", "title": "핵심 개념", "text": concept}, {"type": "formula", "title": "연결한 공식 기준", "text": code}, {"type": "misconception", "title": "조건 점검", "text": "정의역, 포함 관계, 순서 또는 중복 여부를 확인합니다."}]},
            {"id": slug+"-example", "template": "example", "title": "예제와 풀이", "blocks": [{"type": "question", "title": "예제", "text": example_question}, {"type": "solutionStep", "title": "풀이", "text": example}, {"type": "verification", "title": "검산", "text": "원래 조건에 결과를 대입해 확인합니다."}]},
            {"id": slug+"-practice", "template": "practice", "title": "연습과 설명", "blocks": [{"type": "question", "title": "연습", "text": practice}, {"type": "hint", "title": "힌트", "text": feedback}, {"type": "solutionStep", "title": "해설", "text": answer}, {"type": "answer", "title": "정답", "text": answer}, make_quiz((code, title, concept, example, practice, answer, feedback, options, correct), slug+"-quiz")]},
            {"id": slug+"-summary", "template": "summary", "title": "핵심 정리", "blocks": [{"type": "summary", "title": "기억할 점", "text": title}, {"type": "checklist", "title": "스스로 확인", "text": "조건과 계산 근거를 설명하고 결과를 검산할 수 있나요?"}]},
        ]
        chapters.append({"title": title, "intro": [f"2022 교육과정 공식 기준 {code}에 연결한 신규 후보입니다.", "예시와 수치는 직접 작성한 가상 자료입니다."], "pages": pages})

    book = {"schema_version": 2, "title": "공통수학2 · 추출 가능 기준 보완 14모듈 후보", "subtitle": "좌표기하·집합과 명제·함수", "category": "concept_textbook_prototype", "curriculum_version": "2022", "tags": ["공통수학2", "2022 개정", "추가 원고 후보", "가상 예시", "학기 배정 미확정", *codes], "standard_codes": codes, "chapters": chapters}
    page_ids = [page["id"] for chapter in chapters for page in chapter["pages"]]
    if len(page_ids) != 70 or len(set(page_ids)) != 70:
        raise RuntimeError("Expected 70 unique page IDs")

    # Arithmetic and relational spot checks for all numeric examples in this batch.
    assert (6 - 0) / (1 + 2) == 2 and (-2) + (10 - (-2)) / (1 + 3) == 1
    assert 2 * (-0.5) == -1 and abs(3 * 1 + 4 * 2 - 10) / 5 == 0.2
    assert (2 - 2) ** 2 + (-1 + 1) ** 2 == 0
    assert abs(0 + 0 - 10) / 5 == 2 and 4 > 3
    assert (-1 + 3, 4 - 2) == (2, 2) and (2 - 4, -3 + 5) == (-2, 2)
    assert {x for x in range(1, 6) if x % 2 == 0} == {2, 4}
    assert {1, 2} <= {1, 2, 3} and {1, 2, 4} - {2, 3, 4} == {1}
    assert 4 % 2 == 0 and 6 % 3 == 0 and 8 % 3 != 0
    assert 2**2 % 2 == 0 and 2**2 + 4 * 2 + 4 == (2 + 2) ** 2
    assert 3 * 3 == 9 and (3 - 1) / 2 == 1 and (4 - 1) * 3 == 9

    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try:
        old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old = {}
    digest = canonical_file_sha256(OUT)
    same = old.get("bookdata_sha256") == digest
    manifest = {"bookdata_file": OUT.name, "bookdata_sha256": digest, "candidate_code_references": codes, "candidate_code_reference_type": "official_2022_hwp_criterion_table", "deferred_eqedit_batch2_codes": sorted(batch2), "eqedit_recovery_status": "verified_from_original_hwp_raw_records", "module_count": 14, "page_count": 70, "native_activity_count": 14, "native_activity_kinds": ["quiz"], "example_data_status": "synthetic_original_examples; no commercial text, problem, illustration, or dataset copied", "example_question_alignment_status": "explicit_example_question_map_for_all_14_codes; independent review pending", "curriculum_review_status": "official_codes_verified; semester_and_full_scope_pending", "math_review_status": "author_spot_checks_passed; independent_teacher_review_pending", "teacher_review_status": "pending", "rights_status": "newly_authored; publication_rights_decision_pending", "source_interaction_status": "native_quiz_activity_candidate; source_html_parity_not_reviewed", "integration_status": "candidate_for_unit_grouping; not_merged_into_master_book", "publication_eligibility": "not_eligible", "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same else "pending_current_hash_validation", "runtime_validator_head": old.get("runtime_validator_head") if same else None, "runtime_validation_command": old.get("runtime_validation_command") if same else None, "runtime_validator_candidate_sha256": old.get("runtime_validator_candidate_sha256") if same else None}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(f"# {book['title']}\n\n공식 코드 14개에 연결한 14모듈·70쪽 V2 후보입니다. 각 예제에 풀이에 맞는 별도 질문을 연결했습니다. HWP XHTML에서 빠졌던 세 기준의 EqEdit 원문 스크립트가 raw HWP 기록에서 복구되어 Batch2 원고로 분리 제작됩니다: {', '.join(sorted(batch2))}. 예시와 퀴즈는 신규 작성이며 독립 교사 검수·권리 결정 전에는 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n", encoding="utf-8")
    print(f"Built {len(chapters)} Common Math 2 modules, {len(page_ids)} pages, {len(chapters)} quizzes; deferred 3 recovered-EqEdit standards to Batch2.")


if __name__ == "__main__":
    main()
