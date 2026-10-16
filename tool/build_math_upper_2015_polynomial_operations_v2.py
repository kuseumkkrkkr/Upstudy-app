"""Generate a focused 2015 Math (Upper) draft for missing polynomial operations."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
OUT = MANUSCRIPTS / "수학상_2015개정_다항식곱셈나눗셈_보충V2_BookData_초안.json"
PACKAGE = MANUSCRIPTS / "수학상_2015개정_다항식곱셈나눗셈_원고패키지"
CODE = "10수학01-01"


def block(kind: str, title: str, text: str, **extra: object) -> dict[str, object]:
    return {"type": kind, "title": title, "text": text, **extra}


def page(identifier: str, template: str, title: str, *blocks: dict[str, object]) -> dict[str, object]:
    return {"id": identifier, "template": template, "title": title, "blocks": list(blocks)}


def make_book() -> dict[str, object]:
    pages = [
        page("poly-ops-open", "opening", "곱셈과 나눗셈도 다항식으로 정리하기",
             block("lead", "기준 연결", f"2015 개정 기준 {CODE}: 다항식의 사칙연산 중 곱셈과 나눗셈을 보완합니다."),
             block("thinking", "오늘의 질문", "(x+2)(x+3)을 전개하고, x²+5x+6을 x+2로 나누면 무엇이 남을까요?")),
        page("poly-ops-concept", "concept", "곱셈은 분배하고 나눗셈은 거꾸로 검산하기",
             block("definition", "다항식의 곱셈", "한 다항식의 각 항에 다른 다항식의 모든 항을 곱한 뒤 동류항을 정리합니다. 예를 들어 (x+a)(x+b)=x²+(a+b)x+ab입니다."),
             block("formula", "곱셈의 확인", "전개한 식을 다시 묶거나 적절한 값을 대입해 원래 곱과 같은지 확인합니다."),
             block("definition", "다항식의 나눗셈", "나누는 다항식이 0이 아닌 범위에서 몫과 나머지를 구합니다. 피제수=제수×몫+나머지로 결과를 검산하며, 나머지의 차수는 제수의 차수보다 작습니다."),
             block("misconception", "부호와 나머지", "곱셈에서 각 항을 빠뜨리지 않고, 나눗셈에서는 제수×몫만으로 끝났는지 나머지까지 확인합니다.")),
        page("poly-ops-example", "example", "곱셈을 전개하고 나눗셈으로 되돌리기",
             block("question", "예제", "(x+2)(x+3)을 전개하고 x²+5x+6을 x+2로 나누세요."),
             block("solutionStep", "곱셈", "분배법칙으로 x·x+x·3+2·x+2·3=x²+3x+2x+6입니다."),
             block("answer", "곱의 정리", "동류항을 합치면 x²+5x+6입니다."),
             block("solutionStep", "나눗셈 검산", "x²+5x+6=(x+2)(x+3)이므로 x+2로 나눈 몫은 x+3, 나머지는 0입니다.")),
        page("poly-ops-practice", "practice", "나머지가 있는 나눗셈 확인하기",
             block("question", "연습", "x²+2x+5를 x+1로 나눈 몫과 나머지를 구하세요."),
             block("hint", "힌트", "x²+2x+5=(x+1)(x+1)+4로 다시 써 보세요."),
             block("solutionStep", "풀이", "(x+1)(x+1)=x²+2x+1이므로 피제수와의 차는 4입니다."),
             block("answer", "정답", "몫은 x+1, 나머지는 4입니다.")),
        page("poly-ops-quiz", "experiment", "분배법칙으로 곱 계산하기",
             block("lead", "직접 확인", "두 항씩 곱하고 동류항을 모아 보세요."),
             {"type": "activity", "activity": {
                 "id": "poly-ops-product-quiz", "kind": "quiz",
                 "prompt": "(x+2)(x+3)을 전개했을 때 x의 계수는?",
                 "options": ["5", "6", "2"], "correct_index": 0,
                 "correct_feedback": "x·3과 2·x를 더하면 x의 계수는 5입니다.",
                 "incorrect_feedback": "교차항 x·3과 2·x를 모두 적어 보세요.",
                 "hints": ["네 항 x·x, x·3, 2·x, 2·3을 씁니다.", "x항은 3x와 2x입니다."],
             }}),
        page("poly-ops-summary", "summary", "곱한 뒤 나누어 검산하기",
             block("summary", "핵심 정리", "곱셈은 분배법칙을 빠짐없이 적용하고 동류항을 정리합니다. 나눗셈은 피제수=제수×몫+나머지로 확인합니다."),
             block("checklist", "스스로 점검", "곱셈에서 모든 항의 곱을 썼나요? 나눗셈에서 몫과 나머지를 함께 검산했나요?")),
    ]
    return {
        "schema_version": 2,
        "title": "수학(상) · 다항식의 곱셈과 나눗셈 보충 후보",
        "subtitle": "2015 개정 다항식 사칙연산 중 기존 본문에서 확인되지 않은 범위",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2015",
        "tags": ["수학(상)", "2015 개정", "다항식", "곱셈", "나눗셈", CODE, "보충 후보"],
        "standard_codes": [CODE],
        "metadata": {"publication_eligibility": "not_eligible", "rights_status": "pending",
            "teacher_review_status": "pending", "math_review_status": "author_checks_recorded_independent_review_pending"},
        "chapters": [{"title": "다항식의 곱셈과 나눗셈", "standard_codes": [CODE], "pages": pages}],
    }


def validate(book: dict[str, object]) -> None:
    text = CURRICULUM.read_text(encoding="utf-8")
    match = re.search(rf"\[{re.escape(CODE)}\]\s*([^\r\n]+)", text)
    assert match and "다항식의 사칙연산" in match.group(1)
    assert len(book["chapters"]) == 1
    chapter = book["chapters"][0]
    assert chapter["standard_codes"] == [CODE] and len(chapter["pages"]) == 6
    assert len({p["id"] for p in chapter["pages"]}) == 6
    product = [0, 0, 0]
    for i, left in enumerate((2, 1)):
        for j, right in enumerate((3, 1)):
            product[i + j] += left * right
    assert product == [6, 5, 1]  # (x+2)(x+3)=x²+5x+6
    quotient_product = [0, 0, 0]
    for i, left in enumerate((1, 1)):
        for j, right in enumerate((1, 1)):
            quotient_product[i + j] += left * right
    quotient_product[0] += 4
    assert quotient_product == [5, 2, 1]  # x²+2x+5=(x+1)²+4
    activities = [b["activity"] for p in chapter["pages"] for b in p["blocks"] if b.get("type") == "activity"]
    assert len(activities) == 1 and activities[0]["correct_index"] == 0


def main() -> None:
    book = make_book()
    validate(book)
    MANUSCRIPTS.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    (PACKAGE / "README.md").write_text(
        f"# 2015 수학(상) 다항식 곱셈·나눗셈 보충 후보\n\n원본: [`{OUT.name}`](../{OUT.name})\n\n"
        "기존 2015 통합본의 해당 장은 덧셈·뺄셈에 한정됨을 확인해 미확인 곱셈·나눗셈만 보충한다. "
        "독립 수학·교사·권리 검토가 끝나기 전 출판하지 않는다.\n",
        encoding="utf-8",
    )
    digest = hashlib.sha256(OUT.read_bytes()).hexdigest()
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": [CODE], "candidate_code_reference_type": "official_2015_appendix8_criterion",
        "module_count": 1, "page_count": 6, "native_activity_count": 1, "native_activity_kinds": ["quiz"],
        "curriculum_review_status": "pending", "math_review_status": "pending_independent_review",
        "teacher_review_status": "pending", "rights_status": "pending",
        "publication_eligibility": "not_eligible", "integration_status": "supplement_not_merged",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated 1 2015 Math (Upper) polynomial-operations supplement ({len(book['chapters'][0]['pages'])} pages, 1 quiz).")


if __name__ == "__main__":
    main()
