-- Schedule a server-side fallback for the per-user five-minute result ACK.
-- Run after supabase_arena_rankings.sql; this does not retain or export answers.
begin;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  if not exists (
    select 1 from cron.job where jobname='aiflow-arena-answer-cleanup'
  ) then
    perform cron.schedule(
      'aiflow-arena-answer-cleanup',
      '* * * * *',
      'select public.purge_expired_arena_answers();'
    );
  end if;
end $$;

commit;
