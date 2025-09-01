import os
import json
import asyncio
import google.generativeai as genai
from typing import List, Optional
from google.genai.types import GenerateContentConfig

# API 키 설정
GEMINI_API_KEY = "AIzaSyCxYPDh6HYNf7yYouWDo2x6EbhQ2z5fiHQ"
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

def extract_text_from_response(response) -> str:
    if response and hasattr(response, 'text'):
        return response.text.strip()
    elif response and hasattr(response, 'candidates'):
        texts = []
        for part in response.candidates[0].content.parts:
            texts.append(part.text.strip())
        return "\n".join(texts)
    return ""

async def generate_completions(query: str, max_results: int = 5, context: Optional[str] = None) -> List[str]:
    try:
        model = genai.GenerativeModel("gemini-1.5-pro")
        prompt = f"""
주어진 부분 단어 "{query}"에 대해 {max_results}개의 자동완성 제안을 생성해주세요.

조건:
1. 일반적이고 유용한 영어 단어를 제안
2. "{query}"로 시작하거나 관련성이 높은 단어
3. 한 줄에 하나씩만 출력
4. 번호/설명 제외
"""
        if context:
            prompt += f"\n추가 컨텍스트: {context}"

        response = await asyncio.to_thread(model.generate_content, prompt)
        completions = []
        for line in extract_text_from_response(response).split("\n"):
            word = line.strip().lstrip("1234567890.- ")
            if word.isalpha():
                completions.append(word.lower())
        return list(dict.fromkeys(completions))[:max_results]
    except Exception as e:
        print(f"[Gemini API 오류] {e}")
        return []

async def complete_sentence(text: str, context: Optional[str] = None) -> str:
    try:
        model = genai.GenerativeModel("gemini-1.5-pro")
        prompt = f"문장을 자연스럽게 완성해 주세요: {text}"
        if context:
            prompt += f"\n컨텍스트: {context}"
        response = await asyncio.to_thread(model.generate_content, prompt)
        return extract_text_from_response(response)
    except Exception as e:
        print(f"[Gemini 문장완성 오류] {e}")
        return text

async def rewrite_sentence(text: str, style: str = "concise") -> dict:
    try:
        model = genai.GenerativeModel("gemini-1.5-pro")
        prompt = f"""다음 텍스트를 개선하여 다시 작성하고, 정확한 JSON 형식으로 응답해주세요.

원본 텍스트:
{text}

응답 형식:
{{
  "diffs": [
    {{
      "type": "deletion",
      "text": "삭제할 텍스트",
      "reason": "수정 이유"
    }},
    {{
      "type": "addition",
      "text": "추가할 텍스트",
      "reason": "수정 이유"
    }}
  ]
}}

요구사항:
1. 삭제와 추가는 쌍으로 제시
2. 2-3문장 단위로 나누어 수정
3. 각 수정에 대한 이유를 명확히 설명
4. 전체적인 의미는 유지하면서 더 나은 표현으로 개선"""

        response = await asyncio.to_thread(
            model.generate_content,
            prompt,
            generation_config={
                "temperature": 0.7,
                "candidate_count": 1,
                "max_output_tokens": 1024
            }
        )
        
        if not response.text:
            return {"diffs": [], "error": "AI가 응답을 생성하지 못했습니다"}
            
        try:
            json_str = response.text.replace('```json', '').replace('```', '').strip()
            start = json_str.find('{')
            end = json_str.rfind('}') + 1
            if start == -1 or end == 0:
                raise ValueError("유효한 JSON을 찾을 수 없습니다")
                
            json_str = json_str[start:end]
            result = json.loads(json_str)
            
            diffs = result.get('diffs', [])
            if not diffs:
                return {"diffs": [], "error": "수정 사항을 찾지 못했습니다"}
                
            valid_diffs = []
            for i in range(0, len(diffs), 2):
                deletion = diffs[i] if i < len(diffs) else None
                addition = diffs[i+1] if i+1 < len(diffs) else None
                
                if deletion and addition and \
                   deletion.get('type') == 'deletion' and \
                   addition.get('type') == 'addition' and \
                   all(k in deletion for k in ('text', 'reason')) and \
                   all(k in addition for k in ('text', 'reason')):
                    valid_diffs.extend([deletion, addition])
            
            if not valid_diffs:
                return {"diffs": [], "error": "유효한 수정 사항을 찾지 못했습니다"}
            
            return {"diffs": valid_diffs}
            
        except json.JSONDecodeError as e:
            return {"diffs": [], "error": "AI 응답을 처리하는 중 오류가 발생했습니다"}
            
    except Exception as e:
        return {"diffs": [], "error": f"다시쓰기 처리 중 오류가 발생했습니다: {str(e)}"}
