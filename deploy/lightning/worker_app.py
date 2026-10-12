"""Lightning wake worker: handwriting OCR only; product APIs and grading stay on Vercel."""
from __future__ import annotations

import asyncio
import base64
import binascii
import hmac
import os
import socket
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parents[2]
OMJ = ROOT / "omj"
sys.path.insert(0, str(OMJ))

from services.ocr.texteller_grid import extract_math_with_texteller_grid  # noqa: E402

app = FastAPI(title="AIFlow Handwriting OCR Worker")
_worker_id = f"lightning-{socket.gethostname()}-{os.getpid()}"
_run_lock = asyncio.Lock()


class WakeRequest(BaseModel):
    """필요 변수: 선택 작업 ID. 작동 원리: wake 호출 계약만 검증하고 실제 선점은 DB 함수에 맡긴다."""
    job_id: str | None = None


def _client() -> httpx.Client:
    """필요 변수: Vercel OCR URL·전용 worker secret. DB 자격 증명은 Lightning에 두지 않는다."""
    url = os.environ["VERCEL_API_BASE_URL"].strip().rstrip("/")
    secret = os.environ["VERCEL_OCR_WORKER_SECRET"].strip()
    try:
        parsed = urlsplit(url)
        host = parsed.hostname or ""
        port = parsed.port
    except ValueError as error:
        raise RuntimeError("Vercel OCR worker configuration is invalid") from error
    is_vercel_host = host == "vercel.app" or host.endswith(".vercel.app")
    if (
        parsed.scheme != "https"
        or not is_vercel_host
        or parsed.username is not None
        or parsed.password is not None
        or port not in (None, 443)
        or parsed.path not in ("", "/")
        or parsed.query
        or parsed.fragment
        or not secret
    ):
        raise RuntimeError("Vercel OCR worker configuration is invalid")
    return httpx.Client(
        base_url=f"https://{host}",
        headers={"X-Worker-Secret": secret},
        timeout=httpx.Timeout(30, connect=5),
    )


def _request(client: httpx.Client, path: str, body: dict[str, Any]) -> Any:
    """필요 변수: Vercel 내부 OCR 경로·본문. 응답 오류를 예외로 바꾼다."""
    response = client.post(path, json=body)
    response.raise_for_status()
    return response.json()


def _decode_image(value: Any) -> bytes:
    """Decode only the base64 handwriting image Vercel projected for OCR."""
    if not isinstance(value, str) or not value:
        return b""
    if len(value) > 6_000_000:
        raise ValueError("invalid_handwriting_image")
    try:
        return base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error):
        return b""


def _process_available_jobs() -> None:
    """Run TexTeller on leased handwriting input supplied by the Vercel API only."""
    with _client() as client:
        for _ in range(20):
            rows = _request(
                client,
                "/internal/ocr/claim",
                {"worker_id": _worker_id, "lease_seconds": 900},
            ) or []
            if not rows:
                return
            job = rows[0]
            try:
                if not isinstance(job, dict) or job.get("mode") != "ocr":
                    raise ValueError(
                        "Lightning accepts OCR-only jobs; grading and product logic belong to Vercel."
                    )
                payload = dict(job.get("payload") or {})
                if set(payload) - {"student_work_image", "writing_events"}:
                    raise ValueError("non-OCR payload reached Lightning")
                result = extract_math_with_texteller_grid(
                    _decode_image(payload.get("student_work_image")),
                    payload.get("writing_events"),
                )
                _request(
                    client,
                    f"/internal/ocr/jobs/{job['id']}/complete",
                    {"worker_id": _worker_id, "result": result},
                )
            except Exception as error:
                job_id = job.get("id") if isinstance(job, dict) else None
                if not isinstance(job_id, str) or not job_id:
                    raise
                _request(
                    client,
                    f"/internal/ocr/jobs/{job_id}/fail",
                    {"worker_id": _worker_id, "error": type(error).__name__},
                )


async def _run_once() -> None:
    """필요 변수: 프로세스 잠금. 작동 원리: 중복 wake를 하나로 합치고 추론을 이벤트 루프 밖에서 수행한다."""
    if _run_lock.locked():
        return
    async with _run_lock:
        await asyncio.to_thread(_process_available_jobs)


@app.on_event("startup")
async def drain_queue_on_startup() -> None:
    """필요 변수: Vercel OCR endpoint와 전용 secret. 콜드 스타트 뒤 큐 복구를 시도한다."""
    if os.getenv("VERCEL_API_BASE_URL") and os.getenv("VERCEL_OCR_WORKER_SECRET"):
        asyncio.create_task(_run_once())


@app.get("/health")
def health() -> dict[str,str]:
    """필요 변수: 없음. 작동 원리: 모델 로드 없이 worker HTTP 프로세스 생존을 알린다."""
    return {"status":"ok","worker_id":_worker_id,"scope":"handwriting_ocr_only"}


@app.post("/wake", status_code=202)
async def wake(_: WakeRequest, x_worker_secret: str | None = Header(default=None)) -> dict[str,str]:
    """필요 변수: Vercel과 공유한 Secret. 작동 원리: 즉시 응답하고 단일 백그라운드 소비 루프를 시작한다."""
    expected = os.getenv("LIGHTNING_WAKE_SECRET", "")
    if not expected or not x_worker_secret or not hmac.compare_digest(x_worker_secret, expected):
        raise HTTPException(status_code=401,detail="invalid worker secret")
    asyncio.create_task(_run_once())
    return {"status":"accepted"}
