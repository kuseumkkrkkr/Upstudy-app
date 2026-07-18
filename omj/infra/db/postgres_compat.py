"""기존 동기 저장소를 PostgreSQL 연결 풀로 옮기기 위한 최소 DB-API 호환 계층."""
from __future__ import annotations

import re
from collections.abc import Iterator, Mapping
from typing import Any, Optional

from psycopg import IntegrityError, OperationalError

from storage.postgres_problem_store import postgres_problem_store


class Row(Mapping[str, Any]):
    """필요 변수: 컬럼명 목록과 튜플 행.
    작동 원리: 기존 숫자 인덱스 접근과 PostgreSQL식 컬럼명 접근을 동시에 제공한다.
    """

    def __init__(self, columns: list[str], values: tuple[Any, ...]) -> None:
        self._columns = columns
        self._values = values
        self._mapping = dict(zip(columns, values))

    def __getitem__(self, key: str | int) -> Any:
        if isinstance(key, int):
            return self._values[key]
        return self._mapping[key]

    def __iter__(self) -> Iterator[str]:
        return iter(self._columns)

    def __len__(self) -> int:
        return len(self._columns)


def _translate_sql(sql: str) -> tuple[str, Optional[str]]:
    """필요 변수: 기존 쿼리 문자열.
    작동 원리: 제한된 레거시 placeholder·시간 함수·PRAGMA를 PostgreSQL 문법으로 바꾼다.
    """
    stripped = sql.strip()
    table_info = re.fullmatch(
        r"PRAGMA\s+table_info\(([^)]+)\)", stripped, flags=re.IGNORECASE
    )
    if table_info:
        return (
            """
            SELECT ordinal_position - 1 AS cid, column_name, data_type,
                   CASE WHEN is_nullable = 'NO' THEN 1 ELSE 0 END AS notnull,
                   column_default, 0 AS pk
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position
            """,
            table_info.group(1).strip().strip("'\""),
        )
    if re.fullmatch(r"PRAGMA\s+(journal_mode|synchronous|foreign_keys)(\s*=.*)?", stripped, re.IGNORECASE):
        return "SELECT 1", None

    translated = sql.replace("strftime('%s','now')", "EXTRACT(EPOCH FROM NOW())::BIGINT")
    translated = translated.replace('strftime("%s","now")', "EXTRACT(EPOCH FROM NOW())::BIGINT")
    translated = re.sub(
        r"\bid\s+INTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT\b",
        "id BIGSERIAL PRIMARY KEY",
        translated,
        flags=re.IGNORECASE,
    )
    insert_or_ignore = re.match(
        r"(\s*)INSERT\s+OR\s+IGNORE\s+INTO\s+", translated, flags=re.IGNORECASE
    )
    if insert_or_ignore:
        translated = re.sub(
            r"INSERT\s+OR\s+IGNORE\s+INTO\s+",
            "INSERT INTO ",
            translated,
            count=1,
            flags=re.IGNORECASE,
        ).rstrip().rstrip(";") + " ON CONFLICT DO NOTHING"
    translated = re.sub(
        r"\bdatetime\(([A-Za-z_][A-Za-z0-9_.]*)\)",
        r"(\1)::timestamptz",
        translated,
        flags=re.IGNORECASE,
    )
    if "?" in translated:
        translated = translated.replace("?", "%s")
    if isinstance(sql, str) and re.search(r"(?<!:):[A-Za-z_][A-Za-z0-9_]*", translated):
        translated = re.sub(
            r"(?<!:):([A-Za-z_][A-Za-z0-9_]*)", r"%(\1)s", translated
        )
    return translated, None


class Cursor:
    """필요 변수: psycopg 커서. 작동 원리: SQL 변환 후 결과 행을 호환 Row로 감싼다."""

    def __init__(self, cursor: Any) -> None:
        self._cursor = cursor

    @property
    def rowcount(self) -> int:
        return self._cursor.rowcount

    @property
    def description(self) -> Any:
        return self._cursor.description

    def execute(self, sql: str, params: Any = None) -> "Cursor":
        translated, pragma_table = _translate_sql(sql)
        actual_params = (pragma_table,) if pragma_table is not None else params
        self._cursor.execute(translated, actual_params)
        return self

    def executemany(self, sql: str, params_seq: Any) -> "Cursor":
        translated, _ = _translate_sql(sql)
        self._cursor.executemany(translated, params_seq)
        return self

    def _wrap(self, values: Any) -> Optional[Row]:
        if values is None:
            return None
        columns = [str(column.name) for column in (self._cursor.description or [])]
        return Row(columns, tuple(values))

    def fetchone(self) -> Optional[Row]:
        return self._wrap(self._cursor.fetchone())

    def fetchall(self) -> list[Row]:
        return [row for value in self._cursor.fetchall() if (row := self._wrap(value)) is not None]

    def close(self) -> None:
        self._cursor.close()


class Connection:
    """필요 변수: PostgreSQL 풀 연결 컨텍스트.
    작동 원리: 기존 connect/commit/cursor 사용법을 유지하면서 풀에 연결을 반환한다.
    """

    def __init__(self) -> None:
        self._context = postgres_problem_store.get_pool().connection()
        self._connection = self._context.__enter__()
        self.row_factory: Any = None
        self._closed = False

    def cursor(self) -> Cursor:
        return Cursor(self._connection.cursor())

    def execute(self, sql: str, params: Any = None) -> Cursor:
        return self.cursor().execute(sql, params)

    def commit(self) -> None:
        self._connection.commit()

    def rollback(self) -> None:
        self._connection.rollback()

    def close(self) -> None:
        if self._closed:
            return
        self._context.__exit__(None, None, None)
        self._closed = True

    def __enter__(self) -> "Connection":
        return self

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> None:
        if self._closed:
            return
        self._context.__exit__(exc_type, exc, traceback)
        self._closed = True


def connect(_legacy_path: Any = None, **_kwargs: Any) -> Connection:
    """필요 변수: DATABASE_URL.
    작동 원리: 과거 경로 인자는 무시하고 공유 PostgreSQL 연결 풀만 사용한다.
    """
    return Connection()
