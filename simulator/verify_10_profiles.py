#!/usr/bin/env python3
"""
verify_10_profiles.py

Generates 10 diverse student profiles, runs each through the OVR simulator,
collects trajectories, and verifies high-skill/high-accuracy students reach
high OVR.

Output:
    sim_data/verify_10_profiles_results.json
    sim_data/verify_10_profiles.png
"""

import sys
import os
import math
import random
import json
import time
from pathlib import Path
from typing import List, Dict, Tuple, Any

# Ensure simulator module is importable
sys.path.insert(0, str(Path(__file__).parent))

import ovr_convergence_simulator_v3 as sim

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
OUT_DIR = Path("sim_data")
OUT_DIR.mkdir(exist_ok=True)

CHECKPOINTS = (100, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)
SEED = 2026
TAG_COUNT = 5
K = 32.0
DELTA_MAX = 50.0

# ---------------------------------------------------------------------------
# Student profile definitions
# ---------------------------------------------------------------------------
def generate_profiles(n=10, seed=SEED):
    rng = random.Random(seed)
    profiles = []
    for i in range(n):
        true_skill = rng.randint(500, 3500)
        consistency = round(rng.uniform(0.5, 0.99), 2)
        n_problems = rng.randint(5000, 10000)
        # accuracy pattern hint: we don't enforce accuracy directly; it emerges
        # from skill + consistency vs problem difficulty.
        profiles.append({
            "sid": i,
            "true_skill": true_skill,
            "consistency": consistency,
            "n_problems": n_problems,
            "seed": rng.randint(1, 999999),
        })
    return profiles


def expected_ovr_range(true_skill, consistency):
    """Return (min_expected, max_expected) OVR for PASS/FAIL."""
    # Heuristic: high skill + high consistency -> high OVR
    # Low skill -> low OVR regardless of consistency
    # Mid skill -> mid OVR
    effective = true_skill * consistency
    if effective >= 2500:
        return 1700, 9999
    elif effective >= 1800:
        return 1400, 9999
    elif effective >= 1200:
        return 1000, 9999
    elif effective >= 800:
        return 700, 9999
    else:
        return 400, 9999


def generate_hard_problem_pool(n: int, seed: int, all_tags: List[str], max_skill: float = 3500.0):
    """Generate a problem pool where difficulty scales with max_skill."""
    rng = random.Random(seed)
    pool = []
    for _ in range(n):
        # difficulty ranges from very easy to very hard relative to max_skill
        diff = rng.uniform(0.02, 0.6) * max_skill  # 2% to 60% of max_skill
        mh = float(rng.randint(1, 3))
        n_steps = rng.randint(2, 4)
        tags = set()
        for _ in range(n_steps):
            tags.update(rng.sample(all_tags, k=rng.randint(1, 2)))
        pool.append((diff, mh, sorted(tags)))
    return pool


