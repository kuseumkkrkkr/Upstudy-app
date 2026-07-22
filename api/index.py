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
    _start_lightning_studio()
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
