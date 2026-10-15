"""Create a focused 2015 Math (Upper) simultaneous linear inequalities draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "여러 가지 부등식", "연립일차부등식", "수직선", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-compound-linear-inequalities-opening", "template": "opening", "title": "두 조건을 동시에 만족하는 구간은?", "kicker": "연립일차부등식", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "x>2와 x≤3을 동시에 만족하는 수는 어떤 구간에 있을까요?"},
            {"type": "thinking", "title": "수직선에 표시", "text": "첫 부등식의 해를 열린 점으로, 둘째 부등식의 해를 닫힌 점으로 표시하고 겹치는 부분을 찾으세요."},
            {"type": "answer", "title": "확인", "text": "두 조건을 모두 만족하는 구간은 2<x≤3입니다."},
        ]},
        {"id": "math-upper-compound-linear-inequalities-concept", "template": "concept", "title": "연립부등식은 각 해의 공통부분", "kicker": "부등식별 해집합의 교집합", "blocks": [
            {"type": "definition", "title": "연립일차부등식", "text": "두 개 이상의 일차부등식을 동시에 만족하는 x의 범위를 구합니다. 각 부등식의 해집합을 구한 뒤 공통부분을 찾습니다."},
            {"type": "solutionStep", "title": "풀이 순서", "items": ["각 부등식을 따로 풀어 해의 범위를 구합니다.", "수직선에 각 범위의 끝점과 포함 여부를 표시합니다.", "모든 범위가 겹치는 구간만 답으로 정리합니다."]},
            {"type": "misconception", "title": "끝점의 포함 여부", "text": "<, >는 끝점을 포함하지 않고 ≤, ≥는 포함합니다. 교집합의 양 끝점도 각각의 부등식에서 포함되는지 확인하세요."},
        ]},
        {"id": "math-upper-compound-linear-inequalities-example", "template": "example", "title": "두 부등식의 공통 해 구하기", "kicker": "2x−1>3, 3x+1≤10", "blocks": [
            {"type": "question", "title": "예제", "text": "연립부등식 2x−1>3, 3x+1≤10을 푸세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["2x−1>3에서 x>2입니다.", "3x+1≤10에서 x≤3입니다.", "두 해의 공통부분은 2<x≤3입니다."]},
            {"type": "answer", "title": "답", "text": "2<x≤3"},
        ]},
        {"id": "math-upper-compound-linear-inequalities-practice", "template": "practice", "title": "연립일차부등식의 해 연습", "kicker": "끝점 포함을 확인", "blocks": [
            {"type": "question", "title": "문제", "text": "연립부등식 x+4≥1, 2x−2<6을 푸세요."},
            {"type": "thinking", "title": "생각 순서", "text": "각 부등식을 풀고 수직선에서 겹치는 구간을 구하세요."},
            {"type": "answer", "title": "정답", "text": "첫째 부등식에서 x≥−3, 둘째에서 x<4이므로 −3≤x<4입니다."},
            {"type": "checklist", "title": "마무리", "items": ["각 부등식을 따로 풀었나요?", "왼쪽 끝점은 포함하고 오른쪽 끝점은 제외했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 연립일차부등식 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "연립일차부등식과 공통 해", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_연립일차부등식_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 연립일차부등식\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
