#!/usr/bin/env python3
"""
OVR Convergence Simulator v3 - Ultra Optimized
================================================
Pre-generates problem pool, uses minimal tag set, no per-problem I/O.

Run:
    python simulator/ovr_convergence_simulator_v3.py
"""

import sys, os, math, random, time, json, pickle, argparse
from pathlib import Path
from typing import List, Dict, Tuple, Any
from concurrent import futures

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
K = 32.0
K_MIN = 12.0
DELTA_MAX = 50.0
U_MAX = 2400.0
C_MAX = 30.0
M_LOSE = 0.12
ALPHA = 0.35
BETA = 0.25
GAMMA = 0.25
DELTA_W = 0.15
LAMBDA = 0.4
MU = 0.3
NU = 0.3
DEFAULT_RATING = 1200.0

ALL_TAGS = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]  # up to 10 tags available


# ---------------------------------------------------------------------------
# Problem pool (pre-generated)
# ---------------------------------------------------------------------------
def generate_problem_pool(n: int, seed: int, all_tags: List[str]) -> List[Tuple[float, float, List[str]]]:
    """Pre-generate problem pool. Returns list of (difficulty, main_huddle, tags)."""
    rng = random.Random(seed)
    pool = []
    for _ in range(n):
        diff = rng.uniform(3.0, 18.0)
        mh = float(rng.randint(1, 3))
        n_steps = rng.randint(2, 4)
        tags = set()
        for _ in range(n_steps):
            tags.update(rng.sample(all_tags, k=rng.randint(1, 2)))
        pool.append((diff, mh, sorted(tags)))
    return pool


# ---------------------------------------------------------------------------
# Rating engine (inline, no function call overhead)
# ---------------------------------------------------------------------------
def simulate_one(
    sid: int,
    pool: List[Tuple[float, float, List[str]]],
    true_skill: float,
    consistency: float,
    seed: int,
    checkpoints: Tuple[int, ...],
    sim_k: float,
    sim_delta_max: float,
) -> Dict[str, Any]:
    """Simulate one student. Inline for speed."""
    rng = random.Random(seed)
    flow_rate = rng.uniform(0.8, 1.5)

    rating = DEFAULT_RATING
    lose_streak = 0
    tags = {}  # tag -> {attempts: int, rating: float}
    recent = []  # last 10 results
    correct_count = 0

    cp_data = []
    cp_idx = 0
    n = len(pool)

    for pid in range(n):
        diff, mh, ptags = pool[pid]

        # Student solves (simplified: threshold check)
        step_diff = mh * 10.0 + len(ptags) * 3.0
        noise = rng.gauss(0.0, 5.0 / consistency)
        is_correct = (true_skill + noise) >= step_diff

        if is_correct:
            correct_count += 1

        # Rating update (track per-tag rating properly)
        tag = ptags[0] if ptags else "a"
        if tag not in tags:
            tags[tag] = {"attempts": 0, "rating": DEFAULT_RATING}
        tags[tag]["attempts"] += 1
        attempts = tags[tag]["attempts"]
        tag_rating = tags[tag]["rating"]

        k = K_MIN if K_MIN > sim_k * math.exp(-M_LOSE * lose_streak) else sim_k * math.exp(-M_LOSE * lose_streak)
        exp = 1.0 / (1.0 + 10.0 ** ((1500.0 - rating) / 400.0))

        # Recent accuracy
        if len(recent) >= 10:
            recent.pop(0)
        recent.append(1.0 if is_correct else 0.0)
        recent_acc = sum(recent) / len(recent) if recent else 0.5

        # Confidence
        ru = rating / U_MAX
        if ru > 1.0:
            ru = 1.0
        rc = attempts / C_MAX
        if rc > 1.0:
            rc = 1.0
        time_fac = 1.0  # simplified
        conf = (ALPHA * ru + BETA * rc + GAMMA * recent_acc + DELTA_W * time_fac) * time_fac

        # Barrier & weight (simplified)
        barrier_val = max(0.0, min(10.0, mh * 2.0 - mh))
        w_diff = diff / 20.0
        w_barrier = barrier_val / 10.0
        prob_weight = LAMBDA + MU * w_barrier + NU * w_diff

        actual = 1.0 if is_correct else 0.0
        delta = k * (actual - exp) * conf * prob_weight
        if delta > sim_delta_max:
            delta = sim_delta_max
        elif delta < -sim_delta_max:
            delta = -sim_delta_max

        # Update tag rating
        tags[tag]["rating"] = max(400.0, tag_rating + delta)

        rating += delta * 0.3
        if rating < 400.0:
            rating = 400.0

        lose_streak = 0 if is_correct else lose_streak + 1

        # Checkpoint
        if cp_idx < len(checkpoints) and (pid + 1) == checkpoints[cp_idx]:
            tag_ratings = [tags[t]["rating"] for t in tags]
            ovr = sum(tag_ratings) / len(tag_ratings) if tag_ratings else rating
            cp_data.append({
                "pid": pid + 1,
                "ovr": ovr,
                "accuracy": correct_count / (pid + 1),
            })
            cp_idx += 1

    # Final OVR = average of tag ratings
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


