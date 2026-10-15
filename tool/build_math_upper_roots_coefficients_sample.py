"""Create a focused 2015 Math (Upper) roots/coefficients subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "이차방정식", "근과 계수의 관계", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-roots-coefficients-opening", "template": "opening", "title": "근을 구하지 않고 합과 곱을 알 수 있을까?", "kicker": "근과 계수의 관계", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "x²−5x+6=0의 두 근을 구하지 않고 근의 합과 곱을 짐작할 수 있을까요?"},
            {"type": "thinking", "title": "인수분해와 비교", "text": "x²−5x+6=(x−2)(x−3)으로 나타내고, 두 근 2와 3의 합·곱을 계수와 비교해 보세요."},
            {"type": "answer", "title": "확인", "text": "근의 합은 5, 곱은 6입니다. 이차항의 계수와 일차항·상수항의 계수 사이에 관계가 있습니다."},
        ]},
        {"id": "math-upper-roots-coefficients-concept", "template": "concept", "title": "두 근의 합은 −b/a, 곱은 c/a", "kicker": "ax²+bx+c=0", "blocks": [
            {"type": "definition", "title": "근과 계수의 관계", "text": "이차방정식 ax²+bx+c=0 (a≠0)의 두 근을 α, β라 하면 α+β=−b/a, αβ=c/a입니다."},
            {"type": "solutionStep", "title": "계수와 부호 확인", "items": ["일차항 계수 b의 부호를 바꾸고 이차항 계수 a로 나누면 근의 합입니다.", "상수항 c를 이차항 계수 a로 나누면 근의 곱입니다.", "계수가 1인 x²+px+q=0에서는 합은 −p, 곱은 q입니다."]},
            {"type": "misconception", "title": "일차항의 부호 바꾸기", "text": "근의 합은 b/a가 아니라 −b/a입니다. 표준형에서 각 계수의 부호를 먼저 확인하세요."},
        ]},
        {"id": "math-upper-roots-coefficients-example", "template": "example", "title": "근의 합과 곱 구하기", "kicker": "계수에 관계식 적용", "blocks": [
            {"type": "question", "title": "예제", "text": "2x²−6x+4=0의 두 근의 합과 곱을 구하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["a=2, b=−6, c=4입니다.", "근의 합은 −b/a=−(−6)/2=3입니다.", "근의 곱은 c/a=4/2=2입니다."]},
            {"type": "answer", "title": "답", "text": "합 3, 곱 2"},
        ]},
        {"id": "math-upper-roots-coefficients-practice", "template": "practice", "title": "근으로 이차방정식 만들기", "kicker": "두 근의 합과 곱을 계수에 연결", "blocks": [
            {"type": "question", "title": "문제", "text": "두 근이 3과 −2인 계수가 정수인 이차방정식 하나를 만드세요."},
            {"type": "thinking", "title": "생각 순서", "text": "두 근의 합과 곱을 구한 뒤 x²−(근의 합)x+(근의 곱)=0 꼴을 사용하세요."},
            {"type": "answer", "title": "정답", "text": "x²−x−6=0입니다. (x−3)(x+2)=0으로 확인할 수 있습니다."},
            {"type": "checklist", "title": "마무리", "items": ["근의 합을 일차항 계수의 반대 부호로 넣었나요?", "근의 곱을 상수항으로 넣었나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 근과 계수의 관계 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "이차방정식의 근과 계수의 관계", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_근과계수의관계_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 근과 계수의 관계\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
