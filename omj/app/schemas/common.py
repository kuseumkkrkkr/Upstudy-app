"""Common schemas shared across all API routes.

Provides:
- ApiResponse: unified envelope for every API response
- JobStatus: state machine for async generation jobs
- RejectionReason: structured reason when AI refuses a request
"""
from enum import Enum
from typing import Any, Optional
from pydantic import BaseModel, Field


class JobStatus(str, Enum):
    queued = "queued"
    generating = "generating"
    done = "done"
    failed = "failed"
    rejected = "rejected"


class SafetyFlag(str, Enum):
    harmful_content = "harmful_content"
    excessive_request = "excessive_request"
    dangerous_code = "dangerous_code"
    unsupported_language = "unsupported_language"


class RejectionReason(BaseModel):
    flag: SafetyFlag
    detail: str = Field(..., description="Human-readable rejection explanation")
    suggestion: Optional[str] = Field(None, description="Actionable suggestion for the user")


class ApiResponse(BaseModel):
    status: JobStatus = JobStatus.done
    data: Optional[Any] = None
    job_id: Optional[str] = None
    rejection_reason: Optional[RejectionReason] = None
    safety_flags: list[SafetyFlag] = Field(default_factory=list)
    generated_by: Optional[str] = Field(None, description="Model/provider identifier")
    error: Optional[str] = None
    message: Optional[str] = None
