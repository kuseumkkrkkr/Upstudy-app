-- Vercel-only second stage for handwriting OCR jobs. Apply after supabase_ocr_queue.sql.
-- Existing solve-mode rows remain as historical records; no rows are deleted.
begin;

alter table public.ocr_jobs
  add column if not exists grade_status text not null default 'not_required'
    check (grade_status in ('not_required','pending','grading','completed','failed')),
  add column if not exists grade_result jsonb,
  add column if not exists grade_error text,
  add column if not exists grade_attempts integer not null default 0,
  add column if not exists grade_lease_owner uuid,
  add column if not exists grade_lease_until timestamptz;

update public.ocr_jobs
set status='failed', error='legacy_solve_job_requires_resubmission', updated_at=now()
where mode='solve' and status in ('queued','running');

alter table public.ocr_jobs drop constraint if exists ocr_jobs_mode_check;
alter table public.ocr_jobs add constraint ocr_jobs_mode_check
  check (mode = 'ocr' or (mode = 'solve' and status in ('completed','failed')));

create index if not exists ocr_jobs_grade_claim_idx
  on public.ocr_jobs(grade_status, grade_lease_until, created_at)
  where grade_status in ('pending','grading');

create or replace function public.complete_ocr_job(
  p_job_id uuid, p_worker_id text, p_result jsonb
) returns boolean language plpgsql security definer set search_path=pg_catalog,public as $$
declare changed integer;
begin
  update public.ocr_jobs
  set status='completed', result=p_result, error=null,
      grade_status=case when payload @> '{"grade_after_ocr":true}'::jsonb
                        then 'pending' else 'not_required' end,
      payload=jsonb_strip_nulls(jsonb_build_object(
        'quest_id', payload->'quest_id',
        'submission_id', payload->'submission_id',
        'grade_after_ocr', payload->'grade_after_ocr',
        'exam_id', payload->'exam_id',
        'problem_index', payload->'problem_index',
        'problem_count', payload->'problem_count')),
      lease_owner=null, lease_until=null, updated_at=now()
  where id=p_job_id and mode='ocr' and status='running' and lease_owner=p_worker_id;
  get diagnostics changed=row_count;
  return changed=1;
end $$;

create or replace function public.claim_ocr_solve_grade(
  p_job_id uuid, p_user_id text, p_worker_id uuid,
  p_lease_seconds integer default 45
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare job public.ocr_jobs%rowtype;
begin
  select * into job from public.ocr_jobs
  where id=p_job_id and user_id=p_user_id for update;
  if not found then return jsonb_build_object('state','not_found'); end if;
  if job.status <> 'completed' then
    return jsonb_build_object('state','ocr_not_completed');
  end if;
  if job.grade_status='completed' then
    return jsonb_build_object('state','completed','result',job.grade_result);
  end if;
  if job.grade_status='not_required' then
    return jsonb_build_object('state','not_required');
  end if;
  if job.grade_status='failed' or job.grade_attempts>=3 then
    update public.ocr_jobs set grade_status='failed'
    where id=p_job_id and user_id=p_user_id;
    return jsonb_build_object('state','failed','error',coalesce(job.grade_error,'grading_attempts_exhausted'));
  end if;
  if job.grade_status='grading' and job.grade_lease_until > now() then
    return jsonb_build_object('state','grading');
  end if;
  update public.ocr_jobs set grade_status='grading',
    grade_attempts=grade_attempts+1, grade_error=null,
    grade_lease_owner=p_worker_id,
    grade_lease_until=now()+make_interval(secs=>greatest(15,least(p_lease_seconds,90))),
    updated_at=now()
  where id=p_job_id and user_id=p_user_id
  returning * into job;
  return jsonb_build_object(
    'state','claimed','job_id',job.id,'worker_id',p_worker_id,
    'quest_id',job.payload->>'quest_id',
    'submission_id',job.payload->>'submission_id',
    'exam_id',job.payload->>'exam_id',
    'problem_index',job.payload->>'problem_index',
    'problem_count',job.payload->>'problem_count',
    'ocr_result',job.result);
end $$;

create or replace function public.complete_ocr_solve_grade(
  p_job_id uuid, p_user_id text, p_worker_id uuid, p_grade_result jsonb
) returns boolean language plpgsql security definer set search_path=pg_catalog,public as $$
declare changed integer;
begin
  update public.ocr_jobs set grade_status='completed', grade_result=p_grade_result,
    grade_error=null, grade_lease_owner=null, grade_lease_until=null, updated_at=now()
  where id=p_job_id and user_id=p_user_id and status='completed'
    and grade_status='grading' and grade_lease_owner=p_worker_id;
  get diagnostics changed=row_count;
  return changed=1;
end $$;

create or replace function public.fail_ocr_solve_grade(
  p_job_id uuid, p_user_id text, p_worker_id uuid, p_error text
) returns boolean language plpgsql security definer set search_path=pg_catalog,public as $$
declare changed integer;
begin
  update public.ocr_jobs set
    grade_status=case when grade_attempts>=3 then 'failed' else 'pending' end,
    grade_error=left(p_error,1000), grade_lease_owner=null, grade_lease_until=null,
    updated_at=now()
  where id=p_job_id and user_id=p_user_id and grade_status='grading'
    and grade_lease_owner=p_worker_id;
  get diagnostics changed=row_count;
  return changed=1;
end $$;

revoke all on function public.claim_ocr_solve_grade(uuid,text,uuid,integer) from public,anon,authenticated;
revoke all on function public.complete_ocr_solve_grade(uuid,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.fail_ocr_solve_grade(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.claim_ocr_solve_grade(uuid,text,uuid,integer) to service_role;
grant execute on function public.complete_ocr_solve_grade(uuid,text,uuid,jsonb) to service_role;
grant execute on function public.fail_ocr_solve_grade(uuid,text,uuid,text) to service_role;

commit;
