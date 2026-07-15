import asyncio
import logging

import base64

import hashlib

import json

import os
import random
import sqlite3

import urllib.error

import urllib.request

import uuid

import threading

import time

from datetime import datetime, timedelta, timezone

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

from fastapi.responses import Response, StreamingResponse, FileResponse

from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from fastapi.staticfiles import StaticFiles

from pydantic import BaseModel, Field



from env_loader import load_env

from auth import (

    authenticate_teacher,

    authenticate_user,

    create_token,

    decode_token,

    delete_user_account,

    ELEVATED_ROLES,

    get_user_id_by_username,

    get_user_by_id as get_auth_user_by_id,

    get_user_role,

    init_user_db,

    register_teacher,

    register_user,

    resolve_token_payload_user,

    update_user_profile,

    validate_email,

    validate_name,

    validate_password,

    validate_school,

    validate_username,

)

get_user_by_id = get_auth_user_by_id

from analysis_service import analyze_pregrade, analyze_submission
from services.ai.guard import check_excessive, check_harmful

from clean_riddles import build_clean_payload

from baselines.basemodel import ContentBlocks

from exam_service import plan_exam_items
from csat_concept_index import (
    csat_index_metadata,
    get_csat_concept_difficulty,
    get_csat_hard_combinations,
)

from generater.fix_gen import (
    allowed_generation_tags,
    generation_tag_groups,
    validate_generation_tags,
)
from generater.make import make, make_legacy

from generater.codebase_runner import (
    hard_cancel_process_pool,
    shutdown_process_pool,
    warmup_sympy_pool,
)

from generater.problem_solve import generate_problem_set
from student_problem_content_review import require_student_problem_contract
from difficulty_contract import DIFFICULTY_CONTRACTS, clamp_difficulty_tier
from services.jobs.cancellation import (
    GenerationCancelled,
    cancel_token,
    check_cancelled,
    register_token,
    release_token,
)

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

from rating_service import apply_rating_batch, apply_rating_update, fetch_tag_ratings, fetch_user_rating

from storage.exam_storage import (
    add_exam_items,
    create_exam,
    get_exam,
    get_exam_items,
    init_exam_db,
    list_exams_by_ids,
    update_exam_item,
    update_exam_status,
)
from storage.exam_editor_storage import (
    get_exam_editor_paper,
    get_source_connected,
    init_exam_editor_db,
    save_exam_editor_paper,
    search_user_problem_set,
    set_source_connected,
    upsert_user_problem_set,
)

