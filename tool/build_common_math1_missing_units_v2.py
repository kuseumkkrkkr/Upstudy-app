"""Regenerable original V2 drafts for three unmapped Common Math 1 standards."""
from __future__ import annotations

import json
import hashlib
from pathlib import Path
from textbook_digest import canonical_file_sha256
from tempfile import NamedTemporaryFile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/공통수학1_2022개정_누락기준3단원_BookData_V2_시범.json"
PACKAGE = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/공통수학1_2022개정_누락기준3단원_원고패키지"


def block(kind: str, title: str, text: str, **extra: object) -> dict[str, object]:
    return {"type": kind, "title": title, "text": text, **extra}


def page(page_id: str, template: str, title: str, *blocks: dict[str, object]) -> dict[str, object]:
    return {"id": page_id, "template": template, "title": title, "blocks": list(blocks)}


def make_chapters() -> list[dict[str, object]]:
    return [
        {
            "title": "인수분해로 풀 수 있는 삼차·사차방정식",
            "intro": [
                "방정식을 인수의 곱으로 바꾸어 각 인수가 0이 되는 값을 찾습니다.",
                "성취기준 10공수1-02-07의 간단한 삼차방정식과 사차방정식 범위에 맞춰 인수분해나 인수정리로 풀 수 있는 경우만 다룹니다.",
            ],
            "pages": [
                page("cm1-220207-open", "opening", "먼저 대입해 볼 값은?",
                     block("lead", "오늘의 질문", "x³−2x²−5x+6=0의 해를 어떻게 찾을 수 있을까요?"),
                     block("thinking", "예측", "정수 해가 있다면 어떤 수부터 대입해 볼지 정하고, 이유를 말해 보세요.")),
                page("cm1-220207-concept", "concept", "인수의 곱은 0",
                     block("definition", "핵심 원리", "곱이 0이면 적어도 한 인수가 0입니다. 먼저 다항식을 인수분해한 다음 각 인수를 0으로 놓습니다."),
                     block("visual", "인수정리로 후보 검사", "정수 해 r은 상수항 6의 약수 후보입니다. 대입해 0이 되는 r을 찾으면 (x−r)을 인수로 얻습니다.", formula="f(r)=0 ⇔ (x−r)이 f(x)의 인수"),
                     block("misconception", "주의", "모든 삼차·사차방정식을 이 방법으로 풀 수 있다고 가정하지 않습니다. 이 단원은 인수분해 등으로 인수를 찾을 수 있는 경우만 연습합니다.")),
                page("cm1-220207-example", "example", "정수 해를 먼저 찾기",
                     block("question", "예제", "x³−2x²−5x+6=0을 풀어 보세요."),
                     block("solutionStep", "1. 후보 대입", "상수항 6의 정수 약수 중 x=1을 대입하면 1−2−5+6=0입니다. 따라서 (x−1)이 인수입니다."),
                     block("solutionStep", "2. 나머지 인수분해", "조립제법 또는 나눗셈으로 x³−2x²−5x+6=(x−1)(x²−x−6)=(x−1)(x−3)(x+2)입니다."),
                     block("answer", "해", "각 인수를 0으로 놓으면 x=1, 3, −2입니다."),
                     block("verification", "검산", "세 값을 원래 식에 대입하면 모두 0입니다."),
                     block("visual", "사차식으로 확장", "x⁴−5x²+4=(x²−1)(x²−4)=(x−1)(x+1)(x−2)(x+2)이므로 네 실근은 −2, −1, 1, 2입니다.")),
                page("cm1-220207-practice", "practice", "묶어 인수분해하기",
                     block("question", "연습", "x³−x²−4x+4=0을 풀어 보세요."),
                     block("hint", "힌트", "앞의 두 항과 뒤의 두 항을 각각 묶어 공통인수를 찾아보세요."),
                     block("answer", "정답과 검산", "x²(x−1)−4(x−1)=(x−1)(x−2)(x+2)이므로 x=1, 2, −2입니다. 세 해를 원식에 대입하면 0입니다.")),
                page("cm1-220207-activity", "experiment", "대표식의 가장 큰 해",
                     block("lead", "직접 확인", "앞에서 인수분해한 식의 해를 확인합니다."),
                     {"type": "activity", "activity": {
                         "id": "cm1-220207-largest-root", "kind": "quiz",
                         "prompt": "x³−2x²−5x+6=0의 가장 큰 실수 해를 입력하세요.",
                         "answer": 3, "tolerance": 0,
                         "correct_feedback": "맞습니다. 세 해 −2, 1, 3 가운데 가장 큰 해는 3입니다.",
                         "incorrect_feedback": "인수분해 결과 (x−1)(x−3)(x+2)를 이용해 세 해를 모두 비교해 보세요.",
                         "hints": ["먼저 상수항 6의 약수 중 원식에 대입해 0이 되는 값을 찾습니다.", "나머지 이차식을 인수분해해 해를 모두 모읍니다."],
                     }}),
                page("cm1-220207-summary", "summary", "인수분해한 뒤 해를 모으기",
                     block("summary", "핵심 정리", "인수정리로 인수를 찾고, 남은 이차식도 인수분해한 뒤 각 인수를 0으로 놓습니다."),
                     block("checklist", "스스로 점검", "해를 원래 방정식에 대입해 검산했나요?")),
            ],
        },
        {
            "title": "일차식과 이차식으로 된 연립이차방정식",
            "intro": [
                "합과 제곱의 합을 이용해 두 수의 곱을 구한 뒤, 두 수를 결정합니다.",
                "성취기준 10공수1-02-08에 맞춰 일차식 하나와 이차식 하나로 이루어진 간단한 경우를 다룹니다.",
            ],
            "pages": [
                page("cm1-220208-open", "opening", "합만 알 때 쌍을 찾을 수 있을까?",
                     block("lead", "오늘의 질문", "두 수의 합이 5이고 제곱의 합이 13이면 두 수는 무엇일까요?"),
                     block("thinking", "예측", "두 조건을 각각 식으로 쓰고, 한 식으로 다른 식을 보완할 방법을 생각해 보세요.")),
                page("cm1-220208-concept", "concept", "제곱의 합에서 곱을 얻기",
                     block("definition", "두 항등식 연결", "(x+y)²=x²+2xy+y²이므로 합과 제곱의 합을 알면 xy를 구할 수 있습니다."),
                     block("visual", "두 수를 근으로 보기", "x+y=s, xy=p이면 x와 y는 t²−st+p=0의 두 근입니다.", formula="xy=((x+y)²−(x²+y²))/2"),
                     block("misconception", "해의 순서", "순서쌍 (x,y)를 묻는 문제에서는 (2,3)과 (3,2)를 구별합니다. 대칭인 두 식이면 둘 다 확인해야 합니다.")),
                page("cm1-220208-example", "example", "합과 제곱의 합으로 풀기",
                     block("question", "예제", "x+y=5, x²+y²=13을 동시에 만족하는 순서쌍 (x,y)를 구하세요."),
                     block("solutionStep", "1. 곱 구하기", "25=13+2xy이므로 xy=6입니다."),
                     block("solutionStep", "2. 두 수 결정", "x와 y는 t²−5t+6=(t−2)(t−3)=0의 두 근이므로 2와 3입니다."),
                     block("answer", "해", "순서쌍은 (2,3), (3,2)입니다."),
                     block("verification", "검산", "두 순서쌍 모두 합은 5이고 제곱의 합은 4+9=13입니다.")),
                page("cm1-220208-practice", "practice", "두 조건을 함께 사용하기",
                     block("question", "연습", "x+y=4, x²+y²=10을 만족하는 순서쌍을 구하세요."),
                     block("hint", "힌트", "16=10+2xy에서 xy를 먼저 구한 다음 t²−4t+xy=0을 세우세요."),
                     block("answer", "정답과 검산", "xy=3이고 t²−4t+3=(t−1)(t−3)이므로 (x,y)=(1,3),(3,1)입니다. 두 조건에 대입해 확인합니다.")),
                page("cm1-220208-activity", "experiment", "연습 조건에서 곱 구하기",
                     block("lead", "직접 확인", "x+y=4, x²+y²=10에서 xy를 입력합니다."),
                     {"type": "activity", "activity": {
                         "id": "cm1-220208-product", "kind": "quiz",
                         "prompt": "x+y=4이고 x²+y²=10일 때 xy를 입력하세요.",
                         "answer": 3, "tolerance": 0,
                         "correct_feedback": "맞습니다. (x+y)²=x²+y²+2xy에서 xy=3입니다.",
                         "incorrect_feedback": "16=10+2xy를 세워 2xy를 먼저 구해 보세요.",
                         "hints": ["(x+y)²의 값을 계산합니다.", "제곱의 합을 빼고 남은 값을 2로 나눕니다."],
                     }}),
                page("cm1-220208-summary", "summary", "곱을 구하고 순서쌍 확인하기",
                     block("summary", "핵심 정리", "합과 제곱의 합으로 곱을 구하고, 근의 합·곱이 주어진 이차방정식으로 두 수를 찾습니다."),
                     block("checklist", "스스로 점검", "가능한 순서쌍을 모두 원래 두 식에 대입했나요?")),
            ],
        },
        {
            "title": "2×2 행렬의 연산",
            "intro": [
                "행렬의 덧셈·뺄셈·실수배와 2×2 행렬의 곱셈을 계산합니다.",
                "성취기준 10공수1-04-02의 행렬 연산과 관련 문제 범위에서 행과 열의 대응을 확인합니다.",
            ],
            "pages": [
                page("cm1-220402-open", "opening", "행과 열을 어떻게 곱할까?",
                     block("lead", "오늘의 질문", "두 행렬 A, B의 곱 AB에서 첫째 행 둘째 열의 값은 어떻게 정할까요?"),
                     block("thinking", "예측", "A의 어느 줄과 B의 어느 줄을 짝지어야 할지 행·열로 표현해 보세요.")),
                page("cm1-220402-concept", "concept", "같은 위치끼리, 행과 열끼리",
                     block("definition", "기본 연산", "덧셈과 뺄셈은 같은 위치의 성분끼리 계산하고, 실수배는 모든 성분에 실수를 곱합니다."),
                     block("visual", "곱셈 규칙", "AB의 (i,j) 성분은 A의 i번째 행과 B의 j번째 열을 곱해 더합니다.", formula="(AB)ᵢⱼ=Σₖ aᵢₖbₖⱼ"),
                     block("misconception", "곱의 순서", "행렬의 곱은 일반적으로 순서를 바꾸면 값이 달라집니다. AB와 BA를 따로 계산해 확인합니다.")),
                page("cm1-220402-example", "example", "연산을 차례로 계산하기",
                     block("question", "예제", "A=[[1,2],[0,−1]], B=[[3,−1],[2,4]]일 때 A+B, A−B, 2A, AB를 구하세요."),
                     block("solutionStep", "성분별 연산", "A+B=[[4,1],[2,3]], A−B=[[−2,3],[−2,−5]], 2A=[[2,4],[0,−2]]입니다."),
                     block("solutionStep", "행과 열의 곱", "AB의 첫째 행은 [1,2]입니다. B의 두 열과 계산하면 첫째 행은 [1·3+2·2, 1·(−1)+2·4]=[7,7]입니다."),
                     block("answer", "곱의 결과", "둘째 행까지 계산하면 AB=[[7,7],[−2,−4]]입니다."),
                     block("verification", "순서 비교", "BA=[[3,7],[2,0]]이므로 AB와 BA는 서로 다릅니다.")),
                page("cm1-220402-practice", "practice", "곱의 한 성분 계산하기",
                     block("question", "연습", "같은 A, B에서 AB의 첫째 행 둘째 열 성분을 계산하고, 사용한 행과 열을 적으세요."),
                     block("hint", "힌트", "A의 첫째 행 [1,2]와 B의 둘째 열 [−1,4]를 짝지어 곱하고 더합니다."),
                     block("answer", "정답과 검산", "1·(−1)+2·4=7입니다. 전체 곱 AB의 첫째 행 둘째 열과 일치합니다.")),
                page("cm1-220402-activity", "experiment", "곱의 성분 확인",
                     block("lead", "직접 확인", "AB의 첫째 행 둘째 열 성분을 입력합니다."),
                     {"type": "activity", "activity": {
                         "id": "cm1-220402-ab12", "kind": "quiz",
                         "prompt": "A=[[1,2],[0,−1]], B=[[3,−1],[2,4]]일 때 AB의 첫째 행 둘째 열 성분을 입력하세요.",
                         "answer": 7, "tolerance": 0,
                         "correct_feedback": "맞습니다. 첫째 행 [1,2]와 둘째 열 [−1,4]의 곱의 합은 7입니다.",
                         "incorrect_feedback": "AB의 해당 성분에는 A의 첫째 행과 B의 둘째 열이 필요합니다.",
                         "hints": ["1×(−1)+2×4를 계산합니다.", "행렬 곱은 같은 위치끼리 곱하는 연산이 아닙니다."],
                     }}),
                page("cm1-220402-summary", "summary", "연산 규칙을 구분하기",
                     block("summary", "핵심 정리", "덧셈·뺄셈은 같은 자리, 실수배는 모든 성분, 곱셈은 행과 열의 곱의 합으로 계산합니다."),
                     block("checklist", "스스로 점검", "AB를 계산할 때 각 결과 성분에 사용한 행과 열을 표시했나요?")),
            ],
        },
    ]


