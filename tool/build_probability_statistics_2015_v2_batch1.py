"""Build two original V2 candidates mapped to 2015 probability standards."""
from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
SOURCE = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
OUT = MANUSCRIPTS / "확률과통계_2015개정_조건부확률이항분포_2단원_Batch1_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "확률과통계_2015개정_조건부확률이항분포_2단원_Batch1_원고패키지"

EXPECTED = {
    "12확통02-05": "조건부확률의 의미를 이해하고, 이를 구할 수 있다.",
    "12확통03-03": "이항분포의 뜻을 알고, 평균과 표준편차를 구할 수 있다.",
}

SPECS = [
    {
        "code": "12확통02-05", "title": "조건을 반영해 확률 계산하기",
        "lead": "가상 주머니에는 빨간 공 4개와 파란 공 3개가 있다. 공을 되돌려 놓지 않고 두 번 뽑는다. 첫 공이 빨간색이라는 조건 아래 두 번째 공이 빨간색일 확률을 구해 보자.",
        "concept": "사건 B가 일어났다는 조건 아래 사건 A가 일어날 확률을 조건부확률이라 하고 P(A|B)=P(A∩B)/P(B) (P(B)>0)로 정의한다. 조건 B를 반영해 표본공간을 다시 세어 계산할 수도 있다.",
        "example": "A를 두 번째 공이 빨간 사건, B를 첫 번째 공이 빨간 사건으로 두면 P(B)=4/7, P(A∩B)=(4/7)(3/6)=2/7이다. 따라서 P(A|B)=(2/7)/(4/7)=1/2이다. 조건을 반영하면 빨간 공 3개, 전체 공 6개가 남는다.",
        "practice": "빨간 공 5개와 파란 공 2개에서 첫 공이 빨간색이다. 되돌려 놓지 않을 때 두 번째도 빨간색일 조건부확률을 구하세요.",
        "answer": "첫 빨간 공이 빠져 빨간 공 4개, 전체 6개가 남으므로 확률은 4/6=2/3입니다.",
        "practice_hint": "첫 공이 빨간색이라는 조건으로 빨간 공 하나를 제외해 보세요.",
        "prompt": "빨간 공 4개, 파란 공 3개에서 첫 공이 빨간색일 때 두 번째도 빨간색일 확률은?", "options": ["1/2", "3/7", "4/7"], "correct": 0,
        "feedback": "조건으로 빨간 공 하나가 빠져 3/6=1/2입니다.", "wrong": "첫 번째가 빨간색이라는 조건을 표본공간에 반영하세요.",
        "hints": ["남은 전체 공은 6개입니다.", "남은 빨간 공은 3개이므로 3/6을 계산합니다."],
    },
    {
        "code": "12확통03-03", "title": "이항분포의 평균과 표준편차",
        "lead": "성공확률 1/2인 독립 시행을 4회 한다. 성공 횟수 X의 가능한 값과 평균·표준편차를 함께 살펴보자.",
        "concept": "독립인 베르누이 시행을 n번 반복하고 매 시행의 성공확률이 p로 같으면 성공 횟수 X는 이항분포 B(n,p)를 따른다. 평균은 np, 표준편차는 √(np(1−p))이다. X=k일 확률은 C(n,k)pᵏ(1−p)ⁿ⁻ᵏ이다.",
        "example": "X~B(4,1/2)이므로 평균은 4×1/2=2, 표준편차는 √(4×1/2×1/2)=1이다. 정확히 두 번 성공할 확률은 C(4,2)(1/2)⁴=6/16=3/8이다.",
        "practice": "성공확률 0.2인 독립 시행을 5회 할 때 성공 횟수의 평균과 표준편차를 구하세요.",
        "answer": "평균은 np=5×0.2=1, 표준편차는 √(5×0.2×0.8)=√0.8≈0.894입니다.",
        "practice_hint": "n=5, p=0.2를 사용해 평균과 표준편차 식에 각각 대입하세요.",
        "prompt": "X~B(4,1/2)일 때 평균과 표준편차는?", "options": ["평균 2, 표준편차 1", "평균 1, 표준편차 2", "평균 2, 표준편차 2"], "correct": 0,
        "feedback": "np=2이고 √(np(1−p))=1입니다.", "wrong": "평균과 표준편차 공식을 구분해 각각 대입하세요.",
        "hints": ["n=4, p=1/2입니다.", "평균=np, 표준편차=√(np(1−p))입니다."],
    },
]


