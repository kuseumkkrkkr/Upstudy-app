"""Add a non-duplicated tangent/secant classification module for 2015 Geometry."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "기하_2015개정_이차곡선접선_보충_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "기하_2015개정_이차곡선접선_보충_Batch2_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
PRIOR = MANUSCRIPTS / "기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json"
CODE = "12기하01-04"


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    expected = "이차곡선과 직선의 위치 관계를 이해하고, 접선의 방정식을 구할 수 있다"
    if not re.search(rf"\[{re.escape(CODE)}\]\s*{re.escape(expected)}", official):
        raise RuntimeError(f"Official criterion not verified: {CODE}")
    prior = json.loads(PRIOR.read_text(encoding="utf-8-sig"))
    chapters = [chapter for chapter in prior.get("chapters", []) if chapter.get("title") == "이차곡선과 직선의 접선"]
    if len(chapters) != 1:
        raise RuntimeError(f"Expected one prior tangent chapter, found {len(chapters)}")
    pages = chapters[0].get("pages", [])
    example = next((page for page in pages if page.get("template") == "example"), None)
    practice = next((page for page in pages if page.get("template") == "practice"), None)
    example_q = " ".join(block.get("text", "") for block in (example or {}).get("blocks", []) if block.get("type") == "question")
    practice_q = " ".join(block.get("text", "") for block in (practice or {}).get("blocks", []) if block.get("type") == "question")
    if example_q != practice_q or "(4,4)" not in example_q or "ty=x+pt²" not in json.dumps(chapters[0], ensure_ascii=False):
        raise RuntimeError("Prior tangent candidate changed; re-audit before supplementing")


def page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_gap_evidence()
    slug = "geo15-conic-tangent-b2"
    graph = {
        "items": [
            {"id": "geo-conic-upper", "type": "function", "label": "y=2√x", "colorHex": "#2457C5", "enabled": True, "expression": "2*sqrt(x)"},
            {"id": "geo-conic-lower", "type": "function", "label": "y=−2√x", "colorHex": "#6295F2", "enabled": True, "expression": "-2*sqrt(x)"},
            {"id": "geo-conic-tangent", "type": "function", "label": "y=x+1", "colorHex": "#D94841", "enabled": True, "expression": "x+1"},
        ],
        "settings": {"showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False, "viewport": {"left": -1, "right": 5, "top": 5, "bottom": -5}, "parameters": []},
    }
    pages = [
        page(slug+"-open", "opening", "한 점에서 만나는 직선은 모두 접선일까?", [
            {"type": "lead", "title": "핵심 질문", "text": "교점의 개수와 중근 조건으로 접선과 할선을 구별할 수 있을까?"},
            {"type": "thinking", "title": "먼저 생각하기", "text": "직선의 식을 곡선의 방정식에 대입하면 교점의 x좌표가 이차방정식의 근이 됩니다."},
        ]),
        page(slug+"-concept", "concept", "판별식으로 접선 판별하기", [
            {"type": "definition", "title": "교점과 판별식", "text": "직선과 이차곡선의 방정식을 연립해 한 변수의 이차방정식으로 만든다. 실근이 두 개면 두 점에서 만나고, 판별식이 0이면 중근을 가져 접한다. 실근이 없으면 만나지 않는다."},
            {"type": "formula", "title": "포물선의 점에서 접선", "text": "y²=4px의 점 (pt², 2pt)에서 접선은 ty=x+pt²이다."},
            {"type": "misconception", "title": "한 교점과 중근", "text": "계산 과정에서 제곱인수 또는 판별식 0을 확인해야 한다. 그림에서 한 점처럼 보이는 것만으로 접선을 판단하지 않는다."},
        ]),
        page(slug+"-example", "example", "접선 식을 연립으로 확인하기", [
            {"type": "question", "title": "예제", "text": "포물선 y²=4x와 직선 y=x+1의 위치 관계를 판별하고 접점을 구하세요."},
            {"type": "graph", "title": "포물선과 후보 직선", "text": "y=±2√x가 y²=4x의 두 가지를 나타내고, y=x+1은 접선 후보이다.", "graph": graph},
            {"type": "solutionStep", "title": "1단계 · 연립", "text": "y=x+1을 y²=4x에 대입하면 (x+1)²=4x, 즉 (x−1)²=0이다."},
            {"type": "solutionStep", "title": "2단계 · 접점", "text": "중근은 x=1이고 y=2이다. 판별식이 0이므로 직선은 포물선에 접하며 접점은 (1,2)이다."},
            {"type": "verification", "title": "공식으로 확인", "text": "p=1, t=1이면 점은 (1,2), 접선은 y=x+1이다. 연립 결과와 일치한다."},
        ]),
        page(slug+"-practice", "practice", "할선과 교점이 없는 직선 구별하기", [
            {"type": "question", "title": "연습", "text": "y²=4x에 대해 직선 y=x와 y=2x+1이 각각 몇 점에서 만나는지 판별하세요."},
            {"type": "hint", "title": "힌트", "text": "각 직선의 y를 포물선 식에 대입해 정리하고, 서로 다른 실근의 개수를 셉니다."},
            {"type": "solutionStep", "title": "해설 · y=x", "text": "x²=4x이므로 x(x−4)=0이다. 교점은 (0,0), (4,4)의 두 점이므로 할선이다."},
            {"type": "solutionStep", "title": "해설 · y=2x+1", "text": "(2x+1)²=4x를 정리하면 4x²+1=0이다. 실근이 없으므로 포물선과 만나지 않는다."},
            {"type": "answer", "title": "정답", "text": "y=x: 두 점에서 만남(할선); y=2x+1: 만나지 않음"},
            {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "y²=4x에 직선 y=x+1을 대입했을 때 판별식과 위치 관계는?", "options": ["판별식 0, 접한다", "서로 다른 두 실근, 두 점에서 만난다", "실근 없음, 만나지 않는다"], "correct_index": 0, "correct_feedback": "정답입니다. (x−1)²=0이므로 중근이며 한 점에서 접합니다.", "incorrect_feedback": "y=x+1을 대입하면 (x−1)²=0이 되어 중근을 갖습니다.", "hints": ["(x+1)²=4x를 전개해 이차방정식으로 정리하세요.", "정리하면 (x−1)²=0입니다."]}},
        ]),
        page(slug+"-summary", "summary", "위치 관계 판별 순서", [
            {"type": "summary", "title": "세 가지 경우", "text": "직선을 곡선에 대입해 교점 방정식을 만든다. 두 실근이면 할선, 중근이면 접선, 실근이 없으면 만나지 않는다."},
            {"type": "checklist", "title": "자기 점검", "items": ["직선을 곡선 방정식에 대입했다.", "판별식 또는 실근 개수로 위치 관계를 구분했다.", "접점 좌표를 원래 식에 대입해 확인했다."]},
        ]),
    ]
    assert len(pages) == 5 and len({p["id"] for p in pages}) == 5
    assert (1+1)**2 - 4*1 == 0
    assert [x for x in range(-5, 6) if (x+1)**2 == 4*x] == [1]
    assert [x for x in range(-5, 6) if x*x == 4*x] == [0, 4]
    assert -16 < 0
    quiz = pages[3]["blocks"][-1]["activity"]
    assert quiz["options"][quiz["correct_index"]] == "판별식 0, 접한다"

    book = {
        "schema_version": 2, "title": "기하 · 이차곡선과 직선의 위치 관계 보충 Batch2",
        "subtitle": f"2015 개정 기준 {CODE} · 접선·할선·교점 없음 판별",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": [CODE], "tags": ["기하", "2015 개정", "이차곡선 접선 보충", "추가 원고 후보", CODE],
        "chapters": [{"title": "이차곡선과 직선의 위치 관계", "intro": [f"공식 기준 {CODE}에 연결한 보충 후보입니다.", "기존 중근 접선 계산은 유지하고, 교점 두 개·없음과 대조합니다."], "pages": pages}],
        "metadata": {"supplement_only": True, "publication_eligibility": "not_eligible", "teacher_review_status": "pending", "math_review_status": "independent_review_pending", "rights_status": "publication_decision_pending"},
    }
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest, "candidate_code_references": [CODE],
        "candidate_code_reference_type": "official_2015_appendix8_math_criteria_table",
        "module_count": 1, "page_count": 5, "native_activity_count": 1,
        "native_activity_kinds": ["quiz"], "native_graph_count": 1,
        "content_assertion_status": "intersection_and_discriminant_calculations_checked; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; prior_tangent_example_preserved",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 자료 | 기존 범위 | 확인한 공백 |\n|---|---|---|\n| 공식 기준 `{CODE}` | 이차곡선·직선의 위치 관계와 접선 방정식 | 중근 조건 외에 교점 수로 위치 관계 판별 필요 |\n| 기존 Batch1 후보 | `y²=4x`의 `(4,4)` 접선 예제 | 예제와 연습 문제가 동일하고 연습의 독립 풀이가 없음 |\n| 이번 보충 | 접선 `y=x+1`, 할선 `y=x`, 교점 없음 `y=2x+1` | 세 위치 관계를 대입·실근으로 비교 |\n\n5쪽 후보에 그래프, 단계별 풀이, 비교 연습과 native quiz를 담았습니다. 산술 검증은 독립 수학·교사 검토를 대신하지 않습니다. 권리·검토 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built 1 module, {len(pages)} pages, 1 graph, 1 quiz; sha256={digest}")


if __name__ == "__main__":
    main()
