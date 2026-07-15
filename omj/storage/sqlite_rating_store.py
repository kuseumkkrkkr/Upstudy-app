"""PostgreSQL 레이팅 저장소와 호환되는 개발용 SQLite fallback."""
from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, timezone
import json
import sqlite3
from threading import Lock
from typing import Any, Dict, Iterable, Iterator, List, Optional

from infra.db.connection import connect_sqlite
from rating_config import CONFIG
from storage.storage import DB_PATH


_SCHEMA_LOCK = Lock()
_SCHEMA_READY = False


class SQLiteRatingCursor:
    """레이팅 서비스가 SQLite 트랜잭션을 식별할 수 있도록 연결을 감싼다."""

    _is_sqlite_rating_cursor = True

    def __init__(self, connection: sqlite3.Connection) -> None:
        """필요 변수: 열린 SQLite 연결. 작동 원리: 저장소 메서드가 같은 트랜잭션 연결을 공유하게 한다."""
        self.connection = connection


def _now_iso() -> str:
    """필요 변수: 없음. 작동 원리: 모든 fallback 기록 시각을 UTC ISO 문자열로 만든다."""
    return datetime.now(timezone.utc).isoformat()


def _json_loads(value: Any, default: Any) -> Any:
    """필요 변수: JSON 문자열·기본값. 작동 원리: 기존 SQLite 행의 손상된 JSON도 안전한 기본값으로 읽는다."""
    if value is None:
        return default
    if isinstance(value, (dict, list)):
        return value
    try:
        return json.loads(value)
    except (TypeError, ValueError, json.JSONDecodeError):
        return default


