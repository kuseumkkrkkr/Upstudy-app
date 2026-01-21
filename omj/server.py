import asyncio
import os
import uuid
from typing import Any, Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from auth import create_token, decode_token
from exam_service import plan_exam_items
from generater.make import make
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

try:
    from pdf_builder import build_exam_pdf
except ImportError:
    build_exam_pdf = None


app = FastAPI()
security = HTTPBearer(auto_error=False)
_GEN_SEMAPHORE = asyncio.Semaphore(2)

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
    quest_title: Optional[str] = None
    error: Optional[str] = None


class ExamStatusResponse(BaseModel):
    exam_id: str
    status: str
    items: List[ExamItemResponse]


class TokenResponse(BaseModel):
    token: str
    user_id: str


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


@app.post("/auth/anonymous", response_model=TokenResponse)
def issue_anonymous_token() -> TokenResponse:
    user_id = str(uuid.uuid4())
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
    failed_items: List[Dict[str, Any]] = []

    for item in items:
        ok = await _generate_exam_item(
            exam_id,
            item,
            used_quest_ids,
            start_status="generating",
            failure_status="retrying",
        )
        if not ok:
            failed_items.append(item)

    if failed_items:
        update_exam_status(exam_id, "retrying")
        await asyncio.sleep(2)
        retry_failures: List[Dict[str, Any]] = []
        for item in failed_items:
            ok = await _generate_exam_item(
                exam_id,
                item,
                used_quest_ids,
                start_status="retrying",
                failure_status="failed",
            )
            if not ok:
                retry_failures.append(item)
        failed_items = retry_failures

    final_status = "done"
    if failed_items:
        final_status = "failed"
    update_exam_status(exam_id, final_status)


async def _generate_exam_item(
    exam_id: str,
    item: Dict[str, Any],
    used_quest_ids: set[str],
    *,
    start_status: str,
    failure_status: str,
) -> bool:
    item_index = item["item_index"]
    update_exam_item(exam_id, item_index, status=start_status, error="")
    try:
        quest_id: Optional[str] = None
        if get_total_quest_count() >= 20:
            quest_id = find_reusable_quest(
                target_tags=item["hash_tags"],
                min_flow=item["solves_count"],
                max_flow=item["solves_count"] + max(item["branch_conditions"], 1) + 2,
                used_quest_ids=used_quest_ids,
            )

        if quest_id:
            used_quest_ids.add(quest_id)
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

        async with _GEN_SEMAPHORE:
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
