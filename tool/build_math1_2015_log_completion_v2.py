"""Generate resumable 2015 Math I supplements for logarithm/function criteria."""
from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
OUT = MANUSCRIPTS / "수학Ⅰ_2015개정_지수로그누락기준_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "수학Ⅰ_2015개정_지수로그누락기준_Batch2_원고패키지"

UNITS = [
    {
        "code": "12수학Ⅰ01-04",
        "title": "로그의 성질과 계산",
        "tags": ["로그", "로그의 성질", "곱의 로그", "몫의 로그", "거듭제곱의 로그"],
        "concept": "a>0, a≠1이고 M,N>0일 때 log_a(MN)=log_a M+log_a N, log_a(M/N)=log_a M−log_a N, log_a(M^r)=r log_a M입니다. 이 성질은 log_a M=x를 a^x=M으로 바꾸어 지수법칙을 적용하면 얻습니다. 밑과 진수 조건을 먼저 확인합니다.",
        "example_question": "log₂(8·4)와 log₂(8)+log₂(4)가 같은 값을 갖는지 성질과 계산으로 확인하세요.",
        "example_steps": ["곱의 로그 성질에 따르면 log₂(8·4)=log₂8+log₂4입니다.", "8=2³, 4=2²이므로 오른쪽은 3+2=5입니다.", "왼쪽도 8·4=32=2⁵이므로 log₂32=5입니다."],
        "example_answer": "두 식 모두 5",
        "practice_question": "log₃(81/3)+2log₃(3)을 계산하세요.",
        "practice_steps": ["log₃(81/3)=log₃27=3입니다.", "log₃3=1이므로 2log₃3=2입니다.", "두 값을 더하면 5입니다."],
        "practice_answer": "5",
        "source_practice": "log₃(1/27)을 구하고 3의 거듭제곱으로 확인하세요. 정답: 3⁻³=1/27이므로 −3.",
        "quiz_prompt": "log₂(4·8)은 얼마인가요?",
        "options": ["5", "6", "12"],
        "correct_index": 0,
        "feedback": "log₂4+log₂8=2+3=5입니다.",
        "hint": "곱의 로그를 합으로 바꾸거나 4·8을 2의 거듭제곱으로 쓰세요.",
    },
    {
        "code": "12수학Ⅰ01-06",
        "title": "지수함수와 로그함수의 뜻",
        "tags": ["지수함수", "로그함수", "역함수", "함수의 정의역", "함수 그래프"],
        "concept": "a>0, a≠1일 때 y=a^x를 지수함수라 합니다. 정의역은 모든 실수이고 치역은 양수입니다. y=log_a x는 a^y=x를 만족하는 y를 주는 로그함수로, 정의역은 양수이고 치역은 모든 실수입니다. 두 함수는 서로 역함수이므로 그래프는 y=x에 대하여 대칭입니다.",
        "example_question": "f(x)=2^x와 g(x)=log₂x에 대하여 f(3), g(8)을 구하고 두 함수의 관계를 설명하세요.",
        "example_steps": ["f(3)=2³=8입니다.", "g(8)=log₂8=3입니다.", "f(3)=8과 g(8)=3처럼 입력과 출력이 바뀌므로 두 함수는 서로 역함수입니다."],
        "example_answer": "f(3)=8, g(8)=3이며 서로 역함수",
        "practice_question": "f(x)=3^x와 g(x)=log₃x의 정의역과 치역을 각각 쓰세요.",
        "practice_steps": ["3^x는 모든 실수 x에서 정의되고 값은 항상 양수입니다.", "log₃x는 x>0에서 정의되며 결과값은 모든 실수가 될 수 있습니다."],
        "practice_answer": "f: 정의역 R, 치역 (0,∞); g: 정의역 (0,∞), 치역 R",
        "quiz_prompt": "2⁻²의 값과 log₂(1/4)를 고르세요.",
        "options": ["4, 2", "1/4, −2", "−4, 1/2"],
        "correct_index": 1,
        "feedback": "맞아요. 2⁻²=1/4이고 log₂(1/4)=−2입니다.",
        "hint": "음의 지수는 역수 관계를 나타내고, 로그는 그 지수를 되찾습니다.",
        "graph": {
            "items": [
                {"id": "exp-base-2", "type": "function", "label": "y=2^x", "colorHex": "#2457C5", "enabled": True, "expression": "2^x"},
                {"id": "log-base-2", "type": "function", "label": "y=log₂x", "colorHex": "#D35F2E", "enabled": True, "expression": "log(x)/log(2)"},
                {"id": "identity-line", "type": "function", "label": "y=x", "colorHex": "#508A56", "enabled": True, "expression": "x"},
            ],
            "settings": {
                "showAxes": True, "showGrid": True, "lockViewport": True, "degreeMode": False,
                "viewport": {"left": -4, "right": 8, "top": 8, "bottom": -4},
            },
        },
    },
]


