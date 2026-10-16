"""Draft the three 2022 Algebra sequence standards backed by recovered HWP equations."""
from __future__ import annotations

import json
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
HWP = ROOT / "work/official-curriculum/2022_appendix8_math.hwp"
OUT = MANUSCRIPTS / "대수_2022개정_EqEdit복구기준_수열_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "대수_2022개정_EqEdit복구기준_수열_Batch2_원고패키지"

SPECS = [
    {
        "code": "12대수03-03", "title": "등비수열의 일반항과 합",
        "scripts": {"n"},
        "concept": "첫째항이 a₁이고 공비가 r인 등비수열은 aₙ=a₁rⁿ⁻¹이다. r≠1이면 첫째항부터 n항까지의 합은 Sₙ=a₁(1−rⁿ)/(1−r)이고, r=1이면 Sₙ=na₁이다.",
        "example": "2, 6, 18, …에서 a₁=2, r=3이므로 a₆=2·3⁵=486이다. 첫 4항의 합은 2+6+18+54=80이며 공식으로도 2(1−3⁴)/(1−3)=80이다.",
        "practice": "첫째항 5, 공비 2인 등비수열의 제5항을 구하세요.", "answer": "a₅=5·2⁴=80입니다.",
        "prompt": "첫째항 2, 공비 3인 등비수열의 첫 4항의 합은?", "options": ["80", "78", "162"], "correct": 0,
        "hint": "첫째항과 공비를 등비수열의 합 공식에 대입합니다.",
    },
    {
        "code": "12대수03-04", "title": "합의 기호 Σ",
        "scripts": {"SMALLSUM"},
        "concept": "기호 Σ는 정해진 시작값부터 끝값까지 항을 더한다는 뜻이다. 예를 들어 Σ(k=1부터 4까지) 2k는 2+4+6+8을 나타낸다. 합의 선형성에 따라 Σ(caₖ±bₖ)=cΣaₖ±Σbₖ이며, 합의 범위와 항의 대응을 확인하고 적용한다.",
        "example": "Σ(k=1부터 3까지)(2k+1)=2Σ(k=1부터 3까지)k+Σ(k=1부터 3까지)1=2·6+3=15이다. 항을 직접 나열해도 3+5+7=15로 확인된다.",
        "practice": "Σ(k=1부터 4까지) 3k의 값을 구하세요.", "answer": "3+6+9+12=30입니다.",
        "prompt": "Σ(k=1부터 3까지)(2k+1)의 값은?", "options": ["15", "12", "9"], "correct": 0,
        "hint": "k에 1, 2, 3을 차례로 대입해 더합니다.",
    },
    {
        "code": "12대수03-05", "title": "여러 수열의 합",
        "scripts": {"n", "sum _{k=1} ^{n} k", "sum _{k=1} ^{n} k  ^{2}", "sum _{k=1} ^{n} `k  ^{3} `"},
        "concept": "자연수 거듭제곱의 합은 Σk=n(n+1)/2, Σk²=n(n+1)(2n+1)/6, Σk³=[n(n+1)/2]²이다. 합의 선형성을 이용해 다항식 항을 분리하고 각 합 공식에 대응시킨다. n은 양의 정수여야 한다.",
        "example": "첫 5개 자연수 제곱의 합은 1²+2²+3²+4²+5²=5·6·11/6=55이다. 첫 5개 세제곱의 합은 (5·6/2)²=225이다. 또 Σ(k=1부터 4까지)(3k²−2k)=3·30−2·10=70으로 계산한다.",
        "practice": "1³+2³+…+10³의 값을 구하세요.", "answer": "[10·11/2]²=55²=3025입니다.",
        "prompt": "1²+2²+3²+4²의 값은?", "options": ["30", "20", "16"], "correct": 0,
        "hint": "제곱합 공식에 n=4를 대입합니다.",
    },
]


def activity(spec: dict, slug: str) -> dict:
    return {"type": "activity", "activity": {"id": slug + "-quiz", "kind": "quiz", "prompt": spec["prompt"], "options": spec["options"], "correct_index": spec["correct"], "correct_feedback": "정답입니다. 수열의 항이나 합을 확인했습니다.", "incorrect_feedback": "항의 번호와 공식의 적용 범위를 다시 확인하세요.", "hints": [spec["hint"]]}}


