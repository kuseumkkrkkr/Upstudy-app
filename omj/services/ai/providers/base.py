"""AI Provider adapter layer backed by SAM."""
import json
from abc import ABC, abstractmethod
from typing import Any, Optional
from pydantic import BaseModel

from services.ai.sam_client import (
    DEFAULT_FALLBACK_MODEL,
    DEFAULT_PROVIDER_MODEL,
    chat_completion_text,
    generate_json,
)


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


class SAMProvider(AIProvider):
    """SAM OpenAI-compatible provider."""

    def __init__(self, api_key: Optional[str] = None, base_url: Optional[str] = None):
        # api_key/base_url are accepted for backward construction compatibility.
        self._api_key = api_key
        self._base_url = base_url

    @property
    def name(self) -> str:
        return "sam"

    def generate(
        self,
        prompt: str,
        *,
        schema: Optional[type[BaseModel]] = None,
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> dict:
        model = model or DEFAULT_PROVIDER_MODEL
        if schema:
            parsed = generate_json(
                model=model,
                prompt=prompt,
                schema=schema,
                temperature=temperature,
                max_tokens=max_tokens,
            )
            return {"text": json.dumps(parsed, ensure_ascii=False), "parsed": parsed}
        text = chat_completion_text(
            model=model,
            prompt=prompt,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        return {"text": text}

    def stream(self, prompt: str, *, model: Optional[str] = None, temperature: float = 0.7, max_tokens: int = 4096):
        raise NotImplementedError("SAM streaming is not wired in this provider yet")


class KimiProvider(SAMProvider):
    """Backward-compatible name for the old default provider."""

    def __init__(self, api_key: Optional[str] = None):
        super().__init__(api_key=api_key)


class GeminiProvider(SAMProvider):
    """Backward-compatible fallback provider name, now routed through SAM."""

    def generate(self, prompt: str, *, schema: Optional[type[BaseModel]] = None, model: Optional[str] = None, temperature: float = 0.7, max_tokens: int = 4096) -> dict:
        return super().generate(
            prompt,
            schema=schema,
            model=model or DEFAULT_FALLBACK_MODEL,
            temperature=temperature,
            max_tokens=max_tokens,
        )


_DEFAULT_PROVIDER: Optional[AIProvider] = None


def get_default_provider() -> AIProvider:
    global _DEFAULT_PROVIDER
    if _DEFAULT_PROVIDER is None:
        _DEFAULT_PROVIDER = SAMProvider()
    return _DEFAULT_PROVIDER


def set_default_provider(provider: AIProvider) -> None:
    global _DEFAULT_PROVIDER
    _DEFAULT_PROVIDER = provider
