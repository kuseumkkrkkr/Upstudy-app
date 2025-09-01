from typing import List, Optional
from pydantic import BaseModel

class AutocompleteRequest(BaseModel):
    query: str
    max_results: Optional[int] = 5
    context: Optional[str] = None
    model: str = "gemini"  # "gemini" 또는 "gpt"

class SentenceCompleteRequest(BaseModel):
    text: str
    context: Optional[str] = None
    model: str = "gemini"  # "gemini" 또는 "gpt"

class RewriteRequest(BaseModel):
    text: str
    style: Optional[str] = "concise"
    model: str = "gemini"  # "gemini" 또는 "gpt"

class DiffItem(BaseModel):
    type: str  # "deletion" 또는 "addition"
    text: str
    reason: str

class RewriteResponse(BaseModel):
    diffs: List[DiffItem]
    error: Optional[str] = None
