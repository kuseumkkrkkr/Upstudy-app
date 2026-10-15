"""Create a focused 2015 Math (Upper) quadratic inequality subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "이차부등식", "이차함수", "부호와 그래프", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-quadratic-inequality-opening", "template": "opening", "title": "포물선이 x축 위에 있는 구간은?", "kicker": "이차부등식", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "x²−4x+3>0을 만족하는 x는 어느 구간에 있을까요?"},
            {"type": "thinking", "title": "그래프와 x축 비교", "text": "y=x²−4x+3의 x절편을 찾고, 포물선이 x축보다 위에 있는 구간을 살펴보세요."},
            {"type": "answer", "title": "확인", "text": "근은 1과 3이고 포물선은 위로 열립니다. 그래프가 x축 위에 있는 구간은 x<1 또는 x>3입니다."},
        ]},
        {"id": "math-upper-quadratic-inequality-concept", "template": "concept", "title": "근 사이에서 이차식의 부호를 판단", "kicker": "인수분해·그래프·부등호", "blocks": [
            {"type": "definition", "title": "이차부등식", "text": "이차식의 값이 0보다 크거나 작은 x의 범위를 찾는 부등식입니다. 등호가 포함되면 이차식의 값이 0인 경계도 해에 포함할 수 있습니다."},
            {"type": "solutionStep", "title": "해를 구하는 순서", "items": ["이차식을 인수분해하거나 이차방정식의 근을 구합니다.", "근으로 수직선을 나누고 각 구간에서 이차식의 부호를 확인합니다.", "부등호가 > 또는 <이면 근을 제외하고, ≥ 또는 ≤이면 근을 포함합니다."]},
            {"type": "misconception", "title": "등호 포함 여부 확인", "text": "부등호에 등호가 있으면 이차식이 0이 되는 근을 포함합니다. 열린 구간과 닫힌 구간을 구별하세요."},
        ]},
        {"id": "math-upper-quadratic-inequality-example", "template": "example", "title": "두 근 사이 구간 찾기", "kicker": "(x−2)(x+1)≤0", "blocks": [
            {"type": "question", "title": "예제", "text": "(x−2)(x+1)≤0을 푸세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["근은 −1과 2입니다.", "두 일차식의 부호를 구간별로 확인하면 두 근 사이에서 곱이 0 이하입니다.", "부등호에 등호가 있으므로 두 근도 포함합니다."]},
            {"type": "answer", "title": "답", "text": "−1≤x≤2"},
        ]},
        {"id": "math-upper-quadratic-inequality-practice", "template": "practice", "title": "이차부등식 해 구간 연습", "kicker": "최고차항 계수와 부호표 확인", "blocks": [
            {"type": "question", "title": "문제", "text": "−x²+x+6≥0을 푸세요."},
            {"type": "thinking", "title": "생각 순서", "text": "먼저 −(x−3)(x+2)로 인수분해하고 근과 각 구간의 부호를 확인하세요."},
            {"type": "answer", "title": "정답", "text": "근은 −2와 3이고, 식은 두 근 사이에서 0 이상이므로 −2≤x≤3입니다."},
            {"type": "checklist", "title": "마무리", "items": ["이차식을 올바르게 인수분해했나요?", "부등호에 등호가 있어 근을 포함했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 이차부등식 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "이차부등식의 해", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_이차부등식_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 이차부등식\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
