"""Tag existing 2015 geometry vectors and generate a native-interaction V2 candidate."""

from __future__ import annotations

import json
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
PACKAGE = MANUSCRIPTS / "기하_2015개정_기존벡터_예비기준연결"
VECTOR_SOURCE = "고등수학_기하_벡터의덧셈과실수배_BookData_시범.json"
VECTOR_V2 = "고등수학_기하_벡터의덧셈과실수배_BookData_V2_시범.json"
SOURCES = {
    "고등수학_기하_2015개정_개념서_시범_BookData.json": [
        "12기하02-01", "12기하02-02", "12기하02-03", "12기하02-04"
    ],
    VECTOR_SOURCE: ["12기하02-01", "12기하02-02"],
    "고등수학_기하_위치벡터와좌표_BookData_시범.json": ["12기하02-03"],
    "고등수학_기하_평면벡터내적_BookData_시범.json": ["12기하02-04"],
}
EXPECTED_PAGES = {
    "고등수학_기하_2015개정_개념서_시범_BookData.json": 9,
    VECTOR_SOURCE: 3,
    "고등수학_기하_위치벡터와좌표_BookData_시범.json": 3,
    "고등수학_기하_평면벡터내적_BookData_시범.json": 3,
}
PARTIAL = {
    "12기하02-01": "vector meaning is introduced with operations; independent concept coverage remains partial",
    "12기하02-02": "operation examples exist; practice and complete operation coverage require review",
    "12기하02-03": "position vector and coordinates have two separate drafts; full criterion check pending",
    "12기하02-04": "dot product definition and coordinate form exist; application coverage pending",
}


def _activity_blocks() -> list[dict[str, object]]:
    return [
        {
            "type": "activity",
            "activity": {
                "id": "geometry-vector-operations-native",
                "kind": "vectorOperation",
                "prompt": "연산을 선택하고 벡터 성분을 조절한 뒤, 화살표와 결과 좌표를 함께 확인하세요.",
                "hints": [
                    "덧셈과 뺄셈은 x성분끼리, y성분끼리 계산합니다.",
                    "실수배에서는 두 성분에 같은 계수를 곱합니다. 계수가 음수이면 방향이 반대입니다.",
                ],
                "operation": "add",
                "ux": 3,
                "uy": 1,
                "vx": 1,
                "vy": 2,
                "alpha": 2,
            },
        },
        {
            "type": "activity",
            "activity": {
                "id": "geometry-vector-subtraction-socratic",
                "kind": "quiz",
                "prompt": "u−v를 만들 때 v를 어떤 벡터로 바꾸어 u에 더할까요?",
                "hints": ["뺄셈은 두 번째 벡터의 방향을 반대로 하여 더합니다."],
                "options": ["u+v", "u+(−v)", "(−u)+v"],
                "correct_index": 1,
                "correct_feedback": "맞아요. v를 −v로 바꾸어 u에 더합니다.",
                "incorrect_feedback": "뺄셈을 덧셈으로 바꾸는 방법을 다시 생각해 보세요.",
            },
        },
        {
            "type": "activity",
            "activity": {
                "id": "geometry-vector-scalar-socratic",
                "kind": "quiz",
                "prompt": "계수 α를 2에서 −2로 바꾸면 αu의 방향과 길이는 어떻게 바뀔까요?",
                "hints": ["계수의 부호는 방향을, 절댓값은 길이의 배율을 정합니다."],
                "options": ["같은 방향, 같은 길이", "반대 방향, 같은 길이", "반대 방향, 두 배 길이"],
                "correct_index": 1,
                "correct_feedback": "맞아요. 방향은 반대가 되고 길이는 같습니다.",
                "incorrect_feedback": "계수의 부호와 절댓값을 따로 비교해 보세요.",
            },
        },
        {
            "type": "activity",
            "activity": {
                "id": "geometry-vector-subtraction-practice",
                "kind": "quiz",
                "prompt": "u=(3,1), v=(1,2)일 때 u−v의 성분은 무엇인가요?",
                "hints": ["u−v=(3−1, 1−2)로 계산합니다."],
                "options": ["(4,3)", "(2,−1)", "(−2,1)"],
                "correct_index": 1,
                "correct_feedback": "정답입니다. u−v=(2,−1)입니다.",
                "incorrect_feedback": "각 성분에서 v의 해당 성분을 빼 보세요.",
            },
        },
    ]


def _build_vector_v2(source: dict[str, object], codes: list[str]) -> dict[str, object]:
    candidate = json.loads(json.dumps(source, ensure_ascii=False))
    candidate["title"] = "2015 개정 기하 개념서 · 벡터의 덧셈과 실수배 (V2 체험 후보)"
    candidate["subtitle"] = (
        "[12기하02-01], [12기하02-02] 부분 시범 · native activity 연결 · "
        "독립 수학·교사 검수 및 권리 확인 전"
    )
    candidate["curriculum_version"] = "2015"
    candidate["standard_codes"] = codes
    tags = candidate.get("tags", [])
    if not isinstance(tags, list):
        raise RuntimeError("Expected a tag list on the vector source")
    candidate["tags"] = list(
        dict.fromkeys(
            [*tags, *codes, "official-code candidate mapping; content review pending"]
        )
    )

    pages = [page for chapter in candidate.get("chapters", []) for page in chapter.get("pages", [])]
    page = next((item for item in pages if item.get("id") == "geometry-vector-experiment"), None)
    if not isinstance(page, dict) or not isinstance(page.get("blocks"), list):
        raise RuntimeError("Could not find geometry-vector-experiment page blocks")
    blocks = page["blocks"]
    visual = next(
        (block for block in blocks if isinstance(block, dict) and block.get("type") == "visual"),
        None,
    )
    if visual is None:
        raise RuntimeError("Could not find the source visual description")
    visual["text"] = (
        "독립 HTML 원본은 별도 파일로 보존합니다. 아래 앱 체험은 덧셈·뺄셈·실수배의 "
        "벡터 조작과 단계 설명을 네이티브로 일부 대응합니다. 독립 HTML의 전체 화면·동작 "
        "패리티가 검증된 것은 아닙니다."
    )
    known_ids = {item["activity"]["id"] for item in _activity_blocks()}
    page["blocks"] = [
        block
        for block in blocks
        if not (
            isinstance(block, dict)
            and isinstance(block.get("activity"), dict)
            and block["activity"].get("id") in known_ids
        )
    ] + _activity_blocks()
    return candidate


