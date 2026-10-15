"""Create a focused 2015 Math (Upper) quadratic function/root subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "이차방정식", "이차함수", "그래프와 실근", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-quadratic-function-opening", "template": "opening", "title": "방정식의 해를 그래프에서 찾을 수 있을까?", "kicker": "이차방정식과 이차함수", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "x²−4x+3=0의 해를 y=x²−4x+3의 그래프에서 어떻게 찾을 수 있을까요?"},
            {"type": "thinking", "title": "y=0인 점 찾기", "text": "방정식을 만족하는 x에서는 함수값 y가 얼마인지 생각해 보세요."},
            {"type": "answer", "title": "확인", "text": "방정식의 해는 그래프가 x축과 만나는 점의 x좌표입니다. 이 식의 해는 1과 3입니다."},
        ]},
        {"id": "math-upper-quadratic-function-concept", "template": "concept", "title": "실근의 개수는 포물선과 x축의 교점 수", "kicker": "판별식과 그래프 연결", "blocks": [
            {"type": "definition", "title": "방정식과 x절편", "text": "이차방정식 ax²+bx+c=0의 실근은 이차함수 y=ax²+bx+c의 그래프가 x축과 만나는 점의 x좌표입니다."},
            {"type": "solutionStep", "title": "판별식으로 교점 수 보기", "items": ["판별식 D>0이면 서로 다른 두 실근이 있어 x축과 두 점에서 만납니다.", "D=0이면 중근이 있어 x축에 접합니다.", "D<0이면 실근이 없어 그래프와 x축이 만나지 않습니다."]},
            {"type": "misconception", "title": "교점의 x좌표가 해", "text": "그래프의 교점 자체를 방정식의 해라고 하지 않습니다. 교점에서 x좌표를 읽어 해를 구합니다."},
        ]},
        {"id": "math-upper-quadratic-function-example", "template": "example", "title": "포물선의 x절편과 꼭짓점 찾기", "kicker": "y=x²−4x+3", "blocks": [
            {"type": "question", "title": "예제", "text": "y=x²−4x+3의 그래프와 x축의 교점 및 꼭짓점을 구하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["x²−4x+3=(x−1)(x−3)이므로 x절편은 (1,0), (3,0)입니다.", "y=(x−2)²−1로 고치면 꼭짓점은 (2,−1)입니다.", "그래프가 x축과 두 점에서 만나므로 방정식은 서로 다른 두 실근을 가집니다."]},
            {"type": "answer", "title": "답", "text": "x절편 (1,0), (3,0), 꼭짓점 (2,−1)"},
        ]},
        {"id": "math-upper-quadratic-function-practice", "template": "practice", "title": "이차함수 그래프와 방정식 연습", "kicker": "인수분해와 완전제곱식", "blocks": [
            {"type": "question", "title": "문제", "text": "y=x²+2x−3의 x절편과 꼭짓점을 구하고, x²+2x−3=0의 실근 개수를 말하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "이차식을 인수분해해 x절편을 구하고, 완전제곱식으로 바꾸어 꼭짓점을 찾으세요."},
            {"type": "answer", "title": "정답", "text": "y=(x+3)(x−1)=(x+1)²−4이므로 x절편은 (−3,0), (1,0), 꼭짓점은 (−1,−4)입니다. 실근은 2개입니다."},
            {"type": "checklist", "title": "마무리", "items": ["x절편의 x좌표를 방정식의 해로 읽었나요?", "완전제곱식에서 꼭짓점 좌표의 부호를 바르게 읽었나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 이차방정식과 이차함수 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "이차함수 그래프와 이차방정식의 실근", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_이차방정식과이차함수_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 이차방정식과 이차함수\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
