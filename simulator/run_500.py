"""
500-student simulation runner with progress logging
"""
import sys
import time

# 로깅 설정
log_file = open('simulation_run.log', 'w', encoding='utf-8', buffering=1)
start_time = time.time()

def log(msg):
    elapsed = time.time() - start_time
    line = f"[{elapsed:.1f}s] {msg}"
    print(line, flush=True)
    log_file.write(line + '\n')
    log_file.flush()

log("Importing massive_rating_simulator...")

from massive_rating_simulator import MassiveSimulator, ProgressLogger, generate_report

log("Import complete. Starting simulation...")

n_students = int(sys.argv[1]) if len(sys.argv) > 1 else 500
batch_size = int(sys.argv[2]) if len(sys.argv) > 2 else 3

with ProgressLogger("simulation_progress.log") as logger:
    logger.log(f"=== {n_students} Student Simulation ===")
    logger.log(f"Batch size: {batch_size}")
    
    sim = MassiveSimulator(
        n_students=n_students, seed=42,
        fast_mode=True, batch_size=batch_size,
        logger=logger
    )
    
    start = time.time()
    result = sim.run(verbose=True)
    elapsed = time.time() - start
    
    logger.log(f"\n=== COMPLETE ===")
    logger.log(f"Elapsed: {elapsed:.1f}s ({elapsed/60:.1f} min)")
    
    # 결과 요약
    v = result['validation']
    logger.log(f"\n[Results]")
    logger.log(f"  true_skill_corr: {v['true_skill_rating_corr']:.3f}")
    logger.log(f"  tag_corr: {v['avg_tag_corr']:.3f}")
    logger.log(f"  accuracy_corr: {v['accuracy_rating_corr']:.3f}")
    
    # 등급별
    logger.log(f"\n[Tier Ratings]")
    for tier in sorted(result['analysis']['tier_stats'].keys()):
        s = result['analysis']['tier_stats'][tier]
        logger.log(f"  Tier {tier}: {s['avg_rating']:.1f} (n={s['count']}, acc={s['avg_accuracy']:.1%})")
    
    # 리포트 생성
    generate_report(result, "simulation_report.txt", logger)
    
    logger.log("\nDone! Files created:")
    logger.log("  - simulation_progress.log")
    logger.log("  - simulation_report.txt")
    logger.log("  - simulation_report_data.json")

log_file.close()
