import pickle
import json
import numpy as np
import os


def main():
    pkl_path = os.path.join(os.path.dirname(__file__), '..', 'sim_data', 'ovr_v3_20260516_152934.pkl')
    json_path = os.path.join(os.path.dirname(__file__), '..', 'sim_data', 'ovr_v3_analysis_20260516_152934.json')
    out_path = os.path.join(os.path.dirname(__file__), '..', 'sim_data', 'dashboard_data.js')

    with open(pkl_path, 'rb') as f:
        data = pickle.load(f)
    with open(json_path, 'r') as f:
        analysis = json.load(f)

    results = data['results']
    n = len(results)

    # KPIs
    mean_ovr = round(np.mean([r['final_ovr'] for r in results]), 1)
    std_ovr = round(np.std([r['final_ovr'] for r in results]), 1)
    pass_rate = round(sum(1 for r in results if r['final_accuracy'] >= 0.9) / n, 3)
    r_ovr_skill = round(np.corrcoef([r['final_ovr'] for r in results], [r['true_skill'] for r in results])[0, 1], 4)
    r_ovr_acc = round(np.corrcoef([r['final_ovr'] for r in results], [r['final_accuracy'] for r in results])[0, 1], 4)

    # Convergence
    checkpoints = sorted([int(k) for k in analysis['checkpoints'].keys()])
    conv_mean = [round(analysis['checkpoints'][str(k)]['ovr_mean'], 1) for k in checkpoints]
    conv_std = [round(analysis['checkpoints'][str(k)]['ovr_std'], 1) for k in checkpoints]
    conv_upper = [round(conv_mean[i] + conv_std[i], 1) for i in range(len(checkpoints))]
    conv_lower = [round(conv_mean[i] - conv_std[i], 1) for i in range(len(checkpoints))]

    # Distribution
    ovrs = [r['final_ovr'] for r in results]
    hist, edges = np.histogram(ovrs, bins=30)
    hist = [int(x) for x in hist]
    edges = [round(float(x), 1) for x in edges]

    # Correlation progress
    cp_ovr = {k: [] for k in checkpoints}
    cp_skill = {k: [] for k in checkpoints}
    cp_acc = {k: [] for k in checkpoints}
    for r in results:
        for c in r['checkpoints']:
            cp_ovr[c['pid']].append(c['ovr'])
            cp_skill[c['pid']].append(r['true_skill'])
            cp_acc[c['pid']].append(c['accuracy'])
    corr_progress = [round(float(np.corrcoef(cp_ovr[k], cp_skill[k])[0, 1]), 4) for k in checkpoints]

    # Students
    students = []
    for r in results:
        students.append({
            'sid': r['sid'],
            'skill': round(r['true_skill'], 1),
            'consistency': round(r['consistency'], 3),
            'final_ovr': round(r['final_ovr'], 1),
            'final_accuracy': round(r['final_accuracy'], 3),
            'pass': r['final_accuracy'] >= 0.9,
            'checkpoints': [{'pid': c['pid'], 'ovr': round(c['ovr'], 1), 'accuracy': round(c['accuracy'], 3)} for c in r['checkpoints']]
        })

    # Sample trajectories (10 diverse by final OVR)
    sorted_idx = sorted(range(len(students)), key=lambda i: students[i]['final_ovr'])
    sample_sids = [students[sorted_idx[int(i)]]['sid'] for i in np.linspace(0, len(sorted_idx) - 1, 10)]
    sample_students = [next(s for s in students if s['sid'] == sid) for sid in sample_sids]

    # Scatter data
    scatter_ovr = [s['final_ovr'] for s in students]
    scatter_skill = [s['skill'] for s in students]
    scatter_acc = [s['final_accuracy'] for s in students]
    scatter_pass = [s['pass'] for s in students]

    # Trend line for OVR vs Skill
    z = np.polyfit(scatter_skill, scatter_ovr, 1)
    trend_x = [round(float(x), 1) for x in np.linspace(min(scatter_skill), max(scatter_skill), 100)]
    trend_y = [round(float(np.polyval(z, x)), 1) for x in np.linspace(min(scatter_skill), max(scatter_skill), 100)]

    output = {
        'kpi': {
            'total_students': n,
            'mean_ovr': mean_ovr,
            'std_ovr': std_ovr,
            'r_ovr_skill': r_ovr_skill,
            'r_ovr_accuracy': r_ovr_acc,
            'pass_rate': pass_rate,
        },
        'convergence': {
            'x': checkpoints,
            'mean': conv_mean,
            'upper': conv_upper,
            'lower': conv_lower,
        },
        'distribution': {
            'hist': hist,
            'edges': edges,
        },
        'scatter': {
            'ovr': scatter_ovr,
            'skill': scatter_skill,
            'accuracy': scatter_acc,
            'pass': scatter_pass,
            'trend_x': trend_x,
            'trend_y': trend_y,
        },
        'correlation_progress': {
            'x': checkpoints,
            'r': corr_progress,
        },
        'trajectories': [
            {
                'sid': s['sid'],
                'skill': s['skill'],
                'x': [c['pid'] for c in s['checkpoints']],
                'y': [c['ovr'] for c in s['checkpoints']],
                'acc': [c['accuracy'] for c in s['checkpoints']],
            }
            for s in sample_students
        ],
        'students': [
            {
                'sid': s['sid'],
                'skill': s['skill'],
                'consistency': s['consistency'],
                'final_ovr': s['final_ovr'],
                'final_accuracy': s['final_accuracy'],
                'pass': s['pass'],
            }
            for s in students
        ]
    }

    js = 'const DASHBOARD_DATA = ' + json.dumps(output, separators=(',', ':')) + ';'
    with open(out_path, 'w') as f:
        f.write(js)
    print(f'Exported {len(js)} bytes to {out_path}')


if __name__ == '__main__':
    main()
