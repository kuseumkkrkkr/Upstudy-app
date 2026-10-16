"""Build original V2 drafts for the five 2022 Calculus II sequence standards."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "미적분Ⅱ_2022개정_수열극한급수5단원_Batch1_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "미적분Ⅱ_2022개정_수열극한급수5단원_Batch1_원고패키지"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"

SPECS = [
    {
        "code": "12미적Ⅱ-01-01", "title": "수열의 수렴과 발산",
        "lead": "센서가 매 단계 기록하는 값이 2에 가까워지는지 살펴보자. aₙ=(2n+1)/(n+1)과 bₙ=(-1)ⁿ은 각각 어떤 모습일까?",
        "concept": "수열이 어떤 실수 L에 한없이 가까워지면 L로 수렴한다고 하고, 그런 극한값이 없으면 발산한다고 한다. 항의 몇 개만 보고 결론을 내리지 말고 n이 커질 때의 일반항을 살핀다.",
        "example": "aₙ=(2n+1)/(n+1)=2−1/(n+1)이므로 n이 커질수록 2에 가까워져 2로 수렴한다. bₙ=(-1)ⁿ은 1과 −1을 번갈아 가지므로 하나의 값에 가까워지지 않아 발산한다.",
        "practice": "수열 cₙ=5−3/n의 극한을 구하고, 근거를 한 문장으로 설명하세요.",
        "answer": "3/n이 0에 가까워지므로 cₙ은 5에 수렴합니다.",
        "prompt": "aₙ=(2n+1)/(n+1)의 극한은?", "options": ["2", "1", "발산"], "correct": 0,
        "feedback": "aₙ=2−1/(n+1)이므로 극한은 2입니다.", "wrong": "분자와 분모의 최고차항 또는 2−1/(n+1) 꼴로 정리해 보세요.",
        "hints": ["분자 2n+1을 2(n+1)−1로 바꿉니다.", "aₙ=2−1/(n+1)입니다."],
    },
    {
        "code": "12미적Ⅱ-01-02", "title": "수열의 극한 성질로 계산하기",
        "lead": "두 측정 수열 aₙ=2+1/n, bₙ=3−2/n이 각각 가까워지는 값을 알 때, (aₙ+bₙ)/(aₙbₙ)의 극한을 빠르게 구할 수 있을까?",
        "concept": "aₙ→A, bₙ→B일 때 합과 곱의 극한은 각각 A+B, AB이다. B≠0이면 aₙ/bₙ→A/B이다. 분모의 극한이 0이면 몫의 극한 성질을 그대로 적용할 수 없다.",
        "example": "aₙ→2, bₙ→3이고 2·3≠0이므로 (aₙ+bₙ)/(aₙbₙ)의 극한은 (2+3)/(2·3)=5/6이다.",
        "practice": "xₙ=4+1/n, yₙ=2−1/n일 때 (xₙ−yₙ)/yₙ의 극한을 구하세요.",
        "answer": "xₙ→4, yₙ→2이므로 분모 극한이 0이 아니며 극한은 (4−2)/2=1입니다.",
        "prompt": "aₙ→2, bₙ→3일 때 (aₙ+bₙ)/(aₙbₙ)의 극한은?", "options": ["5/6", "5", "6/5"], "correct": 0,
        "feedback": "합과 곱의 극한을 적용하면 (2+3)/(2·3)=5/6입니다.", "wrong": "분자와 분모의 극한을 각각 계산한 뒤 나눕니다.",
        "hints": ["분자 극한은 2+3입니다.", "분모 극한은 2·3이며 0이 아닙니다."],
    },
    {
        "code": "12미적Ⅱ-01-03", "title": "등비수열의 수렴과 발산",
        "lead": "가상의 진동 장치에서 매 단계 값이 직전 값의 −1/3이 된다. 처음 값이 9일 때 값들은 어디에 가까워질까?",
        "concept": "첫째항이 a이고 공비가 r인 등비수열의 n번째 항은 arⁿ⁻¹이다. |r|<1이면 항의 절댓값이 0에 가까워져 수열은 0으로 수렴한다. r=1이면 상수 수열이고, r=−1 또는 |r|>1이면 일반적으로 수렴하지 않는다.",
        "example": "9, −3, 1, −1/3, …은 공비 −1/3으로 절댓값이 1보다 작다. 부호는 번갈아도 항의 절댓값은 0에 가까워지므로 극한은 0이다.",
        "practice": "첫째항 6, 공비 1/2인 등비수열의 극한을 구하고 수렴 조건을 쓰세요.",
        "answer": "|1/2|<1이므로 항의 절댓값이 0에 가까워져 극한은 0입니다.",
        "prompt": "첫째항 9, 공비 −1/3인 등비수열의 극한은?", "options": ["0", "−1/3", "발산"], "correct": 0,
        "feedback": "공비의 절댓값이 1보다 작으므로 항이 0으로 수렴합니다.", "wrong": "공비의 부호와 절댓값을 구분해 보세요.",
        "hints": ["공비는 −1/3입니다.", "|−1/3|<1이면 항의 절댓값은 0에 가까워집니다."],
    },
    {
        "code": "12미적Ⅱ-01-04", "title": "급수의 수렴과 발산",
        "lead": "무한히 많은 항을 더할 때 합이 하나의 유한한 값에 가까워지는지 어떻게 판단할까? 1/2+1/4+1/8+…과 1+1/2+1/3+…을 비교해 보자.",
        "concept": "급수 Σaₙ은 부분합 Sₙ=a₁+…+aₙ의 수열을 살펴본다. 부분합이 유한한 값으로 수렴하면 급수가 수렴하고, 그렇지 않으면 발산한다. aₙ→0은 수렴에 필요한 조건이지만 그것만으로 수렴을 보장하지 않는다.",
        "example": "첫 급수의 n번째 부분합은 1−(1/2)ⁿ이므로 1에 수렴한다. 둘째 급수는 조화급수이며 항은 0으로 가지만 부분합은 발산한다. 따라서 항의 극한만으로 급수의 수렴을 단정할 수 없다.",
        "practice": "급수 Σ(1/3)ⁿ⁻¹의 부분합 극한을 구하고 수렴 여부를 말하세요.",
        "answer": "첫째항 1, 공비 1/3인 등비급수이므로 부분합은 (1−(1/3)ⁿ)/(1−1/3)이고 극한은 3/2입니다. 급수는 수렴합니다.",
        "prompt": "급수 1+1/2+1/4+…의 합은?", "options": ["2", "1", "발산"], "correct": 0,
        "feedback": "공비 1/2인 등비급수의 합은 1/(1−1/2)=2입니다.", "wrong": "급수의 항이 아니라 부분합의 극한을 확인하세요.",
        "hints": ["첫째항 a=1, 공비 r=1/2입니다.", "|r|<1인 등비급수의 합 a/(1−r)을 적용합니다."],
    },
    {
        "code": "12미적Ⅱ-01-05", "title": "등비급수의 합과 반복 상황",
        "lead": "공을 8m 높이에서 떨어뜨린 뒤 매번 직전 높이의 절반까지 튀어 오른다고 하자. 처음 낙하부터 멈출 때까지 공이 이동하는 전체 거리를 구해 보자.",
        "concept": "첫째항 a, 공비 r인 등비급수는 |r|<1일 때 합이 a/(1−r)이다. 반복 상황에서는 처음 이동과 이후 왕복 이동을 구분해 항을 세어야 한다.",
        "example": "처음 아래로 8m 이동한다. 튀어 오른 뒤의 이동거리는 4+2+1+…으로, 합은 4/(1−1/2)=8m이다. 이 구간은 매번 올라가고 내려오므로 전체 거리는 8+2·8=24m이다.",
        "practice": "처음 12m 떨어뜨린 공이 매번 직전 높이의 1/3까지 튀어 오른다. 처음 낙하부터 이후 모든 왕복 이동거리의 합을 구하세요.",
        "answer": "튀어 오른 높이의 합은 4+4/3+4/9+…=4/(1−1/3)=6m입니다. 왕복 이동이므로 전체 거리는 12+2·6=24m입니다.",
        "prompt": "첫째항 3, 공비 1/4인 무한등비급수의 합은?", "options": ["4", "3", "12"], "correct": 0,
        "feedback": "3/(1−1/4)=4입니다.", "wrong": "|r|<1인 등비급수 합 공식에 대입합니다.",
        "hints": ["a=3, r=1/4입니다.", "a/(1−r)=3/(3/4)입니다."],
    },
]


def activity(spec: dict[str, object], aid: str) -> dict[str, object]:
    return {"type": "activity", "activity": {
        "id": aid, "kind": "quiz", "prompt": spec["prompt"], "options": spec["options"],
        "correct_index": spec["correct"], "correct_feedback": spec["feedback"],
        "incorrect_feedback": spec["wrong"], "hints": spec["hints"],
    }}


def main() -> None:
    official = {row["code"]: row["criterion"].rstrip(" .") for row in json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]}
    codes = [spec["code"] for spec in SPECS]
    if len(set(codes)) != 5 or any(code not in official for code in codes):
        raise RuntimeError("Expected five distinct official 2022 Calculus II standards")
    chapters = []
    for spec in SPECS:
        slug = spec["code"].replace("12미적Ⅱ-", "calc2-").replace("-", "")
        pages = [
            {"id": slug+"-open", "template": "opening", "title": "상황에서 질문 만들기", "blocks": [{"type": "lead", "title": "가상 예시", "text": spec["lead"]}, {"type": "thinking", "title": "먼저 생각하기", "text": "수열의 항 또는 부분합을 분리하고 변화의 기준이 되는 조건을 표시합니다."}]},
            {"id": slug+"-concept", "template": "concept", "title": "정의와 성질", "blocks": [{"type": "definition", "title": "핵심 개념", "text": spec["concept"]}, {"type": "formula", "title": "연결한 공식 기준", "text": spec["code"]}, {"type": "misconception", "title": "확인할 점", "text": "몇 개의 항만 관찰해 극한을 단정하지 말고, 정의와 적용 조건을 확인합니다."}]},
            {"id": slug+"-example", "template": "example", "title": "예제와 풀이", "blocks": [{"type": "question", "title": "예제", "text": spec["lead"]}, {"type": "solutionStep", "title": "풀이", "text": spec["example"]}, {"type": "verification", "title": "검산", "text": "공식의 조건과 계산 결과를 대입해 확인합니다."}]},
            {"id": slug+"-practice", "template": "practice", "title": "연습과 설명", "blocks": [{"type": "question", "title": "연습", "text": spec["practice"]}, {"type": "hint", "title": "힌트", "text": spec["hints"][0]}, {"type": "solutionStep", "title": "해설", "text": spec["answer"]}, {"type": "answer", "title": "정답", "text": spec["answer"]}, activity(spec, slug+"-quiz")]},
            {"id": slug+"-summary", "template": "summary", "title": "핵심 정리", "blocks": [{"type": "summary", "title": "기억할 점", "text": spec["title"]}, {"type": "checklist", "title": "스스로 확인", "text": "수렴·발산 판단과 계산에 사용한 조건을 설명할 수 있나요?"}]},
        ]
        chapters.append({"title": spec["title"], "intro": [f"2022 교육과정 공식 기준 {spec['code']}에 연결한 새 집필 후보입니다.", "수치와 상황은 개념 연습을 위해 직접 만든 가상 예시입니다."], "pages": pages})
    book = {"schema_version": 2, "title": "미적분Ⅱ · 수열의 극한과 급수 추가 5모듈 후보", "subtitle": "수열의 수렴·발산, 극한 성질, 등비수열과 급수", "category": "concept_textbook_prototype", "curriculum_version": "2022", "tags": ["미적분Ⅱ", "2022 개정", "추가 원고 후보", "가상 예시", "학기 배정 미확정"], "standard_codes": codes, "chapters": chapters}
    ids = set()
    for chapter in chapters:
        if len(chapter["pages"]) != 5:
            raise RuntimeError("Each module must contain five pages")
        for item in chapter["pages"]:
            if item["id"] in ids: raise RuntimeError(f"Duplicate id: {item['id']}")
            ids.add(item["id"])
    n = 100000
    assert abs((2*n+1)/(n+1) - 2) < 1e-4
    assert math.isclose(1/(1-0.5), 2)
    assert math.isclose(1/(1-1/3), 1.5)
    assert math.isclose(3/(1-1/4), 4)
    assert 8 + 2*(4/(1-0.5)) == 24
    assert 12 + 2*(4/(1-1/3)) == 24
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(OUT.read_bytes()).hexdigest().upper()
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try: old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError): old = {}
    same_hash = old.get("bookdata_sha256") == digest
    manifest = {"bookdata_file": OUT.name, "bookdata_sha256": digest, "candidate_code_references": codes, "candidate_code_reference_type": "official_hwp_criterion_table", "module_count": 5, "page_count": 25, "native_activity_count": 5, "native_activity_kinds": ["quiz"], "example_data_status": "synthetic_original_examples; no commercial text, problem, illustration, or dataset copied", "curriculum_review_status": "official_codes_mapped; semester_and_full_scope_pending", "math_review_status": "pending_full_review", "math_arithmetic_check_status": "pass_for_listed_examples_only", "teacher_review_status": "pending", "rights_status": "newly_authored; publication_rights_decision_pending", "integration_status": "not_merged_into_master_book", "publication_eligibility": "not_eligible", "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same_hash else "pending_current_hash_validation", "runtime_validator_head": old.get("runtime_validator_head") if same_hash else None}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(f"# {book['title']}\n\n신규 집필 5모듈·25쪽의 재개 가능한 V2 후보입니다. 공식 기준 5개에 연결했으며 예시와 수치는 직접 만든 것입니다. 교사·수학 검토, 학기/과목 범위 대조, 권리 승인 전에는 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n", encoding="utf-8")
    print(f"Built {len(chapters)} Calculus II modules, 25 pages, 5 quizzes: {OUT}")


if __name__ == "__main__":
    main()
