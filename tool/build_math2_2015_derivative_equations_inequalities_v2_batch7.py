"""Supplement the 2015 Math II equation/inequality criterion with derivative methods."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "수학Ⅱ_2015개정_미분방정식부등식_보충_Batch7_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "수학Ⅱ_2015개정_미분방정식부등식_보충_Batch7_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
PRIOR_BATCH = MANUSCRIPTS / "수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
CODE = "12수학Ⅱ02-10"


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    if not re.search(rf"\[{re.escape(CODE)}\]\s*방정식과 부등식에 대한 문제를 해결할 수 있다", official):
        raise RuntimeError(f"Official criterion text not verified: {CODE}")
    prior = json.loads(PRIOR_BATCH.read_text(encoding="utf-8-sig"))
    chapters = [chapter for chapter in prior.get("chapters", []) if CODE in json.dumps(chapter, ensure_ascii=False)]
    if len(chapters) != 1:
        raise RuntimeError(f"Expected one prior candidate chapter for {CODE}, found {len(chapters)}")
    pages = chapters[0].get("pages", [])
    example_practice = " ".join(
        block.get("text", "")
        for page in pages if page.get("template") in {"example", "practice"}
        for block in page.get("blocks", [])
    )
    if "x²+1" not in example_practice or "x²+4" not in example_practice:
        raise RuntimeError("Prior candidate examples changed; re-audit before supplementing")
    if "f′" in example_practice:
        raise RuntimeError("Prior candidate now contains derivative-based equation work; re-audit before supplementing")


def make_page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_gap_evidence()
    slug = "m2-eqineq-b7"
    graph = {
        "items": [{"id": "m2-inequality-parabola", "type": "function", "label": "g(x)=x²−4x+3", "colorHex": "#2457C5", "enabled": True, "expression": "x^2-4*x+3"}],
        "settings": {"showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False, "viewport": {"left": -1, "right": 5, "top": 8, "bottom": -2}, "parameters": []},
    }
    pages = [
        make_page(slug+"-open", "opening", "도함수로 방정식과 부등식을 풀 수 있을까?", [
            {"type": "lead", "title": "핵심 질문", "text": "함수의 최솟값은 방정식의 실근 존재와 부등식의 참을 어떻게 알려 줄까?"},
            {"type": "thinking", "title": "먼저 생각하기", "text": "도함수로 가장 낮은 함수값을 알아내면 그래프가 x축과 만나는지 판단할 수 있습니다."},
        ]),
        make_page(slug+"-concept", "concept", "함수의 최솟값과 해의 관계", [
            {"type": "definition", "title": "방정식·부등식에 적용", "text": "방정식 f(x)=0의 실근은 y=f(x) 그래프의 x절편이다. 도함수로 극값과 최솟값을 구하면 근의 존재 여부나 부등식의 부호를 판단할 수 있다. 전체 실수의 최솟값을 주장할 때는 도함수 부호와 양 끝 거동 등 전 구간 근거를 확인한다."},
            {"type": "formula", "title": "완전제곱과 도함수", "text": "f(x)=x²−4x+5=(x−2)²+1, f′(x)=2x−4"},
            {"type": "misconception", "title": "주의", "text": "f′(a)=0이라는 사실만으로 최솟값이나 방정식의 해를 단정하지 않는다. 도함수 부호와 함수값을 확인한다."},
        ]),
        make_page(slug+"-example", "example", "최솟값으로 방정식의 실근 판단", [
            {"type": "question", "title": "예제", "text": "x²−4x+5=0의 실근 개수를 도함수를 이용해 판단하라."},
            {"type": "graph", "title": "함수와 x축", "text": "g(x)=x²−4x+3의 x절편을 그려 부등식 풀이에서 경계와 부호를 확인한다. 방정식 예제 x²−4x+5는 같은 꼭짓점 축을 위로 2만큼 옮긴 함수다.", "graph": graph},
            {"type": "solutionStep", "title": "1단계 · 임계점", "text": "f′(x)=2x−4=0에서 x=2이다. x<2에서 f′<0, x>2에서 f′>0이므로 x=2에서 전역 최솟값을 갖는다."},
            {"type": "solutionStep", "title": "2단계 · 최솟값과 근", "text": "f(2)=2²−4·2+5=1>0이다. 모든 x에서 f(x)≥1이므로 그래프는 x축과 만나지 않는다. 실근은 없다."},
            {"type": "verification", "title": "확인", "text": "완전제곱 f(x)=(x−2)²+1도 모든 x에서 양수임을 확인해 도함수 결과와 일치한다."},
        ]),
        make_page(slug+"-practice", "practice", "도함수로 부등식 해 구하기", [
            {"type": "question", "title": "연습", "text": "x²−4x+3≤0을 도함수와 함수의 영점을 이용해 푸세요."},
            {"type": "hint", "title": "힌트", "text": "도함수로 감소·증가와 최솟값을 찾고, 인수분해로 x절편을 구해 부호를 판단합니다."},
            {"type": "solutionStep", "title": "해설", "text": "g′(x)=2x−4이므로 x=2에서 최솟값 −1을 갖는다. g(x)=(x−1)(x−3)에서 영점은 1, 3이다. 위로 열린 포물선은 두 영점 사이에서 음수이므로 해는 1≤x≤3이다."},
            {"type": "answer", "title": "정답", "text": "[1,3]"},
            {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "x²−4x+3≤0의 해는?", "options": ["1≤x≤3", "x≤1 또는 x≥3", "실수 전체"], "correct_index": 0, "correct_feedback": "정답입니다. 위로 열린 포물선이 두 영점 사이에서 x축 아래에 있습니다.", "incorrect_feedback": "영점 1, 3을 구한 뒤 두 영점 사이에서 함수값이 음수인지 확인합니다.", "hints": ["g(x)=(x−1)(x−3)으로 인수분해합니다.", "g(2)=−1이므로 영점 사이에서 g(x)≤0입니다."]}},
        ]),
        make_page(slug+"-summary", "summary", "풀이 순서", [
            {"type": "summary", "title": "방정식과 부등식", "text": "도함수로 함수의 변화와 극값을 구하고, 방정식은 x절편·최솟값으로 실근을 판단한다. 부등식은 영점과 구간별 부호를 함께 사용한다."},
            {"type": "checklist", "title": "자기 점검", "items": ["임계점에서 도함수 부호가 바뀌는지 확인했다.", "최솟값이 전체 구간에서 최소인지 근거를 댔다.", "부등식은 영점과 구간별 부호로 정리했다."]},
        ]),
    ]
    assert len(pages) == 5 and len({page["id"] for page in pages}) == 5
    assert (2**2 - 4*2 + 5) == 1 and 1 > 0
    assert (2*0 - 4) < 0 and (2*4 - 4) > 0
    assert (1**2 - 4*1 + 3) == 0 and (3**2 - 4*3 + 3) == 0
    assert (2**2 - 4*2 + 3) == -1 and (0**2 - 4*0 + 3) == 3
    quiz = pages[3]["blocks"][-1]["activity"]
    assert quiz["options"][quiz["correct_index"]] == "1≤x≤3"
    book = {
        "schema_version": 2,
        "title": "수학Ⅱ · 도함수로 방정식·부등식 풀기 보충 Batch7",
        "subtitle": "2015 개정 기준 12수학Ⅱ02-10 · 근의 존재와 부등식 해의 구간 판단",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": [CODE], "tags": ["수학Ⅱ", "2015 개정", "방정식 부등식 보충", "추가 원고 후보", CODE],
        "chapters": [{"title": "도함수로 방정식과 부등식 해결하기", "intro": [f"공식 성취기준 {CODE}에 연결한 보충 후보입니다.", "기존의 제곱항 최솟값 예시를 보존하고 방정식 실근 판단과 부등식 해 구간을 추가합니다."], "pages": pages}],
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
        "content_assertion_status": "equation_root_and_inequality_calculations_checked; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; existing_minimum_value_candidate_preserved",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 자료 | 기존 범위 | 확인한 공백 |\n|---|---|---|\n| 공식 기준 `{CODE}` | 방정식과 부등식 문제 해결 | 방정식 실근과 부등식 해를 문제 맥락에서 처리해야 함 |\n| 미연결기준 Batch1 `{CODE}` 후보 | `x²+1` 및 `x²+4`의 최솟값·등호를 직접 제시 | worked example에서 도함수 계산이나 방정식 풀이가 없고, 연습도 같은 형태의 최솟값 하나뿐 |\n| 이번 보충 | `x²−4x+5=0`의 무실근 판정 및 `x²−4x+3≤0` 해 구간 | 도함수 부호·최솟값·영점·부호를 이어서 적용 |\n\n## 보완 범위\n\n5쪽 후보에 개념, 함수 그래프, 단계별 풀이, 연습 해설과 native quiz를 추가했습니다. 계산 assert 및 BookData 왕복 검증은 독립 수학·교사 검토를 대신하지 않습니다. 검토·권리 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built 1 module, {len(pages)} pages, 1 graph, 1 quiz; sha256={digest}")


if __name__ == "__main__":
    main()
