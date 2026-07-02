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

SUBJECT_TAG_RULES = [
    {
        "code": 1,
        "grade": 10,
        "name": "common-math-1",
        "tags": {
            "공통수학1",
            "다항식",
            "다항식의연산",
            "다항식의덧셈",
            "다항식의뺄셈",
            "다항식의곱셈",
            "곱셈공식",
            "완전제곱식",
            "합차공식",
            "세제곱공식",
            "다항식의나눗셈",
            "몫과나머지",
            "조립제법",
            "항등식",
            "항등식의성질",
            "미정계수법",
            "나머지정리",
            "나머지정리증명",
            "나머지정리활용",
            "인수정리",
            "인수정리증명",
            "인수정리활용",
            "인수분해",
            "인수분해공식",
            "고차식인수분해",
            "복소수",
            "허수단위",
            "실수와허수",
            "복소수의연산",
            "켤레복소수",
            "이차방정식",
            "이차방정식의풀이",
            "인수분해법",
            "완성제곱법",
            "근의공식",
            "이차방정식의판별식",
            "판별식과근의개수",
            "중근조건",
            "실근조건",
            "이차방정식의근과계수",
            "근과계수의관계",
            "두근의합",
            "두근의곱",
            "이차함수",
            "이차함수의그래프",
            "포물선",
            "축",
            "꼭짓점",
            "y절편",
            "이차함수의평행이동",
            "이차함수의대칭이동",
            "이차함수의최대최소",
            "최댓값",
            "최솟값",
            "정의역에서의최대최소",
            "이차함수와이차방정식",
            "이차함수와이차부등식",
            "이차부등식",
            "이차부등식의풀이",
            "이차부등식의해",
            "경우의수",
            "합의법칙",
            "사건의합",
            "곱의법칙",
            "사건의곱",
            "순열",
            "순열의수",
            "팩토리얼",
            "중복순열",
            "원순열",
            "조합",
            "조합의수",
            "조합의성질",
            "중복조합",
            "행렬",
            "행렬의정의",
            "행",
            "열",
            "성분",
            "행렬의연산",
            "행렬의덧셈",
            "행렬의뺄셈",
            "행렬의곱셈",
            "스칼라곱",
            "역행렬",
            "역행렬의정의",
            "역행렬의성질",
            "역행렬구하기",
            "연립일차방정식과행렬",
            "행렬을이용한연립방정식",
            "가우스소거법",
        },
    },
    {
        "code": 2,
        "grade": 11,
        "name": "common-math-2",
        "tags": {
            "공통수학2",
            "좌표평면",
            "두점사이의거리",
            "거리공식",
            "선분의내분점",
            "내분점공식",
            "외분점",
            "중점",
            "직선의방정식",
            "기울기",
            "절편",
            "점기울기형",
            "두점을지나는직선",
            "두직선의위치관계",
            "평행조건",
            "수직조건",
            "일치조건",
            "점과직선사이의거리",
            "원의방정식",
            "원의표준형",
            "중심",
            "반지름",
            "원의일반형",
            "일반형을표준형으로",
            "평행이동",
            "x방향이동",
            "y방향이동",
            "대칭이동",
            "x축대칭",
            "y축대칭",
            "원점대칭",
            "직선대칭",
            "집합",
            "집합의표현",
            "원소나열법",
            "조건제시법",
            "집합의연산",
            "합집합",
            "교집합",
            "차집합",
            "여집합",
            "집합의포함관계",
            "부분집합",
            "진부분집합",
            "명제",
            "명제의참거짓",
            "명제의역과대우",
            "역",
            "대우",
            "이",
            "충분조건과필요조건",
            "필요조건",
            "충분조건",
            "필요충분조건",
            "함수",
            "함수의정의",
            "정의역",
            "공역",
            "치역",
            "대응",
            "합성함수",
            "합성함수의정의",
            "합성함수의성질",
            "역함수",
            "일대일함수",
            "일대일대응",
            "역함수구하기",
            "역함수의그래프",
            "유리식과유리함수",
            "유리식",
            "유리식의계산",
            "약분",
            "통분",
            "유리함수의그래프",
            "점근선",
            "쌍곡선",
            "유리함수의평행이동",
            "무리식과무리함수",
            "무리식",
            "무리식의계산",
            "유리화",
            "무리함수의그래프",
            "무리함수의평행이동",
        },
    },
    {
        "code": 3,
        "grade": 12,
        "name": "algebra",
        "tags": {
            "대수",
            "지수",
            "지수의확장",
            "정수지수",
            "유리수지수",
            "실수지수",
            "지수법칙",
            "지수법칙의성질",
            "지수함수",
            "지수함수의그래프",
            "지수함수의성질",
            "지수함수의평행이동",
            "로그",
            "로그의정의",
            "밑",
            "진수",
            "로그의성질",
            "로그법칙",
            "밑의변환",
            "상용로그",
            "로그함수",
            "로그함수의그래프",
            "로그함수의성질",
            "로그함수의평행이동",
            "지수방정식과지수부등식",
            "지수방정식",
            "지수부등식",
            "로그방정식과로그부등식",
            "로그방정식",
            "로그부등식",
            "진수조건",
            "수열",
            "수열의정의",
            "항",
            "일반항",
            "수열의표현",
            "등차수열",
            "공차",
            "등차수열의일반항",
            "등차수열의합",
            "등차중항",
            "등비수열",
            "공비",
            "등비수열의일반항",
            "등비수열의합",
            "등비중항",
            "합의기호시그마",
            "시그마의성질",
            "시그마공식",
            "여러가지수열의합",
            "자연수의거듭제곱의합",
            "계차수열",
            "부분분수",
            "수학적귀납법",
            "귀납법의원리",
            "귀납법증명",
        },
    },
    {
        "code": 4,
        "grade": 13,
        "name": "calculus-1",
        "tags": {
            "미적분Ⅰ",
            "함수의극한",
            "극한의정의",
            "좌극한",
            "우극한",
            "극한의성질",
            "극한의사칙연산",
            "극한값계산",
            "인수분해를이용한극한",
            "유리화를이용한극한",
            "무한대의극한",
            "함수의연속",
            "연속의정의",
            "불연속",
            "연속함수의성질",
            "중간값정리",
            "미분계수",
            "미분계수의정의",
            "미분계수의기하적의미",
            "도함수",
            "도함수의정의",
            "미분가능",
            "도함수공식",
            "거듭제곱의미분",
            "상수배의미분",
            "합차의미분",
            "접선의방정식",
            "접선의기울기",
            "접선방정식구하기",
            "함수의증가와감소",
            "증가함수",
            "감소함수",
            "도함수의부호",
            "함수의극대와극소",
            "극댓값",
            "극솟값",
            "극값의판정",
            "미분과최대최소",
            "최댓값",
            "최솟값",
            "최대최소문제",
            "속도와가속도",
            "위치함수",
            "속도",
            "가속도",
            "부정적분",
            "부정적분의정의",
            "부정적분공식",
            "부정적분의성질",
            "정적분",
            "정적분의정의",
            "구분구적법",
            "정적분의계산",
            "미적분의기본정리",
            "정적분의성질",
            "정적분의선형성",
            "구간의분할",
            "정적분과넓이",
            "곡선과x축사이의넓이",
            "두곡선사이의넓이",
            "정적분과속도",
            "속도와거리",
            "위치변화량",
        },
    },
]


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
