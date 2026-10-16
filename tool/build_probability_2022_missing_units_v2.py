"""Build three original, resumable V2 drafts for verified 2022 probability standards."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "확률과통계_2022개정_확률누락3단원_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "확률과통계_2022개정_확률누락3단원_원고패키지"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
EXPECTED = {
    "12확통02-02": "확률의 덧셈정리를 이해하고, 이를 활용하여 문제를 해결할 수 있다",
    "12확통02-03": "여사건의 확률을 이해하고, 이를 활용하여 문제를 해결할 수 있다",
    "12확통02-04": "조건부확률을 이해하고, 이를 실생활과 연결하여 문제를 해결할 수 있다",
}


def b(kind: str, title: str, text: str, **extra: object) -> dict[str, object]:
    return {"type": kind, "title": title, "text": text, **extra}


def page(pid: str, template: str, title: str, *blocks: dict[str, object]) -> dict[str, object]:
    return {"id": pid, "template": template, "title": title, "blocks": list(blocks)}


def activity(pid: str, prompt: str, options: list[str], answer: int, correct: str, incorrect: str, hints: list[str]) -> dict[str, object]:
    return {"type": "activity", "activity": {
        "id": pid, "kind": "quiz", "prompt": prompt, "options": options,
        "correct_index": answer, "correct_feedback": correct,
        "incorrect_feedback": incorrect, "hints": hints,
    }}


def chapters() -> list[dict[str, object]]:
    specs = [
        {
            "code": "12확통02-02", "title": "두 사건이 함께 일어날 가능성 더하기",
            "question": "독서 모임 A에 참여할 확률은 0.40, 과학 모임 B에 참여할 확률은 0.35, 두 모임에 모두 참여할 확률은 0.15이다. 적어도 한 모임에 참여할 확률을 구해 보세요.",
            "solve": "P(A∪B)=P(A)+P(B)−P(A∩B)=0.40+0.35−0.15=0.60입니다. 두 사건이 겹치는 0.15를 한 번 빼야 중복 계산을 바로잡습니다.",
            "practice": "P(C)=0.5, P(D)=0.3, P(C∩D)=0.1일 때 P(C∪D)를 구하세요.",
            "answer": "0.5+0.3−0.1=0.7입니다. 교집합이 주어졌다면 합에서 한 번 빼야 합니다.",
            "prompt": "P(A)=0.4, P(B)=0.35, P(A∩B)=0.15일 때 P(A∪B)는?",
            "options": ["0.60", "0.75", "0.90"], "correct": 0,
            "feedback": "겹치는 부분을 한 번 빼면 0.40+0.35−0.15=0.60입니다.",
            "incorrect": "두 사건이 모두 일어나는 부분이 합에서 두 번 세어졌는지 확인하세요.",
            "hints": ["두 확률을 더하면 교집합은 두 번 포함됩니다.", "교집합 확률을 한 번 빼세요."],
        },
        {
            "code": "12확통02-03", "title": "일어나지 않을 사건으로 계산하기",
            "question": "공정한 동전을 세 번 던질 때 앞면이 한 번 이상 나올 확률을 구해 보세요.",
            "solve": "앞면이 한 번 이상 나오는 사건의 여사건은 세 번 모두 뒷면이 나오는 사건입니다. 여사건의 확률은 (1/2)³=1/8이므로 구하는 확률은 1−1/8=7/8입니다.",
            "practice": "공정한 주사위를 두 번 던질 때 적어도 한 번 6이 나올 확률을 구하세요.",
            "answer": "여사건은 두 번 모두 6이 아닌 경우이고 확률은 (5/6)²=25/36입니다. 따라서 구하는 확률은 1−25/36=11/36입니다.",
            "prompt": "공정한 동전을 세 번 던져 앞면이 한 번 이상 나올 확률은?",
            "options": ["7/8", "1/8", "3/8"], "correct": 0,
            "feedback": "여사건인 세 번 모두 뒷면의 확률 1/8을 1에서 빼면 7/8입니다.",
            "incorrect": "'한 번 이상'의 여사건을 먼저 쓰고 그 확률을 계산하세요.",
            "hints": ["여사건은 세 번 모두 뒷면입니다.", "P(A)=1−P(A의 여사건)을 이용하세요."],
        },
        {
            "code": "12확통02-04", "title": "조건이 주어졌을 때의 확률",
            "question": "한 카드 모음에는 빨간 카드 12장과 검은 카드 8장이 있다. 빨간 카드 중 그림 카드가 5장이다. 뽑은 카드가 빨간색임을 알 때, 그림 카드일 확률은 얼마인가요?",
            "solve": "빨간색이라는 조건 아래 가능한 카드는 12장으로 줄어듭니다. 그중 그림 카드는 5장이므로 조건부확률은 5/12입니다. 전체 20장을 분모로 쓰지 않도록 조건을 먼저 적용합니다.",
            "practice": "가상의 설문 응답자 30명 중 버스를 이용하는 사람은 18명이고, 그중 6명이 환승한다. 버스 이용자라는 조건 아래 환승할 확률을 구하세요.",
            "answer": "조건을 만족하는 버스 이용자 18명 가운데 환승자는 6명이므로 6/18=1/3입니다. 이는 이 문항에 제시한 가상 표본에서의 비율입니다.",
            "prompt": "빨간 카드 12장 중 그림 카드 5장이 있습니다. 빨간 카드라는 조건 아래 그림 카드일 확률은?",
            "options": ["5/12", "5/20", "12/20"], "correct": 0,
            "feedback": "조건을 만족하는 12장만 분모에 두므로 확률은 5/12입니다.",
            "incorrect": "조건이 주어지면 가능한 표본 공간을 그 조건에 맞게 줄이세요.",
            "hints": ["빨간색이라는 조건에서 가능한 카드 수는 12장입니다.", "그 12장 가운데 그림 카드 수를 분자로 두세요."],
        },
    ]
    result = []
    for spec in specs:
        code = spec["code"]
        short = code.replace("12확통", "p").replace("-", "")
        result.append({
            "title": spec["title"], "intro": [f"공식 기준 {code}에 연결한 새 집필 후보입니다.", "확률을 구한 뒤 사건과 표본 공간이 뜻하는 바를 말로 설명합니다."],
            "pages": [
                page(f"{short}-open", "opening", "먼저 예상하기", b("lead", "상황", spec["question"]), b("thinking", "질문", "어떤 결과를 세고, 전체 가능한 결과는 무엇인지 먼저 정리하세요.")),
                page(f"{short}-concept", "concept", "개념과 표현", b("definition", "핵심", spec["title"]), b("formula", "기준", code), b("misconception", "주의", "사건이 겹치는 부분, 여사건, 조건이 정한 표본 공간을 구별합니다.")),
                page(f"{short}-example", "example", "예제와 풀이", b("question", "예제", spec["question"]), b("solutionStep", "풀이", spec["solve"]), b("verification", "확인", "확률은 0 이상 1 이하이며 분모는 질문에서 정한 표본 공간을 나타냅니다.")),
                page(f"{short}-practice", "practice", "연습과 해설", b("question", "연습", spec["practice"]), b("hint", "Socratic 힌트", "어떤 사건을 세는지와 분모에 들어갈 조건을 먼저 말해 보세요."), b("solutionStep", "해설", spec["answer"]), b("answer", "정답", spec["answer"]), activity(f"{short}-quiz", spec["prompt"], spec["options"], spec["correct"], spec["feedback"], spec["incorrect"], spec["hints"])),
                page(f"{short}-summary", "summary", "핵심 정리", b("summary", "기억할 점", spec["title"]), b("checklist", "스스로 점검", "계산식에서 각 확률이 사건·조건과 맞는지 설명할 수 있나요?")),
            ],
        })
    return result


def main() -> None:
    standard_rows = json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]
    official = {row["code"]: row["criterion"].rstrip(" .") for row in standard_rows}
    missing = [code for code, criterion in EXPECTED.items() if official.get(code) != criterion]
    if missing:
        raise RuntimeError(f"Official 2022 standard table mismatch: {missing}")
    chapter_data = chapters()
    book = {
        "schema_version": 2,
        "title": "확률과 통계 · 확률 단원 추가 3모듈 후보",
        "subtitle": "덧셈정리·여사건·조건부확률",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2022",
        "tags": ["확률과 통계", "2022 개정", "추가 단원 후보", "학기 배정 미확정"],
        "standard_codes": list(EXPECTED),
        "chapters": chapter_data,
    }
    codes = set(book["standard_codes"])
    ids: set[str] = set()
    activities = []
    for chapter in chapter_data:
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
    if len(codes) != 3 or len(activities) != 3 or [a["correct_index"] for a in activities] != [0, 0, 0]:
        raise RuntimeError("Draft scope or quiz coverage mismatch")
    assert 0.40 + 0.35 - 0.15 == 0.60
    assert 1 - (1 / 2) ** 3 == 7 / 8
    assert 5 / 12 == 0.4166666666666667
    assert abs((1 - (5 / 6) ** 2) - 11 / 36) < 1e-12
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    book_hash = canonical_file_sha256(OUT)
    old_path = PACKAGE / "REVIEW_MANIFEST.json"
    try:
        old_manifest = json.loads(old_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old_manifest = {}
    same_hash = old_manifest.get("bookdata_sha256") == book_hash
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": book_hash,
        "candidate_code_references": list(EXPECTED), "candidate_code_reference_type": "official_hwp_criterion_table",
        "module_count": 3, "page_count": 15, "native_activity_count": 3, "native_activity_kinds": ["quiz"],
        "curriculum_review_status": "official_codes_mapped; semester_and_full_scope_pending",
        "math_review_status": "pending_full_review", "math_arithmetic_check_status": "pass_for_listed_examples_only",
        "teacher_review_status": "pending", "rights_status": "newly_authored; publication_rights_decision_pending",
        "integration_status": "not_merged_into_master_book", "publication_eligibility": "not_eligible",
        "runtime_import_status": old_manifest.get("runtime_import_status", "pending_current_hash_validation") if same_hash else "pending_current_hash_validation",
        "runtime_validator_head": old_manifest.get("runtime_validator_head") if same_hash else None,
    }
    old_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        f"# {book['title']}\n\n"
        "신규 집필 3모듈·15쪽 후보이며, 공식 HWP 본표에서 확인한 덧셈정리·여사건·조건부확률 기준에 연결합니다. "
        "확률 계산 assertion과 V2 quiz 3개를 포함합니다. 이 자료는 교사·수학 검수, 학기 배정, 권리 결정, 통합·게시 승인을 받지 않았습니다.\n\n"
        f"BookData: [`{OUT.name}`](../{OUT.name})\n",
        encoding="utf-8",
    )
    print(f"Built {len(chapter_data)} probability modules, 15 pages, 3 native quizzes: {OUT}")


if __name__ == "__main__":
    main()
