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
            "다항식연산",
            "다항식덧셈뺄셈",
            "다항식곱셈",
            "곱셈공식",
            "완전제곱식",
            "합차공식",
            "세제곱공식",
            "다항식나눗셈",
            "몫과나머지",
            "조립제법",
            "항등식",
            "미정계수법",
            "나머지정리",
            "인수정리",
            "인수분해",
            "고차식인수분해",
            "복소수",
            "허수단위",
            "복소수연산",
            "켤레복소수",
            "이차방정식풀이",
            "이차방정식인수분해",
            "완성제곱법",
            "근의공식",
            "이차방정식판별식",
            "이차방정식중근",
            "이차방정식실근조건",
            "근과계수관계",
            "이차함수그래프",
            "이차함수축과꼭짓점",
            "이차함수평행이동",
            "이차함수대칭이동",
            "이차함수최대최소",
            "이차함수정의역최대최소",
            "이차함수와이차방정식",
            "이차함수와이차부등식",
            "이차부등식풀이",
            "합의법칙",
            "곱의법칙",
            "순열",
            "팩토리얼",
            "중복순열",
            "원순열",
            "조합",
            "조합의성질",
            "중복조합기초",
            "행렬의정의",
            "행렬성분",
            "행렬덧셈뺄셈",
            "행렬스칼라곱",
            "행렬곱셈",
            "역행렬",
            "연립방정식과행렬",
            "가우스소거법",
        },
    },
    {
        "code": 2,
        "grade": 11,
        "name": "common-math-2",
        "tags": {
            "두점사이거리",
            "선분내분점",
            "선분외분점",
            "선분중점",
            "직선기울기",
            "직선의방정식",
            "두점지나는직선",
            "두직선평행",
            "두직선수직",
            "두직선일치",
            "점과직선거리",
            "원의방정식",
            "원중심과반지름",
            "원일반형",
            "원평행이동",
            "원대칭이동",
            "집합표현",
            "집합연산",
            "부분집합",
            "진부분집합",
            "명제참거짓",
            "명제의역",
            "명제의이",
            "명제의대우",
            "필요조건",
            "충분조건",
            "필요충분조건",
            "함수의정의",
            "함수정의역공역치역",
            "합성함수",
            "역함수",
            "일대일함수",
            "일대일대응",
            "역함수그래프",
            "유리식계산",
            "유리함수그래프",
            "유리함수점근선",
            "유리함수평행이동",
            "무리식계산",
            "무리식유리화",
            "무리함수그래프",
            "무리함수정의역",
            "무리함수평행이동",
        },
    },
    {
        "code": 3,
        "grade": 12,
        "name": "algebra",
        "tags": {
            "지수의확장",
            "정수지수",
            "유리수지수",
            "실수지수",
            "지수법칙",
            "지수함수",
            "지수함수그래프",
            "지수함수평행이동",
            "로그의정의",
            "로그의밑과진수",
            "로그법칙",
            "로그밑변환",
            "상용로그",
            "로그함수",
            "로그함수그래프",
            "로그함수평행이동",
            "지수방정식",
            "지수부등식",
            "로그방정식",
            "로그부등식",
            "로그진수조건",
            "수열의정의",
            "수열일반항",
            "등차수열",
            "등차수열일반항",
            "등차수열합",
            "등차중항",
            "등비수열",
            "등비수열일반항",
            "등비수열합",
            "등비중항",
            "시그마",
            "시그마성질",
            "자연수거듭제곱합",
            "계차수열",
            "수열부분분수",
            "수학적귀납법",
        },
    },
    {
        "code": 4,
        "grade": 13,
        "name": "calculus-1",
        "tags": {
            "함수의극한",
            "좌극한우극한",
            "극한의사칙연산",
            "극한인수분해",
            "극한유리화",
            "무한대극한",
            "함수의연속",
            "불연속",
            "연속함수성질",
            "중간값정리",
            "미분계수",
            "미분계수기하의미",
            "도함수",
            "미분가능성",
            "거듭제곱미분",
            "상수배미분",
            "합차미분",
            "접선의방정식",
            "접선기울기",
            "함수증가감소",
            "도함수부호",
            "함수극대극소",
            "극값판정",
            "미분최대최소",
            "미분활용최적화",
            "직선운동위치",
            "직선운동속도",
            "직선운동가속도",
            "부정적분",
            "부정적분공식",
            "부정적분성질",
            "정적분",
            "구분구적법",
            "미적분기본정리",
            "정적분선형성",
            "정적분구간분할",
            "정적분넓이",
            "두곡선사이넓이",
            "정적분속도거리",
            "정적분위치변화량",
        },
    },
    {
        "code": 5,
        "grade": 14,
        "name": "probability-statistics",
        "tags": {
            "확통중복조합",
            "이항정리",
            "이항계수",
            "파스칼삼각형",
            "이항정리활용",
            "수학적확률",
            "통계적확률",
            "확률의성질",
            "확률덧셈정리",
            "배반사건",
            "여사건",
            "확률곱셈정리",
            "조건부확률",
            "사건의독립",
            "종속사건",
            "독립시행확률",
            "확률변수",
            "이산확률변수",
            "연속확률변수",
            "확률질량함수",
            "확률밀도함수",
            "확률변수기댓값",
            "확률변수분산",
            "확률변수표준편차",
            "이항분포",
            "베르누이시행",
            "이항분포평균분산",
            "정규분포",
            "표준정규분포",
            "정규분포표",
            "모집단과표본",
            "표본추출",
            "표본크기",
            "표본평균",
            "표본평균분포",
            "표본평균기댓값",
            "표본평균표준편차",
            "모평균추정",
            "점추정",
            "구간추정",
            "신뢰구간",
            "신뢰도",
        },
    },
    {
        "code": 6,
        "grade": 15,
        "name": "calculus-2",
        "tags": {
            "호도법",
            "일반각",
            "삼각함수값",
            "사인함수그래프",
            "코사인함수그래프",
            "탄젠트함수그래프",
            "삼각함수주기",
            "삼각함수대칭성",
            "삼각함수미분",
            "삼각함수적분",
            "합성함수미분",
            "연쇄법칙",
            "곱의미분법",
            "몫의미분법",
            "매개변수미분",
            "음함수미분",
            "이계도함수",
            "치환적분법",
            "부분적분법",
            "유리함수적분",
            "무리함수적분",
            "급수수렴발산",
            "급수부분합",
            "급수의합",
            "급수수렴조건",
            "멱급수",
            "멱급수수렴반경",
            "테일러급수",
            "테일러전개",
            "매클로린급수",
            "평면운동속도벡터",
            "평면운동가속도벡터",
            "등속운동",
            "등가속도운동",
            "곡선의길이",
            "편도함수",
            "편미분계산",
        },
    },
    {
        "code": 7,
        "grade": 16,
        "name": "geometry",
        "tags": {
            "포물선",
            "포물선방정식",
            "포물선초점준선",
            "타원",
            "타원방정식",
            "타원초점",
            "쌍곡선",
            "쌍곡선방정식",
            "쌍곡선점근선",
            "평면벡터연산",
            "평면벡터성분",
            "위치벡터",
            "평면벡터내적",
            "벡터수직조건",
            "벡터직선방정식",
            "공간좌표",
            "공간거리",
            "공간내분점",
            "공간벡터연산",
            "공간벡터내적",
            "공간벡터정사영",
            "공간직선방정식",
            "평면의방정식",
            "법선벡터",
            "구의방정식",
        },
    },
    {
        "code": 8,
        "grade": 9,
        "name": "foundation",
        "tags": {
            "기초정수연산",
            "기초분수연산",
            "기초소수연산",
            "기초문자식",
            "기초대입",
            "기초다항식계산",
            "기초일차식계산",
            "기초일차방정식",
            "기초일차방정식활용",
            "기초일차부등식",
            "기초일차부등식활용",
            "기초부등식성질",
            "기초일차함수",
            "기초기울기절편",
            "기초함수그래프",
            "기초그래프해석",
            "기초비와비율",
            "기초백분율",
            "기초비례식",
            "기초점선면",
            "기초각",
            "기초평행수직",
            "기초합동닮음",
            "기초이차방정식",
            "기초인수분해",
            "기초완전제곱",
            "기초이차함수",
            "기초포물선",
            "기초최대최소",
            "기초경우의수",
            "기초합의법칙",
            "기초곱의법칙",
            "기초도수분포표",
            "기초평균",
            "기초중앙값",
            "기초최빈값",
            "기초히스토그램",
            "기초확률",
            "기초집합표현",
            "기초원소부분집합",
            "기초함수",
            "기초함수값",
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


def generation_tag_groups() -> List[dict]:
    labels = {
        "common-math-1": "공통수학1",
        "common-math-2": "공통수학2",
        "algebra": "대수",
        "calculus-1": "미적분Ⅰ",
        "probability-statistics": "확률과 통계",
        "calculus-2": "미적분Ⅱ",
        "geometry": "기하",
        "foundation": "기초·선수학습",
    }
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
                "label": labels.get(name, name),
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
