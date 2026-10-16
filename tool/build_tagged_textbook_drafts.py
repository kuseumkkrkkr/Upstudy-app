"""Regenerate all current tag-grouped textbook draft outputs."""

from __future__ import annotations

import argparse
import json
import runpy
from pathlib import Path
from typing import Sequence

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tool"
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
GENERATORS = [
    ("convert_2022_curriculum_hwp_to_xhtml.py", "main"),
    ("extract_2022_curriculum_xhtml.py", "main"),
    ("export_tagged_concept_textbooks.py", "export"),
    ("build_middle_school_2015_domain_drafts.py", "main"),
    ("build_middle_school_1_1_2022_sample.py", "main"),
    ("build_middle_school_1_2_2022_candidate.py", "main"),
    ("build_middle_school_linear_system_2022_candidate.py", "main"),
    ("build_middle_school_algebra_2022_candidate.py", "main"),
    ("build_middle_school_quadratic_2022_candidate.py", "main"),
    ("build_middle_school_real_numbers_2022_candidate.py", "main"),
    ("build_middle_school_geometry_statistics_2022_candidate.py", "main"),
    ("build_middle_school_linear_functions_2015_candidate.py", "main"),
    ("build_middle_school_geometry_2015_batch1.py", "main"),
    ("build_middle_school_geometry_2015_batch2.py", "main"),
    ("build_middle_school_statistics_2015_batch1.py", "main"),
    ("build_middle_school_2_1_2022_candidate.py", "main"),
    ("build_middle_school_2_2_2022_candidate.py", "main"),
    ("build_middle_school_3_1_2022_candidate.py", "main"),
    ("build_middle_school_3_2_2022_candidate.py", "main"),
    ("build_probability_2022_missing_units_v2.py", "main"),
    ("build_probability_2022_missing_units_v2_batch2.py", "main"),
    ("build_probability_2022_missing_units_v2_batch3.py", "main"),
    ("build_probability_2022_basic_probability_v2_batch4.py", "main"),
    ("build_common_math2_existing_candidate_tags.py", "main"),
    ("build_common_math2_missing_v2_batch1.py", "main"),
    ("build_common_math2_eqedit_v2_batch2.py", "main"),
    ("build_algebra_2022_remaining_v2_batch1.py", "main"),
    ("build_algebra_2022_eqedit_v2_batch2.py", "main"),
    ("build_other_2022_course_drafts.py", "main"),
    ("build_calculus1_2022_remaining_v2_batch1.py", "main"),
    ("build_calculus_1_2022_draft.py", "main"),
    ("build_calculus_2_2022_draft.py", "main"),
    ("build_calculus_2_2022_sequences_v2_batch1.py", "main"),
    ("build_calculus_2_2022_v2_batch2.py", "main"),
    ("build_geometry_2022_draft.py", "main"),
    ("build_geometry_2022_remaining_v2_batch1.py", "main"),
    ("build_geometry_2015_existing_candidate_tags.py", "main"),
    ("build_geometry_2015_vector_meaning_v2.py", "main"),
    ("build_geometry_2015_position_vector_v2.py", "main"),
    ("build_geometry_2015_remaining_v2_batch1.py", "main"),
    ("build_geometry_2015_vector_drafts.py", "main"),
    ("build_math1_2015_existing_candidate_tags.py", "main"),
    ("build_math1_2015_remaining_v2_batch1.py", "main"),
    ("build_math1_2015_log_completion_v2.py", "main"),
    ("build_math_upper_2015_polynomial_operations_v2.py", "main"),
    ("build_common_math2_rational_graph_v2.py", "main"),
    ("build_common_math2_radical_graph_v2.py", "main"),
    ("build_math_1_2015_draft.py", "main"),
    ("build_math2_2015_remaining_v2_batch1.py", "main"),
    ("build_math_2_2015_draft.py", "main"),
    ("build_probability_statistics_2015_draft.py", "main"),
    ("build_probability_statistics_2015_v2_batch1.py", "main"),
    ("build_probability_statistics_2015_remaining_v2_batch2.py", "main"),
    ("build_calculus_2015_remaining_v2_batch1.py", "main"),
    ("build_calculus_2015_draft.py", "main"),
    ("build_unversioned_middle_school_integer_draft.py", "main"),
    ("build_remaining_tagged_samples.py", "main"),
    ("build_math_upper_2015_polynomial_sample.py", "main"),
    ("build_math_upper_remainder_theorem_sample.py", "main"),
    ("build_math_lower_2015_sets_sample.py", "main"),
    ("build_math_lower_set_complement_difference_sample.py", "main"),
    ("build_math_lower_propositions_sample.py", "main"),
    ("build_math_upper_factorization_sample.py", "main"),
    ("build_math_lower_function_meaning_sample.py", "main"),
    ("build_math_lower_counting_principles_sample.py", "main"),
    ("build_math_lower_permutations_sample.py", "main"),
    ("build_math_lower_combinations_sample.py", "main"),
    ("build_math_lower_rational_function_sample.py", "main"),
    ("build_math_lower_irrational_function_sample.py", "main"),
    ("build_common_math1_missing_units_v2.py", "main"),
    ("build_common_math1_remaining_v2_batch2.py", "main"),
    ("build_common_math_1_2022_draft.py", "main"),
    ("build_math_upper_complex_numbers_sample.py", "main"),
    ("build_math_upper_quadratic_complex_roots_sample.py", "main"),
    ("build_math_upper_quadratic_function_roots_sample.py", "main"),
    ("build_math_upper_roots_coefficients_sample.py", "main"),
    ("build_math_upper_cubic_equation_sample.py", "main"),
    ("build_math_upper_rational_equation_sample.py", "main"),
    ("build_math_upper_quadratic_inequality_sample.py", "main"),
    ("build_math_upper_coordinate_distance_midpoint_sample.py", "main"),
    ("build_math_upper_line_equation_sample.py", "main"),
    ("build_math_upper_circle_equation_sample.py", "main"),
    ("build_math_upper_transformations_sample.py", "main"),
    ("build_math_upper_line_circle_intersections_sample.py", "main"),
    ("build_math_upper_circle_tangent_sample.py", "main"),
    ("build_math_upper_irrational_equation_sample.py", "main"),
    ("build_math_upper_simultaneous_quadratic_sample.py", "main"),
    ("build_math_upper_parallel_perpendicular_lines_sample.py", "main"),
    ("build_math_upper_compound_linear_inequalities_sample.py", "main"),
    ("build_math_2015_missing_criteria_v2.py", "main"),
    ("build_math_2015_partial_criteria_completion_v2.py", "main"),
    ("build_math_2015_split_books.py", "main"),
    ("build_curriculum_code_inventory.py", "main"),
    ("build_textbook_scope_coverage.py", "main"),
    ("build_html_asset_inventory.py", "main"),
    ("build_math2_2015_limits_continuity_v2_batch2.py", "main"),
]


