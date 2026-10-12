"""Keep the Lightning worker's database lease restricted to OCR work."""
import ast
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_claim_rpc_only_selects_ocr_jobs():
    sql = (ROOT / "deploy" / "vercel" / "supabase_ocr_queue.sql").read_text(
        encoding="utf-8"
    )
    claim_body = sql.split("create or replace function public.claim_ocr_job", 1)[1]
    claim_body = claim_body.split("create or replace function public.complete_ocr_job", 1)[0]

    assert "mode = 'ocr'" in claim_body


def test_lightning_worker_has_no_product_api_or_grading_imports():
    worker = (ROOT / "deploy" / "lightning" / "worker_app.py").read_text(
        encoding="utf-8"
    )

    assert "from services.ocr.texteller_grid import extract_math_with_texteller_grid" in worker
    assert "analysis_service" not in worker
    assert "analyze_submission" not in worker
    assert "SAM_API_KEY" not in worker
    assert "SUPABASE_SERVICE_ROLE_KEY" not in worker
    assert "VERCEL_OCR_WORKER_SECRET" in worker
    assert 'FastAPI(title="AIFlow Handwriting OCR Worker")' in worker


def test_lightning_worker_exposes_only_health_and_ocr_wake_routes():
    worker = (ROOT / "deploy" / "lightning" / "worker_app.py").read_text(
        encoding="utf-8"
    )
    routes = [
        line.strip()
        for line in worker.splitlines()
        if line.strip().startswith(("@app.get(", "@app.post(", "@app.put(", "@app.patch(", "@app.delete("))
    ]
    assert routes == ['@app.get("/health")', '@app.post("/wake", status_code=202)']


def test_lightning_receives_only_vercel_projected_handwriting_fields():
    worker = (ROOT / "deploy" / "lightning" / "worker_app.py").read_text(
        encoding="utf-8"
    )
    api = (ROOT / "api" / "index.py").read_text(encoding="utf-8")
    env = (ROOT / "deploy" / "lightning" / "lightning.env.example").read_text(
        encoding="utf-8"
    )

    assert '"student_work_image"' in api
    assert '"writing_events"' in api
    assert '"/internal/ocr/claim"' in worker
    assert '"/internal/ocr/jobs/{job_id}/complete"' in api
    assert '"/internal/ocr/jobs/{job_id}/fail"' in api
    assert "SUPABASE_URL" not in env
    assert "SUPABASE_SERVICE_ROLE_KEY" not in env
    assert "OMJ_JWT_SECRET" not in env
    assert "SAM_API_KEY" not in env


def test_lightning_wake_is_reachable_only_from_ocr_submission():
    tree = ast.parse((ROOT / "api" / "index.py").read_text(encoding="utf-8"))

    def callers(function_name: str) -> list[str]:
        return [
            owner.name
            for owner in ast.walk(tree)
            if isinstance(owner, (ast.FunctionDef, ast.AsyncFunctionDef))
            and any(
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == function_name
                for node in ast.walk(owner)
            )
        ]

    assert callers("_wake_lightning") == ["create_ocr_job"]
    assert callers("_start_lightning_studio") == ["_wake_lightning"]