def validate(book: dict[str, object]) -> None:
    assert book["standard_codes"] == ["10공수1-02-07", "10공수1-02-08", "10공수1-04-02"]
    ids: set[str] = set()
    activities = []
    chapters = book["chapters"]
    assert len(chapters) == 3
    for chapter in chapters:
        assert len(chapter["pages"]) == 6
        for page_item in chapter["pages"]:
            assert page_item["id"] not in ids
            ids.add(page_item["id"])
            for content in page_item["blocks"]:
                if content.get("type") == "activity":
                    activity = content["activity"]
                    activities.append(activity)
                    assert activity["kind"] == "quiz"
                    assert activity["id"] not in ids
                    ids.add(activity["id"])
                    assert activity["correct_feedback"] and activity["incorrect_feedback"]
                    assert len(activity.get("hints", [])) <= 8
    assert len(activities) == 3
    # Arithmetic checks for the worked examples and numeric quiz keys.
    assert all(x**3 - 2 * x**2 - 5 * x + 6 == 0 for x in (-2, 1, 3))
    assert all(x**4 - 5 * x**2 + 4 == 0 for x in (-2, -1, 1, 2))
    assert all(x**3 - x**2 - 4 * x + 4 == 0 for x in (-2, 1, 2))
    assert all(x + y == 5 and x*x + y*y == 13 for x, y in ((2, 3), (3, 2)))
    assert all(x + y == 4 and x*x + y*y == 10 for x, y in ((1, 3), (3, 1)))
    a, b = ((1, 2), (0, -1)), ((3, -1), (2, 4))
    ab = tuple(tuple(sum(a[i][k] * b[k][j] for k in range(2)) for j in range(2)) for i in range(2))
    ba = tuple(tuple(sum(b[i][k] * a[k][j] for k in range(2)) for j in range(2)) for i in range(2))
    assert ab == ((7, 7), (-2, -4)) and ba == ((3, 7), (2, 0))
    assert all(activity["answer"] == answer for activity, answer in zip(activities, (3, 3, 7)))


