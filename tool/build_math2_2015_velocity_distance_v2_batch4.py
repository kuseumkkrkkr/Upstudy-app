"""Supplement the 2015 Mathematics II velocity/distance criterion with reversal cases."""
from __future__ import annotations

import json
import re
from fractions import Fraction
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "수학Ⅱ_2015개정_속도거리_보충_Batch4_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "수학Ⅱ_2015개정_속도거리_보충_Batch4_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
PRIOR_BATCH = MANUSCRIPTS / "수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
CODE = "12수학Ⅱ03-06"


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    if not re.search(rf"\[{re.escape(CODE)}\]\s*속도와 거리에 대한 문제를 해결할 수 있다", official):
        raise RuntimeError(f"Official criterion text not verified: {CODE}")
    prior = json.loads(PRIOR_BATCH.read_text(encoding="utf-8-sig"))
    chapters = [chapter for chapter in prior.get("chapters", []) if CODE in json.dumps(chapter, ensure_ascii=False)]
    if len(chapters) != 1:
        raise RuntimeError(f"Expected one prior candidate chapter for {CODE}, found {len(chapters)}")
    pages = chapters[0].get("pages", [])
    application_text = " ".join(
        block.get("text", "")
        for page in pages if page.get("template") in {"example", "practice"}
        for block in page.get("blocks", [])
    )
    if "v(t)=2" not in application_text or "속도 3" not in application_text:
        raise RuntimeError("Prior constant-speed example/exercise changed; re-audit before supplementing")
    if any(token in application_text for token in ("방향 전환", "부호가 바뀌", "v(t)=t-")):
        raise RuntimeError("Prior candidate now has a direction-reversal application; re-audit the gap")


