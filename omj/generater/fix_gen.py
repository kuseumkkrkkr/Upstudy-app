from __future__ import annotations

from datetime import datetime
from typing import Iterable, Iterator, List

from baselines.basemodel import (
    AISolveStep,
    AIQuestResult,
    ContentBlocks,
    QuestData,
    QuestHeader,
    QuestInfo,
    QuestModel,
    SolveStep,
    blocks_to_text,
)


# =========================
# Non-AI Field Providers
# =========================

from .tag_registry import load_subject_tag_rules

SUBJECT_TAG_RULES = load_subject_tag_rules()

import functools

@functools.lru_cache(maxsize=512)
def _normalize_tag(tag: str) -> str:
    return tag.strip().lstrip("#").strip()


def _build_tag_mapping(hash_tags: List[str]) -> dict:
    mapping = {}
    for tag in hash_tags:
        raw = tag.strip()
        if not raw:
            continue
        normalized = _normalize_tag(raw)
        if normalized and normalized not in mapping:
            mapping[normalized] = raw
    return mapping


def _normalize_step_tags(tags: List[str], tag_mapping: dict) -> List[str]:
    if not tags:
        return []
    seen = set()
    resolved: List[str] = []
    for tag in tags:
        if not isinstance(tag, str):
            continue
        normalized = _normalize_tag(tag)
        if not normalized:
            continue
        mapped = tag_mapping.get(normalized)
        if not mapped or mapped in seen:
            continue
        seen.add(mapped)
        resolved.append(mapped)
    return resolved


def _clean_hash_tags(hash_tags: List[str]) -> List[str]:
    mapping = _build_tag_mapping(hash_tags)
    return list(mapping.values())


def generation_tag_groups() -> List[dict]:
    groups: List[dict] = []
    for subject in SUBJECT_TAG_RULES:
        name = str(subject.get("name", ""))
        tags = sorted(
            str(tag).strip()
            for tag in subject.get("tags", set())
            if str(tag).strip()
        )
        groups.append(
            {
                "code": int(subject.get("code", 0)),
                "grade": int(subject.get("grade", 0)),
                "name": name,
                "label": str(subject.get("label") or name),
                "tags": tags,
            }
        )
    return groups


def allowed_generation_tag_mapping() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for group in generation_tag_groups():
        for tag in group["tags"]:
            normalized = _normalize_tag(tag)
            if normalized and normalized not in mapping:
                mapping[normalized] = tag
    return mapping


def allowed_generation_tags() -> List[str]:
    return sorted(allowed_generation_tag_mapping().values())


def validate_generation_tags(
    hash_tags: Iterable[str],
    *,
    allow_empty: bool = False,
) -> List[str]:
    items = list(hash_tags)
    if any(not isinstance(tag, str) for tag in items):
        raise TypeError("hash_tags must be a list of strings")

    allowed = allowed_generation_tag_mapping()
    results: List[str] = []
    seen: set[str] = set()
    unknown: List[str] = []
    for tag in items:
        normalized = _normalize_tag(tag)
        if not normalized:
            continue
        canonical = allowed.get(normalized)
        if canonical is None:
            unknown.append(normalized)
            continue
        if normalized in seen:
            continue
        seen.add(normalized)
        results.append(canonical)

    if unknown:
        raise ValueError(f"unknown hash tags: {sorted(set(unknown))}")
    if not results and not allow_empty:
        raise ValueError("hash_tags must not be empty")
    return results


def _resolve_primary_tag(primary_hash_tag: str, tag_mapping: dict) -> str:
    normalized = _normalize_tag(primary_hash_tag or "")
    return tag_mapping.get(normalized, "")


def _iter_solve_steps(ai_solves: List[AISolveStep]) -> Iterable[AISolveStep]:
    for step in ai_solves:
        yield step
        if step.branches:
            yield from _iter_solve_steps(step.branches)


