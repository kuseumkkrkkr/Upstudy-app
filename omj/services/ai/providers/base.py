"""AI Provider adapter layer.

Provides:
- AIProvider: abstract interface for all AI backends
- KimiProvider: concrete implementation for Kimi 2.5 via OpenAI-compatible endpoint
- get_default_provider(): returns the default provider instance
"""
import os
import json
from abc import ABC, abstractmethod
from typing import Any, Optional, Callable
from pydantic import BaseModel


class AIProvider(ABC):
    """Abstract AI provider. All concrete providers must implement these methods."""

    @property
    @abstractmethod
    def name(self) -> str:
        ...

    @abstractmethod
    def generate(
        self,
        prompt: str,
        *,
        schema: Optional[type[BaseModel]] = None,
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> dict:
        """Generate content and return a dict.

        If *schema* is provided, the provider should request structured JSON
        and validate against the Pydantic model.
        """
        ...

    @abstractmethod
    def stream(
        self,
        prompt: str,
        *,
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> Any:
        """Return a streaming iterator / async generator."""
        ...

    def safety_check(self, prompt: str, *, operation: str = "generate") -> Optional[dict]:
        """Return a rejection dict if the request should be refused.

        Subclasses may override with provider-specific heuristics.
        """
        # Default naive guard: length cap
        if len(prompt) > 200_000:
            return {
                "rejected": True,
                "flag": "excessive_request",
                "detail": "Prompt exceeds 200k characters.",
                "suggestion": "Split the request into smaller chunks.",
            }
        return None


class KimiProvider(AIProvider):
    """Kimi 2.5 via OpenAI-compatible API."""

    def __init__(self, api_key: Optional[str] = None, base_url: Optional[str] = None):
        import openai
        self._api_key = api_key or os.getenv("KIMI_API_KEY") or os.getenv("COMETAPI_KEY")
        self._base_url = base_url or os.getenv("KIMI_BASE_URL", "https://api.moonshot.cn/v1")
        self._client = openai.OpenAI(api_key=self._api_key, base_url=self._base_url)

    @property
    def name(self) -> str:
        return "kimi"

    def generate(
        self,
        prompt: str,
        *,
        schema: Optional[type[BaseModel]] = None,
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> dict:
        model = model or os.getenv("KIMI_DEFAULT_MODEL", "kimi-k2-5")
        if schema:
            response = self._client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=temperature,
                max_tokens=max_tokens,
            )
            text = response.choices[0].message.content
            parsed = json.loads(text)
            # Validate against schema
            validated = schema.model_validate(parsed)
            return {"text": text, "parsed": validated.model_dump()}
        else:
            response = self._client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                temperature=temperature,
                max_tokens=max_tokens,
            )
            return {"text": response.choices[0].message.content}

    def stream(self, prompt: str, *, model: Optional[str] = None, temperature: float = 0.7, max_tokens: int = 4096):
        model = model or os.getenv("KIMI_DEFAULT_MODEL", "kimi-k2-5")
        return self._client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=temperature,
            max_tokens=max_tokens,
            stream=True,
        )


class GeminiProvider(AIProvider):
    """Google Gemini via google-genai SDK (legacy compatibility)."""

    def __init__(self, api_key: Optional[str] = None):
        import google.genai as genai
        self._api_key = api_key or os.getenv("COMETAPI_KEY")
        self._client = genai.Client(
            http_options={"api_version": "v1beta", "base_url": os.getenv("GEMINI_BASE_URL")},
            api_key=self._api_key,
        )

    @property
    def name(self) -> str:
        return "gemini"

    def generate(
        self,
        prompt: str,
        *,
        schema: Optional[type[BaseModel]] = None,
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> dict:
        model = model or os.getenv("GEMINI_DEFAULT_MODEL", "gemini-3.1-flash-lite")
        if schema:
            response = self._client.models.generate_content(
                model=model,
                contents=prompt,
                config={
                    "response_mime_type": "application/json",
                    "response_json_schema": schema.model_json_schema(),
                },
            )
        else:
            response = self._client.models.generate_content(
                model=model,
                contents=prompt,
            )
        text = response.text
        result: dict = {"text": text}
        if schema:
            import json
            parsed = json.loads(text)
            validated = schema.model_validate(parsed)
            result["parsed"] = validated.model_dump()
        return result

    def stream(self, prompt: str, *, model: Optional[str] = None, temperature: float = 0.7, max_tokens: int = 4096):
        model = model or os.getenv("GEMINI_DEFAULT_MODEL", "gemini-3.1-flash-lite")
        return self._client.models.generate_content(
            model=model,
            contents=prompt,
            stream=True,
        )


_DEFAULT_PROVIDER: Optional[AIProvider] = None


def get_default_provider() -> AIProvider:
    global _DEFAULT_PROVIDER
    if _DEFAULT_PROVIDER is None:
        # Prefer Kimi 2.5 as default per PLANnow.md
        try:
            _DEFAULT_PROVIDER = KimiProvider()
        except Exception:
            # Fallback to Gemini if Kimi env is missing
            _DEFAULT_PROVIDER = GeminiProvider()
    return _DEFAULT_PROVIDER


def set_default_provider(provider: AIProvider) -> None:
    global _DEFAULT_PROVIDER
    _DEFAULT_PROVIDER = provider
