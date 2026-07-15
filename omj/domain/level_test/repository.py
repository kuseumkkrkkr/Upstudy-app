"""SQLite CRUD repository for the Level Test domain.

Uses raw sqlite3 against the shared ``quests.db`` file.
"""
from __future__ import annotations

import json
import uuid
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from domain.level_test import static_store
from domain.level_test.models import LevelTestResult, PowerTest, SpeedTest
from storage.storage import DB_PATH


# ---------------------------------------------------------------------------
# Schema helpers
# ---------------------------------------------------------------------------


def _ensure_level_test_tables() -> None:
    """Create level-test tables if missing."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS speed_test (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            topic TEXT NOT NULL,
            difficulty TEXT NOT NULL DEFAULT 'medium',
            time_limit_seconds INTEGER NOT NULL DEFAULT 0,
            problems_json TEXT,
            submitted_answers_json TEXT,
            score REAL,
            status TEXT NOT NULL DEFAULT 'pending',
            started_at TEXT,
            submitted_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS power_test (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            topic TEXT NOT NULL,
            difficulty TEXT NOT NULL DEFAULT 'medium',
            time_limit_seconds INTEGER NOT NULL DEFAULT 0,
            problems_json TEXT,
            submitted_answers_json TEXT,
            score REAL,
            status TEXT NOT NULL DEFAULT 'pending',
            started_at TEXT,
            submitted_at TEXT,
            weakness_report_input TEXT,
            generated_explanations_json TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS level_test_result (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL UNIQUE,
            overall_speed REAL NOT NULL DEFAULT 0,
            overall_power REAL NOT NULL DEFAULT 0,
            topic_breakdown_json TEXT,
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS level_test_session (
            session_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            template_id TEXT NOT NULL,
            status TEXT NOT NULL,
            estimated_rating REAL,
            estimated_ovr REAL,
            confidence REAL,
            strong_tags_json TEXT,
            weak_tags_json TEXT,
            started_at TEXT NOT NULL,
            submitted_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS level_test_answer (
            session_id TEXT NOT NULL,
            item_index INTEGER NOT NULL,
            quest_id TEXT NOT NULL,
            is_correct INTEGER NOT NULL,
            answer_time REAL,
            step_correctness_json TEXT NOT NULL,
            tags_json TEXT NOT NULL,
            submitted_at TEXT NOT NULL,
            PRIMARY KEY(session_id, item_index)
        )
        """
    )

    cur.execute(
        """
        CREATE INDEX IF NOT EXISTS level_test_session_user_idx
        ON level_test_session(user_id, started_at DESC)
        """
    )

    conn.commit()
    conn.close()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# ---------------------------------------------------------------------------
# Placement template/session CRUD
# ---------------------------------------------------------------------------


def count_ready_placement_templates() -> int:
    """필요 변수: 없음. 작동 원리: 일반 DB가 아닌 전용 정적 DB의 활성 폼 개수를 반환한다."""
    return len(static_store.list_template_ids())


def pick_ready_placement_template(user_id: str) -> Optional[Dict[str, Any]]:
    """필요 변수: 사용자 ID. 작동 원리: 정적 폼 중 최근 3개를 피하고 전체 배정 횟수가 가장 적은 폼을 선택한다."""
    _ensure_level_test_tables()
    template_ids = static_store.list_template_ids()
    if not template_ids:
        return None
    placeholders = ",".join("?" for _ in template_ids)
    with closing(sqlite3.connect(DB_PATH)) as connection:
        recent = {
            str(row[0])
            for row in connection.execute(
                """
                SELECT template_id FROM level_test_session
                WHERE user_id=? ORDER BY started_at DESC LIMIT 3
                """,
                (user_id,),
            )
        }
        usage = {
            str(row[0]): int(row[1])
            for row in connection.execute(
                f"""
                SELECT template_id, COUNT(*) FROM level_test_session
                WHERE template_id IN ({placeholders}) GROUP BY template_id
                """,
                template_ids,
            )
        }
    candidates = [template_id for template_id in template_ids if template_id not in recent]
    if not candidates:
        candidates = template_ids
    order = {template_id: index for index, template_id in enumerate(template_ids)}
    selected_id = min(candidates, key=lambda value: (usage.get(value, 0), order[value]))
    template = static_store.get_template(selected_id) or {}
    return {**template, "template_id": selected_id, "status": "ready"}


