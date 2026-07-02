#!/usr/bin/env python3
"""
OVR Convergence Simulator - Optimized Version
=============================================
Goal: Verify that OVR converges to high values after ~7000 problems at ~90% accuracy.

Optimizations from v1:
  - No CSV per-problem I/O (buffered, write once at end)
  - Pure dicts instead of dataclasses
  - Minimal progress logging (every 10%)
  - Results saved as pickle for post-hoc analysis
  - Optional: multiprocessing via concurrent.futures

Run:
    cd C:/Users/82102/Desktop/s11
    python simulator/ovr_convergence_simulator_v2.py
"""

import sys, os, math, random, time, json, csv, pickle, argparse
from pathlib import Path
from typing import List, Dict, Tuple, Any

# ---------------------------------------------------------------------------
# Config (mirrors rating_config.py)
# ---------------------------------------------------------------------------
K = 32.0
K_MIN = 12.0
DELTA_MAX = 50.0
U_MAX = 2400.0
C_MAX = 30.0
TAU_DAYS = 21.0
M_LOSE = 0.12
ALPHA = 0.35
BETA = 0.25
GAMMA = 0.25
DELTA_W = 0.15
LAMBDA = 0.4
MU = 0.3
NU = 0.3
DEFAULT_RATING = 1200.0

ALL_TAGS = [f"tag_{i:02d}" for i in range(20)]  # 20 tags

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _exp_score(user_rating: float, problem_rating: float) -> float:
    return 1.0 / (1.0 + 10.0 ** ((problem_rating - user_rating) / 400.0))


def _k_factor(lose_streak: int) -> float:
    return max(K_MIN, K * math.exp(-M_LOSE * max(0, lose_streak)))


def _barrier(enter_huddle: float, main_huddle: float) -> float:
    return max(0.0, min(10.0, enter_huddle - main_huddle))


def _problem_weight(difficulty: float, barrier_val: float) -> float:
    w_diff = difficulty / 20.0
    w_barrier = barrier_val / 10.0
    return LAMBDA + MU * w_barrier + NU * w_diff


def _problem_rating(difficulty: float, barrier_val: float) -> float:
    return 800.0 + 1400.0 * (difficulty / 20.0) + 200.0 * (barrier_val / 10.0)


def _time_factor(answer_time: float, flow_rate: float, main_huddle: float) -> float:
    if answer_time <= 0:
        return 1.0
    expected = main_huddle * 60.0 / max(flow_rate, 1.0)
    ratio = answer_time / expected
    if ratio <= 0.5:
        return 1.0
    elif ratio <= 1.0:
        return 1.0 - 0.3 * (ratio - 0.5) / 0.5
    elif ratio <= 2.0:
        return 0.7 - 0.4 * (ratio - 1.0)
    else:
        return 0.3


def _confidence(user_rating: float, attempts: int, recent_acc: float, time_fac: float) -> float:
    r_u = min(user_rating / U_MAX, 1.0)
    r_c = min(attempts / C_MAX, 1.0)
    r_r = recent_acc
    r_t = time_fac
    return (ALPHA * r_u + BETA * r_c + GAMMA * r_r + DELTA_W * r_t) * time_fac


# ---------------------------------------------------------------------------
# Problem generator
# ---------------------------------------------------------------------------
def generate_problem(pid: int, rng: random.Random) -> Dict[str, Any]:
    difficulty = rng.uniform(3.0, 18.0)
    main_huddle = float(rng.randint(1, 3))
    n_steps = rng.randint(2, 4)
    steps = []
    all_tags = set()
    for _ in range(n_steps):
        enter_huddle = rng.uniform(2.0, 8.0)
        n_tags = rng.randint(1, 2)
        step_tags = rng.sample(ALL_TAGS, k=n_tags)
        all_tags.update(step_tags)
        steps.append({
            "enter_huddle": enter_huddle,
            "tags": step_tags,
        })
    return {
        "pid": pid,
        "difficulty": difficulty,
        "main_huddle": main_huddle,
        "steps": steps,
        "tags": sorted(all_tags),
    }


