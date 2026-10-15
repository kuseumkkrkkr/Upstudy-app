"""Create a focused 2015 Math (Upper) quadratic complex-roots subunit draft."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학상_2015개정_초안"
TAGS = ["수학(상)", "2015 개정", "방정식과 부등식", "이차방정식", "복소수", "판별식", "신규 시범", "공식 코드 대조 전"]


def main() -> None:
    pages = [
        {"id": "math-upper-quadratic-complex-opening", "template": "opening", "title": "실수 해가 없으면 방정식을 풀 수 없을까?", "kicker": "복소수 범위의 이차방정식", "blocks": [
            {"type": "lead", "title": "오늘의 질문", "text": "x²−2x+5=0은 실수 범위에서 해가 있을까요?"},
            {"type": "thinking", "title": "판별식으로 먼저 판단", "text": "판별식 b²−4ac의 부호를 계산하고, 근의 공식의 제곱근 부분을 살펴보세요."},
            {"type": "answer", "title": "확인", "text": "판별식은 −16입니다. 복소수 i를 사용하면 두 근을 나타낼 수 있습니다."},
        ]},
        {"id": "math-upper-quadratic-complex-concept", "template": "concept", "title": "음수 판별식은 켤레인 두 복소수 근을 만든다", "kicker": "실수 계수 이차방정식", "blocks": [
            {"type": "definition", "title": "근의 공식", "text": "ax²+bx+c=0 (a≠0)의 근은 x={−b±√(b²−4ac)}/(2a)입니다. 판별식 D=b²−4ac가 음수이면 √D=i√(−D)로 나타냅니다."},
            {"type": "solutionStep", "title": "근을 정리하는 순서", "items": ["a,b,c를 확인하고 D=b²−4ac를 계산합니다.", "D<0이면 √D=i√(−D)로 바꿉니다.", "근의 공식에 대입해 실수부와 허수부를 정리합니다. 두 근은 서로 켤레입니다."]},
            {"type": "misconception", "title": "√(−m)은 i√m", "text": "m>0일 때 √(−m)=i√m입니다. √(−m)을 실수로 계산하거나 i의 부호를 빠뜨리지 마세요."},
        ]},
        {"id": "math-upper-quadratic-complex-example", "template": "example", "title": "판별식이 음수인 방정식 풀기", "kicker": "x²−2x+5=0", "blocks": [
            {"type": "question", "title": "예제", "text": "x²−2x+5=0을 복소수 범위에서 풀어 보세요."},
            {"type": "solutionStep", "title": "풀이", "items": ["D=(−2)²−4·1·5=−16입니다.", "근의 공식에서 √D=4i입니다.", "x={2±4i}/2=1±2i입니다."]},
            {"type": "answer", "title": "답", "text": "x=1+2i 또는 x=1−2i"},
        ]},
        {"id": "math-upper-quadratic-complex-practice", "template": "practice", "title": "복소수 근 계산 연습", "kicker": "판별식과 i를 순서대로 적용", "blocks": [
            {"type": "question", "title": "문제", "text": "x²+4x+8=0을 복소수 범위에서 풀어 보세요."},
            {"type": "thinking", "title": "생각 순서", "text": "판별식을 계산하고, 음수의 제곱근을 i를 이용해 나타낸 뒤 근의 공식에 대입하세요."},
            {"type": "answer", "title": "정답", "text": "D=16−32=−16이므로 x={−4±4i}/2=−2±2i입니다."},
            {"type": "checklist", "title": "마무리", "items": ["판별식 부호를 확인했나요?", "두 근의 실수부가 같고 허수부 부호가 반대인가요?"]},
        ]},
    ]
    book = {"title": "수학(상) 2015 개정 · 복소수 범위의 이차방정식 시범", "subtitle": "태그 기반 신규 소단원 초안", "category": "concept_textbook", "tags": TAGS, "chapters": [{"title": "복소수 범위의 이차방정식", "pages": pages}], "metadata": {"status": "authored_partial_draft", "edition_status": "editorial_split_candidate", "standard_code_status": "not_crosschecked"}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "수학상_2015개정_복소수범위의이차방정식_BookData_초안.json"
    target = OUTPUT / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"][0]["pages"]) != 4 or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Generated draft structure or page IDs are invalid")
    readme_path = OUTPUT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    if filename not in readme:
        readme += f"\n## 복소수 범위의 이차방정식\n\n- [{filename}]({filename}): 도입·개념·예제·연습 4쪽\n- 태그: {' · '.join(TAGS)}\n- 성취기준 코드 대조·교사 검수·학생 파일럿은 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Created one tagged subunit with {len(pages)} pages.")


if __name__ == "__main__":
    main()
