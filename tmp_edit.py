import re
from pathlib import Path
p = Path('omj/generater/codebase_gen.py')
text = p.read_text(encoding='utf-8')
pattern = r"def build_prompt[\s\S]*?return textwrap.dedent\(prompt\)\.strip\(\)\n"
new = '''def build_prompt(
    tags: List[str],
    difficulty: int,
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> str:
    branch_hint = (
        """
Include EXACTLY ONE branch array:
"branch": [
  {"condition": "x > 0", "equation": "Eq(y, k*x)"},
  {"condition": "x <= 0", "equation": "Eq(y, -k*x)"}
]
        """.strip()
        if branch_conditions > 0
        else "Do NOT include branch field."
    )

    prompt = f"""
You are a senior Sympy engineer. Output ONLY a JSON object (no code fences, no prose).

Goal: Define a solvable symbolic system for a single answer variable.

Required JSON keys:
- answer_var: string (the variable to solve, e.g., "k")
- variables: array of variable names (must include answer_var)
- equations: array of Sympy strings using Eq(lhs, rhs); count ≈ {solves_count} (±1)
- ranges: object mapping variable -> [min, max] integers (avoid zero when unsafe)
- branch (optional): only if branch_conditions > 0. If present, array of
    {{ "condition": "Sympy_boolean", "equation": "Eq(...)" }}. Conditions must use defined variables.

Rules:
- Sympy grammar only; no LaTeX.
- Every equation must contribute to solving answer_var; no disconnected pieces.
- Avoid division by zero / undefined expressions.
- Keep expressions simple (linear/affine preferred).
- If branch exists, equations + the chosen branch must be sufficient to solve answer_var.

Example skeleton (edit as needed, keep structure):
{{
  "answer_var": "k",
  "variables": ["x", "y", "k", "a", "b"],
  "equations": [
    "Eq(y, a*x + b)",
    "Eq(k, y - b)"
  ],
  "branch": [
    {{ "condition": "x > 0",  "equation": "Eq(y, k + a*x)" }},
    {{ "condition": "x <= 0", "equation": "Eq(y, k - a*x)" }}
  ],
  "ranges": {{
    "x": [1, 9],
    "y": [-9, 9],
    "a": [1, 5],
    "b": [-5, 5],
    "k": [-9, 9]
  }}
}}

Output JSON only. Do not wrap in ```; do not add explanations.
{branch_hint}
"""

    return textwrap.dedent(prompt).strip()
'''
text_new = re.sub(pattern, new, text)
p.write_text(text_new, encoding='utf-8')
