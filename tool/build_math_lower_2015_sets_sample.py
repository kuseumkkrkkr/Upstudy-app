"""Create a first authored 2015 Math (Lower) sets subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학하_2015개정_초안"
TAGS = ["수학(하)", "2015 개정", "수와 연산", "집합", "집합의 연산", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {
            "id": "math-lower-sets-opening",
            "template": "opening",
            "title": "두 모임에 공통인 원소는 무엇일까?",
            "kicker": "집합의 연산",
            "blocks": [
                {"type": "lead", "title": "오늘의 질문", "text": "A={1,2,3}, B={3,4}일 때 두 집합에 공통인 원소는 무엇일까요?"},
                {"type": "thinking", "title": "먼저 찾아보기", "text": "A와 B의 원소를 나란히 놓고 두 집합에 모두 들어 있는 원소를 표시하세요."},
                {"type": "answer", "title": "확인", "text": "두 집합에 모두 들어 있는 원소는 3이므로 A∩B={3}입니다."},
            ],
        },
        {
            "id": "math-lower-sets-concept",
            "template": "concept",
            "title": "합집합은 한쪽이라도 속하는 원소, 교집합은 공통 원소",
            "kicker": "원소를 기준으로 구분하기",
            "blocks": [
                {"type": "definition", "title": "합집합과 교집합", "text": "A∪B는 A 또는 B에 속하는 원소를 모은 집합이고, A∩B는 A와 B에 공통으로 속하는 원소를 모은 집합입니다."},
                {"type": "solutionStep", "title": "원소로 확인", "items": ["A={1,2,3}, B={3,4}에서 한쪽이라도 속하는 원소는 1,2,3,4입니다.", "두 집합에 모두 속하는 원소는 3입니다.", "따라서 A∪B={1,2,3,4}, A∩B={3}입니다."]},
                {"type": "misconception", "title": "중복은 한 번만", "text": "합집합에서 공통 원소를 두 번 적지 않습니다. 집합은 같은 원소를 반복해 쓰지 않습니다."},
            ],
        },
        {
            "id": "math-lower-sets-example",
            "template": "example",
            "title": "두 조건을 만족하는 항목 찾기",
            "kicker": "원소 목록에서 교집합 읽기",
            "blocks": [
                {"type": "question", "title": "예제", "text": "C={a,b}, D={b,c}일 때 C∪D와 C∩D를 구하세요."},
                {"type": "solutionStep", "title": "풀이", "items": ["한쪽이라도 속하는 원소는 a,b,c입니다.", "양쪽에 모두 속하는 원소는 b입니다."]},
                {"type": "answer", "title": "답", "text": "C∪D={a,b,c}, C∩D={b}"},
            ],
        },
        {
            "id": "math-lower-sets-practice",
            "template": "practice",
            "title": "합집합과 교집합 연습",
            "kicker": "원소를 빠짐없이 분류하기",
            "blocks": [
                {"type": "question", "title": "문제", "text": "X={1,3,5}, Y={2,3,4}일 때 X∪Y와 X∩Y를 구하세요."},
                {"type": "thinking", "title": "생각 순서", "text": "합집합에는 중복 없이 모두 모으고, 교집합에는 양쪽에 함께 있는 원소만 남기세요."},
                {"type": "answer", "title": "정답", "text": "X∪Y={1,2,3,4,5}, X∩Y={3}"},
                {"type": "checklist", "title": "마무리", "items": ["합집합에서 원소를 중복해 적지 않았나요?", "교집합에는 두 집합에 공통인 원소만 남겼나요?"]},
            ],
        },
    ]
    book = {
        "title": "수학(하) 2015 개정 · 집합의 연산 시범",
        "subtitle": "태그 기반 신규 소단원 초안",
        "category": "concept_textbook",
        "tags": TAGS,
        "chapters": [{"title": "집합의 합집합과 교집합", "pages": pages}],
        "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"},
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학하_2015개정_집합의합집합과교집합_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme = ["# 수학(하) 2015 개정 · 집합의 합집합과 교집합", "", "공식 과목 범위 요약의 집합 영역에 맞춘 신규 소단원 시범입니다.", "", f"- [{filename}]({filename}): 도입·개념·예제·연습 4쪽", "- 태그: " + " · ".join(TAGS), "- 공식 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.", "- 상·하 상품 분권은 편집 초안이며 최종 승인되지 않았습니다.", "", "재생성: `python tool/build_math_lower_2015_sets_sample.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(readme), encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
