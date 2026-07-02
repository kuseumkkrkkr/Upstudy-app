"""
Verify 10 random student profiles using the EXACT production rating algorithm replica.

This script uses sim_data.rating_algorithm_replica (which mirrors omj/rating_service.py)
to simulate realistic problem-solving sessions and verify OVR convergence.
"""

import json
import math
import random
import time
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Tuple

import sys
sys.path.insert(0, r'C:\Users\82102\Desktop\s11')

from sim_data.rating_algorithm_replica import (
    CONFIG, InMemoryRatingDB, apply_rating_update, fetch_user_rating
)


# ---------------------------------------------------------------------------
# Problem generation (realistic difficulty model)
# ---------------------------------------------------------------------------
ALL_TAGS = [
    "algebra", "equation", "inequality", "function", "graph",
    "geometry", "triangle", "circle", "polygon", "coordinate",
    "calculus", "limit", "derivative", "integral", "series",
    "probability", "statistics", "combination", "permutation", "number_theory",
    "logic", "set", "sequence", "matrix", "vector",
]


def generate_problem(true_skill: float, consistency: float, seed: int) -> Dict:
    """Generate a problem with difficulty calibrated to true_skill."""
    rng = random.Random(seed)
    # difficulty: 0-10, centered around skill/350 with noise
    base_diff = _clamp(true_skill / 350.0, 0.5, 9.5)
    difficulty = _clamp(base_diff + rng.gauss(0, 1.5), 0.5, 9.5)

    # main_huddle: 0-5, correlated with difficulty
    main_huddle = _clamp(difficulty * 0.4 + rng.gauss(0, 0.5), 0.2, 4.5)

    # flow_rate: 1-5
    flow_rate = rng.randint(1, 5)

    # Number of steps
    n_steps = rng.randint(1, 4)

    # Tags per problem: 2-4
    n_tags = rng.randint(2, 4)
    tags = rng.sample(ALL_TAGS, n_tags)

    steps = []
    for step_idx in range(1, n_steps + 1):
        enter_huddle = _clamp(main_huddle * rng.uniform(0.3, 1.2), 0.1, 5.0)
        step_tags = rng.sample(tags, rng.randint(1, min(2, len(tags))))
        steps.append({
            "enter_huddle": enter_huddle,
            "hash_tag": step_tags,
        })

    return {
        "info": {
            "difficulty": difficulty,
            "main_huddle": main_huddle,
            "flow_rate": flow_rate,
        },
        "solves": steps,
        "tags": tags,
    }


def _clamp(v, lo, hi):
    return max(lo, min(hi, v))


def simulate_answer(true_skill: float, consistency: float, problem: Dict, seed: int) -> Tuple[bool, List[Dict], Optional[float]]:
    """
    Returns (is_correct, step_correctness, answer_time).
    Higher skill + higher consistency = higher accuracy.
    """
    rng = random.Random(seed)
    difficulty = problem["info"]["difficulty"]
    main_huddle = problem["info"]["main_huddle"]
    flow_rate = problem["info"]["flow_rate"]

    # Probability of correct = sigmoid-like based on skill vs difficulty
    skill_advantage = (true_skill - difficulty * 350) / 500.0
    consistency_boost = consistency * 0.3
    p_correct = _clamp(0.5 + skill_advantage + consistency_boost, 0.05, 0.99)

    is_correct = rng.random() < p_correct

    # Step-level correctness
    steps = problem["solves"]
    step_correctness = []
    for i, step in enumerate(steps, start=1):
        step_p = p_correct * rng.uniform(0.85, 1.0) if is_correct else p_correct * rng.uniform(0.5, 0.9)
        step_p = _clamp(step_p, 0.0, 1.0)
        step_correct = rng.random() < step_p
        step_correctness.append({"step_id": i, "correct": step_correct})

    # If any step is wrong, overall is wrong (but we keep is_correct param semantics simple)
    # Actually: if the user got it 'correct' overall but a step is wrong, override
    any_wrong_step = any(not sc["correct"] for sc in step_correctness)
    if any_wrong_step:
        is_correct = False

    # Answer time: faster if skill > difficulty, slower otherwise
    expected_time = 30 + 20 * flow_rate + 30 * main_huddle
    if skill_advantage > 0:
        expected_time *= max(0.3, 1.0 - skill_advantage * 0.5)
    else:
        expected_time *= min(2.0, 1.0 - skill_advantage * 0.8)
    answer_time = max(5.0, expected_time + rng.gauss(0, expected_time * 0.3))

    return is_correct, step_correctness, answer_time


# ---------------------------------------------------------------------------
# Student profile generation
# ---------------------------------------------------------------------------
def generate_student_profile(sid: int, seed: int) -> Dict:
    rng = random.Random(seed + sid * 1000)
    # Skill: 300-3500 (realistic range)
    true_skill = int(rng.gauss(1800, 700))
    true_skill = max(300, min(3500, true_skill))
    # Consistency: 0.3-0.95
    consistency = _clamp(rng.gauss(0.7, 0.15), 0.3, 0.95)
    # Number of problems: 5000-10000
    n_problems = rng.randint(5000, 10000)
    return {
        "sid": sid,
        "true_skill": true_skill,
        "consistency": consistency,
        "n_problems": n_problems,
    }


