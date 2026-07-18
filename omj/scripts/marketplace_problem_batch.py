from __future__ import annotations

import os
import sqlite3
from collections import Counter
from pathlib import Path
from typing import Any

from difficulty_contract import DIFFICULTY_CONTRACTS
from scripts.seed_initial_math_problems import (
    _build_quest,
    _content_text,
    _count_branches,
    _create_backup,
    _remove_inserted_batch,
)
from student_problem_content_review import review_student_problem_contract


def build_market_quest(
    spec: dict[str, Any],
    *,
    batch_id: str,
    model_name: str,
    codebase_base: int,
    seed_base: int,
) -> dict[str, Any]:
    """필요 변수는 직접 출제 명세·배치 식별자·variant 기준값이다. 작동 원리는 기존 생산 조립 규격에 충돌 없는 ID와 직접 저작 메타를 부여하는 것이다."""
    quest = _build_quest(spec)
    tier = int(spec["tier"])
    index = int(spec["index"])
    variant_number = tier * 100 + index
    quest["header"]["quest_id"] = f"curated/{batch_id}/t{tier}-{index:02d}"
    quest["header"]["quest_model"] = {"models": [model_name]}
    quest["data"]["codebase_id"] = -(codebase_base + variant_number)
    quest["data"]["seed"] = seed_base + variant_number
    quest["data"]["meta"] = {
        "batch_id": batch_id,
        "origin": "aiflow_direct_original",
        "copyright_policy": "original_problem_and_solution",
        "authored_at": "2026-07-18",
        "marketplace_ready": True,
    }
    return quest


def validate_problem_batch(
    catalog: list[dict[str, Any]],
    *,
    expected_count: int,
    batch_id: str,
    model_name: str,
    codebase_base: int,
    seed_base: int,
) -> list[dict[str, Any]]:
    """필요 변수는 직접 출제 명세와 배치 규격이다. 작동 원리는 수량·ID·제목·난이도 단계·분기·학생 노출 계약을 저장 전에 전수 검사하는 것이다."""
    if len(catalog) != expected_count:
        raise ValueError(f"신규 문제 수량 불일치: {len(catalog)}/{expected_count}")
    for spec in catalog:
        answer_check = spec.get("answer_check")
        if answer_check is None:
            continue
        if not callable(answer_check):
            raise TypeError(f"정답 검산 함수가 호출 가능하지 않습니다: tier={spec.get('tier')} index={spec.get('index')}")
        checked_answer = str(answer_check()).strip()
        stored_answer = str(spec.get("answer") or "").strip()
        if checked_answer != stored_answer:
            raise ValueError(
                f"정답 독립 검산 불일치: tier={spec.get('tier')} index={spec.get('index')} "
                f"stored={stored_answer} checked={checked_answer}"
            )
    quests = [
        build_market_quest(
            spec,
            batch_id=batch_id,
            model_name=model_name,
            codebase_base=codebase_base,
            seed_base=seed_base,
        )
        for spec in catalog
    ]
    ids = [quest["header"]["quest_id"] for quest in quests]
    titles = [_content_text(quest["data"]["quest_title"]) for quest in quests]
    if len(ids) != len(set(ids)) or len(titles) != len(set(titles)):
        raise ValueError(f"{batch_id} 내부에 중복 ID 또는 제목이 있습니다.")
    for quest in quests:
        tier = int(quest["info"]["difficulty_tier"])
        contract = DIFFICULTY_CONTRACTS[tier]
        if len(quest["solves"]) != contract.solves_count:
            raise ValueError(f"풀이 단계 계약 불일치: {quest['header']['quest_id']}")
        if _count_branches(quest["solves"]) != contract.branch_conditions:
            raise ValueError(f"분기 계약 불일치: {quest['header']['quest_id']}")
        review = review_student_problem_contract(
            quest,
            expected_solve_count=contract.solves_count,
            expected_tags=quest["info"]["hash_tag"],
        )
        if review["approved"] is not True:
            raise ValueError(f"학생 문제 품질 거절: {quest['header']['quest_id']} {review['reasons']}")
    return quests


def seed_problem_batch(
    db_path: Path,
    *,
    quests: list[dict[str, Any]],
    batch_id: str,
    validate_only: bool,
) -> dict[str, Any]:
    """필요 변수는 검증된 문제·대상 DB·배치 ID다. 작동 원리는 백업 후 신규 ID만 직접 저장하고 승인 상태와 난이도별 수량을 전수 재조회하는 것이다."""
    db_path = db_path.resolve()
    report: dict[str, Any] = {
        "batch_id": batch_id,
        "db_path": str(db_path),
        "validated": len(quests),
        "tier_counts": dict(sorted(Counter(int(q["info"]["difficulty_tier"]) for q in quests).items())),
        "inserted": 0,
        "skipped": 0,
    }
    if validate_only:
        return report
    os.environ["QUEST_DB_PATH"] = str(db_path)
    os.environ["PROBLEM_DUAL_WRITE_ENABLED"] = "false"
    from storage import storage as quest_storage

    quest_storage.DB_PATH = str(db_path)
    quest_storage.init_db()
    prefix = f"curated/{batch_id}"
    with sqlite3.connect(db_path) as connection:
        existing_ids = {str(row[0]) for row in connection.execute("SELECT quest_id FROM quest_header WHERE quest_id LIKE ?", (f"{prefix}/%",))}
        existing_titles = {_content_text(row[1]): str(row[0]) for row in connection.execute("SELECT quest_id, quest_title FROM quest_data")}
    for quest in quests:
        quest_id = quest["header"]["quest_id"]
        if quest_id in existing_ids:
            report["skipped"] += 1
            continue
        title = _content_text(quest["data"]["quest_title"])
        if title in existing_titles:
            raise RuntimeError(f"기존 문제와 제목 중복: {existing_titles[title]} / {title}")
    backup_path = db_path.with_name(f"{db_path.name}.bak_{batch_id}")
    report["backup_created"] = _create_backup(db_path, backup_path)
    report["backup_path"] = str(backup_path)
    inserted_ids: list[str] = []
    try:
        for quest in quests:
            quest_id = quest["header"]["quest_id"]
            if quest_id in existing_ids:
                continue
            if not quest_storage.store_data(quest):
                raise RuntimeError(f"문제 저장 실패: {quest_id} {quest_storage.get_last_store_error()}")
            inserted_ids.append(quest_id)
    except Exception:
        _remove_inserted_batch(db_path, inserted_ids)
        raise
    loaded = quest_storage.get_quests_by_ids([quest["header"]["quest_id"] for quest in quests])
    if len(loaded) != len(quests) or any(quest["info"].get("quality_status") != "approved" for quest in loaded):
        raise RuntimeError(f"{batch_id} 재조회 또는 승인 검증에 실패했습니다.")
    report["inserted"] = len(inserted_ids)
    report["readback"] = len(loaded)
    report["approved"] = sum(1 for quest in loaded if quest["info"].get("quality_status") == "approved")
    return report
