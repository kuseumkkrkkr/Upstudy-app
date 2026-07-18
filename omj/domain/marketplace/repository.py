"""시험지·문제세트·코스 마켓 목록 저장소."""
from __future__ import annotations

import json
import os
import re
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterable, Optional

from infra.db import postgres_compat
from infra.db.connection import connect_sqlite


# 공개 목록은 페이지 단위로 DB에서 읽는다. 대량 목록을 프로세스 메모리와
# 응답 대역폭에 동시에 쌓지 않도록 캐시 원장을 만들지 않는다.
# 이전 운영 스크립트의 테스트 격리를 위한 호환 상태이며 목록 조회에는 사용하지 않는다.
_cached_rows: list[dict[str, Any]] = []
_cache_loaded_at = 0.0


def _sqlite_path() -> Path:
    """필요 변수는 선택적 QUEST_DB_PATH다. 작동 원리는 마켓 로컬 저장소를 문제 DB와 같은 UTF-8 SQLite 파일로 고정하는 것이다."""
    configured = os.getenv("QUEST_DB_PATH", "").strip()
    if configured:
        return Path(configured).resolve()
    return Path(__file__).resolve().parents[2] / "quests.db"


def _backend() -> str:
    """필요 변수는 MARKETPLACE_BACKEND다. 작동 원리는 운영 명시값을 우선하고 미설정 로컬 환경은 시드가 저장된 SQLite를 사용하는 것이다."""
    configured = os.getenv("MARKETPLACE_BACKEND", "").strip().lower()
    if configured in {"sqlite", "postgres"}:
        return configured
    return "sqlite"


def _connect() -> Any:
    """필요 변수는 선택된 저장 백엔드다. 작동 원리는 PostgreSQL에서는 공유 풀, 로컬에서는 WAL SQLite 연결을 반환하는 것이다."""
    if _backend() == "postgres":
        return postgres_compat.connect()
    return connect_sqlite(_sqlite_path())


@contextmanager
def _connection_scope() -> Any:
    """필요 변수는 선택된 DB 연결이다. 작동 원리는 SQLite와 PostgreSQL 연결을 예외 여부와 무관하게 즉시 반환·종료하는 것이다."""
    connection = _connect()
    try:
        yield connection
    finally:
        connection.close()


