"""운영 DB의 구형 레벨테스트 문제 템플릿을 제거하고 정적 DB 전환을 검증한다."""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from contextlib import closing
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from domain.level_test.static_store import DEFAULT_STATIC_DB_PATH, validate_static_database


LEGACY_TABLES = ("level_test_template_item", "level_test_template")


def _backup_database(source: Path, target: Path) -> None:
    """필요 변수: 운영 DB와 백업 경로. 작동 원리: SQLite 온라인 백업 API로 일관된 전환 직전 사본을 만든다."""
    with closing(sqlite3.connect(source)) as source_connection:
        with closing(sqlite3.connect(target)) as target_connection:
            source_connection.backup(target_connection)


def migrate(runtime_db: Path, static_db: Path, *, create_backup: bool = True) -> dict[str, Any]:
    """필요 변수: 운영 DB·정적 DB·백업 옵션. 작동 원리: 정적 DB가 완전할 때만 구형 문제 템플릿 두 테이블을 한 트랜잭션으로 제거한다."""
    runtime_path = runtime_db.resolve()
    static_path = static_db.resolve()
    os.environ["LEVEL_TEST_STATIC_DB_PATH"] = str(static_path)
    static_report = validate_static_database()
    backup_path = runtime_path.with_name(f"{runtime_path.name}.bak_before_level-test-static-v1")
    if create_backup:
        _backup_database(runtime_path, backup_path)

    with closing(sqlite3.connect(runtime_path)) as connection:
        existing_tables = {
            str(row[0])
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        before_operational = {
            table: int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])
            for table in ("level_test_session", "level_test_answer")
            if table in existing_tables
        }
        connection.execute("BEGIN IMMEDIATE")
        for table in LEGACY_TABLES:
            if table in existing_tables:
                connection.execute(f"DROP TABLE {table}")
        connection.commit()
        after_tables = {
            str(row[0])
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        after_operational = {
            table: int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])
            for table in before_operational
        }
        integrity = str(connection.execute("PRAGMA integrity_check").fetchone()[0])
    if before_operational != after_operational:
        raise RuntimeError("level-test operational history changed during static migration")
    if any(table in after_tables for table in LEGACY_TABLES) or integrity != "ok":
        raise RuntimeError("legacy level-test template cleanup failed")
    return {
        "runtime_db": str(runtime_path),
        "static_db": static_report,
        "backup_path": str(backup_path) if create_backup else None,
        "dropped_tables": [table for table in LEGACY_TABLES if table in existing_tables],
        "preserved_operational_rows": after_operational,
        "runtime_integrity_check": integrity,
    }


def main() -> None:
    """필요 변수: 운영·정적 DB 경로와 백업 옵션. 작동 원리: 안전 전환 결과를 UTF-8 JSON으로 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime-db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--static-db", type=Path, default=DEFAULT_STATIC_DB_PATH)
    parser.add_argument("--no-backup", action="store_true")
    args = parser.parse_args()
    report = migrate(
        args.runtime_db,
        args.static_db,
        create_backup=not args.no_backup,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
