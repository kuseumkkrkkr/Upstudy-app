import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import env_loader


def test_inherited_loaded_flag_does_not_skip_current_env_file(monkeypatch, tmp_path):
    """필요 변수: 부모 셸 플래그와 현재 작업 폴더 .env. 작동 원리: 현재 프로세스가 실제 파일을 읽기 전에는 상속 플래그를 무시하는지 검증한다."""
    (tmp_path / ".env").write_text("OCR_ENV_LOADER_TEST=loaded\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("OMJ_ENV_LOADED", "1")
    monkeypatch.delenv("OCR_ENV_LOADER_TEST", raising=False)
    monkeypatch.setattr(env_loader, "_env_loaded", False)

    env_loader.load_env()

    assert env_loader.os.environ["OCR_ENV_LOADER_TEST"] == "loaded"


def test_frontend_and_backend_env_files_are_merged(monkeypatch, tmp_path):
    """필요 변수: 서로 다른 키를 가진 앱·서버 환경 파일. 작동 원리: 첫 파일에서 중단하지 않고 누락된 서버 키까지 합치는지 검증한다."""
    frontend = tmp_path / "frontend.env"
    backend = tmp_path / "backend.env"
    frontend.write_text("OCR_FRONTEND_ENV=frontend\n", encoding="utf-8")
    backend.write_text("OCR_BACKEND_ENV=backend\n", encoding="utf-8")
    monkeypatch.delenv("OCR_FRONTEND_ENV", raising=False)
    monkeypatch.delenv("OCR_BACKEND_ENV", raising=False)
    monkeypatch.setattr(env_loader, "_env_loaded", False)
    monkeypatch.setattr(env_loader, "_candidate_paths", lambda: [frontend, backend])

    env_loader.load_env()

    assert env_loader.os.environ["OCR_FRONTEND_ENV"] == "frontend"
    assert env_loader.os.environ["OCR_BACKEND_ENV"] == "backend"
