from __future__ import annotations

import asyncio
import logging
import os
import signal
from datetime import datetime, timedelta, timezone

from env_loader import load_env

load_env()

from generater.codebase_runner import shutdown_process_pool, warmup_sympy_pool
from services.jobs.store import JobStore
from services.jobs.worker import JobWorker


async def run_worker() -> None:
    """필요 변수: 작업 동시성·poll 환경 변수. 작동 원리: HTTP 서버와 분리된 단일 작업 워커를 실행하고 종료 신호에서 생성 풀까지 정리한다."""
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("jobs.worker_main")
    stale_before = (datetime.now(timezone.utc) - timedelta(hours=6)).isoformat()
    stale_count = JobStore().fail_stale_active(
        before_iso=stale_before,
        detail="Dedicated worker restarted before job completed",
    )
    if stale_count:
        logger.warning("marked %s stale jobs as failed", stale_count)

    try:
        concurrency = max(1, int(os.getenv("JOB_WORKER_MAX_CONCURRENT", "6")))
    except ValueError:
        concurrency = 6
    try:
        poll_interval = max(0.1, float(os.getenv("JOB_WORKER_POLL_INTERVAL_SEC", "0.5")))
    except ValueError:
        poll_interval = 0.5
    worker = JobWorker(poll_interval=poll_interval, max_concurrent=concurrency)
    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()

    def request_stop(*_args: object) -> None:
        """필요 변수: 운영체제 종료 신호. 작동 원리: 이벤트 루프에 안전하게 종료 이벤트를 전달한다."""
        loop.call_soon_threadsafe(stop_event.set)

    for signal_name in (signal.SIGINT, signal.SIGTERM):
        try:
            signal.signal(signal_name, request_stop)
        except (OSError, ValueError):
            pass

    if os.getenv("WORKER_CODEBASE_POOL_WARMUP_ENABLED", "1").strip().lower() in {"1", "true", "yes", "on"}:
        await asyncio.to_thread(warmup_sympy_pool)
    await worker.start()
    maintenance_tasks: list[asyncio.Task[None]] = []
    if os.getenv("RUN_WORKER_MAINTENANCE", "1").strip().lower() in {"1", "true", "yes", "on"}:
        # 기존 서버 내장 유지보수 작업을 전용 워커 한 곳으로 옮겨 웹 프로세스별 중복 실행을 막는다.
        import server

        maintenance_tasks.extend(
            [
                asyncio.create_task(server._validate_level_test_static_db()),
                asyncio.create_task(server._seed_validator_loop()),
            ]
        )
    logger.info("dedicated job worker ready concurrency=%s", concurrency)
    try:
        await stop_event.wait()
    finally:
        for task in maintenance_tasks:
            task.cancel()
        if maintenance_tasks:
            await asyncio.gather(*maintenance_tasks, return_exceptions=True)
        await worker.stop()
        shutdown_process_pool(wait=False)
        logger.info("dedicated job worker stopped")


def main() -> None:
    """필요 변수: 없음. 작동 원리: 전용 asyncio 작업 워커 진입점을 실행한다."""
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()