def _select_solve_step_tags(
    hash_tags: List[str],
    solves_flat: List[AISolveStep],
    fallback_tag: str,
) -> List[List[str]]:
    tag_mapping = _build_tag_mapping(hash_tags)
    ordered_norms = list(tag_mapping.keys())
    if not ordered_norms:
        return [[] for _ in solves_flat]

    fallback = fallback_tag or tag_mapping[ordered_norms[0]]
    results = []
    for step in solves_flat:
        ai_tags = _normalize_step_tags(getattr(step, "hash_tag", []) or [], tag_mapping)
        if ai_tags:
            results.append(ai_tags)
            continue
        text = " ".join(
            [
                _content_to_text(step.flow),
                _content_to_text(step.hint_riddle),
                _content_to_text(step.answer_riddle),
            ]
        )
        condensed = text.replace(" ", "")
        matched = []
        for norm in ordered_norms:
            condensed_norm = norm.replace(" ", "")
            if condensed_norm and condensed_norm in condensed:
                matched.append(tag_mapping[norm])
        if not matched:
            matched = [fallback]
        results.append(matched)
    return results


def _content_to_text(content: ContentBlocks | dict | list | str | None) -> str:
    if content is None:
        return ""
    if isinstance(content, ContentBlocks):
        return blocks_to_text(content)
    if isinstance(content, str):
        return content
    try:
        return blocks_to_text(ContentBlocks.model_validate(content))
    except Exception:
        return str(content)


def _has_content(content: ContentBlocks | dict | list | str | None) -> bool:
    return bool(_content_to_text(content).strip())


def _to_blocks(content: ContentBlocks | dict | list | str | None) -> ContentBlocks:
    if isinstance(content, ContentBlocks):
        return content
    return ContentBlocks.model_validate(content)


def _fallback_blocks() -> ContentBlocks:
    return ContentBlocks.model_validate({"blocks": [{"type": "text", "content": "-"}]})


def _ensure_blocks(
    primary: ContentBlocks | dict | list | str | None,
    *fallbacks: ContentBlocks | dict | list | str | None,
) -> ContentBlocks:
    if _has_content(primary):
        return _to_blocks(primary)
    for fallback in fallbacks:
        if _has_content(fallback):
            return _to_blocks(fallback)
    return _fallback_blocks()


def generate_quest_id(subject_code: int) -> str:
    """Build quest ID: {subject_code}/{yymmdd}/{hhmmssff}"""
    if not isinstance(subject_code, int):
        raise TypeError("subject_code must be an int")

    now = datetime.now()
    date_part = now.strftime("%y%m%d")
    time_part = f"{now:%H%M%S%f}"
    return f"{subject_code:03d}/{date_part}/{time_part}"


def get_main_grade(hash_tags: List[str], *, strict: bool = True) -> int:
    """Calculate primary subject code from hash tags."""
    normalized = {_normalize_tag(tag) for tag in hash_tags if _normalize_tag(tag)}
    if not normalized:
        raise ValueError("hash_tags must not be empty")

    known_tags = set()
    for subject in SUBJECT_TAG_RULES:
        known_tags.update({_normalize_tag(tag) for tag in subject["tags"]})

    matched = []
    for subject in SUBJECT_TAG_RULES:
        subject_tags = {_normalize_tag(tag) for tag in subject["tags"]}
        if normalized & subject_tags:
            matched.append(subject)

    if strict:
        unknown = normalized - known_tags
        if unknown:
            raise ValueError(f"unknown hash tags: {sorted(unknown)}")
        if not matched:
            raise ValueError("no subject matched from hash_tags")

    if not matched:
        return 0

    highest = max(matched, key=lambda item: (item["grade"], item["code"]))
    return int(highest["code"])


def get_problem_types(
    hash_tags: List[str],
    solve_step_tags: List[List[str]],
    primary_hash_tag: str,
) -> List[str]:
    """Problem types: [most frequent tag, AI primary tag]"""
    tag_mapping = _build_tag_mapping(hash_tags)
    ordered_norms = list(tag_mapping.keys())
    if not ordered_norms:
        return []

    counts = {norm: 0 for norm in ordered_norms}
    for tags in solve_step_tags:
        for tag in tags:
            normalized = _normalize_tag(tag)
            if normalized in counts:
                counts[normalized] += 1

    best_norm = ordered_norms[0]
    best_count = counts[best_norm]
    for norm in ordered_norms[1:]:
        if counts[norm] > best_count:
            best_norm = norm
            best_count = counts[norm]

    most_frequent = tag_mapping[best_norm]
    primary_tag = _resolve_primary_tag(primary_hash_tag, tag_mapping) or most_frequent
    return [most_frequent, primary_tag]


def _count_total_flows(ai_solves: List[AISolveStep]) -> int:
    return sum(1 for _ in _iter_solve_steps(ai_solves))


