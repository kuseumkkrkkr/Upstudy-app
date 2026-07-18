import json
from infra.db import postgres_compat as db
from datetime import datetime, timedelta
from typing import Any, Dict, Optional

# 필요 변수: 이의신청 확인에 필요한 최근 풀이 기록의 보관 일수와 최대 건수.
# 작동 원리: 서버는 최근 7일분만 유지하고, 저장 직후 만료 행을 삭제해 장기 영구 적재를 막는다.
_RETENTION_FULL_DAYS = 7
_RETENTION_MAX_DAYS = 7
_MAX_RECORDS_PER_USER = 210  # 사용자당 하루 30문제 × 7일
_RECENT_CORRECT_DAYS_DEFAULT = 7


def _now_iso() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def _cutoff(days: int) -> str:
    return (datetime.utcnow() - timedelta(days=days)).isoformat(timespec="seconds") + "Z"


def init_solve_history_db() -> None:
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS solve_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            kind TEXT NOT NULL, -- problem | exam
            quest_id TEXT,
            exam_id TEXT,
            codebase_id INTEGER,
            seed INTEGER,
            created_at TEXT NOT NULL,
            data TEXT NOT NULL,
            compressed INTEGER NOT NULL DEFAULT 0
        )
        """
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_solve_history_user_created ON solve_history (user_id, created_at DESC)"
    )
    conn.commit()
    conn.close()


def _compress_payload(raw: Dict[str, Any]) -> Dict[str, Any]:
    """Keep only lightweight fields for long-term storage."""
    return {
        "status": raw.get("status"),
        "in_panic": raw.get("in_panic"),
        "ai_opinion": raw.get("ai_opinion"),
        "quest_id": raw.get("quest_id"),
        "quest_model": raw.get("quest_model"),
        "exam_id": raw.get("exam_id"),
        "codebase_id": raw.get("codebase_id"),
        "seed": raw.get("seed"),
        "all_formulas": raw.get("all_formulas"),
        "ocr_all_formulas": raw.get("ocr_all_formulas"),
        "ocr_purple_formulas": raw.get("ocr_purple_formulas"),
    }


def _purge_and_compress(user_id: str, *, delete_after_max: bool = True) -> None:
    init_solve_history_db()
    conn = db.connect()
    cur = conn.cursor()
    # 7일 정책에서는 압축 보관 구간이 없으며, 만료 행만 삭제한다.
    cutoff_full = _cutoff(_RETENTION_FULL_DAYS)
    cutoff_max = _cutoff(_RETENTION_MAX_DAYS)
    cur.execute(
        """
        SELECT id, data FROM solve_history
        WHERE user_id = ? AND compressed = 0 AND created_at < ? AND created_at >= ?
        """,
        (user_id, cutoff_full, cutoff_max),
    )
    rows = cur.fetchall()
    for row_id, data_text in rows:
        try:
            data = json.loads(data_text)
        except Exception:
            continue
        compressed = _compress_payload(data)
        cur.execute(
            "UPDATE solve_history SET data = ?, compressed = 1 WHERE id = ?",
            (json.dumps(compressed, ensure_ascii=False), row_id),
        )

    # 이의신청 보관 기간(7일)을 넘긴 풀이는 서버 DB에서 제거한다.
    if delete_after_max:
        cur.execute(
            "DELETE FROM solve_history WHERE user_id = ? AND created_at < ?",
            (user_id, cutoff_max),
        )
        # Trim to most recent N records per user (keep newest first)
        cur.execute(
            """
            DELETE FROM solve_history
            WHERE id IN (
              SELECT id FROM solve_history
              WHERE user_id = ?
              ORDER BY datetime(created_at) DESC
              LIMIT -1 OFFSET ?
            )
            """,
            (user_id, _MAX_RECORDS_PER_USER),
        )
    conn.commit()
    conn.close()


def save_solve_history(
    *,
    user_id: str,
    kind: str,
    quest_id: Optional[str] = None,
    exam_id: Optional[str] = None,
    codebase_id: Optional[int] = None,
    seed: Optional[int] = None,
    payload: Dict[str, Any],
    created_at: Optional[str] = None,
    delete_after_max: bool = True,
) -> None:
    """Persist full solve payload then enforce retention/compression policy."""
    init_solve_history_db()
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO solve_history (
            user_id, kind, quest_id, exam_id, codebase_id, seed, created_at, data, compressed
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
        """,
        (
            user_id,
            kind,
            quest_id,
            exam_id,
            codebase_id,
            seed,
            created_at or _now_iso(),
            json.dumps(payload, ensure_ascii=False),
        ),
    )
    conn.commit()
    conn.close()
    _purge_and_compress(user_id, delete_after_max=delete_after_max)


