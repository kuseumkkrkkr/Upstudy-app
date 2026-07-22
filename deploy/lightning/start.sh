#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
exec python -m uvicorn deploy.lightning.worker_app:app --host 0.0.0.0 --port "${PORT:-8000}"

