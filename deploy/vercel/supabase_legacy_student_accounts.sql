-- Restore existing student identities and their personal data to Vercel storage.
-- UUIDs, PBKDF2 hashes/salts, profiles and source tables are preserved.
-- Teachers remain in the legacy users table. Conflicts abort the entire copy.
-- Run via tools/prepare_product_api_cutover.py so the protected snapshot exists.
begin;
set local lock_timeout='5s';
lock table public.users, public.user_kv, public.solve_history,
  public.canary_users, public.canary_user_kv in share row exclusive mode;

do $$ begin
  if to_regclass('aiflow_api_cutover_20261012.users') is null
  then raise exception 'protected_legacy_snapshot_required'; end if;
  if exists (
    select 1 from public.users where role='student' and (
      user_id !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      or password_hash !~ '^[0-9a-fA-F]{64}$' or salt is null or length(salt)<16
      or coalesce(status,'') not in ('','active','approved'))
  ) then raise exception 'legacy_student_account_validation_failed'; end if;
  if exists (
    select 1 from public.users u join public.canary_users c
      on c.username=u.username or c.user_id::text=u.user_id
    where u.role='student' and row(c.user_id::text,c.username,c.password_hash,c.salt,c.role)
      is distinct from row(u.user_id,u.username,u.password_hash,u.salt,u.role)
  ) then raise exception 'legacy_student_identity_conflict'; end if;
end $$;

insert into public.canary_users
  (user_id,username,name,grade,track,subject,school,profile_image,email,role,password_hash,salt,created_at)
select user_id::uuid,username,name,grade,track,subject,school,profile_image,email,
       role,password_hash,salt,created_at::timestamptz
from public.users where role='student'
on conflict do nothing;

do $$ begin
  if exists (
    select 1 from public.users u left join public.canary_users c on c.user_id::text=u.user_id
    where u.role='student' and (c.user_id is null or
      row(c.username,c.name,c.grade,c.track,c.subject,c.school,c.profile_image,c.email,
          c.role,c.password_hash,c.salt,c.created_at)
      is distinct from
      row(u.username,u.name,u.grade,u.track,u.subject,u.school,u.profile_image,u.email,
          u.role,u.password_hash,u.salt,u.created_at::timestamptz))
  ) then raise exception 'legacy_student_account_copy_verification_failed'; end if;
  if exists (select 1 from public.solve_history h
      left join public.canary_users c on c.user_id::text=h.user_id
      where c.user_id is null)
  then raise exception 'solve_history_owner_not_restored'; end if;
  if exists (select 1 from public.solve_history
      where id<1 or compressed not in (0,1) or kind not in ('problem','exam')
        or jsonb_typeof(data::jsonb) is distinct from 'object')
  then raise exception 'solve_history_payload_validation_failed'; end if;
end $$;

create temporary table api_cutover_kv_stage on commit drop as
select k.user_id::uuid as user_id,k.key,k.value,k.updated_at
from public.user_kv k join public.users u on u.user_id=k.user_id where u.role='student'
union all
select h.user_id::uuid,'solve_history.legacy.' || h.id,
  jsonb_build_object('source_row_id',h.id,'created_at',h.created_at,'kind',h.kind,
    'quest_id',h.quest_id,'exam_id',h.exam_id,'codebase_id',h.codebase_id,'seed',h.seed,
    'data',h.data::jsonb,'compressed',h.compressed<>0)::text,
  h.created_at::timestamptz
from public.solve_history h;

do $$ begin
  if exists (select 1 from api_cutover_kv_stage group by user_id,key having count(*)>1)
  then raise exception 'legacy_kv_duplicate_identity'; end if;
  if exists (select 1 from api_cutover_kv_stage s join public.canary_user_kv d
      using(user_id,key) where d.value is distinct from s.value)
  then raise exception 'legacy_kv_destination_conflict'; end if;
end $$;

insert into public.canary_user_kv(user_id,key,value,updated_at)
select user_id,key,value,updated_at from api_cutover_kv_stage
on conflict(user_id,key) do nothing;

do $$ begin
  if exists (select 1 from api_cutover_kv_stage s left join public.canary_user_kv d
      using(user_id,key) where d.key is null or d.value is distinct from s.value)
  then raise exception 'legacy_kv_copy_verification_failed'; end if;
end $$;

alter table public.users enable row level security;
alter table public.user_kv enable row level security;
alter table public.solve_history enable row level security;
alter table public.user_habit enable row level security;
revoke all on public.users,public.user_kv,public.solve_history,public.user_habit from anon,authenticated;
select jsonb_build_object('restored_student_accounts',(select count(*) from public.users where role='student'),
  'verified_personal_rows',(select count(*) from api_cutover_kv_stage)) as legacy_copy_report;
commit;
