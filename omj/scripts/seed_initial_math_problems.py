from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from difficulty_contract import DIFFICULTY_CONTRACTS
from generater.fix_gen import get_main_grade
from student_problem_content_review import review_student_problem_contract


BATCH_ID = "initial-math-v1"
QUEST_ID_PREFIX = f"curated/{BATCH_ID}"
TIER_STEP_HUDDLES = {
    1: [0, 0],
    2: [0, 0, 0],
    3: [1, 1, 1, 1],
    4: [1, 1, 1, 1, 1],
    5: [1, 2, 2, 2, 3, 3],
}
TIER_TAG_COUNTS = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}


def _content(value: str) -> dict[str, list[dict[str, str]]]:
    """필요 변수: `$...$` 수식이 포함된 UTF-8 문자열. 작동 원리: 일반 문장과 LaTeX를 앱의 콘텐츠 블록 배열로 분리한다."""
    blocks: list[dict[str, str]] = []
    for part in re.split(r"(\$[^$]+\$)", value):
        if not part:
            continue
        if part.startswith("$") and part.endswith("$"):
            blocks.append({"type": "latex", "content": part[1:-1]})
        else:
            blocks.append({"type": "text", "content": part})
    return {"blocks": blocks}


def _content_text(value: Any) -> str:
    """필요 변수: 콘텐츠 블록 또는 JSON 문자열. 작동 원리: 중복 검사에 쓸 수 있도록 모든 블록의 내용을 한 문자열로 합친다."""
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return value.strip()
    if isinstance(value, dict):
        if isinstance(value.get("blocks"), list):
            return " ".join(_content_text(block) for block in value["blocks"]).strip()
        return str(value.get("content") or value.get("text") or "").strip()
    if isinstance(value, list):
        return " ".join(_content_text(item) for item in value).strip()
    return str(value or "").strip()


def _problem(
    tier: int,
    index: int,
    *,
    title: str,
    answer: str,
    tags: list[str],
    steps: list[tuple[str, str]],
    alternatives: list[str] | None = None,
) -> dict[str, Any]:
    """필요 변수: 난이도·문제·정답·태그·풀이. 작동 원리: 사람이 검수하기 쉬운 원본 명세를 결정적 ID가 있는 항목으로 묶는다."""
    return {
        "tier": tier,
        "index": index,
        "title": title,
        "answer": answer,
        "tags": tags,
        "steps": steps,
        "alternatives": alternatives or [],
    }


def _branch_step(note: str, tags: list[str], tier: int) -> dict[str, Any]:
    """필요 변수: 대안 풀이 설명·태그·티어. 작동 원리: 본 풀이와 독립된 검산 또는 대안 풀이를 분기 노드로 만든다."""
    return {
        "flow": _content("다른 풀이 경로로 같은 결론을 확인한다."),
        "hash_tag": tags,
        "hint_riddle": _content("앞의 계산을 다른 정의나 그래프 관점에서 다시 살펴본다."),
        "answer_riddle": _content(note),
        "enter_huddle": max(1, DIFFICULTY_CONTRACTS[tier].strategy_level - 1),
        "branches": [],
    }


def _walk_steps(steps: Iterable[dict[str, Any]]) -> Iterable[dict[str, Any]]:
    """필요 변수: 재귀 풀이 단계. 작동 원리: 본선과 모든 하위 분기를 한 번씩 순회한다."""
    for step in steps:
        yield step
        yield from _walk_steps(step.get("branches") or [])


