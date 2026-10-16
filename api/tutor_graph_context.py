"""Bounded client-observed graph values; never grading or ownership evidence."""
from typing import Annotated
from pydantic import BaseModel, ConfigDict, Field, model_validator
from api.textbook_import import RESERVED


class GraphParameter(BaseModel):
    model_config = ConfigDict(extra='forbid')
    id: str = Field(pattern=r'^[A-Za-z][A-Za-z0-9_]{0,31}$')
    value: float = Field(strict=True, allow_inf_nan=False, ge=-1e9, le=1e9)
    min: float = Field(strict=True, allow_inf_nan=False, ge=-1e9, le=1e9)
    max: float = Field(strict=True, allow_inf_nan=False, ge=-1e9, le=1e9)

    @model_validator(mode='after')
    def bounds(self):
        if self.id in RESERVED | {'y', '__proto__'}:
            raise ValueError('Reserved parameter')
        if not self.min <= self.value <= self.max:
            raise ValueError('Out of range')
        return self


class GraphObservation(BaseModel):
    model_config = ConfigDict(extra='forbid')
    graph_id: str = Field(pattern=r'^page-[0-9]{1,6}-graph-[0-9]{1,2}$')
    parameters: list[GraphParameter] = Field(min_length=1, max_length=16)

    @model_validator(mode='after')
    def unique(self):
        if len({p.id for p in self.parameters}) != len(self.parameters):
            raise ValueError('Duplicate parameter')
        return self


GraphContext = Annotated[list[GraphObservation], Field(max_length=4)]
