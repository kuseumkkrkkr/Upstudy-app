import random
from typing import Dict, List, Sequence, Tuple


def plan_exam_items(
    *,
    ranges: List[Dict[str, List[str]]],
    difficulty_tier: int,
    question_count: int,
    paper_type: str = "aiflow",
) -> List[Dict[str, object]]:
    if paper_type == "csat":
        return _plan_csat_items(
            ranges=ranges,
            initial_tier=difficulty_tier,
            question_count=question_count,
        )
    return _plan_aiflow_items(
        ranges=ranges,
        difficulty_tier=difficulty_tier,
        question_count=question_count,
    )


def _plan_aiflow_items(
    *,
    ranges: List[Dict[str, List[str]]],
    difficulty_tier: int,
    question_count: int,
) -> List[Dict[str, object]]:
    subjects = [r for r in ranges if r.get("tags")]
    if not subjects:
        raise ValueError("at least one subject range with tags is required")
    if question_count < 1:
        raise ValueError("question_count must be >= 1")

    subject_count = len(subjects)
    counts = _split_counts(question_count, subject_count)

    all_subject_tags = [clean_tags(s.get("tags", [])) for s in subjects]

    items: List[Dict[str, object]] = []
    item_index = 1
    for subject_idx, subject_tags in enumerate(all_subject_tags):
        if not subject_tags:
            continue
        count = counts[subject_idx]
        subject_key = subjects[subject_idx].get("key") or f"subject-{subject_idx + 1}"
        distributor = TagDistributor(subject_tags)
        overlay_tags = _build_overlay_tags(all_subject_tags, subject_idx)
        overlay_distributor = TagDistributor(overlay_tags) if overlay_tags else None

        for local_idx in range(count):
            tier = _linear_tier(difficulty_tier, local_idx, count)
            params = _tier_params(tier)
            tag_count = _tier_tag_count(tier)

            use_overlay = question_count >= 30 and local_idx >= max(0, count - 5)
            tags = distributor.pick(tag_count, overlay=overlay_distributor if use_overlay else None)

            items.append(
                {
                    "item_index": item_index,
                    "status": "pending",
                    "subject_key": subject_key,
                    "hash_tags": tags,
                    "difficulty_tier": tier,
                    "solves_count": params["solves_count"],
                    "strategy_level": params["strategy_level"],
                    "branch_conditions": params["branch_conditions"],
                    "question_type": "short",
                    "quest_id": None,
                    "flow_count": None,
                    "error": None,
                }
            )
            item_index += 1

    return items


def _plan_csat_items(
    *,
    ranges: List[Dict[str, List[str]]],
    initial_tier: int,
    question_count: int,
) -> List[Dict[str, object]]:
    if question_count != 30:
        raise ValueError("수능 모드는 30문제만 허용됩니다.")
    if initial_tier not in (3, 4, 5):
        raise ValueError("수능 모드는 난이도 3~5만 허용됩니다.")

    common_tags, optional_tags = _split_csat_ranges(ranges)
    if not common_tags:
        raise ValueError("공통수학 1,2 해시태그가 필요합니다.")
    if not optional_tags:
        raise ValueError("선택 과목 해시태그가 필요합니다.")

    items: List[Dict[str, object]] = []
    for item_index in range(1, 31):
        tier = _csat_tier_for_index(item_index, initial_tier)
        params = _tier_params(tier)
        tag_count = _tier_tag_count(tier)
        question_type = "mcq" if item_index <= 15 or item_index >= 23 else "short"

        if item_index <= 22:
            tags = _pick_csat_tags(
                common_tags,
                [],
                tag_count,
                require_optional=False,
            )
        else:
            tags = _pick_csat_tags(
                common_tags,
                optional_tags,
                tag_count,
                require_optional=True,
            )

        items.append(
            {
                "item_index": item_index,
                "status": "pending",
                "subject_key": "csat",
                "hash_tags": tags,
                "difficulty_tier": tier,
                "solves_count": params["solves_count"],
                "strategy_level": params["strategy_level"],
                "branch_conditions": params["branch_conditions"],
                "question_type": question_type,
                "quest_id": None,
                "flow_count": None,
                "error": None,
            }
        )
    return items


def _split_csat_ranges(ranges: List[Dict[str, List[str]]]) -> Tuple[List[str], List[str]]:
    common = []
    optional = []
    for entry in ranges:
        key = (entry.get("key") or "").lower()
        tags = clean_tags(entry.get("tags", []))
        if not tags:
            continue
        if "common" in key or "공통" in key:
            common.extend(tags)
        elif "optional" in key or "선택" in key:
            optional.extend(tags)
        else:
            optional.extend(tags)
    return clean_tags(common), clean_tags(optional)


