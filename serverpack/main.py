from fastapi import FastAPI, Query
import json
from typing import List, Optional
from gpt import generate_completions, rewrite_sentence, generate_sentence_suggestions

app = FastAPI()

@app.get("/prompt")
async def get_prompt():
    """
    프롬프트 페이지를 반환합니다.
    """
    return {"status": "ok"}

@app.post("/prompt")
async def process_prompt(
    prompt: str = Query("", description="The text to process"),
    model: str = Query("gpt", description="The model to use (gpt or gemini)")
):
    """
    텍스트를 처리하고 개선된 버전을 반환합니다.
    """
    if not prompt:
        return {"error": "프롬프트가 비어있습니다"}
    
    try:
        result = await rewrite_sentence(prompt)
        return result
    except Exception as e:
        return {"error": str(e)}

@app.get("/sentence-complete")
async def sentence_complete(
    context: str = Query(..., description="The current word or phrase to complete"),
    full_text: str = Query(..., description="The full text in the editor"),
    max_suggestions: int = Query(3, description="Maximum number of suggestions to return")
) -> List[str]:
    """
    자동 완성 제안을 생성하는 엔드포인트
    """
    print(f"[자동완성 요청 받음] context: {context}, full_text 길이: {len(full_text)}, max_suggestions: {max_suggestions}")
    
    try:
        suggestions = await generate_sentence_suggestions(
            context=context,
            max_suggestions=max_suggestions,
            full_text=full_text
        )
        print(f"[자동완성 응답] 생성된 제안: {suggestions}")
        return suggestions
    except Exception as e:
        print(f"Error in sentence_complete: {e}")
        return []