def main() -> None:
    official_data = json.loads(STANDARDS.read_text(encoding="utf-8"))
    official = {row["code"]: row for row in official_data["standards"]}
    if not HWP.is_file():
        raise FileNotFoundError(HWP)
    for spec in SPECS:
        row = official.get(spec["code"])
        if not row or not spec["scripts"].issubset(set(row.get("equation_scripts", []))):
            raise RuntimeError(f"Missing official HWP EqEdit evidence for {spec['code']}")

    chapters = []
    all_ids: set[str] = set()
    for spec in SPECS:
        code = spec["code"]
        slug = code.replace("12대수", "algseq").replace("-", "")
        pages = [
            {"id": slug + "-open", "template": "opening", "title": "질문에서 시작하기", "blocks": [{"type": "lead", "title": "핵심 질문", "text": spec["title"]}, {"type": "thinking", "title": "먼저 예측하기", "text": "항의 규칙 또는 합의 범위를 말한 뒤 작은 값으로 확인합니다."}]},
            {"id": slug + "-concept", "template": "concept", "title": "개념과 조건", "blocks": [{"type": "definition", "title": spec["title"], "text": spec["concept"]}, {"type": "formula", "title": "공식 HWP EqEdit 원문 스크립트", "text": "; ".join(sorted(spec["scripts"]))}, {"type": "misconception", "title": "조건 확인", "text": "항 번호, 합의 시작·끝 범위, 공식의 조건을 확인합니다."}]},
            {"id": slug + "-example", "template": "example", "title": "예제와 확인", "blocks": [{"type": "question", "title": "예제", "text": spec["practice"]}, {"type": "solutionStep", "title": "풀이와 추가 예", "text": spec["example"]}, {"type": "verification", "title": "검산", "text": "작은 경우는 직접 더하거나 항을 대입해 결과를 확인합니다."}]},
            {"id": slug + "-practice", "template": "practice", "title": "연습과 해설", "blocks": [{"type": "question", "title": "연습", "text": spec["practice"]}, {"type": "hint", "title": "힌트", "text": spec["hint"]}, {"type": "solutionStep", "title": "해설", "text": spec["answer"]}, {"type": "answer", "title": "정답", "text": spec["answer"]}, activity(spec, slug)]},
            {"id": slug + "-summary", "template": "summary", "title": "핵심 정리", "blocks": [{"type": "summary", "title": "기억할 점", "text": spec["concept"]}, {"type": "checklist", "title": "스스로 확인", "text": "항의 규칙과 공식의 조건을 설명할 수 있나요?"}]},
        ]
        for page in pages:
            if page["id"] in all_ids:
                raise RuntimeError(f"Duplicate page ID {page['id']}")
            all_ids.add(page["id"])
        chapters.append({"title": spec["title"], "candidate_standard_codes": [code], "intro": [f"2022 개정 대수 공식 기준 {code}와 연결한 원고 후보입니다.", "HWP 원본에서 복구한 EqEdit 스크립트를 확인했습니다. 설명·예시·문항은 새로 작성했습니다."], "pages": pages})

    assert 2 * 2**5 == 64 and sum(2 * 2**k for k in range(5)) == 62
    assert 2 * (1 - 3**4) / (1 - 3) == 80
    assert sum(2 * k for k in range(1, 5)) == 20
    assert sum(2 * k + 1 for k in range(1, 4)) == 15
    assert 3 * sum(k * k for k in range(1, 5)) - 2 * sum(k for k in range(1, 5)) == sum(3 * k * k - 2 * k for k in range(1, 5)) == 70
    assert 5 * 6 * 11 // 6 == sum(k*k for k in range(1, 6)) == 55
    assert (10 * 11 // 2) ** 2 == sum(k**3 for k in range(1, 11)) == 3025
    book = {"schema_version": 2, "title": "대수 2022 개정 · HWP EqEdit 복구 기준 수열 후보", "subtitle": "등비수열·합의 기호·여러 수열의 합", "category": "concept_textbook_prototype", "curriculum_version": "2022", "standard_codes": [s["code"] for s in SPECS], "tags": ["대수", "2022 개정", "HWP EqEdit 복구 기준", "수열", "신규 원고 후보", "학기 배정 미확정", *[s["code"] for s in SPECS]], "chapters": chapters}
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    try:
        old = json.loads((PACKAGE / "REVIEW_MANIFEST.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old = {}
    same = old.get("bookdata_sha256") == digest
    manifest = {"bookdata_file": OUT.name, "bookdata_sha256": digest, "candidate_code_references": book["standard_codes"], "candidate_code_reference_type": "official_2022_hwp_criterion_table_and_raw_eqedit_records", "official_hwp_sha256": __import__("hashlib").sha256(HWP.read_bytes()).hexdigest().upper(), "recovered_eqedit_source_scripts": {s["code"]: sorted(s["scripts"]) for s in SPECS}, "module_count": 3, "page_count": len(all_ids), "native_activity_count": 3, "native_activity_kinds": ["quiz"], "spot_checks": "listed arithmetic checks passed only", "app_model_roundtrip_status": old.get("app_model_roundtrip_status", "pending_current_hash_validation") if same else "pending_current_hash_validation", "teacher_reader_interaction_status": old.get("teacher_reader_interaction_status", "pending_current_hash_validation") if same else "pending_current_hash_validation", "validation_test": "test/textbook_activity_compatibility_test.dart", "teacher_review_status": "pending", "math_review_status": "author spot checks passed; independent teacher review pending", "rights_status": "new original examples; publication rights decision pending", "curriculum_review_status": "codes and raw HWP EqEdit evidence verified; full scope and semester assignment pending", "publication_eligibility": "not_eligible", "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same else "pending_current_hash_validation", "runtime_validator_head": old.get("runtime_validator_head") if same else None}
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    app_check = "BookData round-trip과 실제 teacher reader quiz 제출·피드백 테스트가 통과했습니다." if manifest["teacher_reader_interaction_status"].startswith("passed:") else "BookData 왕복과 teacher reader 상호작용 검증 대기 중입니다."
    (PACKAGE / "README.md").write_text(f"# {book['title']}\n\nHWP raw EqEdit 근거를 확인한 3모듈·15쪽·quiz 3개 원고 후보입니다. 공식 기준은 `{', '.join(book['standard_codes'])}`입니다. 예시와 문항은 새로 작성했습니다. {app_check} 이 앱 호환성 검증은 독립 교과·교사 검토를 대신하지 않으며, 전체 범위·권리 결정 전 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n", encoding="utf-8")
    print(f"Built {len(chapters)} Algebra modules, {len(all_ids)} pages, 3 quizzes from recovered HWP EqEdit evidence.")


if __name__ == "__main__":
    main()
