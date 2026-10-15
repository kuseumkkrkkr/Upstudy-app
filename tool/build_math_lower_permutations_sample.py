"""Create a focused 2015 Math (Lower) permutations subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학하_2015개정_초안"
TAGS = ["수학(하)", "2015 개정", "확률과 통계", "순열", "순서가 있는 선택", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-lower-permutations-opening", "template": "opening", "title": "자리까지 정하면 순서가 중요할까?", "kicker": "순열", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "학생 3명 중 회장과 부회장 한 명씩을 뽑는 방법은 몇 가지일까요?"},
            {"type": "thinking", "title": "직책을 바꾸어 보기", "text": "민수가 회장, 지수가 부회장인 경우와 지수가 회장, 민수가 부회장인 경우를 같은 방법으로 볼 수 있을까요?"},
            {"type": "answer", "title": "확인", "text": "직책이 달라 서로 다른 선택이므로 순서를 구별합니다. 가능한 방법은 3×2=6가지입니다."},
        ]},
        {"id": "math-lower-permutations-concept", "template": "concept", "title": "서로 다른 r개를 순서 있게 고르는 방법", "kicker": "nPr로 나타내기", "blocks": [
            {"type": "definition", "title": "순열", "text": "서로 다른 n개에서 r개를 골라 순서 있게 나열하는 방법을 순열이라고 하며 nPr로 나타냅니다."},
            {"type": "solutionStep", "title": "계산 공식", "items": ["첫 자리는 n가지, 다음 자리는 n−1가지로 줄어듭니다.", "따라서 nPr=n(n−1)…(n−r+1)입니다.", "팩토리얼을 쓰면 nPr=n!/(n−r)!입니다."]},
            {"type": "misconception", "title": "순서를 구별하는지 확인", "text": "회장과 부회장처럼 역할이 다르면 순서가 있는 선택입니다. 순서를 구별하지 않는 선택은 조합과 구분합니다."},
        ]},
        {"id": "math-lower-permutations-example", "template": "example", "title": "다섯 명 중 두 자리 정하기", "kicker": "5P2 계산", "blocks": [
            {"type": "question", "title": "예제", "text": "서로 다른 5명 중에서 회장과 부회장을 뽑는 방법의 수를 구하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["회장은 5명 중 한 명을 뽑습니다.", "회장을 뽑고 나면 부회장은 나머지 4명 중 한 명입니다.", "5P2=5×4=20입니다."]},
            {"type": "answer", "title": "답", "text": "20가지"},
        ]},
        {"id": "math-lower-permutations-practice", "template": "practice", "title": "순열 계산 연습", "kicker": "순서가 달라지면 다른 경우", "blocks": [
            {"type": "question", "title": "문제", "text": "달리기 선수 5명 중 금메달과 은메달을 받을 두 명을 정하는 방법은 몇 가지일까요?"},
            {"type": "thinking", "title": "생각 순서", "text": "금메달 수상자를 먼저 정하고, 남은 선수 중 은메달 수상자를 정하세요."},
            {"type": "answer", "title": "정답", "text": "5P2=5×4=20가지"},
            {"type": "checklist", "title": "마무리", "items": ["금·은 순위를 구분했나요?", "첫 번째 선택 뒤 남은 인원이 한 명 줄었나요?"]},
        ]},
    ]
    book = {"title": "수학(하) 2015 개정 · 순열 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "순열", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학하_2015개정_순열_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 순열\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
