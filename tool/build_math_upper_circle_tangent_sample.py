"""Create a focused 2015 Math (Upper) circle tangent equation subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "도형의 방정식", "원의 방정식", "접선의 방정식", "반지름과 수직", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-circle-tangent-opening", "template": "opening", "title": "원에 닿는 직선은 반지름과 어떤 관계일까?", "kicker": "원의 접선", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "중심이 O인 원의 접점 P에서 접선과 반지름 OP는 어떤 각을 이룰까요?"},
            {"type": "thinking", "title": "접점에서 살펴보기", "text": "원 밖의 점에서 접선 위의 점까지 거리가 접점에서 가장 짧아지는 상황을 생각해 보세요."},
            {"type": "answer", "title": "확인", "text": "원의 접점에서 반지름은 접선에 수직입니다. 이 수직 관계로 접선의 방정식을 구할 수 있습니다."},
        ]},
        {"id": "math-upper-circle-tangent-concept", "template": "concept", "title": "접선의 법선은 접점으로 향하는 반지름", "kicker": "중심·접점·기울기", "blocks": [
            {"type": "definition", "title": "접선 조건", "text": "중심이 C(a,b)인 원의 접점 P(x₁,y₁)에서 접선은 반지름 CP에 수직입니다. 따라서 접선 위의 점 (x,y)는 (x₁−a)(x−x₁)+(y₁−b)(y−y₁)=0을 만족합니다."},
            {"type": "solutionStep", "title": "접선식 세우기", "items": ["중심 C와 접점 P를 확인합니다.", "반지름 방향 벡터 (x₁−a,y₁−b)를 구합니다.", "그 벡터를 접선의 법선으로 사용해 접점 P를 지나는 직선식을 씁니다."]},
            {"type": "misconception", "title": "접점은 원 위의 점", "text": "접선식을 구하기 전에 주어진 점이 원 위에 있는지 확인합니다. 원 위가 아니면 그 점에서의 접선은 성립하지 않습니다."},
        ]},
        {"id": "math-upper-circle-tangent-example", "template": "example", "title": "원점 중심 원의 접선 구하기", "kicker": "x²+y²=25, P(3,4)", "blocks": [
            {"type": "question", "title": "예제", "text": "원 x²+y²=25 위의 점 P(3,4)에서 접선의 방정식을 구하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["3²+4²=25이므로 P는 원 위의 점입니다.", "중심은 (0,0)이므로 반지름 OP의 방향 벡터는 (3,4)입니다.", "접선은 3(x−3)+4(y−4)=0, 즉 3x+4y=25입니다."]},
            {"type": "answer", "title": "답", "text": "3x+4y=25"},
        ]},
        {"id": "math-upper-circle-tangent-practice", "template": "practice", "title": "중심이 원점이 아닌 원의 접선", "kicker": "중심에서 접점으로 향하는 벡터", "blocks": [
            {"type": "question", "title": "문제", "text": "중심이 C(1,−2), 반지름이 5인 원 위의 점 P(4,2)에서 접선의 방정식을 구하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "CP=(3,4)를 구한 뒤 접선의 법선 벡터로 사용하세요."},
            {"type": "answer", "title": "정답", "text": "3(x−4)+4(y−2)=0, 즉 3x+4y=20입니다."},
            {"type": "checklist", "title": "마무리", "items": ["접점이 원 위에 있는지 확인했나요?", "중심에서 접점으로 향하는 벡터를 법선으로 사용했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 원의 접선 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "원의 접선의 방정식", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_원의접선_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 원의 접선\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
