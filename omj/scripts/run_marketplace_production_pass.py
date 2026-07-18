from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.seed_marketplace_inventory import seed_inventory
from scripts.seed_marketplace_original_problems import seed_database as seed_v1
from scripts.seed_marketplace_original_problems_v2 import seed_database as seed_v2
from scripts.seed_marketplace_original_problems_v3 import seed_database as seed_v3
from scripts.seed_marketplace_original_problems_v4 import seed_database as seed_v4
from scripts.seed_marketplace_original_problems_v5 import seed_database as seed_v5
from scripts.seed_marketplace_original_problems_v6 import seed_database as seed_v6
from scripts.seed_marketplace_original_problems_v7 import seed_database as seed_v7
from scripts.seed_marketplace_original_problems_v8 import seed_database as seed_v8
from scripts.seed_marketplace_original_problems_v9 import seed_database as seed_v9
from scripts.seed_marketplace_original_problems_v10 import seed_database as seed_v10
from scripts.seed_marketplace_original_problems_v11 import seed_database as seed_v11
from scripts.seed_marketplace_original_problems_v12 import seed_database as seed_v12
from scripts.seed_marketplace_original_problems_v13 import seed_database as seed_v13
from scripts.seed_marketplace_original_problems_v14 import seed_database as seed_v14
from scripts.seed_marketplace_original_problems_v15 import seed_database as seed_v15
from scripts.seed_marketplace_original_problems_v16 import seed_database as seed_v16
from scripts.seed_marketplace_original_problems_v17 import seed_database as seed_v17


def run_production_pass(
    db_path: Path,
    *,
    sync_postgres: bool,
    validate_only: bool,
) -> dict[str, Any]:
    """필요 변수는 로컬 문제 DB·운영 동기화 여부·검증 모드다. 작동 원리는 직접 출제 배치를 순서대로 멱등 저장하고 마켓 원장을 갱신한 뒤 선택적으로 PostgreSQL에 엄격 동기화하는 것이다."""
    resolved = db_path.resolve()
    report: dict[str, Any] = {
        "problem_batches": [
            seed_v1(resolved, validate_only=validate_only),
            seed_v2(resolved, validate_only=validate_only),
            seed_v3(resolved, validate_only=validate_only),
            seed_v4(resolved, validate_only=validate_only),
            seed_v5(resolved, validate_only=validate_only),
            seed_v6(resolved, validate_only=validate_only),
            seed_v7(resolved, validate_only=validate_only),
            seed_v8(resolved, validate_only=validate_only),
            seed_v9(resolved, validate_only=validate_only),
            seed_v10(resolved, validate_only=validate_only),
            seed_v11(resolved, validate_only=validate_only),
            seed_v12(resolved, validate_only=validate_only),
            seed_v13(resolved, validate_only=validate_only),
            seed_v14(resolved, validate_only=validate_only),
            seed_v15(resolved, validate_only=validate_only),
            seed_v16(resolved, validate_only=validate_only),
            seed_v17(resolved, validate_only=validate_only),
        ],
        "local_inventory": seed_inventory(
            resolved,
            backend="sqlite",
            validate_only=validate_only,
        ),
    }
    if sync_postgres:
        report["postgres_inventory"] = seed_inventory(
            resolved,
            backend="postgres",
            validate_only=validate_only,
        )
    return report


def main() -> None:
    """필요 변수는 DB 경로·동기화·검증 옵션이다. 작동 원리는 한 번의 UTF-8 명령으로 현재 직접 생산 배치 전체를 반복 가능하게 실행하는 것이다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--sync-postgres", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    report = run_production_pass(
        args.db,
        sync_postgres=args.sync_postgres,
        validate_only=args.validate_only,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
