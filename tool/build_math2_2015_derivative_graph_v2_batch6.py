"""Supplement the 2015 Math II function-sketch criterion with a full cubic sketch."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "수학Ⅱ_2015개정_도함수그래프개형_보충_Batch6_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "수학Ⅱ_2015개정_도함수그래프개형_보충_Batch6_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
PRIOR_BATCH = MANUSCRIPTS / "수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
SOURCE_MANUSCRIPT = MANUSCRIPTS / "수학Ⅱ_도함수부호와증감_학생용원고.md"
SOURCE_HTML = MANUSCRIPTS / "수학Ⅱ_도함수부호와증감_체험형_시범.html"
CODE = "12수학Ⅱ02-09"


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    if not re.search(rf"\[{re.escape(CODE)}\]\s*함수의 그래프의 개형을 그릴 수 있다", official):
        raise RuntimeError(f"Official criterion text not verified: {CODE}")
    manuscript = SOURCE_MANUSCRIPT.read_text(encoding="utf-8")
    html = SOURCE_HTML.read_text(encoding="utf-8")
    if "세부 성취기준 코드" not in manuscript or "증가와 감소" not in manuscript:
        raise RuntimeError("Existing derivative-sign manuscript changed; re-audit before supplementing")
    if "f=x=>x*x-4*x+3" not in html:
        raise RuntimeError("Existing derivative-sign HTML changed; re-audit before supplementing")
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
    if "증가·감소" not in application or "x=−1,1" not in application:
        raise RuntimeError("Prior derivative-sign application changed; re-audit before supplementing")
    if "x절편" in application or "그래프 개형" in application:
        raise RuntimeError("Prior candidate now includes full graph-sketch steps; re-audit before supplementing")


def make_page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_gap_evidence()
    slug = "m2-graphsketch-b6"
    graph = {
        "items": [{"id": "cubic-sketch", "type": "function", "label": "f(x)=x³−3x", "colorHex": "#2457C5", "enabled": True, "expression": "x^3-3*x"}],
        "settings": {"showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False, "viewport": {"left": -2.5, "right": 2.5, "top": 7, "bottom": -7}, "parameters": []},
    }
    pages = [
        make_page(slug+"-open", "opening", "도함수 정보로 그래프 전체를 그리려면?", [
            {"type": "lead", "title": "핵심 질문", "text": "증가·감소뿐 아니라 x절편, 극값, 양 끝의 모양을 모으면 함수 그래프 개형을 어떻게 정할 수 있을까?"},
            {"type": "thinking", "title": "먼저 생각하기", "text": "도함수 부호표에 함수값과 x절편 정보를 더해 보세요."},
        ]),
        make_page(slug+"-concept", "concept", "그래프 개형을 위한 정보", [
            {"type": "definition", "title": "확인 순서", "text": "정의역과 절편을 찾고, f′(x)=0이거나 미분 불가능한 점을 조사한다. 도함수 부호로 증가·감소와 극값을 정한 다음, 주요 함수값과 양 끝 거동을 함께 표시해 그래프 개형을 그린다."},
            {"type": "formula", "title": "도함수 부호와 극값", "text": "f′: +→− 이면 극대, f′: −→+ 이면 극소"},
            {"type": "misconception", "title": "주의", "text": "임계점의 x좌표만으로 그래프 개형이 결정되지는 않는다. x절편과 극값의 좌표 및 양 끝 거동도 확인한다."},
        ]),
        make_page(slug+"-example", "example", "삼차함수 개형 예제", [
            {"type": "question", "title": "예제", "text": "f(x)=x³−3x의 x절편, 극값, 증가·감소를 조사해 그래프 개형을 정하라."},
            {"type": "graph", "title": "함수 그래프", "text": "그래프는 풀이에서 찾은 절편과 극값을 시각적으로 확인하는 정적 보조 자료다.", "graph": graph},
            {"type": "solutionStep", "title": "1단계 · 절편", "text": "f(x)=x(x²−3)이므로 x절편은 −√3, 0, √3이다."},
            {"type": "solutionStep", "title": "2단계 · 증감과 극값", "text": "f′(x)=3(x²−1)=3(x−1)(x+1)이다. x=−1,1에서 부호가 바뀌며 증가→감소→증가한다. f(−1)=2는 극댓값, f(1)=−2는 극솟값이다."},
            {"type": "solutionStep", "title": "3단계 · 양 끝과 개형", "text": "최고차항이 x³이므로 x→−∞에서 f(x)→−∞, x→∞에서 f(x)→∞이다. 절편 세 점과 극대·극소를 표시해 왼쪽 아래에서 오른쪽 위로 이어지는 개형을 그린다."},
        ]),
        make_page(slug+"-practice", "practice", "연습·해설·퀴즈", [
            {"type": "question", "title": "연습", "text": "g(x)=x³−3x²의 증가·감소, 극값, x절편을 조사해 개형 정보를 정리하라."},
            {"type": "hint", "title": "힌트", "text": "g′(x)=3x(x−2)로 임계점을 찾고, g(x)=x²(x−3)으로 절편을 찾는다."},
            {"type": "solutionStep", "title": "해설", "text": "g′ 부호는 x<0에서 양수, 0<x<2에서 음수, x>2에서 양수다. x=0에서 극댓값 0, x=2에서 극솟값 −4를 갖는다. x절편은 0과 3이다."},
            {"type": "answer", "title": "정답", "text": "증가 (−∞,0), (2,∞); 감소 (0,2); 극대 (0,0); 극소 (2,−4); x절편 0,3"},
            {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "g(x)=x³−3x²의 [0,2]에서 감소하는 까닭은?", "options": ["g′(x)=3x(x−2)<0", "g′(x)>0", "g(x)가 상수"], "correct_index": 0, "correct_feedback": "정답입니다. 0<x<2에서 x>0, x−2<0이므로 도함수가 음수입니다.", "incorrect_feedback": "g′(x)=3x(x−2)이고 0<x<2에서 두 인자의 부호가 반대입니다.", "hints": ["g′(x)를 인수분해합니다.", "0<x<2에서 각 인자의 부호를 확인합니다."]}},
        ]),
        make_page(slug+"-summary", "summary", "개형 점검", [
            {"type": "summary", "title": "정리", "text": "정의역·절편·임계점·도함수 부호·극값·양 끝 거동을 한데 표시해 그래프 개형을 정한다."},
            {"type": "checklist", "title": "자기 점검", "items": ["x절편을 찾았다.", "도함수 부호로 증감과 극값을 구했다.", "극값의 좌표와 함수값을 표시했다.", "양 끝 거동까지 연결해 개형을 정했다."]},
        ]),
    ]
    assert len(pages) == 5 and len({page["id"] for page in pages}) == 5
    assert all(x**3 - 3*x == x*(x**2 - 3) for x in range(-3, 4))
    assert 3*((-2)**2-1) > 0 and 3*(0**2-1) < 0 and 3*(2**2-1) > 0
    assert (-1)**3 - 3*(-1) == 2 and 1**3 - 3*1 == -2
    assert all(x**3 - 3*x**2 == x**2*(x-3) for x in range(-3, 4))
    assert 3*(-1)*(-3) > 0 and 3*1*(1-2) < 0 and 3*3*(3-2) > 0
    assert (-1)**3 - 3*(-1)**2 == -4 and 0**3 - 3*0**2 == 0
    assert 2**3 - 3*2**2 == -4 and 3**3 - 3*3**2 == 0
    quiz = pages[3]["blocks"][-1]["activity"]
    assert quiz["correct_index"] == 0 and "<0" in quiz["options"][0]
    book = {
        "schema_version": 2,
        "title": "수학Ⅱ · 도함수로 함수 그래프 개형 그리기 보충 Batch6",
        "subtitle": "2015 개정 기준 12수학Ⅱ02-09 · 증감에서 절편·극값·양 끝 거동까지 확장",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": [CODE], "tags": ["수학Ⅱ", "2015 개정", "도함수 그래프 개형 보충", "추가 원고 후보", CODE],
        "chapters": [{"title": "도함수로 함수 그래프 개형 그리기", "intro": [f"공식 성취기준 {CODE}에 연결한 보충 후보입니다.", "기존 도함수 부호 체험과 Batch1 증감 사례를 보존하며 그래프 개형에 필요한 정보를 추가합니다."], "pages": pages}],
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
        "content_assertion_status": "intercepts_derivatives_extrema_and_end_behavior_checked; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; existing_derivative_sign_html_preserved_separately",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 자료 | 실제 범위 | 남은 내용 공백 |\n|---|---|---|\n| 공식 기준 `{CODE}` | 함수의 그래프 개형을 그릴 수 있다 | 실제 그래프 개형을 위한 정보의 결합이 요구됨 |\n| Batch1 `{CODE}` 후보 | 삼차함수 임계점과 도함수 부호표로 증감 개형을 정한다 | x절편, 극값 좌표·함수값, 양 끝 거동을 구해 완성된 그래프 개형으로 연결하지 않음 |\n| 기존 독립 HTML | 이차함수 한 개의 접선 기울기·증감 방향을 slider로 탐색 | 해당 삼차함수의 절편·극값·끝 거동을 그리지 않음 |\n| 이번 보충 | 삼차함수 두 개에 절편·증감·극값·끝 거동을 적용 | 정적 native graph와 quiz 포함. 기존 HTML 조작은 별도 보존 |\n\n## 보완 범위\n\n5쪽 후보에 그래프 개형의 확인 순서, 풀이 예제, 연습 해설, native graph와 quiz를 넣었습니다. 교사·독립 수학 검토와 권리 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built 1 module, {len(pages)} pages, 1 graph, 1 quiz; sha256={digest}")


if __name__ == "__main__":
    main()