def get_placement_template_items(template_id: str) -> List[Dict[str, Any]]:
    """필요 변수: 정적 시험지 ID. 작동 원리: 전용 정적 DB에서만 50개 슬롯을 읽는다."""
    return static_store.get_template_items(template_id)


def create_placement_session(*, user_id: str, template_id: str) -> str:
    """필요 변수: 사용자 ID와 정적 폼 ID. 작동 원리: 전용 DB에 존재하는 폼만 운영 세션으로 기록한다."""
    if static_store.get_template(template_id) is None:
        raise ValueError(f"unknown static placement template: {template_id}")
    _ensure_level_test_tables()
    session_id = str(uuid.uuid4())
    now = _now_iso()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO level_test_session (
            session_id, user_id, template_id, status, started_at
        )
        VALUES (?, ?, ?, 'started', ?)
        """,
        (session_id, user_id, template_id, now),
    )
    conn.commit()
    conn.close()
    return session_id


def get_placement_session(session_id: str) -> Optional[Dict[str, Any]]:
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM level_test_session WHERE session_id = ?",
        (session_id,),
    )
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def upsert_placement_answer(
    *,
    session_id: str,
    item_index: int,
    quest_id: str,
    is_correct: bool,
    answer_time: Optional[float],
    step_correctness: List[Dict[str, Any]],
    tags: List[str],
) -> None:
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO level_test_answer (
            session_id, item_index, quest_id, is_correct, answer_time,
            step_correctness_json, tags_json, submitted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(session_id, item_index) DO UPDATE SET
            quest_id = excluded.quest_id,
            is_correct = excluded.is_correct,
            answer_time = excluded.answer_time,
            step_correctness_json = excluded.step_correctness_json,
            tags_json = excluded.tags_json,
            submitted_at = excluded.submitted_at
        """,
        (
            session_id,
            int(item_index),
            quest_id,
            1 if is_correct else 0,
            answer_time,
            json.dumps(step_correctness, ensure_ascii=False),
            json.dumps(tags, ensure_ascii=False),
            _now_iso(),
        ),
    )
    conn.commit()
    conn.close()


def list_placement_answers(session_id: str) -> List[Dict[str, Any]]:
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(
        """
        SELECT *
        FROM level_test_answer
        WHERE session_id = ?
        ORDER BY item_index ASC
        """,
        (session_id,),
    )
    rows = cur.fetchall()
    conn.close()
    answers = []
    for row in rows:
        answer = dict(row)
        try:
            answer["step_correctness"] = json.loads(answer.pop("step_correctness_json") or "[]")
        except json.JSONDecodeError:
            answer["step_correctness"] = []
        try:
            answer["tags"] = json.loads(answer.pop("tags_json") or "[]")
        except json.JSONDecodeError:
            answer["tags"] = []
        answer["is_correct"] = bool(answer["is_correct"])
        answers.append(answer)
    return answers


def complete_placement_session(
    *,
    session_id: str,
    estimated_rating: float,
    estimated_ovr: float,
    confidence: float,
    strong_tags: List[Dict[str, Any]],
    weak_tags: List[Dict[str, Any]],
) -> None:
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE level_test_session
        SET status = 'graded',
            estimated_rating = ?,
            estimated_ovr = ?,
            confidence = ?,
            strong_tags_json = ?,
            weak_tags_json = ?,
            submitted_at = ?
        WHERE session_id = ?
        """,
        (
            estimated_rating,
            estimated_ovr,
            confidence,
            json.dumps(strong_tags, ensure_ascii=False),
            json.dumps(weak_tags, ensure_ascii=False),
            _now_iso(),
            session_id,
        ),
    )
    conn.commit()
    conn.close()


# ---------------------------------------------------------------------------
# SpeedTest CRUD
# ---------------------------------------------------------------------------


def create_speed_test(test: SpeedTest) -> int:
    """Insert a new speed test and return its generated ``id``."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO speed_test
            (user_id, topic, difficulty, time_limit_seconds, problems_json,
             submitted_answers_json, score, status, started_at, submitted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            test.user_id,
            test.topic,
            test.difficulty,
            test.time_limit_seconds,
            test.problems_json,
            test.submitted_answers_json,
            test.score,
            test.status,
            test.started_at.isoformat() if test.started_at else None,
            test.submitted_at.isoformat() if test.submitted_at else None,
        ),
    )
    conn.commit()
    test_id = cur.lastrowid
    conn.close()
    return test_id or 0


