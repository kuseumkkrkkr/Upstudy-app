"""Attach conservative, review-pending 2015 Math I code candidates to existing drafts."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
PACKAGE = MANUSCRIPTS / "수학Ⅰ_2015개정_기존원고_예비연결_원고패키지"
SOURCES = {
    "대수_지수와로그_BookData_시범.json": {
        "codes": ["12수학Ⅰ01-04", "12수학Ⅰ01-06"],
        "alignment": {"12수학Ⅰ01-04": "candidate_partial_log_definition_and_inverse_relation", "12수학Ⅰ01-06": "candidate_partial_function_definition_graph_scope_incomplete"},
    },
    "수학Ⅰ_삼각함수_BookData_시범.json": {
        "codes": ["12수학Ⅰ02-01", "12수학Ⅰ02-02"],
        "alignment": {"12수학Ⅰ02-01": "candidate_mapping_general_angle_and_radian", "12수학Ⅰ02-02": "candidate_partial_tangent_graph_missing"},
    },
    "수학Ⅰ_삼각함수_사인법칙코사인법칙_BookData_시범.json": {
        "codes": ["12수학Ⅰ02-03"],
        "alignment": {"12수학Ⅰ02-03": "candidate_mapping_law_examples_and_triangle_applications_review_pending"},
    },
    "수학Ⅰ_수열_BookData_시범.json": {
        "codes": ["12수학Ⅰ03-01", "12수학Ⅰ03-02", "12수학Ⅰ03-03", "12수학Ⅰ03-07", "12수학Ⅰ03-08"],
        "alignment": {"12수학Ⅰ03-01": "candidate_mapping_sequence_terms", "12수학Ⅰ03-02": "candidate_mapping_arithmetic_sequence_and_sum", "12수학Ⅰ03-03": "candidate_mapping_geometric_sequence_and_sum", "12수학Ⅰ03-07": "candidate_partial_induction_principle", "12수학Ⅰ03-08": "candidate_partial_induction_proof_needs_full_review"},
    },
}


def main() -> None:
    records = []
    alignments = {}
    total_normalized_blocks = 0
    for filename, spec in SOURCES.items():
        path = MANUSCRIPTS / filename
        source_text = path.read_text(encoding="utf-8")
        book = json.loads(source_text)
        tags = book.get("tags", [])
        if "2015 개정" not in tags or book.get("curriculum_version", "2015") != "2015":
            raise RuntimeError(f"Explicit 2015 edition evidence missing from {filename}")
        expected_chapters = json.loads(json.dumps(book.get("chapters", []), ensure_ascii=False))
        normalized_count = sum(1 for chapter in book.get("chapters", []) for page in chapter.get("pages", []) for block in page.get("blocks", []) if block.get("type") == "example")
        for chapter in expected_chapters:
            for page in chapter.get("pages", []):
                for block in page.get("blocks", []):
                    if block.get("type") == "example":
                        block["type"] = "solutionStep"
        total_normalized_blocks += normalized_count

        updated = re.sub(r'("type"\s*:\s*)"example"', r'\1"solutionStep"', source_text)
        tags_match = re.search(r'("tags"\s*:\s*\[)(.*?)(\])', updated, flags=re.S)
        if not tags_match:
            raise RuntimeError(f"Top-level tags array not found in {filename}")
        tag_values = json.loads("[" + tags_match.group(2) + "]")
        for code in spec["codes"]:
            if code not in tag_values:
                tag_values.append(code)
        tags_json = tags_match.group(1)[:-1] + json.dumps(tag_values, ensure_ascii=False)
        updated = updated[:tags_match.start()] + tags_json + updated[tags_match.end():]
        standard_codes = sorted(set(book.get("standard_codes", [])) | set(spec["codes"]))
        if re.search(r'"curriculum_version"\s*:', updated):
            updated = re.sub(r'("curriculum_version"\s*:\s*)"[^"]*"', r'\1"2015"', updated, count=1)
        else:
            category = re.search(r'("category"\s*:\s*"[^"]+")', updated)
            if not category:
                raise RuntimeError(f"Top-level category field not found in {filename}")
            updated = updated[:category.end()] + ',\n  "curriculum_version": "2015"' + updated[category.end():]
        if re.search(r'"standard_codes"\s*:', updated):
            updated = re.sub(r'("standard_codes"\s*:\s*)\[[^\]]*\]', r'\1' + json.dumps(standard_codes, ensure_ascii=False), updated, count=1)
        else:
            updated = re.sub(r'("curriculum_version"\s*:\s*"2015")', r'\1,\n  "standard_codes": ' + json.dumps(standard_codes, ensure_ascii=False), updated, count=1)
        checked = json.loads(updated)
        if checked.get("chapters", []) != expected_chapters:
            raise RuntimeError(f"Existing page content changed beyond compatibility normalization in {filename}")
        path.write_text(updated, encoding="utf-8")
        records.append({"bookdata_file": filename, "bookdata_sha256": canonical_file_sha256(path), "candidate_standard_codes": sorted(spec["codes"])})
        alignments.update(spec["alignment"])

    PACKAGE.mkdir(parents=True, exist_ok=True)
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    old = {}
    try:
        old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        pass
    manifest = {
        "source_bookdata_files": records,
        "candidate_code_reference_type": "2015_moe_appendix8_math_criteria_table",
        "candidate_code_references": sorted(alignments),
        "preliminary_module_alignment": alignments,
        "curriculum_review_status": "official_codes_and_edition_checked; module_content_review_pending",
        "math_review_status": "pending_independent_teacher_review",
        "teacher_review_status": "pending",
        "rights_status": "unknown_for_existing_drafts; project_rights_decision_pending",
        "integration_status": "source_pages_preserved; candidate_tags_only",
        "publication_eligibility": "not_eligible",
        "compatibility_normalization": {"legacy_example_to_solutionStep_blocks": old.get("compatibility_normalization", {}).get("legacy_example_to_solutionStep_blocks", total_normalized_blocks) if old.get("source_bookdata_files") == records else total_normalized_blocks},
        "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if old.get("source_bookdata_files") == records else "pending_current_hash_validation",
        "runtime_validator_head": old.get("runtime_validator_head") if old.get("source_bookdata_files") == records else None,
        "notes": ["Unsupported legacy example block types were mapped to the supported solutionStep type without changing page text.", "The trigonometric-function draft does not contain a tangent graph; 12수학Ⅰ02-02 remains partial until the addendum is independently reviewed.", "Candidate tags are not content approval."],
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text("# 수학Ⅰ(2015) 기존 원고의 예비 기준 연결\n\n명시적인 2015 개정 표기가 있는 기존 BookData 4개에 코드 후보를 추가했습니다. 원문 텍스트와 지면은 유지하고 importer가 지원하지 않는 legacy `example` 블록 유형만 `solutionStep`으로 정규화했습니다. 특히 01-04/01-06, 02-02, 03-07/03-08 연결은 부분 후보이며 교사·수학 검토가 필요합니다. 권리 상태도 미확인으로 유지합니다.\n", encoding="utf-8")
    print(f"Tagged {len(alignments)} candidate standard codes across {len(records)} existing Math I BookData sources; preserved page payloads.")


if __name__ == "__main__":
    main()
