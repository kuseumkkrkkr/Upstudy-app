"""Cooperative cancellation registry for long-running generation work."""
from __future__ import annotations

import threading
from typing import Optional


class GenerationCancelled(RuntimeError):
    """Raised when a generation request is cancelled by the caller."""


_LOCK = threading.Lock()
_TOKENS: dict[str, threading.Event] = {}


def register_token(token_id: str) -> threading.Event:
    with _LOCK:
        event = _TOKENS.get(token_id)
        if event is None:
            event = threading.Event()
            _TOKENS[token_id] = event
        return event


def get_token(token_id: str) -> Optional[threading.Event]:
    with _LOCK:
        return _TOKENS.get(token_id)


def cancel_token(token_id: str) -> None:
    event = register_token(token_id)
    event.set()


def release_token(token_id: str) -> None:
    with _LOCK:
        _TOKENS.pop(token_id, None)


def is_cancelled(cancel_event: Optional[threading.Event]) -> bool:
    return bool(cancel_event is not None and cancel_event.is_set())


def check_cancelled(cancel_event: Optional[threading.Event]) -> None:
    if is_cancelled(cancel_event):
        raise GenerationCancelled("generation cancelled")
