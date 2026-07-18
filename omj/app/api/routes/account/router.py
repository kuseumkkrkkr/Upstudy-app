from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field

from auth import decode_token, resolve_token_payload_user
from app.api.routes.auth.middleware import require_role
from app.schemas.common import ApiResponse, JobStatus
from storage.student_account_store import add_activity_score, get_account_summary
from storage.system_notice_store import (
    delete_system_notice_by_title,
    list_system_notices,
    upsert_system_notice,
)


router = APIRouter(prefix="/account", tags=["account"])


class SystemNoticeUpsertRequest(BaseModel):
    title: str = Field(min_length=1)
    content_html: str = Field(min_length=1)


class ActivityScoreRecordRequest(BaseModel):
    delta_score: int = Field(gt=0, le=10000)
    ref_id: str = Field(min_length=1, max_length=200)
    reason: str = Field(default="activity_log", min_length=1, max_length=80)
    date_key: str | None = Field(default=None, max_length=10)


def _require_account_user(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    scheme, _, token = auth_header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    payload = decode_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    user = resolve_token_payload_user(payload)
    user_id = user["user_id"]
    username = user["username"]
    role = user["role"]
    request.state.user_id = user_id
    request.state.username = username
    request.state.role = role
    return {
        "user_id": user_id,
        "username": username,
        "role": role,
    }


@router.get("/summary", response_model=ApiResponse)
async def get_my_account_summary(
    request: Request,
    _user=Depends(_require_account_user),
):
    user_id: str = request.state.user_id
    data = get_account_summary(user_id)
    return ApiResponse(
        status=JobStatus.done,
        data=data,
        message="Account summary retrieved",
    )


@router.post("/activity-score", response_model=ApiResponse)
async def record_my_activity_score(
    body: ActivityScoreRecordRequest,
    request: Request,
    _user=Depends(require_role("admin")),
):
    """필요 변수: 관리자/신뢰 서버가 검증한 활동 원본이다.
    작동 원리: 학생 앱의 임의 경험치 제출을 차단하고, 내부 서버 역할만
    고유 참조값으로 경험치와 레벨 코인을 기록할 수 있게 한다.
    """
    user_id: str = request.state.user_id
    data = add_activity_score(
        user_id=user_id,
        delta_score=body.delta_score,
        ref_id=body.ref_id,
        reason=body.reason,
        date_key=body.date_key,
    )
    return ApiResponse(
        status=JobStatus.done,
        data=data,
        message="Activity score recorded",
    )


@router.get("/system-notices", response_model=ApiResponse)
async def get_system_notices(
    limit: int = Query(default=20, ge=1, le=100),
    _user=Depends(_require_account_user),
):
    return ApiResponse(
        status=JobStatus.done,
        data={"items": list_system_notices(limit=limit)},
        message="System notices retrieved",
    )


@router.put("/system-notices", response_model=ApiResponse)
async def put_system_notice(
    body: SystemNoticeUpsertRequest,
    request: Request,
    user=Depends(_require_account_user),
):
    if user["role"] not in {"teacher", "admin"}:
        raise HTTPException(status_code=403, detail="Insufficient role")
    try:
        item = upsert_system_notice(
            title=body.title,
            content_html=body.content_html,
            created_by_user_id=request.state.user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return ApiResponse(
        status=JobStatus.done,
        data=item,
        message="System notice saved",
    )


@router.delete("/system-notices", response_model=ApiResponse)
async def remove_system_notice(
    title: str = Query(..., min_length=1),
    user=Depends(_require_account_user),
):
    if user["role"] not in {"teacher", "admin"}:
        raise HTTPException(status_code=403, detail="Insufficient role")
    try:
        deleted = delete_system_notice_by_title(title)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if not deleted:
        raise HTTPException(status_code=404, detail="notice not found")
    return ApiResponse(
        status=JobStatus.done,
        data={"deleted": True, "title": title.strip()},
        message="System notice deleted",
    )