# ---------------------------------------------------------------------------
# Student simulator
# ---------------------------------------------------------------------------
class VirtualStudent:
    """True-skill based student."""

    def __init__(self, sid: int, true_skill: float, consistency: float, rng: random.Random):
        self.sid = sid
        self.true_skill = true_skill
        self.consistency = consistency
        self.rng = rng
        self.flow_rate = rng.uniform(0.8, 1.5)

    def solve_problem(self, problem: Dict[str, Any]) -> Tuple[bool, int, float]:
        """Returns (is_correct, solved_steps, answer_time)."""
        solved = 0
        total_time = 0.0
        for step in problem["steps"]:
            step_diff = step["enter_huddle"] * 10.0 + len(step["tags"]) * 3.0
            noise = self.rng.gauss(0.0, 5.0 / self.consistency)
            performance = self.true_skill + noise
            if performance >= step_diff:
                solved += 1
                total_time += self.rng.uniform(20.0, 60.0) / self.flow_rate
            else:
                total_time += self.rng.uniform(60.0, 120.0) / self.flow_rate
                break
        is_correct = solved == len(problem["steps"])
        return is_correct, solved, total_time


# ---------------------------------------------------------------------------
# Rating engine (pure dict, no DB)
# ---------------------------------------------------------------------------
def apply_rating_update(
    user: Dict[str, Any],
    problem: Dict[str, Any],
    is_correct: bool,
    solved_steps: int,
    answer_time: float,
) -> None:
    """In-place update of user dict."""
    # Problem rating
    barrier_val = 0.0
    for step in problem["steps"]:
        barrier_val += _barrier(step["enter_huddle"], problem["main_huddle"])
    barrier_val /= max(len(problem["steps"]), 1)

    prob_rating = _problem_rating(problem["difficulty"], barrier_val)
    prob_weight = _problem_weight(problem["difficulty"], barrier_val)
    time_fac = _time_factor(answer_time, user.get("flow_rate", 1.0), problem["main_huddle"])

    # Recent accuracy (simplified: use last 10 results)
    recent = user.get("recent_results", [])
    if len(recent) >= 10:
        recent.pop(0)
    recent.append(1.0 if is_correct else 0.0)
    user["recent_results"] = recent
    recent_acc = sum(recent) / len(recent) if recent else 0.5

    # Per-tag update
    tag_updates = []
    user_rating = user["rating"]
    k = _k_factor(user.get("lose_streak", 0))
    expected = _exp_score(user_rating, prob_rating)
    actual = 1.0 if is_correct else 0.0

    for tag in problem["tags"]:
        tag_stats = user["tags"].setdefault(tag, {"attempts": 0, "rating": DEFAULT_RATING})
        tag_stats["attempts"] += 1
        attempts = tag_stats["attempts"]
        tag_rating = tag_stats["rating"]

        conf = _confidence(user_rating, attempts, recent_acc, time_fac)
        delta = k * (actual - expected) * conf * prob_weight
        delta = max(-DELTA_MAX, min(DELTA_MAX, delta))

        tag_stats["rating"] = max(400.0, tag_rating + delta)
        tag_updates.append((tag, delta))

    # Update user rating (weighted average of tag deltas)
    if tag_updates:
        total_delta = sum(d for _, d in tag_updates)
        user["rating"] = max(400.0, user_rating + total_delta / len(tag_updates))

        # OVR = average of tag ratings
        tag_ratings = [user["tags"][t]["rating"] for t in user["tags"]]
        user["ovr"] = sum(tag_ratings) / len(tag_ratings)
        user["ovr_prev"] = user.get("ovr", DEFAULT_RATING)
    else:
        user["rating"] = max(400.0, user_rating + k * (actual - expected) * prob_weight)
        user["ovr"] = user["rating"]

    # Lose streak
    if is_correct:
        user["lose_streak"] = 0
    else:
        user["lose_streak"] = user.get("lose_streak", 0) + 1

    user["attempts"] = user.get("attempts", 0) + 1


