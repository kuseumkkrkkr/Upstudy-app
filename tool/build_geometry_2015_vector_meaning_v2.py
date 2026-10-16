"""Generate an original, review-pending lesson candidate for 12기하02-01."""

from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OFFICIAL_SOURCE = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
CODE = "12기하02-01"
STANDARD = "벡터의 뜻을 안다."
OUTPUT_NAME = "고등수학_기하_벡터의뜻_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "기하_2015_벡터의뜻_부분원고_Batch1"


def build_book() -> dict[str, object]:
    return {
        "title": "2015 개정 기하 · 벡터의 뜻 (V2 개념·예제·연습 시범)",
        "subtitle": f"[{CODE}] {STANDARD} · 부분 원고 · 독립 수학 검토·교사 검수·권리 확인 전",
        "category": "concept_textbook_prototype",
        "curriculum_version": "2015",
        "standard_codes": [CODE],
        "tags": [
            "기하",
            "2015 개정",
            "벡터",
            "벡터의 뜻",
            CODE,
            "개념·예제·연습 시범",
            "독립 검토 전",
            "rights review pending",
        ],
        "chapters": [
            {
                "title": "벡터의 뜻: 크기와 방향",
                "intro": [
                    f"공식 교육과정 기준 {CODE}의 문구는 ‘{STANDARD}’이다. 이 원고는 벡터의 크기와 방향, 같은 벡터의 판정에 초점을 둔 부분 후보이며 기준 전체의 충족 판정은 아니다.",
                    "벡터를 화살표와 이동으로 읽고, 길이만 같거나 방향만 같은 경우와 구별한다.",
                ],
                "sections": [
                    {
                        "title": "벡터를 나타내는 두 정보",
                        "paragraphs": [
                            "벡터는 크기와 방향을 함께 나타내는 양이다. 화살표의 길이는 크기를, 화살촉이 향하는 쪽은 방향을 나타낸다.",
                            "위치가 다른 두 화살표라도 길이와 방향이 모두 같으면 같은 벡터로 본다. 시작점의 위치만으로 벡터가 달라지는 것은 아니다.",
                            "크기만 같고 방향이 반대인 두 벡터는 서로 같은 벡터가 아니다. 두 벡터는 서로 반대벡터다.",
                        ],
                    }
                ],
                "pages": [
                    {
                        "id": "geometry-vector-meaning-opening",
                        "template": "opening",
                        "title": "시작점이 달라지면 벡터도 달라질까?",
                        "kicker": "화살표의 길이와 방향을 먼저 비교",
                        "blocks": [
                            {"type": "lead", "title": "오늘의 질문", "text": "길이가 같고 같은 쪽을 향하는 두 화살표가 서로 다른 곳에서 시작하면, 서로 다른 벡터일까요?"},
                            {"type": "thinking", "title": "먼저 생각하기", "text": "시작점, 화살표 길이, 화살촉 방향 가운데 벡터를 결정하는 정보가 무엇인지 골라 보세요."},
                        ],
                    },
                    {
                        "id": "geometry-vector-meaning-definition",
                        "template": "concept",
                        "title": "벡터는 크기와 방향을 함께 나타낸다",
                        "kicker": "화살표의 길이와 화살촉",
                        "blocks": [
                            {"type": "definition", "title": "벡터", "text": "벡터는 크기와 방향을 함께 가지는 양이다. 화살표로 나타낼 때 화살표의 길이가 크기이고, 화살촉이 향하는 쪽이 방향이다."},
                            {"type": "symbols", "title": "기호 읽기", "text": "점 A에서 점 B로 향하는 화살표를 벡터 AB라고 쓴다. 벡터 AB의 크기는 선분 AB의 길이이며, 방향은 A에서 B를 향한다."},
                            {"type": "paragraph", "title": "같은 벡터", "text": "두 벡터가 같은지는 크기와 방향을 비교해 판단한다. 두 화살표의 시작점이 달라도 크기와 방향이 모두 같으면 같은 벡터다."},
                            {"type": "misconception", "title": "헷갈리기 쉬운 점", "text": "길이만 같다고 같은 벡터인 것은 아니다. 방향이 다르면 다른 벡터이며, 크기가 같고 방향이 반대라면 서로 반대벡터다."},
                        ],
                    },
                    {
                        "id": "geometry-vector-meaning-worked-example",
                        "template": "example",
                        "title": "시작점이 다른 화살표 비교하기",
                        "kicker": "크기와 방향을 차례로 확인",
                        "blocks": [
                            {"type": "question", "title": "예제", "text": "화살표 u와 v는 각각 길이가 4이고 동쪽을 향한다. 시작점은 서로 다르다. 화살표 w는 길이가 4이고 서쪽을 향한다. u, v, w의 관계를 설명하라."},
                            {"type": "solutionStep", "title": "1단계 · 크기 비교", "text": "u, v, w의 크기는 모두 4로 같다."},
                            {"type": "solutionStep", "title": "2단계 · 방향 비교", "text": "u와 v는 모두 동쪽을 향한다. 시작점의 위치만 다르므로 u와 v는 같은 벡터다."},
                            {"type": "solutionStep", "title": "3단계 · 반대 방향 확인", "text": "w는 같은 크기지만 서쪽을 향한다. 따라서 w는 u와 같지 않고, u의 반대벡터다."},
                            {"type": "answer", "title": "정리", "text": "u=v이며 w는 u의 반대벡터다. 벡터의 같음은 시작점이 아니라 크기와 방향으로 판단한다."},
                        ],
                    },
                    {
                        "id": "geometry-vector-meaning-distance-displacement",
                        "template": "principle",
                        "title": "이동한 거리와 변위 벡터",
                        "kicker": "경로의 길이와 처음·끝의 방향",
                        "blocks": [
                            {"type": "paragraph", "title": "경로와 변위는 다르다", "text": "이동 거리는 실제로 지나간 경로의 길이를 모두 더한 값이다. 변위 벡터는 출발점에서 도착점을 향하는 벡터이므로 이동 경로 전체를 기록하지 않는다."},
                            {"type": "question", "title": "직각으로 꺾어 이동", "text": "출발점에서 동쪽으로 3 m, 이어서 북쪽으로 4 m 이동했다. 이동 거리는 7 m다. 처음부터 끝까지의 변위 벡터의 크기와 방향은 무엇인가?"},
                            {"type": "solutionStep", "title": "크기 계산", "text": "동쪽 3 m와 북쪽 4 m는 직각을 이룬다. 출발점과 도착점을 이은 직각삼각형에서 변위의 크기는 √(3²+4²)=5 m다."},
                            {"type": "solutionStep", "title": "방향 확인", "text": "도착점은 출발점에서 동쪽과 북쪽으로 모두 이동한 위치다. 변위 벡터의 방향은 북동쪽이다."},
                            {"type": "verification", "title": "두 값을 구별", "text": "지나간 길이의 합은 3+4=7 m이고, 변위 벡터의 크기는 5 m다. 두 값은 서로 다른 양이다."},
                        ],
                    },
                    {
                        "id": "geometry-vector-meaning-practice",
                        "template": "practice",
                        "title": "크기와 방향으로 벡터 설명하기",
                        "kicker": "풀이를 읽고 이유까지 확인",
                        "blocks": [
                            {"type": "question", "title": "연습 1", "text": "길이가 5 cm이고 북동쪽을 향하는 두 화살표가 서로 다른 곳에서 시작한다. 두 화살표는 같은 벡터인가? 이유를 쓰라."},
                            {"type": "answer", "title": "연습 1 풀이", "text": "같은 벡터다. 크기 5 cm가 같고 방향도 북동쪽으로 같으며, 시작점의 위치는 벡터의 같음을 바꾸지 않는다."},
                            {"type": "question", "title": "연습 2", "text": "크기가 4이고 동쪽을 향하는 벡터 p와 크기가 4이고 서쪽을 향하는 벡터 q의 관계를 설명하라."},
                            {"type": "answer", "title": "연습 2 풀이", "text": "p와 q는 크기는 같지만 방향이 반대이므로 같은 벡터가 아니다. q는 p의 반대벡터다."},
                            {"type": "question", "title": "연습 3", "text": "3 m 동쪽으로 이동한 뒤 4 m 북쪽으로 이동했다. 이동 거리와 변위 벡터를 각각 말하라."},
                            {"type": "answer", "title": "연습 3 풀이", "text": "이동 거리는 7 m다. 변위 벡터는 출발점에서 도착점을 향하며, 크기는 √(3²+4²)=5 m, 방향은 북동쪽이다."},
                            {
                                "type": "activity",
                                "activity": {
                                    "id": "geometry-vector-meaning-check",
                                    "kind": "quiz",
                                    "prompt": "크기가 같고 방향이 반대인 두 벡터를 어떻게 설명할까요?",
                                    "hints": ["같은 벡터인지 판단할 때는 크기와 방향을 모두 비교합니다."],
                                    "options": ["서로 같은 벡터다", "서로 반대벡터이며 같은 벡터는 아니다", "시작점이 다르면 크기와 방향에 관계없이 비교할 수 없다"],
                                    "correct_index": 1,
                                    "correct_feedback": "맞아요. 크기는 같지만 방향이 반대이므로 반대벡터입니다.",
                                    "incorrect_feedback": "두 벡터의 크기와 방향을 각각 비교해 보세요.",
                                },
                            },
                            {"type": "checklist", "title": "확인", "items": ["벡터를 크기와 방향으로 설명한다.", "시작점이 다른 같은 벡터를 판별한다.", "이동 거리와 변위 벡터의 크기를 구별한다."]},
                        ],
                    },
                ],
            }
        ],
    }


