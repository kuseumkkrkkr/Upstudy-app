from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from domain.marketplace import repository
from scripts.seed_marketplace_original_problems import build_catalog, validate_catalog
from scripts.seed_marketplace_original_problems_v2 import (
    build_catalog as build_catalog_v2,
    validate_catalog as validate_catalog_v2,
)
from scripts.seed_marketplace_original_problems_v3 import validated_quests
from scripts.seed_marketplace_original_problems_v4 import validated_quests as validated_quests_v4
from scripts.seed_marketplace_original_problems_v5 import validated_quests as validated_quests_v5
from scripts.seed_marketplace_original_problems_v6 import validated_quests as validated_quests_v6
from scripts.seed_marketplace_original_problems_v7 import validated_quests as validated_quests_v7
from scripts.seed_marketplace_original_problems_v8 import validated_quests as validated_quests_v8
from scripts.seed_marketplace_original_problems_v9 import validated_quests as validated_quests_v9
from scripts.seed_marketplace_original_problems_v10 import validated_quests as validated_quests_v10
from scripts.seed_marketplace_original_problems_v11 import validated_quests as validated_quests_v11
from scripts.seed_marketplace_original_problems_v12 import validated_quests as validated_quests_v12
from scripts.seed_marketplace_original_problems_v13 import validated_quests as validated_quests_v13
from scripts.seed_marketplace_original_problems_v14 import validated_quests as validated_quests_v14
from scripts.seed_marketplace_original_problems_v15 import validated_quests as validated_quests_v15
from scripts.seed_marketplace_original_problems_v16 import validated_quests as validated_quests_v16
from scripts.seed_marketplace_original_problems_v17 import validated_quests as validated_quests_v17
from scripts.seed_marketplace_original_problems_v18 import validated_quests as validated_quests_v18
from scripts.seed_marketplace_original_problems_v19 import validated_quests as validated_quests_v19
from scripts.seed_marketplace_original_problems_v20 import validated_quests as validated_quests_v20
from scripts.seed_marketplace_original_problems_v21 import validated_quests as validated_quests_v21
from scripts.seed_marketplace_original_problems_v22 import validated_quests as validated_quests_v22
from scripts.seed_marketplace_original_problems_v23 import validated_quests as validated_quests_v23
from scripts.seed_marketplace_original_problems_v24 import validated_quests as validated_quests_v24
from scripts.seed_marketplace_original_problems_v25 import validated_quests as validated_quests_v25
from scripts.seed_marketplace_original_problems_v26 import validated_quests as validated_quests_v26
from scripts.seed_marketplace_original_problems_v27 import validated_quests as validated_quests_v27
from scripts.seed_marketplace_original_problems_v28 import validated_quests as validated_quests_v28
from scripts.seed_marketplace_original_problems_v29 import validated_quests as validated_quests_v29
from scripts.seed_marketplace_original_problems_v30 import validated_quests as validated_quests_v30
from scripts.seed_marketplace_original_problems_v31 import validated_quests as validated_quests_v31
from scripts.seed_marketplace_original_problems_v32 import validated_quests as validated_quests_v32
from scripts.seed_marketplace_original_problems_v33 import validated_quests as validated_quests_v33
from scripts.seed_marketplace_original_problems_v34 import validated_quests as validated_quests_v34
from scripts.seed_marketplace_original_problems_v35 import validated_quests as validated_quests_v35
from scripts.seed_marketplace_original_problems_v36 import validated_quests as validated_quests_v36
from scripts.seed_marketplace_original_problems_v37 import validated_quests as validated_quests_v37
from scripts.seed_marketplace_original_problems_v38 import validated_quests as validated_quests_v38
from scripts.seed_marketplace_original_problems_v39 import validated_quests as validated_quests_v39
from scripts.seed_marketplace_original_problems_v40 import validated_quests as validated_quests_v40
from scripts.seed_marketplace_original_problems_v41 import validated_quests as validated_quests_v41
from scripts.seed_marketplace_original_problems_v42 import validated_quests as validated_quests_v42
from scripts.seed_marketplace_original_problems_v43 import validated_quests as validated_quests_v43
from scripts.seed_marketplace_original_problems_v44 import validated_quests as validated_quests_v44
from scripts.seed_marketplace_original_problems_v45 import validated_quests as validated_quests_v45
from scripts.seed_marketplace_original_problems_v46 import validated_quests as validated_quests_v46
from scripts.seed_marketplace_original_problems_v47 import validated_quests as validated_quests_v47
from scripts.seed_marketplace_original_problems_v48 import validated_quests as validated_quests_v48
from scripts.seed_marketplace_original_problems_v49 import validated_quests as validated_quests_v49
from scripts.seed_marketplace_original_problems_v50 import validated_quests as validated_quests_v50
from scripts.seed_marketplace_original_problems_v51 import validated_quests as validated_quests_v51
from scripts.seed_marketplace_original_problems_v52 import validated_quests as validated_quests_v52
from scripts.seed_marketplace_original_problems_v53 import validated_quests as validated_quests_v53
from scripts.seed_marketplace_original_problems_v54 import validated_quests as validated_quests_v54
from scripts.seed_marketplace_original_problems_v55 import validated_quests as validated_quests_v55
from scripts.seed_marketplace_original_problems_v56 import validated_quests as validated_quests_v56
from scripts.seed_marketplace_original_problems_v57 import validated_quests as validated_quests_v57
from scripts.seed_marketplace_original_problems_v58 import validated_quests as validated_quests_v58
from scripts.seed_marketplace_original_problems_v59 import validated_quests as validated_quests_v59