# ---------------------------------------------------------------------------
# Single student simulation
# ---------------------------------------------------------------------------
def simulate_student(
    sid: int,
    n_problems: int,
    true_skill: float,
    consistency: float,
    seed: int,
    checkpoints: List[int] = None,
) -> Dict[str, Any]:
    """Simulate one student. Returns summary + checkpoint data."""
    rng = random.Random(seed)
    student = VirtualStudent(sid, true_skill, consistency, rng)

    user = {
        "rating": DEFAULT_RATING,
        "ovr": DEFAULT_RATING,
        "ovr_prev": DEFAULT_RATING,
        "lose_streak": 0,
        "tags": {},
        "recent_results": [],
        "attempts": 0,
        "flow_rate": student.flow_rate,
    }

    checkpoints = checkpoints or []
    checkpoint_data = []
    history_buffer = []  # Only store if needed for detailed analysis

    correct_count = 0
    for pid in range(n_problems):
        problem = generate_problem(pid, rng)
        is_correct, solved_steps, answer_time = student.solve_problem(problem)
        if is_correct:
            correct_count += 1

        apply_rating_update(user, problem, is_correct, solved_steps, answer_time)

        # Checkpoint recording
        for cp in checkpoints:
            if pid + 1 == cp:
                checkpoint_data.append({
                    "pid": pid + 1,
                    "rating": user["rating"],
                    "ovr": user["ovr"],
                    "accuracy_so_far": correct_count / (pid + 1),
                    "n_tags": len(user["tags"]),
                    "avg_tag_attempts": sum(t["attempts"] for t in user["tags"].values()) / len(user["tags"]) if user["tags"] else 0,
                })

    final_accuracy = correct_count / n_problems if n_problems > 0 else 0.0

    return {
        "sid": sid,
        "true_skill": true_skill,
        "consistency": consistency,
        "final_rating": user["rating"],
        "final_ovr": user["ovr"],
        "final_accuracy": final_accuracy,
        "n_tags": len(user["tags"]),
        "checkpoints": checkpoint_data,
        # Tag-level detail
        "tag_ratings": {t: s["rating"] for t, s in user["tags"].items()},
        "tag_attempts": {t: s["attempts"] for t, s in user["tags"].items()},
    }


