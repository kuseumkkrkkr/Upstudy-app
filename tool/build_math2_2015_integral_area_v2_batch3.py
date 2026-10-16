"""Supplement the 2015 Mathematics II area criterion with exact integral examples."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "수학Ⅱ_2015개정_정적분넓이_보충_Batch3_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "수학Ⅱ_2015개정_정적분넓이_보충_Batch3_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
SOURCE_BOOK = MANUSCRIPTS / "수학Ⅱ_2015개정_정적분과넓이_BookData_시범.json"
PRIOR_BATCH = MANUSCRIPTS / "수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
CODE = "12수학Ⅱ03-05"


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    if not re.search(rf"\[{re.escape(CODE)}\]\s*곡선으로 둘러싸인 도형의 넓이를 구할 수 있다", official):
        raise RuntimeError(f"Official criterion text not verified: {CODE}")
    source = json.loads(SOURCE_BOOK.read_text(encoding="utf-8-sig"))
    prior = json.loads(PRIOR_BATCH.read_text(encoding="utf-8-sig"))
    source_text = json.dumps(source, ensure_ascii=False)
    prior_chapters = [chapter for chapter in prior.get("chapters", []) if CODE in json.dumps(chapter, ensure_ascii=False)]
    if len(prior_chapters) != 1:
        raise RuntimeError(f"Expected one prior candidate chapter for {CODE}, found {len(prior_chapters)}")
    prior_text = json.dumps(prior_chapters[0], ensure_ascii=False)
    if "직사각형 합" not in source_text or "y=x" not in source_text:
        raise RuntimeError("Existing tagged-source audit assumptions changed")
    if CODE not in prior_text or "곡선으로 둘러싸인" not in prior_text:
        raise RuntimeError("Prior Batch1 candidate not found for exact comparison")
    # Batch1 only demonstrates rectangle/line areas; no worked integral evaluation.
    if "∫" in prior_text or "[x³/3]" in prior_text:
        raise RuntimeError("Prior candidate now contains an integral worked example; re-audit before supplementing")


def make_page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def main() -> None:
    verify_gap_evidence()
    slug = "m2-area-b3"
    graph = {
        "items": [{"id": "m2-area-parabola", "type": "function", "label": "y=x²", "colorHex": "#2457C5", "enabled": True, "expression": "x^2"}],
        "settings": {"showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False, "viewport": {"left": -0.5, "right": 2.5, "top": 5, "bottom": -1}, "parameters": []},
    }
    pages = [
        make_page(slug+"-open", "opening", "곡선 아래 넓이는 어떻게 계산할까?", [
            {"type": "lead", "title": "핵심 질문", "text": "y=x²와 x축, x=0, x=2로 둘러싸인 넓이를 정적분으로 구해 봅니다."},
            {"type": "thinking", "title": "먼저 판단하기", "text": "이 구간에서 그래프가 x축 위에 있으므로 넓이는 정적분과 같습니다."},
        ]),
        make_page(slug+"-concept", "concept", "정적분으로 넓이 나타내기", [
            {"type": "definition", "title": "위쪽 함수와 아래쪽 함수", "text": "구간 [a,b]에서 f(x)≥g(x)이면 두 그래프와 양 끝 수직선으로 둘러싸인 넓이는 ∫ₐᵇ(f(x)−g(x))dx이다. 그래프가 구간 안에서 교차하면 교점을 경계로 구간을 나누어 넓이를 양수로 더한다."},
            {"type": "formula", "title": "이번 예의 넓이", "text": "y=x²≥0 (0≤x≤2) 이므로 A=∫₀²x²dx=[x³/3]₀²=8/3"},
            {"type": "graph", "title": "포물선과 x축", "text": "그래프는 영역의 경계와 적분 구간을 확인하는 정적 그림이다. 직사각형 개수 조절과 단계별 아래·위 근사는 기존 독립 HTML 시범에 남아 있다.", "graph": graph},
        ]),
        make_page(slug+"-example", "example", "곡선 아래 넓이 예제", [
            {"type": "question", "title": "예제", "text": "y=x², x축, x=0, x=2로 둘러싸인 넓이를 구하라."},
            {"type": "solutionStep", "title": "1단계 · 부호와 경계", "text": "0≤x≤2에서 x²≥0이므로 위쪽 함수는 x², 아래쪽 함수는 0이다."},
            {"type": "solutionStep", "title": "2단계 · 정적분 계산", "text": "A=∫₀²(x²−0)dx=[x³/3]₀²=8/3."},
            {"type": "verification", "title": "확인", "text": "계산한 넓이는 양수이며, y=x² 그래프와 x축 사이 영역의 크기와 일치한다."},
        ]),
        make_page(slug+"-practice", "practice", "연습·해설·퀴즈", [
            {"type": "question", "title": "연습", "text": "y=2x², x축, x=0, x=1로 둘러싸인 넓이를 구하라."},
            {"type": "hint", "title": "힌트", "text": "A=∫₀¹2x²dx로 놓고 원시함수 2x³/3을 양 끝에서 계산한다."},
            {"type": "solutionStep", "title": "해설", "text": "0≤x≤1에서 2x²≥0이다. 따라서 A=∫₀¹2x²dx=[2x³/3]₀¹=2/3."},
            {"type": "answer", "title": "정답", "text": "2/3"},
            {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": "y=2x², x축, x=0, x=1로 둘러싸인 넓이를 구하라.", "options": ["2/3", "1/3", "2"], "correct_index": 0, "correct_feedback": "정답입니다. ∫₀¹2x²dx=2/3입니다.", "incorrect_feedback": "원시함수를 2x³/3으로 구한 뒤 1과 0에서의 값을 빼세요. 정답은 2/3입니다.", "hints": ["구간에서 함수가 x축 위인지 확인합니다.", "A=∫₀¹2x²dx=[2x³/3]₀¹=2/3입니다."]}},
        ]),
        make_page(slug+"-summary", "summary", "핵심 정리", [
            {"type": "summary", "title": "넓이 계산", "text": "경계와 교점을 먼저 찾고, 위쪽 함수에서 아래쪽 함수를 빼 정적분한다. 교차가 있으면 구간을 나누어 양의 넓이로 더한다."},
            {"type": "checklist", "title": "자기 점검", "items": ["적분 구간과 위·아래 경계를 정했다.", "교점에서 구간을 나누어야 하는지 확인했다.", "정적분의 부호와 도형의 넓이를 구분했다."]},
        ]),
    ]
    assert len(pages) == 5 and len({p["id"] for p in pages}) == 5
    assert 2 * 2**3 / 3 == 16 / 3
    assert 2 * 1**3 / 3 == 2 / 3
    assert (2**3 / 3) - (0**3 / 3) == 8 / 3
    assert pages[3]["blocks"][-1]["activity"]["options"][0] == "2/3"
    assert pages[3]["blocks"][-1]["activity"]["correct_index"] == 0
    book = {
        "schema_version": 2,
        "title": "수학Ⅱ · 정적분으로 곡선 넓이 구하기 보충 Batch3",
        "subtitle": "2015 개정 기준 12수학Ⅱ03-05 · 기존 직사각형 근사 시범의 계산 공백 보완",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2015",
        "standard_codes": [CODE],
        "tags": ["수학Ⅱ", "2015 개정", "정적분 넓이 보충", "추가 원고 후보", CODE],
        "chapters": [{"title": "정적분으로 곡선 넓이 구하기", "intro": [f"공식 성취기준 {CODE}에 연결한 보충 후보입니다.", "원시함수로 곡선과 x축 사이 넓이를 계산하며 기존 직사각형 근사 체험과 병행합니다."], "pages": pages}],
        "metadata": {"supplement_only": True, "publication_eligibility": "not_eligible", "teacher_review_status": "pending", "math_review_status": "independent_review_pending", "rights_status": "publication_decision_pending", "existing_html_interaction": "preserved_as_separate_unmodified_asset"},
    }
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": [CODE], "candidate_code_reference_type": "official_2015_appendix8_math_criteria_table",
        "module_count": 1, "page_count": 5, "native_activity_count": 1,
        "native_activity_kinds": ["quiz"], "native_graph_count": 1,
        "content_assertion_status": "integral_evaluation_assertions_passed; independent_review_pending",
        "source_scope_review": "existing_source_and_batch1_candidate_contrast_recorded_in_readme",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; original_interactive_html_preserved_separately",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = f"""# {book['title']}\n\n## 기존 자료 대조\n\n| 자료 | 실제 범위 | 남은 내용 공백 |\n|---|---|---|\n| `수학Ⅱ_2015개정_정적분과넓이_BookData_시범.json` 및 학생 원고·독립 HTML | `y=x` 아래 직사각형 하한·상한 근사, 분할 수 조절, 삼각형 기하 넓이 | 정적분 원시함수로 곡선 영역의 정확한 넓이를 계산하는 풀이가 없음. 자료가 스스로 곡선 사이 넓이와 일반화를 범위 밖으로 선언함 |\n| `수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json` · `{CODE}` | 위·아래 함수 차를 적분한다는 한 줄 개념, 직사각형 및 일차함수 영역 예제·연습 | 적분식 설정과 원시함수 계산을 연결하는 곡선 예제·연습 풀이가 없음 |\n| 공식 2015 기준 `{CODE}` | 곡선으로 둘러싸인 도형의 넓이 계산 | 위 공백을 곡선 `y=x²` 예제와 `y=2x²` 연습으로 보완 |\n\n## 보완 범위\n\n5쪽 후보에 개념, 위·아래 경계, 적분식, 원시함수 계산 예제, 해설, native graph와 퀴즈를 담았습니다. 기존 직사각형 근사 HTML은 수정하거나 대체하지 않습니다. 교사·독립 수학 검토와 권리 결정 전 게시 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n"""
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(f"Built 1 module, {len(pages)} pages, 1 graph, 1 quiz; sha256={digest}")


if __name__ == "__main__":
    main()
