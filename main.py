from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional, Dict, Any
import os
import json
import asyncio

# 모델 imports
from serverpack.models import AutocompleteRequest, SentenceCompleteRequest, RewriteRequest, RewriteResponse
from serverpack import gemini, gpt

# =============================
# FastAPI 앱 생성
# =============================
app = FastAPI(
    title="AI Autocomplete API",
    description="Gemini/GPT 기반 자동완성/문장완성/문장리라이팅 API 서버",
    version="2025.8"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =============================
# 환경 변수 및 상수
# =============================
SAVED_PROMPT = ""  # 저장된 프롬프트를 메모리에 보관

# =============================
# 기본 단어 데이터 (Fallback)
# =============================
WORDS = [
    "apple", "application", "apply", "approve", "april",
    "banana", "band", "bank", "basic", "beach",
    "cherry", "chair", "change", "check", "choice",
    "durian", "dance", "data", "day", "deep",
    # ... 나머지 단어들
]

def fallback_autocomplete(query: str, max_results: int = 5) -> List[str]:
    q = query.lower().strip()
    if not q:
        return []
    exact_matches = [w for w in WORDS if w.lower() == q]
    starts_with = [w for w in WORDS if w.lower().startswith(q) and w.lower() != q]
    contains = [w for w in WORDS if q in w.lower() and not w.lower().startswith(q)]
    results = exact_matches + starts_with + contains
    return list(dict.fromkeys(results))[:max_results]

# =============================
# API 라우트
# =============================
@app.get("/autocomplete", response_model=List[str])
async def autocomplete(
    q: str = Query(..., description="검색할 문자열"),
    max_results: int = Query(5, ge=1, le=10),
    model: str = Query("gemini", description="사용할 AI 모델 (gemini 또는 gpt)"),
    context: Optional[str] = Query(None, description="추가 컨텍스트")
):
    if not q.strip():
        return []
        
    if model == "gemini" and gemini.GEMINI_API_KEY:
        return await gemini.generate_completions(q, max_results, context)
    elif model == "gpt" and gpt.OPENAI_API_KEY:
        return await gpt.generate_completions(q, max_results, context)
    return fallback_autocomplete(q, max_results)

@app.post("/autocomplete", response_model=List[str])
async def autocomplete_post(request: AutocompleteRequest):
    if not request.query.strip():
        return []
        
    if request.model == "gemini" and gemini.GEMINI_API_KEY:
        return await gemini.generate_completions(request.query, request.max_results, request.context)
    elif request.model == "gpt" and gpt.OPENAI_API_KEY:
        return await gpt.generate_completions(request.query, request.max_results, request.context)
    return fallback_autocomplete(request.query, request.max_results)

@app.post("/complete", response_model=str)
@app.get("/sentence-complete", response_model=List[str])
async def sentence_complete(
    context: str = Query(..., description="문장 컨텍스트"),
    full_text: str = Query(None, description="전체 텍스트"),
    max_suggestions: int = Query(3, ge=1, le=10, description="최대 제안 수"),
    model: str = Query("gemini", description="사용할 AI 모델 (gemini 또는 gpt)"),
    text: str = None,  # POST 요청용
):
    """문장 완성 엔드포인트 - GET/POST 모두 지원"""
    # POST 요청 처리
    if text:
        request_text = text.strip()
        if not request_text:
            return request_text
            
        if model == "gemini" and gemini.GEMINI_API_KEY:
            return await gemini.complete_sentence(request_text, context)
        elif model == "gpt" and gpt.OPENAI_API_KEY:
            return await gpt.complete_sentence(request_text, context)
        return request_text

    # GET 요청 처리
    if not context.strip():
        return []

    try:
        # Gemini 비활성화, GPT만 사용
        if gpt.OPENAI_API_KEY:
            suggestions = await gpt.generate_sentence_suggestions(
                context,
                max_suggestions,
                full_text
            )
        else:
            return []

        return suggestions[:max_suggestions]

    except Exception as e:
        print(f"문장 완성 오류: {str(e)}")
        return []

@app.post("/rewrite", response_model=RewriteResponse)
async def sentence_rewrite(request: RewriteRequest):
    """텍스트를 다시 작성하고 diff를 생성합니다."""
    text = request.text.strip()
    
    # 저장된 모델 설정을 사용
    model = SAVED_MODEL
    
    print("\n" + "="*60)
    print("[REWRITE 요청]")
    print(f"길이: {len(text)}자")
    print(f"스타일: {request.style}")
    print(f"모델: {model}")  # 실제 사용할 모델 표시
    print("-"*60)
    print(text)
    print("="*60)
    
    if not text:
        return RewriteResponse(diffs=[], error="텍스트를 입력해주세요")
    
    try:
        if model == "gemini" and gemini.GEMINI_API_KEY:
            result = await gemini.rewrite_sentence(text, request.style)
        elif model == "gpt" and gpt.OPENAI_API_KEY:
            result = await gpt.rewrite_sentence(text, request.style)
        else:
            return RewriteResponse(diffs=[], error="사용 가능한 AI 모델이 없습니다")
            
        print("\n[AI 응답]")
        print("-"*60)
        print(str(result)[:500] + "..." if len(str(result)) > 500 else str(result))
        print("-"*60)
        
        return RewriteResponse(**result)
            
    except Exception as e:
        error_msg = str(e)
        print(f"[처리 오류] {error_msg}")
        
        # API 키나 할당량 관련 오류 메시지를 더 명확하게
        if "exceeded your current quota" in error_msg:
            if model == "gemini":
                return RewriteResponse(diffs=[], error="Gemini API 할당량이 초과되었습니다. GPT로 전환해보세요.")
            else:
                return RewriteResponse(diffs=[], error="GPT API 할당량이 초과되었습니다. Gemini로 전환해보세요.")
                
        return RewriteResponse(diffs=[], error=f"처리 중 오류가 발생했습니다: {error_msg}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

# =============================
# 프롬프트 관리
# =============================
SAVED_MODEL = "gpt"  # 선택된 모델을 GPT로 변경

@app.get("/prompt", response_model=Dict[str, Any])
async def get_prompt():
    """저장된 프롬프트를 반환합니다."""
    return {
        "prompt": SAVED_PROMPT,
        "model": SAVED_MODEL
    }

@app.post("/prompt")
async def save_prompt(
    prompt: str = Query("", description="저장할 프롬프트"),
    model: str = Query("gemini", description="사용할 AI 모델")
):
    """프롬프트를 저장합니다."""
    global SAVED_PROMPT, SAVED_MODEL
    SAVED_PROMPT = prompt
    SAVED_MODEL = model
    return {"status": "success", "prompt": prompt, "model": model}

# =============================
# 서버 실행
# =============================
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
