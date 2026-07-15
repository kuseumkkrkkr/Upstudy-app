"""Shared SAM OpenAI-compatible client helpers.

All external AI calls should use SAM_API_KEY and the SAM OpenAI-compatible
endpoint. Model defaults live here so runtime choices stay in one place.
"""
from __future__ import annotations

import base64
import json
import os
from functools import lru_cache
from typing import Any, Dict, List, Optional, Sequence

from pydantic import BaseModel

from env_loader import load_env

load_env()

SAM_API_KEY_ENV = "SAM_API_KEY"
SAM_OPENAI_BASE_URL = os.getenv(
    "SAM_OPENAI_BASE_URL",
    "https://sam.soonsoon.ai/openai/v1",
)

DEFAULT_PROVIDER_MODEL = os.getenv("SAM_DEFAULT_MODEL", "fw-kimi-k2.7-code")
DEFAULT_PROBLEM_MODEL = os.getenv("SAM_PROBLEM_MODEL", "gemini-3.5-flash")
DEFAULT_FALLBACK_MODEL = os.getenv("SAM_FALLBACK_MODEL", "fw-kimi-k2.7-code")
DEFAULT_ANALYSIS_MODEL = os.getenv("OMJ_ANALYSIS_MODEL", "az-deepseek-v4-flash")
DEFAULT_CHAT_MODEL = os.getenv("OMJ_CHAT_MODEL", "gemma-3-27b")
DEFAULT_CODEBASE_MODEL = os.getenv("CODEBASE_GEN_MODEL", "gemini-3.5-flash")
DEFAULT_TAG_AGENT_MODEL = os.getenv("TAG_AGENT_MODEL", "az-deepseek-v4-flash")
DEFAULT_CODEBASE_REPAIR_MODEL = os.getenv(
    "CODEBASE_REPAIR_MODEL",
    "gemini-3.5-flash",
)
SAM_REQUEST_TIMEOUT_SECONDS = max(
    5.0,
    float(os.getenv("SAM_REQUEST_TIMEOUT_SECONDS", "120")),
)
SAM_REQUEST_MAX_RETRIES = max(
    0,
    min(2, int(os.getenv("SAM_REQUEST_MAX_RETRIES", "1"))),
)


def get_sam_api_key() -> str:
    key = os.getenv(SAM_API_KEY_ENV, "").strip()
    if not key:
        raise RuntimeError(f"{SAM_API_KEY_ENV} is not set")
    return key


def is_sam_configured() -> bool:
    return bool(os.getenv(SAM_API_KEY_ENV, "").strip())


@lru_cache(maxsize=1)
def get_sam_client() -> Any:
    """필요 변수: API 키·엔드포인트·시간 제한. 작동 원리: 장기 점유를 막는 공용 클라이언트를 프로세스당 한 번 생성한다."""
    from openai import OpenAI

    return OpenAI(
        api_key=get_sam_api_key(),
        base_url=SAM_OPENAI_BASE_URL,
        timeout=SAM_REQUEST_TIMEOUT_SECONDS,
        max_retries=SAM_REQUEST_MAX_RETRIES,
    )


def strip_code_fences(text: str) -> str:
    value = (text or "").strip()
    if value.startswith("```"):
        value = value.lstrip("`").split("\n", 1)[-1]
    if value.endswith("```"):
        value = value.rsplit("\n", 1)[0]
    return value.strip()


def _infer_mime_type(image_bytes: bytes) -> str:
    if len(image_bytes) >= 3 and image_bytes[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if len(image_bytes) >= 8 and image_bytes[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if len(image_bytes) >= 4 and image_bytes[:4] == b"GIF8":
        return "image/gif"
    if len(image_bytes) >= 12 and image_bytes[8:12] == b"WEBP":
        return "image/webp"
    return "application/octet-stream"


def _image_part(image_bytes: bytes) -> Dict[str, Any]:
    encoded = base64.b64encode(image_bytes).decode("utf-8")
    mime_type = _infer_mime_type(image_bytes)
    return {
        "type": "image_url",
        "image_url": {"url": f"data:{mime_type};base64,{encoded}"},
    }


def build_user_content(prompt: str, images: Optional[Sequence[bytes]] = None) -> Any:
    image_parts = [_image_part(image) for image in (images or []) if image]
    if not image_parts:
        return prompt
    return [{"type": "text", "text": prompt}, *image_parts]


def chat_completion_text(
    *,
    model: str,
    prompt: Optional[str] = None,
    messages: Optional[List[Dict[str, Any]]] = None,
    images: Optional[Sequence[bytes]] = None,
    temperature: Optional[float] = 0.7,
    top_p: Optional[float] = None,
    max_tokens: Optional[int] = 4096,
    json_mode: bool = False,
) -> str:
    if messages is None:
        messages = [{"role": "user", "content": build_user_content(prompt or "", images)}]

    kwargs: Dict[str, Any] = {
        "model": model,
        "messages": messages,
    }
    if temperature is not None:
        kwargs["temperature"] = temperature
    if top_p is not None:
        kwargs["top_p"] = top_p
    if max_tokens is not None:
        kwargs["max_tokens"] = max_tokens
    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}

    try:
        response = get_sam_client().chat.completions.create(**kwargs)
    except Exception:
        if not json_mode:
            raise
        retry_kwargs = dict(kwargs)
        retry_kwargs.pop("response_format", None)
        response = get_sam_client().chat.completions.create(**retry_kwargs)
    content = response.choices[0].message.content
    if isinstance(content, list):
        return "".join(str(part.get("text", "")) if isinstance(part, dict) else str(part) for part in content)
    return str(content or "")


def generate_json(
    *,
    model: str,
    prompt: str,
    schema: Optional[type[BaseModel]] = None,
    images: Optional[Sequence[bytes]] = None,
    temperature: Optional[float] = 0.3,
    top_p: Optional[float] = None,
    max_tokens: Optional[int] = 4096,
) -> Dict[str, Any]:
    if schema is not None:
        schema_text = json.dumps(schema.model_json_schema(), ensure_ascii=False)
        prompt = (
            f"{prompt}\n\n"
            "Return JSON only. The response must validate against this JSON schema:\n"
            f"{schema_text}"
        )

    raw = chat_completion_text(
        model=model,
        prompt=prompt,
        images=images,
        temperature=temperature,
        top_p=top_p,
        max_tokens=max_tokens,
        json_mode=True,
    )
    text = strip_code_fences(raw)
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError("SAM JSON response must be an object")
    if schema is not None:
        return schema.model_validate(data).model_dump()
    return data
