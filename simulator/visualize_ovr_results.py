"""
OVR Convergence Simulation Visualization
Generates comprehensive charts from simulation results.
"""

import json
import pickle
import sys
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def load_latest_data(output_dir: Path):
    """Find and load the latest simulation results."""
    pkl_files = sorted(output_dir.glob("ovr_v3_*.pkl"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not pkl_files:
        raise FileNotFoundError(f"No .pkl files found in {output_dir}")
    
    latest_pkl = pkl_files[0]
    latest_json = latest_pkl.with_suffix('.json').name.replace('ovr_v3_', 'ovr_v3_analysis_')
    latest_json_path = output_dir / latest_json
    
    with open(latest_pkl, 'rb') as f:
        data = pickle.load(f)
    
    with open(latest_json_path, 'r') as f:
        analysis = json.load(f)
    
    return data['results'], analysis, latest_pkl.stem


def plot_ovr_convergence(results, analysis, save_path):
    """Figure 1: OVR convergence over problems solved."""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('OVR Convergence Analysis (500 Students × 7000 Problems)', fontsize=14, fontweight='bold')
    
    checkpoints = analysis['checkpoints']
    cp_keys = sorted(checkpoints.keys(), key=int)
    cp_ints = [int(k) for k in cp_keys]
    
    # --- Subplot 1: Mean OVR with std bands ---
    ax = axes[0, 0]
    means = [checkpoints[k]['ovr_mean'] for k in cp_keys]
    stds = [checkpoints[k]['ovr_std'] for k in cp_keys]
    
    ax.plot(cp_ints, means, 'b-o', linewidth=2, markersize=6, label='Mean OVR')
    ax.fill_between(cp_ints, 
                    [m - s for m, s in zip(means, stds)],
                    [m + s for m, s in zip(means, stds)],
                    alpha=0.3, color='blue', label='±1 StdDev')
    ax.axhline(y=1200, color='gray', linestyle='--', alpha=0.5, label='Default (1200)')
    ax.axhline(y=1800, color='green', linestyle='--', alpha=0.5, label='Pass Threshold (1800)')
    ax.set_xlabel('Problems Solved')
    ax.set_ylabel('OVR')
    ax.set_title('OVR Mean Convergence')
    ax.legend(loc='lower right', fontsize=8)
    ax.grid(True, alpha=0.3)
    
    # --- Subplot 2: OVR StdDev growth ---
    ax = axes[0, 1]
    ax.plot(cp_ints, stds, 'r-s', linewidth=2, markersize=6)
    ax.set_xlabel('Problems Solved')
    ax.set_ylabel('OVR Standard Deviation')
    ax.set_title('OVR Dispersion Growth (Student Discrimination)')
    ax.grid(True, alpha=0.3)
    
    # --- Subplot 3: Correlation improvement ---
    ax = axes[1, 0]
    corrs = [checkpoints[k]['ovr_vs_skill'] for k in cp_keys]
    ax.plot(cp_ints, corrs, 'g-^', linewidth=2, markersize=6)
    ax.set_xlabel('Problems Solved')
    ax.set_ylabel('Correlation (OVR vs True Skill)')
    ax.set_title('Skill Estimation Accuracy')
    ax.set_ylim(0.5, 0.8)
    ax.grid(True, alpha=0.3)
    
    # --- Subplot 4: Sample student trajectories ---
    ax = axes[1, 1]
    sample_sids = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450]
    colors = plt.cm.tab10(np.linspace(0, 1, len(sample_sids)))
    
    for idx, sid in enumerate(sample_sids):
        r = results[sid]
        cps = r['checkpoints']
        probs = [cp['pid'] for cp in cps]
        ovrs = [cp['ovr'] for cp in cps]
        ax.plot(probs, ovrs, color=colors[idx], alpha=0.7, linewidth=1.5,
                label=f"Skill={r['true_skill']:.0f}" if idx < 5 else None)
    
    ax.set_xlabel('Problems Solved')
    ax.set_ylabel('OVR')
    ax.set_title('Sample Student Trajectories (10 students)')
    ax.legend(loc='lower right', fontsize=7)
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  Saved: {save_path}")


def plot_ovr_distribution(results, analysis, save_path):
    """Figure 2: Final OVR distribution and skill correlation."""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('Final OVR Distribution & Skill Correlation', fontsize=14, fontweight='bold')
    
    ovrs = [r['final_ovr'] for r in results]
    skills = [r['true_skill'] for r in results]
    accs = [r['final_accuracy'] for r in results]
    
    # --- Subplot 1: OVR histogram ---
    ax = axes[0, 0]
    ax.hist(ovrs, bins=40, color='steelblue', edgecolor='white', alpha=0.8)
    ax.axvline(x=np.mean(ovrs), color='red', linestyle='--', linewidth=2, label=f'Mean={np.mean(ovrs):.0f}')
    ax.axvline(x=1800, color='green', linestyle='--', alpha=0.5, label='Pass=1800')
    ax.set_xlabel('Final OVR')
    ax.set_ylabel('Number of Students')
    ax.set_title(f'OVR Distribution (σ={np.std(ovrs):.0f}, range={min(ovrs):.0f}~{max(ovrs):.0f})')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # --- Subplot 2: OVR vs True Skill scatter ---
    ax = axes[0, 1]
    ax.scatter(skills, ovrs, alpha=0.5, s=20, c='steelblue')
    z = np.polyfit(skills, ovrs, 1)
    p = np.poly1d(z)
    ax.plot(sorted(skills), p(sorted(skills)), "r--", linewidth=2, 
            label=f'r = {analysis["correlations"]["ovr_vs_skill"]:.3f}')
    ax.set_xlabel('True Skill')
    ax.set_ylabel('Final OVR')
    ax.set_title('OVR vs True Skill')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # --- Subplot 3: OVR vs Accuracy scatter ---
    ax = axes[1, 0]
    ax.scatter(accs, ovrs, alpha=0.5, s=20, c='darkgreen')
    z = np.polyfit(accs, ovrs, 1)
    p = np.poly1d(z)
    ax.plot(sorted(accs), p(sorted(accs)), "r--", linewidth=2,
            label=f'r = {analysis["correlations"]["ovr_vs_accuracy"]:.3f}')
    ax.set_xlabel('Final Accuracy')
    ax.set_ylabel('Final OVR')
    ax.set_title('OVR vs Accuracy')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # --- Subplot 4: Skill vs Accuracy ---
    ax = axes[1, 1]
    ax.scatter(skills, accs, alpha=0.5, s=20, c='purple')
    ax.set_xlabel('True Skill')
    ax.set_ylabel('Final Accuracy')
    ax.set_title('True Skill vs Accuracy')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  Saved: {save_path}")


def plot_tag_distribution(results, save_path):
    """Figure 3: Per-tag rating distribution."""
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # Extract final tag ratings from a sample of students
    # Since we don't store per-tag ratings in checkpoints, we'll show skill vs OVR by skill tier
    skills = [r['true_skill'] for r in results]
    ovrs = [r['final_ovr'] for r in results]
    
    # Create skill tiers
    tiers = [(0, 1500, 'Low (0-1500)'), (1500, 2000, 'Medium (1500-2000)'), 
             (2000, 2500, 'High (2000-2500)'), (2500, 3500, 'Elite (2500+)')]
    
    colors = ['#e74c3c', '#f39c12', '#27ae60', '#3498db']
    positions = []
    data_by_tier = []
    labels = []
    
    for i, (low, high, label) in enumerate(tiers):
        tier_ovrs = [ovr for skill, ovr in zip(skills, ovrs) if low <= skill < high]
        if tier_ovrs:
            positions.append(i)
            data_by_tier.append(tier_ovrs)
            labels.append(f"{label}\nn={len(tier_ovrs)}")
    
    bp = ax.boxplot(data_by_tier, positions=positions, widths=0.6, patch_artist=True,
                    showmeans=True, meanline=True)
    
    for patch, color in zip(bp['boxes'], colors[:len(positions)]):
        patch.set_facecolor(color)
        patch.set_alpha(0.6)
    
    ax.set_xticks(positions)
    ax.set_xticklabels(labels)
    ax.set_ylabel('Final OVR')
    ax.set_title('OVR Distribution by True Skill Tier')
    ax.axhline(y=1800, color='green', linestyle='--', alpha=0.5, label='Pass Threshold')
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  Saved: {save_path}")


def plot_summary_dashboard(results, analysis, save_path):
    """Figure 4: One-page summary dashboard."""
    fig = plt.figure(figsize=(16, 10))
    fig.suptitle('OVR Convergence Simulation v3 — Summary Dashboard', 
                 fontsize=16, fontweight='bold', y=0.98)
    
    # Create grid
    gs = fig.add_gridspec(3, 3, hspace=0.35, wspace=0.3,
                          left=0.06, right=0.94, top=0.93, bottom=0.05)
    
    checkpoints = analysis['checkpoints']
    cp_keys = sorted(checkpoints.keys(), key=int)
    cp_ints = [int(k) for k in cp_keys]
    
    ovrs = [r['final_ovr'] for r in results]
    skills = [r['true_skill'] for r in results]
    accs = [r['final_accuracy'] for r in results]
    
    # --- (0,0): Key Metrics ---
    ax = fig.add_subplot(gs[0, 0])
    ax.axis('off')
    metrics_text = f"""
    ┌─────────────────────────┐
    │     KEY METRICS         │
    ├─────────────────────────┤
    │ Students      : 500     │
    │ Problems      : 7,000   │
    │ Total Solved  : 3.5M    │
    │ Runtime       : 54.3s   │
    ├─────────────────────────┤
    │ Mean OVR      : {np.mean(ovrs):.0f}    │
    │ OVR StdDev    : {np.std(ovrs):.0f}    │
    │ OVR Range     : {min(ovrs):.0f}~{max(ovrs):.0f} │
    │ Mean Accuracy : {np.mean(accs)*100:.1f}%   │
    ├─────────────────────────┤
    │ OVR↔Skill r   : {analysis['correlations']['ovr_vs_skill']:.3f}  │
    │ OVR↔Acc r     : {analysis['correlations']['ovr_vs_accuracy']:.3f}  │
    │ 90%+ Pass     : {sum(1 for a in accs if a >= 0.90)/len(accs)*100:.1f}%   │
    └─────────────────────────┘
    """
    ax.text(0.5, 0.5, metrics_text, transform=ax.transAxes, fontsize=11,
            verticalalignment='center', horizontalalignment='center',
            fontfamily='monospace', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))
    
    # --- (0,1): OVR Convergence ---
    ax = fig.add_subplot(gs[0, 1:])
    means = [checkpoints[k]['ovr_mean'] for k in cp_keys]
    stds = [checkpoints[k]['ovr_std'] for k in cp_keys]
    ax.plot(cp_ints, means, 'b-o', linewidth=2.5, markersize=7, label='Mean OVR')
    ax.fill_between(cp_ints, 
                    [m - s for m, s in zip(means, stds)],
                    [m + s for m, s in zip(means, stds)],
                    alpha=0.25, color='blue')
    ax.axhline(y=1800, color='green', linestyle='--', alpha=0.6, linewidth=1.5, label='Pass (1800)')
    ax.axhline(y=1200, color='gray', linestyle='--', alpha=0.4, label='Default (1200)')
    ax.set_xlabel('Problems Solved')
    ax.set_ylabel('OVR')
    ax.set_title('OVR Convergence Over Time')
    ax.legend(loc='lower right')
    ax.grid(True, alpha=0.3)
    
    # --- (1,0): OVR Histogram ---
    ax = fig.add_subplot(gs[1, 0])
    ax.hist(ovrs, bins=35, color='steelblue', edgecolor='white', alpha=0.85)
    ax.axvline(x=np.mean(ovrs), color='red', linestyle='--', linewidth=2, label=f'Mean={np.mean(ovrs):.0f}')
    ax.axvline(x=1800, color='green', linestyle='--', alpha=0.5)
    ax.set_xlabel('Final OVR')
    ax.set_ylabel('Students')
    ax.set_title('OVR Distribution')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # --- (1,1): OVR vs Skill ---
    ax = fig.add_subplot(gs[1, 1])
    ax.scatter(skills, ovrs, alpha=0.4, s=15, c='steelblue')
    z = np.polyfit(skills, ovrs, 1)
    p = np.poly1d(z)
    ax.plot(sorted(skills), p(sorted(skills)), "r--", linewidth=2, 
            label=f'r = {analysis["correlations"]["ovr_vs_skill"]:.3f}')
    ax.set_xlabel('True Skill')
    ax.set_ylabel('Final OVR')
    ax.set_title('OVR vs True Skill')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # --- (1,2): OVR vs Accuracy ---
    ax = fig.add_subplot(gs[1, 2])
    colors_scatter = ['red' if a < 0.90 else 'green' for a in accs]
    ax.scatter(accs, ovrs, alpha=0.4, s=15, c=colors_scatter)
    z = np.polyfit(accs, ovrs, 1)
    p = np.poly1d(z)
    ax.plot(sorted(accs), p(sorted(accs)), "b--", linewidth=2,
            label=f'r = {analysis["correlations"]["ovr_vs_accuracy"]:.3f}')
    ax.axvline(x=0.90, color='orange', linestyle='--', alpha=0.5, label='90% threshold')
    ax.set_xlabel('Final Accuracy')
    ax.set_ylabel('Final OVR')
    ax.set_title('OVR vs Accuracy')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # --- (2,0): Correlation Progress ---
    ax = fig.add_subplot(gs[2, 0])
    corrs = [checkpoints[k]['ovr_vs_skill'] for k in cp_keys]
    ax.plot(cp_ints, corrs, 'g-^', linewidth=2.5, markersize=7, color='darkgreen')
    ax.set_xlabel('Problems Solved')
    ax.set_ylabel('Correlation')
    ax.set_title('Skill Estimation Accuracy (r)')
    ax.set_ylim(0.55, 0.78)
    ax.grid(True, alpha=0.3)
    
    # --- (2,1): StdDev Growth ---
    ax = fig.add_subplot(gs[2, 1])
    stds = [checkpoints[k]['ovr_std'] for k in cp_keys]
    ax.plot(cp_ints, stds, 'r-s', linewidth=2.5, markersize=7)
    ax.set_xlabel('Problems Solved')
    ax.set_ylabel('OVR StdDev')
    ax.set_title('Student Discrimination Growth')
    ax.grid(True, alpha=0.3)
    
    # --- (2,2): Accuracy Distribution ---
    ax = fig.add_subplot(gs[2, 2])
    ax.hist(accs, bins=30, color='darkgreen', edgecolor='white', alpha=0.7)
    ax.axvline(x=0.90, color='orange', linestyle='--', linewidth=2, label='90% threshold')
    ax.axvline(x=np.mean(accs), color='red', linestyle='--', linewidth=2, label=f'Mean={np.mean(accs)*100:.1f}%')
    ax.set_xlabel('Final Accuracy')
    ax.set_ylabel('Students')
    ax.set_title('Accuracy Distribution')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  Saved: {save_path}")


def main():
    output_dir = Path("sim_data")
    output_dir.mkdir(exist_ok=True)
    
    print("=" * 60)
    print("OVR Simulation Visualization")
    print("=" * 60)
    
    print("\n[1/4] Loading simulation data...")
    results, analysis, stem = load_latest_data(output_dir)
    print(f"      Loaded: {len(results)} students, {len(analysis['checkpoints'])} checkpoints")
    
    timestamp = stem.replace('ovr_v3_', '')
    
    print("\n[2/4] Generating convergence charts...")
    plot_ovr_convergence(results, analysis, output_dir / f"ovr_v3_convergence_{timestamp}.png")
    
    print("\n[3/4] Generating distribution charts...")
    plot_ovr_distribution(results, analysis, output_dir / f"ovr_v3_distribution_{timestamp}.png")
    
    print("\n[4/4] Generating summary dashboard...")
    plot_summary_dashboard(results, analysis, output_dir / f"ovr_v3_dashboard_{timestamp}.png")
    
    print("\n" + "=" * 60)
    print("All charts generated successfully!")
    print("=" * 60)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