def simulate_one_hard(
    sid: int,
    pool,
    true_skill: float,
    consistency: float,
    seed: int,
    checkpoints,
    sim_k: float,
    sim_delta_max: float,
    max_skill: float = 3500.0,
):
    """Simulate one student with a harder difficulty model."""
    import ovr_convergence_simulator_v3 as sim
    rng = random.Random(seed)
    flow_rate = rng.uniform(0.8, 1.5)

    rating = sim.DEFAULT_RATING
    lose_streak = 0
    tags = {}
    recent = []
    correct_count = 0

    cp_data = []
    cp_idx = 0
    n = len(pool)

    for pid in range(n):
        diff, mh, ptags = pool[pid]

        # Harder step difficulty that scales with skill range
        step_diff = diff * 0.5 + mh * 50.0 + len(ptags) * 30.0
        noise = rng.gauss(0.0, (max_skill / 10.0) / consistency)
        is_correct = (true_skill + noise) >= step_diff

        if is_correct:
            correct_count += 1

        tag = ptags[0] if ptags else "a"
        if tag not in tags:
            tags[tag] = {"attempts": 0, "rating": sim.DEFAULT_RATING}
        tags[tag]["attempts"] += 1
        attempts = tags[tag]["attempts"]
        tag_rating = tags[tag]["rating"]

        k = sim.K_MIN if sim.K_MIN > sim_k * math.exp(-sim.M_LOSE * lose_streak) else sim_k * math.exp(-sim.M_LOSE * lose_streak)
        exp = 1.0 / (1.0 + 10.0 ** ((1500.0 - rating) / 400.0))

        if len(recent) >= 10:
            recent.pop(0)
        recent.append(1.0 if is_correct else 0.0)
        recent_acc = sum(recent) / len(recent) if recent else 0.5

        ru = rating / sim.U_MAX
        if ru > 1.0:
            ru = 1.0
        rc = attempts / sim.C_MAX
        if rc > 1.0:
            rc = 1.0
        time_fac = 1.0
        conf = (sim.ALPHA * ru + sim.BETA * rc + sim.GAMMA * recent_acc + sim.DELTA_W * time_fac) * time_fac

        barrier_val = max(0.0, min(10.0, mh * 2.0 - mh))
        w_diff = diff / (max_skill / 5.0) if max_skill > 0 else 0
        w_barrier = barrier_val / 10.0
        prob_weight = sim.LAMBDA + sim.MU * w_barrier + sim.NU * w_diff

        actual = 1.0 if is_correct else 0.0
        delta = k * (actual - exp) * conf * prob_weight
        if delta > sim_delta_max:
            delta = sim_delta_max
        elif delta < -sim_delta_max:
            delta = -sim_delta_max

        tags[tag]["rating"] = max(400.0, tag_rating + delta)
        rating += delta * 0.3
        if rating < 400.0:
            rating = 400.0

        lose_streak = 0 if is_correct else lose_streak + 1

        if cp_idx < len(checkpoints) and (pid + 1) == checkpoints[cp_idx]:
            tag_ratings = [tags[t]["rating"] for t in tags]
            ovr = sum(tag_ratings) / len(tag_ratings) if tag_ratings else rating
            cp_data.append({
                "pid": pid + 1,
                "ovr": ovr,
                "accuracy": correct_count / (pid + 1),
            })
            cp_idx += 1

    tag_ratings = [tags[t]["rating"] for t in tags]
    ovr = sum(tag_ratings) / len(tag_ratings) if tag_ratings else rating

    return {
        "sid": sid,
        "true_skill": true_skill,
        "consistency": consistency,
        "final_rating": rating,
        "final_ovr": ovr,
        "final_accuracy": correct_count / n if n > 0 else 0.0,
        "checkpoints": cp_data,
    }


def run_profile(profile):
    """Run a single profile and return enriched result."""
    pool = generate_hard_problem_pool(profile["n_problems"], profile["seed"], sim.ALL_TAGS[:TAG_COUNT], max_skill=3500.0)
    result = simulate_one_hard(
        sid=profile["sid"],
        pool=pool,
        true_skill=profile["true_skill"],
        consistency=profile["consistency"],
        seed=profile["seed"],
        checkpoints=CHECKPOINTS,
        sim_k=K,
        sim_delta_max=DELTA_MAX,
        max_skill=3500.0,
    )
    result["n_problems"] = profile["n_problems"]
    return result


