-- Supabase SQL Editor에서 한 번 실행하는 AIFlow 비동기 OCR 큐다.
create extension if not exists pgcrypto;

create table if not exists public.ocr_jobs (
  id uuid primary key default gen_random_uuid(), user_id text not null,
  idempotency_key text not null, mode text not null check (mode in ('solve','ocr')),
  payload jsonb not null, status text not null default 'queued'
    check (status in ('queued','running','completed','failed')),
  result jsonb, error text, attempts integer not null default 0,
  lease_owner text, lease_until timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '1 day'),
  unique (user_id, idempotency_key)
);
create index if not exists ocr_jobs_claim_idx on public.ocr_jobs(status, created_at)
  where status in ('queued','running');
create index if not exists ocr_jobs_user_idx on public.ocr_jobs(user_id, created_at desc);
create index if not exists ocr_jobs_expiry_idx on public.ocr_jobs(expires_at);
alter table public.ocr_jobs enable row level security;
revoke all on public.ocr_jobs from anon, authenticated;

create or replace function public.claim_ocr_job(p_worker_id text, p_lease_seconds integer default 600)
returns setof public.ocr_jobs language plpgsql security definer set search_path=public as $$
begin
  return query with candidate as (
    select id from public.ocr_jobs
    where expires_at > now() and attempts < 3
      and (status='queued' or (status='running' and lease_until < now()))
    order by created_at for update skip locked limit 1
  ) update public.ocr_jobs j set status='running', attempts=j.attempts+1,
      lease_owner=p_worker_id,
      lease_until=now()+make_interval(secs=>greatest(60,least(p_lease_seconds,900))), updated_at=now()
    from candidate where j.id=candidate.id returning j.*;
end $$;

create or replace function public.complete_ocr_job(p_job_id uuid,p_worker_id text,p_result jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
declare changed integer; begin
  update public.ocr_jobs set status='completed',result=p_result,error=null,payload='{}'::jsonb,
    lease_owner=null,lease_until=null,updated_at=now()
  where id=p_job_id and status='running' and lease_owner=p_worker_id;
  get diagnostics changed=row_count; return changed=1;
end $$;

create or replace function public.fail_ocr_job(p_job_id uuid,p_worker_id text,p_error text)
returns boolean language plpgsql security definer set search_path=public as $$
declare changed integer; begin
  update public.ocr_jobs set status=case when attempts>=3 then 'failed' else 'queued' end,
    error=left(p_error,2000),lease_owner=null,lease_until=null,updated_at=now()
  where id=p_job_id and status='running' and lease_owner=p_worker_id;
  get diagnostics changed=row_count; return changed=1;
end $$;

create or replace function public.delete_expired_ocr_jobs() returns bigint
language plpgsql security definer set search_path=public as $$
declare changed bigint; begin delete from public.ocr_jobs where expires_at<now();
get diagnostics changed=row_count; return changed; end $$;

revoke all on function public.claim_ocr_job(text,integer) from public,anon,authenticated;
revoke all on function public.complete_ocr_job(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.fail_ocr_job(uuid,text,text) from public,anon,authenticated;
revoke all on function public.delete_expired_ocr_jobs() from public,anon,authenticated;
grant execute on function public.claim_ocr_job(text,integer) to service_role;
grant execute on function public.complete_ocr_job(uuid,text,jsonb) to service_role;
grant execute on function public.fail_ocr_job(uuid,text,text) to service_role;
grant execute on function public.delete_expired_ocr_jobs() to service_role;

