"""UTF-8 PostgreSQL 스키마 마이그레이션 적용기."""
from __future__ import annotations

import argparse
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MIGRATION_DIR = ROOT / "migrations" / "postgres"


def _migration_files() -> list[Path]:
    """필요 변수: PostgreSQL 마이그레이션 디렉터리. 작동 원리: UTF-8 SQL 파일을 파일명 순서로 정렬해 반환한다."""
    files = sorted(MIGRATION_DIR.glob("*.sql"))
    if not files:
        raise RuntimeError("PostgreSQL migration files are missing")
    return files


def apply_migrations(*, dry_run: bool) -> list[str]:
    """필요 변수: DATABASE_URL·UTF-8 SQL 파일·dry-run 여부. 작동 원리: 모든 파일을 한 트랜잭션에서 순서대로 적용하고 실패 시 전체를 되돌린다."""
    files = _migration_files()
    if dry_run:
        return [path.name for path in files]
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required")
    import psycopg

    with psycopg.connect(database_url) as conn:
        with conn.transaction():
            with conn.cursor() as cur:
                for path in files:
                    cur.execute(path.read_text(encoding="utf-8"))
    return [path.name for path in files]


def main() -> None:
    """필요 변수: `--dry-run` 선택값. 작동 원리: 적용 대상 또는 실제 적용 완료 파일을 한 줄씩 출력한다."""
    parser = argparse.ArgumentParser(description="PostgreSQL UTF-8 스키마 마이그레이션 적용")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    action = "대상" if args.dry_run else "적용"
    for name in apply_migrations(dry_run=args.dry_run):
        print(f"{action}: {name}")


if __name__ == "__main__":
    main()