def make_quiz(spec: dict[str, object], slug: str) -> dict[str, object]:
    return {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": spec["prompt"], "options": spec["options"], "correct_index": spec["correct"], "correct_feedback": spec["feedback"], "incorrect_feedback": spec["wrong"], "hints": spec["hints"]}}


def main() -> None:
    source_text = SOURCE.read_text(encoding="utf-8")
    official = {m.group(1): re.sub(r"\s+", " ", m.group(2)).strip() for m in re.finditer(r"\[([^\]\s]+-\d{2})\]\s*([^\r\n]*)", source_text)}
    if any(official.get(code) != text for code, text in EXPECTED.items()):
        raise RuntimeError({code: (official.get(code), text) for code, text in EXPECTED.items() if official.get(code) != text})
    chapters = []
    for spec in SPECS:
        if not spec.get("practice_hint") or spec["practice_hint"] in spec["hints"]:
            raise RuntimeError(f"Practice hint must be tailored separately from the quiz hints: {spec['code']}")
        slug = spec["code"].replace("12확통", "prob15-").replace("-", "")
        pages = [
            {"id": slug+"-open", "template": "opening", "title": "상황과 조건 살피기", "blocks": [{"type": "lead", "title": "가상 예시", "text": spec["lead"]}, {"type": "thinking", "title": "먼저 생각하기", "text": "무엇이 조건으로 주어졌는지 표시하고, 사건과 표본공간을 구분합니다."}]},
            {"id": slug+"-concept", "template": "concept", "title": "정의와 성질", "blocks": [{"type": "definition", "title": "핵심 개념", "text": spec["concept"]}, {"type": "formula", "title": "연결한 공식 기준", "text": spec["code"]}, {"type": "misconception", "title": "확인할 점", "text": "조건 또는 시행의 독립 여부를 확인한 다음 공식을 적용합니다."}]},
            {"id": slug+"-example", "template": "example", "title": "예제와 풀이", "blocks": [{"type": "question", "title": "예제", "text": spec["lead"]}, {"type": "solutionStep", "title": "풀이", "text": spec["example"]}, {"type": "verification", "title": "검산", "text": "가정한 조건과 계산한 사건의 결과가 일치하는지 확인합니다."}]},
            {"id": slug+"-practice", "template": "practice", "title": "연습과 설명", "blocks": [{"type": "question", "title": "연습", "text": spec["practice"]}, {"type": "hint", "title": "힌트", "text": spec["practice_hint"]}, {"type": "solutionStep", "title": "해설", "text": spec["answer"]}, {"type": "answer", "title": "정답", "text": spec["answer"]}, make_quiz(spec, slug)]},
            {"id": slug+"-summary", "template": "summary", "title": "핵심 정리", "blocks": [{"type": "summary", "title": "기억할 점", "text": spec["title"]}, {"type": "checklist", "title": "스스로 확인", "text": "공식의 조건과 결과의 의미를 설명할 수 있나요?"}]},
        ]
        chapters.append({"title": spec["title"], "standard_codes": [spec["code"]], "intro": [f"2015 교육과정 공식 기준 {spec['code']}에 연결한 신규 후보입니다.", "수치와 상황은 학습을 위해 직접 만든 가상 예시입니다."], "pages": pages})
    codes = [spec["code"] for spec in SPECS]
    book = {"schema_version": 2, "title": "확률과 통계 · 2015 조건부확률·이항분포 보완 2모듈", "subtitle": "조건부확률의 계산과 이항분포의 평균·표준편차", "category": "concept_textbook_prototype", "curriculum_version": "2015", "tags": ["확률과 통계", "2015 개정", "보완 원고 후보", "가상 예시", "상품 범위 미완"], "standard_codes": codes, "chapters": chapters}
    ids, activities = set(), []
    for chapter in chapters:
        if len(chapter["pages"]) != 5: raise RuntimeError("Expected five pages per module")
        for page in chapter["pages"]:
            if page["id"] in ids: raise RuntimeError(f"Duplicate ID {page['id']}")
            ids.add(page["id"])
            activities.extend(block["activity"] for block in page["blocks"] if block.get("type") == "activity")
    assert len(activities) == 2 and len({a["id"] for a in activities}) == 2
    assert 3/6 == 0.5 and (4/7)*(3/6) / (4/7) == 0.5 and 4/6 == 2/3
    assert 4*0.5 == 2 and math.sqrt(4*0.5*0.5) == 1 and math.comb(4,2)/16 == 3/8
    assert math.isclose(math.sqrt(5*0.2*0.8), math.sqrt(0.8))
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest=canonical_file_sha256(OUT)
    manifest_path=PACKAGE/"REVIEW_MANIFEST.json"
    try: old=json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError,json.JSONDecodeError): old={}
    same=old.get("bookdata_sha256")==digest
    manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"official_2015_appendix8_text","module_count":2,"page_count":10,"native_activity_count":2,"native_activity_kinds":["quiz"],"example_data_status":"synthetic_original_examples; no commercial text, problem, illustration, or dataset copied","curriculum_review_status":"official_2015_codes_verified; product_scope_pending","math_review_status":"pending_full_teacher_review","math_arithmetic_check_status":"pass_for_listed_examples_only","teacher_review_status":"pending","rights_status":"newly_authored; publication_rights_decision_pending","source_interaction_status":"existing independent HTML retained; native UI parity not claimed","integration_status":"not_merged_into_master_book","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if same else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if same else None}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n2015 공식 성취기준 `{codes[0]}`, `{codes[1]}`에 연결한 신규 2모듈·10쪽 V2 후보입니다. 예제와 계산은 직접 만든 가상 예시입니다. 기존 조건부확률·이항분포 HTML은 별도 파일로 보존하며 이 BookData에 자동 임베드되거나 parity가 입증된 것으로 보지 않습니다. 교사 검토와 권리 결정, 과목 범위 전체 대조 전에는 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",encoding="utf-8")
    print(f"Built {len(chapters)} 2015 probability modules, 10 pages, 2 quizzes: {OUT}")


if __name__ == "__main__":
    main()
