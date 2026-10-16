"""Author original Common Math 2 modules using equations recovered from HWP EqEdit records."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
CURRICULUM = ROOT / "work/official-curriculum/2022_math_standards.json"
OFFICIAL_HWP = ROOT / "work/official-curriculum/2022_appendix8_math.hwp"
OUT = MANUSCRIPTS / "공통수학2_2022개정_EqEdit복구기준_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "공통수학2_2022개정_EqEdit복구기준_Batch2_원고패키지"

SPECS = [
    {
        "code": "10공수2-01-07",
        "title": "좌표평면에서 대칭이동",
        "concept": "원점에 대한 대칭은 (x,y)를 (−x,−y)로 보낸다. x축 대칭은 (x,−y), y축 대칭은 (−x,y), 직선 y=x 대칭은 좌표를 맞바꾼 (y,x)로 보낸다. 점과 대칭 기준을 먼저 확인한 뒤 좌표를 변환한다.",
        "example": "P(2,−3)을 원점에 대칭하면 (−2,3), x축에 대칭하면 (2,3), y축에 대칭하면 (−2,−3), y=x에 대칭하면 (−3,2)다. 각 결과를 다시 같은 기준으로 대칭하면 P로 돌아온다.",
        "practice": "점 A(1,−4)를 직선 y=x에 대칭이동한 점의 좌표를 구하세요.",
        "answer": "(−4,1). y=x 대칭은 x좌표와 y좌표를 서로 바꾼다.",
        "hint": "y=x에 대한 대칭에서는 점의 두 좌표가 서로 자리를 바꿉니다.",
        "options": ["(−4,1)", "(4,−1)", "(1,4)"],
        "correct": 0,
        "source_equations": {"x", "y", "y=x"},
        "checks": ["10공수2-01-07 HWP EqEdit raw scripts: x, y, y=x"],
    },
    {
        "code": "10공수2-03-04",
        "title": "유리함수의 그래프와 점근선",
        "concept": "공식 HWP의 기본 형태는 y=(ax+b)/(cx+d)다. 분모가 0인 x는 정의역에서 제외한다. 예를 들어 f(x)=2/(x−1)+3=(3x−1)/(x−1)은 x=1에서 정의되지 않고, x가 1에 가까워질 때 함수값의 크기가 커진다. 이 예의 그래프는 x=1과 y=3에 가까워진다.",
        "example": "f(x)=2/(x−1)+3에서 x=0이면 f(0)=1, x=2이면 f(2)=5다. 두 점은 수직선 x=1의 서로 다른 쪽에 있다. 식을 (3x−1)/(x−1)로 정리해도 같은 함수이며, 분모가 0인 x=1은 허용되지 않는다.",
        "practice": "g(x)=1/(x−2)+4에서 분모가 0이 되는 x와 그래프가 가까워지는 수직선을 쓰세요.",
        "answer": "x=2이며 수직점근선은 x=2다.",
        "hint": "분모 x−2가 0이 되는 x를 찾고 그 값은 정의역에서 제외합니다.",
        "options": ["x=2", "x=−2", "y=4"],
        "correct": 0,
        "source_equations": {"y= {ax+b} over {cx+d}"},
        "checks": ["10공수2-03-04 HWP EqEdit raw script: y= {ax+b} over {cx+d}"],
    },
    {
        "code": "10공수2-03-05",
        "title": "무리함수의 정의역과 그래프",
        "concept": "공식 HWP의 기본 형태는 y=√(ax+b)+c다. 제곱근 안의 값은 0 이상이어야 하므로 ax+b≥0인 x만 정의역에 포함된다. 예시를 그릴 때 정의역의 시작점과 함수값 변화를 함께 확인한다.",
        "example": "g(x)=√(2x+2)+1은 2x+2≥0인 x≥−1에서 정의된다. 시작점은 (−1,1)이고, x=0이면 g(0)=1+√2다. 제곱근 값은 음수가 아니므로 이 함수는 y=0이 되는 점이 없다.",
        "practice": "h(x)=√(3x−6)+2의 정의역을 부등식과 구간으로 나타내세요.",
        "answer": "3x−6≥0이므로 x≥2, 정의역은 [2,∞)다.",
        "hint": "제곱근 안의 식을 0 이상으로 놓고 부등식을 풉니다.",
        "options": ["[2,∞)", "(−∞,2]", "[−2,∞)"],
        "correct": 0,
        "source_equations": {"y= sqrt {ax+b} +c"},
        "checks": ["10공수2-03-05 HWP EqEdit raw script: y= sqrt {ax+b} +c"],
    },
]


def make_quiz(spec: dict, slug: str) -> dict:
    return {
        "type": "activity",
        "activity": {
            "id": slug + "-quiz",
            "kind": "quiz",
            "prompt": spec["practice"],
            "options": spec["options"],
            "correct_index": spec["correct"],
            "correct_feedback": "정답입니다. 좌표 변환과 정의역 조건을 확인했습니다.",
            "incorrect_feedback": "기준이 되는 직선이나 식의 조건을 다시 확인하세요.",
            "hints": [spec["hint"]],
        },
    }


def main() -> None:
    standards_data = json.loads(CURRICULUM.read_text(encoding="utf-8"))
    official = {row["code"]: row for row in standards_data["standards"]}
    codes = [spec["code"] for spec in SPECS]
    if len(codes) != 3 or len(set(codes)) != 3 or any(code not in official for code in codes):
        raise RuntimeError("Expected exactly the three HWP EqEdit-recovered Common Math 2 standards")
    for spec in SPECS:
        observed = set(official[spec["code"]].get("equation_scripts", []))
        if not spec["source_equations"].issubset(observed):
            raise RuntimeError(f"Original EqEdit source evidence missing for {spec['code']}: {observed}")

    chapters = []
    for spec in SPECS:
        slug = spec["code"].replace("10공수2-", "cm2-").replace("-", "")
        code = spec["code"]
        pages = [
            {"id": slug+"-open", "template": "opening", "title": "상황과 질문", "blocks": [{"type": "lead", "title": "핵심 질문", "text": spec["title"]}, {"type": "thinking", "title": "먼저 살펴보기", "text": "대칭 기준 또는 식의 조건을 말하고, 어떤 성질을 확인할지 예상합니다."}]},
            {"id": slug+"-concept", "template": "concept", "title": "개념과 조건", "blocks": [{"type": "definition", "title": spec["title"], "text": spec["concept"]}, {"type": "formula", "title": "교육부 HWP EqEdit 원문 스크립트", "text": "; ".join(sorted(spec["source_equations"]))}, {"type": "misconception", "title": "조건 점검", "text": "대칭 기준, 분모가 0인 값 또는 제곱근 안의 부호를 확인합니다."}]},
            {"id": slug+"-example", "template": "example", "title": "예제와 풀이", "blocks": [{"type": "question", "title": "예제", "text": spec["practice"]}, {"type": "solutionStep", "title": "풀이와 추가 예시", "text": spec["example"]}, {"type": "verification", "title": "검산", "text": "결과를 원래 좌표변환이나 함수식에 대입해 조건을 확인합니다."}]},
            {"id": slug+"-practice", "template": "practice", "title": "연습과 해설", "blocks": [{"type": "question", "title": "연습", "text": spec["practice"]}, {"type": "hint", "title": "힌트", "text": spec["hint"]}, {"type": "solutionStep", "title": "해설", "text": spec["answer"]}, {"type": "answer", "title": "정답", "text": spec["answer"]}, make_quiz(spec, slug)]},
            {"id": slug+"-summary", "template": "summary", "title": "핵심 정리", "blocks": [{"type": "summary", "title": "기억할 점", "text": spec["concept"]}, {"type": "checklist", "title": "스스로 확인", "text": "기준과 정의역을 확인하고 풀이를 설명할 수 있나요?"}]},
        ]
        chapters.append({"title": spec["title"], "intro": [f"2022 교육과정 공식 기준 {code}에 연결한 신규 원고 후보입니다.", "교육부 HWP의 EqEdit 수식 개체 스크립트를 확인해 반영했습니다. 예시·문항은 새로 작성했습니다."], "pages": pages})

    book = {
        "schema_version": 2,
        "title": "공통수학2 · HWP EqEdit 복구 기준 3모듈 후보",
        "subtitle": "대칭이동·유리함수·무리함수",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2022",
        "tags": ["공통수학2", "2022 개정", "HWP EqEdit 복구 기준", "신규 원고 후보", "가상 예시", "학기 배정 미확정", *codes],
        "standard_codes": codes,
        "chapters": chapters,
    }
    page_ids = [page["id"] for chapter in chapters for page in chapter["pages"]]
    assert len(page_ids) == 15 and len(set(page_ids)) == 15
    point = (2, -3)
    assert (-point[0], -point[1]) == (-2, 3)
    assert (point[0], -point[1]) == (2, 3)
    assert (-point[0], point[1]) == (-2, -3)
    assert (point[1], point[0]) == (-3, 2)
    for x in (0, 2, 4):
        assert abs((3*x - 1)/(x - 1) - (2/(x - 1) + 3)) < 1e-12
    assert 2*(-1)+2 == 0 and 3*2-6 == 0 and (2*0+2) >= 0

    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    hwp_sha256 = hashlib.sha256(OFFICIAL_HWP.read_bytes()).hexdigest().upper()
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try:
        old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old = {}
    digest = canonical_file_sha256(OUT)
    same = old.get("bookdata_sha256") == digest
    formula_evidence = {spec["code"]: sorted(spec["source_equations"]) for spec in SPECS}
    manifest = {
        "bookdata_file": OUT.name,
        "bookdata_sha256": digest,
        "candidate_code_references": codes,
        "candidate_code_reference_type": "official_2022_hwp_criterion_table_and_raw_eqedit_records",
        "official_hwp_sha256": hwp_sha256,
        "recovered_eqedit_source_scripts": formula_evidence,
        "module_count": 3,
        "page_count": 15,
        "native_activity_count": 3,
        "native_activity_kinds": ["quiz"],
        "arithmetic_and_domain_checks": "pass_for_listed_examples_only",
        "example_data_status": "synthetic_original_examples; no commercial text, problem, illustration, or dataset copied",
        "curriculum_review_status": "official_codes_and_raw_eqedit_scripts_verified; semester_and_full_scope_pending",
        "math_review_status": "author_spot_checks_passed; independent_teacher_review_pending",
        "teacher_review_status": "pending",
        "rights_status": "newly_authored; publication_rights_decision_pending",
        "integration_status": "candidate_for_unit_grouping; master_not_app_integrated",
        "publication_eligibility": "not_eligible",
        "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same else "pending_current_hash_validation",
        "runtime_validator_head": old.get("runtime_validator_head") if same else None,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        "# 공통수학2 HWP EqEdit 복구 기준 후보\n\n"
        "교육부 2022 HWP 원본에서 복구한 EqEdit 스크립트를 기준으로 3모듈·15쪽·quiz 3개를 새로 작성했습니다. "
        "HWP 원본 수식 스크립트와 SHA-256은 `REVIEW_MANIFEST.json`에 기록했습니다. 예시와 문항은 새로 만들었으며, "
        "독립 교사 검토·권리 결정·과목 전체 범위 대조 전에는 출판 적격이 아닙니다.\n\n"
        f"BookData: [`{OUT.name}`](../{OUT.name})\n",
        encoding="utf-8",
    )
    print(f"Built {len(chapters)} Common Math 2 modules, {len(page_ids)} pages, 3 quizzes from recovered HWP EqEdit evidence.")


if __name__ == "__main__":
    main()
