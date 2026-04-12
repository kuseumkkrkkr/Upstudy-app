import asyncio

import base64

import json

import os

import urllib.error

import urllib.request

import uuid

import threading

import time

from datetime import datetime

from typing import Any, Dict, List, Optional, Set, Tuple



from fastapi import (
    Depends,
    FastAPI,
    HTTPException,
    Request,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
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

from generater.codebase_runner import warmup_sympy_pool

from generater.problem_solve import generate_problem_set

from generater.codebase_store import (

    compute_code_hash,

    count_cached_seeds,

    delete_codebase,

    list_codebase_stats,

    list_agent_logs,

    list_seed_logs,

    load_codebases,

    save_seed_log,

    update_codebase,

)

from generater.seed_validator import run_seed_validation_cycle, validate_codebase

from generater.codebase_repair import repair_codebase

from rating_service import apply_rating_update, fetch_tag_ratings, fetch_user_rating

from storage.exam_storage import (
    add_exam_items,
    create_exam,
    get_exam,
    get_exam_items,
    init_exam_db,
    update_exam_item,
    update_exam_status,
)

from storage.storage import (
    DB_PATH,
    get_quest,
    get_last_store_error,
    init_db,
    search_quests,
    store_data,
)
from user_habit import (
    init_habit_db,
    list_problem_history,
    record_exam_attempt,
    record_problem_attempt,
    record_textbook_view,
)
from storage.solve_history import (
    init_solve_history_db,
    save_solve_history,
    is_latest_fully_correct,
)
from storage.continue_storage import (
    init_continue_db,
    save_strokes as save_continue_strokes,
    delete_strokes as delete_continue_strokes,
    load_strokes as load_continue_strokes,
)
from storage.ox_quiz_storage import (
    count_by_tag as count_ox_by_tag,
    fetch_questions_by_tags,
    insert_questions,
)
from generater.ai_gen import client as gen_client, DEFAULT_MODEL as GEN_DEFAULT_MODEL, COMETAPI_KEY

from storage.social_storage import (
    add_friend,
    append_message,
    are_friends,
    create_friend_request,
    get_friend_request_by_id,
    get_friends,
    get_message_by_id,
    list_conversations,
    get_user_by_id,
    get_user_by_username,
    init_social_db,
    list_friend_requests_for_user,
    list_messages,
    remove_friend,
    search_users_by_username,
    set_friend_request_status,
    delete_conversation,
)
from storage.study_group_storage import init_study_group_db
from study_group import study_group_router

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

# Server chat
from serverchat import (
    get_character as get_serverchat_character,
    get_character_profile as get_serverchat_profile,
    handle_chat_message,
    init as init_serverchat,
    set_character as set_serverchat_character,
)

from test_chat.service import build_test_chat_response



try:

    from pdf_builder import build_exam_pdf

except ImportError:

    build_exam_pdf = None





app = FastAPI()
app.include_router(study_group_router)

security = HTTPBearer(auto_error=False)

_GEN_SEMAPHORE = asyncio.Semaphore(2)

_GEN_STATUS: Dict[str, Dict[str, Any]] = {}

_GEN_STATUS_LOCK = threading.Lock()

_GEN_STATUS_TTL = 300



_WS_CONNECTIONS: Dict[str, List[WebSocket]] = {}
_WS_LOCK = asyncio.Lock()

_HISTORY_KEY = "problem_history_v2"
_HISTORY_WINDOW_SEC = 3 * 24 * 60 * 60
_HISTORY_MAX = 500
_EXAM_SCORE_PREFIX = "exam_score_sheet:"


@app.on_event("startup")
def _startup_event() -> None:
    init_db()
    init_exam_db()
    init_habit_db()
    init_continue_db()
    init_solve_history_db()
    init_weakness_db()
    init_rating_db()
    init_user_db()


def _save_seed_history(user_id: str, entries: List[Dict[str, Any]]) -> None:
    try:
        set_user_kv(user_id, _HISTORY_KEY, json.dumps(entries))
    except Exception:
        # History persistence is best-effort.
        pass


def _load_recent_seed_history(user_id: str) -> Tuple[List[Dict[str, Any]], Dict[int, Set[int]]]:
    raw = get_user_kv(user_id, _HISTORY_KEY)
    entries: List[Dict[str, Any]] = []
    mapping: Dict[int, Set[int]] = {}
    now = int(time.time())
    cutoff = now - _HISTORY_WINDOW_SEC
    dirty = False

    if raw:
        try:
            data = json.loads(raw)
        except Exception:
            data = None
            dirty = True
        if isinstance(data, list):
            for item in data:
                if not isinstance(item, dict):
                    continue
                cb_raw = item.get("codebase_id")
                seed_raw = item.get("seed")
                ts_raw = item.get("ts") or item.get("timestamp")
                try:
                    cb_id = int(cb_raw) if cb_raw is not None else None
                    seed_val = int(seed_raw) if seed_raw is not None else None
                    ts_val = int(ts_raw) if ts_raw is not None else 0
                except Exception:
                    continue
                if cb_id is None or seed_val is None:
                    continue
                if ts_val < cutoff:
                    dirty = True
                    continue
                entries.append({"codebase_id": cb_id, "seed": seed_val, "ts": ts_val})

    for item in entries:
        try:
            cb = int(item.get("codebase_id"))
            sd = int(item.get("seed"))
        except Exception:
            continue
        mapping.setdefault(cb, set()).add(sd)

    if dirty:
        _save_seed_history(user_id, entries)

    return entries, mapping


def _record_seed_history_entry(
    user_id: Optional[str],
    entries: List[Dict[str, Any]],
    mapping: Dict[int, Set[int]],
    codebase_id: Optional[int],
    seed: Optional[int],
) -> None:
    if user_id is None or codebase_id is None or seed is None:
        return
    now = int(time.time())
    entries.append({"codebase_id": int(codebase_id), "seed": int(seed), "ts": now})
    cutoff = now - _HISTORY_WINDOW_SEC
    filtered = [
        item
        for item in entries
        if item.get("codebase_id") is not None
        and item.get("seed") is not None
        and int(item.get("ts", 0)) >= cutoff
    ]
    if len(filtered) > _HISTORY_MAX:
        filtered = filtered[-_HISTORY_MAX:]
    entries[:] = filtered
    mapping.clear()
    for item in entries:
        try:
            cb = int(item.get("codebase_id"))
            sd = int(item.get("seed"))
        except Exception:
            continue
        mapping.setdefault(cb, set()).add(sd)


def _update_exam_score_sheet(
    user_id: str,
    exam_id: str,
    *,
    problem_index: Optional[int],
    problem_count: Optional[int],
    status: List[Dict[str, Any]],
) -> None:
    """Store per-exam score sheet (per problem) for later analysis export."""
    if not exam_id:
        return
    try:
        raw = get_user_kv(user_id, f"{_EXAM_SCORE_PREFIX}{exam_id}") or "[]"
        data = json.loads(raw)
        if not isinstance(data, list):
            data = []
    except Exception:
        data = []
    entry = {
        "problem_index": problem_index,
        "problem_count": problem_count,
        "status": status,
        "updated_at": int(time.time()),
    }
    # replace existing same index
    if problem_index is not None:
        replaced = False
        for i, item in enumerate(data):
            if item.get("problem_index") == problem_index:
                data[i] = entry
                replaced = True
                break
        if not replaced:
            data.append(entry)
    else:
        data.append(entry)
    try:
        set_user_kv(user_id, f"{_EXAM_SCORE_PREFIX}{exam_id}", json.dumps(data))
    except Exception:
        pass


def _is_exam_fully_correct_for_user(exam_id: str, user_id: str) -> bool:
    """
    Determine whether every problem in the exam has been graded correct.
    Uses the persisted score sheet to allow continue-blocking after full completion.
    """
    if not exam_id or not user_id:
        return False
    exam = get_exam(exam_id)
    if not exam or exam.get("user_id") != user_id:
        return False

    params = exam.get("params") or {}
    try:
        total = int(params.get("question_count") or 0)
    except Exception:
        total = 0
    if total <= 0:
        total = len(get_exam_items(exam_id))
    if total <= 0:
        return False

    raw = get_user_kv(user_id, f"{_EXAM_SCORE_PREFIX}{exam_id}") or "[]"
    try:
        sheet = json.loads(raw)
    except Exception:
        sheet = []
    if not isinstance(sheet, list):
        return False

    correct_by_index: dict[int, bool] = {}
    for entry in sheet:
        if not isinstance(entry, dict):
            continue
        idx_raw = entry.get("problem_index")
        try:
            idx = int(idx_raw) if idx_raw is not None else None
        except Exception:
            idx = None
        statuses = entry.get("status")
        if not isinstance(statuses, list) or not statuses:
            continue
        all_correct = all(
            isinstance(item, dict) and str(item.get("status", "")).upper() == "O" for item in statuses
        )
        if all_correct and idx is not None:
            correct_by_index[idx] = True

    return len(correct_by_index) >= total


def _extract_codebase_seed(payload: Dict[str, Any]) -> Tuple[Optional[int], Optional[int]]:
    data = payload.get("data")
    if not isinstance(data, dict):
        return None, None
    cb_raw = data.get("codebase_id")
    seed_raw = data.get("seed")
    try:
        cb_id = int(cb_raw) if cb_raw is not None else None
    except Exception:
        cb_id = None
    try:
        seed_val = int(seed_raw) if seed_raw is not None else None
    except Exception:
        seed_val = None
    return cb_id, seed_val


def _init_gen_status(request_id: str, message: str = "queued") -> None:

    now = int(time.time())

    with _GEN_STATUS_LOCK:

        _GEN_STATUS[request_id] = {

            "status": "queued",

            "message": message,

            "updated_at": now,

            "quest": None,

            "error": None,

        }





def _set_gen_status(

    request_id: str,

    message: str,

    *,

    status: Optional[str] = None,

    quest: Optional[Dict[str, Any]] = None,

    error: Optional[str] = None,

) -> None:

    now = int(time.time())

    with _GEN_STATUS_LOCK:

        state = _GEN_STATUS.get(request_id, {})

        state["message"] = message

        state["status"] = status or state.get("status") or "queued"

        state["updated_at"] = now

        if quest is not None:

            state["quest"] = quest

        if error is not None:

            state["error"] = error

        _GEN_STATUS[request_id] = state



def _get_gen_status(request_id: str) -> Optional[Dict[str, Any]]:

    now = int(time.time())

    with _GEN_STATUS_LOCK:

        expired = [key for key, value in _GEN_STATUS.items() if now - int(value.get("updated_at", 0)) > _GEN_STATUS_TTL]

        for key in expired:

            _GEN_STATUS.pop(key, None)

        return _GEN_STATUS.get(request_id)





_BASE_DIR = os.path.dirname(os.path.abspath(__file__))

_ASSETS_DIR = os.path.join(_BASE_DIR, "assets")

os.makedirs(_ASSETS_DIR, exist_ok=True)



load_env()

_SEED_VALIDATOR_ENABLED = os.environ.get("SEED_VALIDATOR_ENABLED", "0").lower() in ("1", "true", "yes")

_SEED_VALIDATOR_INTERVAL = int(os.environ.get("SEED_VALIDATOR_INTERVAL", "60"))

_SEED_VALIDATOR_BATCH = int(os.environ.get("SEED_VALIDATOR_BATCH", "5"))

_SEED_VALIDATOR_ATTEMPTS = int(os.environ.get("SEED_VALIDATOR_ATTEMPTS", "10"))

_SEED_VALIDATOR_MAX_SUCCESSES = int(os.environ.get("SEED_VALIDATOR_MAX_SUCCESSES", "3"))

_SEED_VALIDATOR_LOCK = asyncio.Lock()



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

    question_count: int = Field(ge=4, le=40)

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

    codebase_id: Optional[int] = None

    seed: Optional[int] = None

    quest_title: Optional[ContentBlocks] = None

    quest_options: Optional[List[ContentBlocks]] = None

    error: Optional[str] = None





class ExamStatusResponse(BaseModel):

    exam_id: str

    status: str

    items: List[ExamItemResponse]


class ExamScoreSheetResponse(BaseModel):
    exam_id: str
    score_sheet: List[Dict[str, Any]] = Field(default_factory=list)





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

    request_id: Optional[str] = None





class QuestGenerateResponse(BaseModel):

    request_id: str

    status: str

    quest: Optional[Dict[str, Any]] = None

    error: Optional[str] = None

    updated_at: Optional[int] = None





class ProblemSolveGenerateRequest(BaseModel):

    hash_tags: List[str]

    min_difficulty_tier: int = Field(ge=1, le=5)

    max_difficulty_tier: int = Field(ge=1, le=5)

    question_count: int = Field(ge=4, le=40)

    strict_tags: bool = False





class ProblemSolveGenerateResponse(BaseModel):

    quests: List[Dict[str, Any]]





class OxQuizQuestion(BaseModel):
    id: Optional[int] = None
    tag: str
    question: str
    answer: bool
    created_at: Optional[int] = None
    created_by: Optional[str] = None


class OxQuizGenerateRequest(BaseModel):
    tags: List[str]
    per_tag: int = Field(default=3, ge=1, le=5)


class OxQuizGenerateResponse(BaseModel):
    questions: List[OxQuizQuestion]


class ProblemHabitItem(BaseModel):
    codebase_id: int
    seed: str
    tags: List[str]
    quest_title: Optional[str] = None
    retry_count: int
    updated_at: str


class ProblemHabitListResponse(BaseModel):
    items: List[ProblemHabitItem]


class ProblemHabitRecordRequest(BaseModel):
    codebase_id: int
    seed: str
    tags: List[str] = []
    quest_title: Optional[str] = None


class ProblemHabitReplayRequest(BaseModel):
    codebase_id: int
    seed: str


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



# Server chat (character chat)
class ServerChatConfigRequest(BaseModel):
    character: str


class ServerChatConfigResponse(BaseModel):
    character: str
    character_name: str


class ServerChatMessageRequest(BaseModel):
    user_message: str
    character: Optional[str] = None
    quest_title: Optional[str] = None
    flow: Optional[str] = None
    ocr: Optional[str] = None
    mode: Optional[str] = Field(default="chat", pattern="^(chat|problem|counseling)$")


class ServerChatMessageResponse(BaseModel):
    assistant_message: str
    affection_score: float
    affection_breakdown: Dict[str, float]
    character: str
    character_name: str
    stats: Dict[str, Any]
    history_size: int
    user_turns: int




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



class ContinueSaveRequest(BaseModel):
    kind: str = Field(pattern="^(problem|exam)$")
    target_id: str
    strokes: List[Any] = Field(default_factory=list)
    forced_exit: bool = True
    completed: bool = False
    allow_back: bool = False  # true when "return to problem" was enabled due to incorrect answer
    device_kind: Optional[str] = None  # "web" | "native" etc., used for retention policy


class ContinueStateResponse(BaseModel):
    target_id: str
    strokes: List[Any] = Field(default_factory=list)
    updated_at: Optional[str] = None
    allow_back: bool = False




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









class FriendRequestCreateRequest(BaseModel):

    username: str

    message: Optional[str] = None




class FriendRequestResponse(BaseModel):

    id: str

    username: str

    direction: str

    status: str

    message: Optional[str] = None

    created_at: str




class FriendRequestListResponse(BaseModel):

    requests: List[FriendRequestResponse]

def _make_friend_request_response(
    request: Dict[str, str],
    *,
    me_user_id: str,
) -> FriendRequestResponse:
    direction = "incoming" if request.get("to_user_id") == me_user_id else "outgoing"
    other_id = request.get("from_user_id") if direction == "incoming" else request.get("to_user_id")
    other = get_user_by_id(other_id) or {}
    username = other.get("username") or other_id or ""
    return FriendRequestResponse(
        id=request.get("id") or "",
        username=username,
        direction=direction,
        status=request.get("status") or "pending",
        message=request.get("message") or "",
        created_at=request.get("created_at") or datetime.utcnow().isoformat(timespec="seconds") + "Z",
    )
class FriendListResponse(BaseModel):

    friends: List[FriendProfile]





class DirectMessagePayload(BaseModel):
    peer: str
    text: str


class DirectMessageResponse(BaseModel):
    id: str
    from_: str = Field(alias="from")
    to: str
    text: str
    created_at: str
    is_mine: bool


class DirectMessageListResponse(BaseModel):
    messages: List[DirectMessageResponse]




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


async def _register_ws(user_id: str, websocket: WebSocket) -> None:
    await websocket.accept()
    async with _WS_LOCK:
        _WS_CONNECTIONS.setdefault(user_id, []).append(websocket)

async def _unregister_ws(user_id: str, websocket: WebSocket) -> None:
    async with _WS_LOCK:
        conns = _WS_CONNECTIONS.get(user_id, [])
        if websocket in conns:
            conns.remove(websocket)
        if not conns:
            _WS_CONNECTIONS.pop(user_id, None)

async def _send_ws(user_id: str, payload: Dict[str, Any]) -> None:
    message = json.dumps(payload)
    async with _WS_LOCK:
        conns = list(_WS_CONNECTIONS.get(user_id, []))
    for ws in conns:
        try:
            await ws.send_text(message)
        except Exception:
            try:
                await ws.close()
            except Exception:
                pass
            await _unregister_ws(user_id, ws)

def _notify_user(user_id: str, payload: Dict[str, Any]) -> None:
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            return
    try:
        loop.create_task(_send_ws(user_id, payload))
    except RuntimeError:
        pass

@app.websocket("/ws/social")
async def social_websocket(websocket: WebSocket) -> None:
    token = websocket.query_params.get("token") or websocket.headers.get("Authorization") or ""
    if token.startswith("Bearer "):
        token = token[7:]
    user_id = decode_token(token)
    if not user_id:
        await websocket.close(code=1008)
        return
    await _register_ws(user_id, websocket)
    try:
        while True:
            try:
                await websocket.receive_text()
            except WebSocketDisconnect:
                break
    finally:
        await _unregister_ws(user_id, websocket)

async def _seed_validator_loop() -> None:

    while True:

        if _SEED_VALIDATOR_ENABLED:

            async with _SEED_VALIDATOR_LOCK:

                try:

                    await asyncio.to_thread(

                        run_seed_validation_cycle,

                        max_codebases=_SEED_VALIDATOR_BATCH,

                        attempts_per_codebase=_SEED_VALIDATOR_ATTEMPTS,

                        max_successes_per_codebase=_SEED_VALIDATOR_MAX_SUCCESSES,

                    )

                except Exception:

                    pass

        await asyncio.sleep(_SEED_VALIDATOR_INTERVAL)





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
    init_serverchat()

    try:

        warmup_sympy_pool()

    except Exception:

        pass

    asyncio.create_task(_seed_validator_loop())





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

        return UsernameCheckResponse(available=False, reason="중복 미확??")

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






@app.get("/social/friend-requests", response_model=FriendRequestListResponse)
def list_friend_requests(user_id: str = Depends(_get_user_id)) -> FriendRequestListResponse:
    requests = list_friend_requests_for_user(user_id)
    return FriendRequestListResponse(
        requests=[
            _make_friend_request_response(request=req, me_user_id=user_id)
            for req in requests
        ]
    )

@app.post("/social/friend-requests", response_model=FriendRequestResponse, status_code=201)
def create_friend_request_handler(
    payload: FriendRequestCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> FriendRequestResponse:
    target = get_user_by_username(payload.username)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    target_id = target["user_id"]
    if target_id == user_id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")
    if are_friends(user_id, target_id):
        raise HTTPException(status_code=409, detail="Already friends")
    created = create_friend_request(
        from_user_id=user_id,
        to_user_id=target_id,
        message=payload.message,
    )
    response = _make_friend_request_response(created, me_user_id=user_id)
    receiver_payload = _make_friend_request_response(created, me_user_id=target_id)
    _notify_user(target_id, {"type": "friend_request", "payload": receiver_payload.model_dump()})
    return response

@app.post("/social/friend-requests/{request_id}/accept", response_model=FriendProfile)
def accept_friend_request(
    request_id: str,
    user_id: str = Depends(_get_user_id),
) -> FriendProfile:
    request = get_friend_request_by_id(request_id)
    if not request or request.get("to_user_id") != user_id:
        raise HTTPException(status_code=404, detail="Request not found")
    updated = set_friend_request_status(request_id, "accepted") or request
    add_friend(user_id, request["from_user_id"])
    other = get_user_by_id(request["from_user_id"])
    if other:
        payload = _make_friend_request_response(
            updated,
            me_user_id=request["from_user_id"],
        )
        _notify_user(
            other["user_id"],
            {"type": "friend_request_accepted", "payload": payload.model_dump()},
        )
        return FriendProfile(**other)
    raise HTTPException(status_code=404, detail="User not found")

@app.post("/social/friend-requests/{request_id}/decline", response_model=FriendRequestResponse)
def decline_friend_request(
    request_id: str,
    user_id: str = Depends(_get_user_id),
) -> FriendRequestResponse:
    request = get_friend_request_by_id(request_id)
    if not request or request.get("to_user_id") != user_id:
        raise HTTPException(status_code=404, detail="Request not found")
    updated = set_friend_request_status(request_id, "declined")
    response = _make_friend_request_response(updated, me_user_id=user_id)
    declined_payload = _make_friend_request_response(
        updated,
        me_user_id=request["from_user_id"],
    )
    _notify_user(
        request["from_user_id"],
        {"type": "friend_request_declined", "payload": declined_payload.model_dump()},
    )
    return response


@app.post("/social/friend-requests/{request_id}/cancel", response_model=FriendRequestResponse)
def cancel_friend_request(
    request_id: str,
    user_id: str = Depends(_get_user_id),
) -> FriendRequestResponse:
    request = get_friend_request_by_id(request_id)
    if not request or request.get("from_user_id") != user_id:
        raise HTTPException(status_code=404, detail="Request not found")
    updated = set_friend_request_status(request_id, "cancelled") or request
    response = _make_friend_request_response(updated, me_user_id=user_id)
    cancelled_payload = _make_friend_request_response(
        updated,
        me_user_id=request["to_user_id"],
    )
    _notify_user(
        request["to_user_id"],
        {"type": "friend_request_cancelled", "payload": cancelled_payload.model_dump()},
    )
    return response

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

    if payload.question_count < 4 or payload.question_count > 40:
        raise HTTPException(status_code=400, detail="question_count must be between 4 and 40")

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
    asyncio.create_task(_run_exam_generation(exam_id, user_id))
    return ExamCreateResponse(exam_id=exam_id, status="queued")





@app.get("/exams/{exam_id}", response_model=ExamStatusResponse)

def get_exam_handler(exam_id: str, user_id: str = Depends(_get_user_id)) -> ExamStatusResponse:

    exam = get_exam(exam_id)

    if not exam or exam["user_id"] != user_id:

        raise HTTPException(status_code=404, detail="Exam not found")

    items = get_exam_items(exam_id)
    missing = [item for item in items if item.get("codebase_id") is None or item.get("seed") is None]
    if missing and exam.get("status") not in {"generating", "retrying", "queued"}:
        # Auto-heal: requeue exam generation to fill missing codebase/seed.
        update_exam_status(exam_id, "retrying")
        try:
            asyncio.get_event_loop().create_task(_run_exam_generation(exam_id, user_id))
        except RuntimeError:
            # If no running loop (unlikely in FastAPI), fall back to background thread.
            threading.Thread(target=asyncio.run, args=(_run_exam_generation(exam_id, user_id),), daemon=True).start()
        exam = get_exam(exam_id) or exam  # refresh status for response

    resolved = _resolve_items(items)

    return ExamStatusResponse(exam_id=exam_id, status=exam["status"], items=resolved)


@app.get("/exams/{exam_id}/score", response_model=ExamScoreSheetResponse)
def get_exam_score_sheet(exam_id: str, user_id: str = Depends(_get_user_id)) -> ExamScoreSheetResponse:
    exam = get_exam(exam_id)
    if not exam or exam["user_id"] != user_id:
        raise HTTPException(status_code=404, detail="Exam not found")
    raw = get_user_kv(user_id, f"{_EXAM_SCORE_PREFIX}{exam_id}")
    try:
        sheet = json.loads(raw) if raw else []
        if not isinstance(sheet, list):
            sheet = []
    except Exception:
        sheet = []
    return ExamScoreSheetResponse(exam_id=exam_id, score_sheet=sheet)





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





@app.get("/quests/generate/status")

def quest_generate_status(request_id: str) -> Dict[str, Any]:

    status = _get_gen_status(request_id)

    if not status:

        return {

            "request_id": request_id,

            "status": None,

            "message": None,

            "updated_at": None,

            "quest": None,

            "error": None,

        }

    return {"request_id": request_id, **status}





async def _run_quest_generation_task(

    request_id: str,

    payload: QuestGenerateRequest,

    user_id: str,

) -> None:

    hash_tags = [tag.strip() for tag in payload.hash_tags if tag.strip()]

    if not hash_tags:

        _set_gen_status(

            request_id,

            "hash_tags must not be empty",

            status="failed",

            error="hash_tags must not be empty",

        )

        return



    def _status_cb(message: str) -> None:

        _set_gen_status(request_id, message, status="generating")



    try:

        _set_gen_status(request_id, "generating", status="generating")

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

                None,

                None,

                _status_cb,

            )

        if not store_data(storage_data):

            detail = get_last_store_error() or "failed to store quest"

            _set_gen_status(

                request_id,

                detail,

                status="failed",

                error=detail,

            )

            return



        _set_gen_status(

            request_id,

            "done",

            status="done",

            quest=storage_data,

        )

    except ValueError as exc:

        _set_gen_status(

            request_id,

            str(exc),

            status="failed",

            error=str(exc),

        )

    except Exception as exc:

        _set_gen_status(

            request_id,

            str(exc),

            status="failed",

            error=str(exc),

        )





@app.post("/quests/generate", response_model=QuestGenerateResponse)

async def generate_quest_handler(

    payload: QuestGenerateRequest,

    user_id: str = Depends(_get_user_id),

) -> QuestGenerateResponse:

    hash_tags = [tag.strip() for tag in payload.hash_tags if tag.strip()]

    if not hash_tags:

        raise HTTPException(status_code=400, detail="hash_tags must not be empty")

    request_id = payload.request_id or str(uuid.uuid4())

    _init_gen_status(request_id, "queued")

    asyncio.create_task(_run_quest_generation_task(request_id, payload, user_id))

    return QuestGenerateResponse(

        request_id=request_id,

        status="queued",

        quest=None,

        error=None,

        updated_at=int(time.time()),

    )





@app.post("/quests/generate/batch", response_model=ProblemSolveGenerateResponse)

async def generate_quest_batch_handler(

    payload: ProblemSolveGenerateRequest,

    user_id: str = Depends(_get_user_id),

) -> ProblemSolveGenerateResponse:

    hash_tags = [tag.strip() for tag in payload.hash_tags if tag.strip()]

    if not hash_tags:

        raise HTTPException(status_code=400, detail="hash_tags must not be empty")

    history_entries, history_map = _load_recent_seed_history(user_id)

    try:

        async with _GEN_SEMAPHORE:

            quests = await asyncio.to_thread(

                generate_problem_set,

                hash_tags=hash_tags,

                min_difficulty_tier=payload.min_difficulty_tier,

                max_difficulty_tier=payload.max_difficulty_tier,

                question_count=payload.question_count,

                recent_codebase_seeds={key: list(value) for key, value in history_map.items()},

            )

    except ValueError as exc:

        raise HTTPException(status_code=400, detail=str(exc)) from exc

    except Exception as exc:

        raise HTTPException(status_code=500, detail=str(exc)) from exc



    for quest in quests:

        if not store_data(quest):

            detail = get_last_store_error() or "failed to store quest"

            raise HTTPException(status_code=500, detail=detail)

        cb_id, seed_val = _extract_codebase_seed(quest)
        _record_seed_history_entry(user_id, history_entries, history_map, cb_id, seed_val)

    _save_seed_history(user_id, history_entries)



    return ProblemSolveGenerateResponse(quests=quests)





def _dummy_ox_questions(tag: str, start_index: int, count: int) -> List[Tuple[str, bool]]:
    qa: List[Tuple[str, bool]] = []
    for i in range(count):
        n = start_index + i + 1
        question = (
            f"{tag} OX #{n}: {tag}의 핵심 정의가 올바르게 서술되었다. "
            f"(예시 수식: ∫_0^1 x^{n} dx = 1/{n+1})"
        )
        answer = n % 2 == 0
        qa.append((question, answer))
    return qa


def _generate_ox_questions_with_ai(tag: str, need: int) -> List[Tuple[str, bool]]:
    if need <= 0:
        return []
    if not COMETAPI_KEY:
        # fallback to dummy if key missing
        return _dummy_ox_questions(tag, 0, need)

    prompt = (
        "You are generating concise conceptual OX (true/false) questions for Korean high school study tags.\n"
        "Rules:\n"
        f"- Tag: {tag}\n"
        "- Output JSON: {\"items\":[{\"question\":\"...\",\"answer\":true|false}]}\n"
        "- Provide exactly {need} items.\n"
        "- Keep each question short (<=120 chars) and conceptual, no calculation steps, no numbers-heavy.\n"
        "- If math, you may include LaTeX snippets (wrap as plain text, not code fences).\n"
        "- Avoid duplicate meaning within this batch. Language: Korean."
    )
    try:
        response = gen_client.models.generate_content(
            model=GEN_DEFAULT_MODEL,
            contents=prompt,
            config={
                "response_mime_type": "application/json",
                "response_json_schema": {
                    "type": "object",
                    "properties": {
                        "items": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "question": {"type": "string"},
                                    "answer": {"type": "boolean"},
                                },
                                "required": ["question", "answer"],
                            },
                        }
                    },
                    "required": ["items"],
                },
            },
        )
        data_text = response.text or ""
        try:
            parsed = json.loads(data_text)
        except json.JSONDecodeError:
            parsed = {}
        items = parsed.get("items") if isinstance(parsed, dict) else None
        qa: List[Tuple[str, bool]] = []
        if isinstance(items, list):
            for entry in items:
                if not isinstance(entry, dict):
                    continue
                q = entry.get("question")
                a = entry.get("answer")
                if isinstance(q, str) and isinstance(a, bool):
                    qa.append((q.strip(), a))
                    if len(qa) >= need:
                        break
        if not qa:
            qa = _dummy_ox_questions(tag, 0, need)
        return qa
    except Exception:
        return _dummy_ox_questions(tag, 0, need)


