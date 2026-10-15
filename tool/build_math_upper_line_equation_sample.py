"""Create a focused 2015 Math (Upper) line slope/equation subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "도형의 방정식", "직선의 방정식", "기울기", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-line-equation-opening", "template": "opening", "title": "두 점을 이은 직선의 기울기는?", "kicker": "기울기와 직선의 방정식", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "A(1,2), B(3,6)을 지나는 직선에서 x가 1만큼 늘 때 y는 얼마나 변할까요?"},
            {"type": "thinking", "title": "좌표 변화 비교", "text": "x좌표 변화량과 y좌표 변화량을 각각 계산하고, 세로 변화량을 가로 변화량으로 나누어 보세요."},
            {"type": "answer", "title": "확인", "text": "x 변화량은 2, y 변화량은 4이므로 기울기는 4/2=2입니다."},
        ]},
        {"id": "math-upper-line-equation-concept", "template": "concept", "title": "기울기는 y 변화량을 x 변화량으로 나눈 값", "kicker": "한 점과 기울기로 직선 정하기", "blocks": [
            {"type": "definition", "title": "기울기와 점기울기식", "text": "두 점 (x₁,y₁), (x₂,y₂)에서 x₁≠x₂이면 기울기는 (y₂−y₁)/(x₂−x₁)입니다. 기울기가 m이고 (x₁,y₁)을 지나는 직선은 y−y₁=m(x−x₁)입니다."},
            {"type": "solutionStep", "title": "식 세우기", "items": ["먼저 두 점의 기울기를 계산하거나 주어진 기울기를 확인합니다.", "직선 위의 한 점 (x₁,y₁)을 점기울기식에 넣습니다.", "필요하면 y=mx+n 꼴로 정리합니다."]},
            {"type": "misconception", "title": "수직선은 기울기 공식으로 나누지 않기", "text": "x좌표가 같은 두 점을 지나는 직선은 수직선 x=x₁입니다. 분모가 0이므로 기울기는 정의되지 않습니다."},
        ]},
        {"id": "math-upper-line-equation-example", "template": "example", "title": "두 점을 지나는 직선식 구하기", "kicker": "A(1,2), B(3,6)", "blocks": [
            {"type": "question", "title": "예제", "text": "A(1,2), B(3,6)을 지나는 직선의 방정식을 구하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["기울기는 (6−2)/(3−1)=2입니다.", "점 (1,2)를 사용하면 y−2=2(x−1)입니다.", "정리하면 y=2x입니다."]},
            {"type": "answer", "title": "답", "text": "y=2x"},
        ]},
        {"id": "math-upper-line-equation-practice", "template": "practice", "title": "기울기와 한 점으로 직선 구하기", "kicker": "점기울기식 적용", "blocks": [
            {"type": "question", "title": "문제", "text": "기울기가 3이고 점 (1,−2)를 지나는 직선의 방정식을 구하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "y−y₁=m(x−x₁)에 m=3, (x₁,y₁)=(1,−2)를 대입하세요."},
            {"type": "answer", "title": "정답", "text": "y+2=3(x−1), 즉 y=3x−5입니다."},
            {"type": "checklist", "title": "마무리", "items": ["기울기를 y 변화량/x 변화량으로 계산했나요?", "점의 좌표 부호를 식에 바르게 대입했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 직선의 방정식 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "기울기와 직선의 방정식", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_직선의방정식_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 직선의 방정식\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