def page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def activity(unit: dict, aid: str) -> dict:
    return {
        "type": "activity",
        "activity": {
            "id": aid, "kind": "quiz", "prompt": unit["quiz_prompt"],
            "options": unit["options"], "correct_index": unit["correct_index"],
            "correct_feedback": unit["feedback"], "incorrect_feedback": unit["hint"],
            "hints": [unit["hint"]],
        },
    }


def make_book() -> dict:
    chapters = []
    for unit in UNITS:
        code = unit["code"]
        slug = code.replace("12수학Ⅰ", "m1-").replace("-", "")
        tags = ["수학Ⅰ", "2015 개정", code, "보충 V2 후보", *unit["tags"]]
        concept_blocks = [
            {"type": "definition", "title": "핵심 개념", "text": unit["concept"]},
            {"type": "formula", "title": "공식 기준", "text": code},
            {"type": "misconception", "title": "조건 확인", "text": "밑의 범위와 진수의 양수 조건을 먼저 확인한 뒤 식을 변형하세요."},
        ]
        if "graph" in unit:
            concept_blocks.append({"type": "graph", "title": "두 함수와 y=x 비교", "graph": unit["graph"]})
            concept_blocks.append({
                "type": "activity",
                "activity": {
                    "id": "m10106-log-power-explorer",
                    "kind": "logarithmPowerExplorer",
                    "prompt": "밑과 지수를 바꾸며 a^x와 log_a(a^x)의 관계를 확인하세요.",
                    "hints": ["밑 a=1이면 1^x는 x와 관계없이 1이어서 로그가 지수를 하나로 정할 수 없습니다."],
                    "explorer": {
                        "bases": [0.5, 0.8, 1.2, 1.5, 2.0, 3.0],
                        "initial_base": 2.0,
                        "initial_exponent": 2.0,
                        "min_exponent": -2.0,
                        "max_exponent": 2.0,
                        "step": 0.25,
                    },
                },
            })
        pages = [
            page(slug + "-open", "opening", "질문에서 시작하기", [
                {"type": "lead", "title": "오늘의 질문", "text": unit["example_question"]},
                {"type": "thinking", "title": "먼저 생각하기", "text": "밑과 진수의 조건을 표시하고, 지수식과 로그식 사이의 대응을 예상합니다."},
            ]),
            page(slug + "-concept", "concept", unit["title"], concept_blocks),
            page(slug + "-example", "example", "예제와 풀이", [
                {"type": "question", "title": "예제", "text": unit["example_question"]},
                {"type": "solutionStep", "title": "풀이", "items": unit["example_steps"]},
                {"type": "answer", "title": "답", "text": unit["example_answer"]},
                {"type": "verification", "title": "검산", "text": "변형한 식을 지수와 로그의 정의 또는 원래 조건에 대입해 확인합니다."},
            ]),
            page(slug + "-practice", "practice", "연습하고 확인하기", [
                {"type": "question", "title": "연습", "text": unit["practice_question"]},
                {"type": "hint", "title": "힌트", "text": unit["hint"]},
                {"type": "solutionStep", "title": "해설", "items": unit["practice_steps"]},
                {"type": "answer", "title": "정답", "text": unit["practice_answer"]},
                *([{"type": "question", "title": "독립 연습", "text": unit["source_practice"]}] if unit.get("source_practice") else []),
                activity(unit, slug + "-quiz"),
            ]),
            page(slug + "-summary", "summary", "핵심 정리", [
                {"type": "summary", "title": unit["title"], "text": unit["concept"]},
                {"type": "checklist", "title": "스스로 확인", "text": "정의역·치역 또는 로그 성질의 조건을 설명하고 답을 검산할 수 있나요?"},
            ]),
        ]
        chapters.append({"title": unit["title"], "standard_codes": [code], "tags": tags, "intro": [f"2015 별책 8 기준 {code}의 기존 시범 원고에서 확인되지 않은 요소를 보충하는 후보입니다.", "예시·수치는 직접 작성했습니다."], "pages": pages})
    codes = [unit["code"] for unit in UNITS]
    return {
        "schema_version": 2, "title": "수학Ⅰ 2015 개정 · 지수·로그 보충 2모듈 후보",
        "subtitle": "기존 부분 원고의 로그 성질과 지수·로그함수 정의 보완",
        "category": "concept_textbook", "curriculum_version": "2015",
        "tags": ["수학Ⅰ", "2015 개정", "보충 V2 후보", *codes],
        "standard_codes": codes, "chapters": chapters,
        "metadata": {
            "status": "authored_partial_draft", "publication_eligibility": "not_eligible",
            "rights_status": "pending", "teacher_review_status": "pending",
            "math_review_status": "author_checks_recorded_independent_review_pending",
            "curriculum_review_status": "official_code_text_verified; content_and_product_scope_review_pending",
            "source_basis": "2015 Appendix 8 official achievement-standard statements",
            "native_interaction_status": "base_and_exponent_controls_staged_guides_reset_hint_and_quiz_ported; visual_parity_review_pending",
            "source_interactive_asset": "대수_지수와로그_체험형_시범.html",
            "external_interactive_assets": [{
                "path": "대수_지수와로그_체험형_시범.html",
                "compatibility_status": "base_and_exponent_controls_staged_guides_reset_hint_and_quiz_mapped_to_native_activity",
            }],
            "integration_status": "separate_supplement_not_merged_into_master_book",
        },
    }