def get_speed_test(test_id: int) -> Optional[SpeedTest]:
    """Fetch a single speed test by ``id``."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM speed_test WHERE id = ?", (test_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_speed_test(row)


def list_speed_tests(user_id: Optional[str] = None) -> List[SpeedTest]:
    """List speed tests, optionally filtered by ``user_id``."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    if user_id is not None:
        cur.execute(
            "SELECT * FROM speed_test WHERE user_id = ? ORDER BY id DESC",
            (user_id,),
        )
    else:
        cur.execute("SELECT * FROM speed_test ORDER BY id DESC")
    rows = cur.fetchall()
    conn.close()
    return [_row_to_speed_test(r) for r in rows]


def update_speed_test(test: SpeedTest) -> bool:
    """Update an existing speed test. Returns ``True`` if a row was affected."""
    if test.id is None:
        return False
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE speed_test SET
            user_id = ?,
            topic = ?,
            difficulty = ?,
            time_limit_seconds = ?,
            problems_json = ?,
            submitted_answers_json = ?,
            score = ?,
            status = ?,
            started_at = ?,
            submitted_at = ?
        WHERE id = ?
        """,
        (
            test.user_id,
            test.topic,
            test.difficulty,
            test.time_limit_seconds,
            test.problems_json,
            test.submitted_answers_json,
            test.score,
            test.status,
            test.started_at.isoformat() if test.started_at else None,
            test.submitted_at.isoformat() if test.submitted_at else None,
            test.id,
        ),
    )
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# PowerTest CRUD
# ---------------------------------------------------------------------------


def create_power_test(test: PowerTest) -> int:
    """Insert a new power test and return its generated ``id``."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO power_test
            (user_id, topic, difficulty, time_limit_seconds, problems_json,
             submitted_answers_json, score, status, started_at, submitted_at,
             weakness_report_input, generated_explanations_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            test.user_id,
            test.topic,
            test.difficulty,
            test.time_limit_seconds,
            test.problems_json,
            test.submitted_answers_json,
            test.score,
            test.status,
            test.started_at.isoformat() if test.started_at else None,
            test.submitted_at.isoformat() if test.submitted_at else None,
            test.weakness_report_input,
            test.generated_explanations_json,
        ),
    )
    conn.commit()
    test_id = cur.lastrowid
    conn.close()
    return test_id or 0


def get_power_test(test_id: int) -> Optional[PowerTest]:
    """Fetch a single power test by ``id``."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM power_test WHERE id = ?", (test_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_power_test(row)


def list_power_tests(user_id: Optional[str] = None) -> List[PowerTest]:
    """List power tests, optionally filtered by ``user_id``."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    if user_id is not None:
        cur.execute(
            "SELECT * FROM power_test WHERE user_id = ? ORDER BY id DESC",
            (user_id,),
        )
    else:
        cur.execute("SELECT * FROM power_test ORDER BY id DESC")
    rows = cur.fetchall()
    conn.close()
    return [_row_to_power_test(r) for r in rows]