def _count_branch_lanes(ai_solves: List[AISolveStep]) -> int:
    total = 0
    for step in ai_solves:
        total += len(step.branches)
        if step.branches:
            total += _count_branch_lanes(step.branches)
    return total


def _sum_enter_huddle(ai_solves: List[AISolveStep]) -> int:
    return sum(step.enter_huddle for step in _iter_solve_steps(ai_solves))


def calculate_flow_rate(ai: AIQuestResult) -> int:
    """Count total flows including branch nodes"""
    return _count_total_flows(ai.solves)


def calculate_difficulty(hash_tags: List[str], ai_solves: List[AISolveStep]) -> int:
    """
    Difficulty formula:
        1.0 * hashtag_count
        + 4.0 * total_flow_count
        + 3.0 * branch_lane_count (number of branch lanes across all splits)
        + 2.0 * strategy_difficulty (sum of enter_huddle)
    """
    tag_count = len(_build_tag_mapping(hash_tags))
    flow_count = _count_total_flows(ai_solves)
    branch_lanes = _count_branch_lanes(ai_solves)
    strategy_score = _sum_enter_huddle(ai_solves)
    return int(tag_count + 4 * flow_count + 3 * branch_lanes + 2 * strategy_score)


def _convert_ai_solves(
    ai_solves: List[AISolveStep],
    tag_iter: Iterator[List[str]],
) -> List[SolveStep]:
    steps: List[SolveStep] = []
    for ai_step in ai_solves:
        try:
            tags_for_step = next(tag_iter)
        except StopIteration as exc:
            raise ValueError("insufficient tags for solve steps") from exc

        flow = _ensure_blocks(ai_step.flow, ai_step.hint_riddle, ai_step.answer_riddle)
        hint_riddle = _ensure_blocks(
            ai_step.hint_riddle,
            ai_step.flow,
            ai_step.answer_riddle,
        )
        answer_riddle = _ensure_blocks(
            ai_step.answer_riddle,
            ai_step.flow,
            ai_step.hint_riddle,
        )

        step = SolveStep(
            flow=flow,
            hash_tag=tags_for_step,
            hint_riddle=hint_riddle,
            answer_riddle=answer_riddle,
            enter_huddle=ai_step.enter_huddle,
            branches=_convert_ai_solves(ai_step.branches, tag_iter),
        )
        steps.append(step)
    return steps


def fix_gen(ai: AIQuestResult, hash_tags: List[str], *, strict_tags: bool = True) -> dict:
    """
    Normalize AI output into domain models and apply difficulty calculation.
    """
    if any(not isinstance(tag, str) for tag in hash_tags):
        raise TypeError("hash_tags must be a list of strings")

    clean_hash_tags = _clean_hash_tags(hash_tags)
    subject_code = get_main_grade(clean_hash_tags, strict=strict_tags)
    tag_mapping = _build_tag_mapping(clean_hash_tags)
    primary_tag = _resolve_primary_tag(ai.primary_hash_tag, tag_mapping)

    # QuestHeader
    quest_header = QuestHeader(
        quest_id=generate_quest_id(subject_code),
        quest_model=QuestModel(models=ai.quest_model),
    )

    # QuestData
    quest_data_model = QuestData(
        quest_title=ai.quest_title,
        quest_image=ai.quest_image,
        quest_answer=ai.quest_answer or None,
    )

    # SolveSteps with branches
    flattened_solves = list(_iter_solve_steps(ai.solves))
    solve_step_tags = _select_solve_step_tags(
        clean_hash_tags,
        flattened_solves,
        fallback_tag=primary_tag,
    )

    tags_iter = iter(solve_step_tags)
    solve_steps = _convert_ai_solves(ai.solves, tags_iter)
    if next(tags_iter, None) is not None:
        raise ValueError("extra tags remained after building solve steps")

    # QuestInfo
    quest_info = QuestInfo(
        main=subject_code,
        sub=get_problem_types(clean_hash_tags, solve_step_tags, ai.primary_hash_tag),
        hash_tag=clean_hash_tags,
        flow_rate=calculate_flow_rate(ai),
        difficulty=calculate_difficulty(clean_hash_tags, ai.solves),
        main_huddle=ai.main_huddle,
    )

    storage_data = {
        "header": quest_header.model_dump(),
        "info": quest_info.model_dump(),
        "data": quest_data_model.model_dump(),
        "solves": [step.model_dump() for step in solve_steps],
    }

    return storage_data
