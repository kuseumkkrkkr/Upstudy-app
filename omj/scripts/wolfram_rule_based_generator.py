from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


def normalize_tag(tag: str) -> str:
    """필요 변수: 입력 태그 문자열. 작동 원리: 공백/기호를 정리해 내부 처리용 정규 태그를 만든다."""
    return tag.strip().lstrip("#")


def parse_tags(raw: list[str] | None) -> list[str]:
    """필요 변수: 사용자 태그 리스트. 작동 원리: 중복 제거 후 사용 가능한 고유 태그만 정렬해 엔진에 넘긴다."""
    if not raw:
        return []
    seen: set[str] = set()
    clean: list[str] = []
    for item in raw:
        norm = normalize_tag(item)
        if not norm or norm in seen:
            continue
        seen.add(norm)
        clean.append(norm)
    return clean


def parse_flowchart(raw_flowchart: str | None) -> list[dict[str, Any]]:
    """필요 변수: JSON 문자열. 작동 원리: 입력을 파싱해 노드 리스트를 만들고, 실패 시 기본 노드로 fallback한다."""
    if not raw_flowchart:
        return [
            {"id": "n1", "text": "주어진 조건을 정리한다.", "branches": []},
            {"id": "n2", "text": "식으로 정리한 뒤 미지수를 정의한다.", "branches": []},
            {"id": "n3", "text": "계산하고 최종 답을 검산한다.", "branches": []},
        ]

    try:
        loaded = json.loads(raw_flowchart)
        nodes = loaded.get("nodes")
        if isinstance(nodes, list) and nodes:
            return [n for n in nodes if isinstance(n, dict)]
    except json.JSONDecodeError:
        pass
    return [
        {"id": "n1", "text": "입력 플로우차트를 읽기 어렵다. 조건을 정수화한다.", "branches": []},
        {"id": "n2", "text": "기본 공식 1개로 근사 해를 추정한다.", "branches": []},
    ]


def parse_numbers_from_prompt(prompt: str) -> list[int]:
    """????? ?? ??? ????."""
    import unicodedata

    values: list[int] = []
    num = ""

    def _to_ascii_digit(ch: str) -> str | None:
        if ch == "-":
            return ch
        if ch.isdigit():
            # ?? 0-9 ?? ???? ??(??/?? ?)?? ??
            try:
                return str(int(ch))
            except Exception:
                try:
                    return str(unicodedata.digit(ch))
                except Exception:
                    return None
        return None

    for ch in prompt:
        digit = _to_ascii_digit(ch)
        if digit is not None and not (digit == "-" and num):
            num += digit
            continue

        if num not in ("", "-"):
            values.append(int(num))
        num = ""

    if num not in ("", "-"):
        values.append(int(num))
    return values



def pick_template(tag_set: set[str]) -> dict[str, str]:
    """필요 변수: 정규화된 태그 집합. 작동 원리: 우선순위 룰로 수학 유형을 뽑아 문제 골격을 만든다."""
    if {"이차방정식", "이차함수", "근의공식", "판별식"} & tag_set:
        return {
            "type": "quadratic",
            "question": "{a}x² + {b}x + {c} = 0의 정수 해 x를 구하시오.",
            "hint": "판별식 D를 계산해 근의 공식을 사용해 정수 해를 고른다.",
        }
    if {"수열", "등차수열", "등비수열"} & tag_set:
        return {
            "type": "sequence",
            "question": "등차수열 aₙ = {a1} + ({d})(n-1)일 때, a₃의 값은?",
            "hint": "일반항 공식을 aₙ = a₁ + d(n-1)으로 계산한다.",
        }
    if {"확률", "경우의수", "순열", "조합"} & tag_set:
        return {
            "type": "combinatorics",
            "question": "1부터 {n}까지에서 서로 다른 숫자 2개를 뽑는 경우의 수를 구하시오.",
            "hint": "조합식 nC2를 사용한다.",
        }
    if {"집합", "명제", "교집합", "합집합"} & tag_set:
        return {
            "type": "set",
            "question": "|A|={a}, |B|={b}, |A∩B|={c}일 때 |A∪B|를 구하시오.",
            "hint": "합집합 공식 |A∪B| = |A|+|B|-|A∩B|를 적용한다.",
        }
    return {
        "type": "arithmetic",
        "question": "정수 a, b, c의 합이 {s}이고 a:b:c = {r1}:{r2}:{r3}일 때, b의 값은?",
        "hint": "비례를 a=kt, b=lt, c=mt로 두고 합 연산으로 t를 구한다.",
    }