def _build_quest(spec: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 검수 가능한 문제 명세. 작동 원리: 난이도 계약·태그·콘텐츠 블록·캐시 식별자를 앱 저장 형식으로 조립한다."""
    tier = int(spec["tier"])
    index = int(spec["index"])
    tags = list(spec["tags"])
    hurdles = TIER_STEP_HUDDLES[tier]
    solves: list[dict[str, Any]] = []
    for step_index, (flow, explanation) in enumerate(spec["steps"]):
        solves.append(
            {
                "flow": _content(flow),
                "hash_tag": tags,
                "hint_riddle": _content(f"{step_index + 1}단계의 핵심 조건을 식으로 먼저 정리한다."),
                "answer_riddle": _content(explanation),
                "enter_huddle": hurdles[step_index],
                "branches": [],
            }
        )
    if solves:
        solves[-1]["branches"] = [
            _branch_step(note, tags, tier) for note in spec["alternatives"]
        ]

    all_steps = list(_walk_steps(solves))
    branch_count = len(all_steps) - len(solves)
    strategy_sum = sum(int(step["enter_huddle"]) for step in all_steps)
    difficulty_score = (
        len(tags)
        + 4 * len(all_steps)
        + 3 * branch_count
        + 2 * strategy_sum
    )
    quest_id = f"{QUEST_ID_PREFIX}/t{tier}-{index:02d}"
    variant_number = tier * 100 + index
    return {
        "header": {
            "quest_id": quest_id,
            "quest_model": {
                "models": ["curated-original-v1", "ksat-structure-reference"]
            },
        },
        "info": {
            "main": get_main_grade(tags, strict=True),
            "sub": [tags[0], tags[0]],
            "hash_tag": tags,
            "flow_rate": len(all_steps),
            "difficulty": difficulty_score,
            "difficulty_score": difficulty_score,
            "difficulty_tier": tier,
            "main_huddle": DIFFICULTY_CONTRACTS[tier].strategy_level,
            "quality_status": "approved",
        },
        "data": {
            "quest_title": _content(spec["title"]),
            "quest_image": None,
            "quest_answer": _content(f"${spec['answer']}$"),
            "question_type": "short",
            "quest_options": [],
            # 음수 ID는 자동 증가 코드베이스와 충돌하지 않는 수동 저작 문제 영역이다.
            "codebase_id": -(20_260_714_000 + variant_number),
            "seed": 202_607_140_000 + variant_number,
            "hash_tag": tags,
            "choice_answer_index": None,
            "meta": {
                "batch_id": BATCH_ID,
                "origin": "curated_original",
                "copyright_policy": "exam_structure_only_no_verbatim_copy",
                "reference_scope": "local_csat_concept_index_and_current_generation_contract",
                "curriculum_scope": "공통수학1·공통수학2·대수·미적분I",
                "authored_at": "2026-07-14",
            },
        },
        "solves": solves,
    }


def build_catalog() -> list[dict[str, Any]]:
    """필요 변수: 없음. 작동 원리: 난이도별 10문항씩 총 50개의 독립 저작 문제와 해설 명세를 반환한다."""
    return [
        _problem(
            1,
            1,
            title=r"다항식 $P(x)=2x^2-3x+1$에 대하여 $P(3)$의 값을 구하시오.",
            answer="10",
            tags=["#다항식의연산"],
            steps=[
                (r"다항식에 $x=3$을 대입한다.", r"$P(3)=2\cdot3^2-3\cdot3+1$이다."),
                ("거듭제곱과 곱셈을 차례로 계산한다.", r"$18-9+1=10$이므로 구하는 값은 $10$이다."),
            ],
        ),
        _problem(
            1,
            2,
            title=r"이차방정식 $x^2-5x+6=0$의 두 근 중 큰 값을 구하시오.",
            answer="3",
            tags=["#이차방정식"],
            steps=[
                ("좌변을 두 일차식의 곱으로 인수분해한다.", r"$x^2-5x+6=(x-2)(x-3)$이다."),
                ("각 인수를 영으로 놓고 큰 근을 고른다.", r"두 근은 $2,3$이므로 큰 값은 $3$이다."),
            ],
        ),
        _problem(
            1,
            3,
            title=r"첫째항이 $4$이고 공차가 $3$인 등차수열 $\{a_n\}$에서 $a_7$을 구하시오.",
            answer="22",
            tags=["#등차수열"],
            steps=[
                ("등차수열의 일반항에 주어진 값을 대입한다.", r"$a_n=4+(n-1)\cdot3$이다."),
                ("일곱째 항을 계산한다.", r"$a_7=4+6\cdot3=22$이다."),
            ],
        ),
        _problem(
            1,
            4,
            title=r"방정식 $2^{x+1}=16$을 만족하는 실수 $x$의 값을 구하시오.",
            answer="3",
            tags=["#지수방정식"],
            steps=[
                ("양변을 같은 밑의 거듭제곱으로 나타낸다.", r"$16=2^4$이므로 $2^{x+1}=2^4$이다."),
                ("지수가 같다는 성질을 적용한다.", r"$x+1=4$이므로 $x=3$이다."),
            ],
        ),
        _problem(
            1,
            5,
            title=r"로그의 정의를 이용하여 $\log_2 32$의 값을 구하시오.",
            answer="5",
            tags=["#로그의정의"],
            steps=[
                ("진수를 밑의 거듭제곱으로 표현한다.", r"$32=2^5$이다."),
                ("로그의 정의를 적용한다.", r"$2^5=32$이므로 $\log_2 32=5$이다."),
            ],
        ),
        _problem(
            1,
            6,
            title=r"집합 $A=\{1,2,3,4,5,6\}$, $B=\{2,4,6\}$에 대하여 $A-B$의 원소의 개수를 구하시오.",
            answer="3",
            tags=["#차집합"],
            steps=[
                ("집합 $A$에서 $B$의 원소를 제외한다.", r"$A-B=\{1,3,5\}$이다."),
                ("남은 서로 다른 원소를 센다.", r"원소가 $3$개이므로 구하는 값은 $3$이다."),
            ],
        ),
        _problem(
            1,
            7,
            title=r"이차함수 $f(x)=(x-2)^2+3$의 최솟값을 구하시오.",
            answer="3",
            tags=["#이차함수의최대최소"],
            steps=[
                ("제곱식이 가질 수 있는 가장 작은 값을 확인한다.", r"모든 실수 $x$에 대하여 $(x-2)^2\ge0$이다."),
                ("등호가 성립할 때의 함숫값을 계산한다.", r"$x=2$일 때 $f(2)=3$이므로 최솟값은 $3$이다."),
            ],
        ),
        _problem(
            1,
            8,
            title=r"두 점 $A(1,2)$, $B(4,6)$ 사이의 거리를 구하시오.",
            answer="5",
            tags=["#두점사이의거리"],
            steps=[
                ("두 점 사이의 거리 공식에 좌표 차를 대입한다.", r"$AB=\sqrt{(4-1)^2+(6-2)^2}$이다."),
                ("제곱의 합과 제곱근을 계산한다.", r"$AB=\sqrt{9+16}=5$이다."),
            ],
        ),
        _problem(
            1,
            9,
            title=r"두 함수 $f(x)=2x+1$, $g(x)=x^2$에 대하여 $(f\circ g)(2)$의 값을 구하시오.",
            answer="9",
            tags=["#합성함수"],
            steps=[
                ("먼저 안쪽 함수의 값을 계산한다.", r"$g(2)=2^2=4$이다."),
                ("그 결과를 바깥 함수에 대입한다.", r"$f(4)=2\cdot4+1=9$이다."),
            ],
        ),
        _problem(
            1,
            10,
            title=r"함수 $f(x)=x^3-2x$에 대하여 $f'(2)$의 값을 구하시오.",
            answer="10",
            tags=["#도함수"],
            steps=[
                ("거듭제곱의 미분법으로 도함수를 구한다.", r"$f'(x)=3x^2-2$이다."),
                ("도함수에 $x=2$를 대입한다.", r"$f'(2)=3\cdot4-2=10$이다."),
            ],
        ),
        _problem(
            2,
            1,
            title=r"다항식 $P(x)=x^3-2x^2+ax+3$을 $x-1$로 나눈 나머지가 $5$일 때, 상수 $a$를 구하시오.",
            answer="3",
            tags=["#나머지정리", "#미정계수법"],
            steps=[
                ("나머지정리로 조건을 함숫값 식으로 바꾼다.", r"$x-1$로 나눈 나머지가 $5$이므로 $P(1)=5$이다."),
                ("다항식에 $1$을 대입하여 계수식을 만든다.", r"$P(1)=1-2+a+3=a+2$이다."),
                ("일차방정식을 풀어 미정계수를 정한다.", r"$a+2=5$이므로 $a=3$이다."),
            ],
        ),
        _problem(
            2,
            2,
            title=r"이차방정식 $x^2-6x+4=0$의 두 근을 $\alpha,\beta$라 할 때, $\alpha^2+\beta^2$의 값을 구하시오.",
            answer="28",
            tags=["#근과계수의관계", "#이차방정식"],
            steps=[
                ("근과 계수의 관계로 합과 곱을 구한다.", r"$\alpha+\beta=6$, $\alpha\beta=4$이다."),
                ("두 제곱의 합을 합과 곱으로 변형한다.", r"$\alpha^2+\beta^2=(\alpha+\beta)^2-2\alpha\beta$이다."),
                ("알려진 값을 대입하여 계산한다.", r"$6^2-2\cdot4=28$이다."),
            ],
        ),
        _problem(
            2,
            3,
            title=r"함수 $f(x)=3x-2$의 역함수를 $g$라 할 때, $g(13)$의 값을 구하시오.",
            answer="5",
            tags=["#역함수", "#일대일대응"],
            steps=[
                ("역함숫값을 원래 함수의 식으로 바꾼다.", r"$g(13)=t$라 하면 $f(t)=13$이다."),
                ("원래 함수에 미지수를 대입한다.", r"$3t-2=13$이다."),
                ("일차방정식을 풀어 역함숫값을 정한다.", r"$3t=15$이므로 $g(13)=5$이다."),
            ],
        ),
        _problem(
            2,
            4,
            title=r"첫째항이 $2$이고 공차가 $2$인 등차수열의 첫째항부터 제10항까지의 합을 구하시오.",
            answer="110",
            tags=["#등차수열의합", "#일반항"],
            steps=[
                ("등차수열의 제10항을 구한다.", r"$a_{10}=2+9\cdot2=20$이다."),
                ("첫째항과 마지막 항을 이용한 합 공식을 세운다.", r"$S_{10}=\dfrac{10(2+20)}{2}$이다."),
                ("식을 계산하여 합을 구한다.", r"$S_{10}=5\cdot22=110$이다."),
            ],
        ),
        _problem(
            2,
            5,
            title=r"모든 항이 양수인 등비수열 $\{a_n\}$에서 $a_2=6$, $a_5=162$일 때, $a_4$를 구하시오.",
            answer="54",
            tags=["#등비수열", "#등비수열의일반항"],
            steps=[
                ("두 항의 비로 공비의 세제곱을 구한다.", r"$\dfrac{a_5}{a_2}=r^3=27$이다."),
                ("양의 공비를 결정한다.", r"모든 항이 양수이므로 $r=3$이다."),
                ("둘째 항에서 두 번 공비를 곱한다.", r"$a_4=a_2r^2=6\cdot9=54$이다."),
            ],
        ),
        _problem(
            2,
            6,
            title=r"방정식 $\log_3(x-1)=2$를 만족하는 실수 $x$를 구하시오.",
            answer="10",
            tags=["#로그방정식", "#진수조건"],
            steps=[
                ("로그의 진수 조건을 확인한다.", r"$x-1>0$이므로 $x>1$이어야 한다."),
                ("로그의 정의로 지수식으로 바꾼다.", r"$x-1=3^2=9$이다."),
                ("해를 구하고 진수 조건을 확인한다.", r"$x=10$은 $x>1$을 만족한다."),
            ],
        ),
        _problem(
            2,
            7,
            title=r"방정식 $4^x-5\cdot2^x+4=0$의 모든 실근의 합을 구하시오.",
            answer="2",
            tags=["#지수방정식", "#지수방정식과지수부등식"],
            steps=[
                (r"$t=2^x$로 치환하여 이차방정식으로 바꾼다.", r"$4^x=(2^x)^2$이므로 $t^2-5t+4=0$이다."),
                ("치환한 이차방정식을 인수분해한다.", r"$(t-1)(t-4)=0$에서 $t=1,4$이다."),
                ("각 지수방정식을 풀고 합을 계산한다.", r"$2^x=1,4$에서 $x=0,2$이므로 합은 $2$이다."),
            ],
        ),
        _problem(
            2,
            8,
            title=r"원 $x^2+y^2-4x+6y-12=0$의 반지름을 구하시오.",
            answer="5",
            tags=["#원의일반형", "#일반형을표준형으로"],
            steps=[
                ("변수별 항을 모아 완전제곱식을 준비한다.", r"$x^2-4x+y^2+6y=12$이다."),
                ("양변에 필요한 수를 더해 표준형을 만든다.", r"$(x-2)^2+(y+3)^2=25$이다."),
                ("표준형에서 반지름을 읽는다.", r"반지름의 제곱이 $25$이므로 반지름은 $5$이다."),
            ],
        ),
        _problem(
            2,
            9,
            title=r"함수 $f(x)=x^3-3x^2+2$의 그래프 위에서 $x$좌표가 $1$인 점에서의 접선의 기울기를 구하시오.",
            answer="-3",
            tags=["#도함수", "#접선의기울기"],
            steps=[
                ("접선의 기울기가 미분계수임을 이용한다.", r"구하는 기울기는 $f'(1)$이다."),
                ("주어진 함수를 미분한다.", r"$f'(x)=3x^2-6x$이다."),
                ("도함수에 좌표를 대입한다.", r"$f'(1)=3-6=-3$이다."),
            ],
        ),
        _problem(
            2,
            10,
            title=r"정적분 $\int_0^2(3x^2+1)\,dx$의 값을 구하시오.",
            answer="10",
            tags=["#정적분", "#정적분의계산"],
            steps=[
                ("피적분함수의 한 부정적분을 구한다.", r"$3x^2+1$의 한 부정적분은 $x^3+x$이다."),
                ("미적분의 기본정리로 양 끝값을 대입한다.", r"$[x^3+x]_0^2=(8+2)-0$이다."),
                ("끝값의 차를 계산한다.", r"정적분의 값은 $10$이다."),
            ],
        ),
        _problem(
            3,
            1,
            title=r"삼차다항식 $P(x)=x^3+ax^2+bx-6$이 $P(1)=P(2)=P(3)=0$을 만족할 때, $a+b$의 값을 구하시오.",
            answer="5",
            tags=["#인수정리", "#근과계수의관계", "#고차식인수분해"],
            steps=[
                ("세 영점을 이용해 다항식의 인수 형태를 정한다.", r"최고차항의 계수가 $1$이므로 $P(x)=(x-1)(x-2)(x-3)$이다."),
                ("세 근의 합으로 이차항의 계수를 구한다.", r"$1+2+3=-a$이므로 $a=-6$이다."),
                ("세 근의 두 개씩 곱한 합으로 일차항의 계수를 구한다.", r"$b=1\cdot2+2\cdot3+3\cdot1=11$이다."),
                ("두 계수를 더한다.", r"$a+b=-6+11=5$이다."),
            ],
            alternatives=[r"직접 $(x-1)(x-2)(x-3)$을 전개하면 $x^3-6x^2+11x-6$이어서 같은 결과를 얻는다."],
        ),
        _problem(
            3,
            2,
            title=r"수열 $\{a_n\}$이 $a_1=1$, $a_{n+1}=a_n+2n$을 만족할 때, $\sum_{k=1}^{5}a_k$의 값을 구하시오.",
            answer="45",
            tags=["#수열의표현", "#시그마공식", "#자연수의거듭제곱의합"],
            steps=[
                ("점화식의 차를 누적하여 일반항을 세운다.", r"$a_n=1+\sum_{k=1}^{n-1}2k$이다."),
                ("자연수의 합 공식을 적용한다.", r"$a_n=1+n(n-1)$이다."),
                ("첫 다섯 항을 계산한다.", r"$a_1,a_2,a_3,a_4,a_5=1,3,7,13,21$이다."),
                ("계산한 항을 모두 더한다.", r"$1+3+7+13+21=45$이다."),
            ],
            alternatives=[r"점화식을 차례로 네 번 적용해도 $1,3,7,13,21$을 바로 얻을 수 있다."],
        ),
        _problem(
            3,
            3,
            title=r"두 그래프 $y=2^{x+1}$, $y=8^{x-1}$의 교점을 $(p,q)$라 할 때, $p+q$를 구하시오.",
            answer="10",
            tags=["#지수함수의그래프", "#지수방정식", "#지수법칙"],
            steps=[
                ("교점에서 두 함숫값이 같다는 방정식을 세운다.", r"$2^{p+1}=8^{p-1}$이다."),
                ("양변의 밑을 $2$로 통일한다.", r"$2^{p+1}=2^{3p-3}$이다."),
                ("지수를 비교하여 교점의 가로좌표를 구한다.", r"$p+1=3p-3$이므로 $p=2$이다."),
                ("세로좌표와 좌표의 합을 계산한다.", r"$q=2^{2+1}=8$이므로 $p+q=10$이다."),
            ],
            alternatives=[r"양변에 밑이 $2$인 로그를 취하면 $p+1=3(p-1)$을 곧바로 얻는다."],
        ),
        _problem(
            3,
            4,
            title=r"등차수열 $\{a_n\}$에서 $a_2=5$, $a_5=14$이고 $b_n=2^{a_n}$일 때, $\log_2 b_4$의 값을 구하시오.",
            answer="11",
            tags=["#등차수열", "#지수법칙", "#로그의정의"],
            steps=[
                ("두 항의 차로 공차를 구한다.", r"$a_5-a_2=3d=9$이므로 $d=3$이다."),
                ("둘째 항에서 두 번 공차를 더한다.", r"$a_4=a_2+2d=5+6=11$이다."),
                ("새 수열의 정의를 적용한다.", r"$b_4=2^{a_4}=2^{11}$이다."),
                ("로그의 정의로 값을 구한다.", r"$\log_2 b_4=\log_2 2^{11}=11$이다."),
            ],
            alternatives=[r"$\log_2 b_n=a_n$이라는 관계를 먼저 찾으면 $a_4$만 계산하여 끝낼 수 있다."],
        ),
        _problem(
            3,
            5,
            title=r"함수 $f(x)=x^2-4x+5$와 $g(x)=f(x+1)$에 대하여, $g$의 그래프의 꼭짓점을 $(a,b)$라 할 때 $a+b$를 구하시오.",
            answer="2",
            tags=["#합성함수", "#이차함수의평행이동", "#최솟값"],
            steps=[
                ("원래 이차함수를 완전제곱식으로 나타낸다.", r"$f(x)=(x-2)^2+1$이다."),
                ("입력값을 $x+1$로 바꾸어 새 함수식을 구한다.", r"$g(x)=((x+1)-2)^2+1=(x-1)^2+1$이다."),
                ("표준형에서 꼭짓점의 좌표를 읽는다.", r"꼭짓점은 $(a,b)=(1,1)$이다."),
                ("두 좌표를 더한다.", r"$a+b=1+1=2$이다."),
            ],
            alternatives=[r"$f(x+1)$은 $f$의 그래프를 왼쪽으로 $1$만큼 옮긴 것이므로 $(2,1)$이 $(1,1)$로 이동한다."],
        ),
        _problem(
            3,
            6,
            title=r"유리함수 $f(x)=\dfrac{2x+1}{x-1}$의 두 점근선의 교점을 $(a,b)$라 할 때, $a+b$를 구하시오.",
            answer="3",
            tags=["#유리함수의그래프", "#점근선", "#유리함수의평행이동"],
            steps=[
                ("분자를 분모를 이용해 다시 나타낸다.", r"$2x+1=2(x-1)+3$이다."),
                ("함수식을 평행이동 표준형으로 바꾼다.", r"$f(x)=2+\dfrac{3}{x-1}$이다."),
                ("수직선과 수평선 점근선을 각각 구한다.", r"두 점근선은 $x=1$, $y=2$이다."),
                ("교점 좌표의 합을 계산한다.", r"$(a,b)=(1,2)$이므로 $a+b=3$이다."),
            ],
            alternatives=[r"분모가 영이 되는 값과 최고차항 계수의 비를 각각 사용해도 점근선 $x=1$, $y=2$를 얻는다."],
        ),
        _problem(
            3,
            7,
            title=r"함수 $f(x)=\begin{cases}\dfrac{x^2-4}{x-2}&(x\ne2)\\k&(x=2)\end{cases}$가 $x=2$에서 연속이고 $g(x)=f(x)+x$일 때, $g(2)$를 구하시오.",
            answer="6",
            tags=["#함수의극한", "#함수의연속", "#인수분해를이용한극한"],
            steps=[
                ("분자를 인수분해하여 약분할 형태를 찾는다.", r"$x^2-4=(x-2)(x+2)$이다."),
                ("구멍이 있는 식의 극한값을 구한다.", r"$x\ne2$에서 $f(x)=x+2$이므로 $\lim_{x\to2}f(x)=4$이다."),
                ("연속 조건으로 함수의 정의값을 정한다.", r"연속이려면 $k=f(2)=4$여야 한다."),
                ("새 함수의 정의에 대입한다.", r"$g(2)=f(2)+2=4+2=6$이다."),
            ],
            alternatives=[r"약분된 직선 $y=x+2$의 빠진 점을 채우면 연속이 되므로 그 점의 높이는 $4$이다."],
        ),
        _problem(
            3,
            8,
            title=r"함수 $f(x)=x^3-3x^2+2$의 극댓값과 극솟값의 차를 구하시오.",
            answer="4",
            tags=["#도함수의부호", "#함수의극대와극소", "#극값의판정"],
            steps=[
                ("도함수를 구해 인수분해한다.", r"$f'(x)=3x^2-6x=3x(x-2)$이다."),
                ("도함수가 영이 되는 임계점을 구한다.", r"임계점의 $x$좌표는 $0,2$이다."),
                ("도함수의 부호 변화로 극대와 극소를 구분한다.", r"$x=0$에서 극대, $x=2$에서 극소이다."),
                ("두 극값을 계산하여 차를 구한다.", r"$f(0)=2$, $f(2)=-2$이므로 차는 $4$이다."),
            ],
            alternatives=[r"도함수의 위로 열린 이차함수 그래프를 이용하면 부호가 $+,-,+$ 순서로 바뀜을 확인할 수 있다."],
        ),
        _problem(
            3,
            9,
            title=r"두 곡선 $y=x$, $y=x^2$로 둘러싸인 넓이를 $S$라 할 때, $6S$의 값을 구하시오.",
            answer="1",
            tags=["#두곡선사이의넓이", "#정적분과넓이", "#정적분의계산"],
            steps=[
                ("두 곡선의 교점의 가로좌표를 구한다.", r"$x=x^2$에서 $x=0,1$이다."),
                ("구간에서 위쪽 곡선을 확인한다.", r"$0<x<1$에서 $x>x^2$이다."),
                ("두 함수의 차를 적분하여 넓이를 구한다.", r"$S=\int_0^1(x-x^2)dx=\dfrac12-\dfrac13=\dfrac16$이다."),
                ("문제에서 요구한 배수를 계산한다.", r"$6S=6\cdot\dfrac16=1$이다."),
            ],
            alternatives=[r"직선 아래 삼각형의 넓이 $1/2$에서 포물선 아래 넓이 $1/3$을 빼도 $S=1/6$이다."],
        ),
        _problem(
            3,
            10,
            title=r"원 $(x-2)^2+(y-1)^2=9$에 접하는 직선 $x+y=k$의 가능한 두 $k$값의 합을 구하시오.",
            answer="6",
            tags=["#원의표준형", "#점과직선사이의거리", "#거리공식"],
            steps=[
                ("원의 중심과 반지름을 확인한다.", r"중심은 $(2,1)$이고 반지름은 $3$이다."),
                ("중심에서 직선까지의 거리를 식으로 나타낸다.", r"거리는 $\dfrac{|2+1-k|}{\sqrt2}=\dfrac{|3-k|}{\sqrt2}$이다."),
                ("접할 조건으로 거리를 반지름과 같게 둔다.", r"$|3-k|=3\sqrt2$이다."),
                ("두 해의 대칭성을 이용해 합을 구한다.", r"$k=3\pm3\sqrt2$이므로 합은 $6$이다."),
            ],
            alternatives=[r"중심을 지나는 평행선 $x+y=3$을 기준으로 두 접선의 상수항이 대칭이므로 평균이 $3$이다."],
        ),
        _problem(
            4,
            1,
            title=r"함수 $f(x)=\begin{cases}x^2+ax&(x<1)\\bx-1&(x\ge1)\end{cases}$가 $x=1$에서 미분가능하고 $f(2)=5$일 때, $a+b$를 구하시오.",
            answer="4",
            tags=["#미분가능", "#함수의연속", "#도함수", "#이차함수"],
            steps=[
                ("미분가능성에 필요한 연속 조건을 세운다.", r"$1+a=b-1$이므로 $b=a+2$이다."),
                ("좌우 미분계수가 같다는 조건을 확인한다.", r"왼쪽 미분계수는 $2+a$, 오른쪽은 $b$이므로 역시 $b=a+2$이다."),
                ("추가 함숫값 조건을 오른쪽 식에 대입한다.", r"$f(2)=2b-1=5$이다."),
                ("두 계수를 각각 구한다.", r"$b=3$이고 $a=b-2=1$이다."),
                ("계수의 합을 계산한다.", r"$a+b=1+3=4$이다."),
            ],
            alternatives=[r"오른쪽 직선이 접합점에서 왼쪽 포물선의 접선이 되어야 한다고 보면 기울기와 높이 조건을 동시에 세울 수 있다."],
        ),
        _problem(
            4,
            2,
            title=r"수열 $\{a_n\}$이 $a_1=1$, $a_{n+1}=a_n+\dfrac1{n(n+1)}$을 만족할 때, $10a_{10}$의 값을 구하시오.",
            answer="19",
            tags=["#수열의표현", "#부분분수", "#여러가지수열의합", "#시그마의성질"],
            steps=[
                ("점화식의 증가량을 부분분수로 분해한다.", r"$\dfrac1{n(n+1)}=\dfrac1n-\dfrac1{n+1}$이다."),
                ("첫째항부터 증가량을 누적한다.", r"$a_n=1+\sum_{k=1}^{n-1}\left(\dfrac1k-\dfrac1{k+1}\right)$이다."),
                ("이웃한 항이 소거되는 망원합을 계산한다.", r"합은 $1-\dfrac1n$이다."),
                ("일반항과 제10항을 구한다.", r"$a_n=2-\dfrac1n$이므로 $a_{10}=\dfrac{19}{10}$이다."),
                ("요구한 배수를 계산한다.", r"$10a_{10}=19$이다."),
            ],
            alternatives=[r"$b_n=2-a_n$으로 두면 $b_{n+1}=b_n-1/n(n+1)$이고 소거 구조가 더 선명하게 보인다."],
        ),
        _problem(
            4,
            3,
            title=r"부등식 $4^x-5\cdot2^x+4\le0$을 만족하는 모든 정수 $x$의 합을 구하시오.",
            answer="3",
            tags=["#지수부등식", "#지수함수의그래프", "#지수방정식", "#함수의증가와감소"],
            steps=[
                (r"$t=2^x$로 치환하고 양수 조건을 둔다.", r"$t>0$이고 부등식은 $t^2-5t+4\le0$이다."),
                ("이차부등식의 해를 구한다.", r"$(t-1)(t-4)\le0$이므로 $1\le t\le4$이다."),
                ("증가하는 지수함수에 치환값을 되돌린다.", r"$1\le2^x\le4$에서 $0\le x\le2$이다."),
                ("범위 안의 정수를 나열한다.", r"가능한 정수는 $0,1,2$이다."),
                ("모든 정수해를 더한다.", r"$0+1+2=3$이다."),
            ],
            alternatives=[r"$y=t^2-5t+4$의 그래프가 두 근 $1,4$ 사이에서 영 이하임을 이용해도 같은 구간을 얻는다."],
        ),
        _problem(
            4,
            4,
            title=r"방정식 $(\log_2 x)^2-5\log_2 x+6=0$의 두 실근의 합을 구하시오.",
            answer="12",
            tags=["#로그방정식", "#진수조건", "#로그법칙", "#이차방정식"],
            steps=[
                ("로그의 진수 조건을 확인한다.", r"$x>0$이어야 한다."),
                (r"$t=\log_2x$로 치환한다.", r"치환하면 $t^2-5t+6=0$이다."),
                ("치환한 이차방정식을 푼다.", r"$(t-2)(t-3)=0$이므로 $t=2,3$이다."),
                ("각 로그방정식을 지수식으로 되돌린다.", r"$x=2^2,2^3$이므로 두 근은 $4,8$이다."),
                ("진수 조건을 확인하고 합을 계산한다.", r"두 값 모두 양수이고 합은 $4+8=12$이다."),
            ],
            alternatives=[r"이차식의 두 근이 $2,3$임을 근과 계수의 관계로 확인한 뒤 바로 $2^2+2^3$을 계산할 수 있다."],
        ),
        _problem(
            4,
            5,
            title=r"함수 $f(x)=x^3-3x$의 그래프와 $x=1$에서의 접선으로 둘러싸인 유한한 부분의 넓이를 $S$라 할 때, $4S$를 구하시오.",
            answer="27",
            tags=["#접선의방정식", "#인수정리", "#두곡선사이의넓이", "#정적분"],
            steps=[
                ("접점의 함숫값과 미분계수를 구한다.", r"$f(1)=-2$, $f'(x)=3x^2-3$에서 $f'(1)=0$이다."),
                ("접선의 방정식을 정한다.", r"접선은 수평선 $y=-2$이다."),
                ("곡선과 접선의 다른 교점을 구한다.", r"$f(x)+2=x^3-3x+2=(x-1)^2(x+2)$이므로 $x=-2,1$이다."),
                ("두 그래프의 위아래 관계로 넓이 적분을 세운다.", r"$[-2,1]$에서 $f(x)+2\ge0$이므로 $S=\int_{-2}^{1}(x^3-3x+2)dx$이다."),
                ("정적분과 요구한 배수를 계산한다.", r"$S=\dfrac{27}{4}$이므로 $4S=27$이다."),
            ],
            alternatives=[r"차이 함수가 $(x-1)^2(x+2)$이므로 구간 전체에서 부호가 바뀌지 않는다는 점을 먼저 확인할 수 있다."],
        ),
        _problem(
            4,
            6,
            title=r"함수 $f(x)=x^2-4x+5$의 정의역을 $x\ge2$로 제한하고 역함수를 $g$라 하자. $f(g(10)-1)$의 값을 구하시오.",
            answer="5",
            tags=["#역함수", "#합성함수", "#이차함수의그래프", "#정의역"],
            steps=[
                ("이차함수를 꼭짓점 형태로 바꾼다.", r"$f(x)=(x-2)^2+1$이다."),
                ("역함숫값의 의미를 원래 함수 방정식으로 바꾼다.", r"$g(10)=t$라 하면 $t\ge2$이고 $(t-2)^2+1=10$이다."),
                ("정의역 제한에 맞는 해를 고른다.", r"$(t-2)^2=9$에서 $t=5,-1$ 중 $t=5$이다."),
                ("바깥 함수의 입력값을 계산한다.", r"$g(10)-1=4$이다."),
                ("원래 함수에 대입한다.", r"$f(4)=16-16+5=5$이다."),
            ],
            alternatives=[r"제한된 그래프를 $y=x$에 대칭이동해도 $g(10)=5$를 읽을 수 있다."],
        ),
        _problem(
            4,
            7,
            title=r"원 $x^2+y^2=25$와 직선 $y=x+1$의 두 교점을 $A,B$라 할 때, $AB^2$의 값을 구하시오.",
            answer="98",
            tags=["#원의방정식", "#직선의방정식", "#이차방정식", "#두점사이의거리"],
            steps=[
                ("직선의 식을 원의 방정식에 대입한다.", r"$x^2+(x+1)^2=25$이다."),
                ("교점의 가로좌표를 정하는 이차방정식을 푼다.", r"$2x^2+2x-24=0$에서 $(x-3)(x+4)=0$이다."),
                ("두 교점의 좌표를 구한다.", r"$A(3,4)$, $B(-4,-3)$로 둘 수 있다."),
                ("좌표 차로 거리의 제곱을 나타낸다.", r"$AB^2=(3+4)^2+(4+3)^2$이다."),
                ("제곱의 합을 계산한다.", r"$AB^2=49+49=98$이다."),
            ],
            alternatives=[r"직선 방향벡터가 $(1,1)$이고 두 점의 $x$좌표 차가 $7$이므로 거리의 제곱은 $7^2(1^2+1^2)$이다."],
        ),
        _problem(
            4,
            8,
            title=r"함수 $F(x)=\int_0^x(t^2+at+1)\,dt$가 $F(2)=\dfrac{20}{3}$을 만족할 때, $6F(1)$의 값을 구하시오.",
            answer="11",
            tags=["#정적분", "#미적분의기본정리", "#미정계수법", "#정적분의선형성"],
            steps=[
                ("매개변수를 포함한 정적분을 계산한다.", r"$F(x)=\dfrac{x^3}{3}+\dfrac{a x^2}{2}+x$이다."),
                ("주어진 함숫값 조건을 대입한다.", r"$F(2)=\dfrac83+2a+2=\dfrac{14}{3}+2a$이다."),
                ("매개변수에 대한 방정식을 푼다.", r"$\dfrac{14}{3}+2a=\dfrac{20}{3}$이므로 $a=1$이다."),
                ("정해진 매개변수로 $F(1)$을 구한다.", r"$F(1)=\dfrac13+\dfrac12+1=\dfrac{11}{6}$이다."),
                ("요구한 배수를 계산한다.", r"$6F(1)=11$이다."),
            ],
            alternatives=[r"$F'(x)=x^2+ax+1$을 먼저 확인한 뒤 원시함수와 $F(0)=0$을 사용해도 같은 식을 얻는다."],
        ),
        _problem(
            4,
            9,
            title=r"이차함수 $f(x)=x^2-2ax+a+3$의 최솟값이 $-3$이고 $a>0$이다. 그래프의 두 $x$절편의 합과 $a$의 합을 구하시오.",
            answer="9",
            tags=["#이차함수의최대최소", "#꼭짓점", "#근과계수의관계", "#이차방정식"],
            steps=[
                ("이차함수의 꼭짓점에서 최솟값을 나타낸다.", r"꼭짓점의 $x$좌표는 $a$이고 최솟값은 $-a^2+a+3$이다."),
                ("주어진 최솟값으로 매개변수 방정식을 세운다.", r"$-a^2+a+3=-3$에서 $a^2-a-6=0$이다."),
                ("부호 조건에 맞는 매개변수를 고른다.", r"$(a-3)(a+2)=0$, $a>0$이므로 $a=3$이다."),
                ("두 절편의 합을 근과 계수의 관계로 구한다.", r"$a=3$일 때 $x^2-6x+6=0$이므로 두 근의 합은 $6$이다."),
                ("매개변수와 두 근의 합을 더한다.", r"$3+6=9$이다."),
            ],
            alternatives=[r"완전제곱식 $f(x)=(x-a)^2-a^2+a+3$을 만들면 꼭짓점과 최솟값을 동시에 읽을 수 있다."],
        ),
        _problem(
            4,
            10,
            title=r"양의 등비수열 $\{a_n\}$에서 $a_1=3$, $a_4=81$이고 $b_n=\log_3a_n$일 때, $\sum_{k=1}^{4}b_k$를 구하시오.",
            answer="10",
            tags=["#등비수열", "#로그법칙", "#등차수열", "#등차수열의합"],
            steps=[
                ("주어진 두 항으로 공비의 세제곱을 구한다.", r"$a_4=a_1r^3$에서 $81=3r^3$이므로 $r^3=27$이다."),
                ("양의 공비를 결정한다.", r"수열의 모든 항이 양수이므로 $r=3$이다."),
                ("등비수열의 일반항을 로그 안에 넣는다.", r"$a_n=3\cdot3^{n-1}=3^n$이다."),
                ("로그를 취한 새 수열의 일반항을 구한다.", r"$b_n=\log_3 3^n=n$이다."),
                ("첫 네 항을 더한다.", r"$b_1+b_2+b_3+b_4=1+2+3+4=10$이다."),
            ],
            alternatives=[r"로그는 곱을 합으로 바꾸므로 $b_n$의 공차가 $\log_3r=1$인 등차수열임을 바로 알 수 있다."],
        ),
        _problem(
            5,
            1,
            title=r"양의 정수로 이루어진 수열 $\{a_n\}$이 $a_{n+1}=\begin{cases}a_n/2&(a_n\text{이 짝수})\\a_n+5&(a_n\text{이 홀수})\end{cases}$를 만족한다. $a_1\le20$, $a_4=4$일 때 가능한 모든 $a_1$의 합을 구하시오.",
            answer="17",
            tags=["#수열", "#수열의표현", "#일반항", "#경우의수", "#함수"],
            steps=[
                ("마지막 조건에서 점화식을 거꾸로 적용한다.", r"$a_4=4$가 되려면 $a_3=8$이거나 $a_3=-1$인데 양수이므로 $a_3=8$이다."),
                ("한 단계 더 거슬러 가능한 둘째 항을 구한다.", r"$a_3=8$이 되려면 $a_2=16$ 또는 $a_2=3$이다."),
                (r"$a_2=16$인 경우의 첫째 항을 조사한다.", r"$a_1=32$ 또는 $11$인데 $a_1\le20$이므로 $a_1=11$이다."),
                (r"$a_2=3$인 경우의 첫째 항을 조사한다.", r"$a_1=6$ 또는 $-2$이고 양수 조건에서 $a_1=6$이다."),
                ("서로 다른 모든 후보를 정리한다.", r"가능한 첫째 항은 $6,11$이다."),
                ("가능한 첫째 항의 합을 계산한다.", r"$6+11=17$이다."),
            ],
            alternatives=[
                r"$a_1=6$이면 $6\to3\to8\to4$로 조건을 만족한다.",
                r"$a_1=11$이면 $11\to16\to8\to4$로 조건을 만족한다.",
            ],
        ),
        _problem(
            5,
            2,
            title=r"함수 $f(x)=x^3-3x$에 대하여 $g(x)=\{f(x)\}^2$라 하자. 함수 $g$가 갖는 극대점과 극소점의 총개수를 구하시오.",
            answer="5",
            tags=["#합성함수", "#함수의극대와극소", "#미분계수", "#도함수의부호", "#최대최소문제"],
            steps=[
                ("합성된 제곱 함수의 도함수를 구한다.", r"$g'(x)=2f(x)f'(x)$이다."),
                ("첫 번째 임계점 묶음인 $f(x)=0$의 해를 구한다.", r"$x(x^2-3)=0$에서 $x=-\sqrt3,0,\sqrt3$이다."),
                ("두 번째 임계점 묶음인 $f'(x)=0$의 해를 구한다.", r"$f'(x)=3x^2-3$이므로 $x=-1,1$이다."),
                ("영점에서 제곱 함수의 극소 여부를 판단한다.", r"$g(x)\ge0$이고 세 영점 주변에서 양수이므로 모두 극소점이다."),
                ("나머지 임계점에서 극대 여부를 판단한다.", r"$x=-1,1$에서 $g'$의 부호가 양에서 음으로 바뀌므로 두 점은 극대점이다."),
                ("서로 다른 극점의 수를 합한다.", r"극소점 $3$개와 극대점 $2$개로 총 $5$개이다."),
            ],
            alternatives=[
                r"$y=f(x)$의 세 영점과 두 극점을 표시한 뒤 함숫값을 제곱하면 극점의 위치를 시각적으로 확인할 수 있다.",
                r"임계점의 순서 $-\sqrt3<-1<0<1<\sqrt3$에 맞춰 $2ff'$의 부호표를 작성해도 총 $5$개가 나온다.",
            ],
        ),
        _problem(
            5,
            3,
            title=r"함수 $f(x)=\begin{cases}\dfrac{x^2+ax+b}{x-1}&(x\ne1)\\c&(x=1)\end{cases}$가 실수 전체에서 연속이고 $f(0)=2$일 때, $a^2+b^2+c^2$을 구하시오.",
            answer="14",
            tags=["#함수의극한", "#극한의성질", "#인수분해를이용한극한", "#미정계수법", "#함수의연속"],
            steps=[
                ("주어진 함숫값으로 상수항을 정한다.", r"$f(0)=b/(-1)=2$이므로 $b=-2$이다."),
                ("유한한 극한이 존재할 분자 조건을 세운다.", r"$x=1$에서 분자도 영이어야 하므로 $1+a+b=0$이다."),
                ("이미 구한 상수항으로 이차항 계수를 정한다.", r"$1+a-2=0$이므로 $a=1$이다."),
                ("분자를 인수분해하고 약분한다.", r"$x^2+x-2=(x-1)(x+2)$이므로 $x\ne1$에서 $f(x)=x+2$이다."),
                ("연속 조건으로 빠진 정의값을 채운다.", r"$c=\lim_{x\to1}f(x)=3$이다."),
                ("세 상수의 제곱합을 계산한다.", r"$a^2+b^2+c^2=1+4+9=14$이다."),
            ],
            alternatives=[
                r"분자 $x^2+ax-2$가 $x-1$을 인수로 가져야 한다는 인수정리를 쓰면 $a=1$을 바로 얻는다.",
                r"약분 뒤 남는 직선 $y=x+2$의 구멍을 $(1,3)$으로 채우는 관점에서 $c=3$을 확인할 수 있다.",
            ],
        ),
        _problem(
            5,
            4,
            title=r"지수함수 $y=2^x$의 그래프 위의 두 점 $A(0,1)$, $B(2,4)$가 있다. 점 $A$를 지나고 직선 $AB$에 수직인 직선을 $l$이라 하고, 원점과 $l$ 사이의 거리를 $d$라 할 때 $AB\cdot d$를 구하시오.",
            answer="3",
            tags=["#지수함수의그래프", "#두점사이의거리", "#점과직선사이의거리", "#직선의방정식", "#기울기"],
            steps=[
                ("두 점의 좌표 차로 선분의 길이를 구한다.", r"$AB=\sqrt{(2-0)^2+(4-1)^2}=\sqrt{13}$이다."),
                ("직선 $AB$의 방향과 기울기를 구한다.", r"방향벡터는 $(2,3)$이고 기울기는 $3/2$이다."),
                ("수직인 직선의 기울기를 정한다.", r"직선 $l$의 기울기는 $-2/3$이다."),
                ("점 $A$를 지나는 직선의 일반형을 구한다.", r"$y-1=-\dfrac23x$에서 $2x+3y-3=0$이다."),
                ("원점과 직선 사이의 거리를 계산한다.", r"$d=\dfrac{3}{\sqrt{2^2+3^2}}=\dfrac3{\sqrt{13}}$이다."),
                ("길이와 거리를 곱한다.", r"$AB\cdot d=\sqrt{13}\cdot\dfrac3{\sqrt{13}}=3$이다."),
            ],
            alternatives=[
                r"삼각형의 넓이를 밑변 $AB$로 계산하면 높이가 바로 $d$가 되어 곱 $AB\cdot d$를 구할 수 있다.",
                r"벡터 $(2,3)$이 $l$의 법선벡터이므로 점 $A$를 대입해 $2x+3y-3=0$을 바로 얻는다.",
            ],
        ),
        _problem(
            5,
            5,
            title=r"함수 $f(x)=x^3-3x^2$의 극대점과 극소점을 잇는 직선과 함수의 그래프로 둘러싸인 넓이를 $S$라 할 때, $2S$의 값을 구하시오.",
            answer="1",
            tags=["#함수의극대와극소", "#도함수의부호", "#직선의방정식", "#두곡선사이의넓이", "#정적분"],
            steps=[
                ("도함수로 극대점과 극소점의 가로좌표를 구한다.", r"$f'(x)=3x(x-2)$이므로 임계점은 $x=0,2$이다."),
                ("두 극점의 좌표를 구한다.", r"극대점은 $(0,0)$, 극소점은 $(2,-4)$이다."),
                ("두 점을 잇는 직선의 방정식을 구한다.", r"기울기가 $-2$이므로 직선은 $y=-2x$이다."),
                ("두 그래프의 차와 교점을 인수분해한다.", r"$f(x)-(-2x)=x(x-1)(x-2)$이고 교점의 가로좌표는 $0,1,2$이다."),
                ("부호가 바뀌는 지점에서 적분을 나누어 넓이를 구한다.", r"$S=\int_0^1x(x-1)(x-2)dx-\int_1^2x(x-1)(x-2)dx=\dfrac12$이다."),
                ("문제에서 요구한 배수를 계산한다.", r"$2S=1$이다."),
            ],
            alternatives=[
                r"차이 함수는 $x=1$을 중심으로 두 부분의 부호가 반대이고 넓이는 각각 $1/4$이다.",
                r"원시함수 $x^4/4-x^3+x^2$의 값이 $0,1/4,0$ 순서임을 이용하면 절댓값 넓이의 합이 $1/2$이다.",
            ],
        ),
        _problem(
            5,
            6,
            title=r"실수 $m>1$에 대하여 방정식 $(\log_2x)^2-(m+1)\log_2x+m=0$의 서로 다른 두 양의 실근을 $\alpha,\beta$라 하자. $\alpha\beta=32$일 때 $m$을 구하시오.",
            answer="4",
            tags=["#로그방정식", "#진수조건", "#로그법칙", "#근과계수의관계", "#지수방정식"],
            steps=[
                ("로그방정식의 진수 조건을 확인한다.", r"두 근은 모두 $x>0$ 범위에 있어야 한다."),
                (r"$t=\log_2x$로 치환한다.", r"$t^2-(m+1)t+m=0$이다."),
                ("치환 방정식의 구조를 인수분해한다.", r"$(t-1)(t-m)=0$이므로 $t=1,m$이다."),
                ("원래 양의 두 근을 지수 형태로 복원한다.", r"$\alpha,\beta$는 순서와 관계없이 $2,2^m$이다."),
                ("두 근의 곱 조건을 지수방정식으로 바꾼다.", r"$2\cdot2^m=2^{m+1}=32=2^5$이다."),
                ("지수를 비교하고 조건을 확인한다.", r"$m+1=5$에서 $m=4>1$이고 두 근도 서로 다르다."),
            ],
            alternatives=[
                r"치환한 두 근의 합이 $m+1$이므로 원래 두 근의 곱은 $2^{m+1}$이라고 바로 볼 수 있다.",
                r"이차식의 상수항이 $m$이고 $1$이 항상 한 근임을 대입으로 확인하면 다른 근은 $m$이다.",
            ],
        ),
        _problem(
            5,
            7,
            title=r"함수 $f(x)=\begin{cases}x+1&(x<0)\\x^2+x+a&(x\ge0)\end{cases}$가 $x=0$에서 미분가능하다. 방정식 $f(f(x))=1$의 서로 다른 실근의 개수를 구하시오.",
            answer="1",
            tags=["#합성함수", "#미분가능", "#함수의연속", "#이차방정식", "#경우의수"],
            steps=[
                ("미분가능성에 앞서 연속 조건으로 매개변수를 정한다.", r"좌극한은 $1$, 함숫값은 $a$이므로 $a=1$이다."),
                ("좌우 미분계수가 일치하는지 확인한다.", r"왼쪽 미분계수는 $1$, 오른쪽은 $2x+1$의 $x=0$ 값인 $1$이다."),
                (r"$x<-1$인 구간에서 합성함수를 계산한다.", r"$f(x)=x+1<0$이므로 $f(f(x))=x+2$이고 $x+2=1$의 해 $-1$은 이 구간에 없다."),
                (r"$-1\le x<0$인 구간에서 합성함수를 계산한다.", r"$t=x+1\in[0,1)$에서 $f(t)=t^2+t+1$이다."),
                ("중간 구간과 오른쪽 구간의 해를 판정한다.", r"$t^2+t=0$에서 $t=0$만 가능하여 $x=-1$이고, $x\ge0$에서는 $f(x)\ge1$라서 다시 합성하면 $1$보다 크다."),
                ("서로 다른 유효한 해의 수를 센다.", r"유효한 해는 $x=-1$ 하나이므로 개수는 $1$이다."),
            ],
            alternatives=[
                r"$f$는 음의 구간에서 직선, 음이 아닌 구간에서 최솟값 $1$인 포물선이므로 입력 부호에 따라 세 구간만 나누면 된다.",
                r"실제 해 $x=-1$을 대입하면 $f(-1)=0$, $f(0)=1$이 되어 조건을 만족함을 검산할 수 있다.",
            ],
        ),
        _problem(
            5,
            8,
            title=r"원 $(x-2)^2+(y+1)^2=1$에 접하고 원점을 지나는 두 직선의 기울기를 $m_1,m_2$라 할 때, $-3(m_1+m_2)$의 값을 구하시오.",
            answer="4",
            tags=["#원의방정식", "#직선의방정식", "#점과직선사이의거리", "#이차방정식", "#기울기"],
            steps=[
                ("원점을 지나는 일반적인 직선을 기울기로 나타낸다.", r"직선은 $y=mx$, 즉 $mx-y=0$이다."),
                ("원의 중심과 반지름을 확인한다.", r"중심은 $(2,-1)$이고 반지름은 $1$이다."),
                ("중심에서 직선까지의 거리를 나타낸다.", r"거리는 $\dfrac{|2m+1|}{\sqrt{m^2+1}}$이다."),
                ("접할 조건으로 거리의 제곱 방정식을 세운다.", r"$(2m+1)^2=m^2+1$이다."),
                ("기울기에 대한 이차방정식과 두 근의 합을 구한다.", r"$3m^2+4m=0$이므로 $m_1+m_2=-\dfrac43$이다."),
                ("문제에서 요구한 식을 계산한다.", r"$-3(m_1+m_2)=-3\left(-\dfrac43\right)=4$이다."),
            ],
            alternatives=[
                r"한 접선은 $x$축이라서 $m_1=0$이고, 다른 접선의 기울기는 이차방정식에서 $-4/3$이다.",
                r"기울기 방정식에서 근과 계수의 관계를 적용하면 두 기울기를 따로 구하지 않고 합을 얻을 수 있다.",
            ],
        ),
        _problem(
            5,
            9,
            title=r"최고차항의 계수가 $1$인 삼차함수 $f$가 $f'(x)=3(x-1)(x-3)$, $f(1)=4$를 만족한다. 곡선 $y=f(x)$와 $x$축 및 두 직선 $x=0$, $x=3$으로 둘러싸인 넓이를 $S$라 할 때, $4S$를 구하시오.",
            answer="27",
            tags=["#도함수", "#부정적분", "#함수의극대와극소", "#인수분해", "#정적분과넓이"],
            steps=[
                ("주어진 도함수를 전개한다.", r"$f'(x)=3x^2-12x+9$이다."),
                ("도함수를 적분하여 삼차함수의 형태를 구한다.", r"$f(x)=x^3-6x^2+9x+C$이다."),
                ("함숫값 조건으로 적분상수를 정한다.", r"$f(1)=4+C=4$이므로 $C=0$이다."),
                ("함수식을 인수분해하여 구간의 부호를 확인한다.", r"$f(x)=x(x-3)^2$이므로 $0\le x\le3$에서 $f(x)\ge0$이다."),
                ("넓이를 정적분으로 계산한다.", r"$S=\int_0^3(x^3-6x^2+9x)dx=\dfrac{27}{4}$이다."),
                ("문제에서 요구한 배수를 계산한다.", r"$4S=27$이다."),
            ],
            alternatives=[
                r"$f'(x)$의 중근 구조와 $f(1)=4$를 이용해 $f(x)=x(x-3)^2$임을 전개로 검산할 수 있다.",
                r"구간에서 $x\ge0$이고 $(x-3)^2\ge0$이므로 절댓값 없이 정적분한 값이 곧 넓이이다.",
            ],
        ),
        _problem(
            5,
            10,
            title=r"유리함수 $f(x)=\dfrac{ax+b}{x+1}$이 $f(0)=2$이고 정의되는 모든 실수 $x$에 대하여 $f(f(x))=x$를 만족한다. 방정식 $f(x)=x$의 두 근의 합을 $s$라 할 때, $a+b+s$를 구하시오.",
            answer="-1",
            tags=["#유리함수의그래프", "#역함수", "#합성함수", "#근과계수의관계", "#점근선"],
            steps=[
                ("주어진 함숫값으로 분자의 상수항을 정한다.", r"$f(0)=b=2$이므로 $b=2$이다."),
                ("일반적인 합성함수 식을 계산한다.", r"$f(f(x))=\dfrac{(a^2+2)x+2a+2}{(a+1)x+3}$이다."),
                ("항등적으로 $x$와 같을 계수 조건을 세운다.", r"분모를 곱하면 $x^2$항의 계수가 $a+1$이므로 $a+1=0$이다."),
                ("매개변수를 정하고 합성 조건을 검산한다.", r"$a=-1$일 때 나머지 계수도 일치하여 $f(f(x))=x$이다."),
                ("고정점 방정식의 두 근의 합을 구한다.", r"$\dfrac{-x+2}{x+1}=x$에서 $x^2+2x-2=0$이므로 $s=-2$이다."),
                ("세 값을 모두 더한다.", r"$a+b+s=-1+2-2=-1$이다."),
            ],
            alternatives=[
                r"일차분수함수의 행렬 $\begin{pmatrix}a&2\\1&1\end{pmatrix}$이 제곱했을 때 스칼라 행렬이 되려면 대각합 조건에서 $a=-1$이다.",
                r"구한 함수 $f(x)=(-x+2)/(x+1)$에 고정점의 두 근을 직접 대입하지 않아도 근과 계수의 관계로 합 $-2$를 얻는다.",
            ],
        ),
    ]


def _count_branches(solves: Iterable[dict[str, Any]]) -> int:
    """필요 변수: 최상위 풀이 단계. 작동 원리: 재귀 순회한 전체 단계 수에서 본 풀이 단계 수를 빼 분기 수를 센다."""
    top_level = list(solves)
    return len(list(_walk_steps(top_level))) - len(top_level)


def validate_catalog(catalog: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """필요 변수: 50문항 원본 명세. 작동 원리: 수량·난이도·태그·풀이·분기·학생 노출 계약을 DB 기록 전에 전수 검증한다."""
    if len(catalog) != 50:
        raise ValueError(f"catalog must contain 50 problems, got {len(catalog)}")
    tier_counts = Counter(int(spec["tier"]) for spec in catalog)
    expected_counts = {tier: 10 for tier in range(1, 6)}
    if dict(tier_counts) != expected_counts:
        raise ValueError(f"tier distribution mismatch: {dict(tier_counts)}")

    quests = [_build_quest(spec) for spec in catalog]
    quest_ids = [quest["header"]["quest_id"] for quest in quests]
    titles = [_content_text(quest["data"]["quest_title"]) for quest in quests]
    variants = [
        (quest["data"]["codebase_id"], quest["data"]["seed"])
        for quest in quests
    ]
    if len(set(quest_ids)) != len(quest_ids):
        raise ValueError("duplicate quest_id in catalog")
    if len(set(titles)) != len(titles):
        raise ValueError("duplicate problem title in catalog")
    if len(set(variants)) != len(variants):
        raise ValueError("duplicate codebase_id/seed pair in catalog")

    for quest in quests:
        info = quest["info"]
        tier = int(info["difficulty_tier"])
        contract = DIFFICULTY_CONTRACTS[tier]
        solves = quest["solves"]
        tags = info["hash_tag"]
        if len(solves) != contract.solves_count:
            raise ValueError(f"solve count mismatch: {quest['header']['quest_id']}")
        if _count_branches(solves) != contract.branch_conditions:
            raise ValueError(f"branch count mismatch: {quest['header']['quest_id']}")
        if len(tags) != TIER_TAG_COUNTS[tier] or len(set(tags)) != len(tags):
            raise ValueError(f"tag count mismatch: {quest['header']['quest_id']}")
        if any(not str(tag).startswith("#") for tag in tags):
            raise ValueError(f"unnormalized tag: {quest['header']['quest_id']}")
        if info["flow_rate"] != len(list(_walk_steps(solves))):
            raise ValueError(f"flow rate mismatch: {quest['header']['quest_id']}")
        review = review_student_problem_contract(
            quest,
            expected_solve_count=contract.solves_count,
            expected_tags=tags,
        )
        if review["approved"] is not True:
            raise ValueError(
                f"student contract rejected: {quest['header']['quest_id']} {review['reasons']}"
            )
    return quests


def _existing_title_map(connection: sqlite3.Connection) -> dict[str, str]:
    """필요 변수: 문제 DB 연결. 작동 원리: 기존 제목을 평문으로 정규화해 다른 ID의 동일 문제 삽입을 차단한다."""
    result: dict[str, str] = {}
    for quest_id, raw_title in connection.execute(
        "SELECT quest_id, quest_title FROM quest_data"
    ):
        title = _content_text(raw_title)
        if title:
            result.setdefault(title, str(quest_id))
    return result


def _create_backup(source_path: Path, backup_path: Path) -> bool:
    """필요 변수: 원본 DB와 백업 경로. 작동 원리: SQLite 온라인 백업 API로 WAL 상태를 포함한 일관된 사본을 한 번만 만든다."""
    if backup_path.exists():
        return False
    with sqlite3.connect(source_path) as source, sqlite3.connect(backup_path) as target:
        source.backup(target)
    return True


def _remove_inserted_batch(db_path: Path, quest_ids: list[str]) -> None:
    """필요 변수: 현재 실행에서 새로 넣은 ID. 작동 원리: 예외 발생 시 해당 ID만 역순으로 지워 부분 저장을 남기지 않는다."""
    if not quest_ids:
        return
    placeholders = ",".join("?" for _ in quest_ids)
    with sqlite3.connect(db_path) as connection:
        connection.execute("BEGIN IMMEDIATE")
        for table in ("quest_tag_index", "solve_step", "quest_data", "quest_info", "quest_header"):
            connection.execute(
                f"DELETE FROM {table} WHERE quest_id IN ({placeholders})",
                quest_ids,
            )
        connection.commit()


def seed_database(
    db_path: Path,
    *,
    validate_only: bool,
    create_backup: bool,
) -> dict[str, Any]:
    """필요 변수: 대상 DB와 실행 옵션. 작동 원리: 전수 사전검사 후 앱 저장 함수를 사용해 신규 항목만 직접 기록하고 다시 전수 조회한다."""
    db_path = db_path.resolve()
    catalog = build_catalog()
    quests = validate_catalog(catalog)
    report: dict[str, Any] = {
        "batch_id": BATCH_ID,
        "db_path": str(db_path),
        "validated": len(quests),
        "inserted": 0,
        "skipped": 0,
        "tier_counts": dict(sorted(Counter(q["info"]["difficulty_tier"] for q in quests).items())),
    }
    if validate_only:
        return report

    os.environ["QUEST_DB_PATH"] = str(db_path)
    from storage import storage as quest_storage

    quest_storage.DB_PATH = str(db_path)
    quest_storage.init_db()
    with sqlite3.connect(db_path) as connection:
        existing_titles = _existing_title_map(connection)
        existing_ids = {
            str(row[0])
            for row in connection.execute(
                "SELECT quest_id FROM quest_header WHERE quest_id LIKE ?",
                (f"{QUEST_ID_PREFIX}/%",),
            )
        }

    for quest in quests:
        quest_id = quest["header"]["quest_id"]
        if quest_id in existing_ids:
            loaded = quest_storage.get_quest(quest_id)
            batch_id = (((loaded or {}).get("data") or {}).get("meta") or {}).get("batch_id")
            if batch_id != BATCH_ID:
                raise RuntimeError(f"quest_id collision with another batch: {quest_id}")
            report["skipped"] += 1
            continue
        title = _content_text(quest["data"]["quest_title"])
        if title in existing_titles:
            raise RuntimeError(
                f"duplicate title with existing quest {existing_titles[title]}: {title}"
            )

    backup_path = db_path.with_name(f"{db_path.name}.bak_{BATCH_ID}")
    if create_backup:
        report["backup_created"] = _create_backup(db_path, backup_path)
        report["backup_path"] = str(backup_path)

    inserted_ids: list[str] = []
    try:
        for quest in quests:
            quest_id = quest["header"]["quest_id"]
            if quest_id in existing_ids:
                continue
            if not quest_storage.store_data(quest):
                raise RuntimeError(
                    f"store failed: {quest_id}: {quest_storage.get_last_store_error()}"
                )
            inserted_ids.append(quest_id)
    except Exception:
        _remove_inserted_batch(db_path, inserted_ids)
        raise

    loaded = quest_storage.get_quests_by_ids(
        [quest["header"]["quest_id"] for quest in quests]
    )
    if len(loaded) != 50:
        raise RuntimeError(f"readback count mismatch: expected 50, got {len(loaded)}")
    readback_tiers: Counter[int] = Counter()
    for quest in loaded:
        info = quest["info"]
        tier = int(info["difficulty_tier"])
        readback_tiers[tier] += 1
        if info.get("quality_status") != "approved":
            raise RuntimeError(f"unapproved readback: {quest['header']['quest_id']}")
        if len(quest.get("solves") or []) != DIFFICULTY_CONTRACTS[tier].solves_count:
            raise RuntimeError(f"readback solve mismatch: {quest['header']['quest_id']}")
        if (((quest.get("data") or {}).get("meta") or {}).get("batch_id")) != BATCH_ID:
            raise RuntimeError(f"readback batch mismatch: {quest['header']['quest_id']}")

    if dict(sorted(readback_tiers.items())) != {tier: 10 for tier in range(1, 6)}:
        raise RuntimeError(f"readback tier mismatch: {dict(readback_tiers)}")
    report["inserted"] = len(inserted_ids)
    report["readback"] = len(loaded)
    report["approved"] = sum(
        1 for quest in loaded if quest["info"].get("quality_status") == "approved"
    )
    report["readback_tier_counts"] = dict(sorted(readback_tiers.items()))
    report["utf8_korean_titles"] = sum(
        1
        for quest in loaded
        if re.search(r"[가-힣]", _content_text(quest["data"]["quest_title"]))
    )
    return report


def main() -> None:
    """필요 변수: 명령행 DB 경로와 검증 옵션. 작동 원리: UTF-8 JSON 보고서를 출력하며 기본 실행은 백업 후 실제 DB에 저장한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--db",
        type=Path,
        default=ROOT / "quests.db",
        help="저장할 quests.db 경로",
    )
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--no-backup", action="store_true")
    args = parser.parse_args()
    report = seed_database(
        args.db,
        validate_only=args.validate_only,
        create_backup=not args.no_backup,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
