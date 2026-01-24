import json
import random
import sqlite3
from datetime import datetime
from typing import Any, Dict, List, Optional

from storage.storage import DB_PATH


def init_exam_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS exam (
            exam_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            status TEXT NOT NULL,
            params TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS exam_item (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id TEXT NOT NULL,
            item_index INTEGER NOT NULL,
            status TEXT NOT NULL,
            subject_key TEXT NOT NULL,
            hash_tags TEXT NOT NULL,
            difficulty_tier INTEGER NOT NULL,
            solves_count INTEGER NOT NULL,
            strategy_level INTEGER NOT NULL,
            branch_conditions INTEGER NOT NULL,
            quest_id TEXT,
            flow_count INTEGER,
            error TEXT,
            FOREIGN KEY (exam_id) REFERENCES exam(exam_id)
        )
        """
    )

    cursor.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS exam_item_unique
        ON exam_item (exam_id, item_index)
        """
    )

    conn.commit()
    conn.close()


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def create_exam(
    exam_id: str,
    user_id: str,
    params: Dict[str, Any],
    status: str = "queued",
) -> None:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    now = _now_iso()
    cursor.execute(
        """
        INSERT INTO exam (exam_id, user_id, status, params, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (exam_id, user_id, status, json.dumps(params), now, now),
    )
    conn.commit()
    conn.close()


def update_exam_status(exam_id: str, status: str) -> None:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        UPDATE exam
        SET status = ?, updated_at = ?
        WHERE exam_id = ?
        """,
        (status, _now_iso(), exam_id),
    )
    conn.commit()
    conn.close()


def add_exam_items(exam_id: str, items: List[Dict[str, Any]]) -> None:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    payload = [
        (
            exam_id,
            item["item_index"],
            item["status"],
            item["subject_key"],
            json.dumps(item["hash_tags"]),
            item["difficulty_tier"],
            item["solves_count"],
            item["strategy_level"],
            item["branch_conditions"],
            item.get("quest_id"),
            item.get("flow_count"),
            item.get("error"),
        )
        for item in items
    ]
    cursor.executemany(
        """
        INSERT INTO exam_item (
            exam_id,
            item_index,
            status,
            subject_key,
            hash_tags,
            difficulty_tier,
            solves_count,
            strategy_level,
            branch_conditions,
            quest_id,
            flow_count,
            error
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        payload,
    )
    conn.commit()
    conn.close()


def update_exam_item(
    exam_id: str,
    item_index: int,
    *,
    status: Optional[str] = None,
    quest_id: Optional[str] = None,
    flow_count: Optional[int] = None,
    error: Optional[str] = None,
) -> None:
    updates = []
    params: List[Any] = []
    if status is not None:
        updates.append("status = ?")
        params.append(status)
    if quest_id is not None:
        updates.append("quest_id = ?")
        params.append(quest_id)
    if flow_count is not None:
        updates.append("flow_count = ?")
        params.append(flow_count)
    if error is not None:
        updates.append("error = ?")
        params.append(error)
    if not updates:
        return
    params.extend([exam_id, item_index])

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        f"""
        UPDATE exam_item
        SET {", ".join(updates)}
        WHERE exam_id = ? AND item_index = ?
        """,
        params,
    )
    conn.commit()
    conn.close()


def get_exam(exam_id: str) -> Optional[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT exam_id, user_id, status, params, created_at, updated_at FROM exam WHERE exam_id = ?", (exam_id,))
    row = cursor.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "exam_id": row[0],
        "user_id": row[1],
        "status": row[2],
        "params": json.loads(row[3]),
        "created_at": row[4],
        "updated_at": row[5],
    }


def get_exam_items(exam_id: str) -> List[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT
            item_index,
            status,
            subject_key,
            hash_tags,
            difficulty_tier,
            solves_count,
            strategy_level,
            branch_conditions,
            quest_id,
            flow_count,
            error
        FROM exam_item
        WHERE exam_id = ?
        ORDER BY item_index ASC
        """,
        (exam_id,),
    )
    rows = cursor.fetchall()
    conn.close()
    items: List[Dict[str, Any]] = []
    for row in rows:
        items.append(
            {
                "item_index": row[0],
                "status": row[1],
                "subject_key": row[2],
                "hash_tags": json.loads(row[3]),
                "difficulty_tier": row[4],
                "solves_count": row[5],
                "strategy_level": row[6],
                "branch_conditions": row[7],
                "quest_id": row[8],
                "flow_count": row[9],
                "error": row[10],
            }
        )
    return items

def get_total_quest_count() -> int:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM quest_header")
    row = cursor.fetchone()
    conn.close()
    return int(row[0] or 0)


def find_reusable_quest(
    *,
    target_tags: List[str],
    min_flow: int,
    max_flow: int,
    used_quest_ids: Optional[set[str]] = None,
) -> Optional[str]:
    if not target_tags:
        return None
    used_quest_ids = used_quest_ids or set()
    normalized_targets = {_normalize_tag(tag) for tag in target_tags if _normalize_tag(tag)}
    if not normalized_targets:
        return None

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT quest_id, flow_rate, hash_tag
        FROM quest_info
        """
    )
    rows = cursor.fetchall()
    conn.close()

    candidates = []
    for quest_id, flow_rate, hash_tag_json in rows:
        if quest_id in used_quest_ids:
            continue
        try:
            tags = json.loads(hash_tag_json)
        except json.JSONDecodeError:
            tags = []
        normalized = {_normalize_tag(tag) for tag in tags if _normalize_tag(tag)}
        if not (normalized & normalized_targets):
            continue
        if flow_rate < min_flow or flow_rate > max_flow:
            continue
        candidates.append(quest_id)

    if not candidates:
        return None
    return random.choice(candidates)


def _normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip()