def verify_bookdata_references() -> int:
    source_files = sorted(MANUSCRIPTS.rglob("*BookData*.json"))
    output_readmes = [readme for readme in MANUSCRIPTS.rglob("README.md") if readme.parent != MANUSCRIPTS]
    output_dirs = [readme.parent for readme in output_readmes]
    generated_text = []
    # A package README can reference a root-level BookData sibling via ../name;
    # searching only the README's own subtree misses that valid package link.
    for readme in output_readmes:
        try:
            generated_text.append(readme.read_text(encoding="utf-8"))
        except (UnicodeDecodeError, OSError):
            continue
    package_index = MANUSCRIPTS / "REMAINING_TEXTBOOKS_DRAFT_PACKAGE_INDEX.md"
    if not package_index.is_file():
        raise RuntimeError("Recursive BookData package index is missing")
    generated_text.append(package_index.read_text(encoding="utf-8"))
    for directory in output_dirs:
        for path in directory.rglob("*"):
            if path.is_file():
                try:
                    generated_text.append(path.read_text(encoding="utf-8"))
                except (UnicodeDecodeError, OSError):
                    continue
    missing = [source.name for source in source_files if not any(source.name in text for text in generated_text)]
    if missing:
        raise RuntimeError("BookData sources without a generated package reference: " + ", ".join(missing))
    return len(source_files)


