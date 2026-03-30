import asyncio
import base64
import json
import os
import urllib.error
import urllib.request
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

from fastapi import Depends, FastAPI, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from env_loader import load_env
from auth import (
    authenticate_user,
    create_token,
    decode_token,
    get_user_id_by_username,
    init_user_db,
    register_user,
    validate_email,
    validate_name,
    validate_password,
    validate_school,
    validate_username,
)
from analysis_service import analyze_pregrade, analyze_submission
from clean_riddles import build_clean_payload
from baselines.basemodel import ContentBlocks
from exam_service import plan_exam_items
from generater.make import make, make_legacy
from generater.csat_cubic_generator import generate_problem
from generater.problem_solve import generate_problem_set
from rating_service import apply_rating_update, fetch_tag_ratings, fetch_user_rating
from storage.exam_storage import (
    add_exam_items,
    create_exam,
    find_reusable_quest,
    get_exam,
    get_exam_items,
    get_total_quest_count,
    init_exam_db,
    update_exam_item,
    update_exam_status,
)
from storage.storage import get_quest, init_db, search_quests, store_data
from storage.social_storage import (
    add_friend,
    get_friends,
    get_user_by_id,
    get_user_by_username,
    init_social_db,
    remove_friend,
    search_users_by_username,
)
from storage.study_group_storage import (
    create_study_group,
    init_study_group_db,
)
from storage.rating_storage import init_rating_db
from storage.weakness_storage import (
    increment_weakness_tags,
    init_weakness_db,
    list_weakness_tags,
)
from storage.textbook_storage import (
    create_textbook,
    get_textbook,
    init_textbook_db,
    list_textbooks,
)
from storage.user_kv_storage import (
    delete_user_kv,
    get_user_kv,
    init_user_kv_db,
    set_user_kv,
)
from test_chat.service import build_test_chat_response

try:
    from pdf_builder import build_exam_pdf
except ImportError:
    build_exam_pdf = None


app = FastAPI()
security = HTTPBearer(auto_error=False)
_GEN_SEMAPHORE = asyncio.Semaphore(2)

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
_ASSETS_DIR = os.path.join(_BASE_DIR, "assets")
os.makedirs(_ASSETS_DIR, exist_ok=True)

load_env()
_raw_origins = os.environ.get("OMJ_CORS_ORIGINS", "*")
_origin_list = [origin.strip() for origin in _raw_origins.split(",") if origin.strip()]
_allow_all = "*" in _origin_list
app.add_middleware(
  CORSMiddleware,
    allow_origins=["*"] if _allow_all else _origin_list,
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=False,
)

app.mount("/assets", StaticFiles(directory=_ASSETS_DIR), name="assets")


class RangeInput(BaseModel):
    key: Optional[str] = None
    tags: List[str] = Field(default_factory=list)


class ExamCreateRequest(BaseModel):
    ranges: List[RangeInput]
    difficulty_tier: int = Field(ge=1, le=5)
    question_count: int = Field(ge=1)
    paper_type: str = "aiflow"


class ExamCreateResponse(BaseModel):
    exam_id: str
    status: str


class ExamItemResponse(BaseModel):
    item_index: int
    status: str
    subject_key: str
    hash_tags: List[str]
    difficulty_tier: int
    solves_count: int
    strategy_level: int
    branch_conditions: int
    question_type: Optional[str] = None
    quest_id: Optional[str] = None
    flow_count: Optional[int] = None
    quest_title: Optional[ContentBlocks] = None
    quest_options: Optional[List[ContentBlocks]] = None
    error: Optional[str] = None


class ExamStatusResponse(BaseModel):
    exam_id: str
    status: str
    items: List[ExamItemResponse]


class TokenResponse(BaseModel):
    token: str
    user_id: str


class RegisterRequest(BaseModel):
    username: str
    password: str
    name: str
    grade: str
    track: Optional[str] = None
    subject: Optional[str] = None
    school: Optional[str] = None
    profile_image: Optional[str] = None
    email: Optional[str] = None


class LoginRequest(BaseModel):
    username: str
    password: str


class UsernameCheckRequest(BaseModel):
    username: str


class UsernameCheckResponse(BaseModel):
    available: bool
    reason: Optional[str] = None


class FieldValidationRequest(BaseModel):
    field: str
    value: str


class FieldValidationResponse(BaseModel):
    valid: bool
    reason: Optional[str] = None


class KakaoLoginRequest(BaseModel):
    provider: Optional[str] = None
    access_token: str
    id_token: Optional[str] = None


class QuestSearchResponse(BaseModel):
    quests: List[Dict[str, Any]]
    total: int
    page: int
    page_size: int


class QuestGenerateRequest(BaseModel):
    hash_tags: List[str]
    solves_count: int = Field(ge=1)
    strategy_level: int = Field(ge=1, le=3)
    branch_conditions: int = Field(ge=0)
    reference_quest_id: Optional[str] = None
    strict_tags: bool = False
    seed: Optional[int] = None


class QuestGenerateResponse(BaseModel):
    quest: Dict[str, Any]


class ProblemSolveGenerateRequest(BaseModel):
    hash_tags: List[str]
    min_difficulty_tier: int = Field(ge=1, le=5)
    max_difficulty_tier: int = Field(ge=1, le=5)
    question_count: int = Field(ge=1)
    strict_tags: bool = False


