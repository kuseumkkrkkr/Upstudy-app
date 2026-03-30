from __future__ import annotations

import json
import textwrap
from typing import List

from .config import PromptMode, TierParams


def build_prompt(
    mode: PromptMode,
    tags: List[str],
    difficulty: int,
    params: TierParams,
) -> str:
    tags_json = json.dumps(tags, ensure_ascii=False)
    base_meta = textwrap.dedent(
        f"""
        - meta must include:
            {{
              "difficulty": {difficulty},
              "concept": "...",
              "params": {{...}},
              "hash_tags": {tags_json}
            }}
        """
    ).strip()

    common = textwrap.dedent(
        f"""
        You are generating a Python module for Korean CSAT-style math problems.
        Use these hash tags as topic guidance: {tags_json}
        Service difficulty settings:
        - solves_count = {params.solves_count}
        - strategy_level = {params.strategy_level}
        - branch_conditions = {params.branch_conditions}
        - computed difficulty score = {difficulty}

        Required interface:
        - Implement generate_problem(seed=None)
        - Return:
            {{
                "problem": str,
                "answer": int,
                "solution": str,
                "meta": dict
            }}
        {base_meta}

        Hard constraints:
        - Answer must be integer, non-zero, abs(answer) <= 50
        - Parameters should be small integers (preferably within [-5, 5])
        - Deterministic output when seed is provided
        - Retry up to 100 times; raise Exception if failed
        - Use sympy to validate the final answer
        - Keep functions modular, no prints

        Anti-shortcut filters:
        - Reject trivial problems (e.g., abs(answer) <= 5)
        - Implement at least two structure-specific anti-shortcut checks to prevent easy brute force
        - Ensure the final problem text and solution use clean signs (avoid "x - - 2", "+ -", "- +")
        """
    ).strip()

    if mode.key == "cubic_strict":
        cubic_details = textwrap.dedent(
            """
            Additional structure (strict):
            - f(x) is a monic cubic polynomial
            - Two integer roots are given
            - Use second derivative condition f''(k)=0 to determine parameter
            - Final question asks f(m)
            - No duplicate roots
            - Reject if (r1 + r2) / 2 == k
            - Reject if number of critical points <= 1
            - Reject if values of f(x) for x in [-3,3] show simple pattern
            - Reject if first differences are constant
            """
        ).strip()
        return (
            common
            + "\n\n"
            + cubic_details
            + "\n\nOutput full Python code only. No explanation."
        )

    tag_details = textwrap.dedent(
        """
        Topic guidance:
        - Pick a coherent problem type consistent with the hash tags.
        - If tags imply calculus/function topics, you may use cubic or derivative structures.
        - Otherwise, use a fitting structure (sequence, inequality, geometry, probability, etc.)
        - Ensure the structure remains solvable with small integer parameters.

        For the chosen structure, implement appropriate anti-shortcut filters
        (e.g., avoid symmetric setups, avoid linear patterns, avoid trivial parameter choices).
        """
    ).strip()

    return common + "\n\n" + tag_details + "\n\nOutput full Python code only. No explanation."
