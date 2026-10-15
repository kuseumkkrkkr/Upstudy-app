"""Create a focused 2015 Math (Upper) factorization subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "다항식", "인수분해", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-factorization-opening", "template": "opening", "title": "곱으로 나타내면 무엇이 보일까?", "kicker": "다항식의 인수분해", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "x²−9를 두 다항식의 곱으로 나타낼 수 있을까요?"},
            {"type": "thinking", "title": "곱셈 공식 거꾸로 보기", "text": "x²−9를 x²−3²로 보고, (a+b)(a−b)=a²−b²를 거꾸로 적용해 보세요."},
            {"type": "answer", "title": "확인", "text": "x²−9=(x+3)(x−3)입니다. 다항식을 인수의 곱으로 나타내는 것을 인수분해라고 합니다."},
        ]},
        {"id": "math-upper-factorization-concept", "template": "concept", "title": "전개와 인수분해는 서로 반대 방향", "kicker": "공통인수와 곱셈 공식 활용", "blocks": [
            {"type": "definition", "title": "인수분해", "text": "다항식을 두 개 이상의 다항식의 곱으로 나타내는 것을 인수분해라고 합니다. 전개 결과를 곱의 꼴로 되돌리는 과정입니다."},
            {"type": "solutionStep", "title": "먼저 살펴볼 것", "items": ["모든 항에 공통인수가 있으면 먼저 묶습니다.", "항이 두 개면 제곱의 차 a²−b²=(a+b)(a−b)인지 살펴봅니다.", "세 항이면 완전제곱식이나 이차식의 곱으로 나타나는지 확인합니다."]},
            {"type": "misconception", "title": "전개로 확인하기", "text": "곱으로 묶은 뒤 다시 전개했을 때 처음 다항식이 나오는지 확인합니다. 부호와 상수항을 특히 살펴보세요."},
        ]},
        {"id": "math-upper-factorization-example", "template": "example", "title": "곱셈 공식의 역으로 묶기", "kicker": "두 수의 합과 곱 확인", "blocks": [
            {"type": "question", "title": "예제", "text": "x²+5x+6을 인수분해하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["곱이 6이고 합이 5인 두 수는 2와 3입니다.", "따라서 x²+5x+6=(x+2)(x+3)입니다.", "전개하면 x²+5x+6이 되어 식이 확인됩니다."]},
            {"type": "answer", "title": "답", "text": "(x+2)(x+3)"},
        ]},
        {"id": "math-upper-factorization-practice", "template": "practice", "title": "인수분해 연습", "kicker": "곱과 합으로 두 수 찾기", "blocks": [
            {"type": "question", "title": "문제", "text": "x²−5x+6을 인수분해하고 전개하여 확인하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "곱이 6이고 합이 −5인 두 수를 찾으세요."},
            {"type": "answer", "title": "정답", "text": "x²−5x+6=(x−2)(x−3)"},
            {"type": "checklist", "title": "마무리", "items": ["두 수의 곱이 6인가요?", "두 수의 합이 −5인가요?", "전개 결과가 처음 식과 같은가요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 인수분해 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "다항식의 인수분해", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_인수분해_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 인수분해\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