class ProblemSolveGenerateResponse(BaseModel):
    quests: List[Dict[str, Any]]


class CubicGenerateRequest(BaseModel):
    seed: Optional[int] = None


class CubicGenerateResponse(BaseModel):
    problem: str
    answer: int
    solution: str
    meta: Dict[str, Any]


class TestChatPair(BaseModel):
    user: str
    assistant: str


class TestChatMessageRequest(BaseModel):
    user_message: str
    affection: int = Field(ge=1, le=255)
    attendance_days: int = Field(ge=1)
    quest_id: Optional[str] = None
    problem_number: Optional[str] = None
    solution_notes: Optional[str] = None
    learning_ratings: Dict[str, int] = Field(default_factory=dict)
    recent_pairs: List[TestChatPair] = Field(default_factory=list)


class TestChatMessageResponse(BaseModel):
    assistant_message: str
    pair_summary: Optional[str] = None
    prompt: str
    input_token_estimate: int
    output_token_estimate: int
    token_estimate: int


class SolveAnalysisRequest(BaseModel):
    quest_id: Optional[str] = None
    quest_model: List[str] = Field(default_factory=list)
    analysis_model: Optional[str] = None
    analysis_prompt: Optional[str] = None
    quest_json: Optional[Dict[str, Any]] = None
    debug: Optional[bool] = None
    gen_config: Optional[Dict[str, Any]] = None
    all_ocr: Optional[str] = None
    hit_mapped: Optional[str] = None
    user_answer: Optional[str] = None
    problem: Optional[str] = None
    problem_index: Optional[int] = None
    problem_count: Optional[int] = None
    hash_tags: List[str] = Field(default_factory=list)
    student_work_image: Optional[str] = None
    problem_image: Optional[str] = None
    reference_steps: List[Dict[str, Any]] = Field(default_factory=list)
    reference_flow_count: Optional[int] = None
    recognized_text: List[Dict[str, Any]] = Field(default_factory=list)
    writing_events: List[Dict[str, Any]] = Field(default_factory=list)
    step_correctness: List[Dict[str, Any]] = Field(default_factory=list)
    time_weakness: List[Dict[str, Any]] = Field(default_factory=list)


class SolveAnalysisResponse(BaseModel):
    status: List[Dict[str, Any]] = Field(default_factory=list)
    in_panic: List[int] = Field(default_factory=list)
    ai_opinion: str = ""
    quest_id: Optional[str] = None
    quest_model: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)
    debug: Optional[Dict[str, Any]] = None


class SolveOcrRequest(BaseModel):
    analysis_model: Optional[str] = None
    analysis_prompt: Optional[str] = None
    debug: Optional[bool] = None
    gen_config: Optional[Dict[str, Any]] = None
    student_work_image: Optional[str] = None
    heatmap_image: Optional[str] = None


class SolveOcrResponse(BaseModel):
    all_formulas: Optional[List[str]] = None
    purple_formulas: Optional[List[str]] = None
    all_ocr: Optional[str] = None
    hit_mapped: Optional[str] = None
    user_answer: Optional[str] = None
    warnings: List[str] = Field(default_factory=list)
    ocr_source: str = ""
    debug: Optional[Dict[str, Any]] = None


class FriendProfile(BaseModel):
    user_id: str
    username: str
    name: Optional[str] = None
    profile_image: Optional[str] = None
    ovr: int = 0
    status: str = ""


class FriendSearchRequest(BaseModel):
    query: str = Field(min_length=1)
    limit: int = Field(default=20, ge=1, le=50)


class FriendSearchResponse(BaseModel):
    users: List[FriendProfile]


class FriendAddRequest(BaseModel):
    username: str


class FriendListResponse(BaseModel):
    friends: List[FriendProfile]


class StudyGroupCreateRequest(BaseModel):
    name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    max_members: int = Field(ge=1)
    is_public: bool = True
    logo_index: Optional[int] = None
    lock_enabled: bool = False
    password: Optional[str] = None
    member_ids: List[str] = Field(default_factory=list)


class StudyGroupResponse(BaseModel):
    group_id: str
    name: str
    description: str
    max_members: int
    is_public: bool
    logo_index: Optional[int] = None
    lock_enabled: bool
    created_at: str
    creator_id: str
    member_ids: List[str]


class TextbookSection(BaseModel):
    title: str
    paragraphs: List[str] = Field(default_factory=list)
    images: List[str] = Field(default_factory=list)


class TextbookChapter(BaseModel):
    title: str
    intro: List[str] = Field(default_factory=list)
    sections: List[TextbookSection] = Field(default_factory=list)


class TextbookCreateRequest(BaseModel):
    title: str
    subtitle: str = ""
    category: str = "custom"
    tags: List[str] = Field(default_factory=list)
    chapters: List[TextbookChapter] = Field(default_factory=list)
    cover_color: Optional[int] = None


class TextbookResponse(BaseModel):
    textbook_id: str
    title: str
    subtitle: str
    category: str
    tags: List[str] = Field(default_factory=list)
    chapters: List[TextbookChapter] = Field(default_factory=list)
    cover_color: Optional[int] = None
    created_at: int
    updated_at: int
    created_by: Optional[str] = None


class TextbookListResponse(BaseModel):
    textbooks: List[TextbookResponse]


_TEXTBOOK_LIBRARY_KEY = "textbook_library_v1"


