"""Regenerate all current tag-grouped textbook draft outputs."""

from __future__ import annotations

import runpy
from pathlib import Path

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
    ("build_middle_school_2_1_2022_candidate.py", "main"),
    ("build_middle_school_2_2_2022_candidate.py", "main"),
    ("build_middle_school_3_1_2022_candidate.py", "main"),
    ("build_middle_school_3_2_2022_candidate.py", "main"),
    ("build_probability_2022_missing_units_v2.py", "main"),
    ("build_probability_2022_missing_units_v2_batch2.py", "main"),
    ("build_probability_2022_missing_units_v2_batch3.py", "main"),
    ("build_probability_2022_basic_probability_v2_batch4.py", "main"),
    ("build_common_math2_existing_candidate_tags.py", "main"),
    ("build_other_2022_course_drafts.py", "main"),
    ("build_calculus_1_2022_draft.py", "main"),
    ("build_calculus_2_2022_draft.py", "main"),
    ("build_calculus_2_2022_sequences_v2_batch1.py", "main"),
    ("build_calculus_2_2022_v2_batch2.py", "main"),
    ("build_geometry_2022_draft.py", "main"),
    ("build_geometry_2022_remaining_v2_batch1.py", "main"),
    ("build_geometry_2015_vector_drafts.py", "main"),
    ("build_math_1_2015_draft.py", "main"),
    ("build_math_2_2015_draft.py", "main"),
    ("build_probability_statistics_2015_draft.py", "main"),
    ("build_probability_statistics_2015_v2_batch1.py", "main"),
    ("build_probability_statistics_2015_remaining_v2_batch2.py", "main"),
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
    ("build_math_2015_split_books.py", "main"),
    ("build_curriculum_code_inventory.py", "main"),
    ("build_textbook_scope_coverage.py", "main"),
    ("build_html_asset_inventory.py", "main"),
]


def verify_bookdata_references() -> int:
    source_files = list(MANUSCRIPTS.glob("*BookData*.json"))
    output_dirs = [readme.parent for readme in MANUSCRIPTS.rglob("README.md") if readme.parent != MANUSCRIPTS]
    generated_text = []
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


def main() -> None:
    for filename, function_name in GENERATORS:
        path = TOOL / filename
        if not path.is_file():
            raise FileNotFoundError(f"Missing textbook generator: {path}")
        namespace = runpy.run_path(str(path), run_name="tagged_textbook_generator")
        function = namespace.get(function_name)
        if not callable(function):
            raise RuntimeError(f"Generator entrypoint missing: {filename}:{function_name}")
        print(f"Running {filename}")
        function()
    source_count = verify_bookdata_references()
    print(f"Verified generated package references for all {source_count} BookData source files.")
    print(f"Completed {len(GENERATORS)} textbook generation steps.")


if __name__ == "__main__":
    main()