def update_power_test(test: PowerTest) -> bool:
    """Update an existing power test. Returns ``True`` if a row was affected."""
    if test.id is None:
        return False
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE power_test SET
            user_id = ?,
            topic = ?,
            difficulty = ?,
            time_limit_seconds = ?,
            problems_json = ?,
            submitted_answers_json = ?,
            score = ?,
            status = ?,
            started_at = ?,
            submitted_at = ?,
            weakness_report_input = ?,
            generated_explanations_json = ?
        WHERE id = ?
        """,
        (
            test.user_id,
            test.topic,
            test.difficulty,
            test.time_limit_seconds,
            test.problems_json,
            test.submitted_answers_json,
            test.score,
            test.status,
            test.started_at.isoformat() if test.started_at else None,
            test.submitted_at.isoformat() if test.submitted_at else None,
            test.weakness_report_input,
            test.generated_explanations_json,
            test.id,
        ),
    )
    conn.commit()
    affected = cur.rowcount > 0
    conn.close()
    return affected


# ---------------------------------------------------------------------------
# LevelTestResult CRUD
# ---------------------------------------------------------------------------


def save_level_test_result(result: LevelTestResult) -> int:
    """Upsert a level-test result row and return its ``id``."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # Check existing
    cur.execute(
        "SELECT id FROM level_test_result WHERE user_id = ?",
        (result.user_id,),
    )
    existing = cur.fetchone()

    topic_json = json.dumps(result.topic_breakdown, ensure_ascii=False)

    if existing:
        cur.execute(
            """
            UPDATE level_test_result SET
                overall_speed = ?,
                overall_power = ?,
                topic_breakdown_json = ?,
                updated_at = ?
            WHERE user_id = ?
            """,
            (
                result.overall_speed,
                result.overall_power,
                topic_json,
                _now_iso(),
                result.user_id,
            ),
        )
        conn.commit()
        row_id = existing[0]
    else:
        cur.execute(
            """
            INSERT INTO level_test_result
                (user_id, overall_speed, overall_power, topic_breakdown_json, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                result.user_id,
                result.overall_speed,
                result.overall_power,
                topic_json,
                _now_iso(),
            ),
        )
        conn.commit()
        row_id = cur.lastrowid or 0

    conn.close()
    return row_id


def get_level_test_result(user_id: str) -> Optional[LevelTestResult]:
    """Fetch the aggregated result for a user."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM level_test_result WHERE user_id = ?", (user_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return None
    return _row_to_level_test_result(row)


def list_level_test_results() -> List[LevelTestResult]:
    """List all aggregated level-test results."""
    _ensure_level_test_tables()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM level_test_result ORDER BY updated_at DESC")
    rows = cur.fetchall()
    conn.close()
    return [_row_to_level_test_result(r) for r in rows]


# ---------------------------------------------------------------------------
# Row mappers
# ---------------------------------------------------------------------------


def _parse_iso(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _row_to_speed_test(row: sqlite3.Row) -> SpeedTest:
    return SpeedTest(
        id=row["id"],
        user_id=row["user_id"],
        topic=row["topic"],
        difficulty=row["difficulty"],
        time_limit_seconds=row["time_limit_seconds"],
        problems_json=row["problems_json"],
        submitted_answers_json=row["submitted_answers_json"],
        score=row["score"],
        status=row["status"],
        started_at=_parse_iso(row["started_at"]),
        submitted_at=_parse_iso(row["submitted_at"]),
    )


def _row_to_power_test(row: sqlite3.Row) -> PowerTest:
    return PowerTest(
        id=row["id"],
        user_id=row["user_id"],
        topic=row["topic"],
        difficulty=row["difficulty"],
        time_limit_seconds=row["time_limit_seconds"],
        problems_json=row["problems_json"],
        submitted_answers_json=row["submitted_answers_json"],
        score=row["score"],
        status=row["status"],
        started_at=_parse_iso(row["started_at"]),
        submitted_at=_parse_iso(row["submitted_at"]),
        weakness_report_input=row["weakness_report_input"],
        generated_explanations_json=row["generated_explanations_json"],
    )


def _row_to_level_test_result(row: sqlite3.Row) -> LevelTestResult:
    topic_json = row["topic_breakdown_json"]
    topic_breakdown: Dict[str, Any] = {}
    if topic_json:
        try:
            topic_breakdown = json.loads(topic_json)
        except json.JSONDecodeError:
            topic_breakdown = {}
    return LevelTestResult(
        user_id=row["user_id"],
        overall_speed=row["overall_speed"],
        overall_power=row["overall_power"],
        topic_breakdown=topic_breakdown,
    )
