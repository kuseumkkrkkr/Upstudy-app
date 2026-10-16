"""Supplement the 2015 Math II continuous-function property with EVT applications."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "수학Ⅱ_2015개정_연속함수최대최소_보충_Batch5_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "수학Ⅱ_2015개정_연속함수최대최소_보충_Batch5_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
PRIOR_BATCH = MANUSCRIPTS / "수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
SOURCE_MANUSCRIPT = MANUSCRIPTS / "수학Ⅱ_함수의연속_학생용원고.md"
CODE = "12수학Ⅱ01-04"


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    if not re.search(rf"\[{re.escape(CODE)}\]\s*연속함수의 성질을 이해하고, 이를 활용할 수 있다", official):
        raise RuntimeError(f"Official criterion text not verified: {CODE}")
    source = SOURCE_MANUSCRIPT.read_text(encoding="utf-8")
    if "최대·최소 정리" not in source or "포함하지 않는다" not in source:
        raise RuntimeError("The original manuscript scope statement changed; re-audit before supplementing")
    prior = json.loads(PRIOR_BATCH.read_text(encoding="utf-8-sig"))
    chapters = [chapter for chapter in prior.get("chapters", []) if CODE in json.dumps(chapter, ensure_ascii=False)]
    if len(chapters) != 1:
        raise RuntimeError(f"Expected one prior candidate chapter for {CODE}, found {len(chapters)}")
    application = " ".join(
        block.get("text", "")
        for page in chapters[0].get("pages", [])
        if page.get("template") in {"example", "practice"}
        for block in page.get("blocks", [])
    )
    if "영점" not in application or "최댓값" in application or "최솟값" in application:
        raise RuntimeError("Prior criterion examples changed; re-audit before supplementing")


def make_page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_gap_evidence()
    slug = "m2-extrema-b5"
    graph = {
        "items": [{"id": "continuous-extrema", "type": "function", "label": "f(x)=(x−2)²", "colorHex": "#2457C5", "enabled": True, "expression": "(x-2)^2"}],
        "settings": {"showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False, "viewport": {"left": -2, "right": 4, "top": 10, "bottom": -1}, "parameters": []},
    }
    pages = [
        make_page(slug+"-open", "opening", "연속이면 구간 안에서 가장 크고 작은 값을 찾을 수 있을까?", [
            {"type": "lead", "title": "핵심 질문", "text": "닫힌구간에서 연속인 함수가 최댓값과 최솟값을 실제로 갖는다는 성질을 적용해 봅니다."},
            {"type": "thinking", "title": "먼저 조건 확인", "text": "정리의 결론을 말하기 전에 구간이 닫혀 있는지, 함수가 그 구간 전체에서 연속인지 확인합니다."},
        ]),
        make_page(slug+"-concept", "concept", "최대·최소 정리의 조건", [
            {"type": "definition", "title": "정리", "text": "함수 f가 닫힌구간 [a,b]의 모든 점에서 연속이면 그 구간에서 최댓값과 최솟값을 각각 적어도 한 번 갖는다. 정리는 극값의 존재를 보장하며, 극값의 위치와 값을 찾으려면 함수와 구간을 추가로 살펴야 한다."},
            {"type": "formula", "title": "조건 점검", "text": "연속 on [a,b] ⇒ max f([a,b])와 min f([a,b])가 존재"},
            {"type": "misconception", "title": "주의", "text": "닫힌구간 조건이나 구간 전체의 연속 조건을 빼고 정리를 적용하지 않는다. 열린구간 (0,1)의 f(x)=x는 연속이지만 최댓값과 최솟값을 갖지 않는다."},
        ]),
        make_page(slug+"-example", "example", "최댓값과 최솟값 예제", [
            {"type": "question", "title": "예제", "text": "f(x)=(x−2)²를 [-1,3]에서 살펴본다. 정리가 적용되는지 확인하고 최댓값과 최솟값을 구하라."},
            {"type": "graph", "title": "구간 위의 연속함수", "text": "다항함수이므로 [-1,3] 전체에서 연속이고 구간은 닫혀 있다. 따라서 최댓값과 최솟값이 모두 존재한다.", "graph": graph},
            {"type": "solutionStep", "title": "후보 비교", "text": "꼭짓점 x=2에서 f(2)=0이다. 양 끝에서는 f(-1)=9, f(3)=1이다. 따라서 최솟값은 0, 최댓값은 9이다."},
            {"type": "verification", "title": "정리와 계산 구별", "text": "최대·최소 정리는 두 값의 존재를 보장하고, 꼭짓점과 양 끝의 값을 비교해 실제 값을 찾았다."},
        ]),
        make_page(slug+"-practice", "practice", "연습·해설·퀴즈", [
            {"type": "question", "title": "연습", "text": "f(x)=−x²+4x를 [0,3]에서 살펴본다. 연속함수의 최대·최소 정리가 적용되는지 확인하고 최댓값과 최솟값을 구하라."},
            {"type": "hint", "title": "힌트", "text": "다항함수의 연속성과 닫힌구간 조건을 먼저 확인한 다음, 꼭짓점과 양 끝의 함수값을 비교한다."},
            {"type": "solutionStep", "title": "해설", "text": "다항함수이고 [0,3]은 닫힌구간이므로 정리가 적용된다. f(0)=0, f(3)=3, 꼭짓점 x=2에서 f(2)=4이므로 최솟값은 0, 최댓값은 4이다."},
            {"type": "answer", "title": "정답", "text": "정리 적용 가능, 최댓값 4, 최솟값 0"},
            {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "f(x)=−x²+4x의 [0,3]에서 최댓값은?", "options": ["4", "3", "0"], "correct_index": 0, "correct_feedback": "정답입니다. 꼭짓점 x=2에서 함수값은 4입니다.", "incorrect_feedback": "양 끝과 꼭짓점의 함수값을 비교하면 가장 큰 값은 4입니다.", "hints": ["꼭짓점은 x=2입니다.", "f(0)=0, f(2)=4, f(3)=3을 비교합니다."]}},
        ]),
        make_page(slug+"-summary", "summary", "핵심 정리", [
            {"type": "summary", "title": "풀이 순서", "text": "닫힌구간과 연속 조건을 확인한다. 정리가 보장하는 것은 최댓값·최솟값의 존재이며, 함수값은 구간 내부의 후보와 양 끝을 비교해 찾는다."},
            {"type": "checklist", "title": "자기 점검", "items": ["함수가 구간 전체에서 연속인지 확인했다.", "구간이 닫힌구간인지 확인했다.", "정리의 존재 결론과 실제 극값 계산을 구별했다."]},
        ]),
    ]
    assert len(pages) == 5 and len({page["id"] for page in pages}) == 5
    assert (2 - 2)**2 == 0 and (-1 - 2)**2 == 9 and (3 - 2)**2 == 1
    assert (-(0**2) + 4*0) == 0 and (-(2**2) + 4*2) == 4 and (-(3**2) + 4*3) == 3
    quiz = pages[3]["blocks"][-1]["activity"]
    assert quiz["options"][quiz["correct_index"]] == "4"
    book = {
        "schema_version": 2,
        "title": "수학Ⅱ · 연속함수의 최댓값·최솟값 보충 Batch5",
        "subtitle": "2015 개정 기준 12수학Ⅱ01-04 · 기존 사이값 정리 사례에 최대·최소 정리 적용 보완",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": [CODE], "tags": ["수학Ⅱ", "2015 개정", "연속함수의 성질 보충", "추가 원고 후보", CODE],
        "chapters": [{"title": "닫힌구간에서의 최댓값과 최솟값", "intro": [f"공식 성취기준 {CODE}에 연결한 보충 후보입니다.", "Batch1의 사이값 정리 예시를 보존하고 최대·최소 정리 적용을 추가합니다."], "pages": pages}],
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
        "content_assertion_status": "continuous_extrema_calculations_checked; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; prior_intermediate_value_theorem_candidate_preserved",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 자료 | 확인한 실제 범위 | 공백 및 보완 |\n|---|---|---|\n| 공식 기준 `{CODE}` | 연속함수의 성질을 이해하고 활용 | 두 정리의 조건과 적용을 모두 검토 |\n| 기존 함수의 연속 원고 | 한 점의 연속 세 조건과 그래프 사례. 학생용 원고가 최대·최소 정리와 연속함수 성질의 확장을 명시적으로 범위 밖으로 둠 | 해당 범위는 기존 원고에 없음 |\n| 미연결기준 Batch1 후보 `{CODE}` | 개념에 최대·최소 정리와 부호가 다른 끝점의 영점 존재를 함께 기재. 예제·퀴즈는 영점 존재(사이값 정리)만 적용 | 최대·최소 정리의 조건과 실제 극값을 찾는 풀이·퀴즈가 없음 |\n| 이번 보충 | 닫힌구간 연속 조건 확인, 꼭짓점·양 끝 비교, 연습·퀴즈 | 최대·최소 정리 적용 예제를 추가하고 기존 사이값 정리 후보는 보존 |\n\n## 보완 범위\n\n5쪽 후보에 조건, 반례 주의, 풀이 예제, native graph, 연습 해설과 quiz를 담았습니다. 교사·독립 수학 검토와 권리 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built 1 module, {len(pages)} pages, 1 graph, 1 quiz; sha256={digest}")


if __name__ == "__main__":
    main()
