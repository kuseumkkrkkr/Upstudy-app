"""Lightning AI에서 TexTeller 작업을 한 번씩 가져와 처리하는 공개 wake API."""
from __future__ import annotations

import asyncio
import os
import socket
import sys
from pathlib import Path
from typing import Any

import httpx
from fastapi import Header, HTTPException
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parents[2]
OMJ = ROOT / "omj"
sys.path.insert(0, str(OMJ))
os.chdir(OMJ)

from analysis_service import analyze_pregrade, analyze_submission  # noqa: E402
from storage.solve_history import save_solve_history  # noqa: E402
from server import app as full_api_app  # noqa: E402

# 기존 FastAPI 전체 라우트에 OCR wake만 추가해, Lightning 한 포트에서 모든 제품 API를 제공한다.
app = full_api_app
_worker_id = f"lightning-{socket.gethostname()}-{os.getpid()}"
_run_lock = asyncio.Lock()


class WakeRequest(BaseModel):
    """필요 변수: 선택 작업 ID. 작동 원리: wake 호출 계약만 검증하고 실제 선점은 DB 함수에 맡긴다."""
    job_id: str | None = None


def _client() -> httpx.Client:
    """필요 변수: Supabase Secret. 작동 원리: service role로 원자적 큐 RPC만 호출한다."""
    url = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    return httpx.Client(base_url=f"{url}/rest/v1", headers={"apikey":key,"Authorization":f"Bearer {key}"}, timeout=30)


def _rpc(client: httpx.Client, name: str, body: dict[str, Any]) -> Any:
    """필요 변수: RPC 이름·인자. 작동 원리: 실패 응답을 즉시 예외로 바꾸고 JSON 결과를 반환한다."""
    response = client.post(f"/rpc/{name}", json=body)
    response.raise_for_status()
    return response.json()


def _extract_codebase_seed(payload: dict[str, Any]) -> tuple[int | None, int | None]:
    """필요 변수: 기존 풀이 payload의 선택 data 객체다.
    작동 원리: 동적 문제에서만 쓰는 codebase_id·seed를 정수로 정규화해 복습 이력과
    문제 재생 기능이 일반 HTTP 풀이 경로와 같은 식별자를 사용하게 한다.
    """
    data = payload.get("data")
    if not isinstance(data, dict):
        return None, None
    try:
        codebase_id = int(data["codebase_id"]) if data.get("codebase_id") is not None else None
    except (TypeError, ValueError):
        codebase_id = None
    try:
        seed = int(data["seed"]) if data.get("seed") is not None else None
    except (TypeError, ValueError):
        seed = None
    return codebase_id, seed


def _save_queued_solve_history(
    *,
    user_id: str,
    payload: dict[str, Any],
    result: dict[str, Any],
) -> None:
    """필요 변수: 큐 소유자·분석 입력·분석 결과다.
    작동 원리: 큐 worker가 분석 서비스만 직접 호출해도 일반 `/analysis/solve`와 같은
    7일 보관 풀이 이력을 저장하여 오답노트·복습 화면에서 누락되지 않게 한다.
    """
    if not user_id:
        return
    exam_id = str(payload.get("exam_id") or "").strip() or None
    quest_id = str(payload.get("quest_id") or "").strip() or None
    codebase_id, seed = _extract_codebase_seed(payload)
    history_payload = {
        **result,
        "all_formulas": payload.get("all_formulas") or [],
        "ocr_all_formulas": payload.get("ocr_all_formulas") or [],
        "ocr_purple_formulas": payload.get("ocr_purple_formulas") or [],
        "codebase_id": codebase_id,
        "seed": seed,
        "exam_id": exam_id,
        "quest_id": quest_id,
    }
    save_solve_history(
        user_id=user_id,
        kind="exam" if exam_id else "problem",
        quest_id=quest_id,
        exam_id=exam_id,
        codebase_id=codebase_id,
        seed=seed,
        payload=history_payload,
        delete_after_max=True,
    )


def _process_available_jobs() -> None:
    """필요 변수: Supabase 큐·기존 분석 서비스. 작동 원리: SKIP LOCKED로 선점해 한 번에 하나씩 최대 20건 처리한다."""
    with _client() as client:
        for _ in range(20):
            rows = _rpc(client,"claim_ocr_job",{"p_worker_id":_worker_id,"p_lease_seconds":900}) or []
            if not rows:
                return
            job = rows[0]
            try:
                payload = dict(job.get("payload") or {})
                result = analyze_submission(payload) if job.get("mode") == "solve" else analyze_pregrade(payload)
                if job.get("mode") == "solve":
                    # 분석 성공 뒤에만 저장한다. 이력 저장 실패가 OCR 결과 응답을 막지는 않는다.
                    try:
                        _save_queued_solve_history(
                            user_id=str(job.get("user_id") or ""),
                            payload=payload,
                            result=result,
                        )
                    except Exception:
                        pass
                _rpc(client,"complete_ocr_job",{"p_job_id":job["id"],"p_worker_id":_worker_id,"p_result":result})
            except Exception as error:
                _rpc(client,"fail_ocr_job",{"p_job_id":job["id"],"p_worker_id":_worker_id,"p_error":f"{type(error).__name__}: {error}"})


async def _run_once() -> None:
    """필요 변수: 프로세스 잠금. 작동 원리: 중복 wake를 하나로 합치고 추론을 이벤트 루프 밖에서 수행한다."""
    if _run_lock.locked():
        return
    async with _run_lock:
        await asyncio.to_thread(_process_available_jobs)


@app.on_event("startup")
async def drain_queue_on_startup() -> None:
    """필요 변수: Supabase 큐 환경값. 작동 원리: 콜드 스타트 wake 연결이 끊겨도 남은 작업을 자동 소비한다."""
    if os.getenv("SUPABASE_URL") and os.getenv("SUPABASE_SERVICE_ROLE_KEY"):
        asyncio.create_task(_run_once())


@app.get("/health")
def health() -> dict[str,str]:
    """필요 변수: 없음. 작동 원리: 모델 로드 없이 worker HTTP 프로세스 생존을 알린다."""
    return {"status":"ok","worker_id":_worker_id}


@app.post("/wake", status_code=202)
async def wake(_: WakeRequest, x_worker_secret: str | None = Header(default=None)) -> dict[str,str]:
    """필요 변수: Vercel과 공유한 Secret. 작동 원리: 즉시 응답하고 단일 백그라운드 소비 루프를 시작한다."""
    if not os.getenv("LIGHTNING_WAKE_SECRET") or x_worker_secret != os.getenv("LIGHTNING_WAKE_SECRET"):
        raise HTTPException(status_code=401,detail="invalid worker secret")
    asyncio.create_task(_run_once())
    return {"status":"accepted"}
