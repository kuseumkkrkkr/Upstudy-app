from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_flutter_product_api_uses_vercel_and_has_no_unsupported_social_websocket():
    contract = (ROOT / "lib/shared/services/api/api_contract.dart").read_text(
        encoding="utf-8"
    )
    friend_screen = (ROOT / "lib/sessions/friend/ui/friend_screen.dart").read_text(
        encoding="utf-8"
    )
    direct_chat = (
        ROOT / "lib/sessions/friend/ui/student_direct_chat_page.dart"
    ).read_text(encoding="utf-8")

    assert "https://aiflow-web-canary.vercel.app" in contract
    assert "static String get ocrQueueBaseUrl => url('/api/ocr');" in contract
    assert "OCR_QUEUE_BASE_URL" not in contract
    assert "analysisOcr" not in contract
    assert "socialWs" not in contract
    assert "SocialWebSocketService" not in friend_screen
    assert "Timer.periodic" in friend_screen
    assert "Timer.periodic" in direct_chat
    assert not (ROOT / "lib/shared/services/api/social_ws_service.dart").exists()


def test_root_readme_matches_vercel_default_and_lightning_ocr_boundary():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    contract = (ROOT / "lib/shared/services/api/api_contract.dart").read_text(
        encoding="utf-8"
    )

    assert "https://aiflow-web-canary.vercel.app" in contract
    assert "기본값: `https://aiflow-web-canary.vercel.app`" in readme
    assert "기본값 `http://localhost:8000`" not in readme
    assert "API_BASE_URL`을 Lightning 주소로 설정하지 않습니다" in readme
    assert "TexTeller 필기 OCR 추론만 수행합니다" in readme


def test_flutter_does_not_call_lightning_or_supabase_directly():
    forbidden = (
        "aiflow-ocr-canary.vercel.app",
        "lightning.ai",
        "supabase.co/rest/v1",
        "supabase.in/rest/v1",
        "Supabase.instance.client",
        "SupabaseClient(",
    )
    violations = []
    for source in (ROOT / "lib").rglob("*.dart"):
        content = source.read_text(encoding="utf-8").casefold()
        for marker in forbidden:
            if marker.casefold() in content:
                violations.append(f"{source.relative_to(ROOT)}: {marker}")

    assert not violations, (
        "Flutter must route product APIs through Vercel: " + ", ".join(violations)
    )


def test_flutter_grading_uses_the_registered_vercel_path_not_retired_analysis():
    client = (ROOT / "lib/shared/services/api/api_client.dart").read_text(
        encoding="utf-8"
    )
    dart_sources = "\n".join(
        source.read_text(encoding="utf-8")
        for source in (ROOT / "lib").rglob("*.dart")
    )

    assert "ApiContract.uri(ApiPaths.analysisVariantGrade)" in client
    assert "ApiContract.uri('/analysis/solve/variant-grade')" not in client
    assert "ApiPaths.analysisSolve" not in dart_sources


def test_problem_habit_client_uses_registered_vercel_route_constants():
    contract = (ROOT / "lib/shared/services/api/api_contract.dart").read_text(
        encoding="utf-8"
    )
    client = (ROOT / "lib/shared/services/api/api_client.dart").read_text(
        encoding="utf-8"
    )
    api = (ROOT / "api/index.py").read_text(encoding="utf-8")

    assert "static const problemHabits = '/habit/problem';" in contract
    assert "static const problemHabitReplay = '/habit/problem/replay';" in contract
    assert "ApiPaths.problemHabits" in client
    assert "ApiPaths.problemHabitReplay" in client
    assert "_get(\n      '/habit/problem'," not in client
    assert "_post<Map<String, dynamic>>('/habit/problem/replay'" not in client
    assert '@app.get("/habit/problem")' in api
    assert '@app.post("/habit/problem/replay")' in api


def test_synchronous_quest_generation_does_not_poll_an_unimplemented_job_route():
    client = (ROOT / "lib/shared/services/api/api_client.dart").read_text(
        encoding="utf-8"
    )
    screen = (
        ROOT / "lib/sessions/tryout_solve/session/quick_generate_page.dart"
    ).read_text(encoding="utf-8")
    generation = client.split("Future<Map<String, dynamic>> generateQuest(", 1)[1]
    generation = generation.split("Future<Map<String, dynamic>> cancelQuestGeneration(", 1)[0]

    assert "fetchQuestGenerateStatus" not in generation
    assert "fetchQuestGenerateStatus" not in screen
    assert "_startStatusPolling" not in screen
    assert "Quest generation response did not contain a quest" in generation


def test_lightning_only_receives_ocr_queue_wake_configuration():
    api = (ROOT / "api/index.py").read_text(encoding="utf-8")
    worker = (ROOT / "deploy/lightning/worker_app.py").read_text(encoding="utf-8")
    lightning_env = (ROOT / "deploy/lightning/lightning.env.example").read_text(
        encoding="utf-8"
    )

    assert '"mode": "ocr"' in api
    assert 'mode") != "ocr"' in worker
    assert "LIGHTNING_APP_URL" not in api
    assert '"/analysis/solve/variant-grade"' not in worker
    assert "SUPABASE_SERVICE_ROLE_KEY" not in worker
    assert "SUPABASE_SERVICE_ROLE_KEY" not in lightning_env
    assert "/internal/ocr/claim" in worker
    assert "/internal/ocr/claim" in api


def test_arena_uses_vercel_rest_without_unsupported_product_websocket_or_chat():
    api = (ROOT / "lib/features/arena/arena_api.dart").read_text(
        encoding="utf-8"
    )
    page = (ROOT / "lib/features/arena/arena_page.dart").read_text(
        encoding="utf-8"
    )
    contract = (ROOT / "lib/shared/services/api/api_contract.dart").read_text(
        encoding="utf-8"
    )
    manifest = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")

    assert "WebSocketChannel" not in api
    assert "ArenaApi.instance.connect" not in page
    assert '"/ws/arena"' not in api + page + contract
    assert "ArenaApi.instance.chat" not in page
    assert "_showTeamChat" not in page
    assert "webSocketUri" not in contract
    assert "web_socket_channel:" not in manifest


def test_private_ocr_worker_callbacks_are_rewritten_to_vercel_api():
    vercel = (ROOT / "vercel.json").read_text(encoding="utf-8")
    api = (ROOT / "api/index.py").read_text(encoding="utf-8")

    assert "api|internal" in vercel
    for route in (
        '@app.post("/internal/ocr/claim")',
        '@app.post("/internal/ocr/jobs/{job_id}/complete")',
        '@app.post("/internal/ocr/jobs/{job_id}/fail")',
    ):
        assert route in api
