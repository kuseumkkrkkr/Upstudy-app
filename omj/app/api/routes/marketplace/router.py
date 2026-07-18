"""학생 마켓플레이스 공개 목록 API."""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field

from app.api.deps import get_current_user
from app.schemas.common import ApiResponse
from domain.marketplace import repository
from domain.marketplace import purchase_repository


router = APIRouter(prefix="/marketplace", tags=["marketplace"])


class MarketplaceProgressRequest(BaseModel):
    progress_index: int = Field(default=0, ge=0)
    completed: bool = False


@router.get("/listings", response_model=ApiResponse)
async def list_marketplace_listings(
    request: Request,
    kind: Optional[str] = Query(default=None, pattern="^(exam|problem_set|course)$"),
    query: Optional[str] = Query(default=None, max_length=80),
    grade_band: Optional[str] = Query(default=None, max_length=40),
    price: Optional[str] = Query(default=None, pattern="^(free|paid)$"),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=30),
    _user=Depends(get_current_user),
) -> ApiResponse:
    """필요 변수는 코너·검색어·학년·가격·페이지 위치다. 작동 원리는 DB에서 조건과 범위를 먼저 적용해 필요한 목록 페이지만 반환하는 것이다."""
    page = repository.list_published_page(
        kind=kind,
        query=query,
        grade_band=grade_band,
        price=price,
        offset=offset,
        limit=limit,
    )
    return ApiResponse(data=page)


@router.get("/my-items", response_model=ApiResponse)
async def list_my_marketplace_items(
    request: Request,
    _user=Depends(get_current_user),
) -> ApiResponse:
    """필요 변수는 로그인 사용자다. 작동 원리는 보유 원장과 공개 상품 정보를 합쳐 학습 모달용 목록을 반환하는 것이다."""
    purchases = purchase_repository.list_owned(request.state.user_id)
    listings = {
        item["id"]: item
        for item in repository.list_published_by_ids(
            [purchase["listing_id"] for purchase in purchases]
        )
    }
    items = []
    for purchase in purchases:
        listing = listings.get(purchase["listing_id"])
        if listing is None:
            continue
        items.append({**listing, **purchase, "owned": True})
    return ApiResponse(data={"items": items, "total": len(items)})


@router.post("/listings/{listing_id}/purchase", response_model=ApiResponse)
async def purchase_marketplace_listing(
    listing_id: str,
    request: Request,
    _user=Depends(get_current_user),
) -> ApiResponse:
    """필요 변수는 상품 ID와 로그인 사용자다. 공개 상품을 단건 확인한 뒤 코인 차감과 보유 등록을 멱등 처리한다."""
    listing = repository.get_published(listing_id)
    if listing is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="listing_not_found")
    try:
        purchase = purchase_repository.purchase(
            user_id=request.state.user_id,
            listing_id=listing_id,
            price_points=int(listing.get("price_points") or 0),
        )
    except ValueError as error:
        if str(error) == "insufficient_coins":
            raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="insufficient_coins") from error
        raise
    return ApiResponse(data={**listing, **purchase, "owned": True})


@router.post("/my-items/{listing_id}/progress", response_model=ApiResponse)
async def update_my_marketplace_progress(
    listing_id: str,
    body: MarketplaceProgressRequest,
    request: Request,
    _user=Depends(get_current_user),
) -> ApiResponse:
    """필요 변수는 보유 상품의 진행 위치와 완료 여부다. 학습 중단 위치를 저장하고 완료 자료를 마지막으로 보낸다."""
    try:
        progress = purchase_repository.update_progress(
            user_id=request.state.user_id,
            listing_id=listing_id,
            progress_index=body.progress_index,
            completed=body.completed,
        )
    except KeyError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="purchase_not_found") from error
    return ApiResponse(data=progress)