from storage.storage import (
    DB_PATH,
    claim_cached_quests,
    get_quest,
    get_last_store_error,
    init_db,
    search_quests,
    store_data,
    update_quest_mcq,
)
from domain.quest.search_view import enrich_quest_search_item, quest_title_text
from domain.exam import repository as exam_paper_repo
from services.ai.providers.base import get_default_provider
from services.ai.guard import evaluate_request
from services.jobs.state_machine import (
    InvalidTransitionError,
    JobNotFoundError,
    JobStateMachine,
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
    list_solve_history,
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
from services.ai.sam_client import DEFAULT_TAG_AGENT_MODEL, generate_json, is_sam_configured
from services.problem_runtime_cache import problem_runtime_cache

from storage.social_storage import (
    add_friend,
    append_message,
    are_friends,
    create_friend_request,
    get_friend_request_by_id,
    get_friends,
    get_message_by_id,
    list_conversations,
    get_user_by_id as get_social_user_by_id,
    get_user_by_username as get_social_user_by_username,
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

from storage.postgres_rating_store import postgres_rating_store
from storage.teacher_store import (
    init_teacher_store_db,
    purchase as teacher_store_purchase,
    summary as teacher_store_summary,
    top_up_test as teacher_store_top_up_test,
)
from storage.teacher_exam_document_store import (
    has_teacher_exam_document,
    init_teacher_exam_document_db,
    list_teacher_exam_documents,
    upsert_teacher_exam_document,
)
from storage.student_account_store import init_student_account_db

from domain.academy import repository as academy_repo
from domain.course import v2_repository as course_v2_repo

from storage.weakness_storage import (

    increment_weakness_tags,

    init_weakness_db,

    list_weakness_tags,

)

from storage.textbook_storage import (

    TEACHER_MANUAL_TEXTBOOK_ID,

    TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,

    create_textbook,

    get_textbook,

    init_textbook_db,

    is_teacher_manual_textbook,

    list_textbooks,

)

from storage.course_storage import (

    init_course_db,

    upsert_course,

    list_courses,

    get_course,

    enroll_course,

    list_enrollments,

    drop_enrollment,

    reorder_enrollments,

    get_enrollment,

    update_progress,

)

from storage.user_kv_storage import (

    delete_user_kv,

    get_user_kv,

    init_user_kv_db,

    set_user_kv,

)

# Server chat
from serverchat import (
    ChatGenerationBlocked,
    ChatInputBlocked,
    ChatRateLimited,
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
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def _embedded_background_workers_enabled() -> bool:
    """필요 변수: RUN_EMBEDDED_BACKGROUND_WORKERS. 작동 원리: 다중 웹 프로세스에서 작업 워커·생성 풀 중복 기동을 명시적으로 차단한다."""
    return os.getenv("RUN_EMBEDDED_BACKGROUND_WORKERS", "1").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


@app.get("/health/ready")
def health_ready() -> Dict[str, Any]:
    """필요 변수: 현재 저장소 환경. 작동 원리: 선택한 상용 캐시 계층이 검증·연결된 경우에만 배포 준비 완료를 반환한다."""
    from services.runtime_readiness import runtime_readiness

    report = runtime_readiness()
    if report["ready"] is not True:
        raise HTTPException(status_code=503, detail=report)
    return report


def _safe_include_router(router, *, name: str) -> None:
    try:
        app.include_router(router)
        logger.info("included router: %s", name)
    except Exception as exc:  # pragma: no cover - startup wiring diagnostics
        logger.error("failed to include router: %s (%s)", name, exc)


def include_api_routers() -> None:
    """Attach API routers with explicit diagnostics."""
    app.include_router(study_group_router)

    # 대결장 라우터는 독립 도메인으로 로드해 기존 소셜 기능과 장애를 분리한다.
    try:
        from arena import router as arena_router
        _safe_include_router(arena_router, name="arena")
    except Exception as exc:
        logger.error("failed to load arena router: %s", exc)

    # V2 course routers
    try:
        from app.api.routes.courses import (
            course_v2_router,
            ai_proposal_router,
            runtime_router,
        )

        _safe_include_router(course_v2_router, name="app.api.routes.courses")
        _safe_include_router(ai_proposal_router, name="app.api.routes.courses.ai_proposal_router")
        _safe_include_router(runtime_router, name="app.api.routes.courses.runtime_router")
    except Exception as exc:
        logger.error("failed to load course-v2 routers: %s", exc)

        try:
            from app.api.routes.courses.router import router as courses_v2_router_legacy
            _safe_include_router(
                courses_v2_router_legacy,
                name="app.api.routes.courses.router (legacy)",
            )
        except Exception as legacy_exc:
            logger.error("failed to load legacy courses-v2 router: %s", legacy_exc)

    # Quest variant router
    try:
        from app.api.routes.quest.router import router as quest_router
        _safe_include_router(quest_router, name="app.api.routes.quest.router")
    except Exception as exc:
        logger.error("failed to load quest router: %s", exc)

    # Exams v2 router
    try:
        from app.api.routes.exams.router import router as exams_v2_router
        _safe_include_router(exams_v2_router, name="app.api.routes.exams.router")
    except Exception as exc:
        logger.error("failed to load exams router: %s", exc)

    # Challenge router
    try:
        from app.api.routes.challenge.router import router as challenge_router
        _safe_include_router(challenge_router, name="app.api.routes.challenge.router")
    except Exception as exc:
        logger.error("failed to load challenge router: %s", exc)

    # Level-test router
    try:
        from app.api.routes.level_test.router import router as level_test_router
        _safe_include_router(level_test_router, name="app.api.routes.level_test.router")
    except Exception as exc:
        logger.error("failed to load level-test router: %s", exc)

    # Curriculum router
    try:
        from app.api.routes.curriculum.router import router as curriculum_router
        _safe_include_router(curriculum_router, name="app.api.routes.curriculum.router")
    except Exception as exc:
        logger.error("failed to load curriculum router: %s", exc)

    # Graph router
    try:
        from app.api.routes.graph.router import router as graph_router
        _safe_include_router(graph_router, name="app.api.routes.graph.router")
    except Exception as exc:
        logger.error("failed to load graph router: %s", exc)

    # Textbook router
    try:
        from app.api.routes.textbook.router import router as textbook_router
        _safe_include_router(textbook_router, name="app.api.routes.textbook.router")
    except Exception as exc:
        logger.error("failed to load textbook router: %s", exc)

    # Jobs service router
    try:
        from services.jobs.api import router as jobs_router
        _safe_include_router(jobs_router, name="services.jobs.api")
    except Exception as exc:
        logger.error("failed to load jobs router: %s", exc)

    # Academy router
    try:
        from app.api.routes.academy.router import router as academy_router
        _safe_include_router(academy_router, name="app.api.routes.academy.router")
    except Exception as exc:
        logger.error("failed to load academy router: %s", exc)

    # Account progress router
    try:
        from app.api.routes.account.router import router as account_router
        _safe_include_router(account_router, name="app.api.routes.account.router")
    except Exception as exc:
        logger.error("failed to load account router: %s", exc)


include_api_routers()


logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)

_GEN_SEMAPHORE = asyncio.Semaphore(2)
_CACHE_REFILL_LOCK = threading.Lock()
_CACHE_REFILL_INFLIGHT: Dict[str, int] = {}
_EXAM_ITEM_MAX_CONCURRENT = max(1, int(os.getenv("EXAM_ITEM_MAX_CONCURRENT", "8")))
_EXAM_ITEM_SEMAPHORE = asyncio.Semaphore(_EXAM_ITEM_MAX_CONCURRENT)

_GEN_STATUS: Dict[str, Dict[str, Any]] = {}

_GEN_STATUS_LOCK = threading.Lock()

_GEN_STATUS_TTL = 300



_WS_CONNECTIONS: Dict[str, List[WebSocket]] = {}
_WS_LOCK = asyncio.Lock()

_HISTORY_KEY = "problem_history_v2"
_HISTORY_WINDOW_SEC = 3 * 24 * 60 * 60
_HISTORY_MAX = 500
_EXAM_SCORE_PREFIX = "exam_score_sheet:"
_VARIANT_TRAY_MAX = 500


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def _init_variant_tray_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS quest_variant_tray (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            quest_id TEXT,
            codebase_id INTEGER,
            seed INTEGER,
            source_variant_mode TEXT NOT NULL DEFAULT '',
            visibility_scope TEXT NOT NULL DEFAULT 'shared',
            is_mcq_branch INTEGER NOT NULL DEFAULT 0,
            payload_json TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_variant_tray_user_time ON quest_variant_tray(user_id, updated_at DESC)"
    )
    conn.commit()
    conn.close()


def _insert_variant_tray_item(
    *,
    user_id: str,
    quest: Optional[Dict[str, Any]],
    source_variant_mode: str,
    visibility_scope: str,
    is_mcq_branch: bool,
    payload: Dict[str, Any],
) -> Dict[str, Any]:
    _init_variant_tray_db()
    header = (quest or {}).get("header", {}) if isinstance(quest, dict) else {}
    quest_id = (header.get("quest_id") or payload.get("quest_id") or "").strip() or None
    codebase_id, seed = _extract_codebase_seed(quest or payload)
    now = _now_iso()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO quest_variant_tray (
            user_id, quest_id, codebase_id, seed, source_variant_mode, visibility_scope,
            is_mcq_branch, payload_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            user_id,
            quest_id,
            codebase_id,
            seed,
            source_variant_mode,
            visibility_scope,
            1 if is_mcq_branch else 0,
            json.dumps(payload, ensure_ascii=False),
            now,
            now,
        ),
    )
    row_id = int(cur.lastrowid or 0)
    cur.execute(
        """
        DELETE FROM quest_variant_tray
        WHERE user_id = ?
          AND id NOT IN (
            SELECT id FROM quest_variant_tray
            WHERE user_id = ?
            ORDER BY updated_at DESC, id DESC
            LIMIT ?
          )
        """,
        (user_id, user_id, _VARIANT_TRAY_MAX),
    )
    conn.commit()
    conn.close()
    return {
        "id": row_id,
        "user_id": user_id,
        "quest_id": quest_id,
        "codebase_id": codebase_id,
        "seed": seed,
        "source_variant_mode": source_variant_mode,
        "visibility_scope": visibility_scope,
        "is_mcq_branch": is_mcq_branch,
        "payload": payload,
        "updated_at": now,
    }


def _list_variant_tray_items(*, user_id: str, limit: int = 100) -> List[Dict[str, Any]]:
    _init_variant_tray_db()
    safe_limit = max(1, min(limit, 500))
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, quest_id, codebase_id, seed, source_variant_mode, visibility_scope,
               is_mcq_branch, payload_json, updated_at
        FROM quest_variant_tray
        WHERE user_id = ?
        ORDER BY updated_at DESC, id DESC
        LIMIT ?
        """,
        (user_id, safe_limit),
    )
    rows = cur.fetchall()
    conn.close()
    items: List[Dict[str, Any]] = []
    for row in rows:
        try:
            payload = json.loads(row[7] or "{}")
        except Exception:
            payload = {}
        items.append(
            {
                "id": int(row[0]),
                "quest_id": row[1],
                "codebase_id": row[2],
                "seed": row[3],
                "source_variant_mode": row[4] or "",
                "visibility_scope": row[5] or "shared",
                "is_mcq_branch": bool(row[6]),
                "payload": payload,
                "updated_at": row[8],
            }
        )
    return items


@app.on_event("startup")
async def _startup_event() -> None:
    init_db()
    init_exam_db()
    init_exam_editor_db()
    init_habit_db()
    init_continue_db()
    init_solve_history_db()
    init_weakness_db()
    postgres_rating_store.require_ready()
    init_teacher_store_db()
    init_teacher_exam_document_db()
    init_student_account_db()
    init_user_db()
    init_course_db()
    _init_variant_tray_db()
    # 웹/워커 모드와 관계없이 정적 문제 파일이 없거나 손상되면 서버를 준비 완료로 올리지 않는다.
    await _validate_level_test_static_db()
    if not _embedded_background_workers_enabled():
        logger.info("embedded background workers disabled for web process")
        return
    # 단일 프로세스 개발 모드에서만 내장 작업 워커를 시작한다. 상용 다중 웹 프로세스는 전용 worker_main을 사용한다.
    from services.jobs.worker import JobWorker
    from services.jobs.store import JobStore
    stale_before = (datetime.now(timezone.utc) - timedelta(hours=6)).isoformat()
    stale_count = JobStore().fail_stale_active(
        before_iso=stale_before,
        detail="Server restarted before job completed",
    )
    if stale_count:
        logger.warning("Marked %s stale active jobs as failed", stale_count)
    worker_concurrency = max(1, int(os.getenv("JOB_WORKER_MAX_CONCURRENT", "6")))
    worker_poll_interval = float(os.getenv("JOB_WORKER_POLL_INTERVAL_SEC", "0.5"))
    app.state.job_worker = JobWorker(
        poll_interval=worker_poll_interval,
        max_concurrent=worker_concurrency,
    )
    await app.state.job_worker.start()


@app.on_event("shutdown")
async def _shutdown_event() -> None:
    if hasattr(app.state, "job_worker"):
        await app.state.job_worker.stop()
    for task_name in ("seed_validator_task",):
        task = getattr(app.state, task_name, None)
        if task is None:
            continue
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
        setattr(app.state, task_name, None)
    shutdown_process_pool(wait=False)


async def _validate_level_test_static_db() -> None:
    """필요 변수: 배포된 레벨테스트 정적 DB. 작동 원리: 서버 시작 시 읽기 전용 무결성만 확인하고 문제 생성이나 운영 DB 쓰기는 하지 않는다."""
    try:
        from domain.level_test.static_store import validate_static_database

        report = await asyncio.to_thread(validate_static_database)
        logger.info(
            "level-test static DB ready: problems=%s templates=%s",
            report["problem_count"],
            report["template_count"],
        )
    except Exception as exc:
        logger.error("failed to validate level-test static DB: %s", exc)
        raise RuntimeError("level-test static DB is not ready") from exc


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


def _enqueue_cache_refill(
    *,
    user_id: str,
    hash_tags: List[str],
    min_tier: int,
    max_tier: int,
    question_count: int,
) -> bool:
    """필요 변수: 생성 조건과 보충 수량. 작동 원리: 동일 조건의 보충 작업을 짧은 시간에 한 번만 등록해 요청 폭주가 생성 폭주로 번지는 것을 막는다."""
    if question_count < 1:
        return False
    normalized_tags = sorted({str(tag).strip().lstrip("#") for tag in hash_tags if str(tag).strip()})
    if not normalized_tags:
        return False
    key = f"{','.join(normalized_tags)}|{min_tier}|{max_tier}"
    now = int(time.time())
    with _CACHE_REFILL_LOCK:
        previous = _CACHE_REFILL_INFLIGHT.get(key, 0)
        if now - previous < 300:
            return False
        _CACHE_REFILL_INFLIGHT[key] = now
    try:
        JobStateMachine().start_job(
            user_id=user_id,
            job_type="quest_cache_refill",
            payload={
                "hash_tags": hash_tags,
                "min_difficulty_tier": min_tier,
                "max_difficulty_tier": max_tier,
                "question_count": min(10, question_count),
            },
        )
        return True
    except Exception:
        with _CACHE_REFILL_LOCK:
            _CACHE_REFILL_INFLIGHT.pop(key, None)
        logger.exception("failed to enqueue quest cache refill")
        return False


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


def _can_access_exam_document(user_id: str, exam: Optional[Dict[str, Any]]) -> bool:
    if not user_id or not exam:
        return False
    exam_id = str(exam.get("exam_id") or "").strip()
    if str(exam.get("user_id") or "") == user_id:
        return True
    return has_teacher_exam_document(user_id, exam_id)


def _course_references_exam(course: Any, exam_id: str) -> bool:
    exam_value = (exam_id or "").strip()
    if not exam_value:
        return False
    for module in getattr(course, "modules", []) or []:
        module_type = getattr(module.type, "value", str(module.type))
        if module_type not in {"exam_solve", "level_test"}:
            continue
        if str(module.exam_id or "").strip() == exam_value:
            return True
    return False


def _can_access_exam_via_course(user_id: str, exam_id: str, course_id: Optional[str]) -> bool:
    course_value = str(course_id or "").strip()
    if not user_id or not course_value:
        return False
    course = course_v2_repo.get_course_v2(course_value)
    if course is None or not _course_references_exam(course, exam_id):
        return False
    role = str(get_user_role(user_id) or "student").strip().lower()
    if course.is_public:
        return True
    if role == "admin":
        return True
    if role == "teacher" and (
        not str(course.owner_user_id or "").strip()
        or str(course.owner_user_id or "") == user_id
    ):
        return True
    group_id = str(course.access_group_id or "").strip()
    if not group_id:
        return False
    if not academy_repo.is_active_group_member(group_id=group_id, user_id=user_id):
        return False
    if course.access_academy_id:
        group = academy_repo.get_group(group_id)
        if not group or str(group.get("academy_id") or "") != str(course.access_academy_id):
            return False
    return True


def _exam_paper_runtime_items(exam_id: str) -> Optional[List[Dict[str, Any]]]:
    try:
        paper_id = int(str(exam_id).strip())
    except (TypeError, ValueError):
        return None

    paper = exam_paper_repo.get_exam_paper(paper_id)
    if paper is None:
        return None

    try:
        layout = json.loads(paper.layout_json or "{}")
    except json.JSONDecodeError:
        layout = {}
    raw_items = layout.get("items") if isinstance(layout, dict) else []
    if not isinstance(raw_items, list):
        raw_items = []

    items: List[Dict[str, Any]] = []
    for index, raw in enumerate(raw_items):
        if not isinstance(raw, dict):
            continue
        quest_id = str(raw.get("quest_id") or "").strip()
        if not quest_id:
            continue
        quest = get_quest(quest_id)
        data = quest.get("data", {}) if quest else {}
        hash_tags = data.get("hash_tag") or data.get("hash_tags") or []
        if isinstance(hash_tags, str):
            try:
                parsed_tags = json.loads(hash_tags)
                hash_tags = parsed_tags if isinstance(parsed_tags, list) else [hash_tags]
            except json.JSONDecodeError:
                hash_tags = [hash_tags]
        if not isinstance(hash_tags, list):
            hash_tags = []
        items.append(
            {
                "item_index": index,
                "status": "done",
                "subject_key": str(raw.get("subject_key") or data.get("subject_key") or "math"),
                "hash_tags": [str(tag) for tag in hash_tags],
                "difficulty_tier": int(raw.get("difficulty_tier") or data.get("difficulty_tier") or 3),
                "solves_count": int(raw.get("solves_count") or data.get("solves_count") or 1),
                "strategy_level": int(raw.get("strategy_level") or data.get("strategy_level") or 1),
                "branch_conditions": int(raw.get("branch_conditions") or data.get("branch_conditions") or 0),
                "question_type": raw.get("question_type") or data.get("question_type"),
                "quest_id": quest_id,
                "flow_count": raw.get("flow_count"),
                "codebase_id": raw.get("codebase_id") or data.get("codebase_id"),
                "seed": raw.get("seed") or data.get("seed"),
                "error": None if quest else "quest not found",
            }
        )
    return items


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


def _init_gen_status(request_id: str, message: str = "queued", user_id: Optional[str] = None) -> None:

    now = int(time.time())

    with _GEN_STATUS_LOCK:

        _GEN_STATUS[request_id] = {

            "status": "queued",

            "message": message,

            "updated_at": now,

            "quest": None,

            "error": None,

            "user_id": user_id,

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


def _parse_job_json(value: Any) -> Any:
    if value is None or isinstance(value, (dict, list)):
        return value
    if isinstance(value, str) and value.strip():
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return None
    return None


def _job_updated_at_epoch(value: Any) -> int:
    if not value:
        return int(time.time())
    try:
        return int(datetime.fromisoformat(str(value)).timestamp())
    except Exception:
        return int(time.time())


def _quest_job_to_status_payload(state: Dict[str, Any]) -> Dict[str, Any]:
    status_value = str(state.get("status") or "")
    visible_status = {
        "queued": "queued",
        "generating": "generating",
        "done": "done",
        "failed": "failed",
        "rejected": "cancelled",
    }.get(status_value, status_value or None)
    result = _parse_job_json(state.get("result"))
    quest = result.get("quest") if isinstance(result, dict) else None
    error = state.get("error") or state.get("rejection_reason")
    return {
        "status": visible_status,
        "message": visible_status,
        "updated_at": _job_updated_at_epoch(state.get("updated_at")),
        "quest": quest,
        "error": error,
    }


def _get_quest_generation_job(request_id: str, user_id: str) -> Optional[Dict[str, Any]]:
    try:
        state = JobStateMachine().get_status(request_id)
    except JobNotFoundError:
        return None
    if state.get("operation") != "quest_generation":
        return None
    owner_id = state.get("user_id")
    if owner_id and owner_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorised to view this generation")
    return state





_BASE_DIR = os.path.dirname(os.path.abspath(__file__))

_ASSETS_DIR = os.path.join(_BASE_DIR, "assets")

os.makedirs(_ASSETS_DIR, exist_ok=True)



load_env()

_SEED_VALIDATOR_ENABLED = os.environ.get("SEED_VALIDATOR_ENABLED", "1").lower() in ("1", "true", "yes")

_SEED_VALIDATOR_INTERVAL = int(os.environ.get("SEED_VALIDATOR_INTERVAL", "60"))

_SEED_VALIDATOR_BATCH = int(os.environ.get("SEED_VALIDATOR_BATCH", "1"))

_SEED_VALIDATOR_ATTEMPTS = int(os.environ.get("SEED_VALIDATOR_ATTEMPTS", "16"))

_SEED_VALIDATOR_MAX_SUCCESSES = int(os.environ.get("SEED_VALIDATOR_MAX_SUCCESSES", "4"))

_SEED_VALIDATOR_LOCK = asyncio.Lock()

_QUEST_GENERATE_FAST_WAIT_MS = max(
    0,
    int(os.environ.get("QUEST_GENERATE_FAST_WAIT_MS", "500")),
)



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


_COURSE_BUILDER_HTML = os.path.join(os.path.dirname(__file__), "course_builder.html")


@app.get("/course-builder", response_class=FileResponse)
def course_builder_page():
    return FileResponse(_COURSE_BUILDER_HTML, media_type="text/html")




class RangeInput(BaseModel):

    key: Optional[str] = None

    tags: List[str] = Field(default_factory=list)





class ExamCreateRequest(BaseModel):

    ranges: List[RangeInput]

    difficulty_tier: int = Field(ge=1, le=5)

    question_count: int = Field(ge=4, le=100)

    paper_type: str = "aiflow"

    title: Optional[str] = None

    save_to_document_box: bool = False





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


class ExamEditorItemInput(BaseModel):
    order_no: int
    page_no: Optional[int] = None
    layout_slot: Optional[str] = "auto"
    codebase_id: Optional[int] = None
    seed: Optional[int] = None
    quest_id: str
    question_type: Optional[str] = None
    is_geometry: bool = False


class ExamEditorPaperSaveRequest(BaseModel):
    paper_id: Optional[str] = None
    title: str = "새 시험지"
    two_per_page: bool = False
    grading_area_direction: str = "bottom"
    expected_updated_at: Optional[str] = None
    items: List[ExamEditorItemInput] = Field(default_factory=list)


class ExamEditorPaperResponse(BaseModel):
    paper_id: str
    title: str
    two_per_page: bool
    grading_area_direction: str
    source_connected: bool
    updated_at: str
    created_at: str
    items: List[Dict[str, Any]] = Field(default_factory=list)


class ExamEditorDeployResponse(BaseModel):
    paper_id: str
    exam_id: str
    status: str
    deployed_count: int


class ExamEditorSearchResponse(BaseModel):
    items: List[Dict[str, Any]]
    total: int
    page: int
    page_size: int
    source_connected: bool


class ExamEditorImportRequest(BaseModel):
    source_exam_id: str
    item_indexes: List[int] = Field(default_factory=list)


class ExamEditorAiArrangeRequest(BaseModel):
    paper_id: Optional[str] = None
    items: List[ExamEditorItemInput] = Field(default_factory=list)
    instruction: Optional[str] = None


class ExamEditorAiArrangeResponse(BaseModel):
    accepted: bool
    reason: Optional[str] = None
    items: List[Dict[str, Any]] = Field(default_factory=list)


class ExamEditorSourceToggleRequest(BaseModel):
    enabled: bool





class TokenResponse(BaseModel):

    token: str

    user_id: str



class TeacherAuthResponse(BaseModel):

    token: str

    username: str

    role: str

    name: str



class TeacherRegisterRequest(BaseModel):

    email: str

    password: str

    name: str



class TeacherLoginRequest(BaseModel):

    email: str

    password: str



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


class UserProfile(BaseModel):

    user_id: str

    username: str

    name: str

    role: Optional[str] = None

    grade: Optional[str] = None

    track: Optional[str] = None

    subject: Optional[str] = None

    school: Optional[str] = None

    email: Optional[str] = None


class UserProfileUpdateRequest(BaseModel):

    username: Optional[str] = None

    password: Optional[str] = None

    name: Optional[str] = None

    grade: Optional[str] = None

    track: Optional[str] = None

    subject: Optional[str] = None

    school: Optional[str] = None

    email: Optional[str] = None


class UserProfileDeleteRequest(BaseModel):

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

    question_count: int = Field(ge=1, le=500)

    strict_tags: bool = False





class ProblemSolveGenerateResponse(BaseModel):

    quests: List[Dict[str, Any]]


class ProblemSolveGenerateQueuedResponse(BaseModel):

    job_id: str

    status: str

    message: Optional[str] = None


class VariantRejection(BaseModel):
    allowed: bool = False
    reason_code: str
    reason_message: str
    suggested_fix: Optional[str] = None


class VariantBaseQuestRef(BaseModel):
    quest_id: Optional[str] = None
    codebase_id: Optional[int] = None
    seed: Optional[int] = None


class VariantFlowNodeDraft(BaseModel):
    node_id: str
    node_type: Optional[str] = None
    text: Optional[str] = None
    hash_tags: List[str] = Field(default_factory=list)
    branches: List[str] = Field(default_factory=list)
    teacher_instruction: Optional[str] = None
    prompt_text: Optional[str] = None


class VariantFlowDraftRequest(BaseModel):
    variant_input_mode: str = Field(default="flow_draft", pattern="^(flow_draft)$")
    base_quest_ref: Optional[VariantBaseQuestRef] = None
    flow_draft: List[VariantFlowNodeDraft] = Field(default_factory=list)
    prompt: Optional[str] = None
    note_blocks: List[Dict[str, Any]] = Field(default_factory=list)
    advanced_metrics: Dict[str, Any] = Field(default_factory=dict)
    advanced_profile: Dict[str, Any] = Field(default_factory=dict)
    seed_override: Optional[int] = None
    tags: List[str] = Field(default_factory=list)
    solves_count: int = Field(default=4, ge=1, le=10)
    strategy_level: int = Field(default=2, ge=1, le=3)
    branch_conditions: int = Field(default=1, ge=0, le=5)


def _validate_typed_variant_flow_graph(
    flow_draft: List[VariantFlowNodeDraft],
) -> Optional[str]:
    """노드 유형이 포함된 새 캔버스 요청의 참조 무결성과 DAG 역할 규칙을 검사한다."""
    if not flow_draft or not all((node.node_type or "").strip() for node in flow_draft):
        return None
    if len(flow_draft) > 32:
        return "flow_draft supports at most 32 typed nodes"

    allowed_types = {
        "condition", "concept", "insight", "reasoning",
        "computation", "trap", "merge", "verification",
    }
    max_outgoing = {
        "condition": 4,
        "concept": 4,
        "insight": 4,
        "reasoning": 4,
        "computation": 2,
        "trap": 2,
        "merge": 1,
        "verification": 0,
    }
    node_ids = [node.node_id.strip() for node in flow_draft]
    if any(not node_id for node_id in node_ids) or len(set(node_ids)) != len(node_ids):
        return "node_id values must be non-empty and unique"

    by_id = {node.node_id.strip(): node for node in flow_draft}
    indegree = {node_id: 0 for node_id in node_ids}
    undirected = {node_id: set() for node_id in node_ids}
    for node_id, node in by_id.items():
        node_type = (node.node_type or "").strip()
        if node_type not in allowed_types:
            return f"unsupported node_type: {node_type}"
        targets = [str(target).strip() for target in node.branches]
        if len(targets) != len(set(targets)):
            return f"duplicate branches are not allowed: {node_id}"
        if len(targets) > max_outgoing[node_type]:
            return f"{node_type} node exceeds its outgoing connection limit"
        for target_id in targets:
            if target_id == node_id:
                return "self connections are not allowed"
            if target_id not in by_id:
                return f"unknown branch target: {target_id}"
            indegree[target_id] += 1
            undirected[node_id].add(target_id)
            undirected[target_id].add(node_id)

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node_id: str) -> bool:
        if node_id in visiting:
            return False
        if node_id in visited:
            return True
        visiting.add(node_id)
        for target_id in by_id[node_id].branches:
            if not visit(str(target_id).strip()):
                return False
        visiting.remove(node_id)
        visited.add(node_id)
        return True

    if any(not visit(node_id) for node_id in node_ids):
        return "flow graph must be acyclic"

    connected = set()
    pending = [node_ids[0]]
    while pending:
        current = pending.pop()
        if current in connected:
            continue
        connected.add(current)
        pending.extend(undirected[current] - connected)
    if len(connected) != len(node_ids):
        return "flow graph contains disconnected nodes"
    if not any(node.node_type == "verification" for node in flow_draft):
        return "at least one verification node is required"
    for node in flow_draft:
        if not node.branches and node.node_type != "verification":
            return "every terminal flow must be a verification node"
        if node.node_type == "merge" and indegree[node.node_id.strip()] < 2:
            return "merge nodes require at least two incoming connections"
    return None


class VariantPromptNoteRequest(BaseModel):
    variant_input_mode: str = Field(default="prompt_note", pattern="^(prompt_note)$")
    base_quest_ref: Optional[VariantBaseQuestRef] = None
    prompt: Optional[str] = None
    note_blocks: List[Dict[str, Any]] = Field(default_factory=list)
    advanced_metrics: Dict[str, Any] = Field(default_factory=dict)
    advanced_profile: Dict[str, Any] = Field(default_factory=dict)
    seed_override: Optional[int] = None
    tags: List[str] = Field(default_factory=list)
    solves_count: int = Field(default=4, ge=1, le=10)
    strategy_level: int = Field(default=2, ge=1, le=3)
    branch_conditions: int = Field(default=1, ge=0, le=5)


class McqPolicy(BaseModel):
    offset_pattern: str = Field(default="pm2", pattern="^(pm1|pm2|mixed)$")
    random_choices: bool = True


class ConvertMcqRequest(BaseModel):
    base_quest_ref: VariantBaseQuestRef
    mcq_policy: McqPolicy = Field(default_factory=McqPolicy)
    visibility_scope: str = Field(default="private_mcq", pattern="^(private_mcq|shared)$")


class VariantGradeRequest(BaseModel):
    quest_id: str
    selected_index: Optional[int] = None
    user_answer: Optional[str] = None
    hints_forbidden: bool = True


class QuestTrayCreateRequest(BaseModel):
    quest_id: Optional[str] = None
    codebase_id: Optional[int] = None
    seed: Optional[int] = None
    source_variant_mode: str = Field(default="")
    visibility_scope: str = Field(default="shared")
    is_mcq_branch: bool = False
    payload: Dict[str, Any] = Field(default_factory=dict)


class QuestTrayItem(BaseModel):
    id: int
    quest_id: Optional[str] = None
    codebase_id: Optional[int] = None
    seed: Optional[int] = None
    source_variant_mode: str = ""
    visibility_scope: str = "shared"
    is_mcq_branch: bool = False
    payload: Dict[str, Any] = Field(default_factory=dict)
    updated_at: str


class QuestTrayResponse(BaseModel):
    items: List[QuestTrayItem]


class VariantGenerateResponse(BaseModel):
    success: bool = True
    quest: Optional[Dict[str, Any]] = None
    rejection: Optional[VariantRejection] = None





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


class SolveHistoryItem(BaseModel):
    created_at: str
    kind: str
    quest_id: Optional[str] = None
    exam_id: Optional[str] = None
    codebase_id: Optional[int] = None
    seed: Optional[int] = None
    data: Optional[Dict[str, Any]] = None


class SolveHistoryListResponse(BaseModel):
    items: List[SolveHistoryItem]


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
    model: str = ""


class ServerChatMessageRequest(BaseModel):
    user_message: str
    character: Optional[str] = None
    quest_title: Optional[str] = None
    flow: Optional[str] = None
    ocr: Optional[str] = None
    ephemeral: bool = False
    include_user_data: bool = False
    mode: Optional[str] = Field(default="chat", pattern="^(chat|problem|counseling)$")


class ServerChatMessageResponse(BaseModel):
    assistant_message: str
    affection_score: float
    affection_breakdown: Dict[str, float]
    character: str
    character_name: str
    model: str = ""
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

    step_correctness: List[Dict[str, Any]] = Field(default_factory=list)

    is_correct: Optional[bool] = None

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
    other = get_social_user_by_id(other_id) or {}
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


class FriendRankItem(BaseModel):
    user_id: str
    username: str
    visible_ovr: float
    rank: int
    is_me: bool = False


class FriendRankingsResponse(BaseModel):
    ranks: List[FriendRankItem]





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

    is_teacher_manual: bool = False

    is_course_selectable: bool = True

    student_visible: bool = True

    document_id: Optional[str] = None

    exam_id: Optional[str] = None

    type: Optional[str] = None

    status: Optional[str] = None

    item_count: Optional[int] = None

    duration_minutes: Optional[int] = None





class TextbookListResponse(BaseModel):

    textbooks: List[TextbookResponse]





_TEXTBOOK_LIBRARY_KEY = "textbook_library_v1"

_TEACHER_MANUAL_TEXTBOOK_ID = TEACHER_MANUAL_TEXTBOOK_ID
_TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID = (
    TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID
)
_TEACHER_MANUAL_TEXTBOOK_IDS = (
    _TEACHER_MANUAL_TEXTBOOK_ID,
    _TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,
)


def _with_textbook_visibility_flags(item: Dict[str, Any]) -> Dict[str, Any]:
    payload = dict(item)
    if is_teacher_manual_textbook(payload.get("textbook_id")):
        payload.update(
            {
                "is_teacher_manual": True,
                "is_course_selectable": False,
                "student_visible": False,
            }
        )
    return payload


def _fallback_teacher_manual_document(textbook_id: str) -> Dict[str, Any]:
    now_ms = int(time.time() * 1000)
    if textbook_id == _TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID:
        return {
            "textbook_id": _TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,
            "title": "문제 생성 설명서",
            "subtitle": "고급 생성 캔버스와 난이도 파라미터 운용 안내",
            "category": "설명서",
            "tags": ["설명서", "교사용", "문제생성", "고급생성"],
            "chapters": [
                {
                    "title": "1. 문제 고급생성",
                    "intro": [
                        "이 교재는 모든 교사가 문서함에서 열람하는 문제 생성 설명서입니다.",
                        "풀이 논리 캔버스, 노드 지시, 난이도 파라미터 반영 방식을 안내합니다.",
                    ],
                    "sections": [
                        {
                            "title": "1-1. 캔버스와 파라미터",
                            "paragraphs": [
                                "캔버스 노드와 연결은 flow_draft로 전달됩니다.",
                                "세부 난이도 지표는 실제 문제 구조와 풀이 부담을 조정하는 고급 지시로 전달됩니다.",
                            ],
                            "images": [],
                        }
                    ],
                }
            ],
            "cover_color": 0xFF214A73,
            "created_at": now_ms,
            "updated_at": now_ms,
            "created_by": "system",
        }
    return {
        "textbook_id": _TEACHER_MANUAL_TEXTBOOK_ID,
        "title": "설명서 기본 교재",
        "subtitle": "교사용 문서함과 코스 교재 권한 연결 안내",
        "category": "설명서",
        "tags": ["설명서", "교사용", "문서함"],
        "chapters": [
            {
                "title": "1. 문서함 사용 설명",
                "intro": [
                    "이 교재는 모든 교사가 공통으로 확인하는 설명서 기본 교재입니다.",
                    "학생에게는 표시되지 않으며 코스 교재로 등록할 수 없습니다.",
                ],
                "sections": [
                    {
                        "title": "1-1. 문서함",
                        "paragraphs": [
                            "문서함은 교사용 코스 생성에서 사용할 수 있는 교재와 안내 문서를 모아 보여줍니다.",
                            "설명서 기본 교재는 교사용 안내 전용이므로 학생 학습 화면에는 노출되지 않습니다.",
                        ],
                        "images": [],
                    },
                    {
                        "title": "1-2. 권한 연결",
                        "paragraphs": [
                            "교재는 복사본을 만들지 않고 권한으로 연결합니다.",
                            "코스에는 학습용 교재만 등록할 수 있으며 설명서 기본 교재는 선택 목록에서 제외됩니다.",
                        ],
                        "images": [],
                    },
                ],
            },
        ],
        "cover_color": 0xFF1B402B,
        "created_at": now_ms,
        "updated_at": now_ms,
        "created_by": "system",
    }


def _teacher_manual_document(textbook_id: str) -> Dict[str, Any]:
    item = get_textbook(textbook_id)
    if item:
        return _with_textbook_visibility_flags(item)
    return _with_textbook_visibility_flags(
        _fallback_teacher_manual_document(textbook_id)
    )


def _teacher_manual_documents() -> List[Dict[str, Any]]:
    return [
        _teacher_manual_document(textbook_id)
        for textbook_id in _TEACHER_MANUAL_TEXTBOOK_IDS
    ]


def _iso_to_epoch_ms(raw: Any) -> int:
    text = str(raw or "").strip()
    if not text:
        return int(time.time() * 1000)
    try:
        normalized = text.replace("Z", "+00:00")
        return int(datetime.fromisoformat(normalized).timestamp() * 1000)
    except ValueError:
        return int(time.time() * 1000)


def _exam_document_title(
    params: Dict[str, Any],
    tags: List[str],
    *,
    title_override: Optional[str] = None,
) -> str:
    title = str(title_override or "").strip()
    if title:
        return title
    title = str(params.get("title") or "").strip()
    if title:
        return title
    if tags:
        return f"{tags[0]} 시험지"
    return "시험지"


def _build_exam_document(item: Dict[str, Any]) -> Dict[str, Any]:
    exam_id = str(item.get("exam_id") or "").strip()
    params = item.get("params") if isinstance(item.get("params"), dict) else {}
    tags: List[str] = []
    for raw_range in params.get("ranges") or []:
        if not isinstance(raw_range, dict):
            continue
        for tag in raw_range.get("tags") or []:
            text = str(tag or "").strip()
            if text and text not in tags:
                tags.append(text)
    question_count = int(item.get("item_count") or params.get("question_count") or 0)
    subtitle_bits = [f"{question_count}문항" if question_count > 0 else None]
    status_text = str(item.get("status") or "").strip()
    if status_text:
        subtitle_bits.append(status_text)
    title = _exam_document_title(
        params,
        tags,
        title_override=str(item.get("document_title") or "").strip(),
    )
    updated_at = _iso_to_epoch_ms(item.get("document_updated_at") or item.get("updated_at"))
    created_at = _iso_to_epoch_ms(item.get("document_created_at") or item.get("created_at"))
    return {
        "textbook_id": exam_id,
        "document_id": exam_id,
        "exam_id": exam_id,
        "title": title,
        "subtitle": " · ".join(part for part in subtitle_bits if part),
        "category": "시험지",
        "tags": tags,
        "chapters": [],
        "cover_color": 0xFF3F6E4A,
        "created_at": created_at,
        "updated_at": updated_at,
        "created_by": None,
        "is_teacher_manual": False,
        "is_course_selectable": True,
        "student_visible": False,
        "type": "exam",
        "status": status_text,
        "item_count": question_count,
        "duration_minutes": int(params.get("duration_minutes") or 0),
    }


def _effective_role_from_payload(auth_payload: Dict[str, Any]) -> tuple[str, str]:
    user = resolve_token_payload_user(auth_payload)
    profile = get_user_by_id(user["user_id"]) or {}
    profile_role = str(profile.get("role") or "").strip().lower()
    role = profile_role if profile_role in ELEVATED_ROLES else user["role"]
    return user["user_id"], role


def _is_teacher_or_admin_payload(auth_payload: Dict[str, Any]) -> bool:
    _, role = _effective_role_from_payload(auth_payload)
    return role in {"teacher", "admin"}





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

    common_books = list_textbooks(category="common")

    if ids:
        known_ids = set(ids)
        missing_common = [
            book
            for book in common_books
            if (book.get("textbook_id") or book.get("id")) not in known_ids
        ]
        if not missing_common:
            return ids
        meta = [*items, *[_build_library_meta(book) for book in missing_common]]
        set_user_kv(user_id, _TEXTBOOK_LIBRARY_KEY, json.dumps(meta, ensure_ascii=False))
        return _library_ids_from_meta(meta)

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

    answer_time: Optional[float] = None

    step_correctness: List[Dict[str, Any]] = Field(default_factory=list)

    submission_id: str = Field(min_length=1, max_length=160)



class RatingBatchSubmitRequest(BaseModel):

    items: List[RatingSubmitRequest] = Field(min_length=1, max_length=100)





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






class CourseMission(BaseModel):
    mission_id: int
    title: str
    detail: str
    action_label: str = "Start"


class CourseUnit(BaseModel):
    unit_id: int
    title: str
    type: str
    detail: str
    estimated_minutes: int = 0
    missions: List[CourseMission] = Field(default_factory=list)


class CourseCreateRequest(BaseModel):
    id: str
    title: str
    description: str
    difficulty: str
    duration: str
    tags: List[str] = Field(default_factory=list)
    focus_tags: List[str] = Field(default_factory=list)
    schedule: Optional[str] = None
    target_ovr: int = 0
    textbook_id: str
    textbook_pages: int = 0
    is_demo: bool = False
    units: List[Dict[str, Any]] = Field(default_factory=list)


class CourseResponse(BaseModel):
    id: str
    title: str
    description: str
    difficulty: str
    duration: str
    tags: List[str] = Field(default_factory=list)
    focus_tags: List[str] = Field(default_factory=list)
    schedule: Optional[str] = None
    target_ovr: int = 0
    textbook_id: str
    textbook_pages: int = 0
    is_demo: bool = False
    units: List[CourseUnit] = Field(default_factory=list)


class CourseListResponse(BaseModel):
    courses: List[CourseResponse]


class CourseEnrollResponse(BaseModel):
    course_id: str
    progress: Dict[str, Any] = Field(default_factory=dict)
    percent: float = 0.0
    status: str = "enrolled"
    last_action: Optional[str] = None


class CourseProgressRequest(BaseModel):
    progress: Dict[str, Any] = Field(default_factory=dict)
    percent: float = 0.0
    last_action: Optional[str] = None


class CourseReorderRequest(BaseModel):
    course_ids: List[str] = Field(default_factory=list)


class CourseProgressResponse(BaseModel):
    course_id: str
    progress: Dict[str, Any] = Field(default_factory=dict)
    percent: float = 0.0
    last_action: Optional[str] = None
    status: str = "enrolled"


class CourseEnrollmentListResponse(BaseModel):
    enrollments: List[CourseEnrollResponse]






def _get_user_id(

    credentials: HTTPAuthorizationCredentials = Depends(security),

) -> str:

    if credentials is None:

        raise HTTPException(status_code=401, detail="Missing token")

    payload = decode_token(credentials.credentials)

    if not payload:

        raise HTTPException(status_code=401, detail="Invalid token")

    user = resolve_token_payload_user(payload)
    if not user["user_id"]:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user["user_id"]


def _get_auth_payload(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing token")
    payload = decode_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = resolve_token_payload_user(payload)
    if not user["user_id"]:
        raise HTTPException(status_code=401, detail="Invalid token")
    return {**payload, "sub": user["user_id"], "username": user["username"], "role": user["role"]}


def _require_admin_payload(
    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),
) -> Dict[str, Any]:
    if str(auth_payload.get("role") or "").strip().lower() != "admin":
        raise HTTPException(status_code=403, detail="Admin only")
    return auth_payload


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
    payload = decode_token(token)
    if not payload:
        await websocket.close(code=1008)
        return
    user_id = payload.get("sub")
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

    postgres_rating_store.require_ready()

    init_weakness_db()

    init_teacher_exam_document_db()

    init_textbook_db()
    init_serverchat()

    if not _embedded_background_workers_enabled():
        return

    try:

        warmup_sympy_pool()

    except Exception:

        pass

    app.state.seed_validator_task = asyncio.create_task(_seed_validator_loop())





def _to_user_profile_payload(profile: Dict[str, Optional[str]]) -> Dict[str, Optional[str]]:
    return {
        "user_id": profile.get("user_id") or "",
        "username": profile.get("username") or "",
        "name": profile.get("name") or "",
        "role": profile.get("role"),
        "grade": profile.get("grade"),
        "track": profile.get("track"),
        "subject": profile.get("subject"),
        "school": profile.get("school"),
        "email": profile.get("email") or profile.get("username"),
    }


@app.get("/auth/me", response_model=UserProfile)
def get_profile(user_id: str = Depends(_get_user_id)) -> UserProfile:
    profile = get_auth_user_by_id(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User not found")
    payload = _to_user_profile_payload(profile)
    return UserProfile(**payload)


@app.put("/auth/me", response_model=UserProfile)
def update_profile(
    payload: UserProfileUpdateRequest,
    user_id: str = Depends(_get_user_id),
) -> UserProfile:
    try:
        updated = update_user_profile(
            user_id=user_id,
            username=payload.username,
            password=payload.password,
            name=payload.name,
            grade=payload.grade,
            track=payload.track,
            subject=payload.subject,
            school=payload.school,
            email=payload.email,
            profile_image=None,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    payload_data = _to_user_profile_payload(updated)
    return UserProfile(**payload_data)


@app.delete("/auth/me")
def delete_profile(
    payload: UserProfileDeleteRequest,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, str]:
    try:
        delete_user_account(user_id, password=payload.password)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"status": "deleted"}


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





@app.post("/auth/teacher/register", response_model=TeacherAuthResponse, status_code=201)

def register_teacher_endpoint(payload: TeacherRegisterRequest) -> TeacherAuthResponse:

    try:

        user_id = register_teacher(

            email=payload.email,

            password=payload.password,

            name=payload.name,

        )

    except ValueError as exc:

        raise HTTPException(status_code=400, detail=str(exc)) from exc

    token = create_token(user_id, role="teacher")

    return TeacherAuthResponse(

        token=token,

        username=payload.email,

        role="teacher",

        name=payload.name,

    )





@app.post("/auth/teacher/login", response_model=TeacherAuthResponse)

def login_teacher_endpoint(payload: TeacherLoginRequest) -> TeacherAuthResponse:

    user = authenticate_teacher(email=payload.email, password=payload.password)

    if not user:

        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_token(user["user_id"], role=user["role"])

    return TeacherAuthResponse(

        token=token,

        username=user["username"],

        role=user["role"],

        name=user["name"],

    )





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
    target = get_social_user_by_username(payload.username)
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
    other = get_social_user_by_id(request["from_user_id"])
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


@app.get("/social/friends/rankings", response_model=FriendRankingsResponse)
def list_friend_rankings(user_id: str = Depends(_get_user_id)) -> FriendRankingsResponse:
    me_profile = get_social_user_by_id(user_id) or {}
    me_rating = fetch_user_rating(user_id)
    friend_profiles = get_friends(user_id)

    rows: List[Dict[str, Any]] = [
        {
            "user_id": user_id,
            "username": (me_profile.get("username") or me_profile.get("name") or "me"),
            "visible_ovr": float(me_rating.ovr),
            "is_me": True,
        }
    ]
    seen_user_ids = {user_id}
    for friend in friend_profiles:
        friend_id = str(friend.get("user_id") or "")
        if not friend_id or friend_id in seen_user_ids:
            continue
        seen_user_ids.add(friend_id)
        rating = fetch_user_rating(friend_id)
        rows.append(
            {
                "user_id": friend_id,
                "username": (friend.get("username") or friend.get("name") or friend_id),
                "visible_ovr": float(rating.ovr),
                "is_me": False,
            }
        )

    rows.sort(key=lambda row: row["visible_ovr"], reverse=True)
    ranked = [
        FriendRankItem(
            user_id=row["user_id"],
            username=row["username"],
            visible_ovr=row["visible_ovr"],
            rank=index + 1,
            is_me=bool(row["is_me"]),
        )
        for index, row in enumerate(rows)
    ]
    return FriendRankingsResponse(ranks=ranked)





@app.post("/social/friends/add", response_model=FriendProfile)

def add_friend_handler(

    payload: FriendAddRequest,

    user_id: str = Depends(_get_user_id),

) -> FriendProfile:

    friend = get_social_user_by_username(payload.username)

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

    friend = get_social_user_by_username(payload.username)

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

    type: Optional[str] = None,

    tag: Optional[str] = None,

    user_id: str = Depends(_get_user_id),

) -> TextbookListResponse:

    allowed_ids = _ensure_default_library(user_id)

    if allowed_ids:
        effective_category = category
        if not effective_category:
            normalized_type = (type or "").strip().lower()
            if normalized_type in {"textbook", "textbooks"}:
                effective_category = "textbook"
            elif normalized_type == "common":
                effective_category = "common"
        items = list_textbooks(
            category=effective_category,

            tag=tag,

            textbook_ids=allowed_ids,

        )

    else:

        items = []

    return TextbookListResponse(

        textbooks=[TextbookResponse(**_with_textbook_visibility_flags(item)) for item in items],

    )



@app.get("/teacher/documents", response_model=TextbookListResponse)

def list_teacher_documents(

    type: Optional[str] = None,

    tag: Optional[str] = None,

    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),

) -> TextbookListResponse:

    user_id, effective_role = _effective_role_from_payload(auth_payload)
    if effective_role not in {"teacher", "admin"}:
        raise HTTPException(status_code=403, detail="Teacher only")

    allowed_ids = _ensure_default_library(user_id)

    category = None
    normalized_type = (type or "").strip().lower()
    if normalized_type in {"textbook", "textbooks"}:
        category = "textbook"
    elif normalized_type == "common":
        category = "common"

    if normalized_type == "exam":
        documents = list_teacher_exam_documents(user_id, limit=200)
        summaries = {
            str(item.get("exam_id") or ""): item
            for item in list_exams_by_ids([doc["exam_id"] for doc in documents])
        }
        items = []
        tag_filter = (tag or "").strip().lower()
        for doc in documents:
            summary = summaries.get(str(doc.get("exam_id") or ""))
            if not summary:
                continue
            item = _build_exam_document(
                {
                    **summary,
                    "document_title": doc.get("title"),
                    "document_created_at": doc.get("created_at"),
                    "document_updated_at": doc.get("updated_at"),
                }
            )
            if tag_filter:
                haystack = " ".join(
                    [item.get("title") or "", " ".join(item.get("tags") or [])]
                ).lower()
                if tag_filter not in haystack:
                    continue
            items.append(item)
        return TextbookListResponse(
            textbooks=[TextbookResponse(**item) for item in items],
        )

    items: List[Dict[str, Any]] = []
    if normalized_type in {"", "textbook", "textbooks"}:
        items.extend(_teacher_manual_documents())
    if allowed_ids:
        items.extend(
            list_textbooks(
                category=category,
                tag=tag,
                textbook_ids=allowed_ids,
            )
        )

    return TextbookListResponse(

        textbooks=[TextbookResponse(**_with_textbook_visibility_flags(item)) for item in items],

    )





@app.get("/textbooks/{textbook_id}", response_model=TextbookResponse)

def get_textbook_handler(

    textbook_id: str,

    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),

) -> TextbookResponse:

    user_id = str(auth_payload.get("sub") or "")

    if is_teacher_manual_textbook(textbook_id):
        if not _is_teacher_or_admin_payload(auth_payload):
            raise HTTPException(status_code=403, detail="Textbook not assigned")
        item = get_textbook(textbook_id)
        if not item:
            raise HTTPException(status_code=404, detail="Textbook not found")
        return TextbookResponse(**_with_textbook_visibility_flags(item))

    allowed_ids = _ensure_default_library(user_id)

    if not allowed_ids:

        raise HTTPException(status_code=403, detail="Textbook not assigned")

    if textbook_id not in allowed_ids:

        raise HTTPException(status_code=403, detail="Textbook not assigned")

    item = get_textbook(textbook_id)

    if not item:

        raise HTTPException(status_code=404, detail="Textbook not found")

    return TextbookResponse(**_with_textbook_visibility_flags(item))





@app.post("/textbooks", response_model=TextbookResponse, status_code=201)

def create_textbook_handler(

    payload: TextbookCreateRequest,

    user_id: str = Depends(_get_user_id),

) -> TextbookResponse:

    if not payload.title.strip():

        raise HTTPException(status_code=400, detail="title is required")

    profile = get_auth_user_by_id(user_id) or {}

    created_by = (

        (profile.get("name") or "").strip()

        or (profile.get("username") or "").strip()

        or user_id

    )

    created = create_textbook(payload.dict(), created_by)

    _upsert_library_item(user_id, created)

    return TextbookResponse(**created)





@app.get("/courses", response_model=CourseListResponse)
def list_courses_handler(
    query: Optional[str] = None,
    tag: Optional[str] = None,
    recommend_for_ovr: Optional[float] = None,
    user_id: str = Depends(_get_user_id),
) -> CourseListResponse:
    items = list_courses(
        query=query,
        tag=tag,
        limit=50,
        recommend_for_ovr=recommend_for_ovr,
    )
    return CourseListResponse(courses=[CourseResponse(**item) for item in items])


@app.get("/courses/hash-tags")
def list_course_hash_tags() -> Dict[str, List[str]]:
    items = list_courses(limit=1000)
    tags: set = set()
    for item in items:
        for t in item.get("tags") or []:
            if t:
                tags.add(str(t))
        for t in item.get("focus_tags") or []:
            if t:
                tags.add(str(t))
    return {"tags": sorted(tags)}


def _validate_generation_tags_or_400(
    hash_tags: List[str],
    *,
    allow_empty: bool = False,
) -> List[str]:
    try:
        return validate_generation_tags(hash_tags, allow_empty=allow_empty)
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _validate_exam_ranges_or_400(ranges: List[RangeInput]) -> List[Dict[str, Any]]:
    validated: List[Dict[str, Any]] = []
    has_any_tags = False
    for item in ranges:
        tags = _validate_generation_tags_or_400(item.tags, allow_empty=True)
        if tags:
            has_any_tags = True
        validated.append({"key": item.key, "tags": tags})
    if not has_any_tags:
        raise HTTPException(status_code=400, detail="ranges must include at least one hash tag")
    return validated


@app.get("/quests/generation-tags")
def list_quest_generation_tags() -> Dict[str, Any]:
    return {"groups": generation_tag_groups(), "tags": allowed_generation_tags()}



@app.get("/courses/enrolled", response_model=CourseEnrollmentListResponse)
def list_enrolled_courses_handler(
    user_id: str = Depends(_get_user_id),
) -> CourseEnrollmentListResponse:
    enrolls = list_enrollments(user_id)
    return CourseEnrollmentListResponse(
        enrollments=[CourseEnrollResponse(**e) for e in enrolls]
    )



@app.post("/courses", response_model=CourseResponse, status_code=201)
def create_course_handler(
    payload: CourseCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> CourseResponse:
    if not payload.title.strip():
        raise HTTPException(status_code=400, detail="title is required")
    if not payload.textbook_id.strip():
        raise HTTPException(status_code=400, detail="textbook_id is required")
    if is_teacher_manual_textbook(payload.textbook_id):
        raise HTTPException(
            status_code=400,
            detail="teacher_manual_textbook_not_course_selectable",
        )
    raw = payload.dict()
    try:
        cid = upsert_course(raw, is_demo=payload.is_demo)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    item = get_course(cid)
    if not item:
        raise HTTPException(status_code=500, detail="course creation failed")
    return CourseResponse(**item)


@app.get("/courses/{course_id}", response_model=CourseResponse)
def get_course_handler(
    course_id: str,
    user_id: str = Depends(_get_user_id),
) -> CourseResponse:
    item = get_course(course_id)
    if not item:
        raise HTTPException(status_code=404, detail="Course not found")
    return CourseResponse(**item)


@app.post("/courses/{course_id}/enroll", response_model=CourseEnrollResponse)
def enroll_course_handler(
    course_id: str,
    user_id: str = Depends(_get_user_id),
) -> CourseEnrollResponse:
    try:
        result = enroll_course(user_id, course_id)
    except ValueError as exc:
        detail = str(exc)
        if "course_not_found" in detail:
            raise HTTPException(status_code=404, detail="Course not found")
        if "course_limit_exceeded" in detail:
            raise HTTPException(status_code=403, detail=detail)
        raise HTTPException(status_code=400, detail=detail)
    return CourseEnrollResponse(**result)


@app.post("/courses/{course_id}/progress", response_model=CourseProgressResponse)
def update_course_progress_handler(
    course_id: str,
    payload: CourseProgressRequest,
    user_id: str = Depends(_get_user_id),
) -> CourseProgressResponse:
    result = update_progress(
        user_id,
        course_id,
        payload.progress,
        payload.percent,
        payload.last_action,
    )
    return CourseProgressResponse(**result)


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

    if payload.question_count < 4 or payload.question_count > 100:
        raise HTTPException(status_code=400, detail="question_count must be between 4 and 100")

    ranges = _validate_exam_ranges_or_400(payload.ranges)

    exam_id = str(uuid.uuid4())

    try:

        selected_concepts = [
            tag
            for exam_range in ranges
            for tag in (exam_range.get("tags") or [])
        ]

        concept_index_metadata = csat_index_metadata()

        items = plan_exam_items(

            ranges=ranges,

            difficulty_tier=payload.difficulty_tier,

            question_count=payload.question_count,

            paper_type=payload.paper_type,

            concept_difficulty_index=get_csat_concept_difficulty(selected_concepts),

            concept_combinations=get_csat_hard_combinations(selected_concepts),

        )

    except ValueError as exc:

        raise HTTPException(status_code=400, detail=str(exc)) from exc

    create_exam(
        exam_id=exam_id,
        user_id=user_id,
        params={
            **payload.model_dump(),
            "ranges": ranges,
            "concept_index": concept_index_metadata,
        },
        status="queued",
    )

    add_exam_items(exam_id, items)
    if payload.save_to_document_box:
        tags: List[str] = []
        for raw_range in ranges:
            for raw_tag in raw_range.get("tags") or []:
                text = str(raw_tag or "").strip()
                if text and text not in tags:
                    tags.append(text)
        upsert_teacher_exam_document(
            user_id,
            exam_id,
            _exam_document_title({"title": payload.title or ""}, tags),
        )
    asyncio.create_task(_run_exam_generation(exam_id, user_id))
    return ExamCreateResponse(exam_id=exam_id, status="queued")





@app.get("/exams/{exam_id}", response_model=ExamStatusResponse)

def get_exam_handler(
    exam_id: str,
    course_id: Optional[str] = None,
    user_id: str = Depends(_get_user_id),
) -> ExamStatusResponse:

    exam = get_exam(exam_id)

    if exam is None:
        if not _can_access_exam_via_course(user_id, exam_id, course_id):
            raise HTTPException(status_code=404, detail="Exam not found")
        paper_items = _exam_paper_runtime_items(exam_id)
        if paper_items is None:
            raise HTTPException(status_code=404, detail="Exam not found")
        return ExamStatusResponse(
            exam_id=exam_id,
            status="done",
            items=_resolve_items(paper_items),
        )

    if not _can_access_exam_document(user_id, exam) and not _can_access_exam_via_course(
        user_id,
        exam_id,
        course_id,
    ):

        raise HTTPException(status_code=404, detail="Exam not found")

    items = get_exam_items(exam_id)
    resolved = _resolve_items(items)
    missing = [item for item in resolved if item.codebase_id is None or item.seed is None]
    if (
        missing
        and str(exam.get("user_id") or "") == user_id
        and exam.get("status") not in {"generating", "retrying", "queued"}
    ):
        # Auto-heal: requeue exam generation to fill missing codebase/seed.
        update_exam_status(exam_id, "retrying")
        try:
            asyncio.get_event_loop().create_task(_run_exam_generation(exam_id, user_id))
        except RuntimeError:
            # If no running loop (unlikely in FastAPI), fall back to background thread.
            threading.Thread(target=asyncio.run, args=(_run_exam_generation(exam_id, user_id),), daemon=True).start()
        exam = get_exam(exam_id) or exam  # refresh status for response

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

    course_id: Optional[str] = None,

    token: Optional[str] = None,

    credentials: HTTPAuthorizationCredentials = Depends(security),

) -> Response:

    if build_exam_pdf is None:

        raise HTTPException(status_code=500, detail="PDF builder not available")



    user_id = None

    payload = None
    if token:
        payload = decode_token(token)
    elif credentials is not None:
        payload = decode_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    user_id = payload.get("sub")



    exam = get_exam(exam_id)

    if not _can_access_exam_document(user_id, exam) and not _can_access_exam_via_course(
        user_id,
        exam_id,
        course_id,
    ):

        raise HTTPException(status_code=404, detail="Exam not found")

    items = get_exam_items(exam_id)

    pdf_bytes = build_exam_pdf(items)

    disposition = "inline" if inline else "attachment"

    return Response(

        content=pdf_bytes,

        media_type="application/pdf",

        headers={"Content-Disposition": f"{disposition}; filename=exam-{exam_id}.pdf"},

    )


@app.post("/exam-editor/papers", response_model=ExamEditorPaperResponse)
def save_exam_editor_paper_handler(
    payload: ExamEditorPaperSaveRequest,
    user_id: str = Depends(_get_user_id),
) -> ExamEditorPaperResponse:
    if len(payload.items) > 100:
        raise HTTPException(status_code=400, detail="maximum 100 items allowed")
    if payload.grading_area_direction not in {"bottom", "top"}:
        raise HTTPException(status_code=400, detail="grading_area_direction must be bottom or top")
    if payload.grading_area_direction != "bottom":
        raise HTTPException(status_code=400, detail="grading_area_direction must be bottom")

    for item in payload.items:
        if not item.quest_id.strip():
            raise HTTPException(status_code=400, detail="quest_id is required for every item")
        if item.page_no is not None and item.page_no < 1:
            raise HTTPException(status_code=400, detail="page_no must be >= 1")
    geometry_per_page: Dict[int, int] = {}
    for item in payload.items:
        if item.is_geometry:
            page_no = int(item.page_no or (item.order_no // (2 if payload.two_per_page else 4)) + 1)
            geometry_per_page[page_no] = geometry_per_page.get(page_no, 0) + 1
            if geometry_per_page[page_no] > 2:
                raise HTTPException(status_code=400, detail="geometry/jsxgraph items cannot exceed 2 per page")

    try:
        upsert_user_problem_set(user_id, [item.model_dump() for item in payload.items])
        saved = save_exam_editor_paper(
            user_id=user_id,
            title=payload.title,
            items=[item.model_dump() for item in payload.items],
            two_per_page=payload.two_per_page,
            grading_area_direction=payload.grading_area_direction,
            paper_id=payload.paper_id,
            expected_updated_at=payload.expected_updated_at,
        )
    except RuntimeError as exc:
        if "version_conflict" in str(exc):
            raise HTTPException(status_code=409, detail="version_conflict") from exc
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    paper = get_exam_editor_paper(user_id, saved["paper_id"])
    if not paper:
        raise HTTPException(status_code=500, detail="failed to reload paper")
    return ExamEditorPaperResponse(**paper)


@app.get("/exam-editor/papers/{paper_id}", response_model=ExamEditorPaperResponse)
def get_exam_editor_paper_handler(
    paper_id: str,
    user_id: str = Depends(_get_user_id),
) -> ExamEditorPaperResponse:
    paper = get_exam_editor_paper(user_id, paper_id)
    if not paper:
        raise HTTPException(status_code=404, detail="paper not found")
    return ExamEditorPaperResponse(**paper)


@app.post("/exam-editor/papers/{paper_id}/deploy", response_model=ExamEditorDeployResponse)
def deploy_exam_editor_paper_handler(
    paper_id: str,
    user_id: str = Depends(_get_user_id),
) -> ExamEditorDeployResponse:
    paper = get_exam_editor_paper(user_id, paper_id)
    if not paper:
        raise HTTPException(status_code=404, detail="paper not found")
    items = paper.get("items") or []
    if not items:
        raise HTTPException(status_code=400, detail="paper has no items")
    if len(items) > 100:
        raise HTTPException(status_code=400, detail="maximum 100 items allowed")

    exam_id = str(uuid.uuid4())
    create_exam(
        exam_id=exam_id,
        user_id=user_id,
        params={
            "source": "exam_editor",
            "paper_id": paper_id,
            "question_count": len(items),
            "paper_type": "aiflow",
        },
        status="done",
    )
    payload_items: List[Dict[str, Any]] = []
    for idx, item in enumerate(items):
        quest_id = str(item.get("quest_id") or "").strip()
        if not quest_id:
            continue
        quest = get_quest(quest_id)
        q_data = (quest or {}).get("data", {})
        q_info = (quest or {}).get("info", {})
        hash_tags = q_data.get("hash_tag") or q_info.get("hash_tag") or []
        payload_items.append(
            {
                "item_index": idx,
                "status": "done",
                "subject_key": "custom",
                "hash_tags": hash_tags if isinstance(hash_tags, list) else [],
                "difficulty_tier": int(q_info.get("difficulty_tier") or 3),
                "solves_count": max(1, len((quest or {}).get("solves", []) or [])),
                "strategy_level": 3,
                "branch_conditions": 2,
                "question_type": item.get("question_type") or q_data.get("question_type"),
                "quest_id": quest_id,
                "flow_count": max(1, len((quest or {}).get("solves", []) or [])),
                "codebase_id": item.get("codebase_id") or q_data.get("codebase_id"),
                "seed": item.get("seed") or q_data.get("seed"),
                "error": None,
            }
        )
    add_exam_items(exam_id, payload_items)
    upsert_teacher_exam_document(
        user_id,
        exam_id,
        str(paper.get("title") or "").strip() or "시험지",
    )
    return ExamEditorDeployResponse(
        paper_id=paper_id,
        exam_id=exam_id,
        status="done",
        deployed_count=len(payload_items),
    )


@app.get("/exam-editor/problems/search", response_model=ExamEditorSearchResponse)
def search_exam_editor_problems_handler(
    hash_tag: Optional[str] = None,
    quest_id: Optional[str] = None,
    text: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    owned_only: bool = True,
    page: int = 1,
    page_size: int = 50,
    user_id: str = Depends(_get_user_id),
) -> ExamEditorSearchResponse:
    result = search_user_problem_set(
        user_id=user_id,
        hash_tag=hash_tag,
        quest_id=quest_id,
        text=text,
        date_from=date_from,
        date_to=date_to,
        page=page,
        page_size=page_size,
    )
    return ExamEditorSearchResponse(source_connected=False, **result)


@app.get("/teacher/store/summary")
def teacher_store_summary_handler(
    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),
) -> Dict[str, Any]:
    user_id, effective_role = _effective_role_from_payload(auth_payload)
    if effective_role not in {"teacher", "admin"}:
        raise HTTPException(status_code=403, detail="Teacher only")
    return teacher_store_summary(user_id)


@app.get("/teacher/store/items")
def teacher_store_items_handler(
    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),
) -> Dict[str, Any]:
    user_id, effective_role = _effective_role_from_payload(auth_payload)
    if effective_role not in {"teacher", "admin"}:
        raise HTTPException(status_code=403, detail="Teacher only")
    data = teacher_store_summary(user_id)
    return {
        "items": data["items"],
        "balance_points": data["balance_points"],
        "entitlements": data["entitlements"],
    }


@app.post("/teacher/store/top-up-test")
def teacher_store_top_up_test_handler(
    payload: Dict[str, Any],
    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),
) -> Dict[str, Any]:
    user_id, effective_role = _effective_role_from_payload(auth_payload)
    if effective_role not in {"teacher", "admin"}:
        raise HTTPException(status_code=403, detail="Teacher only")
    try:
        return teacher_store_top_up_test(user_id, int(payload.get("amount") or 0))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/teacher/store/purchase")
def teacher_store_purchase_handler(
    payload: Dict[str, Any],
    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),
) -> Dict[str, Any]:
    user_id, effective_role = _effective_role_from_payload(auth_payload)
    if effective_role not in {"teacher", "admin"}:
        raise HTTPException(status_code=403, detail="Teacher only")
    item_id = str(payload.get("item_id") or "").strip()
    if not item_id:
        raise HTTPException(status_code=400, detail="item_id is required")
    try:
        return teacher_store_purchase(user_id, item_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/exam-editor/tray/import")
def import_exam_editor_tray_handler(
    payload: ExamEditorImportRequest,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, Any]:
    source = get_exam(payload.source_exam_id)
    if not source or source.get("user_id") != user_id:
        raise HTTPException(status_code=404, detail="source exam not found")
    source_items = get_exam_items(payload.source_exam_id)
    selected_indexes = set(payload.item_indexes)
    selected = [item for item in source_items if item.get("item_index") in selected_indexes]
    if not selected:
        raise HTTPException(status_code=400, detail="import failed: no recognizable blocks")
    for item in selected:
        if not item.get("quest_id"):
            raise HTTPException(status_code=400, detail="import failed: block recognition missing quest_id")
    upserted = upsert_user_problem_set(user_id, selected)
    return {"imported": len(selected), "upserted": upserted}


@app.post("/exam-editor/arrange/ai", response_model=ExamEditorAiArrangeResponse)
def arrange_exam_editor_ai_handler(
    payload: ExamEditorAiArrangeRequest,
    user_id: str = Depends(_get_user_id),
) -> ExamEditorAiArrangeResponse:
    items = payload.items
    if payload.paper_id and not items:
        paper = get_exam_editor_paper(user_id, payload.paper_id)
        if not paper:
            raise HTTPException(status_code=404, detail="paper not found")
        paper_items = paper.get("items") or []
        items = [ExamEditorItemInput(**{
            "order_no": int(item.get("order_no") or idx),
            "page_no": item.get("page_no"),
            "layout_slot": item.get("layout_slot") or "auto",
            "codebase_id": item.get("codebase_id"),
            "seed": item.get("seed"),
            "quest_id": str(item.get("quest_id") or ""),
            "question_type": item.get("question_type"),
            "is_geometry": bool(item.get("is_geometry")),
        }) for idx, item in enumerate(paper_items)]

    if not items:
        raise HTTPException(status_code=400, detail="items required")
    if len(items) > 100:
        raise HTTPException(status_code=400, detail="maximum 100 items allowed")

    prompt = {
        "instruction": payload.instruction or "Arrange exam items while preserving 2x2 constraints.",
        "rules": [
            "max 100 items",
            "2x2 grid immutable",
            "geometry/jsxgraph only one per row and max two per page",
            "two-per-page mode expands grading area downward only",
        ],
        "items": [item.model_dump() for item in items],
    }
    provider = get_default_provider()
    safety = evaluate_request(json.dumps(prompt, ensure_ascii=False), provider)
    if not safety.get("allowed", False):
        reason_obj = safety.get("reason")
        detail = reason_obj.detail if reason_obj else "rejected by safety guard"
        return ExamEditorAiArrangeResponse(accepted=False, reason=detail, items=[])

    sorted_items = sorted(
        [item.model_dump() for item in items],
        key=lambda x: (0 if x.get("is_geometry") else 1, str(x.get("question_type") or ""), int(x.get("order_no") or 0)),
    )
    for idx, item in enumerate(sorted_items):
        item["order_no"] = idx
    return ExamEditorAiArrangeResponse(accepted=True, reason=None, items=sorted_items)


@app.post("/exam-editor/source/toggle")
def toggle_exam_editor_source_handler(
    payload: ExamEditorSourceToggleRequest,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, Any]:
    enabled = set_source_connected(user_id, payload.enabled)
    return {"enabled": enabled}





@app.get("/quests", response_model=QuestSearchResponse)

def search_quests_handler(

    hash_tag: Optional[str] = None,

    quest_id: Optional[str] = None,

    text: Optional[str] = None,
    is_variant: Optional[bool] = None,
    is_mcq_branch: Optional[bool] = None,

    page: int = 1,

    page_size: int = 20,

    auth_payload: Dict[str, Any] = Depends(_get_auth_payload),

) -> QuestSearchResponse:
    user_id, effective_role = _effective_role_from_payload(auth_payload)

    if effective_role == "teacher":
        if is_variant is True or is_mcq_branch is True:
            safe_page = max(1, page)
            safe_page_size = max(1, min(page_size, 200))
            return QuestSearchResponse(
                quests=[],
                total=0,
                page=safe_page,
                page_size=safe_page_size,
            )
        owned_results = search_user_problem_set(
            user_id=user_id,
            hash_tag=hash_tag,
            quest_id=quest_id,
            text=text,
            page=page,
            page_size=page_size,
        )
        return QuestSearchResponse(
            quests=owned_results.get("items", []),
            total=int(owned_results.get("total") or 0),
            page=int(owned_results.get("page") or max(1, page)),
            page_size=int(
                owned_results.get("page_size") or max(1, min(page_size, 200))
            ),
        )

    results = search_quests(

        hash_tag=hash_tag,

        quest_id=quest_id,

        text_query=text,

        page=page,

        page_size=page_size,

    )

    quests = results.get("quests", [])
    if isinstance(quests, list):
        filtered: List[Dict[str, Any]] = []
        for quest in quests:
            data = (quest.get("data", {}) or {}) if isinstance(quest, dict) else {}
            variant_meta = data.get("variant_meta") if isinstance(data.get("variant_meta"), dict) else {}
            has_variant_meta = bool(variant_meta)
            is_mcq = bool(variant_meta.get("is_mcq_branch")) or bool(data.get("mcq_conversion"))
            if is_variant is not None and has_variant_meta != is_variant:
                continue
            if is_mcq_branch is not None and is_mcq != is_mcq_branch:
                continue
            if text and text.strip():
                # Keep text filtering path aligned with quest-title normalization.
                if text.strip().lower() not in quest_title_text(quest).lower():
                    continue
            filtered.append(enrich_quest_search_item(quest))
        results["quests"] = filtered
        results["total"] = len(filtered)
    return QuestSearchResponse(**results)





@app.get("/quests/generate/status")

def quest_generate_status(
    request_id: str,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, Any]:

    job_state = _get_quest_generation_job(request_id, user_id)
    if job_state is not None:
        return {
            "request_id": request_id,
            **_quest_job_to_status_payload(job_state),
        }

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

    owner_id = status.get("user_id")
    if owner_id and owner_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorised to view this generation")

    visible_status = {key: value for key, value in status.items() if key != "user_id"}
    return {"request_id": request_id, **visible_status}





async def _run_quest_generation_task(

    request_id: str,

    payload: QuestGenerateRequest,

    user_id: str,

) -> None:
    cancel_event = register_token(request_id)

    try:
        hash_tags = validate_generation_tags(payload.hash_tags)
    except (TypeError, ValueError) as exc:
        _set_gen_status(
            request_id,
            str(exc),
            status="failed",
            error=str(exc),
        )
        return

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

        check_cancelled(cancel_event)

        _set_gen_status(request_id, "generating", status="generating")

        async with _GEN_SEMAPHORE:

            check_cancelled(cancel_event)

            storage_data = await asyncio.to_thread(

                make,

                hash_tags,

                payload.solves_count,

                payload.strategy_level,

                payload.branch_conditions,

                payload.reference_quest_id,

                True,

                payload.seed,

                None,

                None,

                _status_cb,

                cancel_event=cancel_event,

            )

        check_cancelled(cancel_event)

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
    finally:
        release_token(request_id)


def _variant_rejection(reason_code: str, reason_message: str, suggested_fix: Optional[str] = None) -> VariantGenerateResponse:
    return VariantGenerateResponse(
        success=False,
        quest=None,
        rejection=VariantRejection(
            allowed=False,
            reason_code=reason_code,
            reason_message=reason_message,
            suggested_fix=suggested_fix,
        ),
    )


def _resolve_variant_tags(
    tags: List[str],
    base_quest_ref: Optional[VariantBaseQuestRef],
) -> List[str]:
    clean_tags = [t.strip() for t in tags if isinstance(t, str) and t.strip()]
    if clean_tags:
        return validate_generation_tags(clean_tags)
    if base_quest_ref and base_quest_ref.quest_id:
        quest = get_quest(base_quest_ref.quest_id)
        if quest:
            base_tags = (quest.get("info", {}) or {}).get("hash_tag", []) or []
            return validate_generation_tags(base_tags)
    return []


def _validate_variant_prompt(prompt_text: str) -> Optional[VariantGenerateResponse]:
    excessive = check_excessive(prompt_text)
    if excessive is not None:
        return _variant_rejection(
            reason_code="excessive_request",
            reason_message=excessive.detail,
            suggested_fix=excessive.suggestion,
        )
    harmful = check_harmful(prompt_text)
    if harmful is not None:
        return _variant_rejection(
            reason_code="harmful_content",
            reason_message=harmful.detail,
            suggested_fix=harmful.suggestion,
        )
    return None


def _normalize_variant_tag(tag: Any) -> str:
    return str(tag or "").strip().lstrip("#").strip()


def _resolve_cached_variant_runtime_params(
    *,
    tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
) -> Tuple[int, int, int, Optional[Dict[str, Any]]]:
    requested = (solves_count, strategy_level, branch_conditions)
    selected_tags = {
        _normalize_variant_tag(tag)
        for tag in tags
        if _normalize_variant_tag(tag)
    }
    if not selected_tags:
        return (*requested, None)

    best: Optional[Tuple[Tuple[int, int, int, int], Dict[str, Any], Tuple[int, int, int]]] = None
    for entry in list_codebase_stats():
        if int(entry.get("cached_seeds") or 0) <= 0:
            continue
        if str(entry.get("status") or "ok") == "disabled":
            continue
        entry_tags = {
            _normalize_variant_tag(tag)
            for tag in (entry.get("tags") or [])
            if _normalize_variant_tag(tag)
        }
        if not entry_tags or not entry_tags.issubset(selected_tags):
            continue
        try:
            candidate = (
                int(entry.get("solves_count") or 0),
                int(entry.get("strategy_level") or 0),
                int(entry.get("branch_conditions") or 0),
            )
        except Exception:
            continue
        if candidate[0] <= 0 or candidate[1] <= 0 or candidate[2] < 0:
            continue
        if candidate == requested:
            return (*requested, None)
        distance = (
            abs(candidate[0] - solves_count) * 2
            + abs(candidate[1] - strategy_level)
            + abs(candidate[2] - branch_conditions) * 2
        )
        rank = (
            distance,
            -len(entry_tags),
            -int(entry.get("cached_seeds") or 0),
            int(entry.get("id") or 0),
        )
        if best is None or rank < best[0]:
            best = (rank, entry, candidate)

    if best is None:
        return (*requested, None)

    _, entry, candidate = best
    fallback = {
        "requested": {
            "solves_count": solves_count,
            "strategy_level": strategy_level,
            "branch_conditions": branch_conditions,
        },
        "used": {
            "solves_count": candidate[0],
            "strategy_level": candidate[1],
            "branch_conditions": candidate[2],
        },
        "codebase_id": entry.get("id"),
        "cached_seeds": entry.get("cached_seeds"),
        "reason": "nearest_cached_codebase",
    }
    return (*candidate, fallback)


_VARIANT_METRIC_LABELS = {
    "concept": "개념 난이도",
    "reasoning": "추론 난이도",
    "insight": "발상 난이도",
    "calculation": "계산량",
    "information": "정보 밀도",
    "trap": "함정 강도",
    "compression": "압축도",
    "concept_count": "개념 수",
    "concept_depth": "개념 깊이",
    "prerequisite_depth": "선수 개념 깊이",
    "graph_depth": "풀이 그래프 깊이",
    "graph_width": "풀이 그래프 폭",
    "branch_factor": "분기 계수",
    "merge_factor": "병합 계수",
    "insight_count": "발상 수",
    "insight_depth": "발상 깊이",
    "insight_uniqueness": "발상 희소성",
    "condition_count": "조건 수",
    "condition_density": "조건 밀도",
    "hidden_information": "숨은 정보량",
    "implicit_constraints": "암묵 제약",
    "symbolic_operations": "기호 조작량",
    "algebra_steps": "대수 계산 단계",
    "derivative_steps": "미분 단계",
    "integral_steps": "적분 단계",
    "simplification_cost": "식 정리 비용",
    "trap_count": "함정 수",
    "trap_severity": "함정 강도",
    "compression_score": "압축 점수",
    "implicit_information": "암묵 정보량",
    "top_rate": "상위권 예상 정답률",
    "middle_rate": "중위권 예상 정답률",
    "low_rate": "하위권 예상 정답률",
}

_VARIANT_METRIC_DEFAULTS = {
    "concept": 6,
    "reasoning": 6,
    "insight": 5,
    "calculation": 4,
    "information": 5,
    "trap": 3,
    "compression": 4,
    "concept_count": 3,
    "concept_depth": 5,
    "prerequisite_depth": 4,
    "graph_depth": 5,
    "graph_width": 3,
    "branch_factor": 1,
    "merge_factor": 1,
    "insight_count": 2,
    "insight_depth": 5,
    "insight_uniqueness": 5,
    "condition_count": 4,
    "condition_density": 5,
    "hidden_information": 4,
    "implicit_constraints": 4,
    "symbolic_operations": 4,
    "algebra_steps": 4,
    "derivative_steps": 2,
    "integral_steps": 1,
    "simplification_cost": 4,
    "trap_count": 2,
    "trap_severity": 3,
    "compression_score": 4,
    "implicit_information": 4,
    "top_rate": 82,
    "middle_rate": 46,
    "low_rate": 18,
}

_VARIANT_METRIC_DIRECTIVES = {
    "concept": "서로 다른 개념을 결합하되 정답 변수는 하나로 유지한다.",
    "reasoning": "조건 해석에서 결론까지 중간 추론 단계를 분명히 만든다.",
    "insight": "정방향 계산보다 먼저 떠올려야 하는 관점 전환을 넣는다.",
    "calculation": "계산량을 조절하되 풀이 검증 가능한 식 변형으로 제한한다.",
    "information": "짧은 조건 안에 범위, 부호, 존재 조건을 함께 담는다.",
    "trap": "정의역, 부호, 필요충분 조건 중 하나를 놓치면 오답이 되게 한다.",
    "compression": "문장 하나에서 여러 암묵 결론을 끌어내게 한다.",
    "concept_count": "사용 개념 수를 지표에 맞춰 늘리거나 줄인다.",
    "concept_depth": "공식 대입보다 동치 변환이나 역조건 사용을 우선한다.",
    "prerequisite_depth": "선수 개념을 직접 노출하지 말고 풀이 중 필요하게 만든다.",
    "graph_depth": "풀이 흐름의 최장 경로를 지표에 맞춰 깊게 만든다.",
    "graph_width": "여러 관점을 비교한 뒤 하나의 결론으로 좁히게 한다.",
    "branch_factor": "부호, 범위, 위치 조건으로 케이스 분류를 만든다.",
    "merge_factor": "분기된 케이스가 공통 구조로 다시 합쳐지게 한다.",
    "insight_count": "핵심 발상 수를 지표에 맞춰 명확히 배치한다.",
    "insight_depth": "숨은 구조를 읽어야 풀리는 발상을 넣는다.",
    "insight_uniqueness": "대표 유형 풀이가 바로 통하지 않는 관점 전환을 둔다.",
    "condition_count": "명시 조건 수를 지표에 맞춘다.",
    "condition_density": "한 문장에 여러 조건을 압축한다.",
    "hidden_information": "직접 쓰이지 않은 정보를 추론하게 한다.",
    "implicit_constraints": "실수성, 자연수성, 존재성 같은 암묵 제약을 둔다.",
    "symbolic_operations": "계수 비교나 식 변형 횟수를 지표에 맞춘다.",
    "algebra_steps": "대수 정리 단계 수를 지표에 맞춘다.",
    "derivative_steps": "도함수나 극값 조건 사용 횟수를 지표에 맞춘다.",
    "integral_steps": "정적분 조건이나 넓이 해석 사용 횟수를 지표에 맞춘다.",
    "simplification_cost": "최종 식 정리 비용을 지표에 맞춘다.",
    "trap_count": "오답 유발 요소 수를 지표에 맞춘다.",
    "trap_severity": "초반 조건 누락이 전체 풀이를 흔들도록 함정 강도를 조절한다.",
    "compression_score": "짧은 문장에서 많은 결론을 끌어내게 한다.",
    "implicit_information": "압축된 문장 속 암묵 정보를 풀이 핵심으로 둔다.",
    "top_rate": "상위권 예상 정답률에 맞춰 발상 장벽을 조절한다.",
    "middle_rate": "중위권 예상 정답률에 맞춰 계산과 함정의 부담을 조절한다.",
    "low_rate": "하위권 예상 정답률에 맞춰 접근 가능성을 조절한다.",
}

_VARIANT_METRIC_EXAMPLES = {
    "insight": "예: 조건을 정답에서 역추적해야 자연스럽게 식이 세워진다.",
    "trap": "예: 정의역이나 부호 조건을 빠뜨리면 다른 정수 답이 나온다.",
    "condition_density": "예: 연속성, 범위, 극값 조건을 한 문장에 압축한다.",
    "branch_factor": "예: 매개변수 부호에 따라 두 케이스를 나누고 마지막에 병합한다.",
    "algebra_steps": "예: 계수 비교와 인수분해를 거쳐야 정수 k가 드러난다.",
    "derivative_steps": "예: 도함수의 부호 변화로 극값 위치를 제한한다.",
    "integral_steps": "예: 정적분 조건으로 상수를 복원한 뒤 답을 계산한다.",
    "compression_score": "예: 짧은 조건에서 연속성, 존재성, 부호 정보를 꺼낸다.",
}

_VARIANT_METRIC_LOW_EXAMPLES = {
    "insight": "예: 대표 성질을 바로 적용하면 풀이가 시작된다.",
    "trap": "예: 함정은 줄이고 계산 검산으로 난도를 만든다.",
    "condition_density": "예: 조건을 문장별로 분리해 직접적으로 제시한다.",
    "branch_factor": "예: 케이스 분류 없이 한 흐름으로 풀리게 한다.",
    "trap_count": "예: 오답 유발 요소를 거의 두지 않는다.",
    "trap_severity": "예: 조건을 하나 놓쳐도 검산으로 회복 가능하게 한다.",
    "compression_score": "예: 압축된 암묵 조건보다 명시 조건 중심으로 만든다.",
}


_VARIANT_METRIC_LOW_DIRECTIVES = {
    "insight": "대표 성질이나 공식 적용이 바로 보이게 한다.",
    "trap": "오답 유발 조건을 최소화하고 검산으로 확인 가능하게 한다.",
    "condition_density": "조건을 문장별로 분리해 직접적으로 제시한다.",
    "branch_factor": "케이스 분류 없이 단일 풀이 흐름으로 만든다.",
    "trap_count": "오답 유발 요소를 거의 두지 않는다.",
    "trap_severity": "조건 누락이 치명적 오답으로 이어지지 않게 한다.",
    "compression_score": "암묵 조건보다 명시 조건 중심으로 만든다.",
    "information": "범위, 부호, 존재 조건을 필요한 만큼만 명시한다.",
    "compression": "압축 표현보다 읽히는 조건 제시를 우선한다.",
    "hidden_information": "숨은 정보 추론을 최소화한다.",
    "implicit_constraints": "필요한 제약을 문제 본문에 명시한다.",
    "implicit_information": "암묵 정보보다 직접 제시된 정보로 풀리게 한다.",
    "algebra_steps": "대수 계산 단계를 짧고 검산 가능하게 유지한다.",
    "calculation": "계산량을 낮추고 한두 번의 식 정리로 답이 나오게 한다.",
    "graph_depth": "풀이 흐름을 짧은 직선형 구조로 만든다.",
    "graph_width": "동시에 비교해야 하는 풀이 갈래를 줄인다.",
}


def _variant_metric_is_low(key: str, value: int) -> bool:
    if key in {"branch_factor", "trap_count"}:
        return value <= 0
    if key in {"condition_count", "insight_count"}:
        return value <= 1
    return value <= 2


def _variant_metric_is_high(key: str, value: int) -> bool:
    if key in {"branch_factor", "trap_count"}:
        return value >= 2
    if key in {"condition_count", "insight_count"}:
        return value >= 3
    return value >= 7


def _variant_metric_directive(key: str, value: int) -> str:
    if _variant_metric_is_low(key, value):
        return _VARIANT_METRIC_LOW_DIRECTIVES.get(
            key,
            f"{_VARIANT_METRIC_LABELS.get(key, key)} 값을 낮은 수준으로 반영한다.",
        )
    return _VARIANT_METRIC_DIRECTIVES.get(
        key,
        f"{_VARIANT_METRIC_LABELS.get(key, key)} 값을 {value} 수준으로 반영한다.",
    )


def _variant_metric_contract(key: str, value: int) -> str:
    """횟수형 값은 검증 가능한 수량으로, 점수형 값은 강도로 모델에 전달한다."""
    if key.endswith("_rate"):
        return f"학생 시뮬레이션 목표 정답률 {value}%에 맞춰 난도를 보정한다."
    if key.endswith("_count") or key.endswith("_steps") or key in {
        "symbolic_operations",
        "branch_factor",
        "merge_factor",
    }:
        return f"문제와 풀이에서 식별 가능한 해당 요소를 목표 {value}회(개)로 설계한다."
    return f"1~10 척도에서 목표 강도 {value}가 드러나도록 설계한다."


def _variant_metric_example(key: str, value: int) -> Optional[str]:
    if _variant_metric_is_low(key, value):
        return _VARIANT_METRIC_LOW_EXAMPLES.get(key)
    if _variant_metric_is_high(key, value):
        return _VARIANT_METRIC_EXAMPLES.get(key)
    return None


def _compact_variant_text(value: Any, limit: int = 240) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= limit:
        return text
    return text[:limit].rstrip() + "..."


def _variant_metric_value(value: Any) -> Optional[int]:
    try:
        return int(round(float(value)))
    except Exception:
        return None


def _normalize_variant_metrics(raw_metrics: Any) -> Dict[str, int]:
    if not isinstance(raw_metrics, dict):
        return {}
    metrics: Dict[str, int] = {}
    for key, value in raw_metrics.items():
        clean_key = str(key).strip()
        number = _variant_metric_value(value)
        if clean_key and number is not None:
            metrics[clean_key] = number
    return metrics


def _variant_metric_weight(item: Tuple[str, int]) -> float:
    key, value = item
    baseline = _VARIANT_METRIC_DEFAULTS.get(key, 5)
    difference = abs(value - baseline)
    return difference / 10.0 if key.endswith("_rate") else float(difference)


def _build_variant_generation_context(payload: Any, tags: List[str]) -> Dict[str, Any]:
    """필요 변수: 생성 요청·태그·UI 기본값. 작동 원리: 사용자가 조절한 축만 하드 제약으로 분리해 상충 지시를 줄인다."""
    profile = payload.advanced_profile if isinstance(payload.advanced_profile, dict) else {}
    metrics = _normalize_variant_metrics(payload.advanced_metrics)
    if not metrics:
        metrics = _normalize_variant_metrics(profile.get("metrics"))

    changed_metrics = {
        key: value
        for key, value in metrics.items()
        if value != _VARIANT_METRIC_DEFAULTS.get(key, 5)
    }
    dominant_metrics = []
    for key, value in sorted(
        changed_metrics.items(),
        key=_variant_metric_weight,
        reverse=True,
    )[:12]:
        dominant_metrics.append(
            {
                "id": key,
                "label": _VARIANT_METRIC_LABELS.get(key, key),
                "value": value,
                "directive": _variant_metric_directive(key, value),
                "contract": _variant_metric_contract(key, value),
            }
        )

    examples = []
    for item in dominant_metrics:
        metric_id = str(item.get("id") or "")
        metric_value = _variant_metric_value(item.get("value")) or 0
        example = _variant_metric_example(metric_id, metric_value)
        if example and example not in examples:
            examples.append(example)

    node_directives = []
    for node in getattr(payload, "flow_draft", [])[:32]:
        instruction = node.teacher_instruction or node.prompt_text or node.text
        text = _compact_variant_text(instruction, 260)
        if not text:
            continue
        node_directives.append(
            {
                "node_id": node.node_id,
                "node_type": node.node_type,
                "tags": [str(tag) for tag in (node.hash_tags or [])[:5]],
                "branches": [str(branch) for branch in (node.branches or [])[:8]],
                "instruction": text,
            }
        )

    return {
        "tags": tags,
        "requested_params": {
            "solves_count": int(getattr(payload, "solves_count", 0) or 0),
            "strategy_level": int(getattr(payload, "strategy_level", 0) or 0),
            "branch_conditions": int(getattr(payload, "branch_conditions", 0) or 0),
        },
        "expected_number": _compact_variant_text(profile.get("expected_number"), 80),
        "profile_label": _compact_variant_text(profile.get("label"), 80),
        "profile_intent": _compact_variant_text(profile.get("intent"), 180),
        "metrics": metrics,
        "changed_metrics": changed_metrics,
        "dominant_metrics": dominant_metrics,
        "node_directives": node_directives,
        "examples": examples[:8],
        "prompt_excerpt": _compact_variant_text(payload.prompt, 900),
    }


def _build_variant_request_signature(
    *,
    tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    generation_context: Dict[str, Any],
) -> str:
    material = {
        "tags": tags,
        "solves_count": solves_count,
        "strategy_level": strategy_level,
        "branch_conditions": branch_conditions,
        "generation_context": generation_context,
    }
    raw = json.dumps(material, ensure_ascii=False, sort_keys=True, default=str)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _generate_variant_quest(
    *,
    tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    seed_override: Optional[int],
    reference_quest_id: Optional[str],
    generation_context: Optional[Dict[str, Any]] = None,
    request_signature: Optional[str] = None,
) -> Dict[str, Any]:
    if generation_context:
        runtime_solves = solves_count
        runtime_strategy = strategy_level
        runtime_branches = branch_conditions
        fallback = None
    else:
        runtime_solves, runtime_strategy, runtime_branches, fallback = (
            _resolve_cached_variant_runtime_params(
                tags=tags,
                solves_count=solves_count,
                strategy_level=strategy_level,
                branch_conditions=branch_conditions,
            )
        )
    storage_data = make(
        tags,
        runtime_solves,
        runtime_strategy,
        runtime_branches,
        reference_quest_id,
        True,
        seed_override,
        None,
        None,
        None,
        generation_context=generation_context,
        request_signature=request_signature,
    )
    if isinstance(storage_data.get("data"), dict):
        if fallback is not None:
            storage_data["data"]["variant_runtime_params"] = fallback
        if generation_context:
            storage_data["data"]["advanced_generation_context"] = generation_context
        if request_signature:
            storage_data["data"]["variant_request_signature"] = request_signature[:16]
    if not store_data(storage_data):
        detail = get_last_store_error() or "failed to store quest"
        raise RuntimeError(detail)
    return storage_data


def _to_number(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    try:
        return float(text)
    except Exception:
        return None


def _build_mcq_choices(answer_value: Any, policy: McqPolicy) -> Tuple[List[str], int]:
    answer_num = _to_number(answer_value)
    if answer_num is None:
        answer_text = str(answer_value).strip() or "0"
        choices = [answer_text]
        while len(choices) < 5:
            choices.append(f"{answer_text}_{len(choices)}")
        random.shuffle(choices)
        return choices, choices.index(answer_text)

    answer_int = int(round(answer_num))
    if policy.offset_pattern == "pm1":
        offsets = [-2, -1, 0, 1, 2]
    elif policy.offset_pattern == "mixed":
        offsets = [-2, -1, 0, 2, 4]
    else:
        offsets = [-4, -2, 0, 2, 4]

    values = [answer_int + off for off in offsets]
    if policy.random_choices:
        while len(set(values)) < 5:
            values.append(answer_int + random.randint(-10, 10))
        values = list(dict.fromkeys(values))[:5]
        random.shuffle(values)
    answer_index = values.index(answer_int) if answer_int in values else 0
    return [str(v) for v in values[:5]], answer_index





@app.post("/quests/generate", response_model=QuestGenerateResponse)

async def generate_quest_handler(

    payload: QuestGenerateRequest,

    user_id: str = Depends(_get_user_id),

) -> QuestGenerateResponse:

    hash_tags = _validate_generation_tags_or_400(payload.hash_tags)

    if not hash_tags:

        raise HTTPException(status_code=400, detail="hash_tags must not be empty")

    payload = payload.model_copy(update={"hash_tags": hash_tags, "strict_tags": True})

    request_id = payload.request_id or str(uuid.uuid4())

    sm = JobStateMachine()
    job = sm.start_job(
        user_id=user_id,
        job_type="quest_generation",
        payload={
            "user_id": user_id,
            "hash_tags": hash_tags,
            "solves_count": payload.solves_count,
            "strategy_level": payload.strategy_level,
            "branch_conditions": payload.branch_conditions,
            "reference_quest_id": payload.reference_quest_id,
            "strict_tags": True,
            "seed": payload.seed,
        },
        job_id=request_id,
    )
    owner_id = job.get("user_id")
    if owner_id and owner_id != user_id:
        raise HTTPException(status_code=409, detail="request_id already exists")
    if job.get("operation") != "quest_generation":
        raise HTTPException(status_code=409, detail="request_id already exists")

    if _QUEST_GENERATE_FAST_WAIT_MS > 0:
        deadline = time.monotonic() + (_QUEST_GENERATE_FAST_WAIT_MS / 1000.0)
        while time.monotonic() < deadline:
            status = _get_quest_generation_job(request_id, user_id) or {}
            state = status.get("status")
            if state in {"done", "failed", "rejected"}:
                mapped = _quest_job_to_status_payload(status)
                return QuestGenerateResponse(
                    request_id=request_id,
                    status=mapped.get("status") or state,
                    quest=mapped.get("quest"),
                    error=mapped.get("error"),
                    updated_at=mapped.get("updated_at"),
                )
            await asyncio.sleep(0.05)

        status = _get_quest_generation_job(request_id, user_id) or {}
        state = status.get("status")
        if state in {"done", "failed", "rejected"}:
            mapped = _quest_job_to_status_payload(status)
            return QuestGenerateResponse(
                request_id=request_id,
                status=mapped.get("status") or state or "queued",
                quest=mapped.get("quest"),
                error=mapped.get("error"),
                updated_at=mapped.get("updated_at"),
            )

    return QuestGenerateResponse(

        request_id=request_id,

        status=str(job.get("status") or "queued"),

        quest=None,

        error=None,

        updated_at=_job_updated_at_epoch(job.get("updated_at")),

    )





@app.post("/quests/generate/cancel")
def cancel_quest_generation_handler(
    request_id: str,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, Any]:
    job_state = _get_quest_generation_job(request_id, user_id)
    if job_state is not None:
        try:
            cancel_token(request_id)
            hard_cancel_process_pool()
            JobStateMachine().cancel_job(request_id, user_id)
        except InvalidTransitionError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc
        return {"request_id": request_id, "status": "cancelled"}

    status = _get_gen_status(request_id)
    if not status:
        raise HTTPException(status_code=404, detail="Generation request not found")
    owner_id = status.get("user_id")
    if owner_id and owner_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorised to cancel this generation")
    cancel_token(request_id)
    hard_cancel_process_pool()
    _set_gen_status(
        request_id,
        "cancelled",
        status="cancelled",
        error="generation cancelled",
    )
    return {"request_id": request_id, "status": "cancelled"}


@app.post("/quests/generate/batch", response_model=ProblemSolveGenerateQueuedResponse)

async def generate_quest_batch_handler(

    payload: ProblemSolveGenerateRequest,

    user_id: str = Depends(_get_user_id),

) -> ProblemSolveGenerateQueuedResponse:

    hash_tags = _validate_generation_tags_or_400(payload.hash_tags)

    if not hash_tags:

        raise HTTPException(status_code=400, detail="hash_tags must not be empty")

    sm = JobStateMachine()
    job = sm.start_job(
        user_id=user_id,
        job_type="quest_batch_generation",
        payload={
            "user_id": user_id,
            "hash_tags": hash_tags,
            "min_difficulty_tier": payload.min_difficulty_tier,
            "max_difficulty_tier": payload.max_difficulty_tier,
            "question_count": payload.question_count,
            "strict_tags": True,
        },
    )

    return ProblemSolveGenerateQueuedResponse(
        job_id=job["job_id"],
        status=job.get("status", "queued"),
        message="Batch quest generation queued. Poll /jobs/{job_id} for completion.",
    )


@app.post("/quests/generate/stream")
async def generate_quest_batch_stream_handler(
    request: Request,
    payload: ProblemSolveGenerateRequest,
    user_id: str = Depends(_get_user_id),
):
    hash_tags = _validate_generation_tags_or_400(payload.hash_tags)
    if not hash_tags:
        raise HTTPException(status_code=400, detail="hash_tags must not be empty")

    stream_token = f"stream:{user_id}:{uuid.uuid4()}"
    cancel_event = register_token(stream_token)

    async def _event_stream():
        try:
            # 최근 풀이 이력에 없는 전역 캐시를 먼저 사용자별 큐에서 꺼낸다.
            cached_quests, cache_state = await asyncio.to_thread(
                claim_cached_quests,
                user_id=user_id,
                hash_tags=hash_tags,
                min_difficulty_tier=payload.min_difficulty_tier,
                max_difficulty_tier=payload.max_difficulty_tier,
                question_count=payload.question_count,
                prefetch_count=max(10, payload.question_count),
            )
            # 기존 캐시도 본문·정답·풀이 전체 검수를 통과한 문제만 학생에게 전달한다.
            approved_cached_quests = []
            for quest in cached_quests:
                try:
                    info = quest.get("info") if isinstance(quest.get("info"), dict) else {}
                    tier = clamp_difficulty_tier(info.get("difficulty_tier"))
                    contract = DIFFICULTY_CONTRACTS[tier]
                    approved_cached_quests.append(
                        require_student_problem_contract(
                            quest,
                            expected_solve_count=contract.solves_count,
                            expected_tags=info.get("hash_tag") or [],
                        )
                    )
                except ValueError:
                    continue
            cached_quests = approved_cached_quests
            for quest in cached_quests:
                check_cancelled(cancel_event)
                asyncio.create_task(
                    asyncio.to_thread(
                        problem_runtime_cache.record_delivery,
                        user_id=user_id,
                        quest=quest,
                    )
                )
                yield f"data: {json.dumps(quest, ensure_ascii=False)}\n\n"

            # 캐시가 부족한 경우에만 보충 작업을 큐에 넣는다. 50%/최소 1개 확장 결과는
            # 5% 확률로 신규 생성도 함께 시도해 캐시 품질이 한 조건에 고착되지 않게 한다.
            refill_count = max(0, cache_state["queued"])
            matched = cache_state["match_stage"]
            if cached_quests and 0 < matched < len(hash_tags):
                bucket = int(hashlib.sha256(f"{user_id}:{stream_token}".encode("utf-8")).hexdigest()[:4], 16)
                if bucket % 20 == 0:
                    refill_count = max(refill_count, 1)
            if refill_count:
                _enqueue_cache_refill(
                    user_id=user_id,
                    hash_tags=hash_tags,
                    min_tier=payload.min_difficulty_tier,
                    max_tier=payload.max_difficulty_tier,
                    question_count=refill_count,
                )

            # 캐시 미스 또는 내용 검수 탈락분은 동기 생성으로 채워 요청 문항 수를 보장한다.
            # 검수 통과 캐시는 즉시 제공하고 장기 보충은 worker가 담당한다.
            missing_count = max(0, payload.question_count - len(cached_quests))
            if missing_count:
                history_entries, history_map = _load_recent_seed_history(user_id)
                async with _GEN_SEMAPHORE:
                    quests = await asyncio.to_thread(
                        generate_problem_set,
                        hash_tags=hash_tags,
                        min_difficulty_tier=payload.min_difficulty_tier,
                        max_difficulty_tier=payload.max_difficulty_tier,
                        question_count=missing_count,
                        recent_codebase_seeds={key: list(value) for key, value in history_map.items()},
                        cancel_event=cancel_event,
                    )
                for quest in quests:
                    check_cancelled(cancel_event)
                    if not store_data(quest):
                        detail = get_last_store_error() or "failed to store quest"
                        yield f"data: {json.dumps({'error': detail}, ensure_ascii=False)}\n\n"
                        return
                    cb_id, seed_val = _extract_codebase_seed(quest)
                    _record_seed_history_entry(user_id, history_entries, history_map, cb_id, seed_val)
                    asyncio.create_task(
                        asyncio.to_thread(
                            problem_runtime_cache.record_delivery,
                            user_id=user_id,
                            quest=quest,
                        )
                    )
                    yield f"data: {json.dumps(quest, ensure_ascii=False)}\n\n"
                _save_seed_history(user_id, history_entries)
            yield "data: [DONE]\n\n"

        except ValueError as exc:
            yield f"data: {json.dumps({'error': str(exc)}, ensure_ascii=False)}\n\n"
        except GenerationCancelled:
            yield f"data: {json.dumps({'error': 'generation cancelled'}, ensure_ascii=False)}\n\n"
        except Exception as exc:
            yield f"data: {json.dumps({'error': str(exc)}, ensure_ascii=False)}\n\n"
        finally:
            release_token(stream_token)

    return StreamingResponse(_event_stream(), media_type="text/event-stream")


@app.post("/quests/variants/from-flow-draft", response_model=VariantGenerateResponse)
def generate_variant_from_flow_draft(
    payload: VariantFlowDraftRequest,
    user_id: str = Depends(_get_user_id),
) -> VariantGenerateResponse:
    if not payload.flow_draft:
        return _variant_rejection("missing_field", "flow_draft must not be empty", "Add at least one node")
    graph_error = _validate_typed_variant_flow_graph(payload.flow_draft)
    if graph_error:
        return _variant_rejection(
            "invalid_flow_graph",
            graph_error,
            "Reconnect nodes as one acyclic flow ending in verification",
        )
    try:
        tags = _resolve_variant_tags(payload.tags, payload.base_quest_ref)
    except (TypeError, ValueError) as exc:
        return _variant_rejection("invalid_tags", str(exc), "Use registered generation tags")
    if not tags:
        return _variant_rejection("missing_tags", "tags must not be empty", "Provide tags or base_quest_ref.quest_id")
    prompt_text = (payload.prompt or "") + " " + json.dumps([n.model_dump() for n in payload.flow_draft], ensure_ascii=False)
    rejected = _validate_variant_prompt(prompt_text)
    if rejected is not None:
        return rejected
    try:
        generation_context = _build_variant_generation_context(payload, tags)
        request_signature = _build_variant_request_signature(
            tags=tags,
            solves_count=payload.solves_count,
            strategy_level=payload.strategy_level,
            branch_conditions=payload.branch_conditions,
            generation_context=generation_context,
        )
        quest = _generate_variant_quest(
            tags=tags,
            solves_count=payload.solves_count,
            strategy_level=payload.strategy_level,
            branch_conditions=payload.branch_conditions,
            seed_override=payload.seed_override,
            reference_quest_id=payload.base_quest_ref.quest_id if payload.base_quest_ref else None,
            generation_context=generation_context,
            request_signature=request_signature,
        )
        quest.setdefault("data", {})
        quest["data"]["variant_meta"] = {
            "variant_input_mode": payload.variant_input_mode,
            "base_quest_ref": payload.base_quest_ref.model_dump() if payload.base_quest_ref else None,
            "flow_draft": [n.model_dump() for n in payload.flow_draft],
            "prompt": payload.prompt,
            "note_blocks": payload.note_blocks,
            "advanced_metrics": generation_context.get("metrics", {}),
            "advanced_effect": {
                "signature": request_signature[:16],
                "dominant_metrics": generation_context.get("dominant_metrics", []),
                "examples": generation_context.get("examples", []),
            },
        }
        _insert_variant_tray_item(
            user_id=user_id,
            quest=quest,
            source_variant_mode=payload.variant_input_mode,
            visibility_scope="shared",
            is_mcq_branch=False,
            payload={"tags": tags, "request": payload.model_dump()},
        )
        return VariantGenerateResponse(success=True, quest=quest, rejection=None)
    except Exception as exc:
        return _variant_rejection("generation_failed", str(exc), "Try a different seed or fewer branch constraints")


@app.post("/quests/variants/from-prompt-note", response_model=VariantGenerateResponse)
def generate_variant_from_prompt_note(
    payload: VariantPromptNoteRequest,
    user_id: str = Depends(_get_user_id),
) -> VariantGenerateResponse:
    try:
        tags = _resolve_variant_tags(payload.tags, payload.base_quest_ref)
    except (TypeError, ValueError) as exc:
        return _variant_rejection("invalid_tags", str(exc), "Use registered generation tags")
    if not tags:
        return _variant_rejection("missing_tags", "tags must not be empty", "Provide tags or base_quest_ref.quest_id")
    prompt_text = ((payload.prompt or "").strip() + " " + json.dumps(payload.note_blocks, ensure_ascii=False)).strip()
    if not prompt_text:
        return _variant_rejection("missing_field", "prompt or note_blocks is required", "Provide prompt text or note blocks")
    rejected = _validate_variant_prompt(prompt_text)
    if rejected is not None:
        return rejected
    try:
        generation_context = _build_variant_generation_context(payload, tags)
        request_signature = _build_variant_request_signature(
            tags=tags,
            solves_count=payload.solves_count,
            strategy_level=payload.strategy_level,
            branch_conditions=payload.branch_conditions,
            generation_context=generation_context,
        )
        quest = _generate_variant_quest(
            tags=tags,
            solves_count=payload.solves_count,
            strategy_level=payload.strategy_level,
            branch_conditions=payload.branch_conditions,
            seed_override=payload.seed_override,
            reference_quest_id=payload.base_quest_ref.quest_id if payload.base_quest_ref else None,
            generation_context=generation_context,
            request_signature=request_signature,
        )
        quest.setdefault("data", {})
        quest["data"]["variant_meta"] = {
            "variant_input_mode": payload.variant_input_mode,
            "base_quest_ref": payload.base_quest_ref.model_dump() if payload.base_quest_ref else None,
            "prompt": payload.prompt,
            "note_blocks": payload.note_blocks,
            "advanced_metrics": generation_context.get("metrics", {}),
            "advanced_effect": {
                "signature": request_signature[:16],
                "dominant_metrics": generation_context.get("dominant_metrics", []),
                "examples": generation_context.get("examples", []),
            },
        }
        _insert_variant_tray_item(
            user_id=user_id,
            quest=quest,
            source_variant_mode=payload.variant_input_mode,
            visibility_scope="shared",
            is_mcq_branch=False,
            payload={"tags": tags, "request": payload.model_dump()},
        )
        return VariantGenerateResponse(success=True, quest=quest, rejection=None)
    except Exception as exc:
        return _variant_rejection("generation_failed", str(exc), "Try a simpler prompt or different seed")


@app.post("/quests/variants/convert-mcq", response_model=VariantGenerateResponse)
def convert_variant_to_mcq(
    payload: ConvertMcqRequest,
    user_id: str = Depends(_get_user_id),
) -> VariantGenerateResponse:
    if not payload.base_quest_ref.quest_id:
        return _variant_rejection("missing_field", "base_quest_ref.quest_id is required", "Select a base quest to convert")
    quest = get_quest(payload.base_quest_ref.quest_id)
    if not quest:
        return _variant_rejection("not_found", "base quest not found", "Use an existing quest_id")
    data = (quest.get("data", {}) or {})
    answer_blocks = data.get("quest_answer") or {"blocks": []}
    answer_content = ""
    try:
        blocks = answer_blocks.get("blocks", []) if isinstance(answer_blocks, dict) else []
        answer_content = " ".join(str((b or {}).get("content", "")).strip() for b in blocks if isinstance(b, dict)).strip()
    except Exception:
        answer_content = ""
    choices, answer_index = _build_mcq_choices(answer_content, payload.mcq_policy)
    option_blocks = [{"blocks": [{"type": "text", "content": c}]} for c in choices]
    data["question_type"] = "multiple_choice"
    data["quest_options"] = option_blocks
    codebase_id, seed = _extract_codebase_seed(quest)
    if isinstance(codebase_id, int):
        data["codebase_id"] = codebase_id + 10_000_000
    if isinstance(seed, int):
        data["seed"] = seed
    data["mcq_conversion"] = {
        "source_quest_id": payload.base_quest_ref.quest_id,
        "mcq_policy": payload.mcq_policy.model_dump(),
        "answer_index": answer_index,
        "hints_forbidden": True,
    }
    data["choice_answer_index"] = answer_index
    data["variant_meta"] = {
        "variant_input_mode": "mcq_convert",
        "is_mcq_branch": True,
    }
    update_quest_mcq(
        payload.base_quest_ref.quest_id,
        quest_options=option_blocks,
        choice_answer_index=answer_index,
        meta={
            "mcq_conversion": data["mcq_conversion"],
            "variant_meta": data["variant_meta"],
        },
    )
    quest["data"] = data
    _insert_variant_tray_item(
        user_id=user_id,
        quest=quest,
        source_variant_mode="mcq_convert",
        visibility_scope=payload.visibility_scope,
        is_mcq_branch=True,
        payload={"request": payload.model_dump(), "answer_index": answer_index},
    )
    return VariantGenerateResponse(success=True, quest=quest, rejection=None)


@app.post("/analysis/solve/variant-grade")
def grade_variant_solve(
    payload: VariantGradeRequest,
    user_id: str = Depends(_get_user_id),
) -> Dict[str, Any]:
    quest = get_quest(payload.quest_id)
    if not quest:
        raise HTTPException(status_code=404, detail="Quest not found")
    data = (quest.get("data", {}) or {})
    is_mcq = str(data.get("question_type") or "").lower() in {"multiple_choice", "mcq"}
    mcq_meta = data.get("mcq_conversion", {}) if isinstance(data.get("mcq_conversion"), dict) else {}
    answer_index = data.get("choice_answer_index")
    if answer_index is None:
        answer_index = mcq_meta.get("answer_index")
    selected = payload.selected_index
    raw_correct = bool(selected is not None and answer_index is not None and int(selected) == int(answer_index))
    pass_result = raw_correct
    return {
        "quest_id": payload.quest_id,
        "question_type": data.get("question_type"),
        "raw_correct": raw_correct,
        "pass": pass_result,
        "hints_forbidden": True,
        "reason": "incorrect_choice" if is_mcq and not raw_correct else "normal",
    }


@app.get("/quests/tray", response_model=QuestTrayResponse)
def list_quest_tray(limit: int = 100, user_id: str = Depends(_get_user_id)) -> QuestTrayResponse:
    items = _list_variant_tray_items(user_id=user_id, limit=limit)
    return QuestTrayResponse(items=[QuestTrayItem(**item) for item in items])


@app.post("/quests/tray", response_model=QuestTrayItem)
def create_quest_tray_item(
    payload: QuestTrayCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> QuestTrayItem:
    quest = get_quest(payload.quest_id) if payload.quest_id else None
    item = _insert_variant_tray_item(
        user_id=user_id,
        quest=quest,
        source_variant_mode=payload.source_variant_mode or "",
        visibility_scope=payload.visibility_scope or "shared",
        is_mcq_branch=payload.is_mcq_branch,
        payload=payload.payload,
    )
    return QuestTrayItem(**item)





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
    if not is_sam_configured():
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
        parsed = generate_json(
            model=DEFAULT_TAG_AGENT_MODEL,
            prompt=prompt,
            temperature=0.2,
            max_tokens=1024,
        )
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
    problem_runtime_cache.record_solved(
        user_id=user_id,
        codebase_id=payload.codebase_id,
        seed=str(payload.seed),
    )
    return ProblemHabitItem(
        codebase_id=stored["codebase_id"],
        seed=str(stored["seed"]),
        tags=json.loads(stored["tags"] or "[]"),
        quest_title=stored["quest_title"],
        retry_count=stored["retry_count"],
        updated_at=stored["updated_at"],
    )


@app.get("/problems/trending")
def list_trending_problems(
    minutes: int = 15,
    limit: int = 20,
    user_id: str = Depends(_get_user_id),  # noqa: ARG001 - 통계 조회 권한 확인용 인증
) -> Dict[str, Any]:
    """필요 변수: 집계 시간과 반환 개수. 작동 원리: Redis 분 단위 전달량과 활성 사용자 수를 합산해 급상승 문제를 반환한다."""
    safe_minutes = max(1, min(minutes, 60))
    safe_limit = max(1, min(limit, 100))
    return {
        "minutes": safe_minutes,
        "items": problem_runtime_cache.list_trending(
            minutes=safe_minutes,
            limit=safe_limit,
        ),
    }


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


@app.get("/history/solve", response_model=SolveHistoryListResponse)
def list_solve_history_handler(
    days: int = 30,
    limit: int = 200,
    kind: Optional[str] = None,
    user_id: str = Depends(_get_user_id),
) -> SolveHistoryListResponse:
    init_solve_history_db()
    days = max(1, min(days, 150))
    limit = max(1, min(limit, 5000))
    rows = list_solve_history(
        user_id=user_id, days=days, limit=limit, kind=kind
    )
    return SolveHistoryListResponse(
        items=[
            SolveHistoryItem(
                created_at=row["created_at"],
                kind=row["kind"],
                quest_id=row.get("quest_id"),
                exam_id=row.get("exam_id"),
                codebase_id=row.get("codebase_id"),
                seed=row.get("seed"),
                data=row.get("data"),
            )
            for row in rows
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

def admin_seed_status(
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> AdminSeedStatusResponse:

    return AdminSeedStatusResponse(

        enabled=_SEED_VALIDATOR_ENABLED,

        interval_seconds=_SEED_VALIDATOR_INTERVAL,

        batch_size=_SEED_VALIDATOR_BATCH,

        attempts_per_codebase=_SEED_VALIDATOR_ATTEMPTS,

        max_successes_per_codebase=_SEED_VALIDATOR_MAX_SUCCESSES,

    )





@app.get("/admin/seed/toggle")

def admin_seed_toggle(
    enabled: int = 1,
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

    global _SEED_VALIDATOR_ENABLED

    _SEED_VALIDATOR_ENABLED = bool(int(enabled))

    return {"enabled": _SEED_VALIDATOR_ENABLED}





@app.get("/admin/seed/run")

async def admin_seed_run(
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

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

def admin_codebases(
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Response:

    rows = list_codebase_stats(auto_delete_disabled=True)

    html = _render_admin_codebases(rows)

    return Response(content=html, media_type="text/html")





@app.get("/admin/codebases.json")

def admin_codebases_json(
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

    return {"codebases": list_codebase_stats(auto_delete_disabled=True)}





@app.get("/admin/seed/logs")

def admin_seed_logs(
    codebase_id: Optional[int] = None,
    limit: int = 200,
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

    return {"logs": list_seed_logs(codebase_id=codebase_id, limit=limit)}



@app.get("/admin/agent/logs")

def admin_agent_logs(
    codebase_id: Optional[int] = None,
    limit: int = 200,
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

    return {"logs": list_agent_logs(codebase_id=codebase_id, limit=limit)}







@app.post("/admin/codebases/delete")

def admin_codebases_delete(
    codebase_id: int,
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

    delete_codebase(codebase_id)

    return {"deleted": True, "codebase_id": codebase_id}





@app.post("/admin/codebases/repair")

def admin_codebases_repair(
    codebase_id: int,
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

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

def admin_seed_validate(
    codebase_id: int,
    attempts: int = 10,
    _admin: Dict[str, Any] = Depends(_require_admin_payload),
) -> Dict[str, Any]:

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
        model=profile.get("model", ""),
    )


@app.put("/serverchat/config", response_model=ServerChatConfigResponse)
def serverchat_set_config(
    payload: ServerChatConfigRequest,
    user_id: str = Depends(_get_user_id),
) -> ServerChatConfigResponse:
    character = set_serverchat_character(user_id, payload.character)
    profile = get_serverchat_profile(user_id)
    return ServerChatConfigResponse(
        character=character,
        character_name=profile.get("character_name", ""),
        model="",
    )


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
            ephemeral=payload.ephemeral,
            include_user_data=payload.include_user_data,
        )
    except ChatInputBlocked as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ChatRateLimited as exc:
        raise HTTPException(
            status_code=429,
            detail=str(exc),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc
    except ChatGenerationBlocked as exc:
        raise HTTPException(
            status_code=429,
            detail=str(exc),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc
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
    """풀이 분석 이미지를 서버 파일 시스템에 남기지 않는다.

    필요 변수: 요청에서 전달된 이미지 바이트, 파일 종류, 사용자 식별자.
    작동 원리: OCR/채점 처리에는 메모리의 이미지 바이트만 사용하고, 디버깅 종료 정책에 따라
    학생 풀이·문제·히트맵 원본을 디스크에 기록하지 않는다. 인자는 호출 호환성을 위해 유지한다.
    """
    del image_bytes, prefix, user_id
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
        # 이의신청 확인용 풀이 이력은 storage 정책에 따라 최근 7일만 보관한다.
        kind = "exam" if payload.get("exam_id") else "problem"
        codebase_id, seed_val = _extract_codebase_seed(payload)
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
            # 클라이언트 값으로 서버 보관 기간을 연장할 수 없다.
            delete_after_max=True,
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

    result = apply_rating_update(

        user_id=user_id,

        quest=quest,

        is_correct=bool(payload.is_correct),

        step_outcomes=payload.step_correctness,

        response_time_seconds=payload.answer_time,

        submission_ref=payload.submission_id,

    )

    return RatingResponse(

        rating=result.rating,

        ovr=result.ovr,

        ovr_delta=result.ovr_delta,

        recent_accuracy=result.recent_accuracy,

        lose_streak=result.lose_streak,

    )


@app.post("/rating/submit-batch", response_model=List[RatingResponse])
def submit_rating_batch(
    payload: RatingBatchSubmitRequest,
    user_id: str = Depends(_get_user_id),
) -> List[RatingResponse]:
    """필요 변수: 인증 사용자와 필수 제출 키가 있는 채점 목록. 작동 원리: 서버 문제 원본을 조회한 뒤 한 PostgreSQL 트랜잭션으로 순서대로 반영한다."""
    submissions = []
    for item in payload.items:
        quest = get_quest(item.quest_id)
        if not quest:
            raise HTTPException(status_code=404, detail=f"Quest not found: {item.quest_id}")
        submissions.append({
            "quest": quest,
            "is_correct": item.is_correct,
            "step_outcomes": item.step_correctness,
            "response_time_seconds": item.answer_time,
            "submission_ref": item.submission_id,
        })
    return [
        RatingResponse(**result.__dict__)
        for result in apply_rating_batch(user_id=user_id, submissions=submissions)
    ]





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
    """필요 변수: 요청 사용자 ID와 조회 대상 사용자 ID.

    작동 원리: 본인 또는 양방향 친구 관계인 사용자만 대상의 요약 레이팅을
    조회할 수 있게 하여, 친구 화면의 OVR 표시를 지원하면서 비친구의 레이팅
    정보 노출은 차단한다.
    """
    if target_user_id != user_id and not are_friends(user_id, target_user_id):
        raise HTTPException(status_code=403, detail="Forbidden")

    result = fetch_user_rating(target_user_id)

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
    async with _EXAM_ITEM_SEMAPHORE:
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
                None,  # 동일 승인 코드베이스의 다른 검증 시드는 재사용해 30문항 cold generation을 줄인다.
                avoid_seeds_by_codebase=snapshot_avoid,
                student_ready_only=True,
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
    peer_user = get_social_user_by_username(peer)
    if not peer_user:
        raise HTTPException(status_code=404, detail="Peer not found")
    me = get_social_user_by_id(user_id)
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
    peer = get_social_user_by_username(payload.peer)
    if not peer:
        raise HTTPException(status_code=404, detail="Peer not found")
    me = get_social_user_by_id(user_id)
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
    peer_user = get_social_user_by_username(peer)
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
    me = get_social_user_by_id(user_id)
    me_username = me.get("username") if me else "me"
    result: List[DirectMessageResponse] = []
    for msg in messages:
        peer_user = get_social_user_by_id(msg.get("peer_id") or "") or {}
        peer_username = peer_user.get("username") or ""
        result.append(
            _make_dm_response(
                msg=msg,
                me_username=me_username,
                peer_username=peer_username,
            )
        )
    return DirectMessageListResponse(messages=result)
