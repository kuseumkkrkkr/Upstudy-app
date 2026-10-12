"""Static safety contract for the Vercel-owned OCR-to-grading queue migration."""
from pathlib import Path


SQL = Path(__file__).parents[1] / "deploy" / "vercel" / "supabase_ocr_grading.sql"


def test_grading_migration_preserves_legacy_rows_and_ocr_media_scrubbing():
    sql = SQL.read_text(encoding="utf-8").lower()
    assert sql.lstrip().startswith(
        "-- vercel-only second stage for handwriting ocr jobs. apply after supabase_ocr_queue.sql.\n"
        "-- existing solve-mode rows remain as historical records; no rows are deleted.\n"
        "begin;"
    )
    assert sql.rstrip().endswith("commit;")
    assert "delete from public.ocr_jobs" not in sql
    assert "where mode='solve' and status in ('queued','running')" in sql
    assert "payload=jsonb_strip_nulls(jsonb_build_object(" in sql
    assert "'grade_after_ocr', payload->'grade_after_ocr'" in sql
    assert "mode = 'ocr' or (mode = 'solve' and status in ('completed','failed'))" in sql


def test_grade_claim_is_owner_fenced_leased_and_result_is_idempotently_cached():
    sql = SQL.read_text(encoding="utf-8").lower()
    assert "where id=p_job_id and user_id=p_user_id for update" in sql
    assert "grade_status='completed'" in sql
    assert "'state','completed','result',job.grade_result" in sql
    assert "grade_lease_owner=p_worker_id" in sql
    assert "grade_attempts>=3" in sql
    assert "to service_role" in sql
    assert "from public,anon,authenticated" in sql


def test_grade_completion_and_weakness_counts_are_atomic_and_replay_safe():
    sql_path = Path(__file__).parents[1] / "deploy" / "vercel" / "supabase_student_state.sql"
    sql = sql_path.read_text(encoding="utf-8").lower()
    assert "create or replace function public.complete_ocr_solve_grade_with_weakness" in sql
    assert "where kv.user_id=p_user_id::uuid" in sql
    assert "values(p_user_id::uuid,'solve_history.ocr.'" in sql
    assert "where user_id=p_user_id::uuid and key='exam_score_sheet:'" in sql
    assert "values(p_user_id::uuid,'exam_score_sheet:'" in sql
    assert "where id=p_job_id and user_id=p_user_id for update" in sql
    assert "if job.grade_status='completed' then" in sql
    assert "return job.grade_result is not distinct from p_grade_result" in sql
    assert "grade_status='completed', grade_result=p_grade_result" in sql
    assert "insert into public.user_weakness_tags" in sql
    assert "count=public.user_weakness_tags.count+excluded.count" in sql
    assert "revoke all on function public.complete_ocr_solve_grade_with_weakness" in sql
    assert "to service_role" in sql
    assert "from public,anon,authenticated" in sql


def test_grade_completion_persists_exam_progress_and_only_blocks_fully_correct_exam():
    sql_path = Path(__file__).parents[1] / "deploy" / "vercel" / "supabase_student_state.sql"
    sql = sql_path.read_text(encoding="utf-8").lower()
    assert "'solve_history.ocr.' || p_job_id::text" in sql
    assert "'exam_score_sheet:' || exam_id" in sql
    assert "p_kind='problem' and latest is not null" in sql
    assert "correct_count>=total" in sql
    assert "delete from public.continue_session" in sql
    # The grade history, score sheet, weakness counters and continuation cleanup
    # are all in the same service-role RPC transaction.
    function = sql.split("create or replace function public.complete_ocr_solve_grade_with_weakness", 1)[1]
    assert "insert into public.canary_user_kv" in function
    assert "insert into public.user_weakness_tags" in function
    assert "delete from public.continue_session" in function
    assert "to service_role" in function


def test_problem_grade_and_continue_share_the_same_target_lock():
    sql_path = Path(__file__).parents[1] / "deploy" / "vercel" / "supabase_student_state.sql"
    sql = sql_path.read_text(encoding="utf-8").lower()
    save = sql.split("create or replace function public.save_continue_session_guarded", 1)[1]
    save = save.split("create or replace function public.get_continue_session_guarded", 1)[0]
    complete = sql.split("create or replace function public.complete_ocr_solve_grade_with_weakness", 1)[1]
    problem_branch = complete.split("elsif quest_id is not null then", 1)[1].split("end if;", 1)[0]
    grade_write = complete.split("update public.ocr_jobs set grade_status='completed'", 1)[0]

    assert "hashtextextended(p_user_id || ':' || p_kind || ':' || p_target_id,0)" in save
    assert "hashtextextended(p_user_id || ':problem:' || quest_id,0)" in problem_branch
    assert "pg_advisory_xact_lock" in grade_write


def test_security_definer_sql_pins_search_path_to_system_catalog_first():
    root = Path(__file__).parents[1] / "deploy" / "vercel"
    for name in (
        "supabase_auth.sql",
        "supabase_ocr_queue.sql",
        "supabase_ocr_grading.sql",
        "supabase_student_state.sql",
        "supabase_rating.sql",
        "supabase_arena_rankings.sql",
    ):
        sql = (root / name).read_text(encoding="utf-8").lower()
        assert "security definer set search_path=public" not in sql, name
    assert "security definer set search_path=pg_catalog,public" in (
        root / "supabase_ocr_queue.sql"
    ).read_text(encoding="utf-8").lower()
