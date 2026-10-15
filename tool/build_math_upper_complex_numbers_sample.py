"""Create a focused 2015 Math (Upper) complex numbers subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "복소수", "허수단위", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-complex-opening", "template": "opening", "title": "제곱해서 −1이 되는 수가 있을까?", "kicker": "복소수", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "실수 범위에서 x²=−1을 만족하는 수를 찾을 수 있을까요?"},
            {"type": "thinking", "title": "실수의 제곱 살펴보기", "text": "양수, 0, 음수 중 어느 실수를 제곱해도 결과가 음수가 되지 않습니다."},
            {"type": "answer", "title": "확인", "text": "새로운 수 i를 i²=−1로 정하면 해를 표현할 수 있습니다. i를 허수단위라고 합니다."},
        ]},
        {"id": "math-upper-complex-concept", "template": "concept", "title": "복소수는 a+bi 꼴로 나타낸다", "kicker": "실수부와 허수부", "blocks": [
            {"type": "definition", "title": "복소수", "text": "a,b가 실수일 때 a+bi를 복소수라고 합니다. a를 실수부, b를 허수부라고 하며, i²=−1을 이용해 계산합니다."},
            {"type": "solutionStep", "title": "같은 부분끼리 계산", "items": ["덧셈과 뺄셈은 실수부끼리, 허수부끼리 계산합니다.", "곱셈에서는 분배법칙을 쓰고 i²=−1을 적용합니다.", "예를 들어 (a+bi)(c+di)=(ac−bd)+(ad+bc)i입니다."]},
            {"type": "misconception", "title": "허수부는 i의 계수", "text": "복소수 a+bi의 허수부는 bi가 아니라 실수 b입니다. i²은 i가 아니라 −1입니다."},
        ]},
        {"id": "math-upper-complex-example", "template": "example", "title": "복소수의 덧셈과 뺄셈", "kicker": "실수부·허수부끼리 모으기", "blocks": [
            {"type": "question", "title": "예제", "text": "(2+3i)+(1−4i)를 계산하세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["실수부끼리 더하면 2+1=3입니다.", "허수부의 계수끼리 더하면 3−4=−1입니다.", "따라서 결과는 3−i입니다."]},
            {"type": "answer", "title": "답", "text": "3−i"},
        ]},
        {"id": "math-upper-complex-practice", "template": "practice", "title": "허수단위가 있는 곱셈 연습", "kicker": "분배법칙 뒤 i²=−1 적용", "blocks": [
            {"type": "question", "title": "문제", "text": "(2+i)(1−2i)를 계산하세요."},
            {"type": "thinking", "title": "생각 순서", "text": "분배법칙으로 전개한 다음 i²을 −1로 바꾸어 실수부와 허수부를 정리하세요."},
            {"type": "answer", "title": "정답", "text": "2−4i+i−2i²=4−3i"},
            {"type": "checklist", "title": "마무리", "items": ["분배법칙을 빠짐없이 적용했나요?", "i²=−1을 적용했나요?", "실수부와 허수부를 나누어 정리했나요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 복소수 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "복소수의 뜻과 연산", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_복소수_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 복소수\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
