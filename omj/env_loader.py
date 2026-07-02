from __future__ import annotations

import os
from pathlib import Path


_ENV_LOADED_FLAG = "OMJ_ENV_LOADED"


def load_env() -> None:
    if os.environ.get(_ENV_LOADED_FLAG) == "1":
        return
    for path in _candidate_paths():
        if path.is_file():
            _apply_env_file(path)
            break
    os.environ[_ENV_LOADED_FLAG] = "1"


def _candidate_paths() -> list[Path]:
    here = Path(__file__).resolve().parent
    candidates = [
        Path.cwd() / ".env",
        here / ".env",
        here.parent / ".env",
    ]
    seen: set[Path] = set()
    ordered: list[Path] = []
    for path in candidates:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        ordered.append(resolved)
    return ordered


def _apply_env_file(path: Path) -> None:
    try:
        content = path.read_text(encoding="utf-8")
    except Exception:
        return

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
        if not key:
            continue
        value = value.strip()
        if value and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        os.environ.setdefault(key, value)
