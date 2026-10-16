"""Build original, semester-unassigned 2022 quadratic-equation/function modules."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_이차방정식과이차함수_부분초안"
BOOK_FILE = "중등수학_2022개정_이차방정식과이차함수_BookData_V2_시범.json"
SPECS = [
    {"code": "9수02-20", "slug": "ms22-quadratic-equation", "title": "이차방정식의 해와 활용", "concept": "이차방정식은 ax²+bx+c=0 (a≠0) 꼴의 방정식입니다. 인수분해하여 곱이 0이 되게 하는 두 경우를 찾거나, 식을 동치인 형태로 바꾸어 해를 구합니다. 문제의 상황에서는 길이처럼 양수 조건이 붙을 수 있으므로 해가 맥락에 맞는지도 확인합니다.", "example": "x²−5x+6=0을 풀어 해를 확인하세요.", "solution": "x²−5x+6=(x−2)(x−3)이므로 x=2 또는 x=3입니다. 각각 대입하면 4−10+6=0, 9−15+6=0입니다.", "practice": "직사각형의 넓이는 12 cm²이고 긴 변이 짧은 변보다 1 cm 깁니다. 두 변의 길이를 구하세요.", "answer": "짧은 변을 w cm라 하면 w(w+1)=12, 즉 w²+w−12=0입니다. (w+4)(w−3)=0에서 w=−4 또는 3이고, 길이는 양수이므로 w=3입니다. 긴 변은 4 cm입니다.", "quiz": {"id": "ms22-0220-quiz", "kind": "quiz", "prompt": "x²−5x+6=0의 해는 무엇인가요?", "options": ["2와 3", "−2와 −3", "1과 6"], "correct_index": 0, "correct_feedback": "(x−2)(x−3)=0이므로 x=2 또는 x=3입니다.", "incorrect_feedback": "곱해서 6, 더해서 5가 되는 두 수를 찾아 인수분해하세요.", "hints": ["x²−5x+6=(x−2)(x−3)입니다."]}},
    {"code": "9수02-21", "slug": "ms22-quadratic-function", "title": "이차함수의 뜻과 함숫값", "concept": "이차함수는 f(x)=ax²+bx+c (a≠0)처럼 입력 x에 대해 하나의 함숫값을 정하는 함수입니다. x² 항의 계수가 0이 아니므로 일차함수와 구별됩니다. 이 모듈은 식의 형태와 함숫값을 다루며 그래프의 모양·성질은 별도 기준에서 확인합니다.", "example": "f(x)=x²−4x+1일 때 f(3)을 구하세요.", "solution": "x 대신 3을 대입하면 f(3)=3²−4×3+1=9−12+1=−2입니다.", "practice": "g(x)=−2x²+3x+1일 때 g(−1)을 구하세요.", "answer": "g(−1)=−2×(−1)²+3×(−1)+1=−2−3+1=−4입니다.", "quiz": {"id": "ms22-0221-quiz", "kind": "quiz", "prompt": "f(x)=x²−4x+1일 때 f(3)은 얼마인가요?", "options": ["−2", "2", "14"], "correct_index": 0, "correct_feedback": "9−12+1=−2입니다.", "incorrect_feedback": "x 대신 3을 대입하고 제곱을 먼저 계산하세요.", "hints": ["f(3)=3²−4×3+1입니다."]}},
]


def main() -> None:
    official_data = json.loads((ROOT / "work/official-curriculum/2022_math_standards.json").read_text(encoding="utf-8"))
    official = {row["code"]: row["criterion"] for row in official_data["standards"]}
    if any(item["code"] not in official for item in SPECS):
        raise ValueError("A candidate code is absent from the official standards index")
    assert (2 - 2) * (2 - 3) == 0 and (3 - 2) * (3 - 3) == 0
    assert 3 * 4 == 12 and 4 - 3 == 1
    assert 3**2 - 4 * 3 + 1 == -2
    assert -2 * (-1) ** 2 + 3 * (-1) + 1 == -4

    helper_path = Path(__file__).with_name("build_middle_school_1_2_2022_candidate.py")
    spec = importlib.util.spec_from_file_location("ms22_quadratic_helpers", helper_path)
    helper = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(helper)
    chapters = []
    for item in SPECS:
        chapter = helper.make_chapter(
            item["code"], item["slug"], item["title"], item["code"],
            "교재 내 식·표 확인 활동", item["title"] + "의 규칙과 풀이를 설명해 보세요.",
            item["concept"], item["example"], item["solution"], item["practice"], item["answer"],
            [item["title"] + "의 정의와 조건을 설명한다.", "해와 함숫값을 원래 식에 대입해 확인한다."],
        )
        chapter["intro"][0] = f"공식 기준: {item['code']} {official[item['code']]}"
        chapter["sections"][0]["paragraphs"][0] = f"기준 후보: {item['code']}. 학년군 기준이며 학기 귀속은 미배정입니다."
        chapter["pages"][1]["blocks"] = [
            {"type": "lead", "title": "직접 계산하고 확인하기", "text": "예제의 식을 단계별로 정리하고, 구한 값이 조건을 만족하는지 대입해 확인합니다."},
            {"type": "thinking", "title": "관찰 질문", "text": "이차항의 계수와 해 또는 함숫값은 식에서 어떻게 확인할 수 있나요?"},
            {"type": "hint", "title": "힌트", "text": "먼저 식의 형태를 보고, 그 다음 해나 입력값을 대입하세요."},
            {"type": "answer", "title": "활동 범위", "text": "외부 시뮬레이션 파일 없이 앱 내 지면과 native quiz를 제공합니다. 이차함수 그래프 조작은 포함하지 않습니다."},
        ]
        chapter["pages"][-2]["blocks"].append({"type": "activity", "activity": item["quiz"]})
        chapters.append(chapter)

    codes = [item["code"] for item in SPECS]
    book = {"schema_version": 2, "title": "중등수학 2022 개정 · 이차방정식과 이차함수 부분 후보", "subtitle": "공식 학년군 기준별 개념·예제·연습·native quiz", "category": "concept_textbook_prototype", "curriculum_version": "2022", "standard_codes": codes, "standard_coverage": "partial", "grade_semester_status": "not_assigned", "tags": ["중등수학", "2022 개정", "학년군 기준", "학년·학기 미배정", "부분 원고 후보", "교사·수학 검수 대기", "권리 검토 대기", *[f"성취기준 후보: {code}" for code in codes]], "chapters": chapters, "metadata": {"status": "candidate_partial_draft", "teacher_review_status": "pending", "math_review_status": "author_checks_recorded_independent_review_pending", "rights_status": "pending", "publication_eligibility": "not_eligible", "standard_source": "교육부 고시 제2022-33호 별책8 공식 기준 인덱스", "content_rights": "newly authored candidate; independent rights decision pending", "semester_assignment": "not assigned; middle-school codes are grade-band standards", "external_interactive_assets": []}}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / BOOK_FILE).write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest = {"status": "candidate_partial_draft", "standard_codes": codes, "official_criteria": {code: official[code] for code in codes}, "module_count": len(chapters), "page_count": sum(len(ch["pages"]) for ch in chapters), "native_quiz_ids": [item["quiz"]["id"] for item in SPECS], "arithmetic_checks": "passed", "teacher_review": "pending", "independent_math_review": "pending", "rights_review": "pending", "publication_eligibility": "not_eligible", "semester_assignment": "not assigned"}
    (OUT / "원고매니페스트.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(chapters)} modules, {manifest['page_count']} pages, {len(SPECS)} native quizzes; review and rights pending.")


if __name__ == "__main__":
    main()