@app.post("/ox_quiz/generate", response_model=OxQuizGenerateResponse)
def generate_ox_quiz_handler(
    payload: OxQuizGenerateRequest,
    user_id: str = Depends(_get_user_id),
) -> OxQuizGenerateResponse:
    tags = [tag.strip() for tag in payload.tags if tag and tag.strip()]
    if not tags:
        raise HTTPException(status_code=400, detail="tags must not be empty")
    per_tag = max(1, min(payload.per_tag, 5))

    for tag in tags:
        existing = count_ox_by_tag(tag)
        remaining_capacity = max(0, 50 - existing)
        need = min(per_tag, remaining_capacity)
        if need > 0:
            qa = _generate_ox_questions_with_ai(tag, need)
            insert_questions(tag=tag, qa_list=qa, created_by=user_id)

    items = fetch_questions_by_tags(tags, per_tag_limit=per_tag)
    return OxQuizGenerateResponse(
        questions=[OxQuizQuestion(**item) for item in items]
    )


@app.get("/ox_quiz", response_model=OxQuizGenerateResponse)
def list_ox_quiz_handler(
    tags: str,
    per_tag: int = 3,
    user_id: str = Depends(_get_user_id),  # noqa: ARG001 - reserved for future logging
) -> OxQuizGenerateResponse:
    tag_list = [tag.strip() for tag in tags.split(",") if tag.strip()]
    if not tag_list:
        raise HTTPException(status_code=400, detail="tags must not be empty")
    per_tag_safe = max(1, min(per_tag, 5))
    items = fetch_questions_by_tags(tag_list, per_tag_limit=per_tag_safe)
    return OxQuizGenerateResponse(
        questions=[OxQuizQuestion(**item) for item in items]
    )


