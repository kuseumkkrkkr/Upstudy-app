#!/usr/bin/env bash
set -euo pipefail
# 필요한 변수: 선택 Python 실행 파일과 공개 포트다.
# 작동 원리: Lightning Studio의 /commands/python을 우선 사용해 자동 시작 환경에도
# python 별칭이 없다는 이유로 worker가 중단되지 않게 한다.
cd "$(dirname "$0")/../.."
PYTHON_BIN="${PYTHON_BIN:-python}"
if [ -x /commands/python ]; then
  PYTHON_BIN=/commands/python
fi
exec "$PYTHON_BIN" -m uvicorn deploy.lightning.worker_app:app --host 0.0.0.0 --port "${PORT:-8000}"
