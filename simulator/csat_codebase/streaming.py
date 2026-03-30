from __future__ import annotations

import math
from typing import Any, List

from PyQt5.QtCore import QObject, pyqtSignal


def extract_chunk_text(chunk: Any) -> str:
    if chunk is None:
        return ""
    if isinstance(chunk, str):
        return chunk
    text = getattr(chunk, "text", None)
    if isinstance(text, str) and text:
        return text
    candidates = getattr(chunk, "candidates", None)
    if isinstance(candidates, list):
        parts_text: List[str] = []
        for cand in candidates:
            content = getattr(cand, "content", None)
            parts = getattr(content, "parts", None) if content is not None else None
            if isinstance(parts, list):
                for part in parts:
                    part_text = getattr(part, "text", None)
                    if isinstance(part_text, str) and part_text:
                        parts_text.append(part_text)
        return "".join(parts_text)
    return ""


def estimate_tokens(text: str) -> int:
    if not text:
        return 0
    ascii_count = sum(1 for ch in text if ord(ch) < 128)
    non_ascii_count = len(text) - ascii_count
    return max(1, int(math.ceil(ascii_count / 4.0)) + non_ascii_count)


class StreamWorker(QObject):
    chunk = pyqtSignal(str)
    done = pyqtSignal(str)
    error = pyqtSignal(str)

    def __init__(self, client: Any, model: str, prompt: str) -> None:
        super().__init__()
        self._client = client
        self._model = model
        self._prompt = prompt

    def run(self) -> None:
        try:
            full_text = ""
            if hasattr(self._client.models, "generate_content_stream"):
                stream = self._client.models.generate_content_stream(
                    model=self._model,
                    contents=self._prompt,
                    config={"temperature": 0.6},
                )
                for chunk in stream:
                    piece = extract_chunk_text(chunk)
                    if piece:
                        full_text += piece
                        self.chunk.emit(piece)
            else:
                response = self._client.models.generate_content(
                    model=self._model,
                    contents=self._prompt,
                    config={"temperature": 0.6},
                )
                text = response.text or ""
                full_text = text
                if text:
                    self.chunk.emit(text)
            self.done.emit(full_text)
        except Exception as exc:
            self.error.emit(str(exc))
