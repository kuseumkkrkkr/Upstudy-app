"""Create a focused 2015 Math (Lower) function concept subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학하_2015개정_초안"
TAGS = ["수학(하)", "2015 개정", "함수", "함수의 뜻", "정의역", "치역", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-lower-function-opening", "template": "opening", "title": "입력 하나에 출력은 몇 개일까?", "kicker": "함수의 뜻", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "학생 한 명을 그 학생의 사물함 번호에 대응시키면 함수라고 할 수 있을까요?"},
            {"type": "thinking", "title": "대응을 살펴보기", "text": "각 학생에게 연결되는 번호가 정확히 하나인지 확인해 보세요. 여러 학생이 같은 번호로 이어지는 것은 따로 점검할 문제입니다."},
            {"type": "answer", "title": "확인", "text": "집합 X의 각 원소에 집합 Y의 원소가 오직 하나씩 대응하면 X에서 Y로의 함수입니다."},
        ]},
        {"id": "math-lower-function-concept", "template": "concept", "title": "함수는 정의역의 각 원소에 값을 하나씩 대응", "kicker": "정의역·공역·치역", "blocks": [
            {"type": "definition", "title": "함수와 세 집합", "text": "X의 각 원소에 Y의 원소가 하나씩 대응할 때 X에서 Y로의 함수라고 합니다. X는 정의역, Y는 공역이며 실제 대응된 Y의 원소 전체는 치역입니다."},
            {"type": "solutionStep", "title": "대응을 확인하는 기준", "items": ["정의역의 모든 원소가 대응되어야 합니다.", "정의역의 한 원소에서 화살표가 둘 이상 나가면 함수가 아닙니다.", "서로 다른 정의역 원소가 같은 값에 대응해도 함수일 수 있습니다."]},
            {"type": "misconception", "title": "공역과 치역은 다를 수 있다", "text": "공역은 대응 대상으로 정한 집합 전체이고, 치역은 실제로 대응된 값만 모은 집합입니다. 치역은 공역의 부분집합입니다."},
        ]},
        {"id": "math-lower-function-example", "template": "example", "title": "정의역과 치역 읽기", "kicker": "대응 규칙으로 값 구하기", "blocks": [
            {"type": "question", "title": "예제", "text": "X={1,2,3}, Y={a,b,c}에서 1→a, 2→a, 3→b로 대응한다. 함수인지 판단하고 정의역과 치역을 쓰세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["X의 각 원소 1,2,3이 각각 한 값에 대응합니다.", "따라서 X에서 Y로의 함수입니다.", "실제로 사용된 값은 a,b입니다."]},
            {"type": "answer", "title": "답", "text": "함수이며, 정의역은 {1,2,3}, 공역은 {a,b,c}, 치역은 {a,b}입니다."},
        ]},
        {"id": "math-lower-function-practice", "template": "practice", "title": "함수인지 판단하기", "kicker": "정의역의 모든 원소가 하나씩 대응하는지 확인", "blocks": [
            {"type": "question", "title": "문제", "text": "X={1,2,3}에서 1→p, 2→q, 2→r로 대응하고 3은 대응하지 않는다. X에서 어떤 집합으로 가는 함수인지 판단하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "정의역의 모든 원소가 대응하는지, 한 원소에서 두 값으로 나가지는 않는지 확인하세요."},
            {"type": "answer", "title": "정답", "text": "함수가 아닙니다. 2가 두 값에 대응하고 3은 대응하지 않습니다."},
            {"type": "checklist", "title": "마무리", "items": ["정의역의 모든 원소를 확인했나요?", "각 원소에서 값이 정확히 하나씩 대응하는지 살폈나요?"]},
        ]},
    ]
    book = {"title": "수학(하) 2015 개정 · 함수의 뜻 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "함수의 뜻과 대응", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학하_2015개정_함수의뜻_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 함수의 뜻\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
