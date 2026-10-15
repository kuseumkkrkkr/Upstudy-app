"""Create a focused 2015 Math (Upper) rational equation subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "여러 가지 방정식", "분수방정식", "해의 검토", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-rational-equation-opening", "template": "opening", "title": "분모를 없애면 해가 항상 남을까?", "kicker": "분수방정식", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "(x+1)/(x−1)=2/(x−1)을 풀면 x=1이 나옵니다. 이 값은 해일까요?"},
            {"type": "thinking", "title": "원래 식에 대입", "text": "x=1을 처음 식의 분모에 넣을 수 있는지 확인해 보세요."},
            {"type": "answer", "title": "확인", "text": "분모가 0이 되므로 x=1은 원래 식에 넣을 수 없습니다. 따라서 해가 아닙니다."},
        ]},
        {"id": "math-upper-rational-equation-concept", "template": "concept", "title": "분모가 0이 되는 값은 처음부터 제외", "kicker": "공통분모를 곱한 뒤 해 검토", "blocks": [
            {"type": "definition", "title": "분수방정식 풀이", "text": "미지수가 분모에 포함된 방정식은 분모를 0으로 만드는 값을 제외하고, 양변에 공통분모를 곱해 푼 뒤 후보를 원래 식에서 확인합니다."},
            {"type": "solutionStep", "title": "풀이 순서", "items": ["각 분모를 0으로 두어 제외할 값을 기록합니다.", "양변에 공통분모를 곱해 분수식을 정리합니다.", "얻은 후보를 처음 식에 대입해 제외값이 아닌지 확인합니다."]},
            {"type": "misconception", "title": "변형 뒤 후보가 해가 아닐 수 있다", "text": "공통분모를 곱하는 과정에서 처음 식에 넣을 수 없는 값이 후보로 나올 수 있습니다. 원래 식의 정의 조건을 마지막까지 유지하세요."},
        ]},
        {"id": "math-upper-rational-equation-example", "template": "example", "title": "분모를 0으로 만드는 후보 걸러내기", "kicker": "(x+1)/(x−1)=2/(x−1)", "blocks": [
            {"type": "question", "title": "예제", "text": "(x+1)/(x−1)=2/(x−1)을 풀어 보세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["분모가 0이 되는 x=1은 제외합니다.", "x≠1에서 양변에 x−1을 곱하면 x+1=2이므로 x=1입니다.", "이 후보는 제외값이므로 원래 방정식의 해가 없습니다."]},
            {"type": "answer", "title": "답", "text": "해는 없다."},
        ]},
        {"id": "math-upper-rational-equation-practice", "template": "practice", "title": "분수방정식 풀고 확인하기", "kicker": "제외값과 해를 구분", "blocks": [
            {"type": "question", "title": "문제", "text": "2/(x−1)=3/(x+1)을 풀고 제외값을 확인하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "먼저 x=1, −1을 제외하고 양변에 (x−1)(x+1)을 곱하세요."},
            {"type": "answer", "title": "정답", "text": "2(x+1)=3(x−1)에서 x=5입니다. 제외값이 아니므로 해는 x=5입니다."},
            {"type": "checklist", "title": "마무리", "items": ["분모가 0인 값을 먼저 제외했나요?", "구한 후보가 제외값인지 확인했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 분수방정식 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "분수방정식과 해의 검토", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_분수방정식_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 분수방정식\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
