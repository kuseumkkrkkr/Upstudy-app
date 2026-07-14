"""Redis·PostgreSQL을 연결한 아레나 부하 검증 서버를 실행한다."""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

import uvicorn


def main() -> None:
    """필요 변수: 서버 루트·ARENA_LOAD_HOST·ARENA_LOAD_PORT. 부하 측정에 불필요한 요청 로그 없이 서버를 실행한다."""

    server_root = Path(__file__).resolve().parent.parent
    sys.path.insert(0, str(server_root))
    uvicorn.run(
        "server:app",
        host=os.getenv("ARENA_LOAD_HOST", "127.0.0.1"),
        port=int(os.getenv("ARENA_LOAD_PORT", "8010")),
        loop="asyncio",
        access_log=False,
    )


if __name__ == "__main__":
    main()
