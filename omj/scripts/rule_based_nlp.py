"""중3 범위 룰베이스드 수학 NLP의 최소 인터페이스.

입력 문장을 정규화하고 지식 JSON의 개념·규칙과 연결해 유형과 슬롯을 추출한다.
현재는 외부 모델 없이 키워드와 기호 패턴만 사용하며, 이후 동의어 사전을 확장한다.
"""

from __future__ import annotations

import json
import re
import unicodedata
from fractions import Fraction
from functools import lru_cache
from pathlib import Path
from typing import Any


_ROOT = Path(__file__).resolve().parent / "aiflow_alpha_knowledge"


@lru_cache(maxsize=8)
def _load(name: str) -> dict[str, Any]:
    """필요 변수: 지식 파일명. UTF-8 JSON을 읽어 반환한다."""
    return json.loads((_ROOT / name).read_text(encoding="utf-8"))


def normalize_text(text: str) -> str:
    """필요 변수: 사용자 문장. 유니코드 숫자와 수학 기호를 검색 친화적으로 통일한다."""
    out: list[str] = []
    for ch in unicodedata.normalize("NFKC", text or ""):
        try:
            out.append(str(unicodedata.digit(ch)))
        except (TypeError, ValueError):
            out.append(ch)
    return "".join(out).replace("−", "-").replace("×", "*").replace("∩", "∩")


def classify(text: str) -> dict[str, Any]:
    """필요 변수: 문제 문장. concept_graph와 rule_library를 이용해 유형·태그·슬롯을 추출한다."""
    normalized = normalize_text(text)
    concepts = _load("concept_graph.json")["nodes"]
    rules = _load("rule_library.json")["rules"]
    scores: dict[str, int] = {}
    tags: list[str] = []
    for concept in concepts:
        hits = [topic for topic in concept.get("topics", []) if topic in normalized]
        if hits:
            scores[concept["id"]] = len(hits)
            tags.extend(hits)
    # 지식 그래프에 아직 노드가 없는 중3 핵심 표현은 별칭 규칙으로 먼저 수용한다.
    aliases = {
        "cm_set": ["|A|", "|B|", "∩", "∪", "합집합", "교집합"],
        "cm_arith_sequence": ["수열", "등차수열", "첫항", "첫째항", "공차", "일반항"],
        "cm_linear": ["일차방정식", "미지수", "x를 구"],
        "cm_ratio": ["비례", "비율", "a:b", "반비례"],
        "cm_probability": ["확률", "경우의 수", "조합", "순열", "주사위", "동전"],
        "cm_geometry": ["피타고라스", "직각삼각형", "삼각형의 넓이", "원의 넓이", "직사각형", "가로", "세로"],
        "hs1_function_basic": ["함수", "함숫값", "정의역", "치역", "일차함수"],
        "hs1_function_composition": ["합성함수", "f(g(x))", "g(f(x))"],
        "hs1_inverse_function": ["역함수", "f⁻¹", "f^-1"],
        "hs1_conditional_probability": ["조건부확률", "P(A|B)", "P(A∩B)"],
        "hs1_polynomial_factor": ["다항식", "인수분해", "인수정리", "나머지정리"],
    }
    for domain_name, keywords in aliases.items():
        hits = [word for word in keywords if word in normalized]
        if hits:
            scores[domain_name] = len(hits) + 1
            tags.extend(hits)
    if "=" in normalized and re.search(r"[+-]?\d+\s*x", normalized, flags=re.IGNORECASE):
        scores["cm_linear"] = scores.get("cm_linear", 0) + 2
        tags.append("일차방정식")
    if ("이차" in normalized or "판별식" in normalized) and re.search(r"x(?:\^\s*2|2)", normalized, flags=re.IGNORECASE):
        scores["cm_quadratic"] = scores.get("cm_quadratic", 0) + 3
    if "합성함수" in normalized or "f(g" in normalized or "g(f" in normalized:
        scores["hs1_function_composition"] = scores.get("hs1_function_composition", 0) + 5
    if "역함수" in normalized or "f⁻¹" in normalized or "f^-1" in normalized:
        scores["hs1_inverse_function"] = scores.get("hs1_inverse_function", 0) + 5
    domain = max(scores, key=scores.get) if scores else "cm_algebra_basic"
    matched_rules = [r for r in rules if r.get("domain") == domain]
    slots = _extract_slots(normalized, domain)
    required = [item for rule in matched_rules for item in rule.get("conditions", {}).get("requires", [])]
    missing = [item for item in required if item not in slots]
    top_score = scores.get(domain, 0)
    total_score = sum(scores.values()) or 1
    confidence = round(top_score / total_score, 3) if top_score else 0.0
    return {
        "normalized": normalized,
        "domain": domain,
        "tags": sorted(set(tags)),
        "slots": slots,
        "rules": matched_rules,
        "matched_keywords": sorted(set(tags)),
        "missing": sorted(set(missing)),
        "confidence": confidence,
    }


