import json
import sqlite3
import uuid
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional

from storage.storage import DB_PATH


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def init_exam_editor_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS user_problem_set (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            codebase_id INTEGER,
            seed INTEGER,
            quest_id TEXT NOT NULL,
            question_type TEXT,
            hash_tags TEXT NOT NULL DEFAULT '[]',
            created_at TEXT NOT NULL,
            UNIQUE(user_id, quest_id)
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS exam_editor_paper (
            paper_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            two_per_page INTEGER NOT NULL DEFAULT 0,
            grading_area_direction TEXT NOT NULL DEFAULT 'bottom',
            source_connected INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS exam_editor_paper_item (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            paper_id TEXT NOT NULL,
            order_no INTEGER NOT NULL,
            page_no INTEGER NOT NULL DEFAULT 1,
            layout_slot TEXT NOT NULL DEFAULT 'auto',
            codebase_id INTEGER,
            seed INTEGER,
            quest_id TEXT NOT NULL,
            question_type TEXT,
            is_geometry INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            UNIQUE(paper_id, order_no)
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS exam_editor_source_pref (
            user_id TEXT PRIMARY KEY,
            source_connected INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL
        )
        """
    )
    cur.execute("CREATE INDEX IF NOT EXISTS idx_upset_user_created ON user_problem_set (user_id, created_at DESC)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_upset_user_codebase_seed ON user_problem_set (user_id, codebase_id, seed)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_paper_user_updated ON exam_editor_paper (user_id, updated_at DESC)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_paper_item_paper ON exam_editor_paper_item (paper_id, order_no ASC)")
    conn.commit()
    conn.close()


def get_source_connected(user_id: str) -> bool:
    init_exam_editor_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT source_connected FROM exam_editor_source_pref WHERE user_id = ?", (user_id,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return True
    return bool(int(row[0]))


def set_source_connected(user_id: str, enabled: bool) -> bool:
    init_exam_editor_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = _now_iso()
    cur.execute(
        """
        INSERT INTO exam_editor_source_pref (user_id, source_connected, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            source_connected = excluded.source_connected,
            updated_at = excluded.updated_at
        """,
        (user_id, 1 if enabled else 0, now),
    )
    conn.commit()
    conn.close()
    return enabled


def upsert_user_problem_set(user_id: str, items: Iterable[Dict[str, Any]]) -> int:
    init_exam_editor_db()
    now = _now_iso()
    payload: List[tuple] = []
    for item in items:
        quest_id = str(item.get("quest_id") or "").strip()
        if not quest_id:
            continue
        tags = item.get("hash_tags") or []
        payload.append(
            (
                user_id,
                int(item["codebase_id"]) if item.get("codebase_id") is not None else None,
                int(item["seed"]) if item.get("seed") is not None else None,
                quest_id,
                item.get("question_type"),
                json.dumps(tags, ensure_ascii=False),
                now,
            )
        )
    if not payload:
        return 0
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.executemany(
        """
        INSERT INTO user_problem_set (
            user_id, codebase_id, seed, quest_id, question_type, hash_tags, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, quest_id) DO UPDATE SET
            codebase_id = excluded.codebase_id,
            seed = excluded.seed,
            question_type = excluded.question_type,
            hash_tags = excluded.hash_tags
        """,
        payload,
    )
    conn.commit()
    count = cur.rowcount
    conn.close()
    return max(count, 0)


def search_user_problem_set(
    *,
    user_id: str,
    hash_tag: Optional[str] = None,
    text: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    page: int = 1,
    page_size: int = 50,
) -> Dict[str, Any]:
    init_exam_editor_db()
    safe_page = max(1, int(page))
    safe_page_size = max(1, min(int(page_size), 200))
    where: List[str] = ["ups.user_id = ?"]
    params: List[Any] = [user_id]
    if hash_tag and hash_tag.strip():
        where.append("LOWER(ups.hash_tags) LIKE ?")
        params.append(f"%{hash_tag.strip().lower().lstrip('#')}%")
    if text and text.strip():
        where.append("LOWER(COALESCE(qd.quest_title, '')) LIKE ?")
        params.append(f"%{text.strip().lower()}%")
    if date_from and date_from.strip():
        where.append("date(ups.created_at) >= date(?)")
        params.append(date_from.strip())
    if date_to and date_to.strip():
        where.append("date(ups.created_at) <= date(?)")
        params.append(date_to.strip())
    where_clause = " AND ".join(where)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        f"""
        SELECT COUNT(*)
        FROM user_problem_set ups
        LEFT JOIN quest_data qd ON qd.quest_id = ups.quest_id
        WHERE {where_clause}
        """,
        params,
    )
    total = int(cur.fetchone()[0] or 0)
    offset = (safe_page - 1) * safe_page_size
    cur.execute(
        f"""
        SELECT
            ups.quest_id, ups.codebase_id, ups.seed, ups.question_type, ups.hash_tags, ups.created_at,
            qd.quest_title
        FROM user_problem_set ups
        LEFT JOIN quest_data qd ON qd.quest_id = ups.quest_id
        WHERE {where_clause}
        ORDER BY datetime(ups.created_at) DESC
        LIMIT ? OFFSET ?
        """,
        [*params, safe_page_size, offset],
    )
    rows = cur.fetchall()
    conn.close()
    items: List[Dict[str, Any]] = []
    for row in rows:
        tags: List[str] = []
        try:
            parsed = json.loads(row[4] or "[]")
            if isinstance(parsed, list):
                tags = [str(v) for v in parsed]
        except Exception:
            pass
        items.append(
            {
                "quest_id": row[0],
                "codebase_id": row[1],
                "seed": row[2],
                "question_type": row[3],
                "hash_tags": tags,
                "created_at": row[5],
                "quest_title": row[6],
            }
        )
    return {"items": items, "total": total, "page": safe_page, "page_size": safe_page_size}


def save_exam_editor_paper(
    *,
    user_id: str,
    title: str,
    items: List[Dict[str, Any]],
    two_per_page: bool = False,
    grading_area_direction: str = "bottom",
    paper_id: Optional[str] = None,
    expected_updated_at: Optional[str] = None,
) -> Dict[str, Any]:
    init_exam_editor_db()
    if len(items) > 100:
        raise ValueError("maximum 100 items allowed")
    now = _now_iso()
    resolved_paper_id = (paper_id or str(uuid.uuid4())).strip()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute("BEGIN IMMEDIATE")
        if paper_id:
            cur.execute("SELECT updated_at FROM exam_editor_paper WHERE paper_id = ? AND user_id = ?", (resolved_paper_id, user_id))
            existing = cur.fetchone()
            if not existing:
                raise ValueError("paper not found")
            if expected_updated_at and str(existing[0]) != expected_updated_at:
                raise RuntimeError("version_conflict")
            cur.execute(
                """
                UPDATE exam_editor_paper
                SET title = ?, two_per_page = ?, grading_area_direction = ?, updated_at = ?
                WHERE paper_id = ? AND user_id = ?
                """,
                (title.strip() or "새 시험지", 1 if two_per_page else 0, grading_area_direction, now, resolved_paper_id, user_id),
            )
            cur.execute("DELETE FROM exam_editor_paper_item WHERE paper_id = ?", (resolved_paper_id,))
        else:
            cur.execute(
                """
                INSERT INTO exam_editor_paper (
                    paper_id, user_id, title, two_per_page, grading_area_direction, source_connected, updated_at, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (resolved_paper_id, user_id, title.strip() or "새 시험지", 1 if two_per_page else 0, grading_area_direction, 1 if get_source_connected(user_id) else 0, now, now),
            )
        payload = []
        for idx, item in enumerate(items):
            quest_id = str(item.get("quest_id") or "").strip()
            if not quest_id:
                continue
            payload.append(
                (
                    resolved_paper_id,
                    idx,
                    int(item.get("page_no") or (idx // (2 if two_per_page else 4)) + 1),
                    str(item.get("layout_slot") or "auto"),
                    int(item["codebase_id"]) if item.get("codebase_id") is not None else None,
                    int(item["seed"]) if item.get("seed") is not None else None,
                    quest_id,
                    item.get("question_type"),
                    1 if item.get("is_geometry") else 0,
                    now,
                )
            )
        if payload:
            cur.executemany(
                """
                INSERT INTO exam_editor_paper_item (
                    paper_id, order_no, page_no, layout_slot, codebase_id, seed, quest_id, question_type, is_geometry, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                payload,
            )
        conn.commit()
    except Exception:
        conn.rollback()
        conn.close()
        raise
    conn.close()
    return {"paper_id": resolved_paper_id, "updated_at": now, "item_count": len(items)}


def get_exam_editor_paper(user_id: str, paper_id: str) -> Optional[Dict[str, Any]]:
    init_exam_editor_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT paper_id, title, two_per_page, grading_area_direction, source_connected, updated_at, created_at
        FROM exam_editor_paper
        WHERE paper_id = ? AND user_id = ?
        """,
        (paper_id, user_id),
    )
    paper_row = cur.fetchone()
    if not paper_row:
        conn.close()
        return None
    cur.execute(
        """
        SELECT order_no, page_no, layout_slot, codebase_id, seed, quest_id, question_type, is_geometry
        FROM exam_editor_paper_item
        WHERE paper_id = ?
        ORDER BY order_no ASC
        """,
        (paper_id,),
    )
    item_rows = cur.fetchall()
    conn.close()
    items = [
        {
            "order_no": row[0],
            "page_no": row[1],
            "layout_slot": row[2],
            "codebase_id": row[3],
            "seed": row[4],
            "quest_id": row[5],
            "question_type": row[6],
            "is_geometry": bool(row[7]),
        }
        for row in item_rows
    ]
    return {
        "paper_id": paper_row[0],
        "title": paper_row[1],
        "two_per_page": bool(paper_row[2]),
        "grading_area_direction": paper_row[3],
        "source_connected": bool(paper_row[4]),
        "updated_at": paper_row[5],
        "created_at": paper_row[6],
        "items": items,
    }

