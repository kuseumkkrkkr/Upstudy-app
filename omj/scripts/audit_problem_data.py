from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from csat_concept_index import normalize_csat_tag
from difficulty_contract import DIFFICULTY_CONTRACTS, infer_tier_from_contract
from student_problem_content_review import content_text, review_student_problem_content


TIER_BY_PARAMS = {
    (2, 1, 0): 1,
    (3, 1, 0): 2,
    (4, 2, 1): 3,
    (5, 2, 1): 4,
    (6, 3, 2): 5,
}


def _connect_readonly(path: Path) -> sqlite3.Connection:
    """필요 변수: SQLite 파일 경로. 작동 원리: 원본 데이터를 바꾸지 않도록 URI 읽기 전용 연결을 연다."""
    connection = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def _parse_json(value: Any, fallback: Any) -> Any:
    """필요 변수: DB JSON 문자열과 기본값. 작동 원리: 손상된 JSON을 감사 중단 없이 기본값으로 분리한다."""
    if isinstance(value, (dict, list)):
        return value
    if not isinstance(value, str) or not value.strip():
        return fallback
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return fallback


def _normalized_tags(*values: Any) -> list[str]:
    """필요 변수: 여러 태그 JSON·목록. 작동 원리: 샵과 공백 차이를 제거한 중복 없는 태그 목록을 만든다."""
    result: list[str] = []
    for value in values:
        parsed = _parse_json(value, []) if isinstance(value, str) else value
        if not isinstance(parsed, list):
            continue
        for raw_tag in parsed:
            tag = normalize_csat_tag(str(raw_tag))
            if tag and tag not in result:
                result.append(tag)
    return result


def _load_codebases(path: Path) -> dict[int, dict[str, Any]]:
    """필요 변수: 코드베이스 DB. 작동 원리: 문제의 생성 계약과 티어를 복원할 최소 칼럼을 ID 역색인으로 읽는다."""
    connection = _connect_readonly(path)
    try:
        columns = {row["name"] for row in connection.execute("PRAGMA table_info(codebases)")}
        tier_column = "tier" if "tier" in columns else "NULL AS tier"
        tier_source_column = "tier_source" if "tier_source" in columns else "NULL AS tier_source"
        quality_column = "quality_status" if "quality_status" in columns else "NULL AS quality_status"
        rows = connection.execute(
            f"""
            SELECT id, tags, difficulty, {tier_column}, {tier_source_column}, {quality_column}, solves_count,
                   strategy_level, branch_conditions
            FROM codebases
            """
        ).fetchall()
        return {
            int(row["id"]): {
                "id": int(row["id"]),
                "tags": _normalized_tags(row["tags"]),
                "difficulty_score": row["difficulty"],
                "explicit_tier": row["tier"],
                "tier_source": row["tier_source"],
                "quality_status": row["quality_status"],
                "solves_count": row["solves_count"],
                "strategy_level": row["strategy_level"],
                "branch_conditions": row["branch_conditions"],
            }
            for row in rows
        }
    finally:
        connection.close()


def _resolve_codebase_tier(codebase: dict[str, Any] | None) -> tuple[int | None, str]:
    """필요 변수: 코드베이스 계약. 작동 원리: 명시 티어를 우선하고 없으면 풀이·전략·분기 조합으로 1~5티어를 복원한다."""
    if not codebase:
        return None, "missing_codebase"
    explicit = codebase.get("explicit_tier")
    if isinstance(explicit, int) and 1 <= explicit <= 5:
        contract = DIFFICULTY_CONTRACTS[explicit]
        if (
            int(codebase.get("solves_count") or 0) == contract.solves_count
            and int(codebase.get("strategy_level") or 0) == contract.strategy_level
            and int(codebase.get("branch_conditions") or 0) == contract.branch_conditions
        ):
            return explicit, "explicit"
    params = (
        int(codebase.get("solves_count") or 0),
        int(codebase.get("strategy_level") or 0),
        int(codebase.get("branch_conditions") or 0),
    )
    inferred = TIER_BY_PARAMS.get(params)
    if inferred:
        return inferred, "params"
    nearest, _ = infer_tier_from_contract(*params)
    return nearest, "nearest_params"