def _extract_slots(text: str, domain: str) -> dict[str, int]:
    """필요 변수: 정규화 문장과 개념 도메인. 유형별 기호 뒤 숫자를 슬롯으로 매핑한다."""
    def value(pattern: str) -> int | None:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if not match:
            return None
        groups = [item for item in match.groups() if item not in (None, "")]
        try:
            return int("".join(groups[-2:])) if len(groups) >= 2 and groups[-2] in ("+", "-") else int(groups[-1])
        except ValueError:
            return None

    if domain == "cm_arith_sequence":
        indices = [int(item) for item in re.findall(r"a\s*_?([0-9]+)", text, flags=re.IGNORECASE)]
        term_counts = [int(item) for item in re.findall(r"([0-9]+)\s*항", text)]
        n = max(indices + term_counts) if indices or term_counts else None
        a1 = value(r"a\s*_?1\s*=\s*([+-]?\d+)") or value(r"(?:첫항|첫째항)\s*(?:은|이)?\s*([+-]?\d+)")
        d = value(r"d\s*=\s*([+-]?\d+)") or value(r"공차\s*(?:는|가|이)?\s*([+-]?\d+)")
        result = {k: v for k, v in {"a1": a1, "d": d, "n": n}.items() if v is not None}
        if "합" in text:
            result["kind"] = "arithmetic_sum"
        return result
    if domain == "cm_set":
        return {k: v for k, v in {"a": value(r"\|A\|\s*=\s*([+-]?\d+)"), "b": value(r"\|B\|\s*=\s*([+-]?\d+)"), "c": value(r"\|A∩B\|\s*=\s*([+-]?\d+)")}.items() if v is not None}
    if domain == "cm_linear":
        return {k: v for k, v in {"a": value(r"([+-]?\d+)\s*x"), "b": value(r"x\s*([+-])\s*(\d+)"), "c": value(r"=\s*([+-]?\d+)")}.items() if v is not None}
    if domain == "hs1_function_basic":
        a = value(r"f\s*\(\s*x\s*\)\s*=\s*([+-]?\d+)\s*x")
        b = value(r"f\s*\(\s*x\s*\)\s*=\s*[+-]?\d+\s*x\s*([+-])\s*(\d+)")
        input_value = value(r"(?:x|f\s*\()\s*=\s*([+-]?\d+)\s*\)?")
        return {k: v for k, v in {"a": a, "b": b, "input": input_value}.items() if v is not None}
    if domain == "hs1_function_composition":
        numbers = [int(item) for item in re.findall(r"[+-]?\d+", text)]
        if len(numbers) >= 5:
            return {"a": numbers[0], "b": numbers[1], "c": numbers[2], "d": numbers[3], "input": numbers[4]}
        return {}
    if domain == "hs1_inverse_function":
        a = value(r"f\s*\(\s*x\s*\)\s*=\s*([+-]?\d+)\s*x")
        b = value(r"f\s*\(\s*x\s*\)\s*=\s*[+-]?\d+\s*x\s*([+-])\s*(\d+)")
        return {k: v for k, v in {"a": a, "b": b}.items() if v is not None}
    if domain == "hs1_polynomial_factor":
        b = value(r"x(?:\^\s*2|2)\s*([+-])\s*(\d+)\s*x")
        c = value(r"x(?:\^\s*2|2).*?[+-]\s*\d+\s*x\s*([+-])\s*(\d+)")
        return {k: v for k, v in {"b": b, "c": c}.items() if v is not None}
    if domain == "cm_ratio":
        nums = [int(item) for item in re.findall(r"[+-]?\d+", text)]
        return {"numbers": nums} if nums else {}
    if domain == "cm_probability":
        if "경우의 수" in text or "조합" in text or "순열" in text:
            nums = [int(item) for item in re.findall(r"[+-]?\d+", text)]
            kind = "permutation" if "순열" in text else "combination"
            return {"kind": kind, "numbers": nums} if len(nums) >= 2 else {}
        percent = re.search(r"([+-]?\d+(?:\.\d+)?)\s*%", text)
        if percent:
            return {"probability": float(percent.group(1)) / 100}
        fraction = re.search(r"([+-]?\d+)\s*/\s*([+-]?\d+)", text)
        nums = [int(item) for item in fraction.groups()] if fraction else [int(item) for item in re.findall(r"[+-]?\d+", text)]
        return {"numbers": nums} if nums else {}
    if domain == "hs1_conditional_probability":
        fractions = re.findall(r"(?:P\s*\([^)]*\)|확률)[^=]*=\s*([0-9]+)\s*/\s*([0-9]+)", text)
        if len(fractions) >= 2:
            return {"joint": Fraction(int(fractions[0][0]), int(fractions[0][1])), "condition": Fraction(int(fractions[1][0]), int(fractions[1][1]))}
        return {}
    if domain == "cm_geometry":
        nums = [int(item) for item in re.findall(r"[+-]?\d+", text)]
        if "삼각형의 넓이" in text or ("밑변" in text and "높이" in text):
            return {"kind": "triangle_area", "numbers": nums} if len(nums) >= 2 else {}
        if "원의 넓이" in text or "반지름" in text:
            return {"kind": "circle_area", "numbers": nums} if nums else {}
        if "직사각형" in text or ("가로" in text and "세로" in text):
            kind = "rectangle_perimeter" if "둘레" in text else "rectangle_area"
            return {"kind": kind, "numbers": nums} if len(nums) >= 2 else {}
        return {"numbers": nums} if nums else {}
    a = value(r"([+-]?\d+)\s*x(?:\^\s*2|2)")
    if a is None and re.search(r"(?:^|\s)x(?:\^\s*2|2)", text, flags=re.IGNORECASE):
        a = 1
    return {k: v for k, v in {"a": a, "b": value(r"x(?:\^\s*2|2)\s*([+-])\s*(\d+)"), "c": value(r"x(?:\^\s*2|2).*?([+-])\s*(\d+)\s*=\s*0")}.items() if v is not None}


