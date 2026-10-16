"""Create a first authored 2015 Math (Upper) polynomial subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "다항식", "다항식 연산", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {
            "id": "math-upper-poly-like-terms-opening",
            "template": "opening",
            "title": "어떤 항끼리 더하고 뺄 수 있을까?",
            "kicker": "다항식의 연산",
            "blocks": [
                {"type": "lead", "title": "오늘의 질문", "text": "3x²+2xy−x²+5xy를 간단히 하면 무엇일까요?"},
                {"type": "thinking", "title": "먼저 분류하기", "text": "문자와 각 문자의 지수를 비교해 같은 항끼리 묶어 보세요."},
                {"type": "answer", "title": "확인", "text": "x²항은 3−1=2, xy항은 2+5=7이므로 2x²+7xy입니다."},
            ],
        },
        {
            "id": "math-upper-poly-like-terms-concept",
            "template": "concept",
            "title": "동류항은 계수만 더해 정리한다",
            "kicker": "문자와 지수가 같은 항",
            "blocks": [
                {"type": "definition", "title": "동류항", "text": "문자와 각 문자의 지수가 모두 같은 항을 동류항이라고 합니다. 동류항끼리는 계수를 더하거나 빼고, 문자 부분은 그대로 둡니다."},
                {"type": "solutionStep", "title": "계산 원리", "items": ["3x²−x²=(3−1)x²=2x²", "2xy+5xy=(2+5)xy=7xy", "x²과 xy는 문자 지수가 달라 서로 합칠 수 없습니다."]},
                {"type": "misconception", "title": "주의할 점", "text": "문자 모양만 같다고 동류항은 아닙니다. 예를 들어 x²와 x는 지수가 달라 합칠 수 없습니다."},
            ],
        },
        {
            "id": "math-upper-poly-like-terms-example",
            "template": "example",
            "title": "괄호를 풀고 동류항을 모으기",
            "kicker": "빼기에서는 뒤 다항식의 부호를 바꾼다",
            "blocks": [
                {"type": "question", "title": "예제", "text": "(2x²−xy+3)+(x²+4xy−5)를 간단히 하세요."},
                {"type": "solutionStep", "title": "풀이", "items": ["x²항: 2x²+x²=3x²", "xy항: −xy+4xy=3xy", "상수항: 3−5=−2"]},
                {"type": "answer", "title": "답", "text": "3x²+3xy−2"},
            ],
        },
        {
            "id": "math-upper-poly-like-terms-practice",
            "template": "practice",
            "title": "다항식의 덧셈과 뺄셈 연습",
            "kicker": "같은 문자와 지수부터 찾기",
            "blocks": [
                {"type": "question", "title": "문제", "text": "(3x²+2xy)−(x²−3xy+4)를 간단히 하세요."},
                {"type": "thinking", "title": "생각 순서", "text": "빼는 다항식의 각 항 부호를 바꾼 뒤 x²항, xy항, 상수항을 모으세요."},
                {"type": "answer", "title": "정답", "text": "2x²+5xy−4"},
                {"type": "checklist", "title": "마무리", "items": ["동류항만 모았나요?", "빼기 뒤 괄호 안 항의 부호를 모두 바꾸었나요?"]},
            ],
        },
    ]
    book = {
        "title": "수학(상) 2015 개정 · 다항식의 연산 시범",
        "subtitle": "태그 기반 신규 소단원 초안",
        "category": "concept_textbook",
        "tags": TAGS,
        "chapters": [{"title": "다항식의 덧셈과 뺄셈", "pages": pages}],
        "metadata": {
            "status": "authored_partial_draft",
            "edition_status": "editorial_split_candidate",
            "standard_code_status": "not_crosschecked",
            "source_scope": "고등수학_2015개정_과목범위_공식원문대조.md and the local upper-book market-TOC note",
        },
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_다항식의덧셈과뺄셈_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({p["id"] for p in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme = [
        "# 수학(상) 2015 개정 · 다항식의 덧셈과 뺄셈",
        "",
        "태그 기반 분권 경계 초안 아래에 신규 작성한 첫 소단원 시범입니다.",
        "",
        f"- [{filename}]({filename}): 도입·개념·예제·연습 4쪽",
        "- 태그: " + " · ".join(TAGS),
        "- 범위: 동류항의 뜻, 다항식의 덧셈·뺄셈",
        "- 공식 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.",
        "- 이 파일은 2015 개정 `수학(상)` 상품 경계가 확정되었다는 뜻이 아닙니다.",
        "",
        "재생성: `python tool/build_math_upper_2015_polynomial_sample.py`",
        "",
    ]
    readme_path = OUTPUT / "README.md"
    generated_section = "\n".join(readme).rstrip()
    if readme_path.exists():
        existing_readme = readme_path.read_text(encoding="utf-8")
        next_section = existing_readme.find("\n## ")
        if existing_readme.startswith(readme[0]):
            retained_sections = existing_readme[next_section:].strip() if next_section >= 0 else ""
            combined = generated_section + ("\n\n" + retained_sections if retained_sections else "") + "\n"
        elif generated_section in existing_readme:
            combined = existing_readme
        else:
            combined = existing_readme.rstrip() + "\n\n" + generated_section + "\n"
        readme_path.write_text(combined, encoding="utf-8")
    else:
        readme_path.write_text(generated_section + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