# ---------------------------------------------------------------------------
# Batch simulation with progress
# ---------------------------------------------------------------------------
def run_simulation(
    n_students: int = 500,
    n_problems: int = 7000,
    checkpoints: List[int] = None,
    seed_offset: int = 0,
    progress_every: float = 0.1,
) -> List[Dict[str, Any]]:
    """Run batch simulation. Returns list of student summaries."""
    checkpoints = checkpoints or [100, 500, 1000, 2000, 3000, 5000, 7000]
    results = []

    start = time.time()
    next_progress = progress_every

    for i in range(n_students):
        # Generate student parameters
        rng = random.Random(i + seed_offset)
        true_skill = rng.uniform(40.0, 90.0)
        consistency = rng.uniform(0.6, 1.4)

        result = simulate_student(
            sid=i,
            n_problems=n_problems,
            true_skill=true_skill,
            consistency=consistency,
            seed=i + seed_offset + 100000,
            checkpoints=checkpoints,
        )
        results.append(result)

        # Progress
        frac = (i + 1) / n_students
        if frac >= next_progress:
            elapsed = time.time() - start
            eta = elapsed / frac * (1 - frac) if frac > 0 else 0
            print(f"  [{int(frac*100):3d}%] {i+1}/{n_students} students, "
                  f"elapsed={elapsed:.1f}s, ETA={eta:.1f}s")
            next_progress += progress_every

    total = time.time() - start
    print(f"\nDone: {n_students} students × {n_problems} problems in {total:.1f}s "
          f"({n_students*n_problems/total:.0f} problems/sec)")
    return results


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------
def analyze_results(results: List[Dict[str, Any]], checkpoints: List[int]) -> Dict[str, Any]:
    """Analyze convergence and correlation."""
    n = len(results)

    # Final stats
    final_ovrs = [r["final_ovr"] for r in results]
    final_ratings = [r["final_rating"] for r in results]
    final_accs = [r["final_accuracy"] for r in results]
    true_skills = [r["true_skill"] for r in results]

    def _mean(xs): return sum(xs) / len(xs) if xs else 0.0
    def _std(xs):
        m = _mean(xs)
        return math.sqrt(sum((x - m) ** 2 for x in xs) / len(xs)) if xs else 0.0

    # Correlation helper
    def _corr(x, y):
        mx, my = _mean(x), _mean(y)
        sx, sy = _std(x), _std(y)
        if sx == 0 or sy == 0:
            return 0.0
        return sum((a - mx) * (b - my) for a, b in zip(x, y)) / (len(x) * sx * sy)

    analysis = {
        "n_students": n,
        "final": {
            "ovr_mean": _mean(final_ovrs),
            "ovr_std": _std(final_ovrs),
            "ovr_min": min(final_ovrs) if final_ovrs else 0,
            "ovr_max": max(final_ovrs) if final_ovrs else 0,
            "rating_mean": _mean(final_ratings),
            "rating_std": _std(final_ratings),
            "accuracy_mean": _mean(final_accs),
            "accuracy_std": _std(final_accs),
        },
        "correlations": {
            "ovr_vs_true_skill": _corr(final_ovrs, true_skills),
            "rating_vs_true_skill": _corr(final_ratings, true_skills),
            "ovr_vs_accuracy": _corr(final_ovrs, final_accs),
        },
        "checkpoints": {},
    }

    # Per-checkpoint analysis
    for cp in checkpoints:
        cp_ovrs = []
        cp_accs = []
        for r in results:
            for c in r["checkpoints"]:
                if c["pid"] == cp:
                    cp_ovrs.append(c["ovr"])
                    cp_accs.append(c["accuracy_so_far"])
                    break
        if cp_ovrs:
            analysis["checkpoints"][cp] = {
                "ovr_mean": _mean(cp_ovrs),
                "ovr_std": _std(cp_ovrs),
                "accuracy_mean": _mean(cp_accs),
                "accuracy_std": _std(cp_accs),
                "ovr_vs_true_skill": _corr(cp_ovrs, true_skills),
            }

    return analysis


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="OVR Convergence Simulator v2")
    parser.add_argument("--students", type=int, default=500)
    parser.add_argument("--problems", type=int, default=7000)
    parser.add_argument("--checkpoints", type=str, default="100,500,1000,2000,3000,5000,7000")
    parser.add_argument("--output-dir", type=str, default="sim_data")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    checkpoints = [int(x) for x in args.checkpoints.split(",")]
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)

    print("=" * 60)
    print("OVR Convergence Simulator v2 (Optimized)")
    print("=" * 60)
    print(f"Students : {args.students}")
    print(f"Problems : {args.problems}")
    print(f"Checkpoints: {checkpoints}")
    print(f"Output   : {output_dir}")
    print("=" * 60)

    # Run
    results = run_simulation(
        n_students=args.students,
        n_problems=args.problems,
        checkpoints=checkpoints,
        seed_offset=args.seed,
    )

    # Analyze
    analysis = analyze_results(results, checkpoints)

    # Save results
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    pickle_path = output_dir / f"ovr_sim_{timestamp}.pkl"
    with open(pickle_path, "wb") as f:
        pickle.dump({"results": results, "analysis": analysis, "config": vars(args)}, f)
    print(f"\nSaved raw results: {pickle_path}")

    # Save analysis JSON
    json_path = output_dir / f"ovr_analysis_{timestamp}.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(analysis, f, indent=2, ensure_ascii=False)
    print(f"Saved analysis: {json_path}")

    # Print summary
    print("\n" + "=" * 60)
    print("ANALYSIS SUMMARY")
    print("=" * 60)
    f = analysis["final"]
    print(f"Final OVR      : {f['ovr_mean']:.1f} ± {f['ovr_std']:.1f} "
          f"(range: {f['ovr_min']:.0f} ~ {f['ovr_max']:.0f})")
    print(f"Final Rating   : {f['rating_mean']:.1f} ± {f['rating_std']:.1f}")
    print(f"Final Accuracy : {f['accuracy_mean']:.1%} ± {f['accuracy_std']:.1%}")
    print(f"Corr(OVR, Skill) : {analysis['correlations']['ovr_vs_true_skill']:.3f}")
    print(f"Corr(Rating,Skill): {analysis['correlations']['rating_vs_true_skill']:.3f}")
    print(f"Corr(OVR, Acc)   : {analysis['correlations']['ovr_vs_accuracy']:.3f}")
    print("\nCheckpoint Progress:")
    for cp in checkpoints:
        if cp in analysis["checkpoints"]:
            c = analysis["checkpoints"][cp]
            print(f"  {cp:5d} problems: OVR={c['ovr_mean']:.1f}±{c['ovr_std']:.1f}, "
                  f"Acc={c['accuracy_mean']:.1%}, r(skill)={c['ovr_vs_true_skill']:.3f}")

    # Convergence check
    print("\n" + "=" * 60)
    print("CONVERGENCE VERIFICATION")
    print("=" * 60)
    high_acc = [r for r in results if r["final_accuracy"] >= 0.85]
    if high_acc:
        high_ovrs = [r["final_ovr"] for r in high_acc]
        print(f"Students with ≥85% accuracy: {len(high_acc)} ({len(high_acc)/n*100:.1f}%)")
        print(f"  Their OVR: {_mean(high_ovrs):.1f} ± {_std(high_ovrs):.1f}")
        print(f"  Min OVR  : {min(high_ovrs):.0f}")
    else:
        print("No students reached ≥85% accuracy")

    high_acc_90 = [r for r in results if r["final_accuracy"] >= 0.90]
    if high_acc_90:
        high_ovrs_90 = [r["final_ovr"] for r in high_acc_90]
        print(f"Students with ≥90% accuracy: {len(high_acc_90)} ({len(high_acc_90)/n*100:.1f}%)")
        print(f"  Their OVR: {_mean(high_ovrs_90):.1f} ± {_std(high_ovrs_90):.1f}")
        print(f"  Min OVR  : {min(high_ovrs_90):.0f}")
    else:
        print("No students reached ≥90% accuracy")

    # Success criteria
    print("\n" + "=" * 60)
    print("SUCCESS CRITERIA")
    print("=" * 60)
    success = False
    if high_acc_90:
        mean_ovr_90 = _mean(high_ovrs_90)
        if mean_ovr_90 > 1800:
            print(f"✓ PASS: 90%+ accuracy students have OVR > 1800 (actual: {mean_ovr_90:.0f})")
            success = True
        else:
            print(f"✗ FAIL: 90%+ accuracy students OVR too low ({mean_ovr_90:.0f} < 1800)")
    else:
        print("✗ FAIL: No students reached 90% accuracy")

    if not success and high_acc:
        mean_ovr_85 = _mean(high_ovrs)
        if mean_ovr_85 > 1700:
            print(f"⚠ PARTIAL: 85%+ accuracy students have OVR > 1700 (actual: {mean_ovr_85:.0f})")
        else:
            print(f"✗ FAIL: 85%+ accuracy students OVR too low ({mean_ovr_85:.0f} < 1700)")

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
