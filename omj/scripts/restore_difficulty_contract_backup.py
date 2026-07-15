from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.migrate_difficulty_contract_v2 import _backup_pair, _restore_pair


def _quick_check(database: Path) -> None:
    """필요 변수: SQLite 경로. 작동 원리: 복원 전후 DB 페이지 무결성을 검사해 손상된 백업 적용을 차단한다."""
    connection = sqlite3.connect(database)
    try:
        result = connection.execute("PRAGMA quick_check").fetchone()
    finally:
        connection.close()
    if not result or result[0] != "ok":
        raise RuntimeError(f"SQLite quick_check failed: {database}: {result}")


def main() -> None:
    """필요 변수: 문제·코드베이스 백업과 복원 대상. 작동 원리: 현 상태를 다시 백업한 뒤 두 DB를 한 세트로 복원하고 무결성을 확인한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--quest-backup", type=Path, required=True)
    parser.add_argument("--codebase-backup", type=Path, required=True)
    parser.add_argument("--quest-target", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--codebase-target", type=Path, default=ROOT / "codebases.db")
    parser.add_argument(
        "--safety-backup-dir",
        type=Path,
        default=ROOT / "data" / "migration_backups" / "before_restore",
    )
    args = parser.parse_args()
    for database in (args.quest_backup, args.codebase_backup):
        if not database.is_file():
            raise FileNotFoundError(database)
        _quick_check(database)
    safety = _backup_pair(args.quest_target, args.codebase_target, args.safety_backup_dir)
    _restore_pair(
        {"quests": args.quest_backup, "codebases": args.codebase_backup},
        args.quest_target,
        args.codebase_target,
    )
    _quick_check(args.quest_target)
    _quick_check(args.codebase_target)
    print(
        json.dumps(
            {
                "restored": {
                    "quests": str(args.quest_target.resolve()),
                    "codebases": str(args.codebase_target.resolve()),
                },
                "safety_backups": {key: str(path.resolve()) for key, path in safety.items()},
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