def run_student(db: InMemoryRatingDB, profile: Dict, seed: int) -> Dict:
    sid = profile["sid"]
    true_skill = profile["true_skill"]
    consistency = profile["consistency"]
    n_problems = profile["n_problems"]

    user_id = f"student_{sid}"
    correct_count = 0
    checkpoints = [100, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
    checkpoint_ovrs = {}

    for i in range(n_problems):
        p_seed = seed + sid * 100000 + i
        problem = generate_problem(true_skill, consistency, p_seed)
        is_correct, step_correctness, answer_time = simulate_answer(
            true_skill, consistency, problem, p_seed
        )
        if is_correct:
            correct_count += 1

        apply_rating_update(
            db,
            user_id=user_id,
            quest=problem,
            is_correct=is_correct,
            tags=problem["tags"],
            step_correctness=step_correctness,
            answer_time=answer_time,
            submission_id=f"sub_{sid}_{i}",
        )

        if (i + 1) in checkpoints:
            result = fetch_user_rating(db, user_id)
            checkpoint_ovrs[i + 1] = round(result.ovr, 1)

    final_result = fetch_user_rating(db, user_id)
    accuracy = correct_count / n_problems if n_problems > 0 else 0.0

    return {
        "sid": sid,
        "true_skill": true_skill,
        "consistency": consistency,
        "n_problems": n_problems,
        "final_accuracy": accuracy,
        "final_ovr": final_result.ovr,
        "final_rating": final_result.rating,
        "lose_streak": final_result.lose_streak,
        "recent_accuracy": final_result.recent_accuracy,
        "checkpoints": checkpoint_ovrs,
    }


def expected_ovr_range(true_skill: float, accuracy: float) -> Tuple[float, float]:
    """Return (min_expected, max_expected) OVR based on skill and accuracy."""
    # Rough heuristic: OVR should correlate with both skill and accuracy
    base = 400 + (true_skill / 3500.0) * 1600  # 400-2000 from skill alone
    acc_bonus = accuracy * 800  # 0-800 from accuracy
    min_ovr = base * 0.8 + acc_bonus * 0.5
    max_ovr = base * 1.2 + acc_bonus * 1.5 + 500
    return min_ovr, max_ovr


def main():
    seed = 42
    random.seed(seed)

    print("=" * 70)
    print("VERIFY 10 RANDOM PROFILES -- EXACT PRODUCTION ALGORITHM REPLICA")
    print("=" * 70)
    print(f"CONFIG: K={CONFIG.K}, K_MIN={CONFIG.K_MIN}, DELTA_MAX={CONFIG.DELTA_MAX}")
    print(f"        DEFAULT_RATING={CONFIG.DEFAULT_RATING}, U_MAX={CONFIG.U_MAX}")
    print()

    db = InMemoryRatingDB()
    profiles = [generate_student_profile(i, seed) for i in range(10)]

    t0 = time.time()
    results = []
    for profile in profiles:
        result = run_student(db, profile, seed)
        results.append(result)
    total_time = time.time() - t0

    # Summary table
    print(f"{'SID':>3} | {'Skill':>6} | {'Cons':>4} | {'N':>6} | {'Acc%':>6} | {'OVR':>8} | {'Range':>18} | {'Pass'}")
    print("-" * 70)

    all_pass = True
    for r in results:
        min_ovr, max_ovr = expected_ovr_range(r["true_skill"], r["final_accuracy"])
        passed = min_ovr <= r["final_ovr"] <= max_ovr
        if not passed:
            all_pass = False
        print(
            f"{r['sid']:>3} | {r['true_skill']:>6} | {r['consistency']:.2f} | "
            f"{r['n_problems']:>6} | {r['final_accuracy']*100:>5.1f}% | "
            f"{r['final_ovr']:>8.1f} | [{min_ovr:>6.0f}, {max_ovr:>6.0f}] | "
            f"{'PASS' if passed else 'FAIL'}"
        )

    print("-" * 70)
    print(f"Total time: {total_time:.1f}s for {sum(p['n_problems'] for p in profiles)} problems")
    print(f"Overall: {'ALL PASS' if all_pass else 'SOME FAILED'}")

    # Save results
    output = {
        "config": {
            "k": CONFIG.K,
            "delta_max": CONFIG.DELTA_MAX,
            "default_rating": CONFIG.DEFAULT_RATING,
        },
        "students": [
            {
                "sid": r["sid"],
                "true_skill": r["true_skill"],
                "consistency": r["consistency"],
                "n_problems": r["n_problems"],
                "final_accuracy": r["final_accuracy"],
                "final_ovr": r["final_ovr"],
                "final_rating": r["final_rating"],
                "lose_streak": r["lose_streak"],
                "recent_accuracy": r["recent_accuracy"],
                "checkpoints": r["checkpoints"],
            }
            for r in results
        ],
        "overall_pass": all_pass,
        "total_time_sec": total_time,
    }

    out_path = r"C:\Users\82102\Desktop\s11\sim_data\verify_10_profiles_replica_results.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"\nSaved: {out_path}")


if __name__ == "__main__":
    main()
