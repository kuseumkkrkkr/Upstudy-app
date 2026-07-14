import sqlite3
import time
from typing import Dict, Iterable, List, Tuple

from storage.storage import DB_PATH


def _now_ts() -> int:
    return int(time.time())


def init_ox_quiz_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS ox_quiz_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tag TEXT NOT NULL,
            question TEXT NOT NULL,
            answer INTEGER NOT NULL,
            created_by TEXT,
            created_at INTEGER NOT NULL,
            UNIQUE(tag, question)
        )
        """
    )
    conn.commit()
    conn.close()


def _normalize_tags(tags: Iterable[str]) -> List[str]:
    norm = []
    for tag in tags:
        t = (tag or "").strip()
        if not t:
            continue
        if not t.startswith("#"):
            t = "#" + t
        norm.append(t)
    # de-duplicate while preserving order
    seen = set()
    dedup: List[str] = []
    for t in norm:
        key = t.lower()
        if key in seen:
            continue
        seen.add(key)
        dedup.append(t)
    return dedup


def count_by_tag(tag: str) -> int:
    init_ox_quiz_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM ox_quiz_questions WHERE LOWER(tag)=LOWER(?)", (tag,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else 0


def insert_questions(
    *, tag: str, qa_list: List[Tuple[str, bool]], created_by: str | None
) -> int:
    """
    Insert questions for a tag. Ignores duplicates due to UNIQUE constraint.
    Returns number of inserted rows.
    """
    if not qa_list:
        return 0
    init_ox_quiz_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now_ts = _now_ts()
    payload = [(tag, q, int(ans), created_by, now_ts) for q, ans in qa_list]
    cur.executemany(
        """
        INSERT OR IGNORE INTO ox_quiz_questions (tag, question, answer, created_by, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        payload,
    )
    conn.commit()
    inserted = cur.rowcount if cur.rowcount is not None else 0
    conn.close()
    return inserted


def fetch_questions_by_tags(
    tags: Iterable[str], per_tag_limit: int = 3
) -> List[Dict[str, str | int | bool]]:
    norm_tags = _normalize_tags(tags)
    if not norm_tags:
        return []
    init_ox_quiz_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    results: List[Dict[str, str | int | bool]] = []
    for tag in norm_tags:
        cur.execute(
            """
            SELECT id, tag, question, answer, created_at, created_by
            FROM ox_quiz_questions
            WHERE LOWER(tag)=LOWER(?)
            ORDER BY RANDOM()
            LIMIT ?
            """,
            (tag, per_tag_limit),
        )
        rows = cur.fetchall()
        for row in rows:
            results.append(
                {
                    "id": row[0],
                    "tag": row[1],
                    "question": row[2],
                    "answer": bool(row[3]),
                    "created_at": row[4],
                    "created_by": row[5],
                }
            )
    conn.close()
    return results


def fetch_random_questions(limit: int = 10) -> List[Dict[str, str | int | bool]]:
    """
    필요 변수: 반환할 최대 문항 수.
    작동 원리: 태그 조건이 없는 아레나용 OX 문항을 DB 전체에서 무작위로 제한 조회한다.
    """
    init_ox_quiz_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, tag, question, answer, created_at, created_by
        FROM ox_quiz_questions
        ORDER BY RANDOM()
        LIMIT ?
        """,
        (max(1, min(int(limit), 100)),),
    )
    rows = cur.fetchall()
    conn.close()
    return [
        {
            "id": row[0],
            "tag": row[1],
            "question": row[2],
            "answer": bool(row[3]),
            "created_at": row[4],
            "created_by": row[5],
        }
        for row in rows
    ]
