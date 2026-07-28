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


def _build_marketplace_catalog() -> tuple[dict[str, Any], ...]:
    """필요 변수: 시험지 85개·문제세트 166개·코스 81개 규칙. 작동 원리: Vercel 시작 시 전체 332개 재고를 한 번만 생성해 검색 요청마다 DB를 조회하지 않는다."""
    items: list[dict[str, Any]] = []
    grade_by_tier = {
        1: "고1",
        2: "고1-2",
        3: "고1-2",
        4: "고2-3",
        5: "고2-3",
    }
    tier_labels = {
        1: "기본기",
        2: "개념 적용",
        3: "유형 연결",
        4: "응용 실전",
        5: "심화 사고력",
    }
    version_labels = {
        3: "기본",
        4: "확장",
        5: "유형 확장",
        6: "종합 확장",
        7: "역량 확장",
        8: "병렬 확장",
        9: "원리 확장",
        10: "개념 연결",
        11: "유형 확장",
        12: "실전 연결",
        13: "수리 확장",
        14: "심화 연결",
        15: "구조 통합",
        16: "응용 전개",
        17: "개념 융합",
    }

    exam_specs = (
        ("foundation-a", "공통수학 기초 진단 A", "고1 핵심 개념 10문항 진단", "고1", "입문"),
        ("foundation-b", "공통수학 기초 진단 B", "계산 정확도와 개념 연결 점검", "고1", "기본"),
        ("algebra", "대수 실전 미니 모의", "수열·지수·로그 10문항", "고2", "중급"),
        ("calculus", "미적분 I 실전 미니 모의", "극한·미분·적분 10문항", "고2-3", "중상"),
        ("challenge", "상위권 사고력 모의", "복합 조건 중심 10문항", "고2-3", "심화"),
        ("mixed", "전 범위 밸런스 모의", "난이도 1~5 혼합 10문항", "고1-3", "혼합"),
        ("common-plus", "공통수학 종합 진단 C", "복소수·행렬·직선 10문항", "고1", "중급"),
        ("algebra-plus", "대수 개념 진단 B", "나머지정리·로그·수열 10문항", "고1-2", "중급"),
        ("calculus-plus", "미적분 I 실전 모의 B", "접선과 정적분 중심 10문항", "고2-3", "중상"),
        ("mixed-plus", "전 범위 밸런스 모의 B", "전 범위 혼합 10문항", "고1-3", "혼합"),
    )
    for rank, (slug, title, description, grade, difficulty) in enumerate(exam_specs):
        items.append(
            {
                "id": f"market-v2-exam-{slug}",
                "kind": "exam",
                "title": title,
                "description": description,
                "grade_band": grade,
                "difficulty": difficulty,
                "item_count": 10,
                "price_points": 0,
                "problem_ids": [],
                "owned": False,
                "featured_rank": 199 - rank,
                "asset_id": "",
            }
        )
    for version, suffix in version_labels.items():
        for tier, label in tier_labels.items():
            items.append(
                {
                    "id": f"market-v2-exam-tier-{tier}-v{version}",
                    "kind": "exam",
                    "title": f"난이도 {tier} · {label} 진단 · {suffix}",
                    "description": f"난이도 {tier} 직접 출제 문제 10문항",
                    "grade_band": grade_by_tier[tier],
                    "difficulty": f"난이도 {tier}",
                    "item_count": 10,
                    "price_points": 0,
                    "problem_ids": [],
                    "owned": False,
                    "featured_rank": 185 - version * 3 - tier,
                    "asset_id": "",
                }
            )

    set_specs = (
        ("polynomial", "다항식 기본기 5", "다항식 계산부터 인수정리까지", "고1", "입문"),
        ("quadratic", "이차방정식 집중 5", "근과 계수, 판별식 핵심 연습", "고1", "기본"),
        ("sequence", "수열 패턴 훈련 5", "등차·등비수열과 합의 구조", "고2", "기본"),
        ("exponential", "지수·로그 스타터 5", "지수법칙과 방정식 첫 훈련", "고2", "기본"),
        ("function", "함수 그래프 해석 5", "합성함수와 그래프 이동 연습", "고1-2", "중급"),
        ("counting", "경우의 수 핵심 5", "순열·조합과 조건 분류", "고1", "중급"),
        ("derivative", "미분 개념 점검 5", "도함수와 극대·극소 판정", "고2-3", "중급"),
        ("integral", "적분 계산 점검 5", "정적분 계산과 넓이 해석", "고2-3", "중급"),
        ("complex", "복소수 계산 스타터 5", "허수 단위 거듭제곱 훈련", "고1", "입문"),
        ("matrix", "행렬 연산 스타터 5", "행렬 덧셈과 성분 계산", "고1", "입문"),
        ("remainder", "나머지정리 기본기 5", "대입으로 나머지 계산", "고1", "기본"),
        ("logarithm", "로그 정의 점검 5", "로그식을 지수식으로 변환", "고2", "기본"),
        ("line", "직선의 방정식 점검 5", "기울기와 절편 복원", "고1", "중급"),
        ("permutation", "순열 사고 훈련 5", "선후 조건과 대응 연습", "고1", "중급"),
        ("tangent", "접선 기울기 실전 5", "도함수로 미정계수 복원", "고2-3", "중상"),
        ("parabola-area", "포물선 넓이 실전 5", "정적분 넓이와 매개변수", "고2-3", "심화"),
    )
    for rank, (slug, title, description, grade, difficulty) in enumerate(set_specs):
        items.append(
            {
                "id": f"market-v2-set-{slug}",
                "kind": "problem_set",
                "title": title,
                "description": description,
                "grade_band": grade,
                "difficulty": difficulty,
                "item_count": 5,
                "price_points": 0,
                "problem_ids": [],
                "owned": False,
                "featured_rank": 198 - rank,
                "asset_id": "",
            }
        )
    set_topics = (
        ("다항식", 1),
        ("수열 기초", 1),
        ("방정식", 2),
        ("지수·로그", 2),
        ("함수", 3),
        ("좌표기하", 3),
        ("미분", 4),
        ("적분", 4),
        ("고난도 함수", 5),
        ("복합 사고력", 5),
    )
    for version, suffix in version_labels.items():
        for index, (topic, tier) in enumerate(set_topics):
            items.append(
                {
                    "id": f"market-v2-set-{version}-{index + 1}",
                    "kind": "problem_set",
                    "title": f"난이도 {tier} · {topic} 5 · {suffix}",
                    "description": f"{topic} 핵심 유형 5문항",
                    "grade_band": grade_by_tier[tier],
                    "difficulty": f"난이도 {tier}",
                    "item_count": 5,
                    "price_points": 0,
                    "problem_ids": [],
                    "owned": False,
                    "featured_rank": 180 - version * 3 - index,
                    "asset_id": "",
                }
            )

    base_courses = (
        ("foundation", "공통수학 기초 완성", "다항식부터 지수까지 4단계 코스", "고1-2", "입문", 20, 900),
        ("algebra", "대수 개념 연결", "방정식·수열·지수를 연결하는 3단계 코스", "고1-2", "중급", 15, 1200),
        ("calculus", "미적분 I 실전 루트", "미분과 적분을 연결하는 2단계 코스", "고2-3", "중상", 10, 1500),
        ("challenge", "상위권 복합 사고력", "복합 사고력을 단계별로 훈련하는 심화 코스", "고2-3", "심화", 20, 1800),
        ("geometry", "좌표기하 연결 코스", "원과 직선을 연결하는 2단계 코스", "고1", "중급", 10, 1100),
        ("mastery", "수학 전 범위 마스터 루트", "검수 문제로 구성한 5단계 종합 코스", "고1-3", "혼합", 25, 2200),
    )
    for rank, (slug, title, description, grade, difficulty, count, _price) in enumerate(base_courses):
        items.append(
            {
                "id": f"market-v2-course-{slug}",
                "kind": "course",
                "title": title,
                "description": description,
                "grade_band": grade,
                "difficulty": difficulty,
                "item_count": count,
                "price_points": 0,
                "problem_ids": [],
                "owned": False,
                "featured_rank": 200 - rank,
                "asset_id": f"market-course-{slug}-v1",
            }
        )

    course_tier_labels = {
        1: ("개념 시작", "고1"),
        2: ("기본 완성", "고1"),
        3: ("유형 훈련", "고1-2"),
        4: ("실전 심화", "고2-3"),
        5: ("최상위 도전", "고2-3"),
    }
    course_version_labels = {
        3: "",
        4: "확장",
        5: "유형 확장",
        6: "실전",
        7: "집중 훈련",
        8: "응용",
        9: "고난도",
        10: "실전 완성",
        11: "약점 보완",
        12: "속도 훈련",
        13: "정확도 훈련",
        14: "내신 대비",
        15: "모의 평가",
        16: "파이널",
        17: "마스터",
    }
    for version, suffix in course_version_labels.items():
        for tier, (label, grade) in course_tier_labels.items():
            title = f"난이도 {tier} · {label} 코스"
            if suffix:
                title = f"{title} · {suffix}"
            items.append(
                {
                    "id": f"market-v2-course-tier-{tier}-v{version}",
                    "kind": "course",
                    "title": title,
                    "description": f"난이도 {tier} 문제를 단계별로 학습하는 {suffix or '전용'} 코스",
                    "grade_band": grade,
                    "difficulty": f"난이도 {tier}",
                    "item_count": 10,
                    "price_points": 0,
                    "problem_ids": [],
                    "owned": False,
                    "featured_rank": 180 - version * 5 - tier,
                    "asset_id": f"market-course-tier-{tier}-v{version}",
                }
            )
    return tuple(items)


