import os
from google import genai
from baselines.basemodel import AIQuestResult


# =========================
# 환경 설정
# =========================

COMETAPI_KEY = os.environ.get("COMETAPI_KEY")
BASE_URL = "https://api.cometapi.com"

client = genai.Client(
    http_options={"api_version": "v1beta", "base_url": BASE_URL},
    api_key=COMETAPI_KEY,
)


# =========================
# AI 호출 로직
# =========================

def ai_gen(prompt: str) -> AIQuestResult:
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
        model="gemini-2.5-flash",
        contents=prompt,
        config={
            "response_mime_type": "application/json",
            "response_json_schema": AIQuestResult.model_json_schema(),
        },
    )
    
    # Remove markdown code block wrapper if present
    json_text = response.text
    if json_text.startswith("```"):
        # Remove leading ```json or ```
        json_text = json_text.lstrip("`").split("\n", 1)[-1]
    if json_text.endswith("```"):
        # Remove trailing ```
        json_text = json_text.rsplit("\n", 1)[0]
    
    # Parse and validate JSON
    import json
    parsed = json.loads(json_text)
    
    # Fix quest_model if it's a string instead of array
    if isinstance(parsed.get("quest_model"), str):
        parsed["quest_model"] = [parsed["quest_model"]]
    
    quest_data = AIQuestResult.model_validate(parsed)
    return quest_data