def _quest_from_row(row: sqlite3.Row, solves: Iterable[sqlite3.Row]) -> dict[str, Any]:
    """필요 변수: 문제·풀이 DB 행. 작동 원리: 운영 콘텐츠 검수기가 읽는 정규 문제 구조로 복원한다."""
    solve_items = []
    for solve in solves:
        solve_items.append(
            {
                "flow": _parse_json(solve["flow"], solve["flow"]),
                "hint_riddle": _parse_json(solve["hint_riddle"], solve["hint_riddle"]),
                "answer_riddle": _parse_json(solve["answer_riddle"], solve["answer_riddle"]),
                "branches": _parse_json(solve["branches"], []),
            }
        )
    return {
        "header": {"quest_id": row["quest_id"]},
        "info": {
            "difficulty": row["difficulty"],
            "hash_tag": _parse_json(row["info_tags"], []),
        },
        "data": {
            "quest_title": _parse_json(row["quest_title"], row["quest_title"]),
            "quest_answer": _parse_json(row["quest_answer"], row["quest_answer"]),
            "codebase_id": row["codebase_id"],
            "seed": row["seed"],
            "hash_tag": _parse_json(row["data_tags"], []),
        },
        "solves": solve_items,
    }


def audit_problem_data(quest_db: Path, codebase_db: Path, detail_limit: int) -> dict[str, Any]:
    """필요 변수: 문제·코드베이스 DB와 예시 제한. 작동 원리: 전 문제를 조인해 난도 백필 가능성, 콘텐츠와 태그 계약 위반을 집계한다."""
    codebases = _load_codebases(codebase_db)
    codebase_connection = _connect_readonly(codebase_db)
    try:
        seed_cache = codebase_connection.execute(
            "SELECT COUNT(*) AS rows, COUNT(DISTINCT codebase_id) AS codebases FROM codebase_seed_cache"
        ).fetchone()
        seed_stats = codebase_connection.execute(
            "SELECT COALESCE(SUM(attempts),0) AS attempts, COALESCE(SUM(successes),0) AS successes FROM codebase_seed_stats"
        ).fetchone()
        seed_log_statuses = {
            str(row["status"]): int(row["rows"])
            for row in codebase_connection.execute(
                "SELECT status, COUNT(*) AS rows FROM codebase_seed_logs GROUP BY status ORDER BY status"
            )
        }
        codebase_inventory = {
            "seed_cache_rows": int(seed_cache["rows"]),
            "codebases_with_cached_seeds": int(seed_cache["codebases"]),
            "recorded_attempts": int(seed_stats["attempts"]),
            "recorded_successes": int(seed_stats["successes"]),
            "seed_log_statuses": seed_log_statuses,
        }
    finally:
        codebase_connection.close()
    connection = _connect_readonly(quest_db)
    try:
        table_names = [
            str(row["name"])
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
            )
        ]
        quest_table_counts = {
            table: int(connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])
            for table in table_names
        }
        quest_info_columns = {
            str(row["name"]) for row in connection.execute("PRAGMA table_info(quest_info)")
        }
        stored_quality_status_counts = {}
        if "quality_status" in quest_info_columns:
            stored_quality_status_counts = {
                str(row["quality_status"]): int(row["rows"])
                for row in connection.execute(
                    "SELECT quality_status, COUNT(*) AS rows FROM quest_info GROUP BY quality_status"
                )
            }
        quest_rows = connection.execute(
            """
            SELECT i.quest_id, i.difficulty, i.flow_rate, i.main_huddle,
                   i.hash_tag AS info_tags,
                   d.quest_title, d.quest_answer, d.codebase_id, d.seed,
                   d.hash_tag AS data_tags
            FROM quest_info i
            JOIN quest_data d ON d.quest_id = i.quest_id
            ORDER BY i.quest_id
            """
        ).fetchall()
        solves_by_quest: dict[str, list[sqlite3.Row]] = defaultdict(list)
        for solve in connection.execute(
            """
            SELECT quest_id, flow, hint_riddle, answer_riddle, branches
            FROM solve_step ORDER BY quest_id, id
            """
        ):
            solves_by_quest[str(solve["quest_id"])].append(solve)

        difficulty_distribution: Counter[str] = Counter()
        tier_distribution: Counter[str] = Counter()
        tier_sources: Counter[str] = Counter()
        content_reasons: Counter[str] = Counter()
        mismatch_counts: Counter[str] = Counter()
        title_counts: Counter[str] = Counter()
        examples: dict[str, list[dict[str, Any]]] = defaultdict(list)
        unresolved_profiles: Counter[str] = Counter()

        for row in quest_rows:
            quest_id = str(row["quest_id"])
            quest = _quest_from_row(row, solves_by_quest.get(quest_id, []))
            title = content_text((quest.get("data") or {}).get("quest_title"))
            title_counts[title] += 1
            difficulty_distribution[str(row["difficulty"])] += 1

            codebase_id = row["codebase_id"]
            codebase = codebases.get(int(codebase_id)) if codebase_id is not None else None
            tier, tier_source = _resolve_codebase_tier(codebase)
            tier_sources[tier_source] += 1
            tier_distribution[str(tier) if tier is not None else "unresolved"] += 1
            if tier is None:
                profile = {
                    "difficulty_score": int(row["difficulty"] or 0),
                    "flow_rate": int(row["flow_rate"] or 0),
                    "main_huddle": int(row["main_huddle"] or 0),
                    "solve_count": len(quest.get("solves") or []),
                    "tag_count": len(_normalized_tags(row["info_tags"], row["data_tags"])),
                    "reason": tier_source,
                }
                unresolved_profiles[json.dumps(profile, ensure_ascii=False, sort_keys=True)] += 1

            review = review_student_problem_content(quest)
            for reason in review["reasons"]:
                content_reasons[str(reason)] += 1
                if len(examples[f"content:{reason}"]) < detail_limit:
                    examples[f"content:{reason}"].append(
                        {"quest_id": quest_id, "codebase_id": codebase_id, "title": title}
                    )

            solve_count = len(quest.get("solves") or [])
            if codebase and int(codebase.get("solves_count") or 0) != solve_count:
                mismatch_counts["solve_count_vs_codebase"] += 1
                if len(examples["solve_count_vs_codebase"]) < detail_limit:
                    examples["solve_count_vs_codebase"].append(
                        {
                            "quest_id": quest_id,
                            "codebase_id": codebase_id,
                            "expected": codebase.get("solves_count"),
                            "actual": solve_count,
                            "title": title,
                        }
                    )

            quest_tags = _normalized_tags(row["info_tags"], row["data_tags"])
            codebase_tags = set((codebase or {}).get("tags") or [])
            if codebase and not set(quest_tags).issubset(codebase_tags):
                mismatch_counts["quest_tags_outside_codebase"] += 1
                if len(examples["quest_tags_outside_codebase"]) < detail_limit:
                    examples["quest_tags_outside_codebase"].append(
                        {
                            "quest_id": quest_id,
                            "codebase_id": codebase_id,
                            "quest_only": sorted(set(quest_tags) - codebase_tags),
                            "title": title,
                        }
                    )
            if codebase is None:
                mismatch_counts["missing_codebase_reference"] += 1

        duplicate_titles = {
            title: count
            for title, count in title_counts.items()
            if title and count > 1
        }
        header_count = connection.execute("SELECT COUNT(*) FROM quest_header").fetchone()[0]
        info_count = connection.execute("SELECT COUNT(*) FROM quest_info").fetchone()[0]
        data_count = connection.execute("SELECT COUNT(*) FROM quest_data").fetchone()[0]
        solve_count = connection.execute("SELECT COUNT(*) FROM solve_step").fetchone()[0]
        orphan_counts = {
            "header_without_info": connection.execute(
                "SELECT COUNT(*) FROM quest_header h LEFT JOIN quest_info i ON i.quest_id=h.quest_id WHERE i.quest_id IS NULL"
            ).fetchone()[0],
            "header_without_data": connection.execute(
                "SELECT COUNT(*) FROM quest_header h LEFT JOIN quest_data d ON d.quest_id=h.quest_id WHERE d.quest_id IS NULL"
            ).fetchone()[0],
            "solve_without_header": connection.execute(
                "SELECT COUNT(*) FROM solve_step s LEFT JOIN quest_header h ON h.quest_id=s.quest_id WHERE h.quest_id IS NULL"
            ).fetchone()[0],
        }
        codebase_tiers = Counter()
        for codebase in codebases.values():
            tier, source = _resolve_codebase_tier(codebase)
            codebase_tiers[f"{tier if tier is not None else 'unresolved'}:{source}"] += 1
        approved_codebase_tags = {
            tag
            for codebase in codebases.values()
            if codebase.get("quality_status") == "approved"
            for tag in codebase.get("tags") or []
        }
        approved_scores_by_tier: dict[str, list[int]] = defaultdict(list)
        for codebase in codebases.values():
            if codebase.get("quality_status") != "approved":
                continue
            tier, _ = _resolve_codebase_tier(codebase)
            if tier is not None:
                approved_scores_by_tier[str(tier)].append(int(codebase.get("difficulty_score") or 0))
        approved_score_summary = {
            tier: {
                "count": len(scores),
                "min": min(scores),
                "median": statistics.median(scores),
                "max": max(scores),
            }
            for tier, scores in sorted(approved_scores_by_tier.items())
            if scores
        }

        return {
            "databases": {
                "quest_db": str(quest_db.resolve()),
                "codebase_db": str(codebase_db.resolve()),
            },
            "counts": {
                "quest_header": header_count,
                "quest_info": info_count,
                "quest_data": data_count,
                "solve_step": solve_count,
                "joined_quests": len(quest_rows),
                "codebases": len(codebases),
            },
            "quest_table_counts": quest_table_counts,
            "stored_quality_status_counts": stored_quality_status_counts,
            "codebase_inventory": codebase_inventory,
            "difficulty_distribution": dict(sorted(difficulty_distribution.items(), key=lambda item: int(item[0]))),
            "resolved_tier_distribution": dict(sorted(tier_distribution.items())),
            "tier_resolution_sources": dict(sorted(tier_sources.items())),
            "codebase_tier_distribution": dict(sorted(codebase_tiers.items())),
            "approved_codebase_tag_count": len(approved_codebase_tags),
            "approved_codebase_tags": sorted(approved_codebase_tags),
            "approved_codebase_score_summary": approved_score_summary,
            "unresolved_profiles": [
                {**json.loads(profile), "rows": count}
                for profile, count in sorted(unresolved_profiles.items())
            ],
            "content_rejection_reasons": dict(sorted(content_reasons.items())),
            "contract_mismatches": dict(sorted(mismatch_counts.items())),
            "duplicate_title_groups": len(duplicate_titles),
            "duplicate_title_rows": sum(duplicate_titles.values()),
            "orphan_counts": orphan_counts,
            "examples": dict(sorted(examples.items())),
        }
    finally:
        connection.close()


def main() -> None:
    """필요 변수: 선택적 DB 경로와 예시 수. 작동 원리: 전수 감사 결과를 UTF-8 JSON으로 표준 출력한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--quest-db", type=Path, default=ROOT / "quests.db")
    parser.add_argument("--codebase-db", type=Path, default=ROOT / "codebases.db")
    parser.add_argument("--detail-limit", type=int, default=10)
    args = parser.parse_args()
    result = audit_problem_data(args.quest_db, args.codebase_db, max(0, args.detail_limit))
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