MARKETPLACE_CATALOG = _build_marketplace_catalog()


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


class MarketplaceProgressRequest(BaseModel):
    """필요 변수: 문제 위치와 완료 여부. 작동 원리: 무료 마켓 코스의 사용자별 학습 위치를 제한된 형식으로 받는다."""

    progress_index: int = Field(default=0, ge=0)
    completed: bool = False


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


def _empty_arena_queue(queue_type: str) -> dict[str, Any]:
    """필요 변수: 대결 방식 ID. 작동 원리: 실시간 매칭 서버가 없는 Vercel 카나리에서 404 대신 초기 전적과 준비 상태를 반환한다."""
    return {
        "queue_type": queue_type,
        "rating": 1500,
        "tier": "C",
        "wins": 0,
        "losses": 0,
        "draws": 0,
        "recent_results": [],
        "coming_soon": True,
        "estimated_wait_seconds": 0,
    }


@app.get("/arena/summary")
def get_arena_summary(_user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 인증 사용자. 작동 원리: Vercel 화면이 대결장 구조를 렌더링하도록 두 공개 큐의 명시적 준비 상태를 반환한다."""
    return {
        "queues": [
            _empty_arena_queue("duel_exam"),
            _empty_arena_queue("team_exam"),
        ],
        "active_match_id": None,
        "active_practice_match_id": None,
    }


@app.get("/arena/rankings")
def get_arena_rankings(
    queue_type: str = "duel_exam",
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 인증 사용자·대결 방식. 작동 원리: 카나리 랭킹 원장이 준비되기 전 파싱 가능한 빈 순위를 반환한다."""
    if queue_type not in {"duel_exam", "team_exam"}:
        raise HTTPException(status_code=403, detail="현재 사용할 수 없는 대결 방식입니다.")
    return {"queue_type": queue_type, "items": []}


@app.get("/rating/tags")
def get_tag_ratings(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 태그 풀이 이력이 없으면 빈 목록을 반환한다."""
    return {"tags": []}


@app.get("/weakness/tags")
def get_weakness_tags(_user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자. 작동 원리: 약점 이력이 없는 신규 사용자의 빈 목록을 반환한다."""
    return {"tags": []}


def _catalog_course(item: dict[str, Any]) -> dict[str, Any]:
    """필요 변수: 마켓 코스 상품. 작동 원리: 같은 ID·제목을 코스 목록과 상세 화면이 파싱할 수 있는 V2 코스 계약으로 변환한다."""
    count = int(item["item_count"])
    return {
        "id": item["asset_id"],
        "title": item["title"],
        "description": item["description"],
        "difficulty": item["difficulty"],
        "duration": f"{max(1, (count + 4) // 5)}일",
        "lessons": max(1, (count + 4) // 5),
        "focus_tags": [item["grade_band"], item["difficulty"]],
        "target_ovr": 800,
        "is_demo": False,
        "is_public": True,
        "benefits": ["핵심 개념 정리", "단계별 문제 훈련"],
        "outline": ["개념 확인", "유형 훈련", "학습 마무리"],
        "modules": [],
    }


def _find_catalog_listing(identifier: str) -> dict[str, Any] | None:
    """필요 변수: 상품 ID 또는 코스 asset ID. 작동 원리: 81개 메모리 카탈로그를 단순 순회해 상세 요청 하나를 찾는다."""
    return next(
        (
            item
            for item in MARKETPLACE_CATALOG
            if item["id"] == identifier or item["asset_id"] == identifier
        ),
        None,
    )


def _load_owned_marketplace(user_id: str) -> dict[str, dict[str, Any]]:
    """필요 변수: 인증 사용자 ID. 작동 원리: 복합 인덱스 KV 한 행에서 무료 코스 보유·진도 상태를 읽어 DB 요청 수를 고정한다."""
    try:
        rows = _data_api().request(
            "GET",
            "canary_user_kv",
            query={
                "select": "value",
                "user_id": f"eq.{user_id}",
                "key": "eq.marketplace_owned",
                "limit": "1",
            },
        ) or []
        raw = json.loads(str(rows[0]["value"])) if rows else {}
    except (RuntimeError, ValueError, TypeError, KeyError, json.JSONDecodeError):
        return {}
    return {
        str(key): dict(value)
        for key, value in raw.items()
        if isinstance(value, dict)
    }


def _save_owned_marketplace(user_id: str, owned: dict[str, dict[str, Any]]) -> None:
    """필요 변수: 인증 사용자 ID와 보유 코스 상태. 작동 원리: 한 개 UTF-8 JSON 값으로 upsert해 상품별 DB 행 증가를 피한다."""
    try:
        _data_api().request(
            "POST",
            "canary_user_kv",
            query={"on_conflict": "user_id,key"},
            body={
                "user_id": user_id,
                "key": "marketplace_owned",
                "value": json.dumps(owned, ensure_ascii=False, separators=(",", ":")),
            },
            prefer="resolution=merge-duplicates,return=minimal",
        )
    except RuntimeError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


def _filtered_catalog_courses(
    query: str | None,
    offset: int,
    limit: int,
) -> list[dict[str, Any]]:
    """필요 변수: 코스 검색어와 페이지 범위. 작동 원리: 마켓과 동일한 메모리 원장에서 제목·설명을 검색해 코스 화면의 빈 목록을 제거한다."""
    normalized = (query or "").strip().casefold()
    courses = [
        _catalog_course(item)
        for item in MARKETPLACE_CATALOG
        if item["kind"] == "course"
        and (
            not normalized
            or normalized
            in f"{item['title']} {item['description']} {item['difficulty']}".casefold()
        )
    ]
    safe_offset = max(0, offset)
    safe_limit = min(max(1, limit), 200)
    return courses[safe_offset : safe_offset + safe_limit]


@app.get("/courses/v2")
def list_courses_v2(
    query: str | None = None,
    offset: int = 0,
    limit: int = 50,
    _user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자·검색어·페이지 범위. 작동 원리: 무료 마켓 코스와 같은 81개 코스를 V2 목록 계약으로 반환한다."""
    return {"data": _filtered_catalog_courses(query, offset, limit)}


@app.get("/courses")
def list_courses(
    query: str | None = None,
    offset: int = 0,
    limit: int = 50,
    _user_id: str = Depends(_current_user),
) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자·검색어·페이지 범위. 작동 원리: 레거시 화면에도 V2와 동일한 무료 코스 목록을 제공한다."""
    return {"courses": _filtered_catalog_courses(query, offset, limit)}


@app.get("/courses/enrolled")
def list_enrolled_courses(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 무료 마켓 보유 상태. 작동 원리: 구매한 코스 asset ID를 내 코스 화면의 등록 계약으로 변환한다."""
    owned = _load_owned_marketplace(user_id)
    items = []
    for listing_id, state in owned.items():
        listing = _find_catalog_listing(listing_id)
        if listing is None or listing["kind"] != "course":
            continue
        items.append(
            {
                "course_id": listing["asset_id"],
                "percent": 1.0 if state.get("completed") else 0.0,
                "status": "completed" if state.get("completed") else "in_progress",
                "progress": {
                    "progress_index": int(state.get("progress_index") or 0),
                    "completed_modules": [],
                },
            }
        )
    return {"items": items}


@app.get("/courses/v2/{course_id}")
def get_course_v2(course_id: str, _user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 코스 asset ID. 작동 원리: 마켓 원장에서 같은 코스를 찾아 상세 화면이 404 없이 조회할 V2 계약을 반환한다."""
    listing = _find_catalog_listing(course_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="course_not_found")
    return {"data": _catalog_course(listing)}


@app.get("/courses/{course_id}")
def get_legacy_course(course_id: str, _user_id: str = Depends(_current_user)) -> dict[str, Any]:
    """필요 변수: 코스 asset ID. 작동 원리: 레거시 상세 화면에도 같은 정규화 코스를 반환한다."""
    listing = _find_catalog_listing(course_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="course_not_found")
    return _catalog_course(listing)


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
def list_marketplace_items(
    query: str | None = None,
    kind: str | None = None,
    grade_band: str | None = None,
    price: str | None = None,
    offset: int = 0,
    limit: int = 20,
    _user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 검색어·자료 유형·학년·가격·페이지 범위. 작동 원리: 메모리 상주 카탈로그를 필터링하고 최대 50개만 반환해 Vercel DB 부하를 만들지 않는다."""
    normalized_query = (query or "").strip().casefold()
    normalized_grade = (grade_band or "").replace(" ", "")
    safe_offset = max(0, offset)
    safe_limit = min(max(1, limit), 50)

    def matches(item: dict[str, Any]) -> bool:
        """필요 변수: 카탈로그 항목과 정규화된 검색 조건. 작동 원리: 제목·설명·학년·난이도를 한 번씩 비교해 일치 여부를 결정한다."""
        if kind and item["kind"] != kind:
            return False
        if normalized_grade and normalized_grade not in str(item["grade_band"]).replace(" ", ""):
            return False
        if price == "free" and int(item["price_points"]) != 0:
            return False
        if price == "paid" and int(item["price_points"]) <= 0:
            return False
        searchable = " ".join(
            str(item[field]) for field in ("title", "description", "grade_band", "difficulty")
        ).casefold()
        return not normalized_query or normalized_query in searchable

    filtered = sorted(
        (item for item in MARKETPLACE_CATALOG if matches(item)),
        key=lambda item: (-int(item["featured_rank"]), str(item["title"])),
    )
    page = filtered[safe_offset : safe_offset + safe_limit]
    next_offset = safe_offset + len(page)
    return {
        "items": page,
        "total": len(filtered),
        "next_offset": next_offset if next_offset < len(filtered) else None,
    }


@app.get("/marketplace/my-items")
def list_owned_marketplace_items(user_id: str = Depends(_current_user)) -> dict[str, list[Any]]:
    """필요 변수: 인증 사용자와 보유 상태. 작동 원리: KV의 상품 ID를 공개 카탈로그와 합쳐 내 학습 목록을 반환한다."""
    owned = _load_owned_marketplace(user_id)
    items = []
    for listing_id, state in owned.items():
        listing = _find_catalog_listing(listing_id)
        if listing is not None:
            items.append({**listing, **state, "owned": True})
    return {"items": items}


@app.post("/marketplace/listings/{listing_id}/purchase")
def purchase_marketplace_item(
    listing_id: str,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 무료 상품 ID와 인증 사용자. 작동 원리: 가격 차감 없이 KV 보유 목록에 멱등 등록하고 즉시 코스 조회가 가능하게 한다."""
    listing = _find_catalog_listing(listing_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="listing_not_found")
    owned = _load_owned_marketplace(user_id)
    state = owned.setdefault(
        listing["id"],
        {"progress_index": 0, "status": "in_progress", "completed": False},
    )
    _save_owned_marketplace(user_id, owned)
    return {**listing, **state, "owned": True}


@app.post("/marketplace/my-items/{listing_id}/progress")
def update_owned_marketplace_progress(
    listing_id: str,
    payload: MarketplaceProgressRequest,
    user_id: str = Depends(_current_user),
) -> dict[str, Any]:
    """필요 변수: 보유 상품 ID·문제 위치·완료 여부. 작동 원리: 기존 KV 상태 하나만 갱신해 중단 위치와 완료 상태를 저장한다."""
    owned = _load_owned_marketplace(user_id)
    if listing_id not in owned:
        raise HTTPException(status_code=404, detail="purchase_not_found")
    owned[listing_id] = {
        "progress_index": payload.progress_index,
        "status": "completed" if payload.completed else "in_progress",
        "completed": payload.completed,
    }
    _save_owned_marketplace(user_id, owned)
    return owned[listing_id]


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
