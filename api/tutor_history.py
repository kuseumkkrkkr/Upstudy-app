"""Bounded client-carried tutor history, never system instructions or permissions."""
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, Field


class TutorTurn(BaseModel):
    """One untrusted plain-text turn; no model tools or system-role fields."""
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    role: Literal['user', 'assistant']
    content: str = Field(min_length=1, max_length=2000)


def _bounds(turns):
    """Reject orphan/reordered turns and excessive total context before provider I/O."""
    if len(turns) % 2 or any(turn.role != ('user' if i % 2 == 0 else 'assistant')
                             for i, turn in enumerate(turns)):
        raise ValueError('History must contain complete user/assistant exchanges')
    if sum(len(turn.content) for turn in turns) > 6000:
        raise ValueError('History exceeds 6000 characters')
    return turns


TutorHistory = Annotated[list[TutorTurn], Field(max_length=8), AfterValidator(_bounds)]
