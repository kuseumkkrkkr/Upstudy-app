#!/usr/bin/env python3
"""
Parameter Sensitivity Sweep for OVR Convergence Simulator v3
===============================================================
Runs the simulator across a grid of K, DELTA_MAX, and TAG_COUNT values,
collects metrics, and generates a comparison report + heatmap.

Usage:
    python simulator/parameter_sweep.py
"""

import sys
import os
import json
import time
import subprocess
import pickle
from pathlib import Path
from typing import Dict, List, Any, Tuple

import numpy as np

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SIMULATOR_SCRIPT = Path(__file__).with_name("ovr_convergence_simulator_v3.py")
OUT_DIR = Path("sim_data")
CHECKPOINTS = (500, 1000, 1500, 2000)

STUDENTS = 100
PROBLEMS = 2000
WORKERS = 4
SEED = 42

# Parameter grid (limit total runs to keep runtime reasonable)
K_VALUES = [16, 24, 32, 48, 64]
DELTA_MAX_VALUES = [25, 40, 50, 75, 100]
TAG_COUNT_VALUES = [3, 5, 10]

# Resume support
STATE_FILE = OUT_DIR / "parameter_sweep_state.json"


def run_simulation(k: float, delta_max: float, tag_count: int) -> Dict[str, Any]:
    """Run one simulation configuration and return parsed metrics."""
    cmd = [
        sys.executable,
        str(SIMULATOR_SCRIPT),
        "--students", str(STUDENTS),
        "--problems", str(PROBLEMS),
        "--checkpoints", ",".join(str(c) for c in CHECKPOINTS),
        "--output-dir", str(OUT_DIR),
        "--seed", str(SEED),
        "--workers", str(WORKERS),
        "--k", str(k),
        "--delta-max", str(delta_max),
        "--tag-count", str(tag_count),
    ]

    print(f"\n[RUN] K={k}  DELTA_MAX={delta_max}  TAG_COUNT={tag_count}")
    t0 = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    runtime = time.time() - t0

    if result.returncode not in (0, 1):
        # 0 = PASS, 1 = FAIL/PARTIAL – both are valid exits from the simulator
        print(f"  ERROR: unexpected return code {result.returncode}")
        print(result.stderr[-500:] if result.stderr else "")
        return {"error": True, "stdout": result.stdout, "stderr": result.stderr}

    # Parse stdout for key metrics
    stdout = result.stdout
    metrics = {
        "k": k,
        "delta_max": delta_max,
        "tag_count": tag_count,
        "runtime_sec": runtime,
        "error": False,
    }

    def _extract(line_prefix: str, cast=float):
        for line in stdout.splitlines():
            if line_prefix in line:
                # grab first numeric token after the prefix
                parts = line.split(":", 1)[-1].strip()
                # handle patterns like "1234.5 ± 67.8"
                for token in parts.replace("±", " ").replace(",", " ").replace("~", " ").split():
                    try:
                        return cast(token)
                    except ValueError:
                        continue
        return None

    metrics["ovr_mean"] = _extract("Final OVR", float)
    metrics["ovr_std"] = _extract("ovr_std", float)
    metrics["accuracy_mean"] = _extract("Final Accuracy", float)
    metrics["corr_ovr_skill"] = _extract("Corr(OVR,Skill)", float)
    metrics["corr_ovr_acc"] = _extract("Corr(OVR,Acc)", float)

    # 90%+ pass rate
    for line in stdout.splitlines():
        if "90%+ accuracy students:" in line:
            # e.g. "90%+ accuracy students: 12 (12.0%) -> OVR=1850"
            pct_str = line.split("(")[1].split("%")[0] if "(" in line else None
            if pct_str:
                metrics["pass_rate_90_pct"] = float(pct_str)
            ovr_str = line.split("-> OVR=")[-1].strip() if "-> OVR=" in line else None
            if ovr_str:
                metrics["pass_90_ovr"] = float(ovr_str)
            break

    # Also try to load the latest JSON analysis file for exact numbers
    json_files = sorted(OUT_DIR.glob("ovr_v3_analysis_*.json"), key=lambda p: p.stat().st_mtime)
    if json_files:
        latest = json_files[-1]
        try:
            with open(latest, "r", encoding="utf-8") as f:
                analysis = json.load(f)
            metrics["ovr_mean"] = analysis["final"]["ovr_mean"]
            metrics["ovr_std"] = analysis["final"]["ovr_std"]
            metrics["accuracy_mean"] = analysis["final"]["accuracy_mean"]
            metrics["corr_ovr_skill"] = analysis["correlations"]["ovr_vs_skill"]
            metrics["corr_ovr_acc"] = analysis["correlations"]["ovr_vs_accuracy"]
        except Exception as e:
            print(f"  (warn) could not parse {latest}: {e}")

    print(f"  Runtime: {runtime:.1f}s | OVR={metrics.get('ovr_mean')} ± {metrics.get('ovr_std')} | "
          f"r={metrics.get('corr_ovr_skill')} | pass90={metrics.get('pass_rate_90_pct')}%")
    return metrics


