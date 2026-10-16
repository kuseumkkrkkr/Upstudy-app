"""Supplement 2015 Geometry vector line/circle practice with a real circle problem."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "기하_2015개정_벡터직선원_보충_Batch3_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "기하_2015개정_벡터직선원_보충_Batch3_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
PRIOR = MANUSCRIPTS / "기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json"
CODE = "12기하02-05"


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    expected = "좌표평면에서 벡터를 이용하여 직선과 원의 방정식을 구할 수 있다"
    if not re.search(rf"\[{re.escape(CODE)}\]\s*{re.escape(expected)}", official):
        raise RuntimeError(f"Official criterion not verified: {CODE}")
    prior = json.loads(PRIOR.read_text(encoding="utf-8-sig"))
    chapters = [chapter for chapter in prior.get("chapters", []) if chapter.get("title") == "벡터를 이용한 직선과 원의 방정식"]
    if len(chapters) != 1:
        raise RuntimeError(f"Expected one prior line/circle chapter, found {len(chapters)}")
    pages = chapters[0].get("pages", [])
    example = next((page for page in pages if page.get("template") == "example"), None)
    practice = next((page for page in pages if page.get("template") == "practice"), None)
    q = lambda p: " ".join(block.get("text", "") for block in (p or {}).get("blocks", []) if block.get("type") == "question")
    if not q(example) or q(example) != q(practice) or "방향벡터" not in q(example):
        raise RuntimeError("Prior line example/practice changed; re-audit before supplementing")
    if "원" in q(practice):
        raise RuntimeError("Prior practice now contains a circle construction; re-audit before supplementing")


def page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_gap_evidence()
    slug = "geo15-vector-line-circle-b3"
    graph = {
        "items": [
            {"id": "geo-circle-upper", "type": "function", "label": "y=1+√(25−(x+2)²)", "colorHex": "#2457C5", "enabled": True, "expression": "1+sqrt(25-(x+2)^2)"},
            {"id": "geo-circle-lower", "type": "function", "label": "y=1−√(25−(x+2)²)", "colorHex": "#6295F2", "enabled": True, "expression": "1-sqrt(25-(x+2)^2)"},
        ],
        "settings": {"showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False, "viewport": {"left": -8, "right": 4, "top": 7, "bottom": -5}, "parameters": []},
    }
    pages = [
        page(slug+"-open", "opening", "벡터는 직선과 원을 어떻게 나타낼까?", [
            {"type": "lead", "title": "핵심 질문", "text": "방향벡터는 직선을, 중심에서 원 위 점까지의 벡터는 원의 반지름을 어떻게 정할까?"},
            {"type": "thinking", "title": "먼저 생각하기", "text": "점의 위치벡터와 방향벡터를 구분하고, 원 위 점과 중심의 차벡터 길이를 구해 봅니다."},
        ]),
        page(slug+"-concept", "concept", "점·방향벡터와 중심·반지름", [
            {"type": "definition", "title": "벡터로 쓰는 두 방정식", "text": "점 A=(a,b)를 지나고 영벡터가 아닌 방향벡터 d=(u,v)를 갖는 직선은 r=a+td로 나타낸다. 중심 C=(h,k), 반지름 R인 원은 |r−c|=R이며 좌표식은 (x−h)²+(y−k)²=R²이다."},
            {"type": "formula", "title": "반지름은 거리벡터의 크기", "text": "P=(p₁,p₂)가 원 위에 있으면 중심에서 P까지의 거리 R=|CP|=√((p₁−h)²+(p₂−k)²)이다."},
            {"type": "misconception", "title": "점과 벡터의 역할", "text": "직선의 방향벡터를 지나는 점으로 오해하지 않는다. 원은 중심에서 원 위 점으로 향하는 벡터의 길이가 반지름이다."},
        ]),
        page(slug+"-example", "example", "방향벡터로 직선 쓰기", [
            {"type": "question", "title": "예제", "text": "점 A=(−1,2)를 지나고 방향벡터 d=(3,−1)인 직선의 벡터방정식과 매개방정식을 구하세요."},
            {"type": "solutionStep", "title": "1단계 · 위치벡터", "text": "A의 위치벡터는 a=(−1,2)이다. 직선 위 점의 위치벡터는 r=a+td로 나타낸다."},
            {"type": "solutionStep", "title": "2단계 · 성분으로 전개", "text": "r=(−1,2)+t(3,−1)이므로 x=−1+3t, y=2−t이다. t=0에서 A를 지나고 t가 바뀌면 d 방향으로 이동한다."},
            {"type": "verification", "title": "확인", "text": "t=0이면 (−1,2), t=1이면 (2,1)이다. 두 점의 차는 (3,−1)로 주어진 방향벡터와 같다."},
        ]),
        page(slug+"-practice", "practice", "원 위의 점으로 원의 방정식 구하기", [
            {"type": "question", "title": "연습", "text": "중심이 C=(−2,1)이고 원 위의 점 P=(1,5)를 지나는 원의 방정식을 구하세요."},
            {"type": "hint", "title": "힌트", "text": "반지름 벡터 CP를 구하고 그 길이를 피타고라스 정리로 계산합니다."},
            {"type": "solutionStep", "title": "1단계 · 반지름", "text": "중심에서 P까지의 벡터 CP=(1−(−2),5−1)=(3,4)이므로 R=√(3²+4²)=5이다."},
            {"type": "solutionStep", "title": "2단계 · 원의 식", "text": "중심 (−2,1), 반지름 5를 대입하면 (x+2)²+(y−1)²=25이다."},
            {"type": "graph", "title": "원의 두 함수 가지", "text": "원의 위쪽과 아래쪽을 각각 y=1±√(25−(x+2)²)로 그립니다. x=−2에서는 원 위의 점 (−2,6), (−2,−4)가 나타나므로 중심 자체는 원 위에 있지 않음을 확인합니다.", "graph": graph},
            {"type": "answer", "title": "정답", "text": "(x+2)²+(y−1)²=25"},
            {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "중심 (−2,1), 원 위의 점 (1,5)를 지나는 원의 반지름은?", "options": ["5", "√7", "25"], "correct_index": 0, "correct_feedback": "정답입니다. 중심에서 점까지의 벡터는 (3,4)이므로 길이는 5입니다.", "incorrect_feedback": "점에서 중심을 뺀 벡터는 (3,4)이며 길이는 √(3²+4²)입니다.", "hints": ["중심에서 원 위 점을 빼서 반지름 벡터를 구하세요.", "(3,4)의 길이는 5입니다."]}},
        ]),
        page(slug+"-summary", "summary", "벡터식 만들기", [
            {"type": "summary", "title": "직선과 원", "text": "직선은 지나는 점과 방향벡터로 r=a+td를 쓴다. 원은 중심과 중심에서 원 위 점까지의 거리로 반지름을 구해 |r−c|=R 또는 좌표식을 쓴다."},
            {"type": "checklist", "title": "자기 점검", "items": ["직선의 점과 방향벡터를 분리했다.", "원 위 점과 중심의 차벡터를 계산했다.", "반지름을 제곱해 원의 좌표식에 넣었다."]},
        ]),
    ]
    assert len(pages) == 5 and len({p["id"] for p in pages}) == 5
    assert (1-(-2))**2 + (5-1)**2 == 25
    assert (-2+2)**2 + (1-1)**2 == 0
    assert (3-(-2))**2 + (1-1)**2 == 25
    quiz = pages[3]["blocks"][-1]["activity"]
    assert quiz["options"][quiz["correct_index"]] == "5"

    book = {
        "schema_version": 2, "title": "기하 · 벡터로 직선과 원의 방정식 만들기 보충 Batch3",
        "subtitle": f"2015 개정 기준 {CODE} · 방향벡터 직선과 중심·반지름 원",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": [CODE], "tags": ["기하", "2015 개정", "벡터 직선 원 보충", "추가 원고 후보", CODE],
        "chapters": [{"title": "벡터로 직선과 원 만들기", "intro": [f"공식 기준 {CODE}에 연결한 보충 후보입니다.", "기존 직선 예제·연습의 반복을 보완해 원 방정식의 독립 적용을 추가합니다."], "pages": pages}],
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
        "content_assertion_status": "vector_line_and_circle_distance_calculations_checked; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; prior_line_example_preserved",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 자료 | 기존 범위 | 확인한 공백 |\n|---|---|---|\n| 공식 기준 `{CODE}` | 벡터로 직선과 원의 방정식 구하기 | 두 방정식 유형의 독립 적용 필요 |\n| 기존 Batch1 후보 | 방향벡터 직선 예제와 중심·반지름 공식 | 연습이 예제 직선 문제를 반복하고 원 구하기 연습이 없음 |\n| 이번 보충 | 방향벡터 직선 풀이와 `C=(-2,1)`, `P=(1,5)`로 원 구하기 | 점·벡터·거리·좌표식을 연결하고 원 그래프/퀴즈 포함 |\n\n산술 검증은 독립 수학·교사 검토를 대신하지 않습니다. 검토·권리 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built 1 module, {len(pages)} pages, 1 graph, 1 quiz; sha256={digest}")


if __name__ == "__main__":
    main()