def _json_dumps(value: Any) -> str:
    """필요 변수: Python 값. 작동 원리: 한글을 보존한 UTF-8 JSON 문자열로 직렬화한다."""
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def _ensure_column(connection: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    """필요 변수: SQLite 테이블·컬럼 정의. 작동 원리: 기존 레거시 DB에도 fallback 필수 컬럼만 증분 추가한다."""
    columns = {row[1] for row in connection.execute(f"PRAGMA table_info({table})")}
    if column not in columns:
        connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def _ensure_schema(connection: sqlite3.Connection) -> None:
    """필요 변수: SQLite 연결. 작동 원리: PostgreSQL 003 migration과 같은 레이팅 계약을 SQLite에 준비한다."""
    global _SCHEMA_READY
    if _SCHEMA_READY:
        return
    with _SCHEMA_LOCK:
        if _SCHEMA_READY:
            return
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS user_rating (
                user_id TEXT PRIMARY KEY,
                rating REAL NOT NULL DEFAULT 1200,
                ovr REAL NOT NULL DEFAULT 1200,
                ovr_prev REAL NOT NULL DEFAULT 1200,
                lose_streak INTEGER NOT NULL DEFAULT 0,
                last_attempt_at TEXT,
                recent_results TEXT NOT NULL DEFAULT '[]',
                recent_index INTEGER NOT NULL DEFAULT 0,
                recent_count INTEGER NOT NULL DEFAULT 0,
                recent_sum INTEGER NOT NULL DEFAULT 0,
                tag_rating_sum REAL NOT NULL DEFAULT 0,
                tag_rating_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT '',
                updated_at TEXT NOT NULL DEFAULT ''
            )
            """
        )
        for column, definition in (
            ("ovr", "REAL NOT NULL DEFAULT 1200"),
            ("ovr_prev", "REAL NOT NULL DEFAULT 1200"),
            ("lose_streak", "INTEGER NOT NULL DEFAULT 0"),
            ("last_attempt_at", "TEXT"),
            ("recent_results", "TEXT NOT NULL DEFAULT '[]'"),
            ("recent_index", "INTEGER NOT NULL DEFAULT 0"),
            ("recent_count", "INTEGER NOT NULL DEFAULT 0"),
            ("recent_sum", "INTEGER NOT NULL DEFAULT 0"),
            ("tag_rating_sum", "REAL NOT NULL DEFAULT 0"),
            ("tag_rating_count", "INTEGER NOT NULL DEFAULT 0"),
            ("created_at", "TEXT NOT NULL DEFAULT ''"),
            ("updated_at", "TEXT NOT NULL DEFAULT ''"),
        ):
            _ensure_column(connection, "user_rating", column, definition)
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS user_tag_rating (
                user_id TEXT NOT NULL,
                tag TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                rating REAL NOT NULL DEFAULT 1200,
                rating_prev REAL NOT NULL DEFAULT 1200,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (user_id, tag)
            )
            """
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_sqlite_user_tag_rating_rank
            ON user_tag_rating (user_id, rating DESC)
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS rating_submission (
                user_id TEXT NOT NULL,
                submission_id TEXT NOT NULL,
                quest_id TEXT,
                response TEXT,
                created_at TEXT NOT NULL,
                PRIMARY KEY (user_id, submission_id)
            )
            """
        )
        _ensure_column(connection, "rating_submission", "quest_id", "TEXT")
        _ensure_column(connection, "rating_submission", "response", "TEXT")
        connection.commit()
        _SCHEMA_READY = True


class SQLiteRatingStore:
    """로컬 개발 환경에서 레이팅 기능을 유지하는 SQLite 저장소."""

    def ensure_ready(self) -> None:
        """필요 변수: QUEST_DB_PATH. 작동 원리: startup 전에 fallback 테이블을 한 번 준비한다."""
        connection = connect_sqlite(DB_PATH, row_factory=sqlite3.Row)
        try:
            _ensure_schema(connection)
        finally:
            connection.close()

    @contextmanager
    def transaction(self) -> Iterator[SQLiteRatingCursor]:
        """필요 변수: SQLite 연결·WAL 설정. 작동 원리: 한 요청의 레이팅 변경을 원자적으로 commit 또는 rollback한다."""
        connection = connect_sqlite(DB_PATH, row_factory=sqlite3.Row)
        _ensure_schema(connection)
        try:
            connection.execute("BEGIN")
            yield SQLiteRatingCursor(connection)
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def get_or_create_user(self, cur: SQLiteRatingCursor, user_id: str, *, for_update: bool) -> Dict[str, Any]:
        """필요 변수: 사용자 ID·SQLite 트랜잭션. 작동 원리: 기본 레이팅 행을 원자적으로 만들고 최신 상태를 반환한다."""
        del for_update
        connection = cur.connection
        now = _now_iso()
        connection.execute(
            """
            INSERT OR IGNORE INTO user_rating
                (user_id, rating, ovr, ovr_prev, lose_streak, last_attempt_at,
                 recent_results, recent_index, recent_count, recent_sum,
                 tag_rating_sum, tag_rating_count, created_at, updated_at)
            VALUES (?, ?, ?, ?, 0, NULL, '[]', 0, 0, 0, 0, 0, ?, ?)
            """,
            (user_id, CONFIG.DEFAULT_RATING, CONFIG.DEFAULT_RATING, CONFIG.DEFAULT_RATING, now, now),
        )
        row = connection.execute("SELECT * FROM user_rating WHERE user_id = ?", (user_id,)).fetchone()
        if row is None:
            raise RuntimeError("failed to load SQLite user rating")
        result = dict(row)
        result["recent_results"] = _json_loads(result.get("recent_results"), [])
        return result

    def claim_submission(self, cur: SQLiteRatingCursor, *, user_id: str, submission_id: str, quest_id: str) -> Optional[Dict[str, Any]]:
        """필요 변수: 사용자·제출·문제 ID. 작동 원리: 복합키로 최초 제출만 선점하고 재전송에는 저장된 응답을 반환한다."""
        connection = cur.connection
        result = connection.execute(
            """
            INSERT OR IGNORE INTO rating_submission (user_id, submission_id, quest_id, response, created_at)
            VALUES (?, ?, ?, NULL, ?)
            """,
            (user_id, submission_id, quest_id, _now_iso()),
        )
        if result.rowcount == 1:
            return None
        row = connection.execute(
            "SELECT quest_id, response FROM rating_submission WHERE user_id = ? AND submission_id = ?",
            (user_id, submission_id),
        ).fetchone()
        if row is None or (row[0] and row[0] != quest_id):
            raise ValueError("submission_id is already bound to another quest")
        if not row[1]:
            raise RuntimeError("rating submission is incomplete")
        return dict(_json_loads(row[1], {}))

    def save_submission_response(self, cur: SQLiteRatingCursor, *, user_id: str, submission_id: str, response: Dict[str, Any]) -> None:
        """필요 변수: 선점된 제출 키·응답. 작동 원리: 같은 트랜잭션 안에서 재전송용 결과 스냅샷을 저장한다."""
        cur.connection.execute(
            "UPDATE rating_submission SET response = ? WHERE user_id = ? AND submission_id = ?",
            (_json_dumps(response), user_id, submission_id),
        )

    def get_tag_stats(self, cur: SQLiteRatingCursor, user_id: str, tags: Iterable[str]) -> Dict[str, Dict[str, Any]]:
        """필요 변수: 사용자 ID·태그 목록. 작동 원리: 현재 계산에 필요한 태그 행만 조회한다."""
        tag_list = list(tags)
        if not tag_list:
            return {}
        placeholders = ",".join("?" for _ in tag_list)
        rows = cur.connection.execute(
            f"SELECT user_id, tag, attempts, rating, rating_prev, updated_at FROM user_tag_rating WHERE user_id = ? AND tag IN ({placeholders})",
            (user_id, *tag_list),
        ).fetchall()
        return {str(row["tag"]): dict(row) for row in rows}

    def upsert_tag_stats(self, cur: SQLiteRatingCursor, rows: List[Dict[str, Any]]) -> None:
        """필요 변수: 태그별 계산 결과. 작동 원리: executemany와 UPSERT로 태그 상태를 한 번에 갱신한다."""
        if not rows:
            return
        cur.connection.executemany(
            """
            INSERT INTO user_tag_rating (user_id, tag, attempts, rating, rating_prev, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, tag) DO UPDATE SET
                attempts = excluded.attempts, rating = excluded.rating,
                rating_prev = excluded.rating_prev, updated_at = excluded.updated_at
            """,
            [
                (row["user_id"], row["tag"], row["attempts"], row["rating"], row["rating_prev"], str(row["updated_at"]))
                for row in rows
            ],
        )

    def compute_ovr(self, cur: SQLiteRatingCursor, user_id: str, fallback: float) -> float:
        """필요 변수: 태그별 레이팅·시도 수. 작동 원리: 태그당 최대 C_MAX까지 가중해 전체 레이팅을 계산한다."""
        cap = int(CONFIG.C_MAX)
        row = cur.connection.execute(
            """
            SELECT COALESCE(
                SUM(rating * MIN(attempts, ?)) / NULLIF(SUM(MIN(attempts, ?)), 0), ?
            ) AS ovr
            FROM user_tag_rating WHERE user_id = ?
            """,
            (cap, cap, fallback, user_id),
        ).fetchone()
        return float(row["ovr"] if row and row["ovr"] is not None else fallback)

    def update_user(self, cur: SQLiteRatingCursor, values: Dict[str, Any]) -> None:
        """필요 변수: 계산 완료 레이팅 상태. 작동 원리: 사용자 원점수·OVR·최근 50문항 통계를 단일 UPDATE로 기록한다."""
        cur.connection.execute(
            """
            UPDATE user_rating SET
                rating = ?, ovr = ?, ovr_prev = ?, lose_streak = ?, last_attempt_at = ?,
                recent_results = ?, recent_index = ?, recent_count = ?, recent_sum = ?, updated_at = ?
            WHERE user_id = ?
            """,
            (
                values["rating"], values["ovr"], values["ovr_prev"], values["lose_streak"],
                str(values["last_attempt_at"]) if values.get("last_attempt_at") else None,
                _json_dumps(values["recent_results"]), values["recent_index"], values["recent_count"],
                values["recent_sum"], str(values["updated_at"]), values["user_id"],
            ),
        )

    def fetch_user(self, user_id: str) -> Dict[str, Any]:
        """필요 변수: 사용자 ID. 작동 원리: 별도 읽기 트랜잭션에서 기본 사용자와 최신 레이팅을 반환한다."""
        with self.transaction() as cur:
            return self.get_or_create_user(cur, user_id, for_update=False)

    def list_tag_stats(self, user_id: str) -> List[Dict[str, Any]]:
        """필요 변수: 사용자 ID. 작동 원리: 사용자 태그 레이팅을 점수 내림차순으로 조회한다."""
        with self.transaction() as cur:
            rows = cur.connection.execute(
                "SELECT tag, attempts, rating, rating_prev, updated_at FROM user_tag_rating WHERE user_id = ? ORDER BY rating DESC, tag ASC",
                (user_id,),
            ).fetchall()
            return [dict(row) for row in rows]


sqlite_rating_store = SQLiteRatingStore()