def _parse_library_payload(raw: Optional[str]) -> List[Dict[str, Any]]:
    if not raw:
        return []
    try:
        payload = json.loads(raw)
    except Exception:
        return []
    if not isinstance(payload, list):
        return []
    items: List[Dict[str, Any]] = []
    for entry in payload:
        if isinstance(entry, str):
            entry = entry.strip()
            if entry:
                items.append({"textbook_id": entry})
            continue
        if isinstance(entry, dict):
            text_id = entry.get("textbook_id") or entry.get("id")
            if text_id:
                items.append(dict(entry))
    return items


def _library_ids_from_meta(items: List[Dict[str, Any]]) -> List[str]:
    ids = []
    for entry in items:
        text_id = entry.get("textbook_id") or entry.get("id")
        if text_id:
            ids.append(str(text_id))
    return ids


def _build_library_meta(book: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "textbook_id": book.get("textbook_id") or book.get("id") or "",
        "title": book.get("title") or "",
        "subtitle": book.get("subtitle") or "",
        "category": book.get("category") or "custom",
        "tags": book.get("tags") or [],
        "cover_color": book.get("cover_color"),
        "created_at": book.get("created_at"),
        "updated_at": book.get("updated_at"),
        "created_by": book.get("created_by"),
        "progress": book.get("progress", 0),
        "progress_label": book.get("progress_label", ""),
    }


def _ensure_default_library(user_id: str) -> List[str]:
    raw = get_user_kv(user_id, _TEXTBOOK_LIBRARY_KEY)
    items = _parse_library_payload(raw)
    ids = _library_ids_from_meta(items)
    if ids:
        return ids
    common_books = list_textbooks(category="common")
    if not common_books:
        return []
    meta = [_build_library_meta(book) for book in common_books]
    set_user_kv(user_id, _TEXTBOOK_LIBRARY_KEY, json.dumps(meta, ensure_ascii=False))
    return _library_ids_from_meta(meta)


def _upsert_library_item(user_id: str, book: Dict[str, Any]) -> None:
    raw = get_user_kv(user_id, _TEXTBOOK_LIBRARY_KEY)
    items = _parse_library_payload(raw)
    by_id = {entry.get("textbook_id") or entry.get("id"): entry for entry in items}
    meta = _build_library_meta(book)
    book_id = meta.get("textbook_id")
    if book_id:
        existing = by_id.get(book_id, {})
        merged = {**existing, **meta}
        by_id[book_id] = merged
    updated = [entry for entry in by_id.values() if entry.get("textbook_id") or entry.get("id")]
    set_user_kv(user_id, _TEXTBOOK_LIBRARY_KEY, json.dumps(updated, ensure_ascii=False))


class UserStoragePayload(BaseModel):
    value: str


class RatingSubmitRequest(BaseModel):
    quest_id: str
    is_correct: bool
    tags: List[str] = Field(default_factory=list)
    answer_time: Optional[float] = None
    step_correctness: List[Dict[str, Any]] = Field(default_factory=list)
    submission_id: Optional[str] = None


class RatingResponse(BaseModel):
    rating: float
    ovr: float
    ovr_delta: float
    recent_accuracy: float
    lose_streak: int


class TagRatingItem(BaseModel):
    tag: str
    rating: float
    delta: float
    attempts: int


class TagRatingsResponse(BaseModel):
    tags: List[TagRatingItem]


class WeaknessTagItem(BaseModel):
    tag: str
    count: int
    updated_at: Optional[str] = None


class WeaknessTagsResponse(BaseModel):
    tags: List[WeaknessTagItem] = Field(default_factory=list)


def _get_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing token")
    user_id = decode_token(credentials.credentials)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user_id


@app.on_event("startup")
def _startup() -> None:
    init_db()
    init_exam_db()
    init_user_db()
    init_social_db()
    init_study_group_db()
    init_user_kv_db()
    init_rating_db()
    init_weakness_db()
    init_textbook_db()


@app.post("/auth/anonymous", response_model=TokenResponse)
def issue_anonymous_token() -> TokenResponse:
    user_id = str(uuid.uuid4())
    return TokenResponse(token=create_token(user_id), user_id=user_id)


