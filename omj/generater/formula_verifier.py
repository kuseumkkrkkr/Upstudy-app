from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple
import random

import sympy

from baselines.basemodel import FormulaPlan

_DEFAULT_RANGE = (-9, 9)


def _normalize_range(value: Any) -> Tuple[int, int]:
    if isinstance(value, (list, tuple)) and len(value) >= 2:
        try:
            lo = int(value[0])
            hi = int(value[1])
        except (TypeError, ValueError):
            return _DEFAULT_RANGE
        if lo <= hi:
            return lo, hi
        return hi, lo
    return _DEFAULT_RANGE


def _build_locals() -> Dict[str, Any]:
    return {
        "Eq": sympy.Eq,
        "log": sympy.log,
        "exp": sympy.exp,
        "sqrt": sympy.sqrt,
        "sin": sympy.sin,
        "cos": sympy.cos,
        "tan": sympy.tan,
        "Abs": sympy.Abs,
    }


def _parse_equations(equations: List[str]) -> List[sympy.Eq]:
    locals_dict = _build_locals()
    parsed: List[sympy.Eq] = []
    for raw in equations:
        expr = sympy.sympify(str(raw), locals=locals_dict)
        if isinstance(expr, sympy.core.relational.Relational):
            parsed.append(sympy.Eq(expr.lhs, expr.rhs))
        else:
            parsed.append(sympy.Eq(expr, 0))
    return parsed


def _parse_constraints(constraints: List[str]) -> List[sympy.Expr]:
    locals_dict = _build_locals()
    parsed: List[sympy.Expr] = []
    for raw in constraints:
        expr = sympy.sympify(str(raw), locals=locals_dict)
        parsed.append(expr)
    return parsed


def _serialize_value(value: sympy.Expr) -> Any:
    if value is None:
        return None
    if isinstance(value, sympy.Integer):
        return int(value)
    if isinstance(value, sympy.Rational):
        return float(value)
    if hasattr(value, "is_integer") and value.is_integer() is True:
        return int(value)
    if hasattr(value, "is_real") and value.is_real() is True:
        try:
            return float(value)
        except TypeError:
            return str(value)
    return str(value)


def _has_invalid_value(value: sympy.Expr) -> bool:
    return bool(value.has(sympy.zoo, sympy.oo, sympy.nan))


def _check_constraints(
    constraints: List[sympy.Expr],
    substitutions: Dict[sympy.Symbol, sympy.Expr],
) -> bool:
    for expr in constraints:
        try:
            evaluated = sympy.simplify(expr.subs(substitutions))
        except Exception:
            return False
        if evaluated.free_symbols:
            return False
        try:
            if bool(evaluated) is False:
                return False
        except Exception:
            return False
    return True


def verify_formula_plan(
    plan: FormulaPlan,
    *,
    attempts: int = 20,
    rng: random.Random | None = None,
) -> Dict[str, Any]:
    if not plan.answer_vars:
        raise ValueError("answer_vars must not be empty")
    if not plan.equations:
        raise ValueError("equations must not be empty")

    rng = rng or random.Random()
    last_error: Optional[str] = None
    try:
        equations = _parse_equations(plan.equations)
        constraints = _parse_constraints(plan.guardrails)
    except Exception as exc:
        return {
            "attempts": max(1, int(attempts)),
            "successes": 0,
            "last_error": str(exc),
            "latex_lines": [],
            "sample_params": {},
            "sample_answers": {},
            "sample_seed": None,
        }

    answer_names = [name.strip() for name in plan.answer_vars if name.strip()]
    if not answer_names:
        raise ValueError("answer_vars must not be empty")

    answer_symbols = {name: sympy.symbols(name) for name in answer_names}
    all_symbols = set()
    for eq in equations:
        all_symbols |= set(eq.free_symbols)
    for constraint in constraints:
        all_symbols |= set(constraint.free_symbols)

    param_symbols = [sym for sym in all_symbols if sym.name not in answer_symbols]
    param_symbols.sort(key=lambda sym: sym.name)

    ranges = {name: _normalize_range(plan.ranges.get(name)) for name in plan.ranges}
    successes = 0
    sample_params: Dict[str, Any] = {}
    sample_answers: Dict[str, Any] = {}

    latex_lines = [sympy.latex(eq) for eq in equations]

    sample_seed: int | None = None

    for _ in range(max(1, int(attempts))):
        attempt_seed = rng.randint(1, 1_000_000_000)
        local_rng = random.Random(attempt_seed)
        param_values: Dict[sympy.Symbol, sympy.Expr] = {}
        for sym in param_symbols:
            lo, hi = ranges.get(sym.name, _DEFAULT_RANGE)
            value = None
            for _ in range(20):
                candidate = local_rng.randint(lo, hi)
                if candidate == 0 and (lo < 0 < hi):
                    continue
                value = candidate
                break
            if value is None:
                value = local_rng.randint(lo, hi)
            param_values[sym] = sympy.Integer(value)

        try:
            solutions = sympy.solve(equations, list(answer_symbols.values()), dict=True)
        except Exception as exc:
            last_error = str(exc)
            continue

        if not solutions:
            last_error = "no solutions"
            continue

        for sol in solutions:
            answer_values: Dict[sympy.Symbol, sympy.Expr] = {}
            valid = True
            for name, sym in answer_symbols.items():
                expr = sol.get(sym)
                if expr is None:
                    valid = False
                    break
                try:
                    evaluated = sympy.simplify(expr.subs(param_values))
                except Exception as exc:
                    last_error = str(exc)
                    valid = False
                    break
                if evaluated.free_symbols or _has_invalid_value(evaluated):
                    last_error = "non-finite or symbolic answer"
                    valid = False
                    break
                if hasattr(evaluated, "is_real") and evaluated.is_real() is False:
                    last_error = "non-real answer"
                    valid = False
                    break
                answer_values[sym] = evaluated

            if not valid:
                continue

            substitutions = dict(param_values)
            substitutions.update(answer_values)
            if not _check_constraints(constraints, substitutions):
                last_error = "constraints not satisfied"
                continue

            successes += 1
            if not sample_params:
                sample_params = {sym.name: _serialize_value(val) for sym, val in param_values.items()}
                sample_answers = {sym.name: _serialize_value(val) for sym, val in answer_values.items()}
                sample_seed = attempt_seed
            break

    return {
        "attempts": max(1, int(attempts)),
        "successes": successes,
        "last_error": last_error,
        "latex_lines": latex_lines,
        "sample_params": sample_params,
        "sample_answers": sample_answers,
        "sample_seed": sample_seed,
    }
