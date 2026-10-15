"""Create a focused 2015 Math (Upper) line/circle intersection subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "도형의 방정식", "직선의 방정식", "원의 방정식", "교점", "접선", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-line-circle-opening", "template": "opening", "title": "직선과 원은 몇 점에서 만날까?", "kicker": "직선과 원의 위치 관계", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "원 x²+y²=25와 직선 y=3은 몇 점에서 만날까요?"},
            {"type": "thinking", "title": "직선식을 원에 대입", "text": "y=3을 원의 방정식에 넣어 x에 대한 방정식의 실근 개수를 확인해 보세요."},
            {"type": "answer", "title": "확인", "text": "x²+9=25에서 x=±4입니다. 두 점 (4,3), (−4,3)에서 만납니다."},
        ]},
        {"id": "math-upper-line-circle-concept", "template": "concept", "title": "교점의 개수는 대입한 이차방정식의 실근 개수", "kicker": "판별식으로 secant·tangent 판단", "blocks": [
            {"type": "definition", "title": "직선과 원의 위치 관계", "text": "직선의 방정식을 원의 방정식에 대입해 얻은 이차방정식이 서로 다른 두 실근을 가지면 두 점에서 만나고, 중근이면 접하며, 실근이 없으면 만나지 않습니다."},
            {"type": "solutionStep", "title": "판별식으로 판단", "items": ["직선식을 원의 방정식에 대입해 하나의 변수에 대한 이차방정식을 만듭니다.", "판별식 D>0이면 두 점에서 만납니다.", "D=0이면 접하고, D<0이면 만나지 않습니다."]},
            {"type": "misconception", "title": "중근은 한 교점", "text": "중근은 대수적으로 같은 근이 두 번 나타난 것이며, 원과 직선의 교점은 한 점입니다. 이때 직선은 원의 접선입니다."},
        ]},
        {"id": "math-upper-line-circle-example", "template": "example", "title": "중근으로 접선 확인하기", "kicker": "x²+y²=9, y=3", "blocks": [
            {"type": "question", "title": "예제", "text": "원 x²+y²=9와 직선 y=3의 위치 관계와 교점을 구하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["y=3을 대입하면 x²+9=9이므로 x²=0입니다.", "x=0인 중근 하나를 얻습니다.", "교점은 (0,3) 하나이므로 직선 y=3은 원에 접합니다."]},
            {"type": "answer", "title": "답", "text": "한 점 (0,3)에서 접한다."},
        ]},
        {"id": "math-upper-line-circle-practice", "template": "practice", "title": "직선과 원의 교점 개수 연습", "kicker": "대입과 판별식", "blocks": [
            {"type": "question", "title": "문제", "text": "원 x²+y²=25와 직선 y=4의 교점 개수와 좌표를 구하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "y=4를 원에 대입해 x²의 값을 구하고 실근을 확인하세요."},
            {"type": "answer", "title": "정답", "text": "x²+16=25이므로 x=±3입니다. 교점은 (3,4), (−3,4) 두 개입니다."},
            {"type": "checklist", "title": "마무리", "items": ["직선식을 원의 방정식에 대입했나요?", "근의 개수와 교점의 개수를 연결했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 직선과 원의 위치 관계 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "직선과 원의 교점 및 접선", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_직선과원의위치관계_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 직선과 원의 위치 관계\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