@dataclass
class ProblemBlueprint:
    problem_type: str
    prompt: str
    hint: str
    answer: int
    vars: dict[str, int]
    flow_steps: list[str]


def build_blueprint(tags: list[str], prompt: str, raw_flowchart: str | None, seed: int | None) -> ProblemBlueprint:
    """필요 변수: 태그, 프롬프트, 플로우차트, 시드. 작동 원리: 템플릿 매칭+난수시드로 값/풀이 단계를 구성한다."""
    rng = random.Random(seed)
    clean_tags = parse_tags(tags)
    tag_set = {normalize_tag(tag) for tag in clean_tags}
    template = pick_template(tag_set)
    nums = parse_numbers_from_prompt(prompt) or [6, 3, 4, 1, 2, 3]

    values: dict[str, int] = {}
    # 필요 변수: 템플릿 종류. 작동 원리: 유형별로 파라미터를 정수 보정해 계산 가능한 형태로 생성한다.
    if template["type"] == "quadratic":
        a = rng.randint(1, 4) if len(nums) < 1 else abs(nums[0]) % 4 + 1
        b = rng.randint(-9, 9) if len(nums) < 2 else nums[1] if nums[1] != 0 else 2
        d = (a * a) // 2 if a * a > 8 else 5
        c = rng.choice([-(d), -(d * d), -(a * 2)]) if template["type"] == "quadratic" else -1
        while (b * b - 4 * a * c) < 0:
            c += 1
        values.update({"a": a, "b": b, "c": c})
        statement = f"{template['question'].format(**values)}"
        answer_value = _solve_quadratic_integer_root(a, b, c)
        hint = f"{template['hint']} (D={b*b-4*a*c})"
    elif template["type"] == "sequence":
        a1 = abs(nums[0]) if nums else 3
        d = abs(nums[1]) if len(nums) > 1 and nums[1] != 0 else 4
        values.update({"a1": a1, "d": d})
        statement = template["question"].format(**values)
        answer_value = a1 + d * 2
        hint = template["hint"]
    elif template["type"] == "combinatorics":
        n = abs(nums[0]) if nums else 8
        if n < 2:
            n = 6
        values.update({"n": n})
        statement = template["question"].format(**values)
        answer_value = n * (n - 1) // 2
        hint = template["hint"]
    elif template["type"] == "set":
        a = abs(nums[0]) if nums else 16
        b = abs(nums[1]) if len(nums) > 1 else 9
        c = abs(nums[2]) if len(nums) > 2 and abs(nums[2]) < min(a, b) else max(1, min(a, b) // 4)
        values.update({"a": a, "b": b, "c": c})
        statement = template["question"].format(**values)
        answer_value = a + b - c
        hint = template["hint"]
    else:
        s = abs(nums[0]) if nums else 60
        r = [abs(v) + 1 for v in nums[1:4]] or [2, 3, 5]
        r1, r2, r3 = r[:3]
        values.update({"s": s, "r1": r1, "r2": r2, "r3": r3})
        statement = template["question"].format(**values)
        t = s // (r1 + r2 + r3)
        answer_value = r2 * t
        hint = template["hint"]

    # 필요 변수: flowchart 노드들. 작동 원리: 각 노드 텍스트를 순서대로 풀이 단계로 기록한다.
    flow_nodes = parse_flowchart(raw_flowchart)
    steps = [f"{idx + 1}. {node.get('text', '')}" for idx, node in enumerate(flow_nodes)]
    if not steps:
        steps = ["1. 조건을 정리한다.", "2. 수식으로 바꾼다.", "3. 정답을 계산하고 검산한다."]

    return ProblemBlueprint(
        problem_type=template["type"],
        prompt=statement,
        hint=hint,
        answer=answer_value,
        vars=values,
        flow_steps=steps,
    )


def _solve_quadratic_integer_root(a: int, b: int, c: int) -> int:
    """필요 변수: 이차식 계수 a,b,c. 작동 원리: 판별식이 완전제곱인지 확인 후 정수 해가 하나라도 있으면 반환한다."""
    if a == 0:
        if b == 0:
            return 0
        return -c // b if b != 0 else 0
    disc = b * b - 4 * a * c
    r = int(disc**0.5)
    if r * r != disc:
        return 0
    root1 = (-b + r) // (2 * a)
    if (-b + r) % (2 * a) == 0:
        return root1
    root2 = (-b - r) // (2 * a)
    if (-b - r) % (2 * a) == 0:
        return root2
    return 0


def build_question_payload(blueprint: ProblemBlueprint, tags: list[str], prompt: str, seed: int | None) -> dict[str, Any]:
    """필요 변수: 생성된 blueprint. 작동 원리: 문제 본문/메타데이터/평가 규칙을 고정 스키마로 직렬화한다."""
    return {
        "problem_id": f"rb-{datetime.now().strftime('%Y%m%d%H%M%S')}",
        "type": blueprint.problem_type,
        "prompt": prompt,
        "question": blueprint.prompt,
        "hint": blueprint.hint,
        "params": blueprint.vars,
        "final_answer": str(blueprint.answer),
        "steps": blueprint.flow_steps,
        "tags": parse_tags(tags),
        "seed": seed,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
    }


def _demo_payload() -> dict[str, Any]:
    """필요 변수: 고정 샘플. 작동 원리: 실제 실행 없이도 엔진 동작을 확인할 수 있는 데모 입력을 반환한다."""
    sample_prompt = "수열에서 첫항과 공차가 주어진다. a1=5, d=2인 등차수열의 a3를 구해줘."
    sample_tags = ["#수열", "#등차수열", "#고교 수학"]
    sample_flow = {
        "nodes": [
            {"id": "input", "text": "조건 a1, d를 확인한다.", "branches": []},
            {"id": "formula", "text": "일반항 공식을 적용한다.", "branches": []},
            {"id": "calc", "text": "n=3을 대입해 계산한다.", "branches": []},
            {"id": "check", "text": "결과를 다시 문제 조건에 맞춰 점검한다.", "branches": []},
        ]
    }
    blue = build_blueprint(
        tags=sample_tags,
        prompt=sample_prompt,
        raw_flowchart=json.dumps(sample_flow, ensure_ascii=False),
        seed=2026,
    )
    return build_question_payload(blue, sample_tags, sample_prompt, 2026)


def parse_args() -> argparse.Namespace:
    """필요 변수: 실행 인자. 작동 원리: 태그, 프롬프트, 플로우차트, 난수시드, 출력 개수를 CLI로 받는다."""
    parser = argparse.ArgumentParser(description="Wolfram-like rule based math generator demo")
    parser.add_argument("--tag", action="append", default=[], help="문제 태그 (#이차방정식 등)")
    parser.add_argument("--prompt", default="", help="문제 생성 프롬프트")
    parser.add_argument("--flowchart", default="", help="flowchart JSON 문자열")
    parser.add_argument("--seed", type=int, default=None, help="난수 시드")
    parser.add_argument("--count", type=int, default=1, help="생성 문제 개수")
    parser.add_argument("--save", default="", help="결과 JSON 저장 경로(선택)")
    return parser.parse_args()


def main() -> int:
    """필요 변수: CLI 인자. 작동 원리: 인자를 바탕으로 문제를 생성하고 JSON으로 출력하거나 파일로 저장한다."""
    args = parse_args()
    count = max(1, min(20, args.count))

    if not args.tag and not args.prompt:
        payload = _demo_payload()
        print(json.dumps([payload], ensure_ascii=False, indent=2))
        return 0

    results: list[dict[str, Any]] = []
    for idx in range(count):
        seed = (args.seed or 2000) + idx
        blueprint = build_blueprint(
            tags=args.tag,
            prompt=args.prompt,
            raw_flowchart=args.flowchart,
            seed=seed,
        )
        results.append(build_question_payload(blueprint, args.tag, args.prompt, seed))

    if args.save:
        out = Path(args.save).resolve()
        out.write_text(
            json.dumps(results, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"SAVED {out}")
    else:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
