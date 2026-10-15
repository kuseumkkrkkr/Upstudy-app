"""Create a focused 2015 Math (Lower) rational function subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학하_2015개정_초안"
TAGS = ["수학(하)", "2015 개정", "함수", "유리함수", "반비례 관계", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-lower-rational-function-opening", "template": "opening", "title": "입력이 커지면 출력은 어떻게 변할까?", "kicker": "유리함수 y=k/x", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "y=6/x에서 x가 1, 2로 커지면 y의 값은 어떻게 달라질까요?"},
            {"type": "thinking", "title": "값을 대입하기", "text": "x=1과 x=2일 때 y를 계산해 보세요. x=0을 넣을 수 있는지도 살펴보세요."},
            {"type": "answer", "title": "확인", "text": "y는 각각 6, 3입니다. x=0에서는 나눗셈을 할 수 없으므로 정의역에서 제외합니다."},
        ]},
        {"id": "math-lower-rational-function-concept", "template": "concept", "title": "y=k/x에서 x와 y는 반비례 관계", "kicker": "정의역과 치역 확인", "blocks": [
            {"type": "definition", "title": "기본 꼴", "text": "y=k/x (k≠0)는 x가 0이 아닌 실수일 때 정의되는 유리함수입니다. x와 y의 곱은 xy=k로 일정합니다."},
            {"type": "solutionStep", "title": "그래프의 기본 성질", "items": ["k>0이면 x와 y의 부호가 같아 그래프는 제1·3사분면에 놓입니다.", "k<0이면 x와 y의 부호가 달라 그래프는 제2·4사분면에 놓입니다.", "정의역은 x≠0인 실수이고, 치역도 y≠0인 실수입니다."]},
            {"type": "misconception", "title": "0은 정의역과 치역에서 제외", "text": "분모 x가 0일 수 없고, k≠0이므로 y도 0이 될 수 없습니다."},
        ]},
        {"id": "math-lower-rational-function-example", "template": "example", "title": "표로 그래프의 위치 살피기", "kicker": "y=2/x의 대응값", "blocks": [
            {"type": "question", "title": "예제", "text": "y=2/x에서 x=−2, −1, 1, 2일 때 y를 구하고 그래프가 놓이는 사분면을 말하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["x=−2,−1,1,2를 차례로 대입하면 y=−1,−2,2,1입니다.", "x와 y의 부호가 같은 점과 반대인 점을 확인합니다.", "k=2>0이므로 그래프는 제1·3사분면에 놓입니다."]},
            {"type": "answer", "title": "답", "text": "대응값은 −1, −2, 2, 1이며 그래프는 제1·3사분면에 놓입니다."},
        ]},
        {"id": "math-lower-rational-function-practice", "template": "practice", "title": "유리함수 기본 성질 연습", "kicker": "계수의 부호와 사분면", "blocks": [
            {"type": "question", "title": "문제", "text": "y=−3/x의 그래프가 놓이는 사분면을 말하고, x=3일 때 y의 값을 구하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "k의 부호를 보고 x와 y의 부호 관계를 확인한 뒤 x=3을 대입하세요."},
            {"type": "answer", "title": "정답", "text": "k<0이므로 그래프는 제2·4사분면에 놓이며, x=3일 때 y=−1입니다."},
            {"type": "checklist", "title": "마무리", "items": ["k의 부호로 사분면을 판단했나요?", "x=0은 정의역에서 제외되는 점을 기억했나요?"]},
        ]},
    ]
    book = {"title": "수학(하) 2015 개정 · 유리함수 y=k/x 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "유리함수의 기본 꼴", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학하_2015개정_유리함수_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 유리함수 y=k/x\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