def _sample_listing(listing_id: str, kind: str, title: str) -> dict:
    """필요 변수는 목록 ID·코너·제목이다. 작동 원리는 저장소 필터 테스트에 필요한 최소 공개 상품을 만든다."""
    return {
        "id": listing_id,
        "kind": kind,
        "title": title,
        "description": f"{title} 설명",
        "subject": "수학",
        "grade_band": "고1",
        "difficulty": "기본",
        "item_count": 5,
        "estimated_minutes": 20,
        "price_points": 0,
        "asset_id": "",
        "tags": ["#테스트"],
        "problem_ids": ["quest-1"],
        "payload": {"batch_id": "test"},
        "status": "published",
        "featured_rank": 1,
    }


class MarketplaceInventoryTest(unittest.TestCase):
    """직접 출제 품질과 마켓 저장소 동작을 함께 검증한다."""

    def test_direct_authored_catalog_matches_production_contract(self) -> None:
        """필요 변수는 쉰아홉 직접 출제 카탈로그다. 작동 원리는 2,930문항 전체가 생산 품질 계약과 정답 검산을 통과하고 고유 ID를 갖는지 확인하는 것이다."""
        quests = [
            *validate_catalog(build_catalog()),
            *validate_catalog_v2(build_catalog_v2()),
            *validated_quests(),
            *validated_quests_v4(),
            *validated_quests_v5(),
            *validated_quests_v6(),
            *validated_quests_v7(),
            *validated_quests_v8(),
            *validated_quests_v9(),
            *validated_quests_v10(),
            *validated_quests_v11(),
            *validated_quests_v12(),
            *validated_quests_v13(),
            *validated_quests_v14(),
            *validated_quests_v15(),
            *validated_quests_v16(),
            *validated_quests_v17(),
            *validated_quests_v18(),
            *validated_quests_v19(),
            *validated_quests_v20(),
            *validated_quests_v21(),
            *validated_quests_v22(),
            *validated_quests_v23(),
            *validated_quests_v24(),
            *validated_quests_v25(),
            *validated_quests_v26(),
            *validated_quests_v27(),
            *validated_quests_v28(),
            *validated_quests_v29(),
            *validated_quests_v30(),
            *validated_quests_v31(),
            *validated_quests_v32(),
            *validated_quests_v33(),
            *validated_quests_v34(),
            *validated_quests_v35(),
            *validated_quests_v36(),
            *validated_quests_v37(),
            *validated_quests_v38(),
            *validated_quests_v39(),
            *validated_quests_v40(),
            *validated_quests_v41(),
            *validated_quests_v42(),
            *validated_quests_v43(),
            *validated_quests_v44(),
            *validated_quests_v45(),
            *validated_quests_v46(),
            *validated_quests_v47(),
            *validated_quests_v48(),
            *validated_quests_v49(),
            *validated_quests_v50(),
            *validated_quests_v51(),
            *validated_quests_v52(),
            *validated_quests_v53(),
            *validated_quests_v54(),
            *validated_quests_v55(),
            *validated_quests_v56(),
            *validated_quests_v57(),
            *validated_quests_v58(),
            *validated_quests_v59(),
        ]
        self.assertEqual(len(quests), 2930)
        self.assertEqual(len({quest["header"]["quest_id"] for quest in quests}), 2930)
        self.assertTrue(
            all(
                quest["data"]["meta"]["origin"] == "aiflow_direct_original"
                for quest in quests
            )
        )
        recent_quests = quests[-100:]
        self.assertEqual(
            {
                tier: sum(
                    1
                    for quest in recent_quests
                    if quest["info"]["difficulty_tier"] == tier
                )
                for tier in range(1, 6)
            },
            {tier: 20 for tier in range(1, 6)},
        )

    def test_marketplace_repository_filters_cached_public_inventory(self) -> None:
        """필요 변수는 임시 SQLite DB와 세 코너 목록이다. 작동 원리는 UPSERT·코너 필터·검색 결과가 공개 캐시에서 정확히 반환되는지 확인하는 것이다."""
        with tempfile.TemporaryDirectory() as directory:
            db_path = Path(directory) / "marketplace.db"
            with patch.dict(
                os.environ,
                {
                    "MARKETPLACE_BACKEND": "sqlite",
                    "QUEST_DB_PATH": str(db_path),
                },
            ):
                repository._cached_rows = []
                repository._cache_loaded_at = 0.0
                repository.upsert_listings(
                    [
                        _sample_listing("exam-1", "exam", "기초 진단 시험지"),
                        _sample_listing("set-1", "problem_set", "다항식 문제세트"),
                        _sample_listing("course-1", "course", "공통수학 코스"),
                    ]
                )

                self.assertEqual(len(repository.list_published(limit=10)), 3)
                self.assertEqual(len(repository.list_all_published_for_audit()), 3)
                self.assertEqual(
                    [item["id"] for item in repository.list_published(kind="exam")],
                    ["exam-1"],
                )
                self.assertEqual(
                    [item["id"] for item in repository.list_published(query="다항식")],
                    ["set-1"],
                )


if __name__ == "__main__":
    unittest.main()