def ensure_schema() -> None:
    """필요 변수는 마켓 DB 연결이다. 작동 원리는 멱등 DDL과 공개 목록용 복합 인덱스를 한 번 적용하는 것이다."""
    with _connection_scope() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS marketplace_listing (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                subject TEXT NOT NULL DEFAULT '수학',
                grade_band TEXT NOT NULL DEFAULT '',
                difficulty TEXT NOT NULL DEFAULT '',
                item_count INTEGER NOT NULL DEFAULT 0,
                estimated_minutes INTEGER NOT NULL DEFAULT 0,
                price_points INTEGER NOT NULL DEFAULT 0,
                asset_id TEXT NOT NULL DEFAULT '',
                tags_json TEXT NOT NULL DEFAULT '[]',
                problem_ids_json TEXT NOT NULL DEFAULT '[]',
                payload_json TEXT NOT NULL DEFAULT '{}',
                status TEXT NOT NULL DEFAULT 'draft',
                featured_rank INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_marketplace_listing_public
            ON marketplace_listing (status, kind, featured_rank, updated_at)
            """
        )
        connection.commit()


def _decode_json(value: Any, fallback: Any) -> Any:
    """필요 변수는 DB JSON 문자열과 기본값이다. 작동 원리는 손상된 한 행을 빈 값으로 격리해 전체 마켓 응답을 유지하는 것이다."""
    if isinstance(value, (dict, list)):
        return value
    try:
        return json.loads(str(value or ""))
    except (TypeError, ValueError, json.JSONDecodeError):
        return fallback


def _is_valid_grade_band(value: str) -> bool:
    """필요 변수는 요청으로 전달된 학년 문자열이다. 작동 원리는 초·중·고 학년 형식만 SQL 조건에 사용하고 admin 같은 역할값은 무시하는 것이다."""
    return re.fullmatch(r"(초|중|고)\s?[1-3](?:-[1-3])?", value) is not None


def _normalize_row(row: Any) -> dict[str, Any]:
    """필요 변수는 SQLite/PostgreSQL 행이다. 작동 원리는 JSON 필드를 앱에서 바로 쓰는 목록·객체로 복원하는 것이다."""
    item = dict(row)
    item["tags"] = _decode_json(item.pop("tags_json", "[]"), [])
    item["problem_ids"] = _decode_json(item.pop("problem_ids_json", "[]"), [])
    item["payload"] = _decode_json(item.pop("payload_json", "{}"), {})
    return item


def list_published_page(
    *,
    kind: Optional[str] = None,
    query: Optional[str] = None,
    grade_band: Optional[str] = None,
    price: Optional[str] = None,
    offset: int = 0,
    limit: int = 20,
) -> dict[str, Any]:
    """필요 변수는 필터와 페이지 범위다. 작동 원리는 공개 인덱스를 기준으로 SQL에서 필터·정렬·LIMIT을 적용해 한 페이지와 다음 위치만 반환하는 것이다."""
    normalized_kind = str(kind or "").strip().lower()
    normalized_query = str(query or "").strip().lower()
    normalized_grade = str(grade_band or "").strip().lower()
    normalized_price = str(price or "").strip().lower()
    safe_limit = max(1, min(int(limit), 30))
    safe_offset = max(0, int(offset))
    clauses = ["status = 'published'"]
    params: list[Any] = []
    if normalized_kind:
        clauses.append("kind = ?")
        params.append(normalized_kind)
    if normalized_grade and _is_valid_grade_band(normalized_grade):
        clauses.append("LOWER(grade_band) LIKE ?")
        params.append(f"%{normalized_grade}%")
    if normalized_price == "free":
        clauses.append("price_points = 0")
    elif normalized_price == "paid":
        clauses.append("price_points > 0")
    if normalized_query:
        clauses.append("(LOWER(title) LIKE ? OR LOWER(description) LIKE ? OR LOWER(tags_json) LIKE ?)")
        search = f"%{normalized_query}%"
        params.extend((search, search, search))
    where = " WHERE " + " AND ".join(clauses)
    ensure_schema()
    with _connection_scope() as connection:
        if _backend() == "sqlite":
            connection.row_factory = __import__("sqlite3").Row
        total = int(connection.execute(
            f"SELECT COUNT(*) FROM marketplace_listing{where}", params
        ).fetchone()[0])
        rows = connection.execute(
            """
            SELECT id, kind, title, description, subject, grade_band,
                   difficulty, item_count, estimated_minutes, price_points,
                   asset_id, tags_json, problem_ids_json, payload_json,
                   status, featured_rank, created_at, updated_at
            FROM marketplace_listing
            """ + where + " ORDER BY featured_rank DESC, updated_at DESC, id ASC LIMIT ? OFFSET ?",
            [*params, safe_limit, safe_offset],
        ).fetchall()
    items = [_normalize_row(row) for row in rows]
    next_offset = safe_offset + len(items)
    return {
        "items": items,
        "total": total,
        "next_offset": next_offset if next_offset < total else None,
    }


def list_published(
    *,
    kind: Optional[str] = None,
    query: Optional[str] = None,
    limit: int = 60,
) -> list[dict[str, Any]]:
    """필요 변수는 기존 호출의 코너·검색어·상한이다. 작동 원리는 호환용 호출도 페이지 저장소를 거쳐 절대 전체 공개 원장을 로드하지 않게 하는 것이다."""
    return list_published_page(kind=kind, query=query, limit=limit)["items"]


def list_published_by_ids(ids: Iterable[str]) -> list[dict[str, Any]]:
    """필요 변수는 보유 상품 ID 목록이다. 작동 원리는 필요한 상품만 한 번의 IN 조회로 복원해 보유 모달의 전체 스캔을 막는 것이다."""
    safe_ids = [str(item).strip() for item in ids if str(item).strip()]
    if not safe_ids:
        return []
    ensure_schema()
    placeholders = ",".join("?" for _ in safe_ids)
    with _connection_scope() as connection:
        if _backend() == "sqlite":
            connection.row_factory = __import__("sqlite3").Row
        rows = connection.execute(
            """SELECT id, kind, title, description, subject, grade_band,
                      difficulty, item_count, estimated_minutes, price_points,
                      asset_id, tags_json, problem_ids_json, payload_json,
                      status, featured_rank, created_at, updated_at
               FROM marketplace_listing
               WHERE status = 'published' AND id IN ("""
            + placeholders
            + ")",
            safe_ids,
        ).fetchall()
    return [_normalize_row(row) for row in rows]


def get_published(listing_id: str) -> Optional[dict[str, Any]]:
    """필요 변수는 마켓 상품 ID다. 구매 직전에 공개 상품과 현재 가격을 단건 확인한다."""
    items = list_published_by_ids([listing_id])
    return items[0] if items else None


def list_all_published_for_audit() -> list[dict[str, Any]]:
    """필요 변수는 공개 마켓 원장이다. 작동 원리는 사용자 요청의 100개 상한과 분리해 생산 스크립트가 전체 UPSERT 결과를 한 번에 감사하도록 모든 공개 행을 읽는 것이다."""
    ensure_schema()
    with _connection_scope() as connection:
        if _backend() == "sqlite":
            connection.row_factory = __import__("sqlite3").Row
        rows = connection.execute("SELECT * FROM marketplace_listing WHERE status = 'published'").fetchall()
    return [_normalize_row(row) for row in rows]


def upsert_listings(listings: Iterable[dict[str, Any]]) -> int:
    """필요 변수는 결정적 ID를 가진 마켓 목록이다. 작동 원리는 한 트랜잭션에서 UPSERT해 반복 생산 시 중복 없이 내용만 갱신하는 것이다."""
    ensure_schema()
    now = int(time.time())
    rows = list(listings)
    with _connection_scope() as connection:
        for item in rows:
            connection.execute(
                """
                INSERT INTO marketplace_listing (
                    id, kind, title, description, subject, grade_band,
                    difficulty, item_count, estimated_minutes, price_points,
                    asset_id, tags_json, problem_ids_json, payload_json,
                    status, featured_rank, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    kind=excluded.kind, title=excluded.title,
                    description=excluded.description, subject=excluded.subject,
                    grade_band=excluded.grade_band, difficulty=excluded.difficulty,
                    item_count=excluded.item_count,
                    estimated_minutes=excluded.estimated_minutes,
                    price_points=excluded.price_points, asset_id=excluded.asset_id,
                    tags_json=excluded.tags_json,
                    problem_ids_json=excluded.problem_ids_json,
                    payload_json=excluded.payload_json, status=excluded.status,
                    featured_rank=excluded.featured_rank,
                    updated_at=excluded.updated_at
                """,
                (
                    item["id"],
                    item["kind"],
                    item["title"],
                    item.get("description", ""),
                    item.get("subject", "수학"),
                    item.get("grade_band", ""),
                    item.get("difficulty", ""),
                    int(item.get("item_count", 0)),
                    int(item.get("estimated_minutes", 0)),
                    int(item.get("price_points", 0)),
                    item.get("asset_id", ""),
                    json.dumps(item.get("tags", []), ensure_ascii=False),
                    json.dumps(item.get("problem_ids", []), ensure_ascii=False),
                    json.dumps(item.get("payload", {}), ensure_ascii=False),
                    item.get("status", "draft"),
                    int(item.get("featured_rank", 0)),
                    int(item.get("created_at", now)),
                    now,
                ),
            )
        connection.commit()
    return len(rows)
