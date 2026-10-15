"""Create a focused 2015 Math (Lower) counting principles subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학하_2015개정_초안"
TAGS = ["수학(하)", "2015 개정", "확률과 통계", "경우의 수", "합의 법칙", "곱의 법칙", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-lower-counting-opening", "template": "opening", "title": "가능한 선택은 모두 몇 가지일까?", "kicker": "합의 법칙과 곱의 법칙", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "셔츠 3벌 중 하나와 바지 2벌 중 하나를 고르면 옷차림은 몇 가지일까요?"},
            {"type": "thinking", "title": "선택을 나누어 세기", "text": "셔츠를 하나 고를 때마다 바지 선택이 몇 가지씩 가능한지 표로 세어 보세요."},
            {"type": "answer", "title": "확인", "text": "셔츠 3가지 각각에 바지 2가지가 가능하므로 3×2=6가지입니다."},
        ]},
        {"id": "math-lower-counting-concept", "template": "concept", "title": "이어 하는 선택은 곱하고, 겹치지 않는 갈래는 더한다", "kicker": "선택 구조부터 확인", "blocks": [
            {"type": "definition", "title": "곱의 법칙", "text": "첫 번째 선택이 m가지이고, 각 경우마다 이어지는 두 번째 선택이 n가지이면 두 선택을 함께 하는 방법은 m×n가지입니다."},
            {"type": "solutionStep", "title": "합의 법칙", "items": ["서로 겹치지 않는 갈래 A를 고르는 방법이 m가지입니다.", "갈래 B를 고르는 방법이 n가지라면, A 또는 B를 고르는 방법은 m+n가지입니다.", "갈래가 겹치는 선택을 단순히 더하면 중복해서 세므로 갈래가 겹치지 않는지 확인합니다."]},
            {"type": "misconception", "title": "곱인지 합인지 먼저 판단", "text": "‘A를 하고 이어서 B’이면 곱의 법칙, ‘A 또는 B 중 하나’이고 두 갈래가 겹치지 않으면 합의 법칙을 사용합니다."},
        ]},
        {"id": "math-lower-counting-example", "template": "example", "title": "두 단계 선택 세기", "kicker": "각 단계의 선택 수를 곱한다", "blocks": [
            {"type": "question", "title": "예제", "text": "문자 A, B, C 중 하나와 숫자 1, 2 중 하나를 차례로 골라 두 글자 표지를 만든다. 표지는 몇 가지일까요?"},
            {"type": "solutionStep", "title": "풀이", "items": ["첫 글자 선택은 3가지입니다.", "각 첫 글자에 숫자 선택 2가지가 이어집니다.", "따라서 3×2=6가지입니다."]},
            {"type": "answer", "title": "답", "text": "6가지"},
        ]},
        {"id": "math-lower-counting-practice", "template": "practice", "title": "합의 법칙과 곱의 법칙 연습", "kicker": "선택이 이어지는지 갈라지는지 보기", "blocks": [
            {"type": "question", "title": "문제", "text": "간식 A 4종 중 하나 또는 음료 B 3종 중 하나를 고른다. 간식과 음료 종류는 서로 다르다. 고르는 방법은 몇 가지일까요?"},
            {"type": "thinking", "title": "생각 순서", "text": "두 종류를 함께 고르는 것이 아니라 둘 중 하나를 고르며, 선택 갈래가 겹치는지 확인하세요."},
            {"type": "answer", "title": "정답", "text": "서로 겹치지 않는 갈래이므로 합의 법칙을 써서 4+3=7가지입니다."},
            {"type": "checklist", "title": "마무리", "items": ["선택 단계가 이어지는 상황인지 확인했나요?", "더할 때 갈래가 서로 겹치지 않는지 확인했나요?"]},
        ]},
    ]
    book = {"title": "수학(하) 2015 개정 · 경우의 수 기본 원리 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "합의 법칙과 곱의 법칙", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학하_2015개정_경우의수기본원리_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 경우의 수 기본 원리\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
