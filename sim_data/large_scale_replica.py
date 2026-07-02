"""
Large-scale OVR convergence test using the EXACT production algorithm replica.
500 students x 7000 problems each.
Compare with simulator/ovr_convergence_simulator_v3.py results.
"""

import json
import math
import random
import time
from typing import Dict, List

import sys
sys.path.insert(0, r'C:\Users\82102\Desktop\s11')

from sim_data.rating_algorithm_replica import (
    CONFIG, InMemoryRatingDB, apply_rating_update, fetch_user_rating
)


ALL_TAGS = [
    "algebra", "equation", "inequality", "function", "graph",
    "geometry", "triangle", "circle", "polygon", "coordinate",
    "calculus", "limit", "derivative", "integral", "series",
    "probability", "statistics", "combination", "permutation", "number_theory",
    "logic", "set", "sequence", "matrix", "vector",
]


def _clamp(v, lo, hi):
    return max(lo, min(hi, v))


def generate_problem(true_skill: float, consistency: float, seed: int) -> Dict:
    rng = random.Random(seed)
    base_diff = _clamp(true_skill / 350.0, 0.5, 9.5)
    difficulty = _clamp(base_diff + rng.gauss(0, 1.5), 0.5, 9.5)
    main_huddle = _clamp(difficulty * 0.4 + rng.gauss(0, 0.5), 0.2, 4.5)
    flow_rate = rng.randint(1, 5)
    n_steps = rng.randint(1, 4)
    n_tags = rng.randint(2, 4)
    tags = rng.sample(ALL_TAGS, n_tags)

    steps = []
    for _ in range(n_steps):
        enter_huddle = _clamp(main_huddle * rng.uniform(0.3, 1.2), 0.1, 5.0)
        step_tags = rng.sample(tags, rng.randint(1, min(2, len(tags))))
        steps.append({"enter_huddle": enter_huddle, "hash_tag": step_tags})

    return {
        "info": {"difficulty": difficulty, "main_huddle": main_huddle, "flow_rate": flow_rate},
        "solves": steps,
        "tags": tags,
    }


def simulate_answer(true_skill: float, consistency: float, problem: Dict, seed: int):
    rng = random.Random(seed)
    difficulty = problem["info"]["difficulty"]
    skill_advantage = (true_skill - difficulty * 350) / 500.0
    consistency_boost = consistency * 0.3
    p_correct = _clamp(0.5 + skill_advantage + consistency_boost, 0.05, 0.99)
    is_correct = rng.random() < p_correct

    steps = problem["solves"]
    step_correctness = []
    for i, step in enumerate(steps, start=1):
        step_p = p_correct * rng.uniform(0.85, 1.0) if is_correct else p_correct * rng.uniform(0.5, 0.9)
        step_p = _clamp(step_p, 0.0, 1.0)
        step_correct = rng.random() < step_p
        step_correctness.append({"step_id": i, "correct": step_correct})
    if any(not sc["correct"] for sc in step_correctness):
        is_correct = False

    expected_time = 30 + 20 * problem["info"]["flow_rate"] + 30 * problem["info"]["main_huddle"]
    if skill_advantage > 0:
        expected_time *= max(0.3, 1.0 - skill_advantage * 0.5)
    else:
        expected_time *= min(2.0, 1.0 - skill_advantage * 0.8)
    answer_time = max(5.0, expected_time + rng.gauss(0, expected_time * 0.3))
    return is_correct, step_correctness, answer_time


def simulate_one_student(sid: int, n_problems: int, seed: int, checkpoints: List[int]) -> Dict:
    rng = random.Random(seed + sid * 10000)
    true_skill = int(rng.gauss(1800, 700))
    true_skill = max(300, min(3500, true_skill))
    consistency = _clamp(rng.gauss(0.7, 0.15), 0.3, 0.95)

    db = InMemoryRatingDB()
    user_id = f"student_{sid}"
    correct_count = 0
    checkpoint_ovrs = {}

    for i in range(n_problems):
        p_seed = seed + sid * 100000 + i
        problem = generate_problem(true_skill, consistency, p_seed)
        is_correct, step_correctness, answer_time = simulate_answer(true_skill, consistency, problem, p_seed)
        if is_correct:
            correct_count += 1

        apply_rating_update(
            db, user_id=user_id, quest=problem, is_correct=is_correct,
            tags=problem["tags"], step_correctness=step_correctness,
            answer_time=answer_time, submission_id=f"sub_{sid}_{i}"
        )

        if (i + 1) in checkpoints:
            result = fetch_user_rating(db, user_id)
            checkpoint_ovrs[i + 1] = round(result.ovr, 1)

    final = fetch_user_rating(db, user_id)
    accuracy = correct_count / n_problems

    return {
        "sid": sid,
        "true_skill": true_skill,
        "consistency": consistency,
        "final_accuracy": accuracy,
        "final_ovr": final.ovr,
        "final_rating": final.rating,
        "lose_streak": final.lose_streak,
        "recent_accuracy": final.recent_accuracy,
        "checkpoints": checkpoint_ovrs,
    }


