"""대결장 REST API와 인증 계약."""

from __future__ import annotations

from typing import Any

import asyncio
import json

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from auth import decode_token, resolve_token_payload_user

from .service import arena_service
from .repository import ArenaStoreUnavailable
from .models import JOINABLE_QUEUE_TYPES


router = APIRouter(prefix="/arena", tags=["arena"])
ws_router = APIRouter(tags=["arena"])
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


def _service_unavailable(exc: ArenaStoreUnavailable) -> HTTPException:
    """필요 변수: Redis 운영 오류. 로컬 매칭으로 우회하지 않고 재시도 가능한 503으로 변환한다."""

    return HTTPException(status_code=503, detail=str(exc))


@router.get("/summary")
async def summary(user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """네 대결 큐의 사용자 레이팅과 전적을 조회한다."""

    return await arena_service.summary(user_id)


@router.get("/rankings")
async def rankings(queue_type: str = "duel_exam", user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """필요 변수: 큐 유형·인증 사용자. 봇을 저장하지 않는 사용자 레이팅 순위를 반환한다."""

    del user_id
    if queue_type not in JOINABLE_QUEUE_TYPES:
        raise HTTPException(status_code=403, detail="현재 사용할 수 없는 대결 방식입니다.")
    try:
        return {"queue_type": queue_type, "items": await arena_service.rankings(queue_type)}
    except (ValueError, ArenaStoreUnavailable) as exc:
        raise (_service_unavailable(exc) if isinstance(exc, ArenaStoreUnavailable) else _bad_request(exc)) from exc


@router.post("/queue/join")
async def join_queue(body: JoinBody, user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """대결 큐에 참가하고 인원이 충족되면 경기 ID를 반환한다."""

    if body.queue_type not in JOINABLE_QUEUE_TYPES:
        raise HTTPException(status_code=403, detail="현재 사용할 수 없는 대결 방식입니다.")
    try:
        return await arena_service.join(user_id, body.queue_type, body.idempotency_key)
    except ArenaStoreUnavailable as exc:
        raise _service_unavailable(exc) from exc
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


@router.get("/matches/{match_id}/result")
async def match_result(match_id: str, user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """필요 변수: 경기·인증 사용자. 참가자에게만 PostgreSQL 영속 경기 결과를 반환한다."""

    try:
        return await arena_service.result(user_id, match_id)
    except ValueError as exc:
        raise _bad_request(exc) from exc


def _websocket_user_id(websocket: WebSocket) -> str | None:
    """필요 변수: WebSocket 쿼리 또는 Authorization 헤더. 기존 JWT에서 사용자 ID를 추출한다."""

    token = websocket.query_params.get("token") or websocket.headers.get("Authorization") or ""
    token = token.removeprefix("Bearer ").strip()
    payload = decode_token(token)
    if not payload:
        return None
    user = resolve_token_payload_user(payload)
    return str(user["user_id"]) if user.get("user_id") else None


@ws_router.websocket("/ws/arena")
async def arena_websocket(websocket: WebSocket) -> None:
    """필요 변수: JWT와 선택 경기 ID. 매칭·상태·답안·팀 채팅·종료 이벤트를 한 연결로 전달한다."""

    user_id = _websocket_user_id(websocket)
    if user_id is None:
        await websocket.close(code=1008)
        return
    await websocket.accept()
    match_id = websocket.query_params.get("match_id")
    announced_match_id: str | None = None
    await websocket.send_json({"type": "connected"})
    try:
        while True:
            if not match_id:
                summary = await arena_service.summary(user_id)
                match_id = summary.get("active_match_id")
            if match_id:
                if announced_match_id != match_id:
                    await websocket.send_json({"type": "match_found", "match_id": match_id})
                    announced_match_id = match_id
                state = await arena_service.state(user_id, match_id)
                await websocket.send_json({"type": "match_state", "data": state})
                if state.get("finished"):
                    result = await arena_service.result(user_id, match_id)
                    await websocket.send_json({"type": "match_finished", "data": result})
                    return
            try:
                raw = await asyncio.wait_for(websocket.receive_text(), timeout=1.0)
            except asyncio.TimeoutError:
                continue
            message = json.loads(raw)
            event_type = message.get("type")
            if event_type == "submit_answer" and match_id:
                result = await arena_service.submit(
                    user_id,
                    match_id,
                    str(message.get("question_id", "")),
                    str(message.get("answer", "")),
                    str(message.get("idempotency_key", "")),
                )
                await websocket.send_json({"type": "answer_result", "data": result})
            elif event_type == "team_chat" and match_id:
                item = await arena_service.send_chat(user_id, match_id, str(message.get("message", "")))
                await websocket.send_json({"type": "team_chat", "data": item})
            elif event_type == "ping":
                await websocket.send_json({"type": "pong"})
    except WebSocketDisconnect:
        return
    except (ValueError, ArenaStoreUnavailable) as exc:
        await websocket.send_json({"type": "error", "message": str(exc)})
        await websocket.close(code=1013 if isinstance(exc, ArenaStoreUnavailable) else 1008)
