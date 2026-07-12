import json
import sqlite3
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

DB_PATH = str((Path(__file__).resolve().parent.parent / "textbook.db"))
PUBLIC_MANUAL_TEXTBOOK_ID = "public_manual_textbook"
TEACHER_MANUAL_TEXTBOOK_ID = "teacher_manual_default"
TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID = "teacher_problem_generation_manual"
TEACHER_MANUAL_TEXTBOOK_IDS = (
    TEACHER_MANUAL_TEXTBOOK_ID,
    TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,
)


def is_teacher_manual_textbook(textbook_id: Any) -> bool:
    return str(textbook_id or "").strip() in TEACHER_MANUAL_TEXTBOOK_IDS


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
    _ensure_public_manual_textbook(cur)
    _ensure_teacher_manual_textbook(cur)
    _ensure_teacher_problem_generation_manual_textbook(cur)
    conn.commit()
    conn.close()


def list_textbooks(
    category: Optional[str] = None,
    tag: Optional[str] = None,
    textbook_ids: Optional[List[str]] = None,
    include_teacher_manual: bool = False,
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
    if not include_teacher_manual:
        placeholders = ", ".join("?" for _ in TEACHER_MANUAL_TEXTBOOK_IDS)
        where_clauses.append(f"textbook_id NOT IN ({placeholders})")
        params.extend(TEACHER_MANUAL_TEXTBOOK_IDS)
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


def _ensure_public_manual_textbook(cur: sqlite3.Cursor) -> None:
    now_ms = int(time.time() * 1000)
    chapters = [
        {
            "title": "1. 교재 보기 시작하기",
            "intro": [
                "이 교재는 모든 사용자가 바로 열어볼 수 있는 공개 설명서 교재입니다.",
                "교재함, 목차, 본문, 북마크의 기본 동작을 확인할 수 있습니다.",
            ],
            "sections": [
                {
                    "title": "1-1. 교재함에서 열기",
                    "paragraphs": [
                        "학습터의 교재함을 열면 공개 교재와 내가 저장한 교재를 확인할 수 있습니다.",
                        "목록에서 교재를 누르면 본문 화면으로 이동하고, 목차를 통해 원하는 단원으로 이동합니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "1-2. 본문 읽기",
                    "paragraphs": [
                        "본문은 장, 절, 문단 순서로 정리되어 긴 설명도 끊어서 읽을 수 있습니다.",
                        "학습용 교재는 앱과 서버 DB에 저장된 구조를 그대로 불러와 표시합니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "1-3. 북마크 활용",
                    "paragraphs": [
                        "중요한 위치는 북마크로 저장해 다시 빠르게 돌아올 수 있습니다.",
                        "북마크 목록은 최근 저장한 항목부터 보여주며, 교재 제목과 단원명을 함께 표시합니다.",
                    ],
                    "images": [],
                },
            ],
        },
        {
            "title": "2. 공개 교재 정책",
            "intro": [
                "공개 설명서 교재는 기본 제공 자료이므로 별도 구매나 교사 배정 없이 열람할 수 있습니다.",
            ],
            "sections": [
                {
                    "title": "2-1. 공개 범위",
                    "paragraphs": [
                        "이 교재는 일반 교재 목록에 포함되며 학생과 교사가 모두 볼 수 있습니다.",
                        "교사용 내부 설명서처럼 숨김 처리되지 않고, 기본 교재로 자동 연결됩니다.",
                    ],
                    "images": [],
                }
            ],
        },
    ]
    cur.execute(
        """
        INSERT INTO textbooks (
            textbook_id, title, subtitle, category, tags, chapters, cover_color,
            created_at, updated_at, created_by
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(textbook_id) DO UPDATE SET
            title = excluded.title,
            subtitle = excluded.subtitle,
            category = excluded.category,
            tags = excluded.tags,
            chapters = excluded.chapters,
            cover_color = excluded.cover_color,
            updated_at = excluded.updated_at,
            created_by = excluded.created_by
        """,
        (
            PUBLIC_MANUAL_TEXTBOOK_ID,
            "교재 보기 사용 설명서",
            "교재함과 본문 읽기 기능을 확인하는 공개 설명서",
            "common",
            json.dumps(["설명서", "공개", "교재보기"], ensure_ascii=False),
            json.dumps(chapters, ensure_ascii=False),
            0xFF2D6A4F,
            now_ms,
            now_ms,
            "system",
        ),
    )


def _ensure_teacher_manual_textbook(cur: sqlite3.Cursor) -> None:
    now_ms = int(time.time() * 1000)
    chapters = [
        {
            "title": "1. 문서함 사용 설명",
            "intro": [
                "이 교재는 모든 교사가 공통으로 확인하는 설명서 기본 교재입니다.",
                "학생에게는 표시되지 않으며 코스 교재로 등록할 수 없습니다.",
            ],
            "sections": [
                {
                    "title": "1-1. 문서함",
                    "paragraphs": [
                        "문서함은 교사용 코스 생성에서 사용할 수 있는 교재와 안내 문서를 모아 보여줍니다.",
                        "설명서 기본 교재는 교사용 안내 전용이므로 학생 학습 화면에는 노출되지 않습니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "1-2. 권한 연결",
                    "paragraphs": [
                        "교재는 복사본을 만들지 않고 권한으로 연결합니다.",
                        "코스에는 학습용 교재만 등록할 수 있으며 설명서 기본 교재는 선택 목록에서 제외됩니다.",
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
        ON CONFLICT(textbook_id) DO UPDATE SET
            title = excluded.title,
            subtitle = excluded.subtitle,
            category = excluded.category,
            tags = excluded.tags,
            chapters = excluded.chapters,
            cover_color = excluded.cover_color,
            updated_at = excluded.updated_at,
            created_by = excluded.created_by
        """,
        (
            TEACHER_MANUAL_TEXTBOOK_ID,
            "설명서 기본 교재",
            "교사용 문서함과 코스 교재 권한 연결 안내",
            "설명서",
            json.dumps(["설명서", "교사용", "문서함"], ensure_ascii=False),
            json.dumps(chapters, ensure_ascii=False),
            0xFF1B402B,
            now_ms,
            now_ms,
            "system",
        ),
    )


def _ensure_teacher_problem_generation_manual_textbook(cur: sqlite3.Cursor) -> None:
    now_ms = int(time.time() * 1000)
    chapters = [
        {
            "title": "1. 문제 고급생성 시작",
            "intro": [
                "이 교재는 모든 교사가 문서함에서 열람하는 문제 생성 설명서입니다.",
                "간편 생성과 고급 생성의 차이, 캔버스 노드, 파라미터 반영 방식을 한곳에 정리합니다.",
            ],
            "sections": [
                {
                    "title": "1-1. 간편 생성과 고급 생성",
                    "paragraphs": [
                        "간편 생성은 상, 중, 하 선택값을 풀이 단계 수, 전략 난이도, 분기 수로 매핑합니다.",
                        "고급 생성은 풀이 논리 캔버스와 세부 난이도 지표를 함께 전달해 문제 구조 자체를 조정합니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "1-2. 참고문항 연결",
                    "paragraphs": [
                        "오른쪽 저장소 탭에서 문항을 검색해 참고문항으로 연결할 수 있습니다.",
                        "참고문항이 없으면 선택한 태그와 캔버스 설계를 바탕으로 신규 코드베이스 문항을 생성합니다.",
                    ],
                    "images": [],
                },
            ],
        },
        {
            "title": "2. 풀이 논리 캔버스 설계",
            "intro": [
                "캔버스는 문제를 만들기 전 풀이 흐름을 노드와 화살표로 정의하는 영역입니다.",
            ],
            "sections": [
                {
                    "title": "2-1. 노드 유형",
                    "paragraphs": [
                        "조건, 개념, 발상, 추론, 계산, 함정, 검증 노드를 추가해 출제 의도를 분리합니다.",
                        "각 노드의 제목, 풀이 논리, 세부 지시, 태그는 서버의 flow_draft에 포함됩니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "2-2. 연결 방향",
                    "paragraphs": [
                        "노드 연결은 풀이 그래프의 방향을 의미합니다.",
                        "분기와 병합을 만들고 싶다면 한 노드에서 여러 다음 노드로 연결하거나, 여러 노드를 검증 노드로 모읍니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "2-3. 노드별 태그와 지시",
                    "paragraphs": [
                        "노드 태그가 있으면 해당 노드의 태그를 우선 사용합니다.",
                        "세부 지시는 기본 프롬프트보다 우선 반영되므로 정의역 함정, 역추적 발상, 계산량 제한처럼 구체적으로 씁니다.",
                    ],
                    "images": [],
                },
            ],
        },
        {
            "title": "3. 파라미터 조정 기준",
            "intro": [
                "파라미터는 결과 설명용 메타데이터가 아니라 실제 조건, 풀이 길이, 함정, 계산량에 반영됩니다.",
            ],
            "sections": [
                {
                    "title": "3-1. 코드베이스 파라미터",
                    "paragraphs": [
                        "풀이 단계 수는 루트 풀이의 길이를 결정합니다. 값이 클수록 풀이 흐름이 길어집니다.",
                        "전략 난이도는 핵심 발상의 강도를 결정합니다. 1은 공식 적용, 3은 관점 전환 중심입니다.",
                        "분기 수는 케이스 분류와 병합 규모를 결정합니다. 0은 일직선 풀이, 2 이상은 분기형 풀이에 적합합니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "3-2. 세부 난이도 지표",
                    "paragraphs": [
                        "개념, 추론, 발상, 계산, 정보, 함정, 압축 지표는 고급 생성 프롬프트로 승격됩니다.",
                        "높은 값은 해당 요소를 실제 문제 구조에 늘리라는 지시가 되고, 낮은 값은 해당 부담을 줄이라는 지시가 됩니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "3-3. 예상 번호와 정답률",
                    "paragraphs": [
                        "예상 번호는 개념, 추론, 발상, 풀이 그래프 깊이, 분기 계수 조합으로 판정합니다.",
                        "상위권, 중위권, 하위권 예상 정답률은 발상 장벽과 함정 강도를 조절하는 참고 지표로 사용합니다.",
                    ],
                    "images": [],
                },
            ],
        },
        {
            "title": "4. 생성 후 검증",
            "intro": [
                "생성 결과는 문제, 정답, 모범 풀이, 풀이 그래프, 난이도 벡터, 출제 의도 순서로 확인합니다.",
            ],
            "sections": [
                {
                    "title": "4-1. 캔버스 반영 확인",
                    "paragraphs": [
                        "결과의 풀이 그래프가 캔버스 노드 연결과 같은 방향인지 확인합니다.",
                        "노드별 세부 지시가 조건, 발상, 검증 단계 중 어디에 반영됐는지 확인합니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "4-2. 파라미터 반영 확인",
                    "paragraphs": [
                        "풀이 단계 수를 늘렸다면 모범 풀이 단계가 충분히 늘어났는지 확인합니다.",
                        "함정, 조건 밀도, 계산량 같은 지표를 크게 바꿨다면 문제 문장과 풀이 부담이 함께 변해야 합니다.",
                    ],
                    "images": [],
                },
                {
                    "title": "4-3. 병목 줄이기",
                    "paragraphs": [
                        "이미 검증된 코드베이스와 cached seed가 있으면 서버는 가장 가까운 런타임 파라미터를 우선 사용해 대기 시간을 줄입니다.",
                        "생성이 느릴 때는 태그 수와 분기 수를 먼저 줄이고, 같은 태그 조합으로 다시 시도하면 캐시 활용 가능성이 높아집니다.",
                    ],
                    "images": [],
                },
            ],
        },
    ]
    cur.execute(
        """
        INSERT INTO textbooks (
            textbook_id, title, subtitle, category, tags, chapters, cover_color,
            created_at, updated_at, created_by
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(textbook_id) DO UPDATE SET
            title = excluded.title,
            subtitle = excluded.subtitle,
            category = excluded.category,
            tags = excluded.tags,
            chapters = excluded.chapters,
            cover_color = excluded.cover_color,
            updated_at = excluded.updated_at,
            created_by = excluded.created_by
        """,
        (
            TEACHER_PROBLEM_GENERATION_MANUAL_TEXTBOOK_ID,
            "문제 생성 설명서",
            "고급 생성 캔버스와 난이도 파라미터 운용 안내",
            "설명서",
            json.dumps(["설명서", "교사용", "문제생성", "고급생성"], ensure_ascii=False),
            json.dumps(chapters, ensure_ascii=False),
            0xFF214A73,
            now_ms,
            now_ms,
            "system",
        ),
    )