@app.post("/habit/problem", response_model=ProblemHabitItem, status_code=201)
def record_problem_habit(
    payload: ProblemHabitRecordRequest,
    user_id: str = Depends(_get_user_id),
) -> ProblemHabitItem:
    init_habit_db()
    stored = record_problem_attempt(
        user_id=user_id,
        codebase_id=payload.codebase_id,
        seed=str(payload.seed),
        tags_json=json.dumps(payload.tags, ensure_ascii=False),
        quest_title=payload.quest_title or "",
    )
    return ProblemHabitItem(
        codebase_id=stored["codebase_id"],
        seed=str(stored["seed"]),
        tags=json.loads(stored["tags"] or "[]"),
        quest_title=stored["quest_title"],
        retry_count=stored["retry_count"],
        updated_at=stored["updated_at"],
    )


@app.get("/habit/problem", response_model=ProblemHabitListResponse)
def list_problem_habit(
    days: int = 60,
    tag: Optional[str] = None,
    limit: int = 200,
    user_id: str = Depends(_get_user_id),
) -> ProblemHabitListResponse:
    init_habit_db()
    days = max(1, min(days, 60))
    limit = max(1, min(limit, 500))
    items = list_problem_history(
        user_id=user_id, days=days, tag_filter=tag, limit=limit
    )
    return ProblemHabitListResponse(
        items=[
            ProblemHabitItem(
                codebase_id=it["codebase_id"],
                seed=str(it["seed"]),
                tags=json.loads(it["tags"] or "[]"),
                quest_title=it["quest_title"],
                retry_count=it["retry_count"],
                updated_at=it["updated_at"],
            )
            for it in items
        ]
    )


