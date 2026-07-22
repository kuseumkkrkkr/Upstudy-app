"""Vercel에서 Supabase OCR 작업 큐만 제공하는 경량 FastAPI 진입점."""
from __future__ import annotations

import json
import hashlib
import hmac
import os
import re
import secrets
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from typing import Any

import jwt
from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

MAX_JOB_BYTES = int(os.getenv("OCR_QUEUE_MAX_JOB_BYTES", "4000000"))
VISIBLE_COLUMNS = "id,status,result,error,created_at,updated_at,expires_at"
USER_COLUMNS = "user_id,username,name,grade,track,subject,school,profile_image,email,role,created_at"
USERNAME_RE = re.compile(r"^[A-Za-z0-9]{4,16}$")
PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,20}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
NAME_RE = re.compile(r"^[가-힣A-Za-z0-9 ]{1,20}$")


class OcrJobRequest(BaseModel):
    """필요 변수: 처리 모드와 기존 분석 payload. 작동 원리: 추론 입력을 큐 행 하나로 제한한다."""

    mode: str = Field(default="solve", pattern="^(solve|ocr)$")
    payload: dict[str, Any]


class RegisterRequest(BaseModel):
    """필요 변수: 학생 가입 필드. 작동 원리: 기존 FastAPI 가입 계약과 같은 JSON을 검증한다."""

    username: str
    password: str
    name: str
    grade: str
    track: str | None = None
    subject: str | None = None
    school: str | None = None
    profile_image: str | None = None
    email: str | None = None


class LoginRequest(BaseModel):
    """필요 변수: 아이디와 비밀번호. 작동 원리: Supabase 저장 해시와 비교할 입력을 제한한다."""

    username: str
    password: str


class UsernameRequest(BaseModel):
    """필요 변수: 검사할 아이디. 작동 원리: 가입 전 형식과 중복 여부를 한 번에 확인한다."""

    username: str


class FieldValidationRequest(BaseModel):
    """필요 변수: 필드 이름과 값. 작동 원리: 기존 앱의 단계별 가입 검증 계약을 유지한다."""

    field: str
    value: str = ""


class ProfileUpdateRequest(BaseModel):
    """필요 변수: 변경할 프로필 필드. 작동 원리: 전달된 값만 기존 사용자 행에 반영한다."""

    username: str | None = None
    password: str | None = None
    name: str | None = None
    grade: str | None = None
    track: str | None = None
    subject: str | None = None
    school: str | None = None
    email: str | None = None


class ProfileDeleteRequest(BaseModel):
    """필요 변수: 현재 비밀번호. 작동 원리: 계정 삭제 전 소유자를 재검증한다."""

    password: str


class UserStorageRequest(BaseModel):
    """필요 변수: UTF-8 JSON 문자열. 작동 원리: 기존 앱의 사용자별 KV 계약을 유지한다."""

    value: str


class SupabaseDataApi:
    """필요 변수: Supabase URL·service role key. 작동 원리: HTTPS PostgREST로만 큐를 읽고 쓴다."""

    def __init__(self) -> None:
        base_url = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
        service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not base_url or not service_key:
            raise RuntimeError("SUPABASE_URL과 SUPABASE_SERVICE_ROLE_KEY가 필요합니다")
        self.base_url = f"{base_url}/rest/v1"
        self.headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json; charset=utf-8",
        }

    def request(
        self,
        method: str,
        path: str,
        *,
        query: dict[str, str] | None = None,
        body: dict[str, Any] | None = None,
        prefer: str | None = None,
    ) -> Any:
        """필요 변수: 메서드·경로·필터·JSON. 작동 원리: 10초 제한 Data API 호출 결과를 UTF-8 JSON으로 반환한다."""
        url = f"{self.base_url}/{path.lstrip('/')}"
        if query:
            url = f"{url}?{urllib.parse.urlencode(query)}"
        headers = dict(self.headers)
        if prefer:
            headers["Prefer"] = prefer
        encoded = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(url, data=encoded, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase Data API {error.code}: {detail}") from error
        return json.loads(raw.decode("utf-8")) if raw else None


app = FastAPI(title="AIFlow OCR Queue", version="1.0.0")
origins = [value.strip() for value in os.getenv("CORS_ALLOW_ORIGINS", "").split(",") if value.strip()]
if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Idempotency-Key"],
    )


