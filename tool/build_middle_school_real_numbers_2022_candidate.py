"""Build original, semester-unassigned 2022 middle-school real-number modules."""

from __future__ import annotations

import importlib.util
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_실수와근호_부분초안"
BOOK_FILE = "중등수학_2022개정_실수와근호_BookData_V2_시범.json"
SQUARE_ROOT_SOURCE_HTML = "docs/advanced-generation-vault/07 Data/교재 원고/중학수학3-1_2022개정_통합시범/중학수학3-1_2022개정_제곱근수직선_체험형_시범.html"
SPECS = [
    {"code": "9수01-06", "slug": "ms22-recurring-decimals", "title": "순환소수와 유리수", "concept": "순환소수는 소수점 아래의 숫자 배열이 일정한 부분부터 반복되는 소수입니다. 순환마디 위에 점을 찍어 나타냅니다. 유리수를 소수로 나타내면 유한소수 또는 순환소수가 되고, 순환소수는 분수로 나타낼 수 있습니다.", "example": "0.272727…을 분수로 나타내세요.", "solution": "x=0.272727…이라 하면 100x=27.272727…입니다. 빼면 99x=27이므로 x=27/99=3/11입니다.", "practice": "0.6666…을 기약분수로 나타내세요.", "answer": "x=0.6666…이면 10x=6.6666…입니다. 빼면 9x=6이므로 x=6/9=2/3입니다.", "quiz": {"id": "ms22-0106-quiz", "kind": "quiz", "prompt": "0.454545…을 기약분수로 나타내면 무엇인가요?", "options": ["5/11", "45/100", "4/9"], "correct_index": 0, "correct_feedback": "순환마디가 45이므로 45/99=5/11입니다.", "incorrect_feedback": "x=0.454545…로 두고 100x−x를 계산하세요.", "hints": ["100x=45.454545…입니다."]}},
    {"code": "9수01-07", "slug": "ms22-square-roots", "title": "제곱근의 뜻과 대소", "concept": "a≥0일 때 √a는 제곱하여 a가 되는 음이 아닌 수입니다. a>0이면 x²=a의 해는 x=√a와 x=−√a 두 개입니다. 양수의 제곱근은 수직선의 대소 관계를 이용해 비교할 수 있습니다.", "example": "√50을 간단히 하고, 7과 8 중 어느 수 사이에 있는지 판단하세요.", "solution": "√50=√(25×2)=5√2입니다. 7²=49<50<64=8²이고 모두 양수이므로 7<√50<8입니다.", "practice": "√72를 간단히 하고 x²=72의 두 해를 나타내세요.", "answer": "√72=√(36×2)=6√2입니다. 따라서 x²=72의 두 해는 x=6√2와 x=−6√2입니다.", "quiz": {"id": "ms22-0107-quiz", "kind": "quiz", "prompt": "√49의 값은 얼마인가요?", "options": ["7", "−7", "±7"], "correct_index": 0, "correct_feedback": "√ 기호는 음이 아닌 제곱근을 뜻하므로 √49=7입니다.", "incorrect_feedback": "√49의 값과 x²=49의 해 두 개를 구별하세요.", "hints": ["7²=49이고 7은 음이 아닙니다."]}},
    {"code": "9수01-09", "slug": "ms22-real-number-order", "title": "실수의 대소 관계", "concept": "실수는 수직선 위의 점과 대응하며, 오른쪽에 있는 수가 더 큽니다. 음이 아닌 두 수의 제곱근은 제곱을 비교해 대소를 판단할 수 있습니다. 음수를 붙이면 대소 관계가 반대로 바뀌므로 부호를 확인해야 합니다.", "example": "2.5와 √7의 대소를 판단하고, −2.5와 −√7의 대소도 비교하세요.", "solution": "2.5²=6.25<7이므로 2.5<√7입니다. 양변에 −1을 곱하면 부등호가 반대로 되어 −2.5>−√7입니다.", "practice": "−√5, −2.1, 0, √5를 작은 수부터 차례로 쓰세요.", "answer": "2.1²=4.41<5이므로 2.1<√5입니다. 부호를 바꾸면 −√5<−2.1입니다. 따라서 −√5<−2.1<0<√5입니다.", "quiz": {"id": "ms22-0109-quiz", "kind": "quiz", "prompt": "2.6과 √7의 대소 관계로 옳은 것은 무엇인가요?", "options": ["2.6<√7", "2.6>√7", "2.6=√7"], "correct_index": 0, "correct_feedback": "2.6²=6.76<7이므로 2.6<√7입니다.", "incorrect_feedback": "두 수가 모두 양수이므로 제곱을 비교하세요.", "hints": ["2.6²를 계산해 7과 비교합니다."]}},
    {"code": "9수01-10", "slug": "ms22-radical-arithmetic", "title": "근호를 포함한 식의 계산", "concept": "근호 안의 수를 제곱수의 곱으로 나타내면 근호를 간단히 할 수 있습니다. 같은 근호끼리는 계수끼리 더하거나 뺍니다. 곱셈·나눗셈은 근호의 성질을 적용하며, 나누는 식이 0이 아닌지 확인합니다.", "example": "3√5−√20을 간단히 하세요.", "solution": "√20=√(4×5)=2√5이므로 3√5−√20=3√5−2√5=√5입니다.", "practice": "√8+√18을 간단히 하고, √6×√24와 √48÷√3도 계산하세요.", "answer": "√8=2√2, √18=3√2이므로 합은 5√2입니다. √6×√24=√144=12이고 √48÷√3=√(48/3)=√16=4입니다.", "quiz": {"id": "ms22-0110-quiz", "kind": "quiz", "prompt": "2√3+√12를 간단히 하면 무엇인가요?", "options": ["4√3", "3√15", "2√15"], "correct_index": 0, "correct_feedback": "√12=2√3이므로 2√3+2√3=4√3입니다.", "incorrect_feedback": "먼저 √12를 간단히 한 뒤 같은 근호끼리 계산하세요.", "hints": ["12=4×3이므로 √12=2√3입니다."]}},
]


