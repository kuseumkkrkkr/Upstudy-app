from __future__ import annotations

import math
import re
from dataclasses import dataclass
from fractions import Fraction
from typing import Any, Callable, Optional

from k_wolfram_alpha_dsl import KAlphaProblemProgram


def _safe_number(value: str) -> Optional[Fraction]:
    """필요 변수: 문자열 정답.
    작동 원리: 정수/소수/간단한 분수만 허용해 산술 비교 시 오차를 줄인다."""
    token = str(value).replace(",", "").replace(" ", "").strip()
    token = token.replace("−", "-")
    if token == "":
        return None

    frac_match = re.fullmatch(r"([+-]?\d+)\s*/\s*([+-]?\d+)", token)
    if frac_match:
        numerator = int(frac_match.group(1))
        denominator = int(frac_match.group(2))
        if denominator == 0:
            return None
        return Fraction(numerator, denominator)

    try:
        # Decimal 기반 정규화는 소수 비교 오차를 유도할 수 있으므로 유리수로 변환한다.
        if "." in token:
            return Fraction(token)
        return Fraction(int(token), 1)
    except Exception:
        return None


def _eval_expr(formula: str, variables: dict[str, Any]) -> Fraction:
    """필요 변수: 수식 문자열, 변수 맵.
    작동 원리: 파이썬 eval를 사용하지 않고 AST와 기본 연산만 허용해 정답 계산을 수행한다."""
    import ast

    allowed = {ast.Expression, ast.BinOp, ast.UnaryOp, ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Pow, ast.USub, ast.Load, ast.Name, ast.Constant, ast.FloorDiv, ast.Mod}

    tree = ast.parse(formula, mode="eval")
    for node in ast.walk(tree):
        if type(node) not in allowed:
            raise ValueError(f"disallowed node: {type(node).__name__}")

    def _visit(node: ast.AST) -> Fraction:
        if isinstance(node, ast.Expression):
            return _visit(node.body)
        if isinstance(node, ast.BinOp):
            left = _visit(node.left)
            right = _visit(node.right)
            if isinstance(node.op, ast.Add):
                return left + right
            if isinstance(node.op, ast.Sub):
                return left - right
            if isinstance(node.op, ast.Mult):
                return left * right
            if isinstance(node.op, ast.Div):
                if right == 0:
                    raise ZeroDivisionError("division by zero")
                return left / right
            if isinstance(node.op, ast.FloorDiv):
                if right == 0:
                    raise ZeroDivisionError("division by zero")
                return left // right
            if isinstance(node.op, ast.Pow):
                return left ** right
            if isinstance(node.op, ast.Mod):
                return left % right
            raise ValueError("unsupported operator")
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -_visit(node.operand)
        if isinstance(node, ast.Name):
            value = variables.get(node.id, 0)
            if isinstance(value, bool):
                return Fraction(int(value), 1)
            if isinstance(value, (int, float, str, Fraction)):
                return Fraction(str(value)) if not isinstance(value, Fraction) else value
            raise ValueError(f"unsupported variable type: {type(value)}")
        if isinstance(node, ast.Constant):
            if isinstance(node.value, (int, float)):
                return Fraction(str(node.value))
            if isinstance(node.value, str):
                return Fraction(int(node.value), 1)
            raise ValueError("unsupported constant")
        raise ValueError("unsupported node")

    return _visit(tree)


def _check_bounds(value: Fraction, checks: dict[str, Any]) -> bool:
    """필요 변수: 채점 값, bounds.
    작동 원리: 템플릿별 정답형 안전 범위를 넘지 않는지 사전 검사한다."""
    min_v = checks.get("min", -10**12)
    max_v = checks.get("max", 10**12)
    return min_v <= float(value) <= max_v


@dataclass
class GradingResult:
    """필요 변수: 정답 후보.
    작동 원리: PASS/FAIL/REVIEW 코드와 비교 상세 이유를 함께 저장해 루프에서 집계한다."""

    status: str
    score: float
    expected: Optional[str]
    submitted: Optional[str]
    reason: str


def grade_program_answer(
    program: KAlphaProblemProgram,
    submitted_answer: str,
    *,
    evaluate_formula: Callable[[str, dict[str, Any]], Fraction] = _eval_expr,
) -> GradingResult:
    """필요 변수: 문제 프로그램과 사용자 답안.
    작동 원리: ① 정답식으로 정답 계산 → ② 타입 정규화 비교 → ③ bound/오차 규칙 반영해 등급화한다."""
    checks = program.checks or {}
    try:
        expected_value = evaluate_formula(program.answer_formula, program.vars)
    except Exception as exc:
        return GradingResult("REVIEW_REQUIRED", 0.0, program.expected_answer, str(submitted_answer), f"evaluate_error:{exc}")

    if not _check_bounds(expected_value, checks):
        return GradingResult("REVIEW_REQUIRED", 0.0, str(expected_value), str(submitted_answer), "answer_out_of_bounds")

    user_value = _safe_number(submitted_answer)
    if user_value is None:
        return GradingResult("FAIL", 0.0, str(expected_value), str(submitted_answer), "invalid_user_number")
    if program.question_type == "ratio":
        tol = float(checks.get("tolerance", 1e-9))
        if math.isclose(float(user_value), float(expected_value), abs_tol=tol, rel_tol=tol):
            return GradingResult("PASS", 1.0, str(expected_value), str(user_value), "ok")
        return GradingResult("FAIL", 0.0, str(expected_value), str(user_value), "numeric_mismatch")

    if user_value == expected_value:
        return GradingResult("PASS", 1.0, str(expected_value), str(user_value), "ok")
    return GradingResult("FAIL", 0.0, str(expected_value), str(user_value), "numeric_mismatch")
