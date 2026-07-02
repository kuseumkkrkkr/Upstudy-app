from __future__ import annotations

import os
from pathlib import Path
from typing import Any

try:
    from google import genai
except Exception as exc:  # pragma: no cover
    genai = None
    _GENAI_IMPORT_ERROR = exc
else:
    _GENAI_IMPORT_ERROR = None


COMET_BASE_URL = "https://api.cometapi.com"


def load_env_file() -> None:
    root = Path(__file__).resolve().parents[2]
    candidates = [root / ".env", root / "omj" / ".env"]
    for path in candidates:
        if not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except Exception:
            continue
        for raw_line in content.splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export ") :].strip()
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if value and value[0] == value[-1] and value[0] in ("'", '"'):
                value = value[1:-1]
            if key:
                os.environ.setdefault(key, value)
        break


def build_client() -> Any:
    load_env_file()
    comet_key = os.environ.get("COMETAPI_KEY")
    gemini_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    api_key = comet_key or gemini_key
    if not api_key:
        raise RuntimeError("API 키가 없습니다. .env에 COMETAPI_KEY 또는 GEMINI_API_KEY를 설정하세요.")
    if genai is None:
        raise RuntimeError(f"google-genai import 실패: {_GENAI_IMPORT_ERROR}")
    if comet_key:
        return genai.Client(
            http_options={"api_version": "v1beta", "base_url": COMET_BASE_URL},
            api_key=api_key,
        )
    return genai.Client(api_key=api_key)
