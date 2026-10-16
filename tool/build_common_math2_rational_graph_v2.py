"""Build the graph-and-interaction supplement missing from 2022 rational functions."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
SOURCE = MANUSCRIPTS / "공통수학2_유리함수_체험형_시범.html"
OUT = MANUSCRIPTS / "공통수학2_2022개정_유리함수그래프탐구_Batch1_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "공통수학2_2022개정_유리함수그래프탐구_Batch1_원고패키지"
CODE = "10공수2-03-04"


def block(kind: str, title: str, text: str, **extra: object) -> dict[str, object]:
    return {"type": kind, "title": title, "text": text, **extra}


def page(pid: str, template: str, title: str, *blocks: dict[str, object]) -> dict[str, object]:
    return {"id": pid, "template": template, "title": title, "blocks": list(blocks)}


def make_book() -> dict[str, object]:
    chapters = [{"title": "유리함수 그래프와 점근선 탐구", "standard_codes": [CODE],
        "source_html_reference": SOURCE.name, "pages": [
        page("rational-open", "opening", "그래프와 점근선을 함께 읽기",
             block("lead", "기준 연결", f"2022 개정 기준 {CODE}: 유리함수 그래프를 그리고 성질을 탐구합니다."),
             block("thinking", "오늘의 질문", "y=2/(x−1)−3에서 x=1과 y=−3은 그래프에서 어떤 역할을 할까요?")),
        page("rational-concept", "concept", "이동된 기본 그래프",
             block("definition", "기본형", "y=a/(x−h)+k (a≠0)에서 x=h는 분모가 0이 되는 값이므로 정의역에서 제외됩니다. 그래프는 수직점근선 x=h와 수평점근선 y=k에 가까워집니다."),
             block("formula", "가지의 위치", "a>0이면 중심 (h,k)을 기준으로 오른쪽 위·왼쪽 아래에 가지가 놓이고, a<0이면 왼쪽 위·오른쪽 아래에 놓입니다."),
             block("misconception", "정의역 확인", "점근선은 그래프가 닿는 직선이라고 단정하지 않습니다. x=h에서는 함수가 정의되지 않습니다.")),
        page("rational-example", "example", "함숫값으로 그래프 위치 확인",
             block("question", "예제", "f(x)=2/(x−1)−3에서 f(0), f(2)를 구하고 점근선을 쓰세요."),
             block("solutionStep", "함숫값", "f(0)=2/(−1)−3=−5, f(2)=2/1−3=−1입니다."),
             block("answer", "그래프 정보", "정의역은 x≠1이고 점근선은 x=1, y=−3입니다. 두 점 (0,−5), (2,−1)은 중심 (1,−3)의 서로 다른 쪽 가지에 놓입니다.")),
        page("rational-explore", "experiment", "매개변수를 움직여 그래프 탐구",
             block("lead", "조작 순서", "a를 바꾸어 가지의 방향을 비교하고, h와 k를 움직여 수직·수평 점근선이 어떻게 이동하는지 관찰하세요."),
             {"type": "activity", "activity": {"id": "rational-function-explorer-2022", "kind": "rationalFunctionExplorer",
                 "prompt": "y=a/(x−h)+k의 매개변수를 바꾸어 정의역과 점근선을 관찰합니다.", "hints": ["분모를 0으로 만드는 값과 분수식 바깥의 상수를 따로 보세요."],
                 "explorer": {"a_values": [-2, -1, 1, 2], "initial_a": 2,
                     "min_h": -2, "max_h": 2, "h_step": 0.5, "initial_h": 1,
                     "min_k": -3, "max_k": 3, "k_step": 0.5, "initial_k": -3}}}),
        page("rational-quiz", "practice", "정의역과 점근선 확인",
             block("question", "퀴즈", "y=2/(x−1)−3의 정의역과 두 점근선은?"),
             {"type": "activity", "activity": {"id": "rational-asymptote-quiz-2022", "kind": "quiz",
                 "prompt": "y=2/(x−1)−3의 정의역과 두 점근선은?",
                 "options": ["x≠1, x=1과 y=−3", "x≠−1, x=−1과 y=3", "모든 실수, x=1과 y=3"],
                 "correct_index": 0, "correct_feedback": "분모가 0인 x=1을 제외하며 점근선은 x=1, y=−3입니다.",
                 "incorrect_feedback": "분모 x−1과 분수식 밖의 −3을 각각 확인하세요.",
                 "hints": ["분모가 0인 x는 정의역에서 제외합니다.", "식의 바깥 상수 −3이 수평 점근선입니다."]}}),
        page("rational-independent", "practice", "독립 연습",
             block("question", "문제", "y=−1/(x+2)+4의 정의역에서 제외되는 값과 점근선을 구하세요."),
             block("answer", "정답과 해설", "x=−2에서 정의되지 않습니다. 수직점근선은 x=−2, 수평점근선은 y=4입니다.")),
        page("rational-summary", "summary", "그래프 성질 점검",
             block("summary", "핵심 정리", "y=a/(x−h)+k에서는 x=h를 정의역에서 제외하고 x=h, y=k를 점근선으로 읽습니다. a의 부호는 두 가지의 위치를 정합니다."),
             block("checklist", "스스로 점검", "정의역, 점근선, a의 부호에 따른 두 가지 위치를 그래프와 연결했나요?")),
    ]}]
    return {"schema_version": 2, "title": "공통수학2 · 유리함수 그래프 탐구 보충 후보",
        "subtitle": "기존 점근선 설명을 그래프 작도와 매개변수 탐구로 보완",
        "category": "concept_textbook_prototype", "curriculum_version": "2022",
        "tags": ["공통수학2", "2022 개정", "유리함수", "그래프 탐구", CODE],
        "standard_codes": [CODE], "metadata": {"publication_eligibility": "not_eligible",
            "rights_status": "pending", "teacher_review_status": "pending",
            "math_review_status": "author_checks_recorded_independent_review_pending",
            "external_interactive_assets": [SOURCE.name]}, "chapters": chapters}


def validate(book: dict[str, object]) -> None:
    standards = json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]
    row = next(item for item in standards if item["code"] == CODE)
    assert "그래프를 그릴" in row["criterion"] and "성질" in row["criterion"]
    source = SOURCE.read_text(encoding="utf-8")
    for marker in ('id="a"', 'id="h"', 'id="k"', 'id="step"', 'id="reset"', 'id="check"', 'id="hint"'):
        assert marker in source
    assert "y=2/(x−1)−3" in source
    assert 2 / (0 - 1) - 3 == -5 and 2 / (2 - 1) - 3 == -1
    assert len(book["chapters"]) == 1 and len(book["chapters"][0]["pages"]) == 7
    assert book["chapters"][0]["standard_codes"] == [CODE]
    activities = [b["activity"] for p in book["chapters"][0]["pages"] for b in p["blocks"] if b.get("type") == "activity"]
    assert {a["kind"] for a in activities} == {"quiz", "rationalFunctionExplorer"}


def main() -> None:
    book = make_book()
    validate(book)
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    (PACKAGE / "README.md").write_text(
        f"# 공통수학2 유리함수 그래프 탐구 보충 후보\n\n원본: [`{OUT.name}`](../{OUT.name})\n\n"
        f"기준 {CODE}의 기존 원고는 점근선과 정의역 설명은 있으나 그래프가 없음을 확인해 그래프 조작·퀴즈를 보완했다. "
        f"원 인터랙션 [`{SOURCE.name}`](../{SOURCE.name})의 a/h/k 조절, 단계 안내, 초기화, 퀴즈·힌트를 수치 payload 기반 native UI로 대응한다. 시각 parity는 사람 검토 전이다.\n",
        encoding="utf-8")
    manifest = {"bookdata_file": OUT.name, "bookdata_sha256": hashlib.sha256(OUT.read_bytes()).hexdigest(),
        "candidate_code_references": [CODE], "candidate_code_reference_type": "official_2022_hwp_standard",
        "source_html": SOURCE.name, "source_interaction_mapping": {"parameters": ["a", "h", "k"], "controls": ["slider/dropdown", "step", "reset", "quiz", "hint"]},
        "module_count": 1, "page_count": 7, "native_activity_count": 2,
        "native_activity_kinds": ["rationalFunctionExplorer", "quiz"],
        "curriculum_review_status": "pending", "math_review_status": "pending_independent_review",
        "teacher_review_status": "pending", "rights_status": "pending",
        "publication_eligibility": "not_eligible", "visual_parity_status": "human_review_pending"}
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Generated 1 2022 Common Math 2 rational-function graph supplement (7 pages, 2 activities).")


if __name__ == "__main__":
    main()
