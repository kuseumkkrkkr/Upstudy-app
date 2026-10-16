"""Build an original, resumable 2022 middle-school algebra candidate batch."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_대수와방정식_부분초안"
BOOK_FILE = "중등수학_2022개정_대수와방정식_BookData_V2_시범.json"
SPECS = [
    {"code": "9수02-08", "slug": "ms22-exponent-laws", "title": "지수법칙과 식의 간단히 하기", "concept": "0이 아닌 수 a와 자연수 m,n에 대해 aᵐ×aⁿ=aᵐ⁺ⁿ이고, (aᵐ)ⁿ=aᵐⁿ입니다. 같은 밑의 곱에서는 지수를 더하고, 거듭제곱의 거듭제곱에서는 지수를 곱합니다.", "example": "2³×2²을 간단히 하세요.", "solution": "밑이 2로 같으므로 지수를 더해 2⁵=32입니다. 직접 곱해도 8×4=32입니다.", "practice": "3²×3³을 하나의 거듭제곱으로 나타내고 값을 구하세요.", "answer": "3⁵=243입니다. 같은 밑의 곱에서 지수를 더합니다.", "quiz": {"id": "ms22-0208-quiz", "kind": "quiz", "prompt": "x⁴×x³은 무엇인가요?", "options": ["x⁷", "x¹²", "2x⁷"], "correct_index": 0, "correct_feedback": "같은 밑의 곱이므로 지수 4와 3을 더합니다.", "incorrect_feedback": "밑을 그대로 두고 지수를 더하세요.", "hints": ["aᵐ×aⁿ=aᵐ⁺ⁿ입니다."]}},
    {"code": "9수02-09", "slug": "ms22-polynomial-add-subtract", "title": "다항식의 덧셈과 뺄셈", "concept": "다항식의 덧셈과 뺄셈에서는 같은 문자 부분을 가진 항끼리 계수를 계산합니다. 뺄셈은 빼는 다항식의 각 항의 부호를 바꾸어 더하면 실수를 줄일 수 있습니다.", "example": "(3x+2)+(x−5)를 간단히 하세요.", "solution": "x항은 3x+x=4x이고 상수항은 2−5=−3이므로 4x−3입니다.", "practice": "(5a−4)−(2a+3)을 간단히 하세요.", "answer": "괄호 앞의 빼기를 분배하면 5a−4−2a−3입니다. 같은 항끼리 계산해 3a−7입니다.", "quiz": {"id": "ms22-0209-quiz", "kind": "quiz", "prompt": "(2x+1)+(3x−4)를 간단히 하면 무엇인가요?", "options": ["5x−3", "5x+5", "x−3"], "correct_index": 0, "correct_feedback": "2x+3x=5x이고 1−4=−3입니다.", "incorrect_feedback": "문자항과 상수항을 따로 계산하세요.", "hints": ["x항끼리, 상수항끼리 묶습니다."]}},
    {"code": "9수02-10", "slug": "ms22-monomial-polynomial", "title": "단항식과 다항식의 곱셈·나눗셈", "concept": "단항식을 다항식에 곱할 때는 분배법칙으로 각 항에 곱합니다. 단항식끼리 나눌 때는 계수와 같은 문자 거듭제곱을 각각 나누며, 분모가 0이 되지 않는 범위에서 계산합니다.", "example": "2x(3x−4)를 전개하세요.", "solution": "분배법칙에 따라 2x×3x−2x×4=6x²−8x입니다.", "practice": "12x²y를 3xy로 나누세요. 단, x와 y는 0이 아닙니다.", "answer": "계수는 12÷3=4이고 x²÷x=x, y÷y=1이므로 4x입니다.", "quiz": {"id": "ms22-0210-quiz", "kind": "quiz", "prompt": "3a(2a+5)를 전개하면 무엇인가요?", "options": ["6a²+15a", "6a+15", "5a²+8a"], "correct_index": 0, "correct_feedback": "3a를 두 항에 각각 곱하면 6a²+15a입니다.", "incorrect_feedback": "분배법칙을 적용해 괄호 안의 각 항에 곱하세요.", "hints": ["3a×2a와 3a×5를 따로 계산합니다."]}},
    {"code": "9수02-11", "slug": "ms22-inequality-properties", "title": "부등식의 성질과 해", "concept": "부등식 양변에 같은 수를 더하거나 빼도 부등호 방향은 유지됩니다. 양변에 양수를 곱하거나 나누어도 방향은 유지되지만, 음수를 곱하거나 나누면 부등호 방향을 반대로 바꾸어야 합니다.", "example": "−2x+3<7에서 양변을 정리할 때 부등호 방향을 설명하세요.", "solution": "양변에서 3을 빼면 −2x<4입니다. 양변을 −2로 나누므로 부등호를 뒤집어 x>−2입니다.", "practice": "−3y≤12를 y에 대한 부등식으로 나타내세요.", "answer": "양변을 −3으로 나누며 방향을 바꾸므로 y≥−4입니다.", "quiz": {"id": "ms22-0211-quiz", "kind": "quiz", "prompt": "−4x>8을 풀면 무엇인가요?", "options": ["x<−2", "x>−2", "x<2"], "correct_index": 0, "correct_feedback": "음수 −4로 나눌 때 부등호를 바꾸어 x<−2입니다.", "incorrect_feedback": "음수로 나누면 부등호 방향이 반대가 됩니다.", "hints": ["양변을 −4로 나눈 뒤 방향을 확인하세요."]}},
    {"code": "9수02-12", "slug": "ms22-linear-inequality", "title": "일차부등식 풀기와 활용", "concept": "일차부등식은 미지수의 차수가 1인 부등식입니다. 등식처럼 항을 정리하되, 음수로 곱하거나 나누는 단계에서는 부등호 방향을 바꾸고, 구한 해가 문제의 조건에 맞는지 확인합니다.", "example": "3x−5≤7을 푸세요.", "solution": "양변에 5를 더해 3x≤12, 양변을 양수 3으로 나누어 x≤4입니다.", "practice": "한 장에 800원인 공책을 사고 500원을 남기려 합니다. 가진 돈이 4,500원 이하일 때 살 수 있는 최대 권수를 구하세요.", "answer": "권수를 n이라 하면 800n+500≤4500입니다. 800n≤4000이므로 n≤5입니다. 최대 5권입니다.", "quiz": {"id": "ms22-0212-quiz", "kind": "quiz", "prompt": "2x+1<9의 해는 무엇인가요?", "options": ["x<4", "x>4", "x<5"], "correct_index": 0, "correct_feedback": "2x<8이므로 x<4입니다.", "incorrect_feedback": "먼저 양변에서 1을 빼고 2로 나눕니다.", "hints": ["2x+1<9에서 상수항을 먼저 옮깁니다."]}},
    {"code": "9수02-13", "slug": "ms22-linear-system", "title": "두 미지수 연립일차방정식", "concept": "연립일차방정식의 해는 두 방정식을 모두 참으로 만드는 순서쌍입니다. 한 식을 다른 식에서 빼거나 더해 미지수 하나를 없애는 방법으로 해를 구한 뒤 두 원래 식에 대입해 확인할 수 있습니다.", "example": "2x+y=7, x−y=2를 풀어 해를 확인하세요.", "solution": "두 식을 더하면 3x=9이므로 x=3입니다. x−y=2에 대입하면 y=1입니다. 첫째 식은 6+1=7, 둘째 식은 3−1=2로 모두 성립합니다.", "practice": "어른 표 값을 a원, 청소년 표 값을 c원이라 하자. 어른 2장과 청소년 1장은 17,000원, 어른 1장과 청소년 2장은 13,000원일 때 각 표 값을 구하세요.", "answer": "2a+c=17,  a+2c=13 (단위: 천 원)입니다. 첫 식에서 c=17−2a를 두 번째 식에 대입하면 a+34−4a=13이므로 a=7, c=3입니다. 어른 표는 7,000원, 청소년 표는 3,000원입니다.", "quiz": {"id": "ms22-0213-quiz", "kind": "quiz", "prompt": "x+y=7, x−y=1의 해는 무엇인가요?", "options": ["(4, 3)", "(3, 4)", "(5, 2)"], "correct_index": 0, "correct_feedback": "두 식을 더해 2x=8, x=4를 얻고 y=3입니다.", "incorrect_feedback": "두 식을 더해 y를 없앤 다음 첫째 식에 대입하세요.", "hints": ["두 식을 더하면 2x=8입니다."]}},
]


def main() -> None:
    official_data = json.loads((ROOT / "work/official-curriculum/2022_math_standards.json").read_text(encoding="utf-8"))
    official = {row["code"]: row["criterion"] for row in official_data["standards"]}
    if any(item["code"] not in official for item in SPECS):
        raise ValueError("A candidate code is absent from the official standards index")
    assert 2**3 * 2**2 == 32 and 3**2 * 3**3 == 243
    assert (3 + 1) + (2 - 5) == 4 - 3
    assert 5 - 2 == 3 and (-4) - 3 == -7
    assert 2 * 3 * (3 * 3 - 4) == 6 * 3**2 - 8 * 3
    assert (12 * 2**2 * 5) / (3 * 2 * 5) == 4 * 2
    assert -2 > -4 and -4 <= -4 and -2 < 0
    assert -4 * -3 > 8 and not (-4 * -2 > 8)
    assert 3 * 4 - 5 <= 7 and 3 * 5 - 5 > 7
    assert 800 * 5 + 500 <= 4500 < 800 * 6 + 500
    assert 2 * 3 + 1 == 7 and 3 - 1 == 2
    assert 2 * 7 + 3 == 17 and 7 + 2 * 3 == 13

    helper_path = Path(__file__).with_name("build_middle_school_1_2_2022_candidate.py")
    spec = importlib.util.spec_from_file_location("ms22_algebra_helpers", helper_path)
    helper = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(helper)
    chapters = []
    for item in SPECS:
        chapter = helper.make_chapter(
            item["code"], item["slug"], item["title"], item["code"],
            "교재 내 표·식 확인 활동", item["title"] + "의 규칙을 식과 예제로 설명해 보세요.",
            item["concept"], item["example"], item["solution"], item["practice"], item["answer"],
            [item["title"] + "의 규칙을 설명한다.", "계산 결과를 원래 식이나 조건에 대입해 확인한다."],
        )
        chapter["intro"][0] = f"공식 기준: {item['code']} {official[item['code']]}"
        chapter["sections"][0]["paragraphs"][0] = f"기준 후보: {item['code']}. 학년군 기준이며 학기 귀속은 미배정입니다."
        chapter["pages"][1]["blocks"] = [
            {"type": "lead", "title": "직접 계산하고 확인하기", "text": "예제의 식을 한 줄씩 변형하고, 각 단계가 주어진 조건을 만족하는지 확인합니다."},
            {"type": "thinking", "title": "관찰 질문", "text": "어떤 항끼리 묶거나 어떤 성질을 적용했나요?"},
            {"type": "hint", "title": "힌트", "text": "한 번에 한 단계만 바꾸고, 바꾸기 전후의 식을 비교하세요."},
            {"type": "answer", "title": "활동 범위", "text": "외부 시뮬레이션 파일 없이 앱 내 지면과 native quiz를 제공합니다."},
        ]
        chapter["pages"][-2]["blocks"].append({"type": "activity", "activity": item["quiz"]})
        chapters.append(chapter)

    tags = ["중등수학", "2022 개정", "학년군 기준", "학년·학기 미배정", "부분 원고 후보", "교사·수학 검수 대기", "권리 검토 대기"]
    codes = [item["code"] for item in SPECS]
    book = {"schema_version": 2, "title": "중등수학 2022 개정 · 대수와 방정식 부분 후보", "subtitle": "공식 학년군 기준별 개념·예제·연습·native quiz", "category": "concept_textbook_prototype", "curriculum_version": "2022", "standard_codes": codes, "standard_coverage": "partial", "grade_semester_status": "not_assigned", "tags": tags + [f"성취기준 후보: {code}" for code in codes], "chapters": chapters, "metadata": {"status": "candidate_partial_draft", "teacher_review_status": "pending", "math_review_status": "author_checks_recorded_independent_review_pending", "rights_status": "pending", "publication_eligibility": "not_eligible", "standard_source": "교육부 고시 제2022-33호 별책8 공식 기준 인덱스", "content_rights": "newly authored candidate; independent rights decision pending", "semester_assignment": "not assigned; middle-school codes are grade-band standards", "external_interactive_assets": []}}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / BOOK_FILE).write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest = {"status": "candidate_partial_draft", "standard_codes": codes, "official_criteria": {code: official[code] for code in codes}, "module_count": len(chapters), "page_count": sum(len(ch["pages"]) for ch in chapters), "native_quiz_ids": [item["quiz"]["id"] for item in SPECS], "arithmetic_checks": "passed", "teacher_review": "pending", "independent_math_review": "pending", "rights_review": "pending", "publication_eligibility": "not_eligible", "semester_assignment": "not assigned"}
    (OUT / "원고매니페스트.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(chapters)} modules, {manifest['page_count']} pages, {len(SPECS)} native quizzes; review and rights pending.")


if __name__ == "__main__":
    main()
