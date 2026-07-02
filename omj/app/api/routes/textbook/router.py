"""FastAPI router for textbook domain.

Endpoints:
- POST /textbook/blocks       — create block
- GET  /textbook/blocks/{id}  — get block
- GET  /textbook/blocks       — list blocks by course_id
- POST /textbook/graph        — create graph
- GET  /textbook/graph/{course_id} — get graph
- POST /textbook/build        — enqueue build job
"""
from typing import Optional

from fastapi import APIRouter, Depends, Query, Request

from app.api.routes.auth.middleware import require_role
from app.schemas.common import ApiResponse
from domain.textbook.models import (
    TextbookBlock,
    TextbookBuildRequest,
    TextbookBuildResult,
    TextbookGraph,
)
from domain.textbook import repository as repo
from domain.textbook.build_service import TextbookBuilderService
from services.ai.providers.base import get_default_provider

router = APIRouter(prefix="/textbook", tags=["textbook"])


def _wrap(data: Optional[object], message: Optional[str] = None) -> ApiResponse:
    return ApiResponse(data=data, message=message)


@router.post("/blocks", response_model=ApiResponse)
async def create_block(
    request: Request,
    block: TextbookBlock,
    course_id: int = Query(...),
    _user=Depends(require_role("teacher", "admin")),
):
    """Create a new textbook block under a course."""
    block.course_id = course_id
    block_id = repo.create_block(block)
    block.id = block_id
    return _wrap(block, "Block created")


@router.get("/blocks/{block_id}", response_model=ApiResponse)
async def get_block(
    request: Request,
    block_id: int,
    _user=Depends(require_role("teacher", "admin")),
):
    """Retrieve a single textbook block by id."""
    block = repo.get_block(block_id)
    if block is None:
        return _wrap(None, "Block not found")
    return _wrap(block)


@router.get("/blocks", response_model=ApiResponse)
async def list_blocks(
    request: Request,
    course_id: int = Query(...),
    _user=Depends(require_role("teacher", "admin")),
):
    """List all blocks for a given course."""
    blocks = repo.list_blocks(course_id)
    return _wrap(blocks)


@router.post("/graph", response_model=ApiResponse)
async def create_graph(
    request: Request,
    graph: TextbookGraph,
    _user=Depends(require_role("teacher", "admin")),
):
    """Create a new textbook graph for a course."""
    graph_id = repo.create_graph(graph)
    graph.id = graph_id
    return _wrap(graph, "Graph created")


@router.get("/graph/{course_id}", response_model=ApiResponse)
async def get_graph(
    request: Request,
    course_id: int,
    _user=Depends(require_role("teacher", "admin")),
):
    """Retrieve the textbook graph for a course."""
    graph = repo.get_graph(course_id)
    if graph is None:
        return _wrap(None, "Graph not found")
    return _wrap(graph)


@router.post("/build", response_model=ApiResponse)
async def build_textbook(
    request: Request,
    build_req: TextbookBuildRequest,
    _user=Depends(require_role("teacher", "admin")),
):
    """Enqueue a textbook build job."""
    provider = get_default_provider()
    service = TextbookBuilderService(ai_provider=provider)
    result = service.start_build(build_req)
    return _wrap(result, "Build job enqueued")