def list_solve_history(
    *,
    user_id: str,
    days: int = _RETENTION_FULL_DAYS,
    limit: int = 200,
    kind: Optional[str] = None,
) -> list[dict[str, Any]]:
    """Return recent solve history ordered by newest first.

    Args:
        user_id: owner of the records.
        days: lookback window (capped 1.._RETENTION_MAX_DAYS).
        limit: max rows (capped 1.._MAX_RECORDS_PER_USER).
        kind: optional filter ('problem' or 'exam').
    """
    init_solve_history_db()
    # Normalize bounds
    days = max(1, min(days, _RETENTION_MAX_DAYS))
    limit = max(1, min(limit, _MAX_RECORDS_PER_USER))
    cutoff = _cutoff(days)
    conn = db.connect()
    cur = conn.cursor()
    where = ["user_id = ?", "created_at >= ?"]
    params: list[Any] = [user_id, cutoff]
    if kind:
        where.append("kind = ?")
        params.append(kind)
    cur.execute(
        f"""
        SELECT created_at, kind, quest_id, exam_id, codebase_id, seed, data
        FROM solve_history
        WHERE {' AND '.join(where)}
        ORDER BY datetime(created_at) DESC
        LIMIT ?
        """,
        [*params, limit],
    )
    rows = cur.fetchall()
    conn.close()
    results: list[dict[str, Any]] = []
    for created_at, kind_val, quest_id, exam_id, codebase_id, seed, data_text in rows:
        try:
            data = json.loads(data_text)
        except Exception:
            data = None
        results.append(
            {
                "created_at": created_at,
                "kind": kind_val,
                "quest_id": quest_id,
                "exam_id": exam_id,
                "codebase_id": codebase_id,
                "seed": seed,
                "data": data,
            }
        )
    return results


def recent_correct_codebases(
    user_id: str,
    days: int = _RECENT_CORRECT_DAYS_DEFAULT,
    limit: int = 2000,
) -> set[int]:
    """
    Return codebase_ids the user solved correctly within given days.
    Only records where all status entries are 'O' are counted.
    """
    init_solve_history_db()
    cutoff = _cutoff(days)
    conn = db.connect()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT data
        FROM solve_history
        WHERE user_id = ? AND created_at >= ?
        ORDER BY datetime(created_at) DESC
        LIMIT ?
        """,
        (user_id, cutoff, max(1, limit)),
    )
    rows = cur.fetchall()
    conn.close()
    result: set[int] = set()
    for (data_text,) in rows:
        try:
            data = json.loads(data_text)
        except Exception:
            continue
        status_list = data.get("status")
        if not isinstance(status_list, list) or not status_list:
            continue
        if not all(
            isinstance(item, dict) and str(item.get("status", "")).upper() == "O"
            for item in status_list
        ):
            continue
        cb = data.get("codebase_id")
        try:
            cb_int = int(cb) if cb is not None else None
        except Exception:
            cb_int = None
        if cb_int is not None:
            result.add(cb_int)
    return result


def is_latest_fully_correct(
    *,
    user_id: str,
    kind: str,
    quest_id: Optional[str] = None,
    exam_id: Optional[str] = None,
) -> bool:
    """
    Check the most recent solve record for the given target and see if all steps were correct.
    """
    init_solve_history_db()
    conn = db.connect()
    cur = conn.cursor()
    where = ["user_id = ?", "kind = ?"]
    params: list[Any] = [user_id, kind]
    if quest_id:
        where.append("quest_id = ?")
        params.append(quest_id)
    if exam_id:
        where.append("exam_id = ?")
        params.append(exam_id)
    cur.execute(
        f"""
        SELECT data
        FROM solve_history
        WHERE {" AND ".join(where)}
        ORDER BY datetime(created_at) DESC
        LIMIT 1
        """,
        params,
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return False
    try:
        data = json.loads(row[0])
    except Exception:
        return False
    status_list = data.get("status")
    if not isinstance(status_list, list) or not status_list:
        return False
    try:
        return all((str(item.get("status")).upper() == "O") for item in status_list if isinstance(item, dict))
    except Exception:
        return False
