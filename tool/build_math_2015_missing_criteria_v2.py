"""Generate resumable, code-tagged drafts for 10 uncovered 2015 Math criteria."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"

# Authored from the official criterion statements. These are candidate lessons,
# not independently reviewed textbook content.
UNITS = [
    {
        "code": "10수학01-02", "volume": "상", "area": "다항식", "slug": "항등식",
        "title": "항등식의 성질과 계수 비교", "concept": "항등식은 문자에 어떤 값을 대입해도 항상 참인 등식입니다. 두 다항식이 항등식이면 같은 차수의 계수가 각각 같습니다. 예를 들어 ax+2=5x+b가 항등식이면 a=5, b=2입니다.",
        "example": "3(x−2)+4와 3x−2가 항등식임을 전개하여 확인하세요.", "steps": ["왼쪽을 전개하면 3x−6+4=3x−2입니다.", "오른쪽 다항식과 모든 x에서 같은 식입니다."], "answer": "항등식입니다.",
        "practice": "(a−2)x+3=4x+b가 항등식일 때 a,b를 구하세요.", "practice_steps": ["x의 계수를 비교하면 a−2=4이므로 a=6입니다.", "상수항을 비교하면 3=b이므로 b=3입니다."], "practice_answer": "a=6, b=3",
        "quiz": "2(x+3)−1과 2x+5의 관계는 무엇인가요?", "options": ["항등식이다", "x=0일 때만 참이다", "항등식이 아니다"], "correct": 0, "feedback": "전개하면 2x+6−1=2x+5이므로 모든 x에서 참입니다.", "hint": "왼쪽을 먼저 전개하고 양변을 비교하세요.",
    },
    {
        "code": "10수학01-15", "volume": "상", "area": "방정식과 부등식", "slug": "절댓값일차부등식",
        "title": "절댓값을 포함한 일차부등식", "concept": "a>0일 때 |x−m|<a는 m−a<x<m+a와 같고, |x−m|>a는 x<m−a 또는 x>m+a와 같습니다. 절댓값은 수직선에서 두 수 사이의 거리로 해석합니다.",
        "example": "|x−2|<3을 푸세요.", "steps": ["x와 2 사이의 거리가 3보다 작다는 뜻입니다.", "2−3<x<2+3으로 바꿉니다."], "answer": "−1<x<5",
        "practice": "|x+1|≥2를 푸세요.", "practice_steps": ["|x−(−1)|≥2로 보고 −1에서 거리가 2 이상인 수를 찾습니다.", "x≤−3 또는 x≥1입니다."], "practice_answer": "x≤−3 또는 x≥1",
        "quiz": "|x−4|≤1의 해는 무엇인가요?", "options": ["3≤x≤5", "x≤3 또는 x≥5", "−5≤x≤−3"], "correct": 0, "feedback": "4에서 거리가 1 이하인 수이므로 3≤x≤5입니다.", "hint": "중심 4에서 왼쪽과 오른쪽으로 1씩 이동하세요.",
    },
    {
        "code": "10수학02-05", "volume": "상", "area": "도형의 방정식", "slug": "점과직선사이거리",
        "title": "점과 직선 사이의 거리", "concept": "점 P(x₀,y₀)와 직선 ax+by+c=0 사이의 거리는 |ax₀+by₀+c|/√(a²+b²)입니다. 분자는 점을 직선식에 대입한 절댓값이고, 분모는 직선의 법선벡터 (a,b)의 길이입니다.",
        "example": "점 P(1,2)와 직선 3x+4y−10=0 사이의 거리를 구하세요.", "steps": ["점의 좌표를 직선식에 대입하면 3·1+4·2−10=1입니다.", "√(3²+4²)=5이므로 거리는 |1|/5입니다."], "answer": "1/5",
        "practice": "점 O(0,0)과 직선 3x+4y−20=0 사이의 거리를 구하세요.", "practice_steps": ["대입값은 −20이고 절댓값은 20입니다.", "법선벡터 길이는 √(9+16)=5입니다.", "거리는 20/5입니다."], "practice_answer": "4",
        "quiz": "점 (0,0)과 직선 5x−12y+13=0 사이의 거리는 얼마인가요?", "options": ["1", "13", "5"], "correct": 0, "feedback": "|13|/√(25+144)=13/13=1입니다.", "hint": "원점 대입값의 절댓값을 법선벡터 길이로 나누세요.",
    },
    {
        "code": "10수학03-02", "volume": "하", "area": "수와 연산", "slug": "집합포함관계",
        "title": "두 집합 사이의 포함 관계", "concept": "집합 A의 모든 원소가 집합 B에도 들어 있으면 A는 B의 부분집합이며 A⊂B 또는 A⊆B로 나타냅니다. A=B인지 판단하려면 A⊆B와 B⊆A가 모두 성립하는지 확인합니다.",
        "example": "A={1,2}, B={1,2,3}일 때 포함 관계를 설명하세요.", "steps": ["A의 원소 1과 2를 각각 확인합니다.", "두 원소가 모두 B에 있으므로 A⊆B입니다.", "3은 A에 없으므로 B⊆A는 성립하지 않습니다."], "answer": "A는 B의 진부분집합입니다.",
        "practice": "A={2,4}, B={1,2,3,4}일 때 참인 포함 관계를 쓰세요.", "practice_steps": ["A의 두 원소가 모두 B에 있습니다.", "B에는 A에 없는 원소 1,3도 있습니다."], "practice_answer": "A⊂B",
        "quiz": "A={a,b}, B={a,b}일 때 옳은 것은 무엇인가요?", "options": ["A=B이고 A⊆B이다", "A⊂B만 성립한다", "A와 B는 서로소이다"], "correct": 0, "feedback": "두 집합의 원소가 같으므로 서로 부분집합이며 같은 집합입니다.", "hint": "양쪽 집합의 원소를 각각 모두 확인하세요.",
    },
    {
        "code": "10수학03-05", "volume": "하", "area": "수와 연산", "slug": "명제의역과대우",
        "title": "명제의 역과 대우", "concept": "명제 p⇒q의 역은 q⇒p이고, 대우는 ¬q⇒¬p입니다. 명제와 대우는 참·거짓이 같지만, 원래 명제와 역은 일반적으로 참·거짓이 다를 수 있습니다.",
        "example": "‘n이 4의 배수이면 n은 짝수이다’의 역과 대우를 쓰세요.", "steps": ["p: n은 4의 배수, q: n은 짝수로 둡니다.", "역은 q⇒p이므로 ‘n이 짝수이면 4의 배수이다’입니다.", "대우는 ¬q⇒¬p이므로 ‘n이 짝수가 아니면 4의 배수가 아니다’입니다."], "answer": "역은 거짓일 수 있고(예: n=6), 대우는 참입니다.",
        "practice": "‘정수 n이 6의 배수이면 3의 배수이다’의 대우를 쓰세요.", "practice_steps": ["결론 ‘3의 배수이다’를 부정합니다.", "가정 ‘6의 배수이다’를 부정해 조건의 순서를 바꿉니다."], "practice_answer": "3의 배수가 아니면 6의 배수가 아니다.",
        "quiz": "p⇒q의 대우는 무엇인가요?", "options": ["¬q⇒¬p", "q⇒p", "¬p⇒¬q"], "correct": 0, "feedback": "대우는 결론과 가정을 모두 부정하고 순서를 바꿉니다.", "hint": "먼저 역을 만든 뒤 두 조건을 부정하세요.",
    },
    {
        "code": "10수학03-06", "volume": "하", "area": "수와 연산", "slug": "충분조건필요조건",
        "title": "충분조건과 필요조건", "concept": "p⇒q가 참이면 p는 q이기 위한 충분조건이고 q는 p이기 위한 필요조건입니다. p⇒q와 q⇒p가 모두 참이면 p와 q는 서로 필요충분조건입니다.",
        "example": "정수 n에 대하여 ‘n은 4의 배수’와 ‘n은 짝수’의 조건 관계를 판단하세요.", "steps": ["4의 배수인 정수는 모두 짝수이므로 p⇒q는 참입니다.", "짝수라고 해서 모두 4의 배수는 아니며 n=6이 반례입니다.", "따라서 p는 q의 충분조건이고 q는 p의 필요조건입니다."], "answer": "충분조건·필요조건 관계이며 필요충분조건은 아닙니다.",
        "practice": "자연수 n에 대해 p: n은 10의 배수, q: n은 5의 배수일 때 p와 q의 관계를 쓰세요.", "practice_steps": ["10의 배수는 모두 5의 배수입니다.", "5의 배수 중 15는 10의 배수가 아니므로 역은 거짓입니다."], "practice_answer": "p는 q의 충분조건이고 q는 p의 필요조건입니다.",
        "quiz": "p⇒q만 참일 때 옳은 설명은 무엇인가요?", "options": ["p는 q의 충분조건이다", "q는 p의 충분조건이다", "p와 q는 필요충분조건이다"], "correct": 0, "feedback": "p가 성립하면 q가 보장되므로 p는 q의 충분조건입니다.", "hint": "화살표의 출발 조건이 충분조건입니다.",
    },
    {
        "code": "10수학03-07", "volume": "하", "area": "수와 연산", "slug": "대우증명과귀류법",
        "title": "대우를 이용한 증명과 귀류법", "concept": "명제 p⇒q를 직접 증명하기 어려우면 대우 ¬q⇒¬p를 증명할 수 있습니다. 귀류법은 명제가 거짓이라고 가정해 모순을 이끌어 내어 원래 명제가 참임을 보이는 방법입니다.",
        "example": "정수 n에 대하여 n²이 짝수이면 n도 짝수임을 대우를 이용해 증명하세요.", "steps": ["대우는 n이 홀수이면 n²이 홀수라는 명제입니다.", "n=2k+1로 놓으면 n²=4k²+4k+1=2(2k²+2k)+1입니다.", "따라서 n²은 홀수이고 대우가 참이므로 원래 명제도 참입니다."], "answer": "n²이 짝수이면 n은 짝수입니다.",
        "practice": "‘정수 n의 제곱이 3의 배수이면 n은 3의 배수이다’를 대우로 증명하는 첫 단계를 쓰세요.", "practice_steps": ["대우는 n이 3의 배수가 아니면 n²도 3의 배수가 아니라는 명제입니다.", "n의 나머지가 1 또는 2일 때 제곱의 나머지가 1임을 확인하면 됩니다."], "practice_answer": "n을 3으로 나눈 나머지가 1 또는 2임을 두고 n²의 나머지가 1임을 보인다.",
        "quiz": "귀류법의 첫 단계로 알맞은 것은 무엇인가요?", "options": ["증명할 명제의 부정을 가정한다", "결론을 먼저 참이라고 둔다", "반례가 있어도 무시한다"], "correct": 0, "feedback": "귀류법은 결론이 거짓이라고 가정해 모순을 찾습니다.", "hint": "참임을 보일 명제의 반대 상황을 가정합니다.",
    },
    {
        "code": "10수학03-08", "volume": "하", "area": "수와 연산", "slug": "절대부등식",
        "title": "절대부등식의 뜻과 증명", "concept": "절대부등식은 변수가 허용되는 모든 실숫값에서 성립하는 부등식입니다. 제곱은 0 이상이라는 사실이나 (a−b)²≥0과 같은 기본 부등식을 이용해 증명할 수 있습니다.",
        "example": "모든 실수 x에 대해 x²+1≥2x임을 증명하세요.", "steps": ["왼쪽에서 오른쪽을 빼면 x²−2x+1입니다.", "x²−2x+1=(x−1)²이고 제곱은 항상 0 이상입니다."], "answer": "(x−1)²≥0이므로 x²+1≥2x입니다.",
        "practice": "모든 실수 x에 대해 x²+4≥4x임을 증명하세요.", "practice_steps": ["차를 정리하면 x²−4x+4입니다.", "x²−4x+4=(x−2)²≥0입니다."], "practice_answer": "x²+4−4x=(x−2)²≥0",
        "quiz": "x²+9≥6x가 모든 실수 x에서 성립함을 보이는 식은 무엇인가요?", "options": ["(x−3)²≥0", "(x+3)²≤0", "x²≥9"], "correct": 0, "feedback": "x²+9−6x=(x−3)²이고 제곱은 0 이상입니다.", "hint": "좌변에서 우변을 빼고 완전제곱식으로 만드세요.",
    },
    {
        "code": "10수학04-02", "volume": "하", "area": "함수", "slug": "함수의합성",
        "title": "함수의 합성과 합성함수", "concept": "함수 f와 g의 합성함수 f∘g는 먼저 g를 적용한 뒤 f를 적용합니다. 즉 (f∘g)(x)=f(g(x))입니다. 일반적으로 f∘g와 g∘f는 서로 같지 않습니다.",
        "example": "f(x)=x+1, g(x)=2x일 때 (f∘g)(x)와 (g∘f)(x)를 구하세요.", "steps": ["(f∘g)(x)=f(2x)=2x+1입니다.", "(g∘f)(x)=g(x+1)=2x+2입니다."], "answer": "f∘g=2x+1, g∘f=2x+2로 서로 다릅니다.",
        "practice": "f(x)=x², g(x)=x−3일 때 (f∘g)(x)를 구하세요.", "practice_steps": ["f의 입력 x를 g(x)=x−3으로 바꿉니다.", "f(g(x))=(x−3)²입니다."], "practice_answer": "(x−3)²",
        "quiz": "f(x)=3x, g(x)=x+2일 때 (f∘g)(x)는 무엇인가요?", "options": ["3x+6", "3x+2", "x+6"], "correct": 0, "feedback": "f(g(x))=3(x+2)=3x+6입니다.", "hint": "g(x)를 f의 입력 자리에 넣으세요.",
    },
    {
        "code": "10수학04-03", "volume": "하", "area": "함수", "slug": "역함수",
        "title": "역함수의 의미와 구하기", "concept": "함수 f가 일대일 대응이면 입력과 출력의 역할을 바꾸는 역함수 f⁻¹를 정의할 수 있습니다. y=f(x)에서 x와 y를 바꾸어 y를 x에 대한 식으로 풀고, 정의역과 치역도 서로 바뀌는지 확인합니다.",
        "example": "f(x)=2x+3의 역함수를 구하세요. 정의역과 치역은 실수 전체입니다.", "steps": ["y=2x+3에서 x와 y를 바꾸면 x=2y+3입니다.", "y에 대해 풀면 y=(x−3)/2입니다.", "실수 전체에서 일대일 대응이므로 역함수가 정의됩니다."], "answer": "f⁻¹(x)=(x−3)/2",
        "practice": "실수 전체에서 f(x)=3x−6의 역함수를 구하세요.", "practice_steps": ["y=3x−6에서 x와 y를 바꿔 x=3y−6으로 둡니다.", "y=(x+6)/3으로 풉니다."], "practice_answer": "f⁻¹(x)=(x+6)/3",
        "quiz": "f(x)=x−5의 역함수는 무엇인가요?", "options": ["x+5", "5−x", "x−5"], "correct": 0, "feedback": "y=x−5에서 x,y를 바꾸면 x=y−5이므로 y=x+5입니다.", "hint": "입력과 출력을 바꾸어 y에 대해 푸세요.",
    },
]


def validate_math() -> None:
    assert 3 * (1 - 2) + 4 == 3 * 1 - 2
    assert all(abs(x - 2) < 3 for x in [0, 2, 4])
    assert not any(abs(x - 2) < 3 for x in [-2, 6])
    assert all(abs(x + 1) >= 2 for x in [-4, -3, 1, 2])
    assert abs(3 * 1 + 4 * 2 - 10) / 5 == 0.2
    assert abs(-20) / 5 == 4
    assert abs(13) / 13 == 1
    a, b = {1, 2}, {1, 2, 3}
    assert a < b and not (b <= a)
    for p in (False, True):
        for q in (False, True):
            assert (not p or q) == (q or not p)
    assert all((not p or q) for p, q in [(True, True), (False, True)])
    assert not (not True or False)  # Converse fails when q is true and p is false.
    assert all((n * n) % 2 == 1 for n in range(1, 20, 2))
    assert all((x - 1) ** 2 >= 0 for x in (-3, 0, 1, 4))
    for n in range(1, 20):
        if n % 3:
            assert n * n % 3 == 1
    assert all((x - 2) ** 2 == x * x + 4 - 4 * x for x in (-4, 0, 2, 5))
    for x in (-3, 0, 2, 7):
        assert 3 * (x + 2) == 3 * x + 6
        assert ((3 * x - 6) + 6) / 3 == x
        assert 3 * ((x + 6) / 3) - 6 == x


def page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def make_book(unit: dict) -> dict:
    code = unit["code"]
    slug = unit["slug"]
    prefix = f"math15-{code.replace('-', '').lower()}-{slug}"
    quiz_id = f"{prefix}-quiz"
    tags = [f"수학({'상' if unit['volume'] == '상' else '하'})", "2015 개정", code, unit["area"], unit["title"], "신규 시범"]
    pages = [
        page(f"{prefix}-opening", "opening", unit["title"], [
            {"type": "lead", "title": "오늘의 질문", "text": unit["example"]},
            {"type": "thinking", "title": "먼저 생각하기", "text": "조건과 구하려는 것을 구분해 풀이 계획을 세워 보세요."},
            {"type": "answer", "title": "핵심 확인", "text": unit["answer"]},
        ]),
        page(f"{prefix}-concept", "concept", unit["title"], [
            {"type": "definition", "title": "개념", "text": unit["concept"]},
            {"type": "misconception", "title": "확인할 점", "text": "조건과 결론의 방향, 식의 정의역 또는 부호 조건을 확인한 뒤 결과를 원래 조건에 대입해 검산하세요."},
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
                "id": quiz_id, "kind": "quiz", "prompt": unit["quiz"], "options": unit["options"],
                "correct_index": unit["correct"], "correct_feedback": unit["feedback"],
                "incorrect_feedback": unit["hint"], "hints": [unit["hint"]],
            }},
        ]),
    ]
    chapter = {"title": unit["title"], "standard_codes": [code], "tags": tags, "pages": pages}
    return {
        "title": f"수학({unit['volume']}) 2015 개정 · {unit['title']} 후보",
        "subtitle": "성취기준 연결 재개형 부분 원고",
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


def main() -> None:
    validate_math()
    generated = 0
    for unit in UNITS:
        folder = f"수학{'상' if unit['volume'] == '상' else '하'}_2015개정_초안"
        output_dir = MANUSCRIPTS / folder
        output_dir.mkdir(parents=True, exist_ok=True)
        filename = f"수학{'상' if unit['volume'] == '상' else '하'}_2015개정_{unit['slug']}_V2_BookData_초안.json"
        target = output_dir / filename
        book = make_book(unit)
        serialized = json.dumps(book, ensure_ascii=False, indent=2) + "\n"
        if not target.exists() or target.read_text(encoding="utf-8") != serialized:
            target.write_text(serialized, encoding="utf-8")
        verified = json.loads(target.read_text(encoding="utf-8"))
        pages = verified["chapters"][0]["pages"]
        if len(pages) != 4 or len({p["id"] for p in pages}) != 4:
            raise RuntimeError(f"Invalid page structure or duplicate IDs: {unit['code']}")
        if verified["standard_codes"] != [unit["code"]] or verified["chapters"][0]["standard_codes"] != [unit["code"]]:
            raise RuntimeError(f"Standard code mismatch: {unit['code']}")
        practice = pages[-1]
        activity = next(b["activity"] for b in practice["blocks"] if b.get("type") == "activity")
        if activity["kind"] != "quiz" or not 0 <= activity["correct_index"] < len(activity["options"]):
            raise RuntimeError(f"Invalid quiz payload: {unit['code']}")
        readme = output_dir / "README.md"
        text = readme.read_text(encoding="utf-8")
        marker = f"[{filename}]"
        if marker not in text:
            text = text.rstrip() + f"\n\n## {unit['title']} · V2\n\n- [{filename}]({filename}): 도입·개념·예제·연습+quiz 4쪽, `{unit['code']}` 연결 후보\n- 교사·독립 수학 검토과 권리 확인 전이며 출판 부적격입니다.\n"
            readme.write_text(text, encoding="utf-8")
        generated += 1
    print(f"Generated/resumed {generated} 2015 Math criterion drafts ({len(UNITS)} standards; four pages plus native quiz each).")


if __name__ == "__main__":
    main()