def _csat_tier_for_index(index: int, initial_tier: int) -> int:
    if index >= 29:
        return 5

    if initial_tier == 3:
        if 1 <= index <= 15:
            return _linear_between(1, 3, index - 1, 15)
        if 16 <= index <= 18:
            return _linear_between(1, 2, index - 16, 3)
        if 19 <= index <= 22:
            return _linear_between(2, 4, index - 19, 4)
        if 23 <= index <= 25:
            return _linear_between(1, 2, index - 23, 3)
        if 26 <= index <= 28:
            return _linear_between(2, 4, index - 26, 3)

    if initial_tier == 4:
        if 1 <= index <= 6:
            return _linear_between(1, 2, index - 1, 6)
        if 7 <= index <= 15:
            return _linear_between(2, 4, index - 7, 9)
        if 16 <= index <= 18:
            return _linear_between(1, 2, index - 16, 3)
        if 19 <= index <= 22:
            return _linear_between(2, 5, index - 19, 4)
        if 23 <= index <= 25:
            return _linear_between(1, 2, index - 23, 3)
        if 26 <= index <= 28:
            return _linear_between(2, 5, index - 26, 3)

    if initial_tier == 5:
        if 1 <= index <= 6:
            return _linear_between(1, 2, index - 1, 6)
        if 7 <= index <= 15:
            return _linear_between(3, 5, index - 7, 9)
        if 16 <= index <= 18:
            return _linear_between(1, 2, index - 16, 3)
        if 19 <= index <= 22:
            return _linear_between(3, 5, index - 19, 4)
        if 23 <= index <= 25:
            return _linear_between(1, 2, index - 23, 3)
        if 26 <= index <= 28:
            return _linear_between(3, 5, index - 26, 3)

    return max(1, min(5, initial_tier))


def _linear_between(min_tier: int, max_tier: int, index: int, count: int) -> int:
    if count <= 1:
        return max(1, min(5, min_tier))
    ratio = index / (count - 1)
    tier_value = min_tier + (max_tier - min_tier) * ratio
    return max(1, min(5, int(round(tier_value))))


def _pick_csat_tags(
    common_tags: Sequence[str],
    optional_tags: Sequence[str],
    tag_count: int,
    *,
    require_optional: bool,
) -> List[str]:
    common_tags = clean_tags(common_tags)
    optional_tags = clean_tags(optional_tags)
    if tag_count <= 0:
        return []

    results: List[str] = []
    if require_optional:
        if optional_tags:
            results.append(random.choice(optional_tags))
    else:
        if common_tags:
            results.append(random.choice(common_tags))

    remaining = max(0, tag_count - len(results))
    if remaining <= 0:
        return results

    if require_optional and tag_count >= 2 and optional_tags:
        target_optional = max(1, (tag_count + 1) // 2)
        optional_needed = max(0, target_optional - len(results))
        optional_needed = min(optional_needed, len(optional_tags))
        for _ in range(optional_needed):
            pick = random.choice(optional_tags)
            if pick not in results:
                results.append(pick)

    pool = common_tags + optional_tags
    random.shuffle(pool)
    for tag in pool:
        if len(results) >= tag_count:
            break
        if tag not in results:
            results.append(tag)

    return results[:tag_count]


def clean_tags(tags: Sequence[str]) -> List[str]:
    cleaned = []
    seen = set()
    for tag in tags:
        raw = (tag or "").strip()
        if not raw:
            continue
        if raw in seen:
            continue
        seen.add(raw)
        cleaned.append(raw)
    return cleaned


def _split_counts(total: int, subject_count: int) -> List[int]:
    base = total // subject_count
    remainder = total % subject_count
    return [base + (1 if i < remainder else 0) for i in range(subject_count)]


def _build_overlay_tags(subject_tags: List[List[str]], subject_idx: int) -> List[str]:
    overlay = []
    for idx, tags in enumerate(subject_tags):
        if idx == subject_idx:
            continue
        overlay.extend(tags)
    return clean_tags(overlay)


def _linear_tier(center: int, index: int, count: int) -> int:
    center = max(1, min(5, int(center)))
    if count <= 1:
        return center
    min_tier = max(1, center - 2)
    max_tier = min(5, center + 2)
    ratio = index / (count - 1)
    tier_value = min_tier + (max_tier - min_tier) * ratio
    return int(round(tier_value))


def _tier_params(tier: int) -> Dict[str, int]:
    tier = max(1, min(5, int(tier)))
    params = {
        1: {"solves_count": 2, "strategy_level": 1, "branch_conditions": 0},
        2: {"solves_count": 3, "strategy_level": 1, "branch_conditions": 0},
        3: {"solves_count": 4, "strategy_level": 2, "branch_conditions": 1},
        4: {"solves_count": 5, "strategy_level": 2, "branch_conditions": 1},
        5: {"solves_count": 6, "strategy_level": 3, "branch_conditions": 2},
    }
    return params[tier]


def _tier_tag_count(tier: int) -> int:
    tier = max(1, min(5, int(tier)))
    if tier == 1:
        return 1
    if tier == 2:
        return random.randint(1, 2)
    if tier == 3:
        return 2
    if tier == 4:
        return random.randint(2, 3)
    return 3


class TagDistributor:
    def __init__(self, tags: Sequence[str]) -> None:
        self.tags = list(tags)
        random.shuffle(self.tags)
        self._cursor = 0

    def pick(self, count: int, *, overlay: "TagDistributor | None" = None) -> List[str]:
        if not self.tags or count <= 0:
            return []
        results: List[str] = []

        if overlay and overlay.tags:
            overlay_pick = overlay._next_tag()
            if overlay_pick and overlay_pick not in results:
                results.append(overlay_pick)

        while len(results) < count:
            tag = self._next_tag()
            if tag and tag not in results:
                results.append(tag)
            if len(results) >= len(self.tags):
                break

        return results

    def _next_tag(self) -> str:
        tag = self.tags[self._cursor % len(self.tags)]
        self._cursor = (self._cursor + 1) % len(self.tags)
        return tag