def load_state() -> List[Dict[str, Any]]:
    if STATE_FILE.exists():
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_state(results: List[Dict[str, Any]]) -> None:
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)


def key_for(k, delta_max, tag_count):
    return f"k={k}_d={delta_max}_t={tag_count}"


def generate_report(results: List[Dict[str, Any]]) -> str:
    lines = [
        "# OVR Convergence Simulator – Parameter Sensitivity Report",
        "",
        f"**Grid:** K ∈ {K_VALUES}, DELTA_MAX ∈ {DELTA_MAX_VALUES}, TAG_COUNT ∈ {TAG_COUNT_VALUES}",
        f"**Simulation size:** {STUDENTS} students × {PROBLEMS} problems",
        f"**Workers:** {WORKERS} | **Seed:** {SEED}",
        "",
        "## Results Table",
        "",
        "| K | DELTA_MAX | TAG_COUNT | Runtime (s) | OVR Mean | OVR Std | Acc Mean | OVR↔Skill | OVR↔Acc | 90%+ Pass Rate |",
        "|---|-----------|-----------|-------------|----------|---------|----------|-----------|---------|----------------|",
    ]

    for r in sorted(results, key=lambda x: (x["k"], x["delta_max"], x["tag_count"])):
        if r.get("error"):
            continue
        lines.append(
            f"| {r['k']} | {r['delta_max']} | {r['tag_count']} | "
            f"{r['runtime_sec']:.1f} | {r.get('ovr_mean', 'N/A')} | {r.get('ovr_std', 'N/A')} | "
            f"{r.get('accuracy_mean', 'N/A')} | {r.get('corr_ovr_skill', 'N/A')} | "
            f"{r.get('corr_ovr_acc', 'N/A')} | {r.get('pass_rate_90_pct', 'N/A')}% |"
        )

    lines += ["", "## Observations", ""]

    # Find best by correlation
    valid = [r for r in results if not r.get("error") and r.get("corr_ovr_skill") is not None]
    if valid:
        best_corr = max(valid, key=lambda r: r["corr_ovr_skill"])
        lines.append(
            f"- **Best OVR↔Skill correlation ({best_corr['corr_ovr_skill']:.3f}):** "
            f"K={best_corr['k']}, DELTA_MAX={best_corr['delta_max']}, TAG_COUNT={best_corr['tag_count']}"
        )

        fastest = min(valid, key=lambda r: r["runtime_sec"])
        lines.append(
            f"- **Fastest run ({fastest['runtime_sec']:.1f}s):** "
            f"K={fastest['k']}, DELTA_MAX={fastest['delta_max']}, TAG_COUNT={fastest['tag_count']}"
        )

        best_pass = max(valid, key=lambda r: r.get("pass_rate_90_pct", 0.0))
        lines.append(
            f"- **Highest 90%+ pass rate ({best_pass.get('pass_rate_90_pct', 0):.1f}%):** "
            f"K={best_pass['k']}, DELTA_MAX={best_pass['delta_max']}, TAG_COUNT={best_pass['tag_count']}"
        )

    lines.append("")
    return "\n".join(lines)


