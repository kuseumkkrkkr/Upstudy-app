"""검수된 placement 정적 DB를 PostgreSQL 레벨테스트 테이블로 이관한다."""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

from psycopg.types.json import Jsonb

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from domain.level_test.static_store import DEFAULT_STATIC_DB_PATH


def migrate(source: Path) -> dict[str, int]:
    """필요 변수: UTF-8 JSON을 담은 원본 SQLite와 DATABASE_URL.
    작동 원리: 문제 payload를 먼저 UPSERT한 뒤 폼·슬롯을 PostgreSQL 한 트랜잭션에 저장한다.
    """
    if not source.is_file():
        raise FileNotFoundError(f"source static DB is missing: {source}")
    import psycopg

    with sqlite3.connect(f"file:{source.resolve().as_posix()}?mode=ro", uri=True) as sqlite:
        sqlite.row_factory = sqlite3.Row
        problems = [dict(row) for row in sqlite.execute("SELECT * FROM problem WHERE active=1")]
        templates = [dict(row) for row in sqlite.execute("SELECT * FROM template WHERE active=1 ORDER BY form_index")]
        items = [dict(row) for row in sqlite.execute("SELECT * FROM template_item ORDER BY template_id, item_index")]

    database_url = __import__("os").environ.get("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required")
    with psycopg.connect(database_url) as connection:
        with connection.transaction(), connection.cursor() as cursor:
            for row in problems:
                payload = json.loads(row["payload_json"])
                info = payload.get("info") or {}
                cursor.execute(
                    """INSERT INTO problem_payload
                       (quest_id, difficulty_tier, difficulty_score, quality_status, tags, payload)
                       VALUES (%s, %s, %s, 'approved', %s, %s)
                       ON CONFLICT (quest_id) DO UPDATE SET
                         difficulty_tier=EXCLUDED.difficulty_tier,
                         difficulty_score=EXCLUDED.difficulty_score,
                         quality_status=EXCLUDED.quality_status,
                         tags=EXCLUDED.tags, payload=EXCLUDED.payload, updated_at=NOW()""",
                    (row["quest_id"], int(row["difficulty_tier"]), max(1, int(float(row["problem_rating"]))),
                     Jsonb(info.get("hash_tag") or []), Jsonb(payload)),
                )
            for row in templates:
                cursor.execute(
                    """INSERT INTO level_test_template(template_id, version, form_index, active, created_at)
                       VALUES (%s, %s, %s, %s, %s)
                       ON CONFLICT (template_id) DO UPDATE SET version=EXCLUDED.version,
                         form_index=EXCLUDED.form_index, active=EXCLUDED.active""",
                    (row["template_id"], row["version"], row["form_index"], bool(row["active"]), row["created_at"]),
                )
            for row in items:
                cursor.execute(
                    """INSERT INTO level_test_template_item
                       (template_id, item_index, phase, subject_key, hash_tags, difficulty_tier, quest_id, problem_rating)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                       ON CONFLICT (template_id, item_index) DO UPDATE SET
                         phase=EXCLUDED.phase, subject_key=EXCLUDED.subject_key, hash_tags=EXCLUDED.hash_tags,
                         difficulty_tier=EXCLUDED.difficulty_tier, quest_id=EXCLUDED.quest_id,
                         problem_rating=EXCLUDED.problem_rating""",
                    (row["template_id"], row["item_index"], row["phase"], row["subject_key"],
                     Jsonb(json.loads(row["hash_tags_json"])), row["difficulty_tier"], row["quest_id"], row["problem_rating"]),
                )
    return {"problems": len(problems), "templates": len(templates), "items": len(items)}


def main() -> None:
    """필요 변수: 선택적 --source 경로. 작동 원리: 검증된 원본을 PostgreSQL로 이관하고 건수를 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_STATIC_DB_PATH)
    args = parser.parse_args()
    print(json.dumps(migrate(args.source), ensure_ascii=False))


if __name__ == "__main__":
    main()