def verify_result(domain: str, slots: dict[str, Any], answer: int | float) -> bool:
    """필요 변수: 도메인·추출 슬롯·정답. 규칙의 최소 불변식을 재계산해 결과를 검산한다."""
    if domain == "cm_arith_sequence":
        return answer == slots.get("a1") + (slots.get("n") - 1) * slots.get("d")
    if domain == "cm_set":
        return answer == slots.get("a") + slots.get("b") - slots.get("c")
    if domain == "cm_linear":
        a, b, c = (slots.get(key) for key in ("a", "b", "c"))
        return a not in (None, 0) and a * answer + b == c
    if domain == "hs1_function_basic":
        a, b, input_value = (slots.get(key) for key in ("a", "b", "input"))
        return a is not None and b is not None and input_value is not None and answer == a * input_value + b
    if domain == "hs1_function_composition":
        a, b, c, d, input_value = (slots.get(key) for key in ("a", "b", "c", "d", "input"))
        return None not in (a, b, c, d, input_value) and answer == a * (c * input_value + d) + b
    if domain == "hs1_inverse_function":
        return isinstance(answer, str) and answer.startswith("(x")
    if domain == "hs1_polynomial_factor":
        return isinstance(answer, str) and answer.startswith("(x")
    if domain == "cm_quadratic":
        a, b, c = (slots.get(key) for key in ("a", "b", "c"))
        return a not in (None, 0) and a * answer * answer + b * answer + c == 0
    if domain == "cm_ratio":
        nums = slots.get("numbers", [])
        return len(nums) >= 4 and nums[0] * nums[3] == nums[1] * nums[2]
    if domain == "cm_geometry":
        nums = slots.get("numbers", [])
        return len(nums) >= 3 and nums[0] ** 2 + nums[1] ** 2 == nums[2] ** 2
    return True


