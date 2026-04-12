import random

def generate_problem(seed=None):
    rng = random.Random(seed)
    hash_tags = ["#유리함수의평행이동", "#정적분의선형성", "#일반항"]
    root_flows_len = 4
    branch_conditions = 1

    k = 0
    while k == 0:
        k = rng.randint(-20, 20)

    d = rng.randint(1, 5)
    c = k - d

    problem_title = f"등차수열 $a_n$의 제1항이 ${d+c}$이고, 제2항이 ${2*d+c}$일 때, 일반항 $a_n = dn+c$에서 $a_1$의 값은?"

    solves = []
    for i in range(root_flows_len):
        branches = []
        if i == 0:
            for _ in range(branch_conditions):
                branches.append({
                    "flow": f"수열의 공차 $d$ 확인: $d = {d}$",
                    "hash_tag": ["#일반항"],
                    "hint_riddle": "일반항 공식 $a_n = a_1 + (n-1)d$를 이용하세요.",
                    "answer_riddle": f"주어진 조건에서 $a_1 = {d+c}$이므로 정답은 ${k}$입니다.",
                    "enter_huddle": 0,
                    "branches": []
                })

        solves.append({
            "flow": f"단계 {i+1}: 수열의 일반항 $a_n = {d}n + {c}$ 분석",
            "hash_tag": ["#일반항"],
            "hint_riddle": "n에 1을 대입하여 $a_1$을 계산하세요.",
            "answer_riddle": f"$a_1 = {d}(1) + {c} = {k}$",
            "enter_huddle": 0,
            "branches": branches
        })

    result = {
        "quest_title": problem_title,
        "quest_answer": f"${k}$",
        "main_huddle": 2,
        "primary_hash_tag": "#일반항",
        "quest_image": None,
        "solves": solves,
        "meta": {
            "sympy": {
                "param_symbols": ["k"],
                "params": {"k": k},
                "equations": ["a_n = d*n + c"],
                "constraints": ["n >= 1"],
                "answer_expr": "d + c"
            }
        }
    }

    return result