"""Add an original V2 module for the 2022 basic probability standard."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "확률과통계_2022개정_기본확률1단원_Batch4_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "확률과통계_2022개정_기본확률1단원_Batch4_원고패키지"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
CODE = "12확통02-01"
CRITERION = "확률의 개념을 이해하고 기본 성질을 설명할 수 있다"


def main() -> None:
    rows = json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]
    official = {row["code"]: row["criterion"].rstrip(" .") for row in rows}
    if official.get(CODE) != CRITERION:
        raise RuntimeError(f"Official curriculum criterion mismatch for {CODE}: {official.get(CODE)!r}")
    slug = "probability-basic-0201"
    quiz = {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "공정한 주사위를 한 번 던질 때 짝수가 나올 확률은?", "options": ["1/2", "1/3", "2/3"], "correct_index": 0, "correct_feedback": "짝수 눈은 2, 4, 6의 세 가지이므로 3/6=1/2입니다.", "incorrect_feedback": "표본공간 6개 중 사건에 해당하는 결과 수를 세세요.", "hints": ["표본공간은 {1,2,3,4,5,6}입니다.", "짝수 사건은 {2,4,6}입니다."]}}
    chapters = [{"title": "확률의 개념과 기본 성질", "intro": [f"공식 성취기준 {CODE}에 연결한 신규 보완 원고입니다.", "주사위·반복 시행 수치는 개념 설명을 위한 가상 예시입니다."], "pages": [
        {"id": slug+"-open", "template": "opening", "title": "확률을 두 방식으로 읽기", "blocks": [{"type": "lead", "title": "가상 예시", "text": "공정한 주사위에서 6이 나올 가능성을 시행 전에 계산할 수 있다. 같은 주사위를 60번 던져 6이 8번 관찰되었다면 결과를 어떻게 비교할까?"}, {"type": "thinking", "title": "먼저 구분하기", "text": "시행 조건을 바탕으로 계산한 이론적 확률과 관찰한 상대도수를 구별합니다."}]},
        {"id": slug+"-concept", "template": "concept", "title": "확률의 뜻과 기본 성질", "blocks": [{"type": "definition", "title": "확률의 개념", "text": "유한한 표본공간의 모든 결과가 같은 가능성으로 일어날 때 사건 A의 확률은 A에 속하는 결과 수를 전체 결과 수로 나눈 값이다. 일반적으로 확률은 사건의 가능성을 0과 1 사이의 수로 나타낸다."}, {"type": "formula", "title": "기본 성질", "text": "0≤P(A)≤1, P(S)=1, P(∅)=0, P(Aᶜ)=1−P(A). 여기서 S는 표본공간이고 Aᶜ는 A의 여사건이다."}, {"type": "misconception", "title": "주의", "text": "유리한 결과 수/전체 결과 수 공식은 모든 결과가 같은 가능성일 때 적용합니다. 반복 시행의 상대도수는 이론적 확률과 매번 같을 필요가 없습니다."}]},
        {"id": slug+"-example", "template": "example", "title": "이론적 확률과 관찰값 비교", "blocks": [{"type": "question", "title": "예제", "text": "공정한 주사위를 60번 던져 6이 8번 나왔다. 이론적 확률과 관찰된 상대도수를 각각 구하고 비교하세요."}, {"type": "solutionStep", "title": "풀이", "text": "한 번 시행에서 6이 나올 이론적 확률은 1/6이다. 관찰된 상대도수는 8/60=2/15이다. 두 값은 다르지만, 한 번의 유한한 시행 결과가 이론적 확률과 정확히 같아야 하는 것은 아니다."}, {"type": "verification", "title": "성질 확인", "text": "1/6과 2/15는 모두 0과 1 사이에 있다. 6이 나오지 않는 사건의 이론적 확률은 1−1/6=5/6이다."}]},
        {"id": slug+"-practice", "template": "practice", "title": "기본 성질 적용하기", "blocks": [{"type": "question", "title": "연습", "text": "표본공간 S={1,2,3,4,5,6}에서 A={2,4,6}이다. P(A), P(Aᶜ), P(S)를 구하세요."}, {"type": "hint", "title": "힌트", "text": "각 사건에 속한 결과 수를 세고, 여사건 성질과 전체 표본공간 성질을 사용하세요."}, {"type": "solutionStep", "title": "해설", "text": "P(A)=3/6=1/2, P(Aᶜ)=1−1/2=1/2, P(S)=1입니다."}, {"type": "answer", "title": "정답", "text": "1/2, 1/2, 1"}, quiz]},
        {"id": slug+"-summary", "template": "summary", "title": "핵심 정리", "blocks": [{"type": "summary", "title": "기억할 점", "text": "확률은 0과 1 사이이며 표본공간의 확률은 1이다. 여사건의 확률은 1에서 원래 사건의 확률을 뺀 값이다."}, {"type": "checklist", "title": "스스로 확인", "text": "이론적 확률과 관찰 상대도수의 차이를 설명하고, 기본 성질을 문제에 적용할 수 있나요?"}]},
    ]}]
    book = {"schema_version": 2, "title": "확률과 통계 · 기본 확률 보완 1모듈 후보", "subtitle": "확률의 개념과 기본 성질", "category": "concept_textbook_prototype", "curriculum_version": "2022", "tags": ["확률과 통계", "2022 개정", "추가 원고 후보", "가상 예시", "학기 배정 미확정"], "standard_codes": [CODE], "chapters": chapters}
    page_ids = [p["id"] for c in chapters for p in c["pages"]]
    if len(page_ids) != len(set(page_ids)) or len(page_ids) != 5:
        raise RuntimeError("Expected five pages with unique IDs")
    assert 3/6 == 0.5 and 8/60 == 2/15 and 1-(3/6) == 0.5
    assert math.isclose(1/6, 0.16666666666666666)
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(OUT.read_bytes()).hexdigest().upper()
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try: old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError): old = {}
    same_hash = old.get("bookdata_sha256") == digest
    manifest = {"bookdata_file": OUT.name, "bookdata_sha256": digest, "candidate_code_references": [CODE], "candidate_code_reference_type": "official_hwp_criterion_table", "module_count": 1, "page_count": 5, "native_activity_count": 1, "native_activity_kinds": ["quiz"], "example_data_status": "synthetic_original_examples; no commercial text, problem, illustration, or dataset copied", "curriculum_review_status": "official_code_and_criterion_verified; semester_and_full_scope_pending", "math_review_status": "candidate_content_mapped_pending_teacher_review", "math_arithmetic_check_status": "pass_for_listed_examples_only", "teacher_review_status": "pending", "rights_status": "newly_authored; publication_rights_decision_pending", "integration_status": "not_merged_into_master_book", "publication_eligibility": "not_eligible", "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same_hash else "pending_current_hash_validation", "runtime_validator_head": old.get("runtime_validator_head") if same_hash else None}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(f"# {book['title']}\n\n공식 기준 `{CODE}`의 확률 개념과 기본 성질을 보완하는 신규 1모듈·5쪽 후보입니다. 이전 통계적 확률 후보의 관찰 상대도수 사례를 이어받되, 표본공간·사건 확률·여사건 등 기본 성질을 직접 설명합니다. 교사 검토와 권리 결정 전에는 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n", encoding="utf-8")
    print(f"Built one basic-probability module, 5 pages, 1 quiz: {OUT}")


if __name__ == "__main__":
    main()