def main():
    N_STUDENTS = 500
    N_PROBLEMS = 7000
    SEED = 42
    CHECKPOINTS = [100, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7000]

    print("=" * 70)
    print("LARGE-SCALE OVR CONVERGENCE -- EXACT PRODUCTION ALGORITHM REPLICA")
    print("=" * 70)
    print(f"Students: {N_STUDENTS}, Problems each: {N_PROBLEMS}")
    print(f"CONFIG: K={CONFIG.K}, K_MIN={CONFIG.K_MIN}, DELTA_MAX={CONFIG.DELTA_MAX}")
    print()

    t0 = time.time()
    results = []
    for sid in range(N_STUDENTS):
        result = simulate_one_student(sid, N_PROBLEMS, SEED, CHECKPOINTS)
        results.append(result)
        if (sid + 1) % 50 == 0:
            elapsed = time.time() - t0
            print(f"  Completed {sid + 1}/{N_STUDENTS} students ({elapsed:.1f}s)")

    total_time = time.time() - t0

    # Aggregate stats
    final_ovrs = [r["final_ovr"] for r in results]
    true_skills = [r["true_skill"] for r in results]
    accuracies = [r["final_accuracy"] for r in results]

    avg_ovr = sum(final_ovrs) / len(final_ovrs)
    std_ovr = (sum((o - avg_ovr) ** 2 for o in final_ovrs) / len(final_ovrs)) ** 0.5
    min_ovr = min(final_ovrs)
    max_ovr = max(final_ovrs)

    # Correlation: true_skill vs final_ovr
    n = len(results)
    mean_skill = sum(true_skills) / n
    mean_ovr = avg_ovr
    cov = sum((true_skills[i] - mean_skill) * (final_ovrs[i] - mean_ovr) for i in range(n)) / n
    var_skill = sum((s - mean_skill) ** 2 for s in true_skills) / n
    var_ovr = sum((o - mean_ovr) ** 2 for o in final_ovrs) / n
    corr = cov / ((var_skill * var_ovr) ** 0.5) if var_skill > 0 and var_ovr > 0 else 0.0

    # Correlation: accuracy vs final_ovr
    mean_acc = sum(accuracies) / n
    cov_acc = sum((accuracies[i] - mean_acc) * (final_ovrs[i] - mean_ovr) for i in range(n)) / n
    var_acc = sum((a - mean_acc) ** 2 for a in accuracies) / n
    corr_acc = cov_acc / ((var_acc * var_ovr) ** 0.5) if var_acc > 0 and var_ovr > 0 else 0.0

    print()
    print("-" * 70)
    print("RESULTS SUMMARY")
    print("-" * 70)
    print(f"Total time: {total_time:.1f}s ({total_time / (N_STUDENTS * N_PROBLEMS) * 1000:.2f}ms per problem)")
    print(f"Final OVR:  avg={avg_ovr:.1f}, std={std_ovr:.1f}, min={min_ovr:.1f}, max={max_ovr:.1f}")
    print(f"Accuracy:   avg={mean_acc * 100:.1f}%, std={(sum((a - mean_acc) ** 2 for a in accuracies) / n) ** 0.5 * 100:.1f}%")
    print(f"Skill:      avg={mean_skill:.0f}, std={var_skill ** 0.5:.0f}")
    print(f"Correlation (skill vs ovr): {corr:.3f}")
    print(f"Correlation (accuracy vs ovr): {corr_acc:.3f}")

    # Checkpoint convergence
    print()
    print("CHECKPOINT OVR CONVERGENCE")
    print("-" * 70)
    for cp in CHECKPOINTS:
        cp_ovrs = [r["checkpoints"].get(cp, 1200.0) for r in results]
        cp_avg = sum(cp_ovrs) / len(cp_ovrs)
        cp_std = (sum((o - cp_avg) ** 2 for o in cp_ovrs) / len(cp_ovrs)) ** 0.5
        print(f"  {cp:>5} problems: avg OVR={cp_avg:.1f}, std={cp_std:.1f}")

    # Save
    output = {
        "config": {
            "k": CONFIG.K,
            "delta_max": CONFIG.DELTA_MAX,
            "default_rating": CONFIG.DEFAULT_RATING,
            "u_max": CONFIG.U_MAX,
        },
        "meta": {
            "n_students": N_STUDENTS,
            "n_problems": N_PROBLEMS,
            "seed": SEED,
            "total_time_sec": total_time,
        },
        "aggregate": {
            "avg_ovr": avg_ovr,
            "std_ovr": std_ovr,
            "min_ovr": min_ovr,
            "max_ovr": max_ovr,
            "avg_accuracy": mean_acc,
            "avg_skill": mean_skill,
            "skill_ovr_correlation": corr,
            "accuracy_ovr_correlation": corr_acc,
        },
        "checkpoints": {
            str(cp): {
                "avg": sum(r["checkpoints"].get(cp, 1200.0) for r in results) / len(results),
                "std": (sum((r["checkpoints"].get(cp, 1200.0) - sum(r["checkpoints"].get(cp, 1200.0) for r in results) / len(results)) ** 2 for r in results) / len(results)) ** 0.5,
            }
            for cp in CHECKPOINTS
        },
        "students": [
            {
                "sid": r["sid"],
                "true_skill": r["true_skill"],
                "consistency": r["consistency"],
                "final_accuracy": r["final_accuracy"],
                "final_ovr": r["final_ovr"],
                "final_rating": r["final_rating"],
                "lose_streak": r["lose_streak"],
                "recent_accuracy": r["recent_accuracy"],
                "checkpoints": r["checkpoints"],
            }
            for r in results
        ],
    }

    out_path = r"C:\Users\82102\Desktop\s11\sim_data\large_scale_replica_results.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"\nSaved: {out_path}")


if __name__ == "__main__":
    main()
