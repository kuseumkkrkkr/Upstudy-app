import os
import json
import asyncio
from typing import List, Optional
from openai import AsyncOpenAI

# API 키 설정
OPENAI_API_KEY = "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"  # 실제 발급받은 키
client = AsyncOpenAI(api_key=OPENAI_API_KEY)

# ==============================================
# 자동완성
# ==============================================
async def generate_completions(query: str, max_results: int = 5, context: Optional[str] = None) -> List[str]:
    try:
        print(f"[자동완성 요청] 쿼리: {query}, 컨텍스트 길이: {len(context) if context else 0}")
        
        # 문장 자동완성 모드
        if len(query) >= 10:  # 문장 모드 판별
            prompt = f"""다음 문장의 자연스러운 이어질 내용을 {max_results}개 제안해주세요.

현재 문장: {query}

조건:
1. 자연스러운 한국어로 이어지게 작성
2. 각 제안은 한 줄에 하나씩
3. 간단명료하게 작성
4. 번호나 부가설명 없이 순수 텍스트만
"""
        # 단어 자동완성 모드
        else:
            prompt = f"""주어진 부분 단어 "{query}"에 대해 {max_results}개의 자동완성 제안을 생성해주세요.

조건:
1. 일반적이고 유용한 한국어 단어를 제안
2. "{query}"로 시작하거나 관련성이 높은 단어
3. 한 줄에 하나씩만 출력
4. 번호/설명 제외
"""
        if context:
            prompt += f"\n추가 컨텍스트: {context}"

        print(f"[자동완성 프롬프트] {prompt}")

        try:
            response = await client.chat.completions.create(
                model="gpt-4o-mini",  # 올바른 모델명
                messages=[
                    {"role": "system", "content": "한국어 문장과 단어 자동완성을 제안하는 도우미입니다."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=150,
                presence_penalty=0.6,  # 다양한 제안을 위해 추가
                frequency_penalty=0.3   # 반복 방지를 위해 추가
            )

            completions = []
            if response.choices:
                content = response.choices[0].message.content
                print(f"[GPT 응답 전문]\n{content}")  # 전체 응답 로깅
                
                for line in content.split("\n"):
                    suggestion = line.strip().lstrip("1234567890.- ")
                    if suggestion and len(suggestion) > 1:  # 빈 줄이나 한 글자 제외
                        completions.append(suggestion)
                        
                print(f"[처리된 제안들] {completions}")  # 처리된 제안 로깅
                
            return list(dict.fromkeys(completions))[:max_results]
            
        except Exception as e:
            print(f"[OpenAI API 호출 오류] {str(e)}")
            return []

    except Exception as e:
        print(f"[GPT API 오류] {e}")
        return []

# ==============================================
# 문장 완성 및 제안
# ==============================================
async def generate_sentence_suggestions(
    context: str,
    max_suggestions: int = 3,
    full_text: Optional[str] = None
) -> List[str]:
    """문장 완성 제안을 생성합니다."""
    try:
        prompt = f"""다음 문맥에 이어질 수 있는 자연스러운 문장을 {max_suggestions}개 제안해주세요.

현재 문맥: {context}

조건:
1. 한국어로 자연스럽게 이어지는 문장 제안
2. 각 제안은 완결된 문장으로 작성
3. 간단명료하게 작성 (최대 2-3문장)
4. 번호나 부가설명 없이 순수 텍스트만"""

        if full_text:
            prompt += f"\n\n전체 문서 맥락:\n{full_text}"

        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": "한국어 문장 자동완성을 제안하는 도우미입니다."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=200,
            presence_penalty=0.6,
            frequency_penalty=0.3
        )

        suggestions = []
        if response.choices:
            content = response.choices[0].message.content
            for line in content.strip().split("\n"):
                line = line.strip().lstrip("1234567890.- ")
                if line:
                    suggestions.append(line)

        return suggestions[:max_suggestions]

    except Exception as e:
        print(f"[GPT 문장 제안 오류] {e}")
        return []

async def complete_sentence(text: str, context: Optional[str] = None) -> str:
    try:
        prompt = f"문장을 자연스럽게 완성해 주세요: {text}"
        if context:
            prompt += f"\n컨텍스트: {context}"

        response = await client.chat.completions.create(
            model="gpt-4o-mini",   # ✅ 최신 SDK 호환 모델
            messages=[
                {"role": "system", "content": "You are a helpful assistant that completes sentences naturally."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=200
        )

        if response.choices:
            return response.choices[0].message.content.strip()
        return text

    except Exception as e:
        print(f"[GPT 문장완성 오류] {e}")
        return text

# ==============================================
# 문장 리라이팅
# ==============================================
async def rewrite_sentence(text: str, style: str = "concise") -> dict:
    try:
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

        response = await client.chat.completions.create(
            model="gpt-4o-mini",   # ✅ 최신 SDK 호환 모델
            messages=[
                {"role": "system", "content": "You are a helpful assistant that rewrites text and provides detailed explanations of changes."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=1000
        )

        if not response.choices:
            return {"diffs": [], "error": "AI가 응답을 생성하지 못했습니다"}

        content = response.choices[0].message.content
        try:
            json_str = content.replace('```json', '').replace('```', '').strip()
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
                addition = diffs[i + 1] if i + 1 < len(diffs) else None

                if deletion and addition and \
                   deletion.get('type') == 'deletion' and \
                   addition.get('type') == 'addition' and \
                   all(k in deletion for k in ('text', 'reason')) and \
                   all(k in addition for k in ('text', 'reason')):
                    valid_diffs.extend([deletion, addition])

            if not valid_diffs:
                return {"diffs": [], "error": "유효한 수정 사항을 찾지 못했습니다"}

            return {"diffs": valid_diffs}

        except json.JSONDecodeError:
            return {"diffs": [], "error": "AI 응답을 처리하는 중 오류가 발생했습니다"}

    except Exception as e:
        return {"diffs": [], "error": f"다시쓰기 처리 중 오류가 발생했습니다: {str(e)}"}
