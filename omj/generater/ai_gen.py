import json
import os
from google import genai
from baselines.basemodel import AIQuestResult, FormulaPlan
from env_loader import load_env

load_env()


# =========================
# 환경 설정
# =========================

COMETAPI_KEY = os.environ.get("COMETAPI_KEY")
BASE_URL = "https://api.cometapi.com"
DEFAULT_MODEL = "gemini-3.1-flash-lite"

client = genai.Client(
    http_options={"api_version": "v1beta", "base_url": BASE_URL},
    api_key=COMETAPI_KEY,
)


# =========================
# AI 호출 로직
# =========================

def _extract_json_text(raw: str) -> str:
    text = raw or ""
    if text.startswith("```"):
        text = text.lstrip("`").split("\n", 1)[-1]
    if text.endswith("```"):
        text = text.rsplit("\n", 1)[0]
    return text.strip()


def ai_gen(prompt: str, *, model: str = DEFAULT_MODEL) -> AIQuestResult:
    """
    AI를 통해 문제 생성
    
    Args:
        prompt: AI에게 전달할 프롬프트
        
    Returns:
        AIQuestResult: AI가 생성한 문제 데이터
    """
    if not COMETAPI_KEY:
        raise RuntimeError("COMETAPI_KEY is not set")

    response = client.models.generate_content(
        model=model,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_json_schema": AIQuestResult.model_json_schema(),
        },
    )
    
    # Remove markdown code block wrapper if present
    json_text = _extract_json_text(response.text or "")
    parsed = json.loads(json_text)
    
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
    if not COMETAPI_KEY:
        raise RuntimeError("COMETAPI_KEY is not set")

    response = client.models.generate_content(
        model=model,
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_json_schema": FormulaPlan.model_json_schema(),
        },
    )

    json_text = _extract_json_text(response.text or "")
    parsed = json.loads(json_text)
    return FormulaPlan.model_validate(parsed)