def validate() -> None:
    assert math.isclose(math.log(8 * 4, 2), math.log(8, 2) + math.log(4, 2))
    assert math.isclose(math.log(8 * 4, 2), 5)
    assert math.isclose(math.log(81 / 3, 3) + 2 * math.log(3, 3), 5)
    for base in (2, 3, 5):
        for exponent in (-3, -1, 0, 2, 4):
            assert math.isclose(math.log(base**exponent, base), exponent, abs_tol=1e-12)
    assert 2**3 == 8 and math.isclose(math.log(8, 2), 3)
    assert math.isclose(2 ** math.log(7, 2), 7)
    assert all(2**x > 0 for x in range(-10, 11))
    assert all(math.log(x, 2) > -10 for x in (2**-9, 1, 2, 8))
    source = CURRICULUM.read_text(encoding="utf-8")
    official = {
        match.group(1): " ".join(match.group(2).split())
        for match in re.finditer(r"\[\s*(12수학Ⅰ\d{2}-\d{2})\s*\]\s*([^\r\n]+)", source)
    }
    expected = {
        "12수학Ⅰ01-04": "로그의 뜻을 알고, 그 성질을 이해한다.",
        "12수학Ⅰ01-06": "지수함수와 로그함수의 뜻을 안다.",
    }
    for code, text in expected.items():
        if code not in official or text not in official[code]:
            raise RuntimeError(f"Official 2015 criterion text mismatch: {code}")


def main() -> None:
    validate()
    book = make_book()
    serialized = json.dumps(book, ensure_ascii=False, indent=2) + "\n"
    if not OUT.exists() or OUT.read_text(encoding="utf-8") != serialized:
        OUT.write_text(serialized, encoding="utf-8")
    verified = json.loads(OUT.read_text(encoding="utf-8"))
    if verified["standard_codes"] != [unit["code"] for unit in UNITS]:
        raise RuntimeError("BookData standard-code root mismatch")
    for unit, chapter in zip(UNITS, verified["chapters"], strict=True):
        if chapter.get("standard_codes") != [unit["code"]] or len(chapter.get("pages", [])) != 5:
            raise RuntimeError(f"Invalid chapter/code/page structure: {unit['code']}")
        quiz = next(block["activity"] for block in chapter["pages"][3]["blocks"] if block.get("type") == "activity")
        if quiz["kind"] != "quiz" or not 0 <= quiz["correct_index"] < len(quiz["options"]):
            raise RuntimeError(f"Invalid quiz payload: {unit['code']}")
        if "graph" in unit and not any(block.get("graph") for block in chapter["pages"][1]["blocks"]):
            raise RuntimeError("Missing native graph block")
        if unit["code"] == "12수학Ⅰ01-06" and not any(
            block.get("activity", {}).get("kind") == "logarithmPowerExplorer"
            for block in chapter["pages"][1]["blocks"]
        ):
            raise RuntimeError("Missing native source-interaction mapping")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(OUT.read_bytes()).hexdigest().upper()
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": [unit["code"] for unit in UNITS],
        "candidate_code_reference_type": "official_2015_appendix8_pdf_criterion_text",
        "module_count": 2, "page_count": 10, "native_activity_count": 3,
        "native_activity_kinds": ["logarithmPowerExplorer", "quiz"], "native_graph_count": 1,
        "math_arithmetic_check_status": "pass_for_listed_identity_examples_only",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "curriculum_review_status": "official_code_text_verified; full_scope_and_product_alignment_pending",
        "rights_status": "newly_authored_examples; publication_rights_decision_pending",
        "native_interaction_status": "base_and_exponent_controls_staged_guides_reset_hint_and_quiz_mapped_to_native_explorer; visual_parity_review_pending",
        "source_interactive_asset": "대수_지수와로그_체험형_시범.html",
        "publication_eligibility": "not_eligible",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        "# 수학Ⅰ 2015 개정 지수·로그 보충 후보\n\n"
        "공식 기준 `12수학Ⅰ01-04`, `12수학Ⅰ01-06`을 각각 5쪽으로 보강한 후보입니다. "
        "로그 HTML의 밑 선택, 지수 슬라이더, 단계별 보조선, 초기화, 힌트와 확인 퀴즈를 native activity로 옮겼습니다. "
        "함수 관계는 native graph block으로 표현했습니다. 컨트롤 동작은 위젯 테스트를 포함하며 시각 parity, "
        "전체 기준 충족, 상품 귀속, 교사·독립 수학 검토와 권리 승인은 미확인입니다.\n\n"
        f"BookData: [`{OUT.name}`](../{OUT.name})\n",
        encoding="utf-8",
    )
    print("Generated/resumed 2 2015 Math I logarithm/function supplements (10 pages, 2 quizzes, 1 native graph).")


if __name__ == "__main__":
    main()