def make_page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_gap_evidence()
    slug = "m2-velocity-b4"
    graph = {
        "items": [{"id": "velocity-reversal", "type": "function", "label": "v(t)=t−2", "colorHex": "#B42318", "enabled": True, "expression": "x-2"}],
        "settings": {"showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False, "viewport": {"left": 0, "right": 4, "top": 3, "bottom": -3}, "parameters": []},
    }
    pages = [
        make_page(slug+"-open", "opening", "속도가 음수가 되면 거리는 어떻게 셀까?", [
            {"type": "lead", "title": "핵심 질문", "text": "속도 v(t)=t−2로 0≤t≤4 동안 움직일 때 변위와 이동거리를 구별합니다."},
            {"type": "thinking", "title": "먼저 예측하기", "text": "속도 그래프가 시간축 아래에 있는 구간은 이동거리에서 어떻게 계산해야 할까요?"},
        ]),
        make_page(slug+"-concept", "concept", "변위와 이동거리", [
            {"type": "definition", "title": "부호 있는 변화와 실제 거리", "text": "위치의 변화량인 변위는 속도의 정적분이다. 실제 이동거리는 속력 |v(t)|를 적분한 값이다. v(t)=0인 시각에서 진행 방향이 바뀌면 구간을 나누어 각 거리의 양수 값을 더한다."},
            {"type": "formula", "title": "두 양의 구분", "text": "변위=∫ₐᵇv(t)dt, 이동거리=∫ₐᵇ|v(t)|dt"},
            {"type": "graph", "title": "v(t)=t−2", "text": "그래프의 가로축은 시간 t를 나타내도록 x축을 사용했다. t=2에서 속도가 0이 되어 부호가 바뀐다.", "graph": graph},
        ]),
        make_page(slug+"-example", "example", "방향 전환이 있는 예제", [
            {"type": "question", "title": "예제", "text": "속도 v(t)=t−2로 0≤t≤4 동안 움직일 때 변위와 이동거리를 각각 구하라."},
            {"type": "solutionStep", "title": "1단계 · 부호 확인", "text": "v(t)=0은 t=2이다. 0≤t<2에서 v(t)<0이고 2<t≤4에서 v(t)>0이므로 이 시각에 진행 방향이 바뀐다."},
            {"type": "solutionStep", "title": "2단계 · 변위", "text": "∫₀⁴(t−2)dt=[t²/2−2t]₀⁴=0이다."},
            {"type": "solutionStep", "title": "3단계 · 이동거리", "text": "∫₀²(2−t)dt+∫₂⁴(t−2)dt=2+2=4이다. 변위는 0이지만 실제로 4만큼 이동했다."},
        ]),
        make_page(slug+"-practice", "practice", "연습·해설·퀴즈", [
            {"type": "question", "title": "연습", "text": "속도 v(t)=2t−2로 0≤t≤2 동안 움직인다. 변위와 이동거리를 구하고 방향이 바뀌는 시각을 찾으라."},
            {"type": "hint", "title": "힌트", "text": "v(t)=0을 먼저 풀어 적분 구간을 나눈다. 변위에는 부호를 유지하고 이동거리에는 속력 |v(t)|를 사용한다."},
            {"type": "solutionStep", "title": "해설", "text": "v(t)=0에서 t=1이다. 변위는 ∫₀²(2t−2)dt=[t²−2t]₀²=0이다. 이동거리는 ∫₀¹(2−2t)dt+∫₁²(2t−2)dt=1+1=2이다."},
            {"type": "answer", "title": "정답", "text": "방향 전환 시각 1, 변위 0, 이동거리 2"},
            {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "속도 v(t)=2t−2로 0≤t≤2 동안 움직일 때 이동거리는?", "options": ["2", "0", "4"], "correct_index": 0, "correct_feedback": "정답입니다. t=1에서 나누어 거리 1과 1을 더합니다.", "incorrect_feedback": "변위는 0이지만 이동거리는 속도의 음수·양수 구간을 나누어 더하므로 2입니다.", "hints": ["속도가 0이 되는 t=1을 찾으세요.", "각 구간의 거리 크기를 양수로 더하세요."]}},
        ]),
        make_page(slug+"-summary", "summary", "핵심 정리", [
            {"type": "summary", "title": "풀이 순서", "text": "변위는 속도를 부호 그대로 적분한다. 이동거리는 속도가 0인 시각을 경계로 나눈 뒤 속력을 적분해 합한다."},
            {"type": "checklist", "title": "자기 점검", "items": ["속도 부호로 방향을 확인했다.", "방향 전환 시각에서 구간을 나누었다.", "변위와 이동거리를 별도로 계산했다."]},
        ]),
    ]
    assert len(pages) == 5 and len({page["id"] for page in pages}) == 5
    assert Fraction(4**2, 2) - 2 * 4 == 0  # displacement for v=t-2
    assert Fraction(2 * 2, 1) - Fraction(2**2, 2) == 2  # negative-velocity distance
    assert (Fraction(4**2, 2) - 2 * 4) - (Fraction(2**2, 2) - 2 * 2) == 2
    assert 2 + 2 == 4  # total distance for v=t-2
    assert (2**2 - 2 * 2) - (0**2 - 2 * 0) == 0  # displacement for v=2t-2
    assert (2 * 1 - 1**2) == 1 and ((2**2 - 2 * 2) - (1**2 - 2 * 1)) == 1
    assert 1 + 1 == 2  # total distance for v=2t-2
    quiz = pages[3]["blocks"][-1]["activity"]
    assert quiz["options"][quiz["correct_index"]] == "2"
    book = {
        "schema_version": 2,
        "title": "수학Ⅱ · 속도 부호와 이동거리 보충 Batch4",
        "subtitle": "2015 개정 기준 12수학Ⅱ03-06 · 방향 전환 사례 보완",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": [CODE], "tags": ["수학Ⅱ", "2015 개정", "속도와 거리 보충", "추가 원고 후보", CODE],
        "chapters": [{"title": "변위와 이동거리", "intro": [f"공식 성취기준 {CODE}에 연결한 보충 후보입니다.", "속도가 부호를 바꾸는 독립 예시이며 Batch1의 상수 속도 사례를 대체하지 않습니다."], "pages": pages}],
        "metadata": {"supplement_only": True, "publication_eligibility": "not_eligible", "teacher_review_status": "pending", "math_review_status": "independent_review_pending", "rights_status": "publication_decision_pending"},
    }
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": [CODE], "candidate_code_reference_type": "official_2015_appendix8_math_criteria_table",
        "module_count": 1, "page_count": 5, "native_activity_count": 1,
        "native_activity_kinds": ["quiz"], "native_graph_count": 1,
        "content_assertion_status": "displacement_and_distance_calculations_checked; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; existing_constant_velocity_candidate_preserved",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 자료 | 실제 범위 | 확인한 공백 |\n|---|---|---|\n| 공식 2015 기준 `{CODE}` | 속도와 거리에 대한 문제 해결 | 속도의 부호가 바뀌는 사례에서도 변위와 총 이동거리를 해결해야 함 |\n| 미연결기준 Batch1 `{CODE}` 후보 | 개념에서 변위와 이동거리 관계를 언급하고, `v(t)=2`·상수 속도 3 사례를 풀이 | 예제·연습에 방향 전환이 없어 변위 상쇄와 이동거리 합산을 계산하지 않음 |\n| 이번 보충 | `v(t)=t−2` 및 `v(t)=2t−2` 사례 | 영점에서 구간을 나누고 부호 있는 변위와 속력 적분을 각각 계산 |\n\n## 보완 범위\n\n5쪽 후보에 개념, 부호 그래프, 방향 전환 예제, 연습 해설, native quiz를 담았습니다. 수치는 직접 만든 예시입니다. 교사·독립 수학 검토와 권리 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built 1 module, {len(pages)} pages, 1 graph, 1 quiz; sha256={digest}")


if __name__ == "__main__":
    main()
