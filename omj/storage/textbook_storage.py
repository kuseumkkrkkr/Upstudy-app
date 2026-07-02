import json
import sqlite3
import time
import uuid
from typing import Any, Dict, List, Optional

DB_PATH = "textbook.db"


def init_textbook_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS textbooks (
            textbook_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'custom',
            tags TEXT NOT NULL DEFAULT '[]',
            chapters TEXT NOT NULL,
            cover_color INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            created_by TEXT
        )
        """
    )
    conn.commit()
    _ensure_default_textbook(cur)
    conn.commit()
    conn.close()


def list_textbooks(
    category: Optional[str] = None,
    tag: Optional[str] = None,
    textbook_ids: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    params: List[Any] = []
    query = """
        SELECT textbook_id, title, subtitle, category, tags, chapters, cover_color,
               created_at, updated_at, created_by
        FROM textbooks
    """
    where_clauses: List[str] = []
    if category:
        where_clauses.append("category = ?")
        params.append(category)
    if textbook_ids:
        cleaned_ids = [item.strip() for item in textbook_ids if item and item.strip()]
        if cleaned_ids:
            placeholders = ", ".join("?" for _ in cleaned_ids)
            where_clauses.append(f"textbook_id IN ({placeholders})")
            params.extend(cleaned_ids)
    if where_clauses:
        query += " WHERE " + " AND ".join(where_clauses)
    query += " ORDER BY created_at DESC"
    cur.execute(query, params)
    rows = cur.fetchall()
    conn.close()

    textbooks = [_row_to_textbook(row) for row in rows]
    if tag:
        tag = tag.strip()
        if tag:
            textbooks = [
                book for book in textbooks if tag in (book.get("tags") or [])
            ]
    return textbooks


def get_textbook(textbook_id: str) -> Optional[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT textbook_id, title, subtitle, category, tags, chapters, cover_color,
               created_at, updated_at, created_by
        FROM textbooks
        WHERE textbook_id = ?
        """,
        (textbook_id,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return _row_to_textbook(row)


def create_textbook(payload: Dict[str, Any], created_by: str) -> Dict[str, Any]:
    title = (payload.get("title") or "").strip()
    if not title:
        raise ValueError("title is required")
    subtitle = (payload.get("subtitle") or "").strip()
    category = (payload.get("category") or "custom").strip() or "custom"
    tags = _normalize_string_list(payload.get("tags"))
    chapters = _normalize_chapters(payload.get("chapters"))
    cover_color = payload.get("cover_color")
    if isinstance(cover_color, str):
        try:
            cover_color = int(cover_color)
        except ValueError:
            cover_color = None
    if not isinstance(cover_color, int):
        cover_color = None

    textbook_id = payload.get("textbook_id") or str(uuid.uuid4())
    now_ms = int(time.time() * 1000)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO textbooks (
            textbook_id, title, subtitle, category, tags, chapters, cover_color,
            created_at, updated_at, created_by
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            textbook_id,
            title,
            subtitle,
            category,
            json.dumps(tags, ensure_ascii=False),
            json.dumps(chapters, ensure_ascii=False),
            cover_color,
            now_ms,
            now_ms,
            created_by,
        ),
    )
    conn.commit()
    conn.close()
    return get_textbook(textbook_id) or {}


def _row_to_textbook(row: sqlite3.Row | tuple) -> Dict[str, Any]:
    (
        textbook_id,
        title,
        subtitle,
        category,
        tags_raw,
        chapters_raw,
        cover_color,
        created_at,
        updated_at,
        created_by,
    ) = row
    tags = _normalize_string_list(tags_raw)
    chapters = _normalize_chapters(chapters_raw)
    return {
        "textbook_id": textbook_id,
        "title": title,
        "subtitle": subtitle,
        "category": category,
        "tags": tags,
        "chapters": chapters,
        "cover_color": cover_color,
        "created_at": created_at,
        "updated_at": updated_at,
        "created_by": created_by,
    }


def _normalize_chapters(value: Any) -> List[Dict[str, Any]]:
    if value is None:
        return []
    if isinstance(value, str):
        value = value.strip()
        if not value:
            return []
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return []
    if not isinstance(value, list):
        return []
    chapters: List[Dict[str, Any]] = []
    for entry in value:
        if not isinstance(entry, dict):
            continue
        title = str(entry.get("title") or "").strip()
        intro = _normalize_string_list(entry.get("intro"))
        sections = _normalize_sections(entry.get("sections"))
        chapters.append(
            {
                "title": title,
                "intro": intro,
                "sections": sections,
            }
        )
    return chapters


def _normalize_sections(value: Any) -> List[Dict[str, Any]]:
    if value is None:
        return []
    if isinstance(value, str):
        value = value.strip()
        if not value:
            return []
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return []
    if not isinstance(value, list):
        return []
    sections: List[Dict[str, Any]] = []
    for entry in value:
        if not isinstance(entry, dict):
            continue
        title = str(entry.get("title") or "").strip()
        paragraphs = _normalize_string_list(entry.get("paragraphs"))
        images = _normalize_string_list(entry.get("images"))
        sections.append(
            {
                "title": title,
                "paragraphs": paragraphs,
                "images": images,
            }
        )
    return sections


def _normalize_string_list(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, str):
        value = value.strip()
        if not value:
            return []
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return [value]
    if isinstance(value, list):
        return [str(entry).strip() for entry in value if str(entry).strip()]
    return [str(value).strip()]


def _ensure_default_textbook(cur: sqlite3.Cursor) -> None:
    cur.execute("SELECT COUNT(*) FROM textbooks")
    row = cur.fetchone()
    if row and row[0] > 0:
        return
    now_ms = int(time.time() * 1000)
    chapters = [
        {
            "title": "1. 교재 사용법",
            "intro": [
                "이 교재는 테스트용 더미입니다.",
                "실제 교재는 서버의 textbook.db에서 불러옵니다.",
            ],
            "sections": [
                {
                    "title": "1-1. 교재 보기",
                    "paragraphs": [
                        "학습 모달에서 교재보기를 누르면 교재 목록이 열립니다.",
                        "목차에서 대제목/소주제를 선택해 빠르게 이동할 수 있습니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "1-2. 교재 만들기",
                    "paragraphs": [
                        "학습터에서 교재 만들기를 선택하면 직접 집필 에디터가 열립니다.",
                        "대제목과 소주제를 추가하고 소주제 단위로 내용을 입력하세요.",
                    ],
                    "images": [],
                },
                {
                    "title": "1-3. 이미지 추가",
                    "paragraphs": [
                        "소주제 하단에 이미지 URL을 추가하면 본문에 표시됩니다.",
                        "예: https://... 또는 /assets/... 형식을 사용할 수 있습니다.",
                    ],
                    "images": [],
                },
            ],
        }
    ]
    cur.execute(
        """
        INSERT INTO textbooks (
            textbook_id, title, subtitle, category, tags, chapters, cover_color,
            created_at, updated_at, created_by
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            "test_textbook",
            "테스트 교재",
            "교재 사용법 안내",
            "common",
            json.dumps(["테스트", "안내"], ensure_ascii=False),
            json.dumps(chapters, ensure_ascii=False),
            0xFF1B402B,
            now_ms,
            now_ms,
            "system",
        ),
    )
