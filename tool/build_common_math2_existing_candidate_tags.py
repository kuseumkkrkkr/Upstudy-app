"""Add evidence-backed 2022 standard tags to two existing Common Math 2 drafts."""
from __future__ import annotations

import json
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
PACKAGE = MANUSCRIPTS / "공통수학2_기존원고_예비연결_원고패키지"

SOURCES = {
    "공통수학2_명제와조건_BookData_시범.json": {
        "codes": ["10공수2-02-04", "10공수2-02-05"],
        "required_intro": ["10공수2-02-04", "10공수2-02-05"],
        "alignment": {
            "10공수2-02-04": "candidate_mapping_review_pending",
            "10공수2-02-05": "candidate_mapping_review_pending",
        },
    },
    "공통수학2_함수의대응_BookData_시범.json": {
        "codes": ["10공수2-03-01"],
        "required_intro": ["10공수2-03-01"],
        "alignment": {"10공수2-03-01": "candidate_partial_general_function_graph_incomplete"},
    },
}


def main() -> None:
    official = {row["code"]: row["criterion"] for row in json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]}
    records = []
    alignments = {}
    for filename, spec in SOURCES.items():
        path = MANUSCRIPTS / filename
        book = json.loads(path.read_text(encoding="utf-8"))
        expected = spec["codes"]
        if any(code not in official for code in expected):
            raise RuntimeError(f"Unofficial code in {filename}: {expected}")
        intro = " ".join(text for chapter in book.get("chapters", []) for text in chapter.get("intro", []))
        if any(code not in intro for code in spec["required_intro"]):
            raise RuntimeError(f"Explicit source-to-code statement missing from {filename}")
        tags = book.get("tags", [])
        if "2022 개정" not in tags and "2022 개정" not in intro:
            raise RuntimeError(f"No explicit 2022 edition evidence in {filename}")
        old_pages = json.dumps(book.get("chapters", []), ensure_ascii=False, sort_keys=True)
        book["curriculum_version"] = "2022"
        book["standard_codes"] = sorted(set(book.get("standard_codes", [])) | set(expected))
        if "2022 개정" not in tags:
            tags.append("2022 개정")
        for code in expected:
            if code not in tags:
                tags.append(code)
        book["tags"] = tags
        if json.dumps(book.get("chapters", []), ensure_ascii=False, sort_keys=True) != old_pages:
            raise RuntimeError(f"Page content changed while tagging {filename}")
        path.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        records.append({"bookdata_file": filename, "bookdata_sha256": canonical_file_sha256(path), "standard_codes": sorted(expected)})
        alignments.update(spec["alignment"])

    PACKAGE.mkdir(parents=True, exist_ok=True)
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try:
        old_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old_manifest = {}
    same_sources = old_manifest.get("source_bookdata_files") == records
    manifest = {
        "source_bookdata_files": records,
        "candidate_code_reference_type": "official_2022_hwp_criterion_table",
        "candidate_code_references": sorted(alignments),
        "preliminary_module_alignment": alignments,
        "curriculum_review_status": "official_codes_and_explicit_source_mentions_checked; product_scope_pending",
        "math_review_status": "pending_independent_teacher_review",
        "teacher_review_status": "pending",
        "rights_status": "unknown_for_existing_drafts; project_rights_decision_pending",
        "integration_status": "candidate_pages_preserved; grouped_output_generated_by_pipeline",
        "publication_eligibility": "not_eligible",
        "runtime_import_status": old_manifest.get("runtime_import_status", "pending_current_hash_validation") if same_sources else "pending_current_hash_validation",
        "runtime_validator_head": old_manifest.get("runtime_validator_head") if same_sources else None,
        "notes": [
            "10공수2-03-01 source explicitly says general function graph understanding is incomplete; this remains a partial candidate.",
            "Other Common Math 2 samples without explicit edition evidence or standard-code evidence were left untagged.",
        ],
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        "# 공통수학2 기존 원고 예비 연결\n\n"
        "기존 지면을 바꾸지 않고, 본문에 명시된 2022 기준 연결이 확인되는 두 BookData에만 기계 판독 가능한 성취기준 태그를 추가했습니다. "
        "10공수2-03-01 자료는 일반 함수 그래프 이해가 미완료인 부분 후보입니다. 판본 또는 코드 근거가 불분명한 기존 집합·유리함수 파일은 연결하지 않았습니다. "
        "교사·수학 검토와 권리 결정 전에는 출판 적격이 아닙니다.\n",
        encoding="utf-8",
    )
    print("Tagged 3 existing Common Math 2 candidate codes across two page-preserved BookData files.")


if __name__ == "__main__":
    main()
