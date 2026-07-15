"""대결장 REST API와 인증 계약."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from auth import decode_token, resolve_token_payload_user

from .service import arena_service


router = APIRouter(prefix="/arena", tags=["arena"])
security = HTTPBearer(auto_error=False)


def _user_id(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """필요 변수: Bearer 인증값. 기존 JWT에서 정규 사용자 ID를 추출한다."""

    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing token")
    payload = decode_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = resolve_token_payload_user(payload)
    if not user.get("user_id"):
        raise HTTPException(status_code=401, detail="Invalid token")
    return str(user["user_id"])


class JoinBody(BaseModel):
    queue_type: str
    idempotency_key: str = Field(min_length=8, max_length=128)


class SubmitBody(BaseModel):
    question_id: str
    answer: str = Field(max_length=500)
    idempotency_key: str = Field(min_length=8, max_length=128)


class ChatBody(BaseModel):
    message: str = Field(min_length=1, max_length=500)


def _bad_request(exc: ValueError) -> HTTPException:
    """필요 변수: 도메인 오류. 클라이언트가 처리할 HTTP 409 오류로 변환한다."""

    return HTTPException(status_code=409, detail=str(exc))


@router.get("/summary")
async def summary(user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """네 대결 큐의 사용자 레이팅과 전적을 조회한다."""

    return await arena_service.summary(user_id)


@router.post("/queue/join")
async def join_queue(body: JoinBody, user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """대결 큐에 참가하고 인원이 충족되면 경기 ID를 반환한다."""

    try:
        return await arena_service.join(user_id, body.queue_type, body.idempotency_key)
    except ValueError as exc:
        raise _bad_request(exc) from exc


@router.post("/queue/cancel")
async def cancel_queue(user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """사용자의 현재 매칭 대기를 취소한다."""

    return await arena_service.cancel(user_id)


@router.get("/matches/{match_id}")
async def match_state(match_id: str, user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """재접속을 포함한 공개 경기 상태를 조회한다."""

    try:
        return await arena_service.state(user_id, match_id)
    except ValueError as exc:
        raise _bad_request(exc) from exc


@router.post("/matches/{match_id}/answers")
async def submit_answer(match_id: str, body: SubmitBody, user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """문자열 답안을 제출하고 원자적인 채점 결과를 반환한다."""

    try:
        return await arena_service.submit(user_id, match_id, body.question_id, body.answer, body.idempotency_key)
    except ValueError as exc:
        raise _bad_request(exc) from exc


@router.post("/matches/{match_id}/chat")
async def send_chat(match_id: str, body: ChatBody, user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """2v2 경기의 같은 팀에만 보이는 채팅을 전송한다."""

    try:
        return await arena_service.send_chat(user_id, match_id, body.message)
    except ValueError as exc:
        raise _bad_request(exc) from exc