# ---------------------------------------------------------------------------
# Batch runner
# ---------------------------------------------------------------------------
def run_batch(
    n_students: int,
    pool: List[Tuple[float, float, List[str]]],
    checkpoints: Tuple[int, ...],
    seed_offset: int,
    max_workers: int = 4,
    sim_k: float = 32.0,
    sim_delta_max: float = 50.0,
) -> List[Dict[str, Any]]:
    """Run simulation for all students."""
    # Generate student params
    rng = random.Random(seed_offset)
    students = []
    for i in range(n_students):
        students.append((
            i,
            rng.uniform(40.0, 90.0),   # true_skill
            rng.uniform(0.6, 1.4),       # consistency
            i + seed_offset + 100000,    # seed
        ))

    start = time.time()
    results = []

    if max_workers > 1:
        with futures.ProcessPoolExecutor(max_workers=max_workers) as exe:
            futs = {
                exe.submit(simulate_one, sid, pool, ts, cons, seed, checkpoints, sim_k, sim_delta_max): sid
                for sid, ts, cons, seed in students
            }
            done_count = 0
            for fut in futures.as_completed(futs):
                results.append(fut.result())
                done_count += 1
                if done_count % 50 == 0 or done_count == n_students:
                    elapsed = time.time() - start
                    print(f"  [{done_count}/{n_students}] {elapsed:.1f}s")
    else:
        for sid, ts, cons, seed in students:
            results.append(simulate_one(sid, pool, ts, cons, seed, checkpoints, sim_k, sim_delta_max))
            if (sid + 1) % 50 == 0 or sid == n_students - 1:
                elapsed = time.time() - start
                print(f"  [{sid+1}/{n_students}] {elapsed:.1f}s")

    total = time.time() - start
    print(f"\nDone: {n_students} students x {len(pool)} problems in {total:.1f}s")
    return results


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------
def analyze(results: List[Dict[str, Any]], checkpoints: Tuple[int, ...]) -> Dict[str, Any]:
    n = len(results)
    ovrs = [r["final_ovr"] for r in results]
    ratings = [r["final_rating"] for r in results]
    accs = [r["final_accuracy"] for r in results]
    skills = [r["true_skill"] for r in results]

    def mean(xs):
        return sum(xs) / len(xs) if xs else 0.0

    def std(xs):
        m = mean(xs)
        v = sum((x - m) ** 2 for x in xs) / len(xs) if xs else 0.0
        return math.sqrt(v)

    def corr(x, y):
        mx, my = mean(x), mean(y)
        sx, sy = std(x), std(y)
        if sx == 0 or sy == 0:
            return 0.0
        return sum((a - mx) * (b - my) for a, b in zip(x, y)) / (len(x) * sx * sy)

    analysis = {
        "n_students": n,
        "final": {
            "ovr_mean": mean(ovrs),
            "ovr_std": std(ovrs),
            "ovr_min": min(ovrs) if ovrs else 0,
            "ovr_max": max(ovrs) if ovrs else 0,
            "rating_mean": mean(ratings),
            "accuracy_mean": mean(accs),
            "accuracy_std": std(accs),
        },
        "correlations": {
            "ovr_vs_skill": corr(ovrs, skills),
            "rating_vs_skill": corr(ratings, skills),
            "ovr_vs_accuracy": corr(ovrs, accs),
        },
        "checkpoints": {},
    }

    for cp in checkpoints:
        cp_ovrs = []
        cp_accs = []
        for r in results:
            for c in r["checkpoints"]:
                if c["pid"] == cp:
                    cp_ovrs.append(c["ovr"])
                    cp_accs.append(c["accuracy"])
                    break
        if cp_ovrs:
            analysis["checkpoints"][cp] = {
                "ovr_mean": mean(cp_ovrs),
                "ovr_std": std(cp_ovrs),
                "accuracy_mean": mean(cp_accs),
                "ovr_vs_skill": corr(cp_ovrs, skills),
            }

    return analysis


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--students", type=int, default=500)
    parser.add_argument("--problems", type=int, default=7000)
    parser.add_argument("--checkpoints", type=str, default="100,500,1000,2000,3000,5000,7000")
    parser.add_argument("--output-dir", type=str, default="sim_data")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--k", type=float, default=32.0)
    parser.add_argument("--delta-max", type=float, default=50.0)
    parser.add_argument("--tag-count", type=int, default=5)
    args = parser.parse_args()

    # Inject parameter overrides into module-level globals
    global K, DELTA_MAX, ALL_TAGS
    K = args.k
    DELTA_MAX = args.delta_max
    ALL_TAGS = ALL_TAGS[:args.tag_count]

    checkpoints = tuple(int(x) for x in args.checkpoints.split(","))
    out_dir = Path(args.output_dir)
    out_dir.mkdir(exist_ok=True)

    print("=" * 60)
    print("OVR Convergence Simulator v3 (Ultra Optimized)")
    print("=" * 60)
    print(f"Students : {args.students}")
    print(f"Problems : {args.problems}")
    print(f"Workers  : {args.workers}")
    print(f"Output   : {out_dir}")
    print("=" * 60)

    # Pre-generate problem pool
    print("Generating problem pool...")
    t0 = time.time()
    pool = generate_problem_pool(args.problems, args.seed, ALL_TAGS)
    print(f"  Pool generated: {len(pool)} problems in {time.time()-t0:.2f}s")

    # Run
    results = run_batch(args.students, pool, checkpoints, args.seed, args.workers, sim_k=args.k, sim_delta_max=args.delta_max)

    # Analyze
    analysis = analyze(results, checkpoints)

    # Save
    ts = time.strftime("%Y%m%d_%H%M%S")
    pkl_path = out_dir / f"ovr_v3_{ts}.pkl"
    with open(pkl_path, "wb") as f:
        pickle.dump({"results": results, "analysis": analysis, "config": vars(args)}, f)
    print(f"\nSaved: {pkl_path}")

    json_path = out_dir / f"ovr_v3_analysis_{ts}.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(analysis, f, indent=2, ensure_ascii=False)
    print(f"Saved: {json_path}")

    # Summary
    f = analysis["final"]
    print("\n" + "=" * 60)
    print("RESULTS")
    print("=" * 60)
    print(f"Final OVR      : {f['ovr_mean']:.1f} ± {f['ovr_std']:.1f} "
          f"(range: {f['ovr_min']:.0f} ~ {f['ovr_max']:.0f})")
    print(f"Final Rating   : {f['rating_mean']:.1f}")
    print(f"Final Accuracy : {f['accuracy_mean']:.1%} ± {f['accuracy_std']:.1%}")
    print(f"Corr(OVR,Skill): {analysis['correlations']['ovr_vs_skill']:.3f}")
    print(f"Corr(OVR,Acc)  : {analysis['correlations']['ovr_vs_accuracy']:.3f}")

    print("\nCheckpoints:")
    for cp in checkpoints:
        if cp in analysis["checkpoints"]:
            c = analysis["checkpoints"][cp]
            print(f"  {cp:5d}: OVR={c['ovr_mean']:.1f}±{c['ovr_std']:.1f}, "
                  f"Acc={c['accuracy_mean']:.1%}, r={c['ovr_vs_skill']:.3f}")

    # Verification
    def _mean(xs):
        return sum(xs) / len(xs) if xs else 0.0

    print("\n" + "=" * 60)
    print("VERIFICATION")
    print("=" * 60)
    high_90 = [r for r in results if r["final_accuracy"] >= 0.90]
    if high_90:
        m = _mean([r["final_ovr"] for r in high_90])
        print(f"90%+ accuracy students: {len(high_90)} ({len(high_90)/len(results)*100:.1f}%) -> OVR={m:.0f}")
        if m > 1800:
            print("PASS: OVR > 1800")
            return 0
        else:
            print(f"FAIL: OVR {m:.0f} < 1800")
    else:
        print("FAIL: No students reached 90% accuracy")

    high_85 = [r for r in results if r["final_accuracy"] >= 0.85]
    if high_85:
        m = _mean([r["final_ovr"] for r in high_85])
        print(f"85%+ accuracy students: {len(high_85)} ({len(high_85)/len(results)*100:.1f}%) -> OVR={m:.0f}")
        if m > 1700:
            print("PARTIAL PASS: OVR > 1700")
        else:
            print(f"FAIL: OVR {m:.0f} < 1700")
    return 1


if __name__ == "__main__":
    sys.exit(main())
