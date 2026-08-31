-- Vercel 카나리 인증이 HTTPS Data API로 사용하는 사용자 저장소다.
create table if not exists public.canary_users (
  user_id uuid primary key,
  username text not null unique,
  name text not null,
  grade text not null,
  track text,
  subject text,
  school text,
  profile_image text,
  email text,
  role text not null default 'student' check (role = 'student'),
  password_hash text not null,
  salt text not null,
  created_at timestamptz not null default now()
);

create index if not exists canary_users_created_idx
  on public.canary_users(created_at desc);

alter table public.canary_users enable row level security;
revoke all on public.canary_users from anon, authenticated;
grant select, insert, update, delete on public.canary_users to service_role;

create table if not exists public.canary_user_kv (
  user_id uuid not null references public.canary_users(user_id) on delete cascade,
  key text not null,
  value text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table public.canary_user_kv enable row level security;
revoke all on public.canary_user_kv from anon, authenticated;
grant select, insert, update, delete on public.canary_user_kv to service_role;

-- 카나리 종료 후 사용자 정보를 명시적으로 파기할 수 있다.
create or replace function public.delete_all_canary_users() returns bigint
language plpgsql security definer set search_path=public as $$
declare changed bigint;
begin
  delete from public.canary_users;
  get diagnostics changed=row_count;
  return changed;
end $$;

revoke all on function public.delete_all_canary_users() from public,anon,authenticated;
grant execute on function public.delete_all_canary_users() to service_role;