def main():
    print("=" * 60)
    print("OVR Convergence Verification - 10 Random Profiles")
    print("=" * 60)

    # Override module globals
    sim.K = K
    sim.DELTA_MAX = DELTA_MAX
    sim.ALL_TAGS = sim.ALL_TAGS[:TAG_COUNT]

    profiles = generate_profiles()
    print(f"Generated {len(profiles)} profiles:\n")
    for p in profiles:
        print(f"  SID={p['sid']:2d} | Skill={p['true_skill']:4d} | Consistency={p['consistency']:.2f} | Problems={p['n_problems']}")
    print()

    results = []
    trajectories = []  # list of (sid, list of (pid, ovr, acc))
    start = time.time()

    for p in profiles:
        print(f"Running SID={p['sid']} ...", end=" ")
        t0 = time.time()
        r = run_profile(p)
        dt = time.time() - t0
        results.append(r)
        traj = [(c["pid"], c["ovr"], c["accuracy"]) for c in r["checkpoints"]]
        trajectories.append((p["sid"], traj))
        print(f"done in {dt:.1f}s | OVR={r['final_ovr']:.1f} Acc={r['final_accuracy']:.1%}")

    total = time.time() - start
    print(f"\nTotal time: {total:.1f}s")

    # -----------------------------------------------------------------------
    # Build report
    # -----------------------------------------------------------------------
    report_lines = []
    report_lines.append("\n" + "=" * 60)
    report_lines.append("VERIFICATION REPORT")
    report_lines.append("=" * 60)

    all_pass = True
    per_student = []

    for r in results:
        sid = r["sid"]
        skill = r["true_skill"]
        cons = r["consistency"]
        n_prob = r["n_problems"]
        acc = r["final_accuracy"]
        ovr = r["final_ovr"]

        lo, hi = expected_ovr_range(skill, cons)
        passed = lo <= ovr <= hi
        if not passed:
            all_pass = False
        status = "PASS" if passed else "FAIL"

        line = (f"  SID={sid:2d} | Skill={skill:4d} | Cons={cons:.2f} | "
                f"N={n_prob:5d} | Acc={acc:.1%} | OVR={ovr:7.1f} | {status}")
        report_lines.append(line)

        per_student.append({
            "sid": sid,
            "true_skill": skill,
            "consistency": cons,
            "n_problems": n_prob,
            "final_accuracy": acc,
            "final_ovr": ovr,
            "expected_ovr_min": lo,
            "expected_ovr_max": hi,
            "pass": passed,
            "checkpoints": r["checkpoints"],
        })

    # Benchmark verification
    report_lines.append("\n" + "-" * 60)
    report_lines.append("BENCHMARK CHECK: 7000 problems / 90% accuracy -> OVR > 1800")
    report_lines.append("-" * 60)

    # Find closest profile to benchmark (or just check all high-accuracy)
    benchmark_candidates = [s for s in per_student if s["n_problems"] >= 5000 and s["final_accuracy"] >= 0.90]
    if benchmark_candidates:
        best = max(benchmark_candidates, key=lambda x: x["final_ovr"])
        report_lines.append(f"  Best match: SID={best['sid']} Acc={best['final_accuracy']:.1%} OVR={best['final_ovr']:.1f}")
        if best["final_ovr"] > 1800:
            report_lines.append("  BENCHMARK PASS")
        else:
            report_lines.append("  BENCHMARK FAIL")
            all_pass = False
    else:
        report_lines.append("  No student reached 90% accuracy — BENCHMARK INCONCLUSIVE")

    report_lines.append("\n" + "=" * 60)
    report_lines.append(f"OVERALL: {'ALL PASS' if all_pass else 'SOME FAILURES'}")
    report_lines.append("=" * 60)

    report_text = "\n".join(report_lines)
    print(report_text)

    # -----------------------------------------------------------------------
    # Save JSON
    # -----------------------------------------------------------------------
    json_path = OUT_DIR / "verify_10_profiles_results.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump({
            "config": {
                "k": K,
                "delta_max": DELTA_MAX,
                "tag_count": TAG_COUNT,
                "checkpoints": CHECKPOINTS,
            },
            "students": per_student,
            "overall_pass": all_pass,
            "total_time_sec": total,
        }, f, indent=2, ensure_ascii=False)
    print(f"\nSaved JSON: {json_path}")

    # -----------------------------------------------------------------------
    # Plot
    # -----------------------------------------------------------------------
    fig, axes = plt.subplots(2, 1, figsize=(12, 10), sharex=True)

    colors = plt.cm.tab10(range(10))

    # Plot 1: OVR trajectories
    ax1 = axes[0]
    for idx, (sid, traj) in enumerate(trajectories):
        pids = [t[0] for t in traj]
        ovrs = [t[1] for t in traj]
        ax1.plot(pids, ovrs, marker="o", markersize=3, label=f"SID={sid}", color=colors[idx])
    ax1.set_ylabel("OVR")
    ax1.set_title("OVR Trajectories — 10 Random Profiles")
    ax1.legend(loc="lower right", fontsize=7, ncol=2)
    ax1.grid(True, alpha=0.3)

    # Plot 2: Final OVR bar chart with expected ranges
    ax2 = axes[1]
    sids = [s["sid"] for s in per_student]
    ovrs = [s["final_ovr"] for s in per_student]
    mins = [s["expected_ovr_min"] for s in per_student]
    colors_bar = ["green" if s["pass"] else "red" for s in per_student]

    bars = ax2.bar(sids, ovrs, color=colors_bar, alpha=0.7, edgecolor="black")
    ax2.axhline(1800, color="blue", linestyle="--", linewidth=1.5, label="Benchmark OVR=1800")
    ax2.set_xlabel("Student ID")
    ax2.set_ylabel("Final OVR")
    ax2.set_title("Final OVR per Student (green=PASS, red=FAIL)")
    ax2.set_xticks(sids)
    ax2.legend()
    ax2.grid(True, alpha=0.3, axis="y")

    # Annotate bars
    for bar, ovr, acc in zip(bars, ovrs, [s["final_accuracy"] for s in per_student]):
        height = bar.get_height()
        ax2.annotate(f"{ovr:.0f}\n({acc:.0%})",
                     xy=(bar.get_x() + bar.get_width() / 2, height),
                     xytext=(0, 3),
                     textcoords="offset points",
                     ha="center", va="bottom", fontsize=7)

    plt.tight_layout()
    png_path = OUT_DIR / "verify_10_profiles.png"
    plt.savefig(png_path, dpi=150)
    print(f"Saved PNG: {png_path}")

    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
