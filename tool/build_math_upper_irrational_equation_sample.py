"""Create a focused 2015 Math (Upper) radical equation subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "여러 가지 방정식", "무리방정식", "해의 검토", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-irrational-equation-opening", "template": "opening", "title": "양변을 제곱한 뒤에도 해일까?", "kicker": "무리방정식", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "√(x+1)=x−1을 풀 때 x=0도 해가 될까요?"},
            {"type": "thinking", "title": "먼저 오른쪽 부호 보기", "text": "왼쪽은 음수가 아니므로 등식이 성립하려면 x−1도 음수가 아니어야 합니다."},
            {"type": "answer", "title": "확인", "text": "x≥1이어야 합니다. 제곱해 얻은 후보 중 이 조건과 원래 식을 만족하는 값만 해입니다."},
        ]},
        {"id": "math-upper-irrational-equation-concept", "template": "concept", "title": "제곱 전 조건을 세우고 원래 식으로 검산", "kicker": "제곱으로 생기는 후보 걸러내기", "blocks": [
            {"type": "definition", "title": "무리방정식 풀이", "text": "미지수가 근호 안에 있는 방정식은 근호의 정의역과 양변의 부호 조건을 확인하고, 근호를 없애도록 변형한 뒤 후보를 원래 식에 대입해 검토합니다."},
            {"type": "solutionStep", "title": "풀이 순서", "items": ["근호 안의 식이 0 이상인지 확인합니다.", "근호가 있는 항을 한쪽에 두고 양변의 부호 조건을 기록합니다.", "필요한 횟수만큼 제곱한 뒤 얻은 후보를 원래 식에서 확인합니다."]},
            {"type": "misconception", "title": "제곱은 동치 변형이 아닐 수 있다", "text": "양변을 제곱하면 원래 식에는 맞지 않는 후보가 생길 수 있습니다. 제곱으로 얻은 방정식의 모든 근을 바로 해로 확정하지 마세요."},
        ]},
        {"id": "math-upper-irrational-equation-example", "template": "example", "title": "제곱 후 조건으로 후보 확인", "kicker": "√(x+1)=x−1", "blocks": [
            {"type": "question", "title": "예제", "text": "√(x+1)=x−1을 풀어 보세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["오른쪽이 음수가 아니어야 하므로 x≥1입니다.", "양변을 제곱하면 x+1=(x−1)², 즉 x(x−3)=0입니다.", "후보 0,3 중 조건 x≥1을 만족하는 3만 원래 식에도 맞습니다."]},
            {"type": "answer", "title": "답", "text": "x=3"},
        ]},
        {"id": "math-upper-irrational-equation-practice", "template": "practice", "title": "무리방정식의 해 검토 연습", "kicker": "정의역·부호·대입", "blocks": [
            {"type": "question", "title": "문제", "text": "√(2x+3)=x를 풀어 보세요."},
            {"type": "thinking", "title": "생각 순서", "text": "먼저 x≥0 조건을 기록하고 양변을 제곱한 뒤 후보를 원래 식에 넣어 보세요."},
            {"type": "answer", "title": "정답", "text": "x²−2x−3=0에서 후보는 3, −1입니다. x≥0이고 원래 식에 맞는 해는 x=3입니다."},
            {"type": "checklist", "title": "마무리", "items": ["근호 안이 음수가 되지 않는지 확인했나요?", "오른쪽 항의 부호 조건을 고려했나요?", "후보를 원래 식에 대입했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 무리방정식 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "무리방정식과 해의 검토", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_무리방정식_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 무리방정식\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