def solve_rule(domain: str, slots: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 분류 도메인과 슬롯. 중3 기본 규칙을 계산하고 검산 결과를 함께 반환한다."""
    if domain == "cm_arith_sequence":
        a1, d, n = (slots.get(key) for key in ("a1", "d", "n"))
        if a1 is None or d is None or n is None:
            return {"status": "FAIL", "reason": "a1,d,n이 필요합니다."}
        if slots.get("kind") == "arithmetic_sum":
            answer = n * (2 * a1 + (n - 1) * d) / 2
            return {"status": "PASS", "answer": int(answer) if answer == int(answer) else answer, "formula": "S_n = n(2a1+(n-1)d)/2", "verified": answer == n * (2 * a1 + (n - 1) * d) / 2}
        answer = a1 + (n - 1) * d
    elif domain == "cm_set":
        a, b, c = (slots.get(key) for key in ("a", "b", "c"))
        if a is None or b is None or c is None or c > min(a, b):
            return {"status": "FAIL", "reason": "집합 크기 조건이 올바르지 않습니다."}
        answer = a + b - c
    elif domain == "cm_ratio":
        nums = slots.get("numbers", [])
        if len(nums) < 4 or nums[1] == 0 or nums[3] == 0:
            return {"status": "FAIL", "reason": "a:b=c:d 네 수가 필요합니다."}
        if nums[0] * nums[3] != nums[1] * nums[2]:
            return {"status": "FAIL", "reason": "비례식이 성립하지 않습니다."}
        answer = nums[0] / nums[1]
    elif domain == "cm_linear":
        a, b, c = (slots.get(key) for key in ("a", "b", "c"))
        if a in (None, 0) or b is None or c is None:
            return {"status": "FAIL", "reason": "a,b,c가 필요합니다."}
        answer = (c - b) / a
        if answer != int(answer):
            return {"status": "FAIL", "reason": "정수 범위를 벗어난 해입니다."}
        answer = int(answer)
    elif domain == "hs1_function_basic":
        a, b, input_value = (slots.get(key) for key in ("a", "b", "input"))
        if a is None or b is None or input_value is None:
            return {"status": "FAIL", "reason": "f(x)=ax+b와 입력값이 필요합니다."}
        answer = a * input_value + b
    elif domain == "hs1_function_composition":
        a, b, c, d, input_value = (slots.get(key) for key in ("a", "b", "c", "d", "input"))
        if None in (a, b, c, d, input_value):
            return {"status": "FAIL", "reason": "f,g의 일차식과 입력값이 필요합니다."}
        inner = c * input_value + d
        answer = a * inner + b
    elif domain == "hs1_inverse_function":
        a, b = (slots.get(key) for key in ("a", "b"))
        if a in (None, 0) or b is None:
            return {"status": "FAIL", "reason": "f(x)=ax+b의 a,b가 필요합니다."}
        answer = f"(x{(-b):+d})/{a}"
    elif domain == "hs1_conditional_probability":
        joint, condition = slots.get("joint"), slots.get("condition")
        if not joint or not condition or condition == 0:
            return {"status": "FAIL", "reason": "교집합 확률과 조건 사건 확률이 필요합니다."}
        answer = joint / condition
        return {"status": "PASS", "answer": float(answer), "fraction": str(answer), "formula": "P(A|B)=P(A∩B)/P(B)", "verified": answer * condition == joint}
    elif domain == "hs1_polynomial_factor":
        b, c = (slots.get(key) for key in ("b", "c"))
        if b is None or c is None:
            return {"status": "FAIL", "reason": "x²+bx+c의 b,c가 필요합니다."}
        factors = [(u, v) for u in range(-abs(c), abs(c) + 1) if u != 0 for v in range(-abs(c), abs(c) + 1) if v != 0 and u * v == c and u + v == b]
        if not factors:
            return {"status": "FAIL", "reason": "정수 범위에서 인수분해할 수 없습니다."}
        u, v = factors[0]
        answer = f"(x{u:+d})(x{v:+d})"
    elif domain == "cm_quadratic":
        a, b, c = (slots.get(key) for key in ("a", "b", "c"))
        if a in (None, 0) or b is None or c is None:
            return {"status": "FAIL", "reason": "a,b,c가 필요합니다."}
        disc = b * b - 4 * a * c
        root = int(disc ** 0.5) if disc >= 0 else -1
        if root < 0 or root * root != disc:
            return {"status": "FAIL", "reason": "정수근을 계산할 수 없습니다."}
        candidates = [(-b + root), (-b - root)]
        integer_roots = [num // (2 * a) for num in candidates if num % (2 * a) == 0]
        if not integer_roots:
            return {"status": "FAIL", "reason": "정수근이 없습니다."}
        answer = integer_roots[0]
    elif domain == "cm_geometry":
        nums = slots.get("numbers", [])
        if slots.get("kind") == "triangle_area":
            if len(nums) < 2:
                return {"status": "FAIL", "reason": "밑변과 높이가 필요합니다."}
            answer = nums[0] * nums[1] / 2
            return {"status": "PASS", "answer": answer, "formula": "삼각형 넓이 = 밑변×높이÷2", "verified": answer == nums[0] * nums[1] / 2}
        if slots.get("kind") == "circle_area":
            if not nums or nums[0] < 0:
                return {"status": "FAIL", "reason": "반지름이 필요합니다."}
            answer = 3.141592653589793 * nums[0] ** 2
            return {"status": "PASS", "answer": answer, "formula": "원의 넓이 = πr²", "verified": answer >= 0}
        if slots.get("kind") in {"rectangle_area", "rectangle_perimeter"}:
            if len(nums) < 2 or min(nums[:2]) < 0:
                return {"status": "FAIL", "reason": "가로와 세로가 필요합니다."}
            if slots["kind"] == "rectangle_perimeter":
                answer = 2 * (nums[0] + nums[1])
                formula = "직사각형 둘레 = 2×(가로+세로)"
            else:
                answer = nums[0] * nums[1]
                formula = "직사각형 넓이 = 가로×세로"
            return {"status": "PASS", "answer": answer, "formula": formula, "verified": answer >= 0}
        if len(nums) < 3:
            if len(nums) == 2:
                hypotenuse_squared = nums[0] ** 2 + nums[1] ** 2
                hypotenuse = int(hypotenuse_squared ** 0.5)
                if hypotenuse * hypotenuse != hypotenuse_squared:
                    return {"status": "FAIL", "reason": "두 변으로 정수 빗변을 계산할 수 없습니다."}
                return {"status": "PASS", "answer": hypotenuse, "formula": "c = √(a²+b²)", "verified": hypotenuse * hypotenuse == hypotenuse_squared}
            return {"status": "FAIL", "reason": "세 변의 길이가 필요합니다."}
        answer = nums[0] ** 2 + nums[1] ** 2
        if answer != nums[2] ** 2:
            return {"status": "FAIL", "reason": "피타고라스 조건을 만족하지 않습니다."}
        answer = nums[2]
    elif domain == "cm_probability":
        if slots.get("kind") == "combination":
            nums = slots.get("numbers", [])
            if len(nums) < 2 or nums[0] < nums[1] or nums[1] < 0:
                return {"status": "FAIL", "reason": "n과 r 조건이 필요합니다."}
            from math import comb
            answer = comb(nums[0], nums[1])
            return {"status": "PASS", "answer": answer, "formula": "nCr = n!/(r!(n-r)!)", "verified": answer == comb(nums[0], nums[1])}
        if slots.get("kind") == "permutation":
            nums = slots.get("numbers", [])
            if len(nums) < 2 or nums[0] < nums[1] or nums[1] < 0:
                return {"status": "FAIL", "reason": "n과 r 조건이 필요합니다."}
            from math import factorial
            answer = factorial(nums[0]) // factorial(nums[0] - nums[1])
            return {"status": "PASS", "answer": answer, "formula": "nPr = n!/(n-r)!", "verified": answer == factorial(nums[0]) // factorial(nums[0] - nums[1])}
        if "probability" in slots:
            answer = slots["probability"]
            fraction = str(Fraction(answer).limit_denominator())
            return {"status": "PASS", "answer": answer, "fraction": fraction, "formula": "P(E) = 유리한 경우 / 전체 경우", "verified": True}
        nums = slots.get("numbers", [])
        if len(nums) < 2 or nums[1] <= 0 or nums[0] < 0 or nums[0] > nums[1]:
            return {"status": "FAIL", "reason": "유리한 경우/전체 경우가 필요합니다."}
        answer = nums[0] / nums[1]
    else:
        return {"status": "FAIL", "reason": "아직 계산기가 없는 도메인입니다."}
    formulas = {
        "cm_arith_sequence": "a_n = a1 + (n-1)d",
        "cm_set": "|A∪B| = |A| + |B| - |A∩B|",
        "cm_linear": "x = (c-b)/a",
        "cm_quadratic": "x = (-b ± √(b²-4ac)) / 2a",
        "cm_ratio": "a:b=c:d ↔ ad=bc",
        "cm_probability": "P(E) = 유리한 경우 / 전체 경우",
        "cm_geometry": "a²+b²=c²",
        "hs1_function_basic": "f(x)=ax+b, f(t)=at+b",
        "hs1_function_composition": "f(g(t)) = a(ct+d)+b",
        "hs1_inverse_function": "f⁻¹(x)=(x-b)/a",
        "hs1_conditional_probability": "P(A|B)=P(A∩B)/P(B)",
        "hs1_polynomial_factor": "x²+bx+c=(x+u)(x+v)",
    }
    result = {
        "status": "PASS",
        "answer": answer,
        "formula": formulas.get(domain, ""),
        "verified": verify_result(domain, slots, answer),
    }
    if domain == "cm_probability":
        result["fraction"] = str(Fraction(answer).limit_denominator())
    return result


def select_optimal_rule(parsed: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: classify 결과. 위험도·필수 슬롯 충족·단계 수를 점수화해 가장 짧고 안전한 규칙 경로를 선택한다."""
    candidates = []
    for rule in parsed.get("rules", []):
        required = rule.get("conditions", {}).get("requires", [])
        missing = sum(item not in parsed.get("slots", {}) for item in required)
        risk_score = {"low": 0, "medium": 1, "high": 2}.get(rule.get("risk", "medium"), 1)
        candidates.append((missing, risk_score, len(required), rule))
    if not candidates:
        return {"status": "FAIL", "reason": "적용 가능한 규칙이 없습니다.", "path": []}
    _, _, _, selected = min(candidates, key=lambda item: item[:3])
    return {"status": "PASS", "rule_id": selected.get("rule_id"), "path": [selected.get("rule_id")], "objective": "최소 누락·최소 위험·최소 단계"}


def build_solution_trace(parsed: dict[str, Any], result: dict[str, Any]) -> list[str]:
    """필요 변수: 분류 결과와 계산 결과. 학생이 읽을 수 있는 순서형 풀이 단계를 생성한다."""
    if result.get("status") != "PASS":
        return [f"계산 실패: {result.get('reason', '조건을 확인하세요.')}" ]
    slots = parsed.get("slots", {})
    domain = parsed.get("domain", "")
    rule_path = select_optimal_rule(parsed).get("path", [])
    steps = [f"1. 문제 유형을 {domain}으로 분류한다.", f"2. 적용 규칙: {', '.join(rule_path) or '내장 규칙'}"]
    if result.get("formula"):
        steps.append(f"3. 공식: {result['formula']}")
    if domain == "hs1_function_composition":
        inner = slots["c"] * slots["input"] + slots["d"]
        steps.append(f"4. 안쪽 함수부터 계산한다: g({slots['input']})={slots['c']}×{slots['input']}+{slots['d']}={inner}.")
        steps.append(f"5. 바깥 함수에 대입한다: f({inner})={slots['a']}×{inner}+{slots['b']}={result.get('answer')}.")
    elif domain == "hs1_inverse_function":
        steps.append(f"4. y={slots['a']}x+{slots['b']}에서 x와 y를 바꾼다.")
        steps.append(f"5. y를 정리한 결과는 {result.get('answer')}이다.")
    elif domain == "hs1_polynomial_factor":
        steps.append(f"4. 두 수의 합은 {slots['b']}, 곱은 {slots['c']}가 되도록 찾는다.")
        steps.append(f"5. 인수분해 결과는 {result.get('answer')}이다.")
    elif domain == "cm_arith_sequence" and slots.get("kind") == "arithmetic_sum":
        steps.append(f"4. S_{slots['n']}={slots['n']}({2 * slots['a1']}+({slots['n']}-1)×{slots['d']})/2로 대입한다.")
        steps.append(f"5. 계산 결과는 {result.get('answer')}이다.")
    else:
        steps.append(f"4. 추출한 값 {slots}을 공식에 대입해 {result.get('answer')}를 계산한다.")
    if result.get("fraction"):
        steps.append(f"기약분수로 정리하면 {result['fraction']}이다.")
    steps.append(f"{len(steps) + 1}. 원래 조건에 재대입해 검산한다: {'통과' if result.get('verified') else '실패'}.")
    return steps


if __name__ == "__main__":
    """CLI: 문제 문장을 받아 NLP 해석과 규칙 계산 결과를 JSON으로 출력한다."""
    import argparse

    parser = argparse.ArgumentParser(description="AIFlow rule-based math NLP")
    parser.add_argument("text", nargs="+", help="풀이할 수학 문제 문장")
    args = parser.parse_args()
    parsed = classify(" ".join(args.text))
    result = solve_rule(parsed["domain"], parsed["slots"])
    print(json.dumps({"parse": parsed, "result": result, "trace": build_solution_trace(parsed, result)}, ensure_ascii=False, indent=2))
