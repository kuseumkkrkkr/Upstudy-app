"""Build eight original V2 drafts for the remaining untagged 2022 probability/statistics standards."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "확률과통계_2022개정_확률통계누락8단원_Batch3_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "확률과통계_2022개정_확률통계누락8단원_Batch3_원고패키지"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
EXPECTED = {
    "12확통01-01": "중복순열, 같은 것이 있는 순열을 이해하고, 그 순열의 수를 구하는 방법을 설명할 수 있다",
    "12확통01-02": "중복조합을 이해하고, 중복조합의 수를 구하는 방법을 설명할 수 있다",
    "12확통01-03": "이항정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다",
    "12확통03-03": "이항분포의 뜻과 성질을 이해하고, 평균과 표준편차를 구할 수 있다",
    "12확통03-04": "정규분포의 뜻과 성질을 이해하고, 이항분포와의 관계를 설명할 수 있다",
    "12확통03-05": "모집단과 표본의 뜻을 알고, 표본추출의 방법을 설명할 수 있다",
    "12확통03-06": "표본평균과 모평균, 표본비율과 모비율의 관계를 이해하고 설명할 수 있다",
    "12확통03-07": "공학 도구를 이용하여 모평균 및 모비율을 추정하고 그 결과를 해석할 수 있다",
}

SPECS = [
    {
        "code": "12확통01-01", "title": "중복되는 선택이 있는 순열 세기",
        "lead": "가상 행사에서 세 자리 기호를 A, B, C 중 골라 만들며 같은 기호를 여러 번 쓸 수 있다. 가능한 기호열은 몇 개인가요? 또 A, A, B를 일렬로 놓는 방법은 몇 개인가요?",
        "concept": "중복순열은 각 자리에 같은 선택지를 다시 사용할 수 있는 순열이다. 같은 것이 있는 순열은 전체 자리의 순열 수에서 서로 바꾸어도 같은 배열이 되는 중복 순열을 나눈다.",
        "example": "세 자리에 A, B, C를 각각 선택할 수 있으므로 3³=27가지다. A, A, B의 배열은 3!/2!=3가지다.",
        "practice": "문자 A, A, B, B, C 다섯 개를 모두 일렬로 배열하는 방법은 몇 가지인가요?",
        "answer": "같은 A 두 개와 B 두 개가 각각 서로 바뀌는 중복을 나누어 5!/(2!2!)=30가지입니다.",
        "prompt": "A, A, B, B, C 다섯 문자의 서로 다른 배열 수는?", "options": ["30", "60", "120"], "correct": 0,
        "feedback": "5!에서 같은 A끼리 2!, 같은 B끼리 2!만큼 중복된 배열을 나누면 30입니다.",
        "wrong": "같은 문자끼리 서로 바꾸어도 같은 배열이라는 점을 반영하세요.", "hints": ["일단 다섯 문자를 구별하면 5!입니다.", "A 두 개와 B 두 개의 중복을 각각 나눕니다."],
    },
    {
        "code": "12확통01-02", "title": "같은 종류를 여러 번 고르는 조합",
        "lead": "가상 아이스크림 가게에 맛이 세 가지 있다. 맛의 순서는 따지지 않고 다섯 스쿱을 고르며 한 맛을 여러 번 골라도 된다. 선택 방법은 몇 가지일까요?",
        "concept": "중복조합은 서로 다른 n종류 중에서 같은 종류를 여러 번 허용하여 r개를 순서 없이 고르는 방법이다. 개수는 nHr=C(n+r−1,r)로 계산할 수 있다.",
        "example": "세 맛에서 다섯 스쿱을 고르는 방법은 3H5=C(3+5−1,5)=C(7,5)=21가지다. 맛을 고르는 순서는 구별하지 않는다.",
        "practice": "세 종류 간식에서 중복을 허용해 네 개를 순서 없이 고르는 방법 수를 구하세요.",
        "answer": "3H4=C(3+4−1,4)=C(6,4)=15가지입니다.",
        "prompt": "세 맛 중에서 다섯 스쿱을 순서 없이 고르는 중복조합의 수는?", "options": ["21", "15", "243"], "correct": 0,
        "feedback": "3H5=C(7,5)=21입니다. 243은 다섯 자리 순서를 구별하는 중복순열 수입니다.",
        "wrong": "순서를 구별하지 않고 같은 맛을 반복 선택하므로 중복조합을 사용합니다.", "hints": ["nH r=C(n+r−1,r)를 적용합니다.", "3H5=C(7,5)입니다."],
    },
    {
        "code": "12확통01-03", "title": "이항정리로 항의 계수 찾기",
        "lead": "가상 다항식 (x+y)⁵을 전개하지 않고 x³y²의 계수를 찾으려면 어떤 조합 수를 보면 될까요?",
        "concept": "이항정리는 (a+b)ⁿ=Σ C(n,r)aⁿ⁻ʳbʳ이다. 특정 항의 계수는 해당 항을 만들 선택 횟수의 조합으로 얻는다.",
        "example": "x³y²는 다섯 인수 중 y를 두 번 선택한 항이므로 계수는 C(5,2)=10이다.",
        "practice": "(2x+1)⁴에서 x²의 계수를 구하세요.",
        "answer": "x² 항은 C(4,2)(2x)²에서 나오므로 계수는 6×4=24입니다.",
        "prompt": "(x+y)⁵에서 x³y²의 계수는?", "options": ["10", "5", "20"], "correct": 0,
        "feedback": "y를 다섯 인수 중 두 곳에서 고르는 C(5,2)=10가지입니다.",
        "wrong": "x³y²가 되려면 다섯 인수 중 y를 정확히 두 번 골라야 합니다.", "hints": ["이항정리의 일반항에서 지수를 맞춥니다.", "계수는 C(5,2)입니다."],
    },
    {
        "code": "12확통03-03", "title": "이항분포의 평균과 표준편차",
        "lead": "공정한 동전을 네 번 던져 앞면 수 X를 센다. 각 시행은 독립이고 앞면 확률은 1/2이다. X의 평균과 표준편차를 구해 보세요.",
        "concept": "독립인 베르누이 시행 n회에서 성공확률이 p로 일정하면 성공 횟수 X는 이항분포 B(n,p)를 따른다. 평균은 np, 표준편차는 √(np(1−p))이다.",
        "example": "X~B(4,1/2)이므로 평균은 4×1/2=2, 표준편차는 √(4×1/2×1/2)=1이다. 성공은 앞면으로 정했다.",
        "practice": "성공확률 0.2인 독립 시행을 25회 할 때 성공 횟수의 평균과 표준편차를 구하세요.",
        "answer": "평균은 25×0.2=5이고 표준편차는 √(25×0.2×0.8)=2입니다.",
        "prompt": "X~B(4, 1/2)일 때 평균은?", "options": ["2", "1", "4"], "correct": 0,
        "feedback": "이항분포의 평균은 np이므로 4×1/2=2입니다.",
        "wrong": "평균 공식 np에서 시행 횟수와 성공확률을 확인하세요.", "hints": ["n=4, p=1/2입니다.", "평균은 np입니다."],
    },
    {
        "code": "12확통03-04", "title": "이항분포와 정규분포의 관계",
        "lead": "가상 품질 검사를 100회 반복하고 각 검사에서 결함일 확률이 1/2이라고 가정한다. 결함 개수 X는 B(100,1/2)로 나타낼 수 있다. 평균과 표준편차를 구하고 큰 시행 횟수에서의 분포 모양을 설명해 보세요.",
        "concept": "정규분포는 평균을 중심으로 대칭인 연속확률분포다. 이항분포에서 n이 충분히 크고 np와 n(1−p)가 모두 충분히 크면 정규분포로 근사할 수 있다. 근사는 정확한 동일성이 아니다.",
        "example": "X~B(100,1/2)의 평균은 50, 표준편차는 5다. 시행 횟수가 크고 양쪽 기대 횟수도 충분하므로 종 모양인 정규분포로 근사하는 상황을 설명할 수 있다.",
        "practice": "B(100,0.4)의 평균과 표준편차를 구하고 정규근사 조건 두 수 np, n(1−p)를 확인하세요.",
        "answer": "평균은 40, 표준편차는 √24≈4.90이다. np=40, n(1−p)=60이 모두 충분히 큰 편이므로 근사 사용을 검토할 수 있지만 이항분포와 정규분포가 같다는 뜻은 아니다.",
        "prompt": "X~B(100,1/2)의 평균은?", "options": ["50", "25", "100"], "correct": 0,
        "feedback": "이항분포의 평균은 np=100×1/2=50입니다.",
        "wrong": "정규근사 여부와 관계없이 평균은 이항분포의 np로 계산합니다.", "hints": ["n=100, p=1/2입니다.", "평균은 np입니다."],
    },
    {
        "code": "12확통03-05", "title": "모집단과 표본, 추출 방법",
        "lead": "가상 학교의 재학생 전체 의견을 알고 싶지만 전원에게 묻기 어렵다. 전체 학생과 조사에 참여한 일부 학생을 각각 무엇이라 부를까요?",
        "concept": "조사 대상 전체가 모집단이고, 모집단에서 뽑아 실제로 조사한 일부가 표본이다. 단순임의·층화·계통·집락추출 등은 표본을 구성하는 방법이며 조사 목적과 모집단 구조에 맞게 선택한다.",
        "example": "학년별 의견이 다를 수 있어 각 학년을 층으로 나눈 다음 각 층에서 무작위로 학생을 뽑는 방법은 층화추출이다. 학년별 비율을 반영할 수 있다.",
        "practice": "가상 학교 1~3학년 학생 수가 다를 때 각 학년에서 일정 비율을 무작위 추출하려 한다. 적합한 방법과 이유를 쓰세요.",
        "answer": "층화추출이 적합하다. 학년을 층으로 나누어 각 층에서 뽑으므로 모든 학년이 표본에 반영되도록 설계할 수 있다.",
        "prompt": "모집단의 각 학년을 층으로 나눈 뒤 각 층에서 무작위로 뽑는 방법은?", "options": ["층화추출", "집락추출", "계통추출"], "correct": 0,
        "feedback": "모집단을 층으로 나누고 각 층에서 표본을 뽑으므로 층화추출입니다.",
        "wrong": "먼저 모집단을 어떤 집단으로 나누고 각 집단에서 표본을 뽑는지 살펴보세요.", "hints": ["학년별로 나누어 각 학년을 포함합니다.", "각 층 안에서 무작위 추출합니다."],
    },
    {
        "code": "12확통03-06", "title": "표본평균·표본비율과 모집단 모수",
        "lead": "가상 모집단의 40%가 자전거 통학을 한다. 무작위 표본 50명 중 18명이 자전거 통학을 한다면 표본비율은 얼마이며 모비율과 어떻게 비교해야 할까요?",
        "concept": "모평균과 모비율은 모집단의 특성을 나타내는 모수이고, 표본평균과 표본비율은 표본에서 계산한 통계량이다. 적절한 무작위 표본에서는 표본 통계량이 모수를 추정하지만 표본마다 변동한다.",
        "example": "표본비율은 18/50=0.36이다. 가정한 모비율 0.40과 같지 않지만 무작위 표본에서 가능한 변동이며, 한 표본의 값만으로 모비율을 확정하지 않는다.",
        "practice": "가상 모집단의 평균 통학시간이 20분이다. 크기 4인 무작위 표본의 통학시간이 18, 19, 21, 22분이면 표본평균을 구하고 모평균과의 관계를 설명하세요.",
        "answer": "표본평균은 (18+19+21+22)/4=20분이다. 이번 표본에서는 모평균과 같지만 다른 표본에서는 달라질 수 있다.",
        "prompt": "표본 50명 중 18명이 해당 사건을 경험했다. 표본비율은?", "options": ["0.36", "0.40", "0.18"], "correct": 0,
        "feedback": "표본비율은 성공 횟수를 표본 크기로 나눈 18/50=0.36입니다.",
        "wrong": "표본비율은 표본에서 해당 사건이 관측된 비율입니다.", "hints": ["분자는 해당 사건을 경험한 수입니다.", "18을 50으로 나눕니다."],
    },
    {
        "code": "12확통03-07", "title": "공학 도구로 모수 추정하고 해석하기",
        "lead": "가상 설문에서 무작위로 뽑은 50명 중 28명이 대중교통을 선호했다. 계산기나 스프레드시트로 표본비율을 구해 모비율을 어떻게 추정할지 설명해 보세요.",
        "concept": "표본평균은 모평균의 점추정값으로, 표본비율은 모비율의 점추정값으로 사용된다. 공학 도구는 자료 입력·계산·요약을 도울 수 있으며 추정값은 표본에 따른 불확실성을 가진다.",
        "example": "가상 표본의 선호 비율은 28/50=0.56이다. 이를 모비율의 점추정값으로 제시할 수 있지만, 실제 모비율이 정확히 0.56이라고 단정할 수는 없다.",
        "practice": "가상 무작위 표본 6개의 측정값이 8, 9, 10, 10, 11, 12이다. 스프레드시트 평균 기능으로 모평균을 추정하고 해석할 때 주의할 점을 쓰세요.",
        "answer": "표본평균은 60/6=10이다. 이를 모평균의 추정값으로 사용하지만 표본 크기와 추출 변동 때문에 모평균과 다를 수 있다.",
        "prompt": "가상 무작위 표본 50명 중 28명이 선호했다. 표본비율을 모비율의 추정값으로 쓰면 얼마인가요?", "options": ["0.56", "0.28", "0.50"], "correct": 0,
        "feedback": "28/50=0.56이 표본비율이며 모비율의 점추정값으로 해석할 수 있습니다.",
        "wrong": "표본에서 관측된 비율을 계산한 뒤 추정값과 실제 모수를 구분하세요.", "hints": ["분자는 28, 표본 크기는 50입니다.", "표본비율 28/50을 계산합니다."],
    },
]


def block(kind: str, title: str, text: str, **extra: object) -> dict[str, object]:
    return {"type": kind, "title": title, "text": text, **extra}


def page(pid: str, template: str, title: str, *blocks: dict[str, object]) -> dict[str, object]:
    return {"id": pid, "template": template, "title": title, "blocks": list(blocks)}


def make_quiz(spec: dict[str, object], pid: str) -> dict[str, object]:
    return {"type": "activity", "activity": {
        "id": pid, "kind": "quiz", "prompt": spec["prompt"], "options": spec["options"],
        "correct_index": spec["correct"], "correct_feedback": spec["feedback"],
        "incorrect_feedback": spec["wrong"], "hints": spec["hints"],
    }}


def make_estimator(pid: str, prompt: str, statistics: dict[str, object], hints: list[str]) -> dict[str, object]:
    return {"type": "activity", "activity": {
        "id": pid, "kind": "statisticsEstimator", "prompt": prompt,
        "statistics": statistics, "hints": hints,
    }}


def main() -> None:
    rows = json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]
    official = {item["code"]: item["criterion"].rstrip(" .") for item in rows}
    mismatch = {code: (official.get(code), criterion) for code, criterion in EXPECTED.items() if official.get(code) != criterion}
    if mismatch:
        raise RuntimeError(f"Official HWP table mismatch: {mismatch}")
    chapters = []
    for spec in SPECS:
        short = spec["code"].replace("12확통", "ps").replace("-", "")
        chapters.append({
            "title": spec["title"],
            "intro": [f"공식 기준 {spec['code']}에 연결한 새 집필 후보입니다.", "사례·표본 수치·조사 상황은 개념을 연습하기 위해 만든 가상 예시입니다."],
            "pages": [
                page(f"{short}-open", "opening", "상황에서 질문 만들기", block("lead", "가상 예시", spec["lead"]), block("thinking", "먼저 생각하기", "무엇을 세거나 추정하며, 어떤 조건을 사용했는지 확인합니다.")),
                page(f"{short}-concept", "concept", "정의와 규칙", block("definition", "핵심 개념", spec["concept"]), block("formula", "공식 기준", spec["code"]), block("misconception", "주의", "표본 통계량과 모집단 모수, 정확한 분포와 근사 분포를 혼동하지 않습니다.")),
                page(f"{short}-example", "example", "예제와 풀이", block("question", "예제", spec["lead"]), block("solutionStep", "풀이", spec["example"]), block("verification", "검산", "조건·계산·해석이 가상 자료에 일관되는지 확인합니다.")),
                page(f"{short}-practice", "practice", "연습과 설명", block("question", "연습", spec["practice"]), block("hint", "Socratic 힌트", "필요한 수치와 그 수치가 나타내는 사건·표본을 먼저 나누어 적으세요."), block("solutionStep", "해설", spec["answer"]), block("answer", "정답", spec["answer"]), make_quiz(spec, f"{short}-quiz"), *(
                    [
                        make_estimator(f"{short}-estimate-mean", "가상 표본 8, 9, 10, 10, 11, 12로 모평균을 추정해 보세요.", {"mode": "mean", "sample_values": [8, 9, 10, 10, 11, 12]}, ["표본 값의 합과 개수를 확인하세요.", "표본평균을 모평균의 추정값으로 해석하세요."]),
                        make_estimator(f"{short}-estimate-proportion", "가상 표본 50명 중 28명이 선호했습니다. 모비율을 추정해 보세요.", {"mode": "proportion", "successes": 28, "trials": 50}, ["성공 수를 표본 크기로 나누세요.", "표본비율을 모비율의 추정값으로 해석하세요."]),
                    ] if spec["code"] == "12확통03-07" else []
                )),
                page(f"{short}-summary", "summary", "핵심 정리", block("summary", "기억할 점", spec["title"]), block("checklist", "스스로 확인", "공식과 결과가 무엇을 세거나 추정하는지 말할 수 있나요?")),
            ],
        })
    book = {
        "schema_version": 2, "title": "확률과 통계 · 조합·분포·추정 추가 8모듈 후보",
        "subtitle": "중복순열·중복조합·이항정리·분포·표본과 추정",
        "category": "concept_textbook_prototype", "curriculum_version": "2022",
        "tags": ["확률과 통계", "2022 개정", "추가 원고 후보", "가상 예시", "학기 배정 미확정"],
        "standard_codes": list(EXPECTED), "chapters": chapters,
    }
    ids, activities = set(), []
    for chapter in chapters:
        if len(chapter["pages"]) != 5:
            raise RuntimeError("Each module must contain exactly five pages")
        for page_item in chapter["pages"]:
            if page_item["id"] in ids:
                raise RuntimeError("Duplicate page id")
            ids.add(page_item["id"])
            for content in page_item["blocks"]:
                if content.get("type") == "activity":
                    activity = content["activity"]
                    if activity["id"] in ids:
                        raise RuntimeError("Duplicate activity id")
                    ids.add(activity["id"])
                    activities.append(activity)
    activity_kinds = [activity["kind"] for activity in activities]
    if len(chapters) != 8 or activity_kinds.count("quiz") != 8 or activity_kinds.count("statisticsEstimator") != 2:
        raise RuntimeError("Expected eight quizzes and two 12확통03-07 estimator interactions")
    # Exact arithmetic checks for every numerical claim in the new examples.
    assert 3**3 == 27 and math.factorial(3) // math.factorial(2) == 3
    assert math.factorial(5) // (math.factorial(2) ** 2) == 30
    assert math.comb(7, 5) == 21 and math.comb(6, 4) == 15
    assert math.comb(5, 2) == 10 and math.comb(4, 2) * 2**2 == 24
    assert 4 * 0.5 == 2 and math.sqrt(4 * 0.5 * 0.5) == 1
    assert 25 * 0.2 == 5 and math.sqrt(25 * 0.2 * 0.8) == 2
    assert 100 * 0.5 == 50 and math.sqrt(100 * 0.5 * 0.5) == 5
    assert 100 * 0.4 == 40 and abs(math.sqrt(100 * 0.4 * 0.6) - math.sqrt(24)) < 1e-12
    assert 28 / 50 == 0.56 and sum([8, 9, 10, 10, 11, 12]) / 6 == 10
    assert 18 / 50 == 0.36 and sum([18, 19, 21, 22]) / 4 == 20
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try:
        old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old = {}
    same_hash = old.get("bookdata_sha256") == digest
    alignment = {
        code: ("candidate_statistics_estimator_added_runtime_qa_pending" if code == "12확통03-07" else "content_mapped_pending_teacher_review")
        for code in EXPECTED
    }
    if same_hash and isinstance(old.get("preliminary_module_alignment"), dict):
        alignment.update(old["preliminary_module_alignment"])
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": list(EXPECTED), "candidate_code_reference_type": "official_hwp_criterion_table",
        "module_count": 8, "page_count": 40, "native_activity_count": 10, "native_activity_kinds": ["quiz", "statisticsEstimator"],
        "example_data_status": "synthetic_original_examples; no commercial text, problem, illustration, or dataset copied",
        "curriculum_review_status": "official_codes_mapped; semester_and_full_scope_pending",
        "math_review_status": "pending_full_review", "math_arithmetic_check_status": "pass_for_listed_examples_only",
        "preliminary_module_alignment": alignment,
        "statistics_estimator_qa_status": old.get("statistics_estimator_qa_status", "pending") if same_hash else "pending",
        "statistics_estimator_qa_head": old.get("statistics_estimator_qa_head") if same_hash else None,
        "statistics_estimator_qa_page_id": "ps0307-practice",
        "teacher_review_status": "pending", "rights_status": "newly_authored; publication_rights_decision_pending",
        "integration_status": "not_merged_into_master_book", "publication_eligibility": "not_eligible",
        "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same_hash else "pending_current_hash_validation",
        "runtime_validator_head": old.get("runtime_validator_head") if same_hash else None,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        f"# {book['title']}\n\n"
        "신규 집필 8모듈·40쪽의 재개 가능한 V2 후보입니다. 모든 조사와 수치는 개념 연습을 위해 직접 만든 가상 예시이며 상업 교재의 문장·문제·그림·데이터를 복사하지 않았습니다. "
        "7개 모듈은 기준과 초안 본문을 예비 대조했으나 교사 검토는 남아 있습니다. `12확통03-07`에는 표본평균과 표본비율 추정용 first-class statisticsEstimator를 넣었습니다. QA 상태와 검증 checkout은 manifest에 기록하며 수학·교사 검토 및 권리 결정은 별도 승인 전까지 대기합니다. "
        "과목 전체 완료, 학기 배정, 권리 결정도 대기 중입니다.\n\n"
        f"BookData: [`{OUT.name}`](../{OUT.name})\n",
        encoding="utf-8",
    )
    print(f"Built {len(chapters)} probability/statistics modules, 40 pages, 8 quizzes, 2 statistics estimators: {OUT}")


if __name__ == "__main__":
    main()
