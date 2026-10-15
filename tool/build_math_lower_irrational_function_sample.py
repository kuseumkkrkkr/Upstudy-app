"""Create a focused 2015 Math (Lower) irrational function subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학하_2015개정_초안"
TAGS = ["수학(하)", "2015 개정", "함수", "무리함수", "정의역", "그래프의 이동", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-lower-irrational-function-opening", "template": "opening", "title": "제곱근이 함수의 값이 될 수 있을까?", "kicker": "무리함수", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "y=√x에서 x가 0, 1, 4일 때 y의 값은 무엇일까요?"},
            {"type": "thinking", "title": "제곱해서 확인", "text": "각 x에 대해 제곱하면 x가 되는 음이 아닌 수를 찾아보세요."},
            {"type": "answer", "title": "확인", "text": "y는 0, 1, 2입니다. 실수 범위에서 제곱근 기호 √x는 음이 아닌 값을 나타냅니다."},
        ]},
        {"id": "math-lower-irrational-function-concept", "template": "concept", "title": "근호 안이 음수가 되지 않도록 정의역을 정한다", "kicker": "정의역 조건과 그래프 이동", "blocks": [
            {"type": "definition", "title": "무리함수의 기본 꼴", "text": "무리함수는 변수에 대한 식이 근호 안에 포함된 함수입니다. 실수 범위에서 제곱근을 다룰 때는 근호 안의 식이 0 이상이어야 합니다."},
            {"type": "solutionStep", "title": "y=√(x−a)+b 살펴보기", "items": ["정의역은 x−a≥0을 풀어 구합니다.", "y=√x의 그래프를 x축 방향으로 a만큼, y축 방향으로 b만큼 평행이동한 그래프입니다.", "제곱근 값이 0 이상이므로 치역은 y≥b입니다."]},
            {"type": "misconception", "title": "정의역부터 구하기", "text": "그래프를 그리기 전에 근호 안의 식이 0 이상인지 확인합니다. 근호 바깥의 이동은 정의역 조건을 바꾸지 않습니다."},
        ]},
        {"id": "math-lower-irrational-function-example", "template": "example", "title": "평행이동한 그래프의 정의역과 치역", "kicker": "y=√(x−1)+2", "blocks": [
            {"type": "question", "title": "예제", "text": "y=√(x−1)+2의 정의역과 치역을 구하고 그래프의 시작점을 말하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["x−1≥0이므로 x≥1입니다.", "√(x−1)≥0이므로 y≥2입니다.", "y=√x의 그래프를 오른쪽으로 1, 위로 2만큼 옮기므로 시작점은 (1,2)입니다."]},
            {"type": "answer", "title": "답", "text": "정의역은 x≥1, 치역은 y≥2이며 시작점은 (1,2)입니다."},
        ]},
        {"id": "math-lower-irrational-function-practice", "template": "practice", "title": "대칭과 정의역 연습", "kicker": "근호 조건과 부호 확인", "blocks": [
            {"type": "question", "title": "문제", "text": "y=−√(x+2)+1의 정의역과 치역을 구하고 그래프의 시작점을 말하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "x+2≥0으로 정의역을 구하세요. 앞의 음수는 그래프를 x축에 대하여 대칭시킵니다."},
            {"type": "answer", "title": "정답", "text": "정의역은 x≥−2, 치역은 y≤1이며 시작점은 (−2,1)입니다."},
            {"type": "checklist", "title": "마무리", "items": ["근호 안을 0 이상으로 두었나요?", "앞의 음수로 치역의 방향을 바꾸었나요?"]},
        ]},
    ]
    book = {"title": "수학(하) 2015 개정 · 무리함수 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "무리함수의 정의역과 그래프", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학하_2015개정_무리함수_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 무리함수\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
