from __future__ import annotations

import os
from pathlib import Path


_env_loaded = False
_WINDOWS_RUNTIME_KEYS = (
    "POSTGRES_PASSWORD",
    "DATABASE_URL",
    "REDIS_URL",
    "PROBLEM_CACHE_BACKEND",
    "PROBLEM_CACHE_VERIFIED",
    "RUN_EMBEDDED_BACKGROUND_WORKERS",
)


def load_env() -> None:
    """필요 변수: 프로세스 환경·UTF-8 .env·Windows 사용자 환경 변수.

    작동 원리: 기존 프로세스 값을 보존하면서 .env와 Windows 사용자 설정 순서로
    누락된 런타임 값만 한 번 보충한다.
    """
    global _env_loaded
    # 부모 셸의 OMJ_ENV_LOADED 값은 현재 Python 프로세스가 파일을 읽었다는 증거가 아니다.
    if _env_loaded:
        return
    for path in _candidate_paths():
        if path.is_file():
            _apply_env_file(path)
    _apply_windows_user_environment()
    _env_loaded = True


def _apply_windows_user_environment() -> None:
    """필요 변수: HKCU\\Environment에 저장된 런타임 키 목록.

    작동 원리: 오래 열린 터미널에서도 DB 설정을 읽되 이미 설정된 값은 덮어쓰지 않는다.
    Windows가 아니거나 키가 없으면 아무 변경 없이 종료한다.
    """
    if os.name != "nt":
        return

    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as user_environment:
            for name in _WINDOWS_RUNTIME_KEYS:
                if os.environ.get(name):
                    continue
                try:
                    value, _ = winreg.QueryValueEx(user_environment, name)
                except FileNotFoundError:
                    continue
                if isinstance(value, str) and value.strip():
                    os.environ[name] = value
    except OSError:
        return


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