def main() -> None:
    book: dict[str, object] = {
        "schema_version": 2,
        "title": "공통수학1 개념서 · 2022 개정 추가 단원 후보",
        "subtitle": "미연결 성취기준 3개를 위한 새 집필 초안",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2022",
        "tags": [
            "공통수학1", "2022 개정", "추가 단원 후보",
            "10공수1-02-07", "10공수1-02-08", "10공수1-04-02",
        ],
        "standard_codes": ["10공수1-02-07", "10공수1-02-08", "10공수1-04-02"],
        "chapters": make_chapters(),
    }
    validate(book)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile("w", encoding="utf-8", newline="\n", dir=OUT.parent, delete=False) as handle:
        temp = Path(handle.name)
        json.dump(book, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    temp.replace(OUT)
    PACKAGE.mkdir(parents=True, exist_ok=True)
    (PACKAGE / "README.md").write_text(
        "# 공통수학1 추가 3단원 후보\n\n"
        "원본 BookData: [`" + OUT.name + "`](../" + OUT.name + ")\n\n"
        "삼·사차방정식, 연립이차방정식, 행렬 연산의 새 집필 초안이다. 공식 HWP XHTML 본표에서 확인한 성취기준 3개와 연결했다. 18쪽과 네이티브 quiz activity 3개를 담았고 기존 통합 교재에는 아직 병합하지 않았다. 교사·수학·권리 검토는 별도 승인 전까지 대기한다.\n",
        encoding="utf-8",
    )
    book_hash = canonical_file_sha256(OUT)
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    previous_manifest = {}
    if manifest_path.is_file():
        try:
            previous_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            previous_manifest = {}
    validation_current = previous_manifest.get("bookdata_sha256") == book_hash
    manifest = {
        "bookdata_file": OUT.name,
        "bookdata_sha256": book_hash,
        "candidate_code_references": ["10공수1-02-07", "10공수1-02-08", "10공수1-04-02"],
        "candidate_code_reference_type": "official_hwp_criterion_table",
        "module_count": 3,
        "page_count": 18,
        "native_activity_count": 3,
        "native_activity_kinds": ["quiz"],
        "curriculum_review_status": "pending",
        "math_review_status": "pending_full_review",
        "math_arithmetic_check_status": "pass_for_listed_examples_only",
        "math_arithmetic_check_scope": "generator assertions for displayed roots, solution pairs and matrix products; not a full content review or teacher review",
        "teacher_review_status": "pending",
        "rights_status": "unknown",
        "integration_status": "not_merged_into_master_book",
        "publication_eligibility": "not_eligible",
        "runtime_import_status": previous_manifest.get("runtime_import_status", "pending_final_validation") if validation_current else "pending_final_validation",
        "runtime_validator_head": previous_manifest.get("runtime_validator_head") if validation_current else None,
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote 3 resumable V2 candidate modules, 18 pages, 3 native quizzes: {OUT}")


if __name__ == "__main__":
    main()
