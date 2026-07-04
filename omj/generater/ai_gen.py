from baselines.basemodel import AIQuestResult, FormulaPlan
from env_loader import load_env
from services.ai.sam_client import (
    DEFAULT_PROBLEM_MODEL,
    SAM_API_KEY_ENV,
    generate_json,
    is_sam_configured,
)

load_env()


# =========================
# 환경 설정
# =========================

DEFAULT_MODEL = DEFAULT_PROBLEM_MODEL


# =========================
# AI 호출 로직
# =========================

def ai_gen(prompt: str, *, model: str = DEFAULT_MODEL) -> AIQuestResult:
    """
    AI를 통해 문제 생성
    
    Args:
        prompt: AI에게 전달할 프롬프트
        
    Returns:
        AIQuestResult: AI가 생성한 문제 데이터
    """
    if not is_sam_configured():
        raise RuntimeError(f"{SAM_API_KEY_ENV} is not set")

    parsed = generate_json(
        model=model,
        prompt=prompt,
        schema=AIQuestResult,
    )

    # Fix quest_model if it's a string instead of array
    if isinstance(parsed.get("quest_model"), str):
        parsed["quest_model"] = [parsed["quest_model"]]
    
    quest_data = AIQuestResult.model_validate(parsed)
    return quest_data


def ai_gen_formula_plan(prompt: str, *, model: str = DEFAULT_MODEL) -> FormulaPlan:
    """
    AI를 통해 공식 설계(1차 호출) 생성

    Args:
        prompt: AI에게 전달할 프롬프트

    Returns:
        FormulaPlan: 수식 설계 데이터
    """
    if not is_sam_configured():
        raise RuntimeError(f"{SAM_API_KEY_ENV} is not set")

    parsed = generate_json(
        model=model,
        prompt=prompt,
        schema=FormulaPlan,
    )

    return FormulaPlan.model_validate(parsed)
