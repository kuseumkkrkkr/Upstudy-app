import asyncio
import json
import os
import urllib.error
import urllib.request
import uuid
from typing import Any, Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

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
from analysis_service import analyze_submission
from baselines.basemodel import ContentBlocks
from exam_service import plan_exam_items
from generater.make import make
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
    quest_id: Optional[str] = None
    flow_count: Optional[int] = None
    quest_title: Optional[ContentBlocks] = None
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


class QuestGenerateResponse(BaseModel):
    quest: Dict[str, Any]


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
    problem: Optional[str] = None
    problem_index: Optional[int] = None
    problem_count: Optional[int] = None
    hash_tags: List[str] = Field(default_factory=list)
    student_work_image: Optional[str] = None
    recognized_text: List[Dict[str, Any]] = Field(default_factory=list)
    writing_events: List[Dict[str, Any]] = Field(default_factory=list)
    step_correctness: List[Dict[str, Any]] = Field(default_factory=list)
    time_weakness: List[Dict[str, Any]] = Field(default_factory=list)


class SolveAnalysisResponse(BaseModel):
    analysis: str
    recognized_text: List[Dict[str, Any]] = Field(default_factory=list)
    ocr_source: str
    quest_id: Optional[str] = None
    quest_model: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)


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
            )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    if not store_data(storage_data):
        raise HTTPException(status_code=500, detail="failed to store quest")

    return QuestGenerateResponse(quest=storage_data)


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


@app.post("/analysis/solve", response_model=SolveAnalysisResponse)
def analyze_solve(
    payload: SolveAnalysisRequest,
    user_id: str = Depends(_get_user_id),
) -> SolveAnalysisResponse:
    try:
        result = analyze_submission(payload.model_dump())
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
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


def _resolve_items(items: List[Dict[str, Any]]) -> List[ExamItemResponse]:
    resolved: List[ExamItemResponse] = []
    for item in items:
        quest_title = None
        if item.get("quest_id"):
            quest = get_quest(item["quest_id"])
            if quest:
                quest_title = quest.get("data", {}).get("quest_title")
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
                quest_id=item.get("quest_id"),
                flow_count=item.get("flow_count"),
                quest_title=quest_title,
                error=item.get("error"),
            )
        )
    return resolved


async def _run_exam_generation(exam_id: str) -> None:
    update_exam_status(exam_id, "generating")
    items = get_exam_items(exam_id)
    used_quest_ids: set[str] = set()
    used_quest_lock = asyncio.Lock()
    failed_items = await _run_exam_batch(
        exam_id,
        items,
        used_quest_ids,
        used_quest_lock,
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
    *,
    start_status: str,
    failure_status: str,
) -> bool:
    item_index = item["item_index"]
    update_exam_item(exam_id, item_index, status=start_status, error="")
    try:
        quest_id: Optional[str] = None
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

        if quest_id:
            quest = get_quest(quest_id)
            flow_count = len(quest.get("solves", [])) if quest else item["solves_count"]
            update_exam_item(
                exam_id,
                item_index,
                status="reused",
                quest_id=quest_id,
                flow_count=flow_count,
            )
            return True

        storage_data = await asyncio.to_thread(
            make,
            item["hash_tags"],
            item["solves_count"],
            item["strategy_level"],
            item["branch_conditions"],
            None,
            False,
        )
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
                start_status=start_status,
                failure_status=failure_status,
            )
        )
        for item in items
    ]
    results = await asyncio.gather(*tasks)
    return [item for item, ok in zip(items, results) if not ok]