def main() -> None:
    official_data = json.loads((ROOT / "work/official-curriculum/2022_math_standards.json").read_text(encoding="utf-8"))
    official = {row["code"]: row["criterion"] for row in official_data["standards"]}
    if any(item["code"] not in official for item in SPECS):
        raise ValueError("A candidate code is absent from the official standards index")
    assert 27 * 11 == 99 * 3 and 6 * 3 == 9 * 2
    assert 7**2 < 50 < 8**2 and 5 * 5 * 2 == 50 and 6 * 6 * 2 == 72
    assert 5**2 < 7 * 2**2 and 21**2 < 5 * 10**2
    assert 12 == 4 * 3 and 2 + 2 == 4 and 3 * 5 - 2 * 5 == 5
    assert 6 * 24 == 144
    assert 48 / 3 == 16 and 16**0.5 == 4

    helper_path = Path(__file__).with_name("build_middle_school_1_2_2022_candidate.py")
    spec = importlib.util.spec_from_file_location("ms22_real_number_helpers", helper_path)
    helper = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(helper)
    chapters = []
    for item in SPECS:
        chapter = helper.make_chapter(
            item["code"], item["slug"], item["title"], item["code"],
            "교재 내 수직선·식 확인 활동", item["title"] + "의 표현을 말과 식으로 설명해 보세요.",
            item["concept"], item["example"], item["solution"], item["practice"], item["answer"],
            [item["title"] + "의 뜻과 성질을 설명한다.", "계산 결과와 대소 관계를 다시 확인한다."],
        )
        chapter["intro"][0] = f"공식 기준: {item['code']} {official[item['code']]}"
        chapter["sections"][0]["paragraphs"][0] = f"기준 후보: {item['code']}. 학년군 기준이며 학기 귀속은 미배정입니다."
        chapter["pages"][1]["blocks"] = [
            {"type": "lead", "title": "직접 계산하고 확인하기", "text": "예제의 수를 수직선이나 식으로 나타내고 계산 과정을 확인합니다."},
            {"type": "thinking", "title": "관찰 질문", "text": "기호·제곱·부호 중 결과를 바꾸는 조건은 무엇인가요?"},
            {"type": "hint", "title": "힌트", "text": "양수·음수와 근호 안의 수를 구분해 한 단계씩 계산하세요."},
            {"type": "answer", "title": "활동 범위", "text": "외부 시뮬레이션 파일 없이 앱 내 지면과 native quiz를 제공합니다."},
        ]
        if item["code"] == "9수01-07":
            chapter["pages"][1]["blocks"].insert(1, {
                "type": "activity",
                "title": "제곱근의 위치 조절",
                "activity": {"id": "ms22-sqrt-number-line", "kind": "squareRootNumberLine", "prompt": "n을 바꾸고 √n의 위치를 수직선에서 확인하세요.", "min": 1, "max": 25, "hints": []},
            })
            chapter["pages"][1]["blocks"][-1] = {
                "type": "answer",
                "title": "확인",
                "text": "점의 위치가 표시된 √n 값과 일치하는지 확인하세요.",
            }
        chapter["pages"][-2]["blocks"].append({"type": "activity", "activity": item["quiz"]})
        chapters.append(chapter)

    codes = [item["code"] for item in SPECS]
    book = {"schema_version": 2, "title": "중등수학 2022 개정 · 실수와 근호 부분 후보", "subtitle": "공식 학년군 기준별 개념·예제·연습·native quiz", "category": "concept_textbook_prototype", "curriculum_version": "2022", "standard_codes": codes, "standard_coverage": "partial", "grade_semester_status": "not_assigned", "tags": ["중등수학", "2022 개정", "학년군 기준", "학년·학기 미배정", "부분 원고 후보", "교사·수학 검수 대기", "권리 검토 대기", *[f"성취기준 후보: {code}" for code in codes]], "chapters": chapters, "metadata": {"status": "candidate_partial_draft", "teacher_review_status": "pending", "math_review_status": "author_checks_recorded_independent_review_pending", "rights_status": "pending", "publication_eligibility": "not_eligible", "standard_source": "교육부 고시 제2022-33호 별책8 공식 기준 인덱스", "content_rights": "newly authored candidate; independent rights decision pending", "semester_assignment": "not assigned; middle-school codes are grade-band standards", "interactive_compatibility_status": "native squareRootNumberLine interaction; validation pending", "external_interactive_assets": [SQUARE_ROOT_SOURCE_HTML]}}
    OUT.mkdir(parents=True, exist_ok=True)
    book_path = OUT / BOOK_FILE
    manifest_path = OUT / "원고매니페스트.json"
    prior = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    book_path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    book_sha256 = hashlib.sha256(book_path.read_bytes()).hexdigest().upper()
    source_path = ROOT / SQUARE_ROOT_SOURCE_HTML
    if not source_path.is_file():
        raise FileNotFoundError(f"Interactive source asset missing: {source_path}")
    source_sha256 = hashlib.sha256(source_path.read_bytes()).hexdigest().upper()
    previous_book_sha256 = prior.get("bookdata_sha256")
    validation = (
        prior.get("validation", {})
        if previous_book_sha256 == book_sha256
        and prior.get("validated_bookdata_sha256") == book_sha256
        else {
            "activity_roundtrip": "pending",
            "native_graph_builder": "pending",
            "student_quiz_reader": "pending",
            "source_html_visual_behavior_parity": "pending",
        }
    )
    validated_book_sha256 = (
        book_sha256
        if previous_book_sha256 == book_sha256
        and prior.get("validated_bookdata_sha256") == book_sha256
        else None
    )
    manifest = {"status": "candidate_partial_draft", "standard_codes": codes, "official_criteria": {code: official[code] for code in codes}, "module_count": len(chapters), "page_count": sum(len(ch["pages"]) for ch in chapters), "native_quiz_ids": [item["quiz"]["id"] for item in SPECS], "bookdata_sha256": book_sha256, "validated_bookdata_sha256": validated_book_sha256, "validation": validation, "interactive_source": {"path": SQUARE_ROOT_SOURCE_HTML, "sha256": source_sha256, "source_behavior": "range input n=1..25; displays sqrt(n) to 3 decimals and moves an SVG number-line point", "native_mapping": "squareRootNumberLine with n slider, three-decimal sqrt value, and moving number-line point", "full_html_visual_behavior_parity": "implemented; visual review pending"}, "arithmetic_checks": "passed", "teacher_review": "pending", "independent_math_review": "pending", "rights_review": "pending", "publication_eligibility": "not_eligible", "semester_assignment": "not assigned"}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(chapters)} modules, {manifest['page_count']} pages, {len(SPECS)} native quizzes; review and rights pending.")


if __name__ == "__main__":
    main()