def main() -> None:
    if not OFFICIAL_SOURCE.is_file():
        raise FileNotFoundError(f"Official curriculum text is required: {OFFICIAL_SOURCE}")
    official_text = OFFICIAL_SOURCE.read_text(encoding="utf-8")
    if not re.search(rf"\[{re.escape(CODE)}\]\s*{re.escape(STANDARD)}", official_text):
        raise RuntimeError(f"Official source does not contain the expected standard: {CODE}")

    output = MANUSCRIPTS / OUTPUT_NAME
    output.write_text(json.dumps(build_book(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source_files": [
            {
                "source_file": OUTPUT_NAME,
                "sha256": canonical_file_sha256(output),
                "curriculum_version": "2015",
                "standard_codes": [CODE],
                "page_count": 5,
                "content_elements": ["concept_explanation", "worked_example", "practice", "answer_explanations", "native_quiz"],
                "content_status": "authored_candidate; independent review pending",
                "math_review_status": "pending_independent_review",
                "teacher_review_status": "pending",
                "rights_status": "pending_review",
            }
        ],
        "official_source_file": "work/official-curriculum/2015_appendix8_math.txt",
        "official_source_sha256": __import__("hashlib").sha256(OFFICIAL_SOURCE.read_bytes()).hexdigest().upper(),
        "official_standard": {"code": CODE, "text": STANDARD},
        "curriculum_review_status": "code_and_statement_checked; content alignment review pending",
        "math_review_status": "pending_independent_review",
        "teacher_review_status": "pending",
        "rights_status": "pending_review",
        "publication_eligibility": "not_eligible",
        "runtime_import_status": "pending_current_hash_validation",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        "# 기하 2015 개정 · 벡터의 뜻 부분 원고\n\n"
        f"`{OUTPUT_NAME}`는 공식 기준 `{CODE}`의 문구를 확인해 작성한 한 기준 부분 후보입니다. "
        "정의, 풀이 예제, 세 연습 문제와 해설, 확인 퀴즈를 포함합니다. 이는 독립 수학·교사 검수를 통과한 원고가 아니며, "
        "기하 상품 전체 범위나 권리를 승인하지 않습니다. rights와 publication eligibility는 pending/not eligible입니다.\n",
        encoding="utf-8",
    )
    print(f"Generated 5-page, review-pending V2 candidate for {CODE}: {output}")


if __name__ == "__main__":
    main()
