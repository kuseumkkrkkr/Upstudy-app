"""UTF-8 SQLite 서버 데이터를 PostgreSQL 이관 스테이징 스키마로 안전하게 복제한다."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
from pathlib import Path
from typing import Any

from psycopg import sql
from psycopg.rows import tuple_row


ROOT = Path(__file__).resolve().parents[1]
SOURCES = {"quests": ROOT / "quests.db", "codebases": ROOT / "codebases.db", "textbook": ROOT / "textbook.db"}
SCHEMA = "sqlite_staging"


def _pg_type(sqlite_type: str) -> str:
    """필요 변수: SQLite 선언 타입. 작동 원리: 값 손실 없이 PostgreSQL의 넓은 호환 타입으로 변환한다."""
    normalized = sqlite_type.upper()
    if "INT" in normalized:
        return "BIGINT"
    if any(token in normalized for token in ("REAL", "FLOA", "DOUB")):
        return "DOUBLE PRECISION"
    if any(token in normalized for token in ("NUM", "DEC")):
        return "NUMERIC"
    if "BLOB" in normalized:
        return "BYTEA"
    return "TEXT"


def _json_value(value: Any) -> Any:
    """필요 변수: SQLite·PostgreSQL 셀 값. 작동 원리: 이진값을 hex 표식으로 정규화해 양쪽 행 해시를 비교한다."""
    if isinstance(value, bytes):
        return {"__bytes__": value.hex()}
    return value


def _rows_digest(rows: list[tuple[Any, ...]]) -> str:
    """필요 변수: 테이블 전체 행. 작동 원리: 행 순서와 무관하게 UTF-8 정규화 JSON을 정렬·해시해 이관 손실을 탐지한다."""
    serialized = sorted(
        json.dumps([_json_value(value) for value in row], ensure_ascii=False, default=str, separators=(",", ":"))
        for row in rows
    )
    return hashlib.sha256("\n".join(serialized).encode("utf-8")).hexdigest()


def _source_tables(conn: sqlite3.Connection) -> list[str]:
    """필요 변수: SQLite 연결. 작동 원리: 내부 sqlite_ 테이블을 제외한 실제 애플리케이션 테이블만 반환한다."""
    return [row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]


def _target_name(source_key: str, table: str) -> str:
    """필요 변수: 원본 DB 별칭·테이블명. 작동 원리: 서로 같은 테이블명을 가진 DB도 충돌 없이 보존한다."""
    return f"{source_key}__{table}"


def _create_target_table(cur: Any, source_key: str, table: str, source: sqlite3.Connection) -> None:
    """필요 변수: PostgreSQL 커서·SQLite 테이블 메타데이터. 작동 원리: 열·복합 PK·고유키를 보존한 스테이징 테이블을 생성한다."""
    columns = source.execute(f'PRAGMA table_info("{table}")').fetchall()
    if not columns:
        raise RuntimeError(f"SQLite table definition is missing: {source_key}.{table}")
    names = [str(row[1]) for row in columns]
    pk_columns = [str(row[1]) for row in sorted(columns, key=lambda row: int(row[5] or 0)) if int(row[5] or 0)]
    parts = [sql.SQL("{} {}").format(sql.Identifier(str(row[1])), sql.SQL(_pg_type(str(row[2] or "")))) for row in columns]
    if pk_columns:
        parts.append(sql.SQL("PRIMARY KEY ({})").format(sql.SQL(", ").join(map(sql.Identifier, pk_columns))))
    cur.execute(sql.SQL("CREATE TABLE {}.{} ({})").format(sql.Identifier(SCHEMA), sql.Identifier(_target_name(source_key, table)), sql.SQL(", ").join(parts)))
    for index in source.execute(f'PRAGMA index_list("{table}")').fetchall():
        if not bool(index[2]) or str(index[3]) == "pk":
            continue
        index_columns = [str(row[2]) for row in source.execute(f'PRAGMA index_info("{index[1]}")').fetchall()]
        if not index_columns:
            continue
        index_name = f"uq_{source_key}_{table}_{index[0]}"[:60]
        cur.execute(sql.SQL("CREATE UNIQUE INDEX {} ON {}.{} ({})").format(sql.Identifier(index_name), sql.Identifier(SCHEMA), sql.Identifier(_target_name(source_key, table)), sql.SQL(", ").join(map(sql.Identifier, index_columns))))


def stage_source(cur: Any, source_key: str, source_path: Path) -> list[dict[str, Any]]:
    """필요 변수: 열린 PostgreSQL 트랜잭션·SQLite DB. 작동 원리: 원본을 읽기 전용으로 열어 각 테이블을 복제하고 행 수·내용 해시를 즉시 대조한다."""
    if not source_path.exists():
        raise RuntimeError(f"SQLite source does not exist: {source_path}")
    source = sqlite3.connect(f"file:{source_path.as_posix()}?mode=ro", uri=True)
    reports: list[dict[str, Any]] = []
    try:
        for table in _source_tables(source):
            target = _target_name(source_key, table)
            _create_target_table(cur, source_key, table, source)
            columns = [str(row[1]) for row in source.execute(f'PRAGMA table_info("{table}")').fetchall()]
            rows = source.execute(f'SELECT * FROM "{table}"').fetchall()
            if rows:
                statement = sql.SQL("INSERT INTO {}.{} ({}) VALUES ({})").format(
                    sql.Identifier(SCHEMA), sql.Identifier(target), sql.SQL(", ").join(map(sql.Identifier, columns)), sql.SQL(", ").join(sql.Placeholder() for _ in columns)
                )
                cur.executemany(statement, rows)
            cur.execute(sql.SQL("SELECT * FROM {}.{}").format(sql.Identifier(SCHEMA), sql.Identifier(target)))
            target_rows = cur.fetchall()
            report = {"source": source_key, "table": table, "target": target, "source_count": len(rows), "target_count": len(target_rows), "source_digest": _rows_digest(rows), "target_digest": _rows_digest(target_rows)}
            if report["source_count"] != report["target_count"] or report["source_digest"] != report["target_digest"]:
                raise RuntimeError(f"staging verification failed: {report}")
            reports.append(report)
    finally:
        source.close()
    return reports


def stage(*, apply: bool) -> list[dict[str, Any]]:
    """필요 변수: 실제 적용 승인. 작동 원리: 기본은 원본 테이블 목록만 반환하며 --apply에서만 새 스테이징 스키마를 만든다."""
    source_reports: list[dict[str, Any]] = []
    if not apply:
        for key, path in SOURCES.items():
            with sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True) as conn:
                source_reports.extend({"source": key, "table": table} for table in _source_tables(conn))
        return source_reports
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required")
    import psycopg
    with psycopg.connect(database_url, row_factory=tuple_row) as conn, conn.transaction(), conn.cursor() as cur:
        cur.execute(sql.SQL("CREATE SCHEMA {} ").format(sql.Identifier(SCHEMA)))
        for key, path in SOURCES.items():
            source_reports.extend(stage_source(cur, key, path))
        cur.execute("CREATE TABLE public.sqlite_staging_migration_audit (id BIGSERIAL PRIMARY KEY, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), report JSONB NOT NULL)")
        cur.execute("INSERT INTO public.sqlite_staging_migration_audit (report) VALUES (%s::jsonb)", (json.dumps(source_reports, ensure_ascii=False),))
    return source_reports


def main() -> None:
    """필요 변수: --apply. 작동 원리: 기본 모드는 대상 목록만 확인하고, 적용은 이미 존재하는 스테이징 스키마를 절대 덮어쓰지 않는다."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    report = stage(apply=args.apply)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
