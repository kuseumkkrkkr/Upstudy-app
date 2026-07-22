#!/bin/bash
# 필요한 변수: 영속 Studio의 aiflow-worker 경로와 설치된 Python 환경.
# 작동 원리: Studio 재시작 때 중복 프로세스를 피하면서 공개 OCR worker를 자동 실행한다.
cd /teamspace/studios/this_studio/aiflow-worker
pgrep -f 'uvicorn deploy.lightning.worker_app:app.*--port 8000' >/dev/null || \
  nohup bash deploy/lightning/start.sh >> worker.log 2>&1 &