@app.post("/auth/register", response_model=TokenResponse, status_code=201)
def register(payload: RegisterRequest) -> TokenResponse:
    try:
        user_id = register_user(
            username=payload.username,
            password=payload.password,
            name=payload.name,
            grade=payload.grade,
            track=payload.track,
            subject=payload.subject,
            school=payload.school,
            profile_image=payload.profile_image,
            email=payload.email,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return TokenResponse(token=create_token(user_id), user_id=user_id)


@app.post("/auth/login", response_model=TokenResponse)
def login(payload: LoginRequest) -> TokenResponse:
    user_id = authenticate_user(username=payload.username, password=payload.password)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return TokenResponse(token=create_token(user_id), user_id=user_id)


@app.get("/user/storage/{key}")
def get_user_storage(
    key: str,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, str]:
    value = get_user_kv(user_id, key)
    if value is None:
        raise HTTPException(status_code=404, detail="Not found")
    return {"value": value}


@app.put("/user/storage/{key}")
def put_user_storage(
    key: str,
    payload: UserStoragePayload,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, str]:
    set_user_kv(user_id, key, payload.value)
    return {"status": "ok"}


@app.delete("/user/storage/{key}")
def delete_user_storage(
    key: str,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, str]:
    delete_user_kv(user_id, key)
    return {"status": "ok"}


@app.post("/auth/username/check", response_model=UsernameCheckResponse)
def check_username(payload: UsernameCheckRequest) -> UsernameCheckResponse:
    error = validate_username(payload.username)
    if error:
        return UsernameCheckResponse(available=False, reason=error)
    if get_user_id_by_username(payload.username):
        return UsernameCheckResponse(available=False, reason="중복 미확인!")
    return UsernameCheckResponse(available=True)


@app.post("/auth/validate", response_model=FieldValidationResponse)
def validate_field(payload: FieldValidationRequest) -> FieldValidationResponse:
    field = payload.field.strip().lower()
    value = payload.value or ""
    error: Optional[str] = None
    if field == "name":
        error = validate_name(value)
    elif field == "password":
        error = validate_password(value)
    elif field == "email":
        error = validate_email(value)
    elif field == "school":
        error = validate_school(value)
    elif field == "username":
        error = validate_username(value)
    else:
        raise HTTPException(status_code=400, detail="Unknown validation field")
    return FieldValidationResponse(valid=error is None, reason=error)


@app.post("/social/friends/search", response_model=FriendSearchResponse)
def search_friends(
    payload: FriendSearchRequest,
    user_id: str = Depends(_get_user_id),
) -> FriendSearchResponse:
    users = search_users_by_username(
        payload.query,
        exclude_user_id=user_id,
        limit=payload.limit,
    )
    return FriendSearchResponse(
        users=[FriendProfile(**user) for user in users],
    )


@app.get("/social/friends", response_model=FriendListResponse)
def list_friends(user_id: str = Depends(_get_user_id)) -> FriendListResponse:
    friends = get_friends(user_id)
    return FriendListResponse(
        friends=[FriendProfile(**friend) for friend in friends],
    )


@app.post("/social/friends/add", response_model=FriendProfile)
def add_friend_handler(
    payload: FriendAddRequest,
    user_id: str = Depends(_get_user_id),
) -> FriendProfile:
    friend = get_user_by_username(payload.username)
    if not friend:
        raise HTTPException(status_code=404, detail="User not found")
    friend_id = friend["user_id"]
    if friend_id == user_id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")
    add_friend(user_id, friend_id)
    return FriendProfile(**friend)


@app.post("/social/friends/remove", response_model=FriendProfile)
def remove_friend_handler(
    payload: FriendAddRequest,
    user_id: str = Depends(_get_user_id),
) -> FriendProfile:
    friend = get_user_by_username(payload.username)
    if not friend:
        raise HTTPException(status_code=404, detail="User not found")
    friend_id = friend["user_id"]
    if friend_id == user_id:
        raise HTTPException(status_code=400, detail="Cannot remove yourself")
    remove_friend(user_id, friend_id)
    return FriendProfile(**friend)


@app.post("/social/study-groups", response_model=StudyGroupResponse, status_code=201)
def create_study_group_handler(
    payload: StudyGroupCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupResponse:
    try:
        group = create_study_group(
            name=payload.name,
            description=payload.description,
            max_members=payload.max_members,
            is_public=payload.is_public,
            creator_id=user_id,
            logo_index=payload.logo_index,
            lock_enabled=payload.lock_enabled,
            password=payload.password,
            member_ids=payload.member_ids,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return StudyGroupResponse(**group)


@app.get("/textbooks", response_model=TextbookListResponse)
def list_textbooks_handler(
    category: Optional[str] = None,
    tag: Optional[str] = None,
    user_id: str = Depends(_get_user_id),
) -> TextbookListResponse:
    allowed_ids = _ensure_default_library(user_id)
    if allowed_ids:
        items = list_textbooks(
            category=category,
            tag=tag,
            textbook_ids=allowed_ids,
        )
    else:
        items = []
    return TextbookListResponse(
        textbooks=[TextbookResponse(**item) for item in items],
    )


@app.get("/textbooks/{textbook_id}", response_model=TextbookResponse)
def get_textbook_handler(
    textbook_id: str,
    user_id: str = Depends(_get_user_id),
) -> TextbookResponse:
    allowed_ids = _ensure_default_library(user_id)
    if not allowed_ids:
        raise HTTPException(status_code=403, detail="Textbook not assigned")
    if textbook_id not in allowed_ids:
        raise HTTPException(status_code=403, detail="Textbook not assigned")
    item = get_textbook(textbook_id)
    if not item:
        raise HTTPException(status_code=404, detail="Textbook not found")
    return TextbookResponse(**item)


@app.post("/textbooks", response_model=TextbookResponse, status_code=201)
def create_textbook_handler(
    payload: TextbookCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> TextbookResponse:
    if not payload.title.strip():
        raise HTTPException(status_code=400, detail="title is required")
    profile = get_user_by_id(user_id) or {}
    created_by = (
        (profile.get("name") or "").strip()
        or (profile.get("username") or "").strip()
        or user_id
    )
    created = create_textbook(payload.dict(), created_by)
    _upsert_library_item(user_id, created)
    return TextbookResponse(**created)


def _fetch_kakao_profile(access_token: str) -> Dict[str, Any]:
    req = urllib.request.Request(
        "https://kapi.kakao.com/v2/user/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status != 200:
                raise HTTPException(status_code=401, detail="Invalid Kakao token")
            data = resp.read()
    except urllib.error.HTTPError as exc:
        detail = f"Kakao token rejected ({exc.code})"
        raise HTTPException(status_code=401, detail=detail) from exc
    except urllib.error.URLError as exc:
        raise HTTPException(status_code=502, detail="Failed to reach Kakao API") from exc
    try:
        return json.loads(data.decode("utf-8"))
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=502, detail="Invalid response from Kakao API") from exc


@app.post("/auth/kakao", response_model=TokenResponse)
def login_with_kakao(payload: KakaoLoginRequest) -> TokenResponse:
    profile = _fetch_kakao_profile(payload.access_token)
    kakao_id = profile.get("id")
    if kakao_id is None:
        raise HTTPException(status_code=401, detail="Invalid Kakao token")

    kakao_account = profile.get("kakao_account") or {}
    profile_info = kakao_account.get("profile") or {}
    nickname = (
        profile_info.get("nickname")
        or kakao_account.get("email")
        or f"kakao-{kakao_id}"
    )
    email = kakao_account.get("email")
    profile_image = profile_info.get("profile_image_url")
    username = f"kakao:{kakao_id}"

    existing_user_id = get_user_id_by_username(username)
    if existing_user_id:
        user_id = existing_user_id
    else:
        try:
            user_id = register_user(
                username=username,
                password=uuid.uuid4().hex,
                name=nickname,
                grade="kakao",
                profile_image=profile_image,
                email=email,
            )
        except ValueError:
            # If another request created the user concurrently, fall back to lookup
            user_id = get_user_id_by_username(username)
            if not user_id:
                raise HTTPException(status_code=500, detail="Failed to provision Kakao user")

    return TokenResponse(token=create_token(user_id), user_id=user_id)


@app.post("/exams", response_model=ExamCreateResponse)
async def create_exam_handler(
    payload: ExamCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> ExamCreateResponse:
    if not payload.ranges:
        raise HTTPException(status_code=400, detail="ranges must not be empty")
    ranges = [r.model_dump() for r in payload.ranges]
    exam_id = str(uuid.uuid4())
    try:
        items = plan_exam_items(
            ranges=ranges,
            difficulty_tier=payload.difficulty_tier,
            question_count=payload.question_count,
            paper_type=payload.paper_type,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    create_exam(
        exam_id=exam_id,
        user_id=user_id,
        params=payload.model_dump(),
        status="queued",
    )
    add_exam_items(exam_id, items)
    asyncio.create_task(_run_exam_generation(exam_id))
    return ExamCreateResponse(exam_id=exam_id, status="queued")


@app.get("/exams/{exam_id}", response_model=ExamStatusResponse)
def get_exam_handler(exam_id: str, user_id: str = Depends(_get_user_id)) -> ExamStatusResponse:
    exam = get_exam(exam_id)
    if not exam or exam["user_id"] != user_id:
        raise HTTPException(status_code=404, detail="Exam not found")
    items = get_exam_items(exam_id)
    resolved = _resolve_items(items)
    return ExamStatusResponse(exam_id=exam_id, status=exam["status"], items=resolved)


@app.get("/exams/{exam_id}/pdf")
def download_exam_pdf(
    exam_id: str,
    inline: bool = False,
    token: Optional[str] = None,
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Response:
    if build_exam_pdf is None:
        raise HTTPException(status_code=500, detail="PDF builder not available")

    user_id = None
    if token:
        user_id = decode_token(token)
    elif credentials is not None:
        user_id = decode_token(credentials.credentials)
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing or invalid token")

    exam = get_exam(exam_id)
    if not exam or exam["user_id"] != user_id:
        raise HTTPException(status_code=404, detail="Exam not found")
    items = get_exam_items(exam_id)
    pdf_bytes = build_exam_pdf(items)
    disposition = "inline" if inline else "attachment"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"{disposition}; filename=exam-{exam_id}.pdf"},
    )


@app.get("/quests", response_model=QuestSearchResponse)
def search_quests_handler(
    hash_tag: Optional[str] = None,
    quest_id: Optional[str] = None,
    text: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
    user_id: str = Depends(_get_user_id),
) -> QuestSearchResponse:
    results = search_quests(
        hash_tag=hash_tag,
        quest_id=quest_id,
        text_query=text,
        page=page,
        page_size=page_size,
    )
    return QuestSearchResponse(**results)


@app.post("/quests/generate", response_model=QuestGenerateResponse)
async def generate_quest_handler(
    payload: QuestGenerateRequest,
    user_id: str = Depends(_get_user_id),
) -> QuestGenerateResponse:
    hash_tags = [tag.strip() for tag in payload.hash_tags if tag.strip()]
    if not hash_tags:
        raise HTTPException(status_code=400, detail="hash_tags must not be empty")
    try:
        async with _GEN_SEMAPHORE:
            storage_data = await asyncio.to_thread(
                make,
                hash_tags,
                payload.solves_count,
                payload.strategy_level,
                payload.branch_conditions,
                payload.reference_quest_id,
                payload.strict_tags,
                payload.seed,
            )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    if not store_data(storage_data):
        raise HTTPException(status_code=500, detail="failed to store quest")

    return QuestGenerateResponse(quest=storage_data)


@app.post("/quests/generate/batch", response_model=ProblemSolveGenerateResponse)
async def generate_quest_batch_handler(
    payload: ProblemSolveGenerateRequest,
    user_id: str = Depends(_get_user_id),
) -> ProblemSolveGenerateResponse:
    hash_tags = [tag.strip() for tag in payload.hash_tags if tag.strip()]
    if not hash_tags:
        raise HTTPException(status_code=400, detail="hash_tags must not be empty")
    try:
        async with _GEN_SEMAPHORE:
            quests = await asyncio.to_thread(
                generate_problem_set,
                hash_tags=hash_tags,
                min_difficulty_tier=payload.min_difficulty_tier,
                max_difficulty_tier=payload.max_difficulty_tier,
                question_count=payload.question_count,
            )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    for quest in quests:
        if not store_data(quest):
            raise HTTPException(status_code=500, detail="failed to store quest")

    return ProblemSolveGenerateResponse(quests=quests)


@app.post("/quests/generate/legacy", response_model=QuestGenerateResponse)
async def generate_quest_legacy_handler(
    payload: QuestGenerateRequest,
    user_id: str = Depends(_get_user_id),
) -> QuestGenerateResponse:
    hash_tags = [tag.strip() for tag in payload.hash_tags if tag.strip()]
    if not hash_tags:
        raise HTTPException(status_code=400, detail="hash_tags must not be empty")
    try:
        async with _GEN_SEMAPHORE:
            storage_data = await asyncio.to_thread(
                make_legacy,
                hash_tags,
                payload.solves_count,
                payload.strategy_level,
                payload.branch_conditions,
                payload.reference_quest_id,
                payload.strict_tags,
                payload.seed,
            )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    if not store_data(storage_data):
        raise HTTPException(status_code=500, detail="failed to store quest")

    return QuestGenerateResponse(quest=storage_data)


@app.post("/csat/cubic", response_model=CubicGenerateResponse)
def generate_csat_cubic(
    payload: CubicGenerateRequest,
    user_id: str = Depends(_get_user_id),
) -> CubicGenerateResponse:
    try:
        result = generate_problem(seed=payload.seed)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    meta = result.get("meta", {}) or {}
    params = meta.get("params", {}) or {}
    solution = _build_cubic_solution_text(params, int(result["answer"]))
    return CubicGenerateResponse(
        problem=str(result["problem"]),
        answer=int(result["answer"]),
        solution=solution,
        meta=meta,
    )


@app.post("/test-chat/message", response_model=TestChatMessageResponse)
def test_chat_message(
    payload: TestChatMessageRequest,
    user_id: str = Depends(_get_user_id),
) -> TestChatMessageResponse:
    try:
        result = build_test_chat_response(payload.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return TestChatMessageResponse(**result)


def _coerce_solve_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    json_fields = {
        "quest_model",
        "hash_tags",
        "recognized_text",
        "writing_events",
        "step_correctness",
        "time_weakness",
        "reference_steps",
        "quest_json",
        "gen_config",
    }
    int_fields = {"problem_index", "problem_count", "reference_flow_count"}
    for key, value in list(payload.items()):
        if key in json_fields and isinstance(value, str):
            try:
                payload[key] = json.loads(value)
            except Exception:
                pass
        if key in int_fields and isinstance(value, str):
            try:
                payload[key] = int(value)
            except Exception:
                pass
    return payload


async def _parse_solve_payload(
    request: Request,
) -> Tuple[Dict[str, Any], Dict[str, bytes]]:
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("multipart/form-data"):
        form = await request.form()
        payload: Dict[str, Any] = {}
        files: Dict[str, bytes] = {}
        for key, value in form.multi_items():
            if isinstance(value, UploadFile):
                files[key] = await value.read()
            else:
                payload[key] = value
        return _coerce_solve_payload(payload), files
    try:
        payload = await request.json()
    except Exception:
        payload = {}
    return _coerce_solve_payload(payload), {}


def _decode_base64_image(value: Any) -> Optional[bytes]:
    if not value:
        return None
    if not isinstance(value, str):
        return None
    try:
        return base64.b64decode(value)
    except Exception:
        return None


def _save_solve_image(
    image_bytes: Optional[bytes],
    *,
    prefix: str,
    user_id: Optional[str],
) -> Optional[str]:
    if not image_bytes:
        return None
    safe_user = (user_id or "anonymous").replace(os.sep, "_")
    stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%S%fZ")
    filename = f"{prefix}_{safe_user}_{stamp}.png"
    path = os.path.join(_ASSETS_DIR, "solve_images", filename)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(image_bytes)
        return path
    except Exception:
        return None


@app.post("/analysis/ocr", response_model=SolveOcrResponse)
async def analyze_ocr(
    request: Request,
    user_id: str = Depends(_get_user_id),
) -> SolveOcrResponse:
    payload, files = await _parse_solve_payload(request)
    student_bytes = files.get("student_work_image") or _decode_base64_image(
        payload.get("student_work_image")
    )
    heatmap_bytes = files.get("heatmap_image") or _decode_base64_image(
        payload.get("heatmap_image")
    )
    _save_solve_image(student_bytes, prefix="student_work", user_id=user_id)
    _save_solve_image(heatmap_bytes, prefix="heatmap", user_id=user_id)
    try:
        result = analyze_pregrade(
            payload,
            student_work_image_bytes=student_bytes,
            heatmap_image_bytes=heatmap_bytes,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return SolveOcrResponse(**result)


@app.post("/analysis/solve", response_model=SolveAnalysisResponse)
async def analyze_solve(
    request: Request,
    user_id: str = Depends(_get_user_id),
) -> SolveAnalysisResponse:
    payload, files = await _parse_solve_payload(request)
    student_bytes = files.get("student_work_image") or _decode_base64_image(
        payload.get("student_work_image")
    )
    problem_bytes = files.get("problem_image") or _decode_base64_image(
        payload.get("problem_image")
    )
    heatmap_bytes = files.get("heatmap_image") or _decode_base64_image(
        payload.get("heatmap_image")
    )
    _save_solve_image(student_bytes, prefix="student_work", user_id=user_id)
    _save_solve_image(problem_bytes, prefix="problem", user_id=user_id)
    _save_solve_image(heatmap_bytes, prefix="heatmap", user_id=user_id)
    try:
        result = analyze_submission(
            payload,
            student_work_image_bytes=student_bytes,
            problem_image_bytes=problem_bytes,
            heatmap_image_bytes=heatmap_bytes,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    try:
        in_panic = result.get("in_panic") or []
        if in_panic:
            quest_json = payload.get("quest_json")
            if isinstance(quest_json, str):
                try:
                    quest_json = json.loads(quest_json)
                except Exception:
                    quest_json = None
            quest_id = payload.get("quest_id")
            quest = quest_json if isinstance(quest_json, dict) else (get_quest(quest_id) if quest_id else None)
            clean_payload = build_clean_payload(quest if isinstance(quest, dict) else None)
            flows = clean_payload.get("flows") or []
            tags: List[str] = []
            for item in in_panic:
                try:
                    idx = int(item)
                except (TypeError, ValueError):
                    continue
                if 0 <= idx < len(flows):
                    tags.extend(flows[idx].get("hash_tag") or [])
            increment_weakness_tags(user_id=user_id, tags=tags)
    except Exception:
        pass
    return SolveAnalysisResponse(**result)


@app.post("/rating/submit", response_model=RatingResponse)
def submit_rating(
    payload: RatingSubmitRequest,
    user_id: str = Depends(_get_user_id),
) -> RatingResponse:
    quest = get_quest(payload.quest_id)
    if not quest:
        raise HTTPException(status_code=404, detail="Quest not found")
    tags = payload.tags
    if not tags:
        tags = (quest.get("info", {}) or {}).get("hash_tag", []) or []
    result = apply_rating_update(
        user_id=user_id,
        quest=quest,
        is_correct=bool(payload.is_correct),
        tags=tags,
        step_correctness=payload.step_correctness,
        answer_time=payload.answer_time,
        submission_id=payload.submission_id,
    )
    return RatingResponse(
        rating=result.rating,
        ovr=result.ovr,
        ovr_delta=result.ovr_delta,
        recent_accuracy=result.recent_accuracy,
        lose_streak=result.lose_streak,
    )


@app.get("/rating/user", response_model=RatingResponse)
def get_my_rating(user_id: str = Depends(_get_user_id)) -> RatingResponse:
    result = fetch_user_rating(user_id)
    return RatingResponse(
        rating=result.rating,
        ovr=result.ovr,
        ovr_delta=result.ovr_delta,
        recent_accuracy=result.recent_accuracy,
        lose_streak=result.lose_streak,
    )


@app.get("/rating/user/{target_user_id}", response_model=RatingResponse)
def get_user_rating(
    target_user_id: str,
    user_id: str = Depends(_get_user_id),
) -> RatingResponse:
    if target_user_id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    result = fetch_user_rating(user_id)
    return RatingResponse(
        rating=result.rating,
        ovr=result.ovr,
        ovr_delta=result.ovr_delta,
        recent_accuracy=result.recent_accuracy,
        lose_streak=result.lose_streak,
    )


@app.get("/rating/tags", response_model=TagRatingsResponse)
def get_tag_ratings(user_id: str = Depends(_get_user_id)) -> TagRatingsResponse:
    items = fetch_tag_ratings(user_id)
    return TagRatingsResponse(
        tags=[TagRatingItem(**item) for item in items],
    )


@app.get("/weakness/tags", response_model=WeaknessTagsResponse)
def get_weakness_tags(user_id: str = Depends(_get_user_id)) -> WeaknessTagsResponse:
    items = list_weakness_tags(user_id)
    return WeaknessTagsResponse(tags=[WeaknessTagItem(**item) for item in items])


def _resolve_items(items: List[Dict[str, Any]]) -> List[ExamItemResponse]:
    resolved: List[ExamItemResponse] = []
    for item in items:
        quest_title = None
        quest_options = None
        question_type = item.get("question_type")
        if item.get("quest_id"):
            quest = get_quest(item["quest_id"])
            if quest:
                quest_title = quest.get("data", {}).get("quest_title")
                question_type = quest.get("data", {}).get("question_type") or question_type
                quest_options = quest.get("data", {}).get("quest_options")
                if item.get("flow_count") is None:
                    item["flow_count"] = len(quest.get("solves", []))
        resolved.append(
            ExamItemResponse(
                item_index=item["item_index"],
                status=item["status"],
                subject_key=item["subject_key"],
                hash_tags=item["hash_tags"],
                difficulty_tier=item["difficulty_tier"],
                solves_count=item["solves_count"],
                strategy_level=item["strategy_level"],
                branch_conditions=item["branch_conditions"],
                question_type=question_type,
                quest_id=item.get("quest_id"),
                flow_count=item.get("flow_count"),
                quest_title=quest_title,
                quest_options=quest_options,
                error=item.get("error"),
            )
        )
    return resolved


def _build_cubic_solution_text(params: Dict[str, Any], answer: int) -> str:
    try:
        r1 = int(params["r1"])
        r2 = int(params["r2"])
        k = int(params["k"])
        m = int(params["m"])
        a = int(params["a"])
    except Exception:
        return f"정답: {answer}"

    return (
        f"f(x)=(x-{r1})(x-{r2})(x-{a})\n"
        f"f''(x)=6x-2({r1}+{r2}+{a})\n"
        f"f''({k})=0 => {r1}+{r2}+{a}=3*{k}\n"
        f"따라서 f({m})={answer}"
    )


async def _run_exam_generation(exam_id: str) -> None:
    update_exam_status(exam_id, "generating")
    items = get_exam_items(exam_id)
    used_quest_ids: set[str] = set()
    used_quest_lock = asyncio.Lock()
    used_codebase_ids: set[int] = set()
    used_codebase_lock = asyncio.Lock()
    failed_items = await _run_exam_batch(
        exam_id,
        items,
        used_quest_ids,
        used_quest_lock,
        used_codebase_ids,
        used_codebase_lock,
        start_status="generating",
        failure_status="retrying",
    )

    if failed_items:
        update_exam_status(exam_id, "retrying")
        await asyncio.sleep(2)
        failed_items = await _run_exam_batch(
            exam_id,
            failed_items,
            used_quest_ids,
            used_quest_lock,
            used_codebase_ids,
            used_codebase_lock,
            start_status="retrying",
            failure_status="failed",
        )

    final_status = "done"
    if failed_items:
        final_status = "failed"
    update_exam_status(exam_id, final_status)


async def _generate_exam_item(
    exam_id: str,
    item: Dict[str, Any],
    used_quest_ids: set[str],
    used_quest_lock: asyncio.Lock,
    used_codebase_ids: set[int],
    used_codebase_lock: asyncio.Lock,
    *,
    start_status: str,
    failure_status: str,
) -> bool:
    item_index = item["item_index"]
    update_exam_item(exam_id, item_index, status=start_status, error="")
    try:
        quest_id: Optional[str] = None
        reserved_quest_id: Optional[str] = None
        if get_total_quest_count() >= 20:
            async with used_quest_lock:
                quest_id = find_reusable_quest(
                    target_tags=item["hash_tags"],
                    min_flow=item["solves_count"],
                    max_flow=item["solves_count"] + max(item["branch_conditions"], 1) + 2,
                    used_quest_ids=used_quest_ids,
                )
                if quest_id:
                    used_quest_ids.add(quest_id)
                    reserved_quest_id = quest_id

        if quest_id:
            quest = get_quest(quest_id)
            if item.get("question_type") == "mcq":
                options = (quest or {}).get("data", {}).get("quest_options") if quest else None
                if not options:
                    quest_id = None
            if quest_id:
                codebase_id = (quest or {}).get("data", {}).get("codebase_id")
                if codebase_id is not None:
                    async with used_codebase_lock:
                        if codebase_id in used_codebase_ids:
                            quest_id = None
                        else:
                            used_codebase_ids.add(codebase_id)
            if quest_id:
                flow_count = len(quest.get("solves", [])) if quest else item["solves_count"]
            else:
                flow_count = None
        else:
            flow_count = None
        if quest_id:
            update_exam_item(
                exam_id,
                item_index,
                status="reused",
                quest_id=quest_id,
                flow_count=flow_count,
            )
            return True
        if reserved_quest_id and quest_id is None:
            async with used_quest_lock:
                used_quest_ids.discard(reserved_quest_id)

        async with used_codebase_lock:
            storage_data = await asyncio.to_thread(
                make,
                item["hash_tags"],
                item["solves_count"],
                item["strategy_level"],
                item["branch_conditions"],
                None,
                False,
                None,
                item.get("question_type"),
                used_codebase_ids,
            )
            codebase_id = (storage_data.get("data") or {}).get("codebase_id")
            if isinstance(codebase_id, int):
                used_codebase_ids.add(codebase_id)
        if not store_data(storage_data):
            raise RuntimeError("failed to store quest")
        quest_id = storage_data["header"]["quest_id"]
        flow_count = len(storage_data.get("solves", []))
        update_exam_item(
            exam_id,
            item_index,
            status="done",
            quest_id=quest_id,
            flow_count=flow_count,
        )
        return True
    except Exception as exc:
        update_exam_item(
            exam_id,
            item_index,
            status=failure_status,
            error=str(exc),
        )
        return False


async def _run_exam_batch(
    exam_id: str,
    items: List[Dict[str, Any]],
    used_quest_ids: set[str],
    used_quest_lock: asyncio.Lock,
    used_codebase_ids: set[int],
    used_codebase_lock: asyncio.Lock,
    *,
    start_status: str,
    failure_status: str,
) -> List[Dict[str, Any]]:
    if not items:
        return []
    tasks = [
        asyncio.create_task(
            _generate_exam_item(
                exam_id,
                item,
                used_quest_ids,
                used_quest_lock,
                used_codebase_ids,
                used_codebase_lock,
                start_status=start_status,
                failure_status=failure_status,
            )
        )
        for item in items
    ]
    results = await asyncio.gather(*tasks)
    return [item for item, ok in zip(items, results) if not ok]
