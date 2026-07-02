from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field, model_validator


# =========================
# Domain Models
# =========================


class ContentBlock(BaseModel):
    type: Literal["text", "latex"]
    content: str


class ContentBlocks(BaseModel):
    blocks: List[ContentBlock] = Field(default_factory=list)

    @model_validator(mode="before")
    @classmethod
    def _coerce_input(cls, value: Any) -> Any:
        if value is None:
            return {"blocks": []}
        if isinstance(value, str):
            if not value:
                return {"blocks": []}
            return {"blocks": [{"type": "text", "content": value}]}
        if isinstance(value, list):
            return {"blocks": value}
        if isinstance(value, dict):
            if "blocks" in value:
                return value
            if "type" in value and "content" in value:
                return {"blocks": [value]}
        return value


class QuestModel(BaseModel):
    models: List[str] = Field(..., description="Models used to solve the quest")


class QuestHeader(BaseModel):
    quest_id: str = Field(..., description="Quest identifier")
    quest_model: QuestModel = Field(..., description="Models used when generating the quest")


class QuestInfo(BaseModel):
    main: int = Field(..., description="Primary subject code")
    sub: List[str] = Field(..., description="Problem types")
    hash_tag: List[str] = Field(..., description="Hashtags describing the quest")
    flow_rate: int = Field(..., description="Number of solve flows, including branches")
    difficulty: int = Field(..., description="Overall difficulty score")
    main_huddle: int = Field(..., ge=0, le=10, description="Requested strategy difficulty level")


class QuestData(BaseModel):
    quest_title: ContentBlocks = Field(..., description="Problem statement blocks")
    quest_image: Optional[str] = Field(None, description="Optional path or URL to reference image")
    quest_answer: Optional[ContentBlocks] = Field(None, description="Final answer blocks")


class SolveStep(BaseModel):
    flow: ContentBlocks = Field(..., description="Step-by-step solving flow description blocks")
    hash_tag: List[str] = Field(..., description="Hashtags applicable to this step")
    hint_riddle: ContentBlocks = Field(..., description="Hint blocks")
    answer_riddle: ContentBlocks = Field(..., description="Answer explanation blocks")
    enter_huddle: int = Field(..., ge=0, le=10, description="Per-step solving difficulty")
    branches: List["SolveStep"] = Field(
        default_factory=list,
        description="Conditional sub-flows to follow when branches are taken",
    )


# =========================
# AI Models (DTO)
# =========================


class AISolveStep(BaseModel):
    flow: ContentBlocks
    hint_riddle: ContentBlocks
    answer_riddle: ContentBlocks
    hash_tag: List[str] = Field(
        default_factory=list,
        description="Hashtags applicable to this step",
    )
    enter_huddle: int = Field(..., ge=0, le=10)
    branches: List["AISolveStep"] = Field(
        default_factory=list,
        description="Conditional sub-flows to follow when branches are taken",
    )


class AIQuestResult(BaseModel):
    quest_title: ContentBlocks = Field(..., description="Quest body blocks")
    quest_answer: Optional[ContentBlocks] = Field(None, description="Final answer blocks")
    quest_model: List[str] = Field(..., description="Model names used when generating the quest")
    main_huddle: int = Field(..., ge=0, le=10, description="Requested strategy difficulty level")
    primary_hash_tag: str = Field("", description="Most representative hash tag for the quest")
    quest_image: Optional[str] = Field(None, description="Optional quest image path or URL")
    solves: List[AISolveStep]


class FormulaPlan(BaseModel):
    answer_vars: List[str] = Field(..., description="Answer variable symbols.")
    equations: List[str] = Field(..., description="SymPy equations in order.")
    guardrails: List[str] = Field(
        default_factory=list,
        description="SymPy-compatible constraints, e.g., a != 0, x > 0.",
    )
    ranges: Dict[str, List[int]] = Field(
        default_factory=dict,
        description="Variable ranges for random sampling, e.g., {\"a\": [-9, 9]}.",
    )


# Resolve forward references for recursive models
AISolveStep.model_rebuild()
SolveStep.model_rebuild()


# =========================
# Conversion helpers
# =========================


def convert_solve_steps(ai_solves: List[AISolveStep], hash_tag: List[str]) -> List[SolveStep]:
    """Convert AI solve steps into domain solve steps, preserving branches."""

    def _convert(step: AISolveStep) -> SolveStep:
        return SolveStep(
            flow=step.flow,
            hash_tag=hash_tag,
            hint_riddle=step.hint_riddle,
            answer_riddle=step.answer_riddle,
            enter_huddle=step.enter_huddle,
            branches=[_convert(branch) for branch in step.branches],
        )

    return [_convert(step) for step in ai_solves]


def build_quest_header(ai: AIQuestResult, quest_id: str) -> QuestHeader:
    return QuestHeader(
        quest_id=quest_id,
        quest_model=QuestModel(models=ai.quest_model),
    )


def build_quest_info(
    *,
    ai: AIQuestResult,
    main: int,
    sub: List[str],
    hash_tag: List[str],
    flow_rate: int,
    difficulty: int,
) -> QuestInfo:
    return QuestInfo(
        main=main,
        sub=sub,
        hash_tag=hash_tag,
        flow_rate=flow_rate,
        difficulty=difficulty,
        main_huddle=ai.main_huddle,
    )


def build_quest_data(ai: AIQuestResult) -> QuestData:
    return QuestData(
        quest_title=ai.quest_title,
        quest_image=ai.quest_image,
        quest_answer=ai.quest_answer or None,
    )


def blocks_to_text(blocks: Optional[ContentBlocks]) -> str:
    if not blocks or not blocks.blocks:
        return ""
    return " ".join(block.content for block in blocks.blocks if block.content)


# ========================
# Assembly helper
# ========================


def assemble_quest(
    *,
    quest_id: str,
    ai_result: AIQuestResult,
    main: int,
    sub: List[str],
    hash_tag: List[str],
    flow_rate: int,
    difficulty: int,
):
    """
    Assemble a quest dict from AIQuestResult and domain-specific values.
    """
    header = build_quest_header(ai_result, quest_id)
    info = build_quest_info(
        ai=ai_result,
        main=main,
        sub=sub,
        hash_tag=hash_tag,
        flow_rate=flow_rate,
        difficulty=difficulty,
    )
    data = build_quest_data(ai_result)
    solves = convert_solve_steps(ai_result.solves, hash_tag)

    return {
        "header": header,
        "info": info,
        "data": data,
        "solves": solves,
    }