def main() -> None:
    records: list[dict[str, object]] = []
    tagged_sources: dict[str, dict[str, object]] = {}
    for name, codes in SOURCES.items():
        path = MANUSCRIPTS / name
        data = json.loads(path.read_text(encoding="utf-8"))
        tags = data.get("tags", [])
        if tags[:2] != ["기하", "2015 개정"]:
            raise RuntimeError(f"Unexpected edition tags: {name}")
        pages = [page for chapter in data.get("chapters", []) for page in chapter.get("pages", [])]
        if len(pages) != EXPECTED_PAGES[name]:
            raise RuntimeError(f"Unexpected source page count for {name}: {len(pages)}")
        # Preserve every source page and authored block; add only provisional metadata.
        data["curriculum_version"] = "2015"
        data["standard_codes"] = codes
        data["tags"] = list(
            dict.fromkeys([*tags, *codes, "official-code candidate mapping; content review pending"])
        )
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        tagged_sources[name] = data
        records.append(
            {
                "source_file": name,
                "sha256": canonical_file_sha256(path),
                "standard_codes": codes,
                "page_count": len(pages),
                "content_mapping_status": "partial_candidate_mapping; independent review pending",
                "rights_status": "source rights not verified",
            }
        )

    vector_codes = SOURCES[VECTOR_SOURCE]
    vector_path = MANUSCRIPTS / VECTOR_SOURCE
    v2_path = MANUSCRIPTS / VECTOR_V2
    candidate = _build_vector_v2(tagged_sources[VECTOR_SOURCE], vector_codes)
    v2_pages = [page for chapter in candidate["chapters"] for page in chapter["pages"]]
    if len(v2_pages) != EXPECTED_PAGES[VECTOR_SOURCE]:
        raise RuntimeError("V2 candidate must preserve all three source pages")
    v2_path.write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    records.append(
        {
            "source_file": VECTOR_V2,
            "sha256": canonical_file_sha256(v2_path),
            "standard_codes": vector_codes,
            "page_count": len(v2_pages),
            "content_mapping_status": "partial_candidate_mapping; independent review pending",
            "interactive_activity_kinds": ["vectorOperation", "quiz"],
            "interactive_migration_status": "native_partial_port; HTML parity pending",
            "rights_status": "source rights not verified",
        }
    )

    PACKAGE.mkdir(parents=True, exist_ok=True)
    old = {}
    try:
        old = json.loads((PACKAGE / "REVIEW_MANIFEST.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        pass
    same = old.get("source_files") == records
    manifest = {
        "source_files": records,
        "candidate_code_references": sorted(PARTIAL),
        "candidate_code_reference_type": "2015_moe_appendix8_geometry_standards",
        "curriculum_review_status": "official_codes_checked; body mapping partial",
        "math_review_status": "pending_independent_teacher_review",
        "teacher_review_status": "pending",
        "rights_status": "existing source rights not verified",
        "publication_eligibility": "not_eligible",
        "source_html_status": "native activity maps selected controls and stages; Socratic checks preserved as quizzes; full standalone HTML visual and behavior parity pending",
        "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same else "pending_current_hash_validation",
        "runtime_validator_head": old.get("runtime_validator_head") if same else None,
        "runtime_validation_command": old.get("runtime_validation_command") if same else None,
        "runtime_validation_evidence": old.get("runtime_validation_evidence") if same else None,
        "notes": PARTIAL,
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (PACKAGE / "README.md").write_text(
        "# 기하 2015 개정 기존 벡터 원고의 예비 기준 연결\n\n"
        "기존 BookData 4개의 원고 본문과 지면은 유지하고 판본 메타데이터와 성취기준 후보를 추가했습니다. "
        f"`{VECTOR_V2}`는 기존 덧셈·실수배 원고 3쪽을 보존한 native activity V2 후보입니다. "
        "벡터 조작과 세 개의 확인 문항을 앱 importer 및 reader로 검증하되, standalone HTML 전체 화면·동작 "
        "패리티는 미확인입니다. 기존 HTML 자산은 별도 파일로 보존합니다. 네 기준 매핑은 부분 후보이며 "
        "독립 교사 검수와 권리 확인을 기다립니다. 출판 부적격입니다.\n",
        encoding="utf-8",
    )
    print(f"Tagged {len(SOURCES)} original vector sources; generated {VECTOR_V2} with 4 native activities.")


if __name__ == "__main__":
    main()
