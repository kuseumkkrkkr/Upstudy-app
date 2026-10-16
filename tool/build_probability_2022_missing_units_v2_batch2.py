"""Build four original V2 drafts for the next verified 2022 probability/statistics standards."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "확률과통계_2022개정_확률누락4단원_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "확률과통계_2022개정_확률누락4단원_Batch2_원고패키지"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
HWP = ROOT / "work/official-curriculum/2022_appendix8_math.hwp"
EXPECTED = {
    "12확통02-05": "사건의 독립과 종속을 이해하고, 이를 판단할 수 있다",
    "12확통02-06": "확률의 곱셈정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다",
    "12확통03-01": "확률변수와 확률분포의 뜻을 설명할 수 있다",
    "12확통03-02": "이산확률변수의 기댓값(평균)과 표준편차를 구할 수 있다",
}


def block(kind: str, title: str, text: str, **extra: object) -> dict[str, object]:
    return {"type": kind, "title": title, "text": text, **extra}


def page(pid: str, template: str, title: str, *blocks: dict[str, object]) -> dict[str, object]:
    return {"id": pid, "template": template, "title": title, "blocks": list(blocks)}


def quiz(pid: str, prompt: str, options: list[str], correct_index: int, feedback: str, wrong: str, hints: list[str]) -> dict[str, object]:
    return {"type": "activity", "activity": {
        "id": pid, "kind": "quiz", "prompt": prompt, "options": options,
        "correct_index": correct_index, "correct_feedback": feedback,
        "incorrect_feedback": wrong, "hints": hints,
    }}


SPECS = [
    {
        "code": "12확통02-05", "title": "사건이 독립인지 자료로 판단하기",
        "lead": "가상 주사위 실험에서 A는 첫째 주사위가 짝수인 사건, B는 둘째 주사위가 4보다 큰 사건이다. 두 사건은 독립인가요?",
        "concept": "두 사건 A와 B가 독립이면 P(A∩B)=P(A)P(B)이다. 조건부확률 P(B|A)가 P(B)와 같은지 비교해도 판단할 수 있다.",
        "example": "공정한 주사위 두 개를 던진다. A: 첫째 눈이 짝수, B: 둘째 눈이 4보다 큼. P(A)=1/2, P(B)=1/3, P(A∩B)=1/6이고 P(A)P(B)=1/6이므로 독립이다.",
        "practice": "공정한 주사위 하나를 던진다. C: 짝수, D: 3보다 큰 수일 때 두 사건은 독립인가요?",
        "answer": "P(C)=1/2, P(D)=1/2, P(C∩D)=2/6=1/3이다. P(C)P(D)=1/4와 다르므로 독립이 아니다.",
        "prompt": "첫째 주사위가 짝수일 사건과 둘째 주사위가 4보다 클 사건은 독립인가요?",
        "options": ["독립이다", "독립이 아니다", "확률만으로 판단할 수 없다"], "correct": 0,
        "feedback": "두 주사위의 결과가 독립이고 P(A∩B)=1/6=P(A)P(B)이므로 독립입니다.",
        "wrong": "각 사건의 확률과 교집합 확률을 곱셈 조건과 비교하세요.",
        "hints": ["P(A)=3/6, P(B)=2/6입니다.", "두 사건이 동시에 일어나는 결과는 36개 중 6개입니다."],
    },
    {
        "code": "12확통02-06", "title": "연속해서 일어나는 사건의 곱셈정리",
        "lead": "가상 주머니에 빨간 구슬 3개와 파란 구슬 2개가 있다. 되돌려 넣지 않고 두 번 뽑을 때 두 구슬 모두 빨간색일 확률은?",
        "concept": "두 사건 A, B에 대해 P(A∩B)=P(A)P(B|A)이다. 서로 독립인 경우에만 P(B|A)=P(B)로 바꾸어 P(A)P(B)를 쓸 수 있다.",
        "example": "첫 구슬이 빨간색일 확률은 3/5이다. 빨간 구슬을 뽑은 뒤 남은 빨간 구슬은 2개, 전체는 4개이므로 두 번째도 빨간색일 조건부확률은 2/4이다. 따라서 3/5×2/4=3/10이다.",
        "practice": "가상 주머니에 흰 구슬 2개와 검은 구슬 3개가 있다. 되돌려 넣지 않고 두 번 뽑을 때 흰색 다음 검은색일 확률을 구하세요.",
        "answer": "첫 흰색 확률은 2/5이고, 그 뒤 검은색은 3/4이므로 2/5×3/4=3/10입니다.",
        "prompt": "빨간 구슬 3개, 파란 구슬 2개에서 비복원으로 두 번 뽑을 때 두 번 모두 빨간색일 확률은?",
        "options": ["3/10", "9/25", "2/5"], "correct": 0,
        "feedback": "첫 빨간색 3/5에 이어 빨간색 2/4이므로 곱은 3/10입니다.",
        "wrong": "첫 번째 결과 뒤에는 주머니 구성이 바뀌므로 두 번째 조건부확률을 새로 계산하세요.",
        "hints": ["첫 빨간색 확률을 계산합니다.", "첫 빨간색을 꺼낸 뒤 남은 빨간색 수와 전체 구슬 수를 사용합니다."],
    },
    {
        "code": "12확통03-01", "title": "확률변수와 확률분포 읽기",
        "lead": "공정한 동전을 두 번 던진다. 확률변수 X를 앞면이 나온 횟수로 정하면 X는 어떤 값을 가질까요?",
        "concept": "확률변수는 시행 결과를 실수 값에 대응시키는 변수이다. 확률분포는 각 값과 그 값이 나올 확률을 함께 나타낸다.",
        "example": "두 번 던진 결과 HH, HT, TH, TT는 같은 확률 1/4이다. 앞면 수 X는 각각 2, 1, 1, 0이므로 P(X=0)=1/4, P(X=1)=1/2, P(X=2)=1/4이다.",
        "practice": "위 분포에서 P(X≥1)을 구하고 확률의 합이 1인지 확인하세요.",
        "answer": "P(X≥1)=1/2+1/4=3/4이고 전체 확률은 1/4+1/2+1/4=1입니다.",
        "prompt": "공정한 동전 두 번 던지기에서 앞면 수 X의 P(X=1)은?",
        "options": ["1/2", "1/4", "3/4"], "correct": 0,
        "feedback": "HT와 TH 두 결과가 해당하므로 2/4=1/2입니다.",
        "wrong": "순서가 다른 HT와 TH를 각각 가능한 결과로 세세요.",
        "hints": ["가능한 결과는 HH, HT, TH, TT 네 가지입니다.", "앞면이 한 번인 결과를 모두 나열하세요."],
    },
    {
        "code": "12확통03-02", "title": "이산확률변수의 기댓값과 표준편차",
        "lead": "두 번의 공정한 동전 던지기에서 앞면 수 X의 분포가 (0,1/4), (1,1/2), (2,1/4)이다. 평균과 퍼짐을 어떻게 구할까요?",
        "concept": "이산확률변수 X의 기댓값은 ΣxP(X=x)이고 분산은 Σ(x−E(X))²P(X=x)이다. 표준편차는 분산의 양의 제곱근이다.",
        "example": "E(X)=0×1/4+1×1/2+2×1/4=1이다. 분산은 (0−1)²×1/4+(1−1)²×1/2+(2−1)²×1/4=1/2이고 표준편차는 √(1/2)=1/√2이다.",
        "practice": "분포 (0,1/2), (2,1/2)의 기댓값과 표준편차를 구하세요.",
        "answer": "기댓값은 0×1/2+2×1/2=1이다. 분산은 (0−1)²×1/2+(2−1)²×1/2=1이므로 표준편차는 1이다.",
        "prompt": "앞면 수 X의 확률분포가 (0,1/4), (1,1/2), (2,1/4)일 때 E(X)는?",
        "options": ["1", "1/2", "3/2"], "correct": 0,
        "feedback": "확률가중합은 0×1/4+1×1/2+2×1/4=1입니다.",
        "wrong": "각 값에 그 확률을 곱하고 모두 더하세요.",
        "hints": ["값과 확률을 짝지어 곱합니다.", "0, 1, 2에 각각 1/4, 1/2, 1/4를 곱하세요."],
    },
]


def chapters() -> list[dict[str, object]]:
    result = []
    for spec in SPECS:
        short = spec["code"].replace("12확통", "ps").replace("-", "")
        result.append({
            "title": spec["title"],
            "intro": [f"공식 기준 {spec['code']}에 연결한 새 집필 후보입니다.", "수치와 사례는 개념을 연습하기 위해 직접 만든 가상 예시입니다."],
            "pages": [
                page(f"{short}-open", "opening", "상황을 먼저 읽기", block("lead", "가상 예시", spec["lead"]), block("thinking", "질문", "어떤 확률 관계를 비교하거나 계산해야 할까요?")),
                page(f"{short}-concept", "concept", "정의와 관계", block("definition", "핵심 개념", spec["concept"]), block("formula", "공식 기준", spec["code"]), block("misconception", "주의", "사건의 독립 여부나 조건이 바뀌는지 확인한 뒤 곱셈·분포 공식을 선택합니다.")),
                page(f"{short}-example", "example", "예제와 풀이", block("question", "예제", spec["lead"]), block("solutionStep", "풀이", spec["example"]), block("verification", "검산", "확률의 합과 계산 결과가 정의한 가상 표본 공간에 맞는지 확인합니다.")),
                page(f"{short}-practice", "practice", "연습과 설명", block("question", "연습", spec["practice"]), block("hint", "Socratic 힌트", "사건, 조건, 각 결과의 확률을 따로 적어 보세요."), block("solutionStep", "해설", spec["answer"]), block("answer", "정답", spec["answer"]), quiz(f"{short}-quiz", spec["prompt"], spec["options"], spec["correct"], spec["feedback"], spec["wrong"], spec["hints"])),
                page(f"{short}-summary", "summary", "핵심 정리", block("summary", "기억할 점", spec["title"]), block("checklist", "스스로 확인", "확률 관계와 계산 근거를 말로 설명할 수 있나요?")),
            ],
        })
    return result


def main() -> None:
    rows = json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]
    official = {item["code"]: item["criterion"].rstrip(" .") for item in rows}
    mismatches = {code: (official.get(code), criterion) for code, criterion in EXPECTED.items() if official.get(code) != criterion}
    if mismatches:
        raise RuntimeError(f"Official HWP table mismatch: {mismatches}")
    chapter_data = chapters()
    codes = list(EXPECTED)
    book = {
        "schema_version": 2,
        "title": "확률과 통계 · 확률분포 추가 4모듈 후보",
        "subtitle": "독립·곱셈정리·확률분포·기댓값과 표준편차",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2022",
        "tags": ["확률과 통계", "2022 개정", "추가 원고 후보", "가상 예시", "학기 배정 미확정"],
        "standard_codes": codes,
        "chapters": chapter_data,
    }
    ids: set[str] = set()
    activities = []
    for chapter in chapter_data:
        if len(chapter["pages"]) != 5:
            raise RuntimeError("Each module must contain five instructional pages")
        for page_item in chapter["pages"]:
            if page_item["id"] in ids:
                raise RuntimeError(f"Duplicate page id: {page_item['id']}")
            ids.add(page_item["id"])
            for content in page_item["blocks"]:
                if content.get("type") == "activity":
                    activity_data = content["activity"]
                    if activity_data["id"] in ids:
                        raise RuntimeError(f"Duplicate activity id: {activity_data['id']}")
                    ids.add(activity_data["id"])
                    activities.append(activity_data)
    if len(chapter_data) != 4 or len(activities) != 4:
        raise RuntimeError("Draft scope mismatch")
    # Arithmetic checks for the synthetic examples and their teaching claims.
    assert (3 / 6) * (2 / 6) == 1 / 6
    assert 2 / 6 != (3 / 6) * (3 / 6)
    assert (3 / 5) * (2 / 4) == 3 / 10
    assert abs((2 / 5) * (3 / 4) - 3 / 10) < 1e-12
    distribution = {0: 1 / 4, 1: 1 / 2, 2: 1 / 4}
    assert sum(distribution.values()) == 1 and distribution[1] == 1 / 2
    expected_value = sum(x * p for x, p in distribution.items())
    variance = sum((x - expected_value) ** 2 * p for x, p in distribution.items())
    assert expected_value == 1 and variance == 1 / 2
    assert math_sqrt(variance) == 0.7071067811865476
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try:
        old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old = {}
    same_hash = old.get("bookdata_sha256") == digest
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": codes, "candidate_code_reference_type": "official_hwp_criterion_table",
        "module_count": 4, "page_count": 20, "native_activity_count": 4, "native_activity_kinds": ["quiz"],
        "example_data_status": "synthetic_original_examples; no commercial text, problem, or illustration copied",
        "curriculum_review_status": "official_codes_mapped; semester_and_full_scope_pending",
        "math_review_status": "pending_full_review", "math_arithmetic_check_status": "pass_for_listed_examples_only",
        "teacher_review_status": "pending", "rights_status": "newly_authored; publication_rights_decision_pending",
        "integration_status": "not_merged_into_master_book", "publication_eligibility": "not_eligible",
        "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same_hash else "pending_current_hash_validation",
        "runtime_validator_head": old.get("runtime_validator_head") if same_hash else None,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        f"# {book['title']}\n\n"
        "신규 집필 4모듈·20쪽의 재개 가능한 V2 후보입니다. 수치 사례는 직접 만든 가상 예시이며 상업 교재의 문장·문제·그림을 복사하지 않았습니다. "
        "공식 HWP 본표 코드와 연결했지만 학기 배정·과목 전체 완결·교사 및 전체 수학 검토·출판 권리 결정은 대기 중입니다.\n\n"
        f"BookData: [`{OUT.name}`](../{OUT.name})\n",
        encoding="utf-8",
    )
    print(f"Built {len(chapter_data)} probability modules, 20 pages, 4 native quizzes: {OUT}")


def math_sqrt(value: float) -> float:
    import math
    return math.sqrt(value)


if __name__ == "__main__":
    main()
