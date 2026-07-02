# -*- coding: utf-8 -*-
"""
개념 교재 자동 생성기 (Gemini API 호출)

사용법:
    python gen_textbook/gen.py \
        --model gemini-3.1-flash-lite \
        --max-workers 5 \
        --output gen_textbook/generated_textbooks.json

동작:
    1. leaves.txt 를 읽어 leaf 개념 목록을 파싱
    2. 각 개념마다 프롬프트를 구성하여 Gemini API 에 async 병렬 호출
    3. 결과를 JSON 으로 저장

환경변수:
    COMETAPI_KEY  - CometAPI 키 (필수)
"""

import argparse
import asyncio
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor

from google import genai

# ── 설정 ──────────────────────────────

COMETAPI_KEY = os.environ.get("COMETAPI_KEY")
BASE_URL = "https://api.cometapi.com"
DEFAULT_MODEL = "gemini-3.1-flash-lite"

DEFAULT_PROMPT_TEMPLATE = """당신은 한국 고등학교 수학 교과서 집필자입니다.
아래 개념에 대해 **4~6개 문단**으로 상세 설명과 예제를 작성해주세요.

요구사항:
1. 첫 2~3 문단: 정의, 핵심 공식, 성질 (한국어 상세 설명)
2. 공식은 반드시 LaTeX 형식으로 작성하고 $$ 로 감싸주세요.
3. 마지막 2~3 문단: 구체적인 예제 문제와 단계별 풀이 (한국어 + LaTeX 수식)
4. 중학생도 이해할 수 있게 친절하고 정확하게, **절대로** "설명을 추가하세요" 같은 placeholder를 쓰지 마세요.

개념: {concept_name}
경로: {concept_path}

각 문단은 JSON 문자열 배열로 반환해주세요."""


# ── 파싱 ──────────────────────────────

def parse_leaves(path="data/leaves.txt"):
    leaves = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) == 2:
                name, path_str = parts
                leaves.append({"name": name, "path": path_str.split("|")})
    return leaves


# ── Gemini 클라이언트 초기화 ──────────────────────────────

def make_client() -> genai.Client:
    if not COMETAPI_KEY:
        print("ERROR: COMETAPI_KEY 환경변수가 설정되지 않았습니다.")
        sys.exit(1)
    return genai.Client(
        http_options={"api_version": "v1beta", "base_url": BASE_URL},
        api_key=COMETAPI_KEY,
    )


# ── 프롬프트 / 응답 처리 ──────────────────────────────

def build_prompt(concept: dict, template: str | None = None) -> str:
    return (template or DEFAULT_PROMPT_TEMPLATE).format(
        concept_name=concept["name"],
        concept_path=" > ".join(concept["path"]),
    )


def _extract_json_text(raw: str) -> str:
    """마크다운 코드 블록 제거."""
    text = raw or ""
    if text.startswith("```"):
        text = text.lstrip("`").split("\n", 1)[-1]
    if text.endswith("```"):
        text = text.rsplit("\n", 1)[0]
    return text.strip()


def parse_paragraphs(raw_text: str) -> list[str]:
    """API 응답에서 문단을 추출. JSON 배열이면 파싱, 아니면 줄단위 분할."""
    text = _extract_json_text(raw_text)
    if text.startswith("[") and text.endswith("]"):
        try:
            arr = json.loads(text)
            if isinstance(arr, list) and all(isinstance(x, str) for x in arr):
                return [x.strip() for x in arr if x.strip()]
        except Exception:
            pass
    # fallback: 빈 줄 기준 문단 분리
    return [p.strip() for p in text.split("\n\n") if p.strip()]


# ── API 호출 (동기 → 스레드풀로 async 래핑) ──────────────────────────────

def _call_gemini_sync(client: genai.Client, model: str, prompt: str) -> str:
    """동기 Gemini 호출. ThreadPoolExecutor 안에서 실행됩니다."""
    response = client.models.generate_content(
        model=model,
        contents=prompt,
        config={
            "temperature": 0.3,
            "max_output_tokens": 2048,
        },
    )
    return response.text or ""


async def call_gemini_async(
    executor: ThreadPoolExecutor,
    client: genai.Client,
    model: str,
    prompt: str,
) -> str:
    loop = asyncio.get_running_loop()
    try:
        raw = await loop.run_in_executor(
            executor, _call_gemini_sync, client, model, prompt
        )
        return raw
    except Exception as e:
        return f"ERROR:EXCEPTION:{type(e).__name__}:{str(e)[:200]}"


# ── 메인 생성 루틴 ──────────────────────────────

async def generate_concepts(leaves: list[dict], args) -> dict:
    client = make_client()
    results: dict = {}
    semaphore = asyncio.Semaphore(args.max_workers)
    executor = ThreadPoolExecutor(max_workers=args.max_workers)

    # 커스텀 프롬프트 템플릿 로드
    prompt_template: str | None = None
    if args.prompt_template:
        with open(args.prompt_template, "r", encoding="utf-8") as f:
            prompt_template = f.read()

    name_to_concept = {c["name"]: c for c in leaves}

    async def fetch(concept: dict):
        async with semaphore:
            prompt = build_prompt(concept, prompt_template)
            raw = await call_gemini_async(executor, client, args.model, prompt)
            return concept["name"], raw

    tasks = [fetch(c) for c in leaves]
    for coro in asyncio.as_completed(tasks):
        name, raw = await coro
        paragraphs = parse_paragraphs(raw)
        concept = name_to_concept[name]
        results[name] = {
            "name": name,
            "path": " > ".join(concept["path"]),
            "paragraphs": paragraphs,
            "raw": raw,
        }
        status = "OK" if not raw.startswith("ERROR") else "ERR"
        print(f"[{status}] {name}  ({len(paragraphs)} paragraphs)", flush=True)

    executor.shutdown(wait=False)
    return results


# ── CLI ──────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="개념 교재 자동 생성기 (Gemini)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Gemini 모델명 (기본값: {DEFAULT_MODEL})")
    parser.add_argument("--max-workers", type=int, default=5, help="동시 API 호출 수")
    parser.add_argument("--output", default="gen_textbook/generated_textbooks.json", help="출력 JSON 경로")
    parser.add_argument("--prompt-template", default=None, help="커스텀 프롬프트 템플릿 파일 경로")
    parser.add_argument("--leaves", default="data/leaves.txt", help="Leaves 정의 파일")
    parser.add_argument("--dry-run", action="store_true", help="API 호출 없이 프롬프트만 출력")
    args = parser.parse_args()

    # google-genai 설치 확인
    try:
        import google.genai  # noqa: F401
    except ImportError:
        print("ERROR: google-genai 패키지가 필요합니다.  pip install google-genai")
        sys.exit(1)

    leaves = parse_leaves(args.leaves)
    print(f"총 개념 수: {len(leaves)}")

    if args.dry_run:
        for c in leaves[:3]:
            prompt = build_prompt(c)
            print("=" * 60)
            print(prompt)
        return

    results = asyncio.run(generate_concepts(leaves, args))

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n완료. {len(results)}개 개념을 {args.output} 에 저장했습니다.")


if __name__ == "__main__":
    main()