def build_draft_package_index() -> int:
    """Index every recursive BookData artifact and its declared review/interaction signals."""
    paths = sorted(MANUSCRIPTS.rglob("*BookData*.json"))
    lines = [
        "# 재귀 BookData 초안 패키지 색인",
        "",
        f"재귀 BookData `{len(paths)}`개를 파일 경로와 선언된 구조·검토 상태로 색인했다. 태그·구조·검토 metadata는 내용 충족이나 독립 승인을 증명하지 않는다.",
        "",
        "| BookData | 판본 | 기준 코드 수 | 챕터 | 페이지 | activity block | 외부 HTML 참조 | 게시 적격성 | 교사 검토 | 수학 검토 | 권리 |",
        "|---|---|---:|---:|---:|---:|---:|---|---|---|---|",
    ]

    def count_structure(value: object) -> tuple[int, int, int]:
        chapters = pages = activities = 0
        if isinstance(value, dict):
            chapters = int("pages" in value and "title" in value)
            pages = int("blocks" in value and isinstance(value.get("blocks"), list))
            activities = int(value.get("type") == "activity" and isinstance(value.get("activity"), dict))
            for child in value.values():
                c, p, a = count_structure(child)
                chapters += c
                pages += p
                activities += a
        elif isinstance(value, list):
            for child in value:
                c, p, a = count_structure(child)
                chapters += c
                pages += p
                activities += a
        return chapters, pages, activities

    for path in paths:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        metadata = data.get("metadata", {})
        metadata = metadata if isinstance(metadata, dict) else {}
        codes = data.get("standard_codes", [])
        code_count = len(codes) if isinstance(codes, list) else int(bool(codes))
        code_count += int(bool(data.get("standard_code")) and not code_count)
        chapters, pages, activities = count_structure(data.get("chapters", []))
        assets = metadata.get("external_interactive_assets", [])
        asset_count = len(assets) if isinstance(assets, list) else 0
        relative = path.relative_to(MANUSCRIPTS).as_posix()
        label = str(data.get("title") or path.name).replace("|", "\\|")
        link = f"[{label}](<{relative}>)"
        values = [
            link,
            str(data.get("curriculum_version") or "미기록"),
            str(code_count),
            str(chapters),
            str(pages),
            str(activities),
            str(asset_count),
            str(metadata.get("publication_eligibility", data.get("publication_eligibility", "unspecified"))),
            str(metadata.get("teacher_review_status", metadata.get("teacher_review", "unspecified"))),
            str(metadata.get("math_review_status", metadata.get("independent_math_review", "unspecified"))),
            str(metadata.get("rights_status", metadata.get("rights_review", "unspecified"))),
        ]
        lines.append("| " + " | ".join(value.replace("|", "\\|") for value in values) + " |")
    output = MANUSCRIPTS / "REMAINING_TEXTBOOKS_DRAFT_PACKAGE_INDEX.md"
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(paths)


def main(argv: Sequence[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Regenerate tag-grouped textbook drafts; resume at a named generator stage."
    )
    stage_options = parser.add_mutually_exclusive_group()
    stage_options.add_argument(
        "--from-stage",
        "--resume-from",
        dest="from_stage",
        metavar="GENERATOR.py",
        help="resume at this exact generator filename; earlier outputs must already be valid",
    )
    parser.add_argument(
        "--skip-derived-indexes",
        action="store_true",
        help="skip shared package-index regeneration while still checking BookData references",
    )
    stage_options.add_argument(
        "--list-stages",
        action="store_true",
        help="list generator stages in pipeline order and exit",
    )
    args = parser.parse_args(argv)

    if args.list_stages:
        for index, (filename, _) in enumerate(GENERATORS, start=1):
            print(f"{index:02d}/{len(GENERATORS)} {filename}")
        return

    start_index = 0
    if args.from_stage:
        names = [filename for filename, _ in GENERATORS]
        try:
            start_index = names.index(args.from_stage)
        except ValueError:
            parser.error(
                f"unknown stage {args.from_stage!r}; use --list-stages to see valid filenames"
            )

    selected_generators = GENERATORS[start_index:]
    if start_index:
        print(
            f"Resuming at stage {start_index + 1}/{len(GENERATORS)} "
            f"({selected_generators[0][0]})."
        )

    for filename, function_name in selected_generators:
        path = TOOL / filename
        if not path.is_file():
            raise FileNotFoundError(f"Missing textbook generator: {path}")
        namespace = runpy.run_path(str(path), run_name="tagged_textbook_generator")
        function = namespace.get(function_name)
        if not callable(function):
            raise RuntimeError(f"Generator entrypoint missing: {filename}:{function_name}")
        print(f"Running {filename}")
        function()
    indexed_count = None if args.skip_derived_indexes else build_draft_package_index()
    source_count = verify_bookdata_references()
    if indexed_count is not None:
        print(f"Indexed {indexed_count} recursive BookData files.")
    print(f"Verified package references for all {source_count} BookData files.")
    print(f"Completed {len(selected_generators)} textbook generation steps.")


if __name__ == "__main__":
    main()
