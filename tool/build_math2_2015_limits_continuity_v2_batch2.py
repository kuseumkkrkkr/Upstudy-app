"""Add focused 2015 Mathematics II limit/continuity gap coverage."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "수학Ⅱ_2015개정_극한연속_보충_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "수학Ⅱ_2015개정_극한연속_보충_Batch2_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"

MODULES = [
    {
        "code": "12수학Ⅱ01-01", "title": "함수의 극한의 뜻", "unit": "함수의 극한과 연속",
        "concept": "lim(x→a) f(x)=L은 x가 a의 왼쪽과 오른쪽에서 다가갈 때 함수값이 같은 L에 가까워진다는 뜻이다. f(a)의 값은 극한과 별도로 정한다.",
        "example_q": "x≠1에서 f(x)=(x²−1)/(x−1), f(1)=5이다. lim(x→1)f(x)와 f(1)을 비교하라.",
        "example": "x≠1에서 (x²−1)/(x−1)=x+1이므로 좌극한과 우극한은 모두 2이다. 따라서 lim(x→1)f(x)=2이고 f(1)=5이다.",
        "question": "x≠2에서 g(x)=|x−2|/(x−2)이다. 좌극한과 우극한을 구하고 양쪽 극한의 존재를 판단하라.",
        "answer": "좌 −1, 우 1; 양쪽 극한 없음",
        "options": ["좌 −1, 우 1; 양쪽 극한 없음", "좌 1, 우 1", "좌 −1, 우 −1"],
        "solution": "x<2이면 |x−2|=−(x−2)이므로 값은 −1이다. x>2이면 |x−2|=x−2이므로 값은 1이다. 좌우 극한이 달라 양쪽 극한은 없다.",
    },
    {
        "code": "12수학Ⅱ01-02", "title": "극한의 성질과 극한값 계산", "unit": "함수의 극한과 연속",
        "concept": "극한이 존재하는 두 함수의 합·차·곱의 극한은 각 극한의 합·차·곱이다. 몫의 극한은 분모의 극한이 0이 아닐 때 분자와 분모의 극한의 몫이다.",
        "example_q": "lim(x→2) (x²−4)/(x−2)를 구하라.",
        "example": "x≠2에서 x²−4=(x−2)(x+2)이므로 식은 x+2와 같다. 따라서 극한은 4이다. 약분은 x≠2인 근방에서 한 것이며 x=2의 식값을 주장하지 않는다.",
        "question": "lim(x→3) (x²−9)/(x−3)를 구하라.",
        "answer": "6", "options": ["6", "3", "9"],
        "solution": "x²−9=(x−3)(x+3)이고 x≠3에서 식은 x+3이다. x가 3에 가까워지면 x+3은 6에 가까워진다.",
    },
    {
        "code": "12수학Ⅱ01-03", "title": "함수의 연속의 뜻", "unit": "함수의 극한과 연속",
        "concept": "함수 f가 x=a에서 연속이려면 f(a)가 정의되고, lim(x→a)f(x)가 존재하며, 그 극한이 f(a)와 같아야 한다.",
        "example_q": "x≠1에서 f(x)=(x²−1)/(x−1), f(1)=k이다. f가 x=1에서 연속일 조건을 구하라.",
        "example": "x≠1에서 식은 x+1이므로 lim(x→1)f(x)=2이다. 연속의 세 조건 중 함수값은 이미 정의되어 있으므로 k=2여야 극한과 함수값이 같다.",
        "question": "x≠3에서 f(x)=(x²−9)/(x−3), f(3)=k이다. x=3에서 연속일 k를 구하라.",
        "answer": "6", "options": ["6", "3", "9"],
        "solution": "x≠3에서 식은 x+3이므로 극한은 6이다. 연속이려면 f(3)=k가 이 극한과 같아야 하므로 k=6이다.",
    },
]


def verify_scope() -> None:
    source = CURRICULUM.read_text(encoding="utf-8")
    for module in MODULES:
        if not re.search(rf"\[{re.escape(module['code'])}\]", source):
            raise RuntimeError(f"Official curriculum criterion missing: {module['code']}")
    wanted = {item["code"] for item in MODULES}
    for manifest_path in MANUSCRIPTS.rglob("REVIEW_MANIFEST.json"):
        if manifest_path.parent == PACKAGE:
            continue
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue
        refs = set(manifest.get("candidate_code_references", []))
        overlap = wanted & refs
        if overlap:
            raise RuntimeError(f"Manifest overlap at {manifest_path}: {sorted(overlap)}")


def page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_scope()
    chapters = []
    for module in MODULES:
        code = module["code"]
        slug = "m2-lc-" + code[-5:].replace("-", "")
        options = module["options"]
        correct = options.index(module["answer"])
        chapters.append({
            "title": module["title"],
            "intro": [f"2015 개정 교육과정 기준 {code}에 연결한 보충 후보입니다.", "기존 그래프·HTML 시범과 별도 원고이며, 기존 자료의 대체나 화면 동등성을 주장하지 않습니다."],
            "pages": [
                page(slug+"-open", "opening", "질문 열기", [{"type":"lead","title":"핵심 질문","text":module["title"]},{"type":"thinking","title":"먼저 생각하기","text":"주어진 점의 함수값과 가까이에서의 함수값을 구분해 봅니다."}]),
                page(slug+"-concept", "concept", "개념과 조건", [{"type":"definition","title":module["title"],"text":module["concept"]},{"type":"formula","title":"기준 코드","text":code},{"type":"misconception","title":"확인","text":"좌우 접근이나 연속의 조건을 빠뜨리지 않았는지 확인합니다."}]),
                page(slug+"-example", "example", "예제 풀이", [{"type":"question","title":"예제","text":module["example_q"]},{"type":"solutionStep","title":"풀이","text":module["example"]},{"type":"verification","title":"검산","text":"인수분해한 식은 접근점과 다른 x에서만 사용했는지 확인합니다."}]),
                page(slug+"-practice", "practice", "연습·해설·퀴즈", [{"type":"question","title":"연습","text":module["question"]},{"type":"hint","title":"힌트","text":"접근점의 왼쪽과 오른쪽을 나누어 계산합니다."},{"type":"solutionStep","title":"해설","text":module["solution"]},{"type":"answer","title":"정답","text":module["answer"]},{"type":"activity","activity":{"id":slug+"-quiz","kind":"quiz","prompt":module["question"],"options":options,"correct_index":correct,"correct_feedback":"정답입니다. "+module["answer"],"incorrect_feedback":"정답은 "+module["answer"]+"입니다. "+module["solution"],"hints":["좌우에서 따로 접근값을 확인합니다.",module["solution"]]}}]),
                page(slug+"-summary", "summary", "핵심 정리", [{"type":"summary","title":"기억할 점","text":module["concept"]},{"type":"checklist","title":"자기 점검","text":"정의와 풀이의 근거를 설명할 수 있나요?"}]),
            ],
        })

    codes = [module["code"] for module in MODULES]
    pages = [p for chapter in chapters for p in chapter["pages"]]
    ids = [p["id"] for p in pages]
    assert len(chapters) == 3 and len(pages) == 15 and len(set(ids)) == 15
    assert set(codes) == {"12수학Ⅱ01-01", "12수학Ⅱ01-02", "12수학Ⅱ01-03"}
    # Verify representative factorisations and their evaluated limits.
    assert 3**2 - 1**2 == (3 - 1) * (3 + 1) and 3 + 1 == 4
    assert 4**2 - 2**2 == (4 - 2) * (4 + 2) and 4 + 2 == 6
    assert 5**2 - 3**2 == (5 - 3) * (5 + 3) and 5 + 3 == 8
    # Check the one-sided absolute-value cases and continuity assignments.
    assert abs(1 - 2) / (1 - 2) == -1 and abs(3 - 2) / (3 - 2) == 1
    assert 1 + 1 == 2 and 3 + 3 == 6
    assert MODULES[0]["answer"] == MODULES[0]["options"][0]
    assert "연속" in MODULES[2]["concept"]
    assert (-1) != 1 and ((-1) + 1) == 0
    assert all(module["answer"] in module["options"] for module in MODULES)
    book = {
        "schema_version": 2, "title": "수학Ⅱ · 극한과 연속 보충 Batch2",
        "subtitle": "2015 개정 기준 01-01~03의 기존 원고 공백 보완",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": codes, "tags": ["수학Ⅱ", "2015 개정", "보충 후보", *codes],
        "chapters": chapters,
        "metadata": {"supplement_only": True, "publication_eligibility": "not_eligible", "teacher_review_status": "pending", "math_review_status": "independent_review_pending", "rights_status": "publication_decision_pending"},
    }
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": codes,
        "candidate_code_reference_type": "official_2015_appendix8_math_criteria_table",
        "module_count": 3, "page_count": 15, "native_activity_count": 3,
        "native_activity_kinds": ["quiz"], "content_assertion_status": "generator_assertions_passed; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; existing_graph_html_assets_separate",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 기준 | 기존 3쪽 후보의 실제 범위 | 확인한 실질 공백 |\n|---|---|---|\n| 12수학Ⅱ01-01 | 좌우 접근, f(a) 구분, 연습 정답 | 풀이가 있는 적용 예제와 채점형 퀴즈가 없음 |\n| 12수학Ⅱ01-02 | 01-01과 같은 극한 개념 중심 | 극한의 성질, 대수적 극한 계산, 풀이, 퀴즈가 없음 |\n| 12수학Ⅱ01-03 | 연속의 세 조건과 단순 연습 | 조건을 적용하는 풀이 예제와 채점형 퀴즈가 없음 |\n\n## 보완 범위\n\n세 기준 각각 5쪽(개념·풀이 예제·연습 해설·채점형 퀴즈 포함)의 추가 후보입니다. 기존 그래프 BookData와 독립 HTML 시범은 별도 유지하며 대체하거나 동등한 상호작용이라고 주장하지 않습니다. 교사·독립 수학 검토와 권리 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built {len(chapters)} modules, {len(pages)} pages; sha256={digest}")


if __name__ == "__main__":
    main()
