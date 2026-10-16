"""Generate supplemental drafts for eight partially evidenced 2015 Math criteria."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"

UNITS = [
    {
        "code": "10수학01-10", "volume": "상", "area": "방정식과 부등식", "slug": "포물선과직선의위치관계",
        "title": "이차함수 그래프와 직선의 위치 관계",
        "concept": "이차함수 y=f(x)의 그래프와 직선 y=mx+n의 교점은 f(x)=mx+n의 실근에 대응합니다. 정리한 이차방정식의 판별식이 양수이면 두 점, 0이면 한 점에서 만나고, 음수이면 만나지 않습니다.",
        "example": "포물선 y=x²과 직선 y=2x+3의 교점 개수와 좌표를 구하세요.",
        "steps": ["x²=2x+3을 정리하면 x²−2x−3=0입니다.", "(x−3)(x+1)=0이므로 x=3 또는 x=−1입니다.", "각 x를 직선에 대입하면 교점은 (3,9), (−1,1)입니다."],
        "answer": "두 점 (3,9), (−1,1)에서 만납니다.",
        "practice": "y=x²−4와 y=0의 교점 개수와 좌표를 구하세요.",
        "practice_steps": ["x²−4=0을 풀면 x=−2 또는 x=2입니다.", "두 교점의 y좌표는 0입니다."], "practice_answer": "(−2,0), (2,0)의 두 점",
        "quiz": "y=x²과 y=2x−1은 몇 점에서 만나나요?", "options": ["한 점", "두 점", "만나지 않는다"], "correct": 0,
        "feedback": "x²=2x−1에서 (x−1)²=0이므로 한 점 (1,1)에서 만납니다.",
        "hint": "두 그래프의 y값을 같게 놓고 판별식을 확인하세요.",
    },
    {
        "code": "10수학01-11", "volume": "상", "area": "방정식과 부등식", "slug": "이차함수최대최소활용",
        "title": "이차함수의 최댓값·최솟값과 활용",
        "concept": "y=a(x−p)²+q에서 (x−p)²≥0입니다. a>0이면 꼭짓점에서 최솟값 q를, a<0이면 최댓값 q를 갖습니다. 문제의 정의역이 제한되면 꼭짓점뿐 아니라 구간 끝의 함수값도 비교합니다.",
        "example": "가로와 세로의 합이 10인 직사각형의 넓이 최댓값을 구하세요.",
        "steps": ["가로를 x라 하면 세로는 10−x이고 0<x<10입니다.", "넓이 A=x(10−x)=−(x−5)²+25입니다.", "x=5에서 넓이의 최댓값은 25입니다."], "answer": "가로 5, 세로 5일 때 25",
        "practice": "0≤x≤3에서 f(x)=−(x−1)²+4의 최댓값과 최솟값을 구하세요.",
        "practice_steps": ["아래로 열린 포물선이므로 꼭짓점 x=1에서 최댓값 4입니다.", "끝점 값은 f(0)=3, f(3)=0이므로 최솟값은 0입니다."], "practice_answer": "최댓값 4, 최솟값 0",
        "quiz": "−2≤x≤4에서 f(x)=−(x−1)²+5의 최댓값은?", "options": ["5", "4", "−4"], "correct": 0,
        "feedback": "꼭짓점 x=1이 구간 안에 있고 아래로 열린 포물선이므로 최댓값은 5입니다.", "hint": "꼭짓점이 정의역 구간 안에 있는지 먼저 확인하세요.",
    },
    {
        "code": "10수학01-12", "volume": "상", "area": "방정식과 부등식", "slug": "사차방정식풀이",
        "title": "치환과 인수분해로 사차방정식 풀기",
        "concept": "x⁴처럼 짝수 거듭제곱만 있는 식은 t=x²로 치환하면 t에 대한 이차방정식이 될 수 있습니다. 다만 t=x²이므로 t≥0이어야 하며, 구한 t마다 x²=t를 다시 풀어야 합니다.",
        "example": "x⁴−5x²+4=0을 푸세요.",
        "steps": ["t=x² (t≥0)로 놓으면 t²−5t+4=0입니다.", "(t−1)(t−4)=0이므로 t=1 또는 t=4입니다.", "x²=1 또는 x²=4를 풀어 x=±1, ±2를 얻습니다."], "answer": "x=−2, −1, 1, 2",
        "practice": "x⁴−10x²+9=0을 푸세요.",
        "practice_steps": ["t=x²로 놓으면 t²−10t+9=(t−1)(t−9)=0입니다.", "t=1,9이고 둘 다 0 이상입니다.", "x²=1 또는 9이므로 x=±1, ±3입니다."], "practice_answer": "x=−3, −1, 1, 3",
        "quiz": "x⁴−13x²+36=0의 해는?", "options": ["x=±2, ±3", "x=2,3만", "x=±6"], "correct": 0,
        "feedback": "t=x²로 두면 (t−4)(t−9)=0이어서 x=±2, ±3입니다.", "hint": "x²=t로 치환한 뒤 t의 근에서 x를 다시 구하세요.",
    },
    {
        "code": "10수학01-16", "volume": "상", "area": "방정식과 부등식", "slug": "이차함수와연립이차부등식",
        "title": "이차함수와 연립이차부등식",
        "concept": "이차부등식 f(x)≥0의 해는 그래프 y=f(x)가 x축 위에 있거나 만나는 x의 범위입니다. 연립부등식은 각 부등식의 해집합을 구한 뒤 교집합을 취합니다.",
        "example": "x²+x−2≤0과 x²≤4를 함께 푸세요.",
        "steps": ["x²+x−2=(x+2)(x−1)이므로 첫 부등식의 해는 −2≤x≤1입니다.", "x²≤4의 해는 −2≤x≤2입니다.", "두 구간의 교집합을 구합니다."], "answer": "−2≤x≤1",
        "practice": "x²−x−2≥0과 x²<9를 함께 푸세요.",
        "practice_steps": ["(x−2)(x+1)≥0의 해는 x≤−1 또는 x≥2입니다.", "x²<9의 해는 −3<x<3입니다.", "두 해집합의 교집합을 취합니다."], "practice_answer": "−3<x≤−1 또는 2≤x<3",
        "quiz": "x²−1≤0과 x≥0의 공통 해는?", "options": ["0≤x≤1", "x≤−1 또는 x≥1", "−1≤x≤1"], "correct": 0,
        "feedback": "첫 해는 −1≤x≤1이고, x≥0과의 교집합은 0≤x≤1입니다.", "hint": "각 부등식의 해를 따로 구하고 겹치는 부분만 남기세요.",
    },
    {
        "code": "10수학02-02", "volume": "상", "area": "도형의 방정식", "slug": "내분점외분점",
        "title": "선분의 내분점과 외분점 좌표",
        "concept": "A(x₁,y₁), B(x₂,y₂)를 AP:PB=m:n으로 내분하는 점은 ((n x₁+m x₂)/(m+n), (n y₁+m y₂)/(m+n))입니다. 외분점은 m≠n일 때 ((m x₂−n x₁)/(m−n), (m y₂−n y₁)/(m−n))입니다.",
        "example": "A(0,0), B(6,3)을 AP:PB=1:2로 내분하는 점을 구하세요.",
        "steps": ["내분 공식에서 m=1,n=2를 대입합니다.", "x좌표는 (2·0+1·6)/3=2입니다.", "y좌표는 (2·0+1·3)/3=1입니다."], "answer": "P(2,1)",
        "practice": "A(0,0), B(6,3)을 AP:PB=2:1로 외분하는 점을 구하세요.",
        "practice_steps": ["외분 공식에 m=2,n=1을 대입합니다.", "x=(2·6−1·0)/(2−1)=12, y=(2·3−1·0)/(2−1)=6입니다."], "practice_answer": "P(12,6)",
        "quiz": "A(0,0), B(8,4)를 1:3으로 내분하는 점은?", "options": ["(2,1)", "(6,3)", "(4,2)"], "correct": 0,
        "feedback": "(3A+1B)/4=(2,1)입니다.", "hint": "AP:PB=m:n이면 A 쪽 좌표에 n, B 쪽에 m을 곱합니다.",
    },
    {
        "code": "10수학02-09", "volume": "상", "area": "도형의 방정식", "slug": "직선yx대칭",
        "title": "직선 y=x에 대한 대칭이동",
        "concept": "점 (a,b)를 직선 y=x에 대하여 대칭이동하면 좌표가 서로 바뀌어 (b,a)가 됩니다. 직선 y=x 위의 점은 두 좌표가 같으므로 대칭이동 뒤에도 그대로입니다.",
        "example": "점 P(2,−3)을 직선 y=x에 대하여 대칭이동한 점을 구하세요.",
        "steps": ["y=x 대칭은 x좌표와 y좌표를 서로 바꿉니다.", "(2,−3)을 (−3,2)로 바꿉니다.", "원래 점과 대칭점의 중점 (−1/2,−1/2)은 y=x 위에 있습니다."], "answer": "(−3,2)",
        "practice": "점 (4,4)와 (1,5)를 각각 y=x에 대하여 대칭이동하세요.",
        "practice_steps": ["(4,4)는 좌표가 같아 그대로입니다.", "(1,5)는 좌표를 바꾸어 (5,1)입니다."], "practice_answer": "(4,4), (5,1)",
        "quiz": "점 (−2,7)의 y=x 대칭점은?", "options": ["(7,−2)", "(2,−7)", "(−2,−7)"], "correct": 0,
        "feedback": "직선 y=x 대칭은 두 좌표를 맞바꿉니다.", "hint": "x좌표와 y좌표의 자리를 서로 바꾸세요.",
    },
    {
        "code": "10수학03-01", "volume": "하", "area": "수와 연산", "slug": "집합개념과표현",
        "title": "집합의 개념과 표현",
        "concept": "집합은 대상이 무엇인지 분명하고, 각 대상이 원소인지 아닌지를 판단할 수 있는 모임입니다. 원소를 직접 나열하는 방법과 조건을 이용해 {x | 조건}으로 나타내는 방법이 있습니다.",
        "example": "A={x∈Z | −1≤x<3}을 원소나열법으로 나타내세요.",
        "steps": ["정수 가운데 −1 이상 3 미만인 수를 찾습니다.", "해당 정수는 −1, 0, 1, 2입니다.", "집합의 원소를 중복 없이 나열합니다."], "answer": "A={−1,0,1,2}",
        "practice": "B={x∈N | x는 10의 양의 약수}를 원소나열법으로 나타내세요. (N은 양의 정수)",
        "practice_steps": ["10의 양의 약수는 1,2,5,10입니다.", "각 원소를 한 번씩 씁니다."], "practice_answer": "B={1,2,5,10}",
        "quiz": "집합을 판별하는 조건으로 가장 알맞은 것은?", "options": ["대상이 원소인지 분명히 판단할 수 있다", "원소의 개수가 반드시 3개이다", "원소는 숫자만 가능하다"], "correct": 0,
        "feedback": "집합은 각 대상의 포함 여부가 명확해야 합니다.", "hint": "모임의 구성원이 되는지 객관적으로 판단 가능한지 보세요.",
    },
    {
        "code": "10수학03-04", "volume": "하", "area": "수와 연산", "slug": "전칭존재명제",
        "title": "모든과 어떤을 포함한 명제",
        "concept": "‘모든 x에 대하여 P(x)’는 정해진 논의 영역의 모든 원소에서 P가 참이라는 뜻이고, ‘어떤 x가 존재하여 P(x)’는 적어도 하나에서 참이라는 뜻입니다. 참·거짓은 논의 영역에 따라 달라질 수 있습니다.",
        "example": "실수 x에 대하여 ‘모든 x는 x²≥0이다’와 ‘어떤 x는 x²=2이다’를 판단하세요.",
        "steps": ["모든 실수의 제곱은 0 이상이므로 첫 명제는 참입니다.", "x=√2를 택하면 x²=2이므로 둘째 명제도 참입니다.", "전칭명제는 임의의 원소에서 확인하고, 존재명제는 한 예를 제시하면 됩니다."], "answer": "두 명제 모두 참",
        "practice": "정수 n에 대한 ‘모든 n은 짝수이다’와 ‘어떤 n은 홀수이다’를 판단하세요.",
        "practice_steps": ["n=1은 홀수이므로 첫 명제의 반례입니다.", "n=1을 택하면 둘째 명제는 참입니다."], "practice_answer": "첫 명제는 거짓, 둘째 명제는 참",
        "quiz": "논의 영역이 정수일 때 ‘어떤 n은 n²=2이다’는?", "options": ["거짓", "참", "논의 영역과 무관하게 참"], "correct": 0,
        "feedback": "정수의 제곱이 2가 되는 경우는 없습니다.", "hint": "정수에서 제곱수가 2가 될 수 있는지 확인하세요.",
    },
]


def page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def make_book(unit: dict) -> dict:
    code = unit["code"]
    prefix = f"math15-supp-{code.replace('-', '').lower()}-{unit['slug']}"
    tags = [f"수학({'상' if unit['volume'] == '상' else '하'})", "2015 개정", code, unit["area"], unit["title"], "보충 V2 후보"]
    pages = [
        page(f"{prefix}-opening", "opening", unit["title"], [
            {"type": "lead", "title": "오늘의 질문", "text": unit["example"]},
            {"type": "thinking", "title": "먼저 생각하기", "text": "공식만 적용하기 전에 대상·조건·정의역을 확인하고 그림이나 식으로 관계를 나타내 보세요."},
            {"type": "answer", "title": "핵심 확인", "text": unit["answer"]},
        ]),
        page(f"{prefix}-concept", "concept", unit["title"], [
            {"type": "definition", "title": "개념", "text": unit["concept"]},
            {"type": "misconception", "title": "확인할 점", "text": "부호, 정의역, 조건의 방향을 확인하고 구한 답을 원래 식이나 상황에 대입해 검산하세요."},
        ]),
        page(f"{prefix}-example", "example", "예제로 풀이 순서 익히기", [
            {"type": "question", "title": "예제", "text": unit["example"]},
            {"type": "solutionStep", "title": "풀이", "items": unit["steps"]},
            {"type": "answer", "title": "답", "text": unit["answer"]},
        ]),
        page(f"{prefix}-practice", "practice", "스스로 풀고 확인하기", [
            {"type": "question", "title": "연습", "text": unit["practice"]},
            {"type": "solutionStep", "title": "풀이와 검산", "items": unit["practice_steps"]},
            {"type": "answer", "title": "정답", "text": unit["practice_answer"]},
            {"type": "activity", "activity": {
                "id": f"{prefix}-quiz", "kind": "quiz", "prompt": unit["quiz"], "options": unit["options"],
                "correct_index": unit["correct"], "correct_feedback": unit["feedback"],
                "incorrect_feedback": unit["hint"], "hints": [unit["hint"]],
            }},
        ]),
    ]
    chapter = {"title": unit["title"], "standard_codes": [code], "tags": tags, "pages": pages}
    return {
        "title": f"수학({unit['volume']}) 2015 개정 · {unit['title']} 보충 후보",
        "subtitle": "기존 부분 후보의 미확인 기준 요소를 보강하는 재개형 원고",
        "category": "concept_textbook", "curriculum_version": "2015", "standard_codes": [code],
        "tags": tags, "schema_version": 2, "chapters": [chapter],
        "metadata": {
            "status": "authored_partial_draft", "edition_status": "editorial_split_candidate",
            "standard_code_status": "candidate_exact_code_pending_teacher_review",
            "publication_eligibility": "not_eligible", "rights_status": "pending",
            "teacher_review_status": "pending", "math_review_status": "author_checks_recorded_independent_review_pending",
            "source_basis": "2015 Appendix 8 official achievement-standard statement",
        },
    }


def validate_math() -> None:
    # Parabola/line intersections; repeated and absent intersections.
    assert [x for x in (-1, 3) if x * x == 2 * x + 3] == [-1, 3]
    assert (-2) ** 2 - 4 * 1 * 1 == 0
    # Vertex and restricted-domain extrema.
    assert max(x * (10 - x) for x in range(11)) == 25
    assert min((-(x - 1) ** 2 + 4) for x in range(4)) == 0
    # Quartic substitutions.
    assert {x for x in range(-3, 4) if x**4 - 5 * x**2 + 4 == 0} == {-2, -1, 1, 2}
    assert {x for x in range(-4, 5) if x**4 - 10 * x**2 + 9 == 0} == {-3, -1, 1, 3}
    # Compound inequality intersections.
    assert [x for x in range(-5, 6) if x * x + x - 2 <= 0 and x * x <= 4] == [-2, -1, 0, 1]
    assert [x for x in range(-5, 6) if x * x - x - 2 >= 0 and x * x < 9] == [-2, -1, 2]
    # Section and external division formulas.
    assert ((2 * 0 + 1 * 6) / 3, (2 * 0 + 1 * 3) / 3) == (2, 1)
    assert ((2 * 6 - 1 * 0) / 1, (2 * 3 - 1 * 0) / 1) == (12, 6)
    # Reflection across y=x.
    assert (2, -3)[::-1] == (-3, 2)
    # Set comprehension and quantifier counterexamples/witnesses.
    assert {x for x in range(-5, 6) if -1 <= x < 3} == {-1, 0, 1, 2}
    assert all(x * x >= 0 for x in range(-10, 11)) and abs((2**0.5) ** 2 - 2) < 1e-12
    assert any(n % 2 != 0 for n in range(-5, 6))
    assert not any(n * n == 2 for n in range(-100, 101))


def main() -> None:
    validate_math()
    for unit in UNITS:
        volume_folder = f"수학{'상' if unit['volume'] == '상' else '하'}_2015개정_초안"
        output_dir = MANUSCRIPTS / volume_folder
        output_dir.mkdir(parents=True, exist_ok=True)
        filename = f"수학{'상' if unit['volume'] == '상' else '하'}_2015개정_{unit['slug']}_보충V2_BookData_초안.json"
        target = output_dir / filename
        serialized = json.dumps(make_book(unit), ensure_ascii=False, indent=2) + "\n"
        if not target.exists() or target.read_text(encoding="utf-8") != serialized:
            target.write_text(serialized, encoding="utf-8")
        verified = json.loads(target.read_text(encoding="utf-8"))
        chapter = verified["chapters"][0]
        if verified["standard_codes"] != [unit["code"]] or chapter["standard_codes"] != [unit["code"]]:
            raise RuntimeError(f"Standard-code mismatch: {unit['code']}")
        if len(chapter["pages"]) != 4 or len({p["id"] for p in chapter["pages"]}) != 4:
            raise RuntimeError(f"Invalid four-page structure: {unit['code']}")
        activity = next(b["activity"] for b in chapter["pages"][-1]["blocks"] if b.get("type") == "activity")
        if activity["kind"] != "quiz" or not 0 <= activity["correct_index"] < len(activity["options"]):
            raise RuntimeError(f"Invalid native quiz: {unit['code']}")
        readme = output_dir / "README.md"
        text = readme.read_text(encoding="utf-8")
        if f"[{filename}]" not in text:
            text = text.rstrip() + f"\n\n## {unit['title']} · 보충 V2\n\n- [{filename}]({filename}): 미확인 기준 요소 보충 4쪽과 native quiz, `{unit['code']}` 연결 후보\n- 사람 검토와 권리 확인 전이며 기존 통합본에 병합되지 않은 별도 후보입니다.\n"
            readme.write_text(text, encoding="utf-8")
    print(f"Generated/resumed {len(UNITS)} supplemental 2015 Math drafts with native quizzes.")


if __name__ == "__main__":
    main()
