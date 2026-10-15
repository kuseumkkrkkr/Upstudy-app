"""Create a focused 2015 Math (Lower) complement and difference subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/수학하_2015개정_초안"
TAGS = ["수학(하)", "2015 개정", "수와 연산", "집합", "여집합", "차집합", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {
            "id": "math-lower-set-complement-difference-opening",
            "template": "opening",
            "title": "기준이 달라지면 빠진 원소도 달라질까?",
            "kicker": "여집합과 차집합",
            "blocks": [
                {"type": "lead", "title": "오늘의 질문", "text": "U={1,2,3,4,5}, A={1,2,4}일 때 A에 속하지 않는 U의 원소는 무엇일까요?"},
                {"type": "thinking", "title": "먼저 표시하기", "text": "전체집합 U의 원소를 모두 적고, A에 속한 원소와 속하지 않은 원소를 다른 표시로 나눠 보세요."},
                {"type": "answer", "title": "확인", "text": "U에는 있지만 A에는 없는 원소는 3,5입니다. 이 집합은 U를 기준으로 한 A의 여집합입니다."},
            ],
        },
        {
            "id": "math-lower-set-complement-difference-concept",
            "template": "concept",
            "title": "여집합은 전체집합을 기준으로, 차집합은 한 집합을 기준으로",
            "kicker": "기준 집합을 먼저 확인하기",
            "blocks": [
                {"type": "definition", "title": "여집합과 차집합", "text": "A의 여집합 Aᶜ은 전체집합 U에 속하면서 A에는 속하지 않는 원소의 집합입니다. A\u2216B는 A에는 속하고 B에는 속하지 않는 원소의 집합입니다."},
                {"type": "solutionStep", "title": "원소로 구분", "items": ["U={1,2,3,4,5}, A={1,2,4}, B={2,3}으로 둡니다.", "U에서 A의 원소를 제외하면 Aᶜ={3,5}입니다.", "A에서 B에도 속한 2를 제외하면 A\u2216B={1,4}입니다."]},
                {"type": "misconception", "title": "여집합에는 전체집합이 필요", "text": "A의 여집합은 U가 정해져야 하나로 결정됩니다. 차집합 A\u2216B와 B\u2216A는 기준이 되는 첫 집합이 달라 일반적으로 서로 다릅니다."},
            ],
        },
        {
            "id": "math-lower-set-complement-difference-example",
            "template": "example",
            "title": "여집합과 차집합 계산하기",
            "kicker": "원소가 속하는 조건 확인",
            "blocks": [
                {"type": "question", "title": "예제", "text": "U={a,b,c,d,e}, X={a,c,e}, Y={c,d}일 때 Xᶜ, X\u2216Y, Y\u2216X를 구하세요."},
                {"type": "solutionStep", "title": "풀이", "items": ["U에서 X의 원소 a,c,e를 빼면 Xᶜ={b,d}입니다.", "X에는 있고 Y에는 없는 원소는 a,e입니다.", "Y에는 있고 X에는 없는 원소는 d입니다."]},
                {"type": "answer", "title": "답", "text": "Xᶜ={b,d}, X\u2216Y={a,e}, Y\u2216X={d}"},
            ],
        },
        {
            "id": "math-lower-set-complement-difference-practice",
            "template": "practice",
            "title": "여집합과 차집합 연습",
            "kicker": "기준을 바꾸지 않고 끝까지 계산하기",
            "blocks": [
                {"type": "question", "title": "문제", "text": "U={1,2,3,4,5,6}, P={1,3,5}, Q={3,4,5}일 때 Pᶜ, P\u2216Q, Q\u2216P를 구하세요."},
                {"type": "thinking", "title": "생각 순서", "text": "여집합은 U에서 시작하고, 차집합은 기호 왼쪽 집합에서 시작해 오른쪽 집합의 원소를 제외하세요."},
                {"type": "answer", "title": "정답", "text": "Pᶜ={2,4,6}, P\u2216Q={1}, Q\u2216P={4}"},
                {"type": "checklist", "title": "마무리", "items": ["여집합을 구할 때 전체집합 U를 기준으로 삼았나요?", "차집합의 순서 P\u2216Q와 Q\u2216P를 구분했나요?"]},
            ],
        },
    ]
    book = {
        "title": "수학(하) 2015 개정 · 여집합과 차집합 시범",
        "subtitle": "태그 기반 신규 소단원 초안",
        "category": "concept_textbook",
        "tags": TAGS,
        "chapters": [{"title": "여집합과 차집합", "pages": pages}],
        "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"},
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학하_2015개정_여집합과차집합_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 여집합과 차집합\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 공식 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
