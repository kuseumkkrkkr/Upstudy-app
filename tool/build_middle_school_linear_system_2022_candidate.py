"""Build original, semester-unassigned candidates for two 2022 standards."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_함수와연립방정식_부분초안"
BOOK_FILE = "중등수학_2022개정_함수와연립방정식_BookData_V2_시범.json"
SPECS = [
    {
        "code": "9수02-14", "slug": "ms22-function-input-output",
        "title": "함수의 대응과 함숫값",
        "criterion": "함수의 개념을 이해하고, 함숫값을 구할 수 있다",
        "opening": "입력 하나마다 출력이 하나씩 정해지는 규칙은 어떻게 구별할까요?",
        "concept": "집합 X의 각 원소에 집합 Y의 원소가 하나씩 대응할 때 함수라고 합니다. 서로 다른 입력이 같은 출력에 대응해도 함수일 수 있지만, 한 입력이 두 출력에 대응하면 함수가 아닙니다. f(x)=2x−3이면 입력 x에 대응하는 함숫값은 f(x)로 씁니다.",
        "example": "f(x)=2x−3일 때 f(4)를 구하고, f(x)=5가 되게 하는 x를 구하세요.",
        "solution": "f(4)=2×4−3=5입니다. f(x)=5이면 2x−3=5이므로 2x=8, x=4입니다. 두 결과를 원래 식에 대입해 확인할 수 있습니다.",
        "practice": "g(x)=−3x+2일 때 g(−2)를 구하세요.",
        "answer": "g(−2)=−3×(−2)+2=6+2=8입니다.",
        "quiz": {"id": "ms22-0214-quiz", "kind": "quiz", "prompt": "f(x)=2x−3일 때 f(4)는 얼마인가요?", "options": ["5", "8", "11"], "correct_index": 0, "correct_feedback": "2×4−3=5입니다.", "incorrect_feedback": "x 대신 4를 대입한 뒤 곱셈과 뺄셈을 계산하세요.", "hints": ["f(4)=2×4−3으로 씁니다.", "먼저 2×4를 계산합니다."]},
    },
    {
        "code": "9수02-17", "slug": "ms22-linear-equation-function",
        "title": "두 변수 일차방정식과 일차함수의 그래프",
        "criterion": "일차함수와 미지수가 2개인 일차방정식의 관계를 설명할 수 있다",
        "opening": "두 수의 합이 6이라는 조건을 좌표평면의 점들로 나타내면 어떤 모양일까요?",
        "concept": "두 변수 일차방정식 x+y=6의 해는 x+y=6을 만족하는 순서쌍 (x,y)입니다. y=6−x로 고쳐 쓰면 일차함수의 그래프 위 점과 같은 점들이 해임을 볼 수 있습니다. 일반적으로 ax+by=c에서 b≠0이면 y=(c−ax)/b로 나타내어 직선 그래프와 연결할 수 있습니다.",
        "example": "x+y=6의 해인 순서쌍 세 개를 찾고 그래프에서 공통점을 설명하세요.",
        "solution": "x=0, 2, 6을 차례로 대입하면 (0,6), (2,4), (6,0)을 얻습니다. 세 점은 모두 y=6−x를 만족하므로 같은 직선 위에 있고, 이 직선의 점은 모두 원래 방정식의 해입니다.",
        "practice": "2x+y=8을 y에 대한 식으로 나타내고, x=1일 때 그래프 위의 점을 구하세요.",
        "answer": "y=8−2x입니다. x=1이면 y=6이므로 점 (1,6)입니다. 2×1+6=8이므로 원래 방정식에도 맞습니다.",
        "quiz": {"id": "ms22-0217-quiz", "kind": "quiz", "prompt": "2x+y=8을 만족하는 점은 무엇인가요?", "options": ["(1, 6)", "(1, 5)", "(2, 3)"], "correct_index": 0, "correct_feedback": "2×1+6=8이므로 해입니다.", "incorrect_feedback": "각 좌표를 2x+y=8에 대입해 확인하세요.", "hints": ["x=1을 대입하면 2+y=8입니다."]},
    },
    {
        "code": "9수02-18", "slug": "ms22-two-lines-system",
        "title": "두 직선의 교점과 연립일차방정식",
        "criterion": "두 일차함수의 그래프와 연립일차방정식의 관계를 설명할 수 있다",
        "opening": "두 직선이 만나는 점의 좌표는 두 직선의 식을 동시에 만족할까요?",
        "concept": "두 일차함수 y=f(x), y=g(x)의 그래프가 만나는 점에서는 같은 x에 대해 f(x)=g(x)입니다. 따라서 교점의 좌표는 두 식을 동시에 만족하는 순서쌍이며, 연립일차방정식의 해와 같습니다. 교점이 없으면 공통 해가 없고, 두 직선이 겹치면 공통 해가 여러 개입니다.",
        "example": "y=x+1과 y=−x+5의 그래프 교점과 이에 대응하는 연립방정식의 해를 구하세요.",
        "solution": "교점에서는 x+1=−x+5이므로 2x=4, x=2입니다. y=2+1=3이므로 교점은 (2,3)입니다. 두 식에 대입하면 3=2+1, 3=−2+5로 모두 성립합니다.",
        "practice": "y=2x−1과 y=−x+8의 그래프 교점 좌표를 구하고 두 식에 대입해 확인하세요.",
        "answer": "2x−1=−x+8에서 3x=9, x=3입니다. y=2×3−1=5이므로 교점은 (3,5)입니다. 두 번째 식도 −3+8=5를 줍니다.",
        "quiz": {"id": "ms22-0218-quiz", "kind": "quiz", "prompt": "y=x+1과 y=−x+5의 교점은 무엇인가요?", "options": ["(2, 3)", "(3, 2)", "(1, 4)"], "correct_index": 0, "correct_feedback": "x+1=−x+5에서 x=2, y=3입니다.", "incorrect_feedback": "먼저 두 식의 y값을 같게 놓고 x를 구하세요.", "hints": ["x+1=−x+5를 풀어 x를 찾습니다.", "구한 x를 식에 대입해 y를 찾습니다."]},
    },
]


def main() -> None:
    standards_doc = json.loads((ROOT / "work/official-curriculum/2022_math_standards.json").read_text(encoding="utf-8"))
    official = {row["code"]: row["criterion"] for row in standards_doc["standards"]}
    for item in SPECS:
        if official.get(item["code"]) != item["criterion"]:
            raise ValueError(f"Official standard missing: {item['code']}")
        assert 2 * 1 + 6 == 8
    assert 2 * 4 - 3 == 5
    assert -3 * -2 + 2 == 8
    assert (2 + 1) == (-2 + 5)
    assert 2 * 3 - 1 == -3 + 8 == 5
    helper_path = Path(__file__).with_name("build_middle_school_1_2_2022_candidate.py")
    helper_spec = importlib.util.spec_from_file_location("ms22_book_helpers", helper_path)
    helper = importlib.util.module_from_spec(helper_spec)
    assert helper_spec and helper_spec.loader
    helper_spec.loader.exec_module(helper)

    chapters = []
    for item in SPECS:
        chapter = helper.make_chapter(
            item["code"], item["slug"], item["title"], item["code"],
            "앱 내 BookData 지면과 native quiz", item["opening"], item["concept"],
            item["example"], item["solution"], item["practice"], item["answer"],
            [item["title"] + "의 관계를 식과 그래프로 설명한다.", "찾은 점을 원래 식에 대입해 확인한다."],
        )
        chapter["intro"][0] = f"공식 기준: {item['code']} {official[item['code']]}"
        chapter["sections"][0]["paragraphs"][0] = (
            f"기준 후보: {item['code']}. 앱 내 지면과 native quiz를 연결한 부분 원고입니다."
        )
        chapter["pages"][1]["blocks"] = [
            {"type": "lead", "title": "직접 확인하기", "text": "예제의 관계를 표와 식으로 나타내고, 각 단계가 원래 조건을 만족하는지 확인하세요."},
            {"type": "thinking", "title": "관찰 질문", "text": "입력·좌표·식 중 무엇을 바꾸어도 같은 관계가 유지되나요?"},
            {"type": "hint", "title": "힌트", "text": "한 번에 하나의 값을 대입해 좌변과 우변을 비교하세요."},
            {"type": "answer", "title": "활동 범위", "text": "이 시범에는 외부 시뮬레이션 파일이 없습니다. 앱 내 native quiz와 풀이 지면을 제공합니다."},
        ]
        chapter["pages"][-2]["blocks"].append({"type": "activity", "activity": item["quiz"]})
        chapters.append(chapter)

    tags = ["중등수학", "2022 개정", "학년·학기 미배정", "부분 원고 후보", "교사·수학 검수 대기", "권리 검토 대기"]
    book = {
        "schema_version": 2,
        "title": "중등수학 2022 개정 · 함수와 연립방정식 부분 후보",
        "subtitle": "공식 기준 후보와 원고·native quiz 연결",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2022",
        "standard_codes": [item["code"] for item in SPECS],
        "standard_coverage": "partial",
        "grade_semester_status": "not_assigned",
        "tags": tags + [f"성취기준 후보: {item['code']}" for item in SPECS],
        "chapters": chapters,
        "metadata": {"status": "candidate_partial_draft", "teacher_review_status": "pending", "math_review_status": "pending", "rights_status": "pending", "publication_eligibility": "not_eligible", "source": "교육부 고시 제2022-33호 별책8 공식 기준 인덱스", "content_rights": "newly authored candidate; independent rights decision pending", "semester_assignment": "not assigned; middle-school codes are grade-band standards"},
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / BOOK_FILE).write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest = {"status": "candidate_partial_draft", "standard_codes": book["standard_codes"], "official_criteria": {code: official[code] for code in book["standard_codes"]}, "module_count": len(chapters), "page_count": sum(len(chapter["pages"]) for chapter in chapters), "interactive_blocks": [item["quiz"]["id"] for item in SPECS], "curriculum_review": "pending", "teacher_review": "pending", "independent_math_review": "pending", "rights_review": "pending", "publication_eligibility": "not_eligible", "semester_assignment": "not assigned"}
    (OUT / "원고매니페스트.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(chapters)} modules, {manifest['page_count']} pages, {len(SPECS)} native quizzes; review and rights pending.")


if __name__ == "__main__":
    main()
