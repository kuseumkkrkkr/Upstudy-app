"""AI service layer.

Exports:
- AIProvider, KimiProvider, GeminiProvider, get_default_provider
- evaluate_request, rejected_response
- Prompt functions: course_proposal_prompt, quest_variant_prompt,
  solve_ocr_prompt, solve_grading_prompt, level_test_speed_prompt,
  level_test_power_prompt, rejection_check_prompt
"""

from services.ai.providers.base import (
    AIProvider,
    KimiProvider,
    GeminiProvider,
    get_default_provider,
)
from services.ai.guard import evaluate_request, rejected_response
from services.ai.prompts import (
    course_proposal_prompt,
    solve_ocr_prompt,
    solve_grading_prompt,
    quest_variant_prompt,
    level_test_speed_prompt,
    level_test_power_prompt,
    rejection_check_prompt,
)

__all__ = [
    "AIProvider",
    "KimiProvider",
    "GeminiProvider",
    "get_default_provider",
    "evaluate_request",
    "rejected_response",
    "course_proposal_prompt",
    "solve_ocr_prompt",
    "solve_grading_prompt",
    "quest_variant_prompt",
    "level_test_speed_prompt",
    "level_test_power_prompt",
    "rejection_check_prompt",
]
