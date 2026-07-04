from __future__ import annotations

import sqlite3
from datetime import datetime
from typing import Any, Dict, List, Optional

from storage.storage import DB_PATH


TEST_TOP_UP_AMOUNTS = {100, 500, 1000, 5000, 10000}

DEFAULT_ITEMS = [
    {
        "item_id": "problem_db",
        "title": "문제 DB",
        "description": "문제 검색에서 전체 문제 DB까지 사용할 수 있습니다.",
        "price_points": 1000,
        "kind": "problem",
    },
    {
        "item_id": "textbook_db",
        "title": "교재 DB",
        "description": "상점 교재 DB 상품과 보유 교재를 확장합니다.",
        "price_points": 1000,
        "kind": "textbook",
    },
    {
        "item_id": "exam_db",
        "title": "시험지 DB",
        "description": "시험지 DB 상품과 공개 시험지 자료를 사용할 수 있습니다.",
        "price_points": 1000,
        "kind": "exam",
    },
]


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def init_teacher_store_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS teacher_wallet (
            user_id TEXT PRIMARY KEY,
            balance_points INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS teacher_point_ledger (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            delta_points INTEGER NOT NULL,
            reason TEXT NOT NULL,
            ref_id TEXT,
            created_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS store_item (
            item_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            price_points INTEGER NOT NULL,
            kind TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS teacher_entitlement (
            user_id TEXT NOT NULL,
            item_id TEXT NOT NULL,
            purchased_at TEXT NOT NULL,
            PRIMARY KEY (user_id, item_id)
        )
        """
    )
    now = _now_iso()
    for item in DEFAULT_ITEMS:
        cur.execute(
            """
            INSERT INTO store_item (
                item_id, title, description, price_points, kind, active, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, 1, ?, ?)
            ON CONFLICT(item_id) DO UPDATE SET
                title = excluded.title,
                description = excluded.description,
                price_points = excluded.price_points,
                kind = excluded.kind,
                active = 1,
                updated_at = excluded.updated_at
            """,
            (
                item["item_id"],
                item["title"],
                item["description"],
                item["price_points"],
                item["kind"],
                now,
                now,
            ),
        )
    cur.execute("CREATE INDEX IF NOT EXISTS idx_teacher_ledger_user_time ON teacher_point_ledger(user_id, created_at DESC)")
    conn.commit()
    conn.close()


def _ensure_wallet(cur: sqlite3.Cursor, user_id: str) -> None:
    cur.execute(
        """
        INSERT INTO teacher_wallet (user_id, balance_points, updated_at)
        VALUES (?, 0, ?)
        ON CONFLICT(user_id) DO NOTHING
        """,
        (user_id, _now_iso()),
    )


def get_balance(user_id: str) -> int:
    init_teacher_store_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    _ensure_wallet(cur, user_id)
    cur.execute("SELECT balance_points FROM teacher_wallet WHERE user_id = ?", (user_id,))
    row = cur.fetchone()
    conn.commit()
    conn.close()
    return int(row[0] if row else 0)


def list_items(user_id: str) -> List[Dict[str, Any]]:
    init_teacher_store_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT item_id, title, description, price_points, kind, active
        FROM store_item
        WHERE active = 1
        ORDER BY price_points ASC, item_id ASC
        """
    )
    rows = cur.fetchall()
    owned = set(list_entitlements(user_id))
    conn.close()
    return [
        {
            "item_id": row[0],
            "title": row[1],
            "description": row[2],
            "price_points": int(row[3]),
            "kind": row[4],
            "active": bool(row[5]),
            "owned": row[0] in owned,
        }
        for row in rows
    ]


def list_entitlements(user_id: str) -> List[str]:
    init_teacher_store_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT item_id FROM teacher_entitlement WHERE user_id = ? ORDER BY purchased_at DESC",
        (user_id,),
    )
    rows = cur.fetchall()
    conn.close()
    return [str(row[0]) for row in rows]


def has_entitlement(user_id: str, item_id: str) -> bool:
    init_teacher_store_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT 1 FROM teacher_entitlement WHERE user_id = ? AND item_id = ?",
        (user_id, item_id),
    )
    row = cur.fetchone()
    conn.close()
    return row is not None


def top_up_test(user_id: str, amount: int) -> Dict[str, Any]:
    if amount not in TEST_TOP_UP_AMOUNTS:
        raise ValueError("invalid_top_up_amount")
    init_teacher_store_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = _now_iso()
    _ensure_wallet(cur, user_id)
    cur.execute(
        "UPDATE teacher_wallet SET balance_points = balance_points + ?, updated_at = ? WHERE user_id = ?",
        (amount, now, user_id),
    )
    cur.execute(
        "INSERT INTO teacher_point_ledger (user_id, delta_points, reason, ref_id, created_at) VALUES (?, ?, ?, ?, ?)",
        (user_id, amount, "test_top_up", None, now),
    )
    conn.commit()
    conn.close()
    return summary(user_id)


def purchase(user_id: str, item_id: str) -> Dict[str, Any]:
    init_teacher_store_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = _now_iso()
    _ensure_wallet(cur, user_id)
    cur.execute(
        "SELECT price_points, active FROM store_item WHERE item_id = ?",
        (item_id,),
    )
    item = cur.fetchone()
    if item is None or not bool(item[1]):
        conn.close()
        raise ValueError("store_item_not_found")
    cur.execute(
        "SELECT 1 FROM teacher_entitlement WHERE user_id = ? AND item_id = ?",
        (user_id, item_id),
    )
    if cur.fetchone() is not None:
        conn.close()
        raise ValueError("already_purchased")
    price = int(item[0])
    cur.execute("SELECT balance_points FROM teacher_wallet WHERE user_id = ?", (user_id,))
    balance = int((cur.fetchone() or [0])[0])
    if balance < price:
        conn.close()
        raise ValueError("insufficient_points")
    cur.execute(
        "UPDATE teacher_wallet SET balance_points = balance_points - ?, updated_at = ? WHERE user_id = ?",
        (price, now, user_id),
    )
    cur.execute(
        "INSERT INTO teacher_entitlement (user_id, item_id, purchased_at) VALUES (?, ?, ?)",
        (user_id, item_id, now),
    )
    cur.execute(
        "INSERT INTO teacher_point_ledger (user_id, delta_points, reason, ref_id, created_at) VALUES (?, ?, ?, ?, ?)",
        (user_id, -price, "purchase", item_id, now),
    )
    conn.commit()
    conn.close()
    return summary(user_id)


def summary(user_id: str) -> Dict[str, Any]:
    return {
        "balance_points": get_balance(user_id),
        "entitlements": list_entitlements(user_id),
        "items": list_items(user_id),
        "test_top_up_amounts": sorted(TEST_TOP_UP_AMOUNTS),
    }