def generate_heatmap(results: List[Dict[str, Any]]) -> None:
    """Generate a heatmap PNG for K × DELTA_MAX, averaged across TAG_COUNT."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError as e:
        print(f"[WARN] matplotlib not available, skipping heatmap: {e}")
        return

    valid = [r for r in results if not r.get("error")]
    if not valid:
        print("[WARN] no valid results for heatmap")
        return

    # Build matrices for each metric, averaged over tag_count
    ks = sorted(set(r["k"] for r in valid))
    ds = sorted(set(r["delta_max"] for r in valid))

    def _mat(metric: str):
        mat = np.full((len(ks), len(ds)), np.nan)
        for i, k in enumerate(ks):
            for j, d in enumerate(ds):
                vals = [r[metric] for r in valid if r["k"] == k and r["delta_max"] == d and metric in r and r[metric] is not None]
                if vals:
                    mat[i, j] = np.mean(vals)
        return mat

    metrics_to_plot = [
        ("corr_ovr_skill", "OVR ↔ Skill Correlation"),
        ("ovr_mean", "Mean Final OVR"),
        ("pass_rate_90_pct", "90%+ Accuracy Pass Rate (%)"),
        ("runtime_sec", "Runtime (seconds)"),
    ]

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    fig.suptitle("OVR Simulator Parameter Sensitivity (K × DELTA_MAX, avg over TAG_COUNT)", fontsize=14)

    for ax, (metric, title) in zip(axes.flat, metrics_to_plot):
        mat = _mat(metric)
        im = ax.imshow(mat, aspect="auto", cmap="viridis", origin="lower")
        ax.set_xticks(range(len(ds)))
        ax.set_xticklabels(ds)
        ax.set_yticks(range(len(ks)))
        ax.set_yticklabels(ks)
        ax.set_xlabel("DELTA_MAX")
        ax.set_ylabel("K")
        ax.set_title(title)
        # Annotate cells
        for i in range(len(ks)):
            for j in range(len(ds)):
                if not np.isnan(mat[i, j]):
                    text = f"{mat[i, j]:.2f}" if metric != "runtime_sec" else f"{mat[i, j]:.1f}"
                    ax.text(j, i, text, ha="center", va="center", color="white", fontsize=8)
        plt.colorbar(im, ax=ax, shrink=0.8)

    plt.tight_layout()
    heatmap_path = OUT_DIR / "parameter_sweep_heatmap.png"
    plt.savefig(heatmap_path, dpi=150)
    plt.close()
    print(f"\n[SAVED] {heatmap_path}")


def main():
    OUT_DIR.mkdir(exist_ok=True)
    results = load_state()
    completed = {key_for(r["k"], r["delta_max"], r["tag_count"]) for r in results if not r.get("error")}

    total = len(K_VALUES) * len(DELTA_MAX_VALUES) * len(TAG_COUNT_VALUES)
    print(f"[SWEEP] Total combinations: {total}")
    print(f"[SWEEP] Already completed: {len(completed)}")

    for k in K_VALUES:
        for delta_max in DELTA_MAX_VALUES:
            for tag_count in TAG_COUNT_VALUES:
                key = key_for(k, delta_max, tag_count)
                if key in completed:
                    print(f"[SKIP] {key} (already done)")
                    continue
                result = run_simulation(k, delta_max, tag_count)
                results.append(result)
                save_state(results)

    # Generate report
    report = generate_report(results)
    report_path = OUT_DIR / "parameter_sweep_report.md"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\n[SAVED] {report_path}")

    # Generate heatmap
    generate_heatmap(results)

    print("\n[SWEEP COMPLETE]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
