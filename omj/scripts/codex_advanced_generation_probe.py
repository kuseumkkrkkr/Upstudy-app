from __future__ import annotations

import json
import os
import sqlite3
import sys
import time
from pathlib import Path
from typing import Any


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _print_json(label: str, value: Any) -> None:
    print(f"{label} {json.dumps(value, ensure_ascii=False, sort_keys=True)}", flush=True)


def _block_text(value: Any) -> str:
    if isinstance(value, dict):
        blocks = value.get("blocks")
        if isinstance(blocks, list):
            return " ".join(
                str(block.get("content") or "").strip()
                for block in blocks
                if isinstance(block, dict)
            ).strip()
    return str(value or "").strip()


def _case_payloads(server: Any) -> list[dict[str, Any]]:
    tag = "#수열"
    return [
        {
            "name": "low",
            "payload": server.VariantFlowDraftRequest(
                flow_draft=[
                    {
                        "node_id": "given_node",
                        "text": "수열의 인접한 두 항 관계를 한 번만 사용한다.",
                        "hash_tags": [tag],
                        "branches": [],
                        "teacher_instruction": "분기 없이 등차 또는 단순 점화 조건만으로 k를 바로 복원한다.",
                    },
                    {
                        "node_id": "solve_node",
                        "text": "주어진 식을 정리하여 정수 k를 구한다.",
                        "hash_tags": [tag],
                        "branches": [],
                        "prompt_text": "계산 단계는 짧고 검산 한 줄을 포함한다.",
                    },
                ],
                prompt="Codex DB validation dummy: 분기 없는 낮은 난도 수열 문항. 정답은 정수 k 하나.",
                tags=[tag],
                solves_count=2,
                strategy_level=1,
                branch_conditions=0,
                advanced_metrics={
                    "trap": 1,
                    "condition_density": 2,
                    "algebra_steps": 3,
                    "branch_factor": 0,
                },
                advanced_profile={
                    "expected_number": "10",
                    "label": "기본",
                    "intent": "단일 조건으로 수열의 일반항 또는 항 값을 복원한다.",
                },
            ),
        },
        {
            "name": "high",
            "payload": server.VariantFlowDraftRequest(
                flow_draft=[
                    {
                        "node_id": "condition_node",
                        "text": "여러 항 조건을 먼저 정리한다.",
                        "hash_tags": [tag],
                        "branches": ["case_check", "verification"],
                        "teacher_instruction": "두 개 이상의 조건을 결합하고, 누락하면 다른 정수 답이 나오게 한다.",
                    },
                    {
                        "node_id": "case_check",
                        "text": "가능한 경우를 나누어 모순을 제거한다.",
                        "hash_tags": [tag],
                        "branches": ["verification"],
                        "prompt_text": "분기별 조건 확인을 풀이에 드러낸다.",
                    },
                    {
                        "node_id": "verification",
                        "text": "구한 k를 원 조건에 대입해 검산한다.",
                        "hash_tags": [tag],
                        "branches": [],
                        "teacher_instruction": "마지막에 모든 조건 만족 여부를 확인한다.",
                    },
                ],
                prompt="Codex DB validation dummy: 고급 캔버스 수열 문항. 조건 밀도와 검산을 강화하고 정답은 정수 k 하나.",
                tags=[tag],
                solves_count=6,
                strategy_level=3,
                branch_conditions=2,
                advanced_metrics={
                    "trap": 9,
                    "condition_density": 9,
                    "algebra_steps": 12,
                    "branch_factor": 2,
                    "verification_depth": 8,
                },
                advanced_profile={
                    "expected_number": "21",
                    "label": "고급 캔버스",
                    "intent": "조건 결합, 경우 확인, 검산을 통해 고난도 수열 추론을 평가한다.",
                },
            ),
        },
    ]


def main() -> int:
    root = _repo_root()
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    os.environ.setdefault("RUNTIME_SEED_BACKFILL_ENABLED", "0")
    sys.path.insert(0, str(root / "omj"))
    os.chdir(root / "omj")

    import server

    created: list[str] = []
    for case in _case_payloads(server):
        name = case["name"]
        payload = case["payload"]
        tags = payload.tags
        context = server._build_variant_generation_context(payload, tags)
        signature = server._build_variant_request_signature(
            tags=tags,
            solves_count=payload.solves_count,
            strategy_level=payload.strategy_level,
            branch_conditions=payload.branch_conditions,
            generation_context=context,
        )
        _print_json(f"PROMPT_CONTEXT {name}", context)
        print(f"REQUEST_SIGNATURE {name} {signature[:16]}", flush=True)
        started = time.monotonic()
        response = server.generate_variant_from_flow_draft(
            payload,
            user_id="codex_dummy_teacher_canvas_math_review",
        )
        elapsed = round(time.monotonic() - started, 3)
        print(f"RESPONSE {name} success={response.success} elapsed={elapsed}", flush=True)
        if not response.success:
            rejection = response.rejection.model_dump() if response.rejection else None
            _print_json(f"REJECTION {name}", rejection)
            continue
        quest = response.quest or {}
        quest_id = (quest.get("header") or {}).get("quest_id")
        if quest_id:
            created.append(str(quest_id))
        data = quest.get("data") or {}
        solves = quest.get("solves") or []
        summary = {
            "quest_id": quest_id,
            "codebase_id": data.get("codebase_id"),
            "seed": data.get("seed"),
            "title": _block_text(data.get("quest_title")),
            "answer": _block_text(data.get("quest_answer")),
            "solves_count": len(solves),
            "branch_counts": [
                len(step.get("branches") or [])
                for step in solves
                if isinstance(step, dict)
            ],
        }
        _print_json(f"QUEST_SUMMARY {name}", summary)

    _print_json("CREATED_IDS", created)
    con = sqlite3.connect("quests.db")
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    for quest_id in created:
        row = cur.execute(
            "SELECT * FROM quest_data WHERE quest_id = ?",
            (quest_id,),
        ).fetchone()
        _print_json("DB_QUEST_DATA", dict(row) if row else None)
        steps = cur.execute(
            """
            SELECT flow, hash_tag, hint_riddle, answer_riddle, enter_huddle, branches
            FROM solve_step
            WHERE quest_id = ?
            ORDER BY id
            """,
            (quest_id,),
        ).fetchall()
        _print_json("DB_SOLVE_STEPS", [dict(step) for step in steps])
        tray = cur.execute(
            """
            SELECT user_id, quest_id, source_variant_mode, visibility_scope,
                   is_mcq_branch, payload_json
            FROM quest_variant_tray
            WHERE quest_id = ?
            ORDER BY id
            """,
            (quest_id,),
        ).fetchall()
        _print_json("DB_TRAY", [dict(item) for item in tray])
    con.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