def _current_user(authorization: str | None = Header(default=None)) -> str:
    """필요 변수: 기존 AIFlow JWT와 OMJ_JWT_SECRET. 작동 원리: 동일 HS256 서명으로 큐 소유자를 확정한다."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Bearer token required")
    secret = os.getenv("OMJ_JWT_SECRET", "").strip()
    if not secret:
        raise HTTPException(status_code=503, detail="OMJ_JWT_SECRET is not configured")
    try:
        claims = jwt.decode(authorization[7:].strip(), secret, algorithms=["HS256"])
    except jwt.PyJWTError as error:
        raise HTTPException(status_code=401, detail="Invalid token") from error
    user_id = str(claims.get("sub") or "").strip()
    if not user_id:
        raise HTTPException(status_code=401, detail="Token subject required")
    return user_id


def _jwt_secret() -> str:
    """필요 변수: OMJ_JWT_SECRET. 작동 원리: 모든 카나리 인증 토큰에 동일한 운영 Secret을 강제한다."""
    secret = os.getenv("OMJ_JWT_SECRET", "").strip()
    if not secret:
        raise HTTPException(status_code=503, detail="OMJ_JWT_SECRET is not configured")
    return secret


def _create_token(user_id: str) -> str:
    """필요 변수: 사용자 UUID. 작동 원리: 기존 서버와 같은 HS256·7일 만료 토큰을 발급한다."""
    now = int(time.time())
    return jwt.encode(
        {"sub": user_id, "role": "student", "iat": now, "exp": now + 60 * 60 * 24 * 7},
        _jwt_secret(),
        algorithm="HS256",
    )


def _hash_password(password: str, salt: str) -> str:
    """필요 변수: 평문 비밀번호와 무작위 salt. 작동 원리: 기존 서버와 동일한 PBKDF2-SHA256 12만 회 해시를 만든다."""
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 120_000).hex()


def _validate_registration(payload: RegisterRequest) -> None:
    """필요 변수: 가입 payload. 작동 원리: DB 요청 전에 기존 학생 가입 형식을 동일하게 검사한다."""
    if not USERNAME_RE.fullmatch(payload.username.strip()):
        raise HTTPException(status_code=400, detail="아이디 형식이 다릅니다")
    if not PASSWORD_RE.fullmatch(payload.password):
        raise HTTPException(status_code=400, detail="비밀번호 형식이 다릅니다")
    if not NAME_RE.fullmatch(payload.name.strip()):
        raise HTTPException(status_code=400, detail="이름 형식이 다릅니다")
    if not payload.grade.strip():
        raise HTTPException(status_code=400, detail="학년을 입력해주세요")
    if payload.email and not EMAIL_RE.fullmatch(payload.email.strip()):
        raise HTTPException(status_code=400, detail="이메일 형식이 다릅니다")


def _get_private_user(user_id: str) -> dict[str, Any]:
    """필요 변수: 사용자 UUID. 작동 원리: 비밀번호 검증이 필요한 내부 열을 단건 조회한다."""
    try:
        rows = _data_api().request(
            "GET",
            "canary_users",
            query={"select": "user_id,password_hash,salt", "user_id": f"eq.{user_id}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")
    return dict(rows[0])


def _password_matches(row: dict[str, Any], password: str) -> bool:
    """필요 변수: 비밀번호 해시 행과 평문 입력. 작동 원리: PBKDF2 결과를 상수시간으로 비교한다."""
    computed = _hash_password(password, str(row["salt"]))
    return hmac.compare_digest(computed, str(row["password_hash"]))


def _data_api() -> SupabaseDataApi:
    """필요 변수: 배포 Secret. 작동 원리: serverless 요청마다 무상태 Data API 클라이언트를 만든다."""
    try:
        return SupabaseDataApi()
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


def _wake_lightning(job_id: str) -> None:
    """필요 변수: Lightning 공개 URL·공유 Secret. 작동 원리: Studio 시작 요청 후 wake를 보내 대기 큐를 소비시킨다."""
    wake_url = os.getenv("LIGHTNING_WAKE_URL", "").strip()
    wake_secret = os.getenv("LIGHTNING_WAKE_SECRET", "").strip()
    if not wake_url or not wake_secret:
        return
    try:
        _start_lightning_studio()
    except (urllib.error.HTTPError, OSError):
        # 큐 행은 이미 Supabase에 저장됐다. 관리 API의 일시 인증·네트워크 오류가
        # 학생의 OCR 접수 자체를 500으로 바꾸지 않게 하고, 실행 중 worker의 다음 poll을 기다린다.
        pass
    # Lightning는 너무 빨리 끊긴 요청을 Auto start 신호로 확정하지 않을 수 있다.
    wake_timeout = max(5.0, min(float(os.getenv("LIGHTNING_WAKE_TIMEOUT_SECONDS", "20")), 24.0))
    request = urllib.request.Request(
        wake_url,
        data=json.dumps({"job_id": job_id}).encode("utf-8"),
        headers={"Content-Type": "application/json", "X-Worker-Secret": wake_secret},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=wake_timeout) as response:
            response.read(128)
    except OSError:
        # 콜드 스타트 timeout이어도 최초 요청이 Studio 시작 신호로 사용된다.
        pass


def _start_lightning_studio() -> None:
    """필요 변수: Lightning Basic 인증·팀스페이스/Studio ID. 작동 원리: 기존 무료 CPU-4 Studio만 명시적으로 재개한다."""
    authorization = os.getenv("LIGHTNING_API_AUTH", "").strip()
    teamspace_id = os.getenv("LIGHTNING_TEAMSPACE_ID", "").strip()
    studio_id = os.getenv("LIGHTNING_STUDIO_ID", "").strip()
    if not authorization or not teamspace_id or not studio_id:
        return
    url = f"https://lightning.ai/v1/projects/{teamspace_id}/cloudspaces/{studio_id}/start"
    request = urllib.request.Request(
        url,
        data=json.dumps({"computeConfig": {"name": "cpu-4", "spot": False}}).encode("utf-8"),
        headers={"Authorization": authorization, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            response.read(128)
    except urllib.error.HTTPError as error:
        # 이미 Running/Pending인 Studio의 충돌 응답은 이어지는 wake 호출로 처리한다.
        if error.code not in {400, 409}:
            raise
    except OSError:
        # 관리 API 일시 실패는 공개 URL Auto start 경로로 한 번 더 시도한다.
        return


@app.get("/health")
def health() -> dict[str, str]:
    """필요 변수: 없음. 작동 원리: DB나 모델 없이 Vercel 함수 생존만 확인한다."""
    return {"status": "ok", "service": "aiflow-ocr-queue"}


@app.post("/auth/register", status_code=status.HTTP_201_CREATED)
def register_user(payload: RegisterRequest) -> dict[str, str]:
    """필요 변수: 검증된 가입 정보. 작동 원리: 고유 아이디를 Supabase에 저장하고 즉시 기존 호환 JWT를 발급한다."""
    _validate_registration(payload)
    user_id = str(uuid.uuid4())
    salt = secrets.token_hex(16)
    row = {
        "user_id": user_id,
        "username": payload.username.strip(),
        "name": payload.name.strip(),
        "grade": payload.grade.strip(),
        "track": (payload.track or "").strip() or None,
        "subject": (payload.subject or "").strip() or None,
        "school": (payload.school or "").strip() or None,
        "profile_image": (payload.profile_image or "").strip() or None,
        "email": (payload.email or "").strip() or None,
        "password_hash": _hash_password(payload.password, salt),
        "salt": salt,
    }
    try:
        rows = _data_api().request("POST", "canary_users", body=row, prefer="return=representation") or []
    except RuntimeError as error:
        if "23505" in str(error):
            raise HTTPException(status_code=409, detail="username already exists") from error
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=502, detail="User was not created")
    return {"token": _create_token(user_id), "user_id": user_id}


@app.post("/auth/login")
def login_user(payload: LoginRequest) -> dict[str, str]:
    """필요 변수: 아이디·비밀번호. 작동 원리: 인덱스 단건 조회 후 상수시간 해시 비교로 로그인한다."""
    username = payload.username.strip()
    try:
        rows = _data_api().request(
            "GET",
            "canary_users",
            query={"select": "user_id,password_hash,salt", "username": f"eq.{username}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    row = rows[0]
    computed = _hash_password(payload.password, str(row["salt"]))
    if not hmac.compare_digest(computed, str(row["password_hash"])):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    user_id = str(row["user_id"])
    return {"token": _create_token(user_id), "user_id": user_id}


@app.get("/auth/me")
def get_current_profile(user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증된 사용자 UUID. 작동 원리: 토큰 소유자의 공개 프로필 열만 단건 조회한다."""
    try:
        rows = _data_api().request(
            "GET", "canary_users", query={"select": USER_COLUMNS, "user_id": f"eq.{user_id}", "limit": "1"}
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")
    return dict(rows[0])


@app.put("/auth/me")
def update_current_profile(payload: ProfileUpdateRequest, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자·변경 필드. 작동 원리: 허용 필드만 검증해 Supabase 단일 행을 갱신한다."""
    changes = payload.model_dump(exclude_none=True)
    password = changes.pop("password", None)
    if "username" in changes and not USERNAME_RE.fullmatch(str(changes["username"]).strip()):
        raise HTTPException(status_code=400, detail="아이디 형식이 다릅니다")
    if "name" in changes and not NAME_RE.fullmatch(str(changes["name"]).strip()):
        raise HTTPException(status_code=400, detail="이름 형식이 다릅니다")
    if "email" in changes and changes["email"] and not EMAIL_RE.fullmatch(str(changes["email"]).strip()):
        raise HTTPException(status_code=400, detail="이메일 형식이 다릅니다")
    changes = {key: value.strip() if isinstance(value, str) else value for key, value in changes.items()}
    if password is not None:
        if not PASSWORD_RE.fullmatch(password):
            raise HTTPException(status_code=400, detail="비밀번호 형식이 다릅니다")
        salt = secrets.token_hex(16)
        changes.update({"salt": salt, "password_hash": _hash_password(password, salt)})
    if changes:
        try:
            _data_api().request(
                "PATCH",
                "canary_users",
                query={"user_id": f"eq.{user_id}"},
                body=changes,
                prefer="return=minimal",
            )
        except RuntimeError as error:
            if "23505" in str(error):
                raise HTTPException(status_code=409, detail="username already exists") from error
            raise HTTPException(status_code=502, detail=str(error)) from error
    return get_current_profile(user_id)


@app.delete("/auth/me")
def delete_current_profile(payload: ProfileDeleteRequest, user_id: str = Depends(_current_user)) -> dict[str, str]:
    """필요 변수: 인증 사용자·현재 비밀번호. 작동 원리: 비밀번호 확인 후 연관 KV와 사용자 행을 cascade 삭제한다."""
    if not _password_matches(_get_private_user(user_id), payload.password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    try:
        _data_api().request("DELETE", "canary_users", query={"user_id": f"eq.{user_id}"}, prefer="return=minimal")
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"status": "deleted"}


@app.post("/auth/anonymous")
def create_anonymous_token() -> dict[str, str]:
    """필요 변수: 없음. 작동 원리: 저장 행 없이 7일짜리 익명 사용자 토큰을 발급한다."""
    user_id = str(uuid.uuid4())
    return {"token": _create_token(user_id), "user_id": user_id}


@app.post("/auth/username/check")
def check_username(payload: UsernameRequest) -> dict[str, Any]:
    """필요 변수: 후보 아이디. 작동 원리: 형식 확인 후 고유 인덱스로 존재 여부만 조회한다."""
    username = payload.username.strip()
    if not USERNAME_RE.fullmatch(username):
        return {"available": False, "reason": "형식이 다릅니다"}
    try:
        rows = _data_api().request(
            "GET", "canary_users", query={"select": "user_id", "username": f"eq.{username}", "limit": "1"}
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"available": not rows, "reason": None if not rows else "이미 사용 중인 아이디입니다"}


@app.post("/auth/validate")
def validate_auth_field(payload: FieldValidationRequest) -> dict[str, Any]:
    """필요 변수: 필드명·값. 작동 원리: 네트워크 DB 조회 없이 가입 입력 형식을 빠르게 검증한다."""
    field = payload.field.strip().lower()
    value = payload.value
    valid = True
    if field == "username":
        valid = bool(USERNAME_RE.fullmatch(value.strip()))
    elif field == "password":
        valid = bool(PASSWORD_RE.fullmatch(value))
    elif field == "name":
        valid = bool(NAME_RE.fullmatch(value.strip()))
    elif field == "email":
        valid = not value.strip() or bool(EMAIL_RE.fullmatch(value.strip()))
    elif field == "school":
        valid = bool(value.strip())
    else:
        raise HTTPException(status_code=400, detail="unsupported field")
    return {"valid": valid, "reason": None if valid else "형식이 다릅니다"}


@app.get("/user/storage/{key}")
def get_user_storage(key: str, user_id: str = Depends(_current_user)) -> dict[str, str | None]:
    """필요 변수: 인증 사용자·저장 키. 작동 원리: 복합 기본키로 사용자 JSON 문자열을 단건 조회한다."""
    try:
        rows = _data_api().request(
            "GET",
            "canary_user_kv",
            query={"select": "value", "user_id": f"eq.{user_id}", "key": f"eq.{key}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"value": str(rows[0]["value"]) if rows else None}


@app.put("/user/storage/{key}")
def put_user_storage(key: str, payload: UserStorageRequest, user_id: str = Depends(_current_user)) -> dict[str, str]:
    """필요 변수: 인증 사용자·키·값. 작동 원리: 복합키 upsert로 재시작 가능한 사용자 상태를 저장한다."""
    try:
        _data_api().request(
            "POST",
            "canary_user_kv",
            query={"on_conflict": "user_id,key"},
            body={"user_id": user_id, "key": key, "value": payload.value},
            prefer="resolution=merge-duplicates,return=minimal",
        )
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"status": "ok"}


@app.delete("/user/storage/{key}")
def delete_user_storage(key: str, user_id: str = Depends(_current_user)) -> dict[str, str]:
    """필요 변수: 인증 사용자·키. 작동 원리: 본인 복합키 행만 삭제한다."""
    try:
        _data_api().request(
            "DELETE", "canary_user_kv", query={"user_id": f"eq.{user_id}", "key": f"eq.{key}"}, prefer="return=minimal"
        )
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"status": "ok"}


def _empty_account_summary() -> dict[str, Any]:
    """필요 변수: 없음. 작동 원리: 신규 카나리 계정의 포인트·활동 기본값을 앱 계약대로 반환한다."""
    return {
        "total_points": 0,
        "activity_score": 0,
        "level": 1,
        "current_level_score": 0,
        "next_level_score": 100,
        "level_progress": 0.0,
        "daily_points": 0,
        "daily_point_limit": 100,
        "daily_points_remaining": 100,
        "activity_display_daily_cap": 2000,
    }


@app.get("/account/summary")
def get_account_summary(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 신규 계정이 홈 화면을 열 수 있는 기본 계정 요약을 반환한다."""
    return _empty_account_summary()


@app.get("/rating/user")
def get_user_rating(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 풀이 이력이 없는 신규 사용자의 초기 레이팅을 반환한다."""
    return {"rating": 0.0, "ovr": 0.0, "ovr_delta": 0.0, "recent_accuracy": 0.0, "lose_streak": 0}


@app.get("/rating/tags")
def get_tag_ratings(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 태그 풀이 이력이 없으면 빈 목록을 반환한다."""
    return {"tags": []}


@app.get("/weakness/tags")
def get_weakness_tags(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 약점 이력이 없는 신규 사용자의 빈 목록을 반환한다."""
    return {"tags": []}


@app.get("/courses/v2")
def list_courses_v2(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: Supabase 코스 원장이 준비되기 전 빈 V2 페이지 계약을 유지한다."""
    return {"data": []}


@app.get("/courses")
def list_courses(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 레거시 코스 화면에 빈 목록을 반환한다."""
    return {"courses": []}


@app.get("/courses/enrolled")
def list_enrolled_courses(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 신규 계정의 수강 목록을 빈 배열로 반환한다."""
    return {"items": []}


@app.get("/academy/assignments/my")
@app.get("/academy/students/me/schedule")
def list_empty_student_tasks(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 배정 과제와 개인 일정이 없는 초기 홈 계약을 유지한다."""
    return {"items": []}


@app.get("/challenges/daily-quests")
def get_daily_quests(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 코스 미선택 상태의 일일 퀘스트와 계정 기본값을 반환한다."""
    return {"items": [], "account": _empty_account_summary(), "revision": 1}


@app.get("/marketplace/listings")
def list_marketplace_items(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 마켓 원장 이관 전 빈 페이지 응답을 반환한다."""
    return {"items": [], "total": 0, "next_offset": None}


@app.get("/marketplace/my-items")
def list_owned_marketplace_items(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 구매 이력이 없는 신규 계정의 빈 보유 목록을 반환한다."""
    return {"items": []}


@app.get("/history/solve")
def list_solve_history(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 풀이 이력이 없는 신규 계정의 빈 기록을 반환한다."""
    return {"items": []}


@app.get("/social/friends")
def list_friends(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 친구 관계가 없는 신규 계정의 빈 목록을 반환한다."""
    return {"friends": []}


@app.get("/social/friend-requests")
def list_friend_requests(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 대기 요청이 없는 신규 계정의 빈 목록을 반환한다."""
    return {"requests": []}


@app.get("/social/friends/rankings")
def list_friend_rankings(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 친구 랭킹이 없는 초기 상태를 반환한다."""
    return {"ranks": []}


@app.get("/social/conversations")
def list_conversations(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 대화가 없는 초기 상태를 반환한다."""
    return {"messages": []}


@app.get("/social/study-groups/mine")
@app.get("/social/study-groups/notices/my/system")
def list_my_social_items(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 가입 그룹·알림이 없는 초기 상태를 반환한다."""
    return {"items": []}


@app.get("/account/system-notices")
def list_system_notices(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 전역 알림이 없을 때 빈 목록을 반환한다."""
    return {"items": []}


@app.get("/textbooks")
def list_textbooks(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 교재 원장 이관 전 빈 교재 목록을 반환한다."""
    return {"textbooks": []}


@app.get("/quests")
def list_quests(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 문제 원장 이관 전 빈 검색 페이지를 반환한다."""
    return {"quests": [], "items": [], "total": 0}


@app.get("/quests/generation-tags")
def list_generation_tags(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 생성 태그 원장 이관 전 빈 그룹을 반환한다."""
    return {"groups": []}


@app.get("/exams")
def list_exams(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 시험지가 없는 신규 계정의 빈 목록을 반환한다."""
    return {"items": [], "exams": []}


@app.get("/serverchat/config")
def get_server_chat_config(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: 채팅 모델 Secret 미설정 상태를 명시적으로 비활성 응답한다."""
    return {"enabled": False, "reason": "SAM_API_KEY is not configured"}


@app.post("/api/ocr/jobs", status_code=status.HTTP_202_ACCEPTED)
async def create_ocr_job(
    request: Request,
    job: OcrJobRequest,
    user_id: str = Depends(_current_user),
    idempotency_key: str | None = Header(default=None, alias="X-Idempotency-Key"),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자·payload·멱등 키. 작동 원리: 중복 없이 큐에 넣고 Lightning을 깨운다."""
    size = len(json.dumps(job.model_dump(), ensure_ascii=False).encode("utf-8"))
    if int(request.headers.get("content-length") or 0) > MAX_JOB_BYTES or size > MAX_JOB_BYTES:
        raise HTTPException(status_code=413, detail=f"OCR job exceeds {MAX_JOB_BYTES} bytes")
    stable_key = (idempotency_key or str(uuid.uuid4())).strip()[:128]
    api = _data_api()
    try:
        rows = api.request(
            "POST",
            "ocr_jobs",
            query={"on_conflict": "user_id,idempotency_key"},
            body={"user_id": user_id, "mode": job.mode, "payload": job.payload, "idempotency_key": stable_key},
            prefer="resolution=ignore-duplicates,return=representation",
        ) or []
        if not rows:
            rows = api.request(
                "GET",
                "ocr_jobs",
                query={"select": VISIBLE_COLUMNS, "user_id": f"eq.{user_id}", "idempotency_key": f"eq.{stable_key}", "limit": "1"},
            ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=502, detail="OCR job was not created")
    created = dict(rows[0])
    _wake_lightning(str(created["id"]))
    return {"job_id": created["id"], "status": created["status"]}


@app.get("/api/ocr/jobs/{job_id}")
def get_ocr_job(job_id: uuid.UUID, user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 작업 UUID·인증 사용자. 작동 원리: 본인의 단일 큐 행만 인덱스로 조회한다."""
    try:
        rows = _data_api().request(
            "GET",
            "ocr_jobs",
            query={"select": VISIBLE_COLUMNS, "id": f"eq.{job_id}", "user_id": f"eq.{user_id}", "limit": "1"},
        ) or []
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    if not rows:
        raise HTTPException(status_code=404, detail="OCR job not found")
    return dict(rows[0])