@app.post("/habit/problem/replay")
def replay_problem_habit(
    payload: ProblemHabitReplayRequest,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, Any]:
    # Try to find an exact quest stored with the same codebase/seed
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT quest_id FROM quest_data
        WHERE codebase_id = ? AND seed = ?
        ORDER BY rowid DESC LIMIT 1
        """,
        (payload.codebase_id, payload.seed),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="No quest found for this seed")
    quest = get_quest(row[0])
    if not quest:
        raise HTTPException(status_code=404, detail="Quest data missing")
    return quest


@app.post("/quests/generate/legacy", response_model=QuestGenerateResponse)

async def generate_quest_legacy_handler(

    payload: QuestGenerateRequest,

    user_id: str = Depends(_get_user_id),

) -> QuestGenerateResponse:
    # Legacy 생성은 더 이상 지원하지 않음
    raise HTTPException(status_code=410, detail="legacy generation is no longer supported")









class AdminSeedStatusResponse(BaseModel):

    enabled: bool

    interval_seconds: int

    batch_size: int

    attempts_per_codebase: int

    max_successes_per_codebase: int





@app.get("/admin/seed/status", response_model=AdminSeedStatusResponse)

def admin_seed_status() -> AdminSeedStatusResponse:

    return AdminSeedStatusResponse(

        enabled=_SEED_VALIDATOR_ENABLED,

        interval_seconds=_SEED_VALIDATOR_INTERVAL,

        batch_size=_SEED_VALIDATOR_BATCH,

        attempts_per_codebase=_SEED_VALIDATOR_ATTEMPTS,

        max_successes_per_codebase=_SEED_VALIDATOR_MAX_SUCCESSES,

    )





@app.get("/admin/seed/toggle")

def admin_seed_toggle(enabled: int = 1) -> Dict[str, Any]:

    global _SEED_VALIDATOR_ENABLED

    _SEED_VALIDATOR_ENABLED = bool(int(enabled))

    return {"enabled": _SEED_VALIDATOR_ENABLED}





@app.get("/admin/seed/run")

async def admin_seed_run() -> Dict[str, Any]:

    async with _SEED_VALIDATOR_LOCK:

        result = await asyncio.to_thread(

            run_seed_validation_cycle,

            max_codebases=_SEED_VALIDATOR_BATCH,

            attempts_per_codebase=_SEED_VALIDATOR_ATTEMPTS,

            max_successes_per_codebase=_SEED_VALIDATOR_MAX_SUCCESSES,

        )

    return result





def _render_admin_codebases(rows: List[Dict[str, Any]]) -> str:

    header = """

    <html><head><meta charset="utf-8"><title>Codebase Admin</title>

    <style>

      body { font-family: Arial, sans-serif; padding: 20px; }

      table { border-collapse: collapse; width: 100%; }

      th, td { border: 1px solid #ddd; padding: 8px; font-size: 13px; }

      th { background: #f3f3f3; text-align: left; }

      .ok { color: #0b7a2b; font-weight: 600; }

      .warning { color: #b36b00; font-weight: 600; }

      .disabled { color: #b00020; font-weight: 600; }

      .meta { color: #666; font-size: 12px; }

      .actions a { margin-right: 8px; }

      #diffModal { position: fixed; inset: 0; background: rgba(0,0,0,0.45); display: none; align-items: center; justify-content: center; }

      #diffBox { background: #fff; padding: 16px; width: 90%; max-width: 1000px; max-height: 80vh; overflow: auto; border-radius: 8px; }

      #diffBox pre { white-space: pre-wrap; font-size: 12px; }

    </style></head><body>

    """

    controls = f"""

    <h2>Seed Validator</h2>

    <div class="meta">enabled: {_SEED_VALIDATOR_ENABLED} | interval: {_SEED_VALIDATOR_INTERVAL}s | batch: {_SEED_VALIDATOR_BATCH} | attempts: {_SEED_VALIDATOR_ATTEMPTS} | max_successes: {_SEED_VALIDATOR_MAX_SUCCESSES}</div>

    <div style="margin:8px 0;">

      <a href="/admin/seed/toggle?enabled=1">Enable</a> |

      <a href="/admin/seed/toggle?enabled=0">Disable</a> |

      <a href="/admin/seed/run">Run Once</a>

    </div>

    <script>

      async function runValidate(codebaseId) {{

        const input = prompt('검??????????, '10');

        if (!input) return;

        const attempts = parseInt(input, 10);

        if (!attempts || attempts < 1) {{

          alert('?????????????');

          return;

        }}

        const url = `/admin/seed/validate?codebase_id=${{codebaseId}}&attempts=${{attempts}}`;

        const res = await fetch(url, {{ method: 'POST' }});

        const payload = await res.json();

        if (!res.ok) {{

          alert(payload.detail || '검????);

          return;

        }}

        alert(`검??? attempts=${{payload.attempts}} successes=${{payload.successes}} cached=${{payload.cached_seeds}}`);

        location.reload();

      }}

      async function deleteCodebase(codebaseId) {{

        if (!confirm(`코드베이??#${{codebaseId}} ??????`)) return;

        const url = `/admin/codebases/delete?codebase_id=${{codebaseId}}`;

        const res = await fetch(url, {{ method: 'POST' }});

        const payload = await res.json();

        if (!res.ok) {{

          alert(payload.detail || '?? ???);

          return;

        }}

        location.reload();

      }}

      async function repairCodebase(codebaseId) {{

        const url = `/admin/codebases/repair?codebase_id=${{codebaseId}}`;

        const res = await fetch(url, {{ method: 'POST' }});

        const payload = await res.json();

        if (!res.ok) {{

          alert(payload.detail || '??????);

          return;

        }}

        showDiff(payload.diff || '', payload.error_message || '');

      }}

      function showDiff(diffText, errorMessage) {{

        const modal = document.getElementById('diffModal');

        const diff = document.getElementById('diffContent');

        const err = document.getElementById('diffError');

        err.textContent = errorMessage ? `?? ${errorMessage}` : '';

        diff.textContent = diffText || '(diff ???';

        modal.style.display = 'flex';

      }}

      function closeDiff() {{

        const modal = document.getElementById('diffModal');

        modal.style.display = 'none';

      }}

      function refreshPage() {{

        location.reload();

      }}

    </script>

    <h2>Codebases</h2>

    <table>

      <tr>

        <th>ID</th><th>Name</th><th>Status</th><th>Attempts</th><th>Successes</th><th>Success %</th><th>Cached Seeds</th><th>Difficulty</th><th>Tags</th><th>Created</th><th>Actions</th>

      </tr>

    """

    rows_html = []

    for row in rows:

        status = row.get("status", "")

        rate = row.get("success_rate")

        rate_text = f"{rate:.1f}" if isinstance(rate, (int, float)) else "-"

        tags = ", ".join(row.get("tags") or [])

        entry_id = row.get("id")

        actions = ""

        if entry_id is not None:

          actions = (

            f"<span class='actions'>"

            f"<a href='#' onclick='runValidate({entry_id});return false;'>Validate</a>"

            f"<a href='#' onclick='deleteCodebase({entry_id});return false;'>Delete</a>"

            f"<a href='#' onclick='repairCodebase({entry_id});return false;'>Repair</a>"

            f"</span>"

          )

        rows_html.append(

            f"<tr><td>{row.get('id')}</td><td>{row.get('name')}</td><td class='{status}'>{status}</td>"

            f"<td>{row.get('attempts')}</td><td>{row.get('successes')}</td><td>{rate_text}</td>"

            f"<td>{row.get('cached_seeds')}</td><td>{row.get('difficulty')}</td><td>{tags}</td><td>{row.get('created_at')}</td><td>{actions}</td></tr>"

        )

    footer = """

    </table>

    <div id="diffModal" onclick="closeDiff()">

      <div id="diffBox" onclick="event.stopPropagation()">

        <div style="display:flex; justify-content: space-between; align-items:center; margin-bottom:8px;">

          <strong>Repair Diff</strong>

          <div>

            <button onclick="refreshPage()">????</button>

            <button onclick="closeDiff()">??</button>

          </div>

        </div>

        <div id="diffError" class="meta" style="margin-bottom:8px;"></div>

        <pre id="diffContent"></pre>

      </div>

    </div>

    </body></html>

    """

    return header + controls + "\n".join(rows_html) + footer





@app.get("/admin/codebases")

def admin_codebases() -> Response:

    rows = list_codebase_stats(auto_delete_disabled=True)

    html = _render_admin_codebases(rows)

    return Response(content=html, media_type="text/html")





@app.get("/admin/codebases.json")

def admin_codebases_json() -> Dict[str, Any]:

    return {"codebases": list_codebase_stats(auto_delete_disabled=True)}





@app.get("/admin/seed/logs")

def admin_seed_logs(codebase_id: Optional[int] = None, limit: int = 200) -> Dict[str, Any]:

    return {"logs": list_seed_logs(codebase_id=codebase_id, limit=limit)}



@app.get("/admin/agent/logs")

def admin_agent_logs(codebase_id: Optional[int] = None, limit: int = 200) -> Dict[str, Any]:

    return {"logs": list_agent_logs(codebase_id=codebase_id, limit=limit)}







@app.post("/admin/codebases/delete")

def admin_codebases_delete(codebase_id: int) -> Dict[str, Any]:

    delete_codebase(codebase_id)

    return {"deleted": True, "codebase_id": codebase_id}





@app.post("/admin/codebases/repair")

def admin_codebases_repair(codebase_id: int) -> Dict[str, Any]:

    codebases = load_codebases()

    entry = next((cb for cb in codebases if cb.get("id") == codebase_id), None)

    if entry is None:

        raise HTTPException(status_code=404, detail="codebase not found")



    logs = list_seed_logs(codebase_id=codebase_id, limit=20)

    error_message = None

    for log in logs:

        if log.get("status") != "success" and log.get("error_message"):

            error_message = log.get("error_message")

            break

    if not error_message:

        raise HTTPException(status_code=400, detail="no error log available")



    result = repair_codebase(

        prompt=entry.get("prompt") or "",

        code_text=entry.get("code") or "",

        error_message=error_message,

    )

    update_codebase(codebase_id, result["code"])

    code_hash = compute_code_hash(result.get("code") or "")

    save_seed_log(

        codebase_id=codebase_id,

        code_hash=code_hash,

        seed=None,

        status="repair",

        error_type="Repair",

        error_message=error_message,

        stage="repair",

        elapsed_ms=None,

        source="admin",

    )

    return {

        "repaired": True,

        "codebase_id": codebase_id,

        "diff": result.get("diff"),

        "error_message": error_message,

    }





@app.post("/admin/seed/validate")

def admin_seed_validate(codebase_id: int, attempts: int = 10) -> Dict[str, Any]:

    if attempts < 1:

        raise HTTPException(status_code=400, detail="attempts must be >= 1")

    codebases = load_codebases()

    entry = next((cb for cb in codebases if cb.get("id") == codebase_id), None)

    if entry is None:

        raise HTTPException(status_code=404, detail="codebase not found")

    result = validate_codebase(

        entry,

        attempts_per_codebase=attempts,

        max_successes_per_codebase=attempts,

        source="admin",

    )

    code_hash = compute_code_hash(entry.get("code") or "")

    cached = count_cached_seeds(codebase_id, code_hash)

    return {

        "attempts": result.get("attempts", 0),

        "successes": result.get("successes", 0),

        "cached_seeds": cached,

    }





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





@app.get("/serverchat/config", response_model=ServerChatConfigResponse)
def serverchat_get_config(user_id: str = Depends(_get_user_id)) -> ServerChatConfigResponse:
    profile = get_serverchat_profile(user_id)
    return ServerChatConfigResponse(
        character=profile.get("character", "female"),
        character_name=profile.get("character_name", ""),
    )


@app.put("/serverchat/config", response_model=ServerChatConfigResponse)
def serverchat_set_config(
    payload: ServerChatConfigRequest,
    user_id: str = Depends(_get_user_id),
) -> ServerChatConfigResponse:
    character = set_serverchat_character(user_id, payload.character)
    return ServerChatConfigResponse(character=character)


@app.post("/serverchat/message", response_model=ServerChatMessageResponse)
def serverchat_message(
    payload: ServerChatMessageRequest,
    user_id: str = Depends(_get_user_id),
) -> ServerChatMessageResponse:
    if not payload.user_message.strip():
        raise HTTPException(status_code=400, detail="user_message is required")
    try:
        result = handle_chat_message(
            user_id=user_id,
            user_message=payload.user_message.strip(),
            character=payload.character,
            quest_title=payload.quest_title,
            flow=payload.flow,
            ocr=payload.ocr,
            mode=payload.mode or "chat",
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return ServerChatMessageResponse(**result)



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

    # 이어하기 종료 조건: 모든 단계가 정답인 경우에만 이어하기 삭제
    try:
        kind = "exam" if payload.get("exam_id") else "problem"
        target_id = payload.get("exam_id") or payload.get("quest_id") or "unknown"
        status_list = result.get("status") or []
        all_correct = status_list and all(
            isinstance(item, dict) and str(item.get("status", "")).upper() == "O" for item in status_list
        )
        if all_correct:
            delete_continue_strokes(user_id=user_id, kind=kind, target_id=target_id)
    except Exception:
        pass

    try:
        # Persist solve history for weakness/review (full for 30d, compressed afterwards)
        kind = "exam" if payload.get("exam_id") else "problem"
        codebase_id, seed_val = _extract_codebase_seed(payload)
        delete_after_max = True
        device_kind = payload.get("device_kind") or payload.get("data", {}).get("device_kind")
        local_storage_flag = payload.get("local_storage")
        if isinstance(local_storage_flag, bool) and local_storage_flag:
            delete_after_max = False
        elif isinstance(device_kind, str) and device_kind.lower() in {"native", "local", "offline"}:
            delete_after_max = False
        history_payload = {
            **result,
            "all_formulas": payload.get("all_formulas") or [],
            "ocr_all_formulas": payload.get("ocr_all_formulas") or [],
            "ocr_purple_formulas": payload.get("ocr_purple_formulas") or [],
            "codebase_id": codebase_id,
            "seed": seed_val,
            "exam_id": payload.get("exam_id"),
            "quest_id": payload.get("quest_id"),
        }
        save_solve_history(
            user_id=user_id,
            kind=kind,
            quest_id=payload.get("quest_id"),
            exam_id=payload.get("exam_id"),
            codebase_id=codebase_id,
            seed=seed_val,
            payload=history_payload,
            delete_after_max=delete_after_max,
        )
        if kind == "exam" and payload.get("exam_id"):
            _update_exam_score_sheet(
                user_id=user_id,
                exam_id=payload.get("exam_id"),
                problem_index=payload.get("problem_index"),
                problem_count=payload.get("problem_count"),
                status=result.get("status") or [],
            )
            if _is_exam_fully_correct_for_user(payload.get("exam_id"), user_id):
                delete_continue_strokes(
                    user_id=user_id,
                    kind="exam",
                    target_id=payload.get("exam_id"),
                )
    except Exception:
        # best-effort; failure should not block grading response
        pass

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



@app.post("/continue/strokes", response_model=ContinueStateResponse)
def save_continue_strokes_handler(
    payload: ContinueSaveRequest,
    user_id: str = Depends(_get_user_id),
) -> ContinueStateResponse:
    target_id = (payload.target_id or "").strip()
    if not target_id:
        raise HTTPException(status_code=400, detail="target_id is required")
    kind = payload.kind
    if kind == "exam" and _is_exam_fully_correct_for_user(target_id, user_id):
        delete_continue_strokes(user_id=user_id, kind=kind, target_id=target_id)
        raise HTTPException(status_code=409, detail="Fully graded; continue is not allowed")
    # 이미 완전 정답 처리된 항목은 이어하기 불가
    if is_latest_fully_correct(
        user_id=user_id,
        kind=kind,
        quest_id=target_id if kind == "problem" else None,
        exam_id=target_id if kind == "exam" else None,
    ):
        raise HTTPException(status_code=409, detail="Fully graded; continue is not allowed")
    # Only preserve when user actively returned from wrong answer state
    if payload.completed or not payload.allow_back:
        delete_continue_strokes(user_id=user_id, kind=kind, target_id=target_id)
        return ContinueStateResponse(target_id=target_id, strokes=[], updated_at=None)
    if not payload.forced_exit:
        raise HTTPException(status_code=400, detail="forced_exit must be true to save strokes")
    if payload.allow_back:
        save_continue_strokes(
            user_id=user_id,
            kind=kind,
            target_id=target_id,
            strokes=payload.strokes or [],
        )
    else:
        delete_continue_strokes(user_id=user_id, kind=kind, target_id=target_id)
    saved = load_continue_strokes(user_id=user_id, kind=kind, target_id=target_id) or {
        "strokes": [],
        "updated_at": None,
    }
    return ContinueStateResponse(
        target_id=target_id,
        strokes=saved.get("strokes") or [],
        updated_at=saved.get("updated_at"),
    )


@app.get("/continue/strokes", response_model=ContinueStateResponse)
def load_continue_strokes_handler(
    kind: str,
    target_id: str,
    user_id: str = Depends(_get_user_id),
) -> ContinueStateResponse:
    target = (target_id or "").strip()
    if not target:
        raise HTTPException(status_code=400, detail="target_id is required")
    if is_latest_fully_correct(
        user_id=user_id,
        kind=kind,
        quest_id=target if kind == "problem" else None,
        exam_id=target if kind == "exam" else None,
    ):
        raise HTTPException(status_code=409, detail="Fully graded; continue is not allowed")
    if kind == "exam" and _is_exam_fully_correct_for_user(target, user_id):
        delete_continue_strokes(user_id=user_id, kind=kind, target_id=target)
        raise HTTPException(status_code=409, detail="Fully graded; continue is not allowed")
    data = load_continue_strokes(user_id=user_id, kind=kind, target_id=target)
    if not data:
        raise HTTPException(status_code=404, detail="no continue session found")
    return ContinueStateResponse(
        target_id=data.get("target_id") or target,
        strokes=data.get("strokes") or [],
        updated_at=data.get("updated_at"),
        allow_back=True,
    )




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
        codebase_id = item.get("codebase_id")
        seed_value = item.get("seed")

        if item.get("quest_id"):

            quest = get_quest(item["quest_id"])

            if quest:

                quest_title = quest.get("data", {}).get("quest_title")

                question_type = quest.get("data", {}).get("question_type") or question_type

                quest_options = quest.get("data", {}).get("quest_options")

                if item.get("flow_count") is None:

                    item["flow_count"] = len(quest.get("solves", []))

                if codebase_id is None:

                    codebase_id = quest.get("data", {}).get("codebase_id")

                if seed_value is None:

                    seed_value = quest.get("data", {}).get("seed")

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
                codebase_id=codebase_id,
                seed=seed_value,
                quest_title=quest_title,
                quest_options=quest_options,
                error=item.get("error"),

            )

        )

    return resolved





async def _run_exam_generation(exam_id: str, user_id: Optional[str] = None) -> None:

    exam = get_exam(exam_id)
    resolved_user_id = user_id or (exam.get("user_id") if exam else None)
    if resolved_user_id:
        history_entries, history_map = _load_recent_seed_history(resolved_user_id)
    else:
        history_entries, history_map = [], {}

    update_exam_status(exam_id, "generating")

    items = get_exam_items(exam_id)

    used_codebase_ids: set[int] = set()

    used_codebase_lock = asyncio.Lock()

    failed_items = await _run_exam_batch(

        exam_id,

        items,

        used_codebase_ids,

        used_codebase_lock,

        history_entries,

        history_map,

        resolved_user_id,

        start_status="generating",

        failure_status="retrying",

    )



    if failed_items:

        update_exam_status(exam_id, "retrying")

        await asyncio.sleep(2)

        failed_items = await _run_exam_batch(

            exam_id,

            failed_items,

            used_codebase_ids,

            used_codebase_lock,

            history_entries,

            history_map,

            resolved_user_id,

            start_status="retrying",

            failure_status="failed",

        )



    final_status = "done"

    if failed_items:

        final_status = "failed"

    update_exam_status(exam_id, final_status)

    if resolved_user_id:
        _save_seed_history(resolved_user_id, history_entries)





async def _generate_exam_item(

    exam_id: str,

    item: Dict[str, Any],

    used_codebase_ids: set[int],

    used_codebase_lock: asyncio.Lock,

    history_entries: List[Dict[str, Any]],

    history_map: Dict[int, Set[int]],

    user_id: Optional[str],

    *,

    start_status: str,

    failure_status: str,

) -> bool:

    item_index = item["item_index"]

    update_exam_item(exam_id, item_index, status=start_status, error="")

    try:
        # snapshot avoid map to reduce lock contention; minor duplicate risk acceptable
        snapshot_avoid = {cb: set(seeds) for cb, seeds in history_map.items()}
        storage_data = await asyncio.to_thread(
            make,
            item["hash_tags"],
            item["solves_count"],
            item["strategy_level"],
            item["branch_conditions"],
            None,  # no legacy quest reuse; always generate via codebase
            False,
            None,
            item.get("question_type"),
            used_codebase_ids,
            avoid_seeds_by_codebase=snapshot_avoid,
        )
        data_block = storage_data.get("data") or {}
        codebase_id = data_block.get("codebase_id")
        seed_value = data_block.get("seed")
        if isinstance(codebase_id, int):
            async with used_codebase_lock:
                used_codebase_ids.add(codebase_id)
                history_map.setdefault(int(codebase_id), set()).add(int(seed_value or 0))

        if not store_data(storage_data):

            detail = get_last_store_error() or "failed to store quest"

            raise RuntimeError(detail)

        quest_id = storage_data["header"]["quest_id"]

        flow_count = len(storage_data.get("solves", []))

        update_exam_item(
            exam_id,
            item_index,
            status="done",
            quest_id=quest_id,
            flow_count=flow_count,
            codebase_id=codebase_id,
            seed=seed_value,
        )

        _record_seed_history_entry(user_id, history_entries, history_map, codebase_id, seed_value)

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

    used_codebase_ids: set[int],

    used_codebase_lock: asyncio.Lock,

    history_entries: List[Dict[str, Any]],

    history_map: Dict[int, Set[int]],

    user_id: Optional[str],

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

                used_codebase_ids,

                used_codebase_lock,

                history_entries,

                history_map,

                user_id,

                start_status=start_status,

                failure_status=failure_status,

            )

        )

        for item in items

    ]

    results = await asyncio.gather(*tasks)

    return [item for item, ok in zip(items, results) if not ok]





def _make_dm_response(*, msg: Dict[str, str], me_username: str, peer_username: str) -> DirectMessageResponse:
    is_mine = bool(msg.get("is_mine"))
    return DirectMessageResponse(
        **{
            "id": msg.get("id") or "",
            "from": me_username if is_mine else peer_username,
            "to": peer_username if is_mine else me_username,
            "text": msg.get("text") or "",
            "created_at": msg.get("created_at") or datetime.utcnow().isoformat(timespec="seconds") + "Z",
            "is_mine": is_mine,
        }
    )


@app.get("/social/messages", response_model=DirectMessageListResponse)
def list_direct_messages(
    peer: str,
    limit: int = 30,
    before: Optional[str] = None,
    max_total: int = 2000,
    user_id: str = Depends(_get_user_id),
) -> DirectMessageListResponse:
    peer_user = get_user_by_username(peer)
    if not peer_user:
        raise HTTPException(status_code=404, detail="Peer not found")
    me = get_user_by_id(user_id)
    me_username = me.get("username") if me else "me"
    peer_username = peer_user.get("username") or peer
    safe_limit = max(1, min(limit, 100))
    messages = list_messages(
        user_id=user_id,
        peer_id=peer_user["user_id"],
        limit=safe_limit,
        before_message_id=before,
    )
    trimmed = messages[-max_total:] if len(messages) > max_total else messages
    return DirectMessageListResponse(
        messages=[
            _make_dm_response(
                msg=msg,
                me_username=me_username,
                peer_username=peer_username,
            )
            for msg in trimmed
        ]
    )


@app.post("/social/messages", response_model=DirectMessageResponse)
def send_direct_message(
    payload: DirectMessagePayload,
    user_id: str = Depends(_get_user_id),
) -> DirectMessageResponse:
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is required")
    peer = get_user_by_username(payload.peer)
    if not peer:
        raise HTTPException(status_code=404, detail="Peer not found")
    me = get_user_by_id(user_id)
    me_username = me.get("username") if me else "me"
    peer_username = peer.get("username") or payload.peer
    now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    sender_msg_id = str(uuid.uuid4())
    receiver_msg_id = str(uuid.uuid4())

    append_message(
        message_id=sender_msg_id,
        user_id=user_id,
        peer_id=peer["user_id"],
        text=text,
        created_at=now,
        is_mine=True,
    )
    append_message(
        message_id=receiver_msg_id,
        user_id=peer["user_id"],
        peer_id=user_id,
        text=text,
        created_at=now,
        is_mine=False,
    )
    receiver_event = _make_dm_response(
        msg={
            "id": receiver_msg_id,
            "text": text,
            "created_at": now,
            "is_mine": False,
        },
        me_username=peer_username,
        peer_username=me_username,
    )
    _notify_user(
        peer["user_id"],
        {"type": "direct_message", "payload": receiver_event.model_dump()},
    )
    return _make_dm_response(
        msg={
          "id": sender_msg_id,
          "text": text,
          "created_at": now,
          "is_mine": True,
        },
        me_username=me_username,
        peer_username=peer_username,
    )


@app.post("/social/messages/{peer}/delete")
def delete_direct_message_thread(
    peer: str,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, str]:
    peer_user = get_user_by_username(peer)
    if not peer_user:
        raise HTTPException(status_code=404, detail="Peer not found")
    delete_conversation(user_id, peer_user["user_id"])
    return {"status": "deleted"}


@app.get("/social/conversations", response_model=DirectMessageListResponse)
def list_conversations_handler(
    limit: int = 15,
    before: Optional[str] = None,
    user_id: str = Depends(_get_user_id),
) -> DirectMessageListResponse:
    safe_limit = max(1, min(limit, 100))
    messages = list_conversations(
        user_id=user_id,
        limit=safe_limit,
        before_created_at=before,
    )
    me = get_user_by_id(user_id)
    me_username = me.get("username") if me else "me"
    result: List[DirectMessageResponse] = []
    for msg in messages:
        peer_user = get_user_by_id(msg.get("peer_id") or "") or {}
        peer_username = peer_user.get("username") or ""
        result.append(
            _make_dm_response(
                msg=msg,
                me_username=me_username,
                peer_username=peer_username,
            )
        )
    return DirectMessageListResponse(messages=result)



