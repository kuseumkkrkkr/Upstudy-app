"""Keep the Lightning worker's database lease restricted to OCR work."""
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

    assert "from analysis_service import analyze_pregrade" in worker
    assert "analyze_submission" not in worker
    assert "save_solve_history" not in worker
    assert 'FastAPI(title="AIFlow Handwriting OCR Worker")' in worker
