-- Run ONLY in the separate ADMIN Supabase project, never the student database.
begin;
do $$ begin
  if to_regclass('public.canary_users') is not null then
    raise exception 'Refusing admin migration in the student database';
  end if;
end $$;
create table if not exists public.content_admin_accounts (
  id uuid primary key,
  username text not null unique check (username ~ '^[A-Za-z0-9]{4,32}$'),
  password_hash text not null check (password_hash ~ '^[0-9a-f]{64}$'),
  salt text not null check (length(salt) >= 32),
  session_version integer not null default 1 check (session_version > 0),
  active boolean not null default true
);
create table if not exists public.content_admin_login_windows (
  username text primary key check (length(username) between 4 and 32),
  window_start timestamptz not null,
  attempts integer not null
);
create table if not exists public.canary_content (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9-]{2,119}$'),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  version integer not null check (version > 0),
  archived boolean not null default false,
  updated_by uuid not null references public.content_admin_accounts(id),
  updated_at timestamptz not null default now()
);
create table if not exists public.canary_content_changes (
  actor uuid not null references public.content_admin_accounts(id),
  request_key text not null check (length(request_key) between 1 and 160),
  fingerprint text not null,
  content_id text not null,
  before_payload jsonb,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor, request_key)
);
alter table public.content_admin_accounts enable row level security;
alter table public.content_admin_login_windows enable row level security;
alter table public.canary_content enable row level security;
alter table public.canary_content_changes enable row level security;
revoke all on public.content_admin_accounts, public.content_admin_login_windows, public.canary_content, public.canary_content_changes from public, anon, authenticated, service_role;
grant select,insert on public.content_admin_accounts to service_role;
grant select on public.canary_content to service_role;

create or replace function public.claim_content_admin_login(p_username text)
returns boolean language plpgsql security definer set search_path=pg_catalog,public as $$
declare n integer;
begin
  if p_username is null or p_username !~ '^[A-Za-z0-9]{4,32}$' then return false; end if;
  insert into public.content_admin_login_windows(username,window_start,attempts)
    values(p_username,now(),1)
    on conflict(username) do update set
      window_start=case when content_admin_login_windows.window_start < now()-interval '5 minutes' then now() else content_admin_login_windows.window_start end,
      attempts=case when content_admin_login_windows.window_start < now()-interval '5 minutes' then 1 else least(content_admin_login_windows.attempts+1,11) end
    returning attempts into n;
  return n <= 10;
end $$;
revoke all on function public.claim_content_admin_login(text) from public,anon,authenticated;
grant execute on function public.claim_content_admin_login(text) to service_role;

create or replace function public.admin_write_content(
  p_actor uuid, p_id text, p_payload jsonb, p_version integer,
  p_archived boolean, p_key text, p_operation text
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare
  previous public.canary_content%rowtype;
  receipt public.canary_content_changes%rowtype;
  signature text;
  result jsonb;
begin
  if not exists (select 1 from public.content_admin_accounts where id=p_actor and active) then
    return jsonb_build_object('error','not_admin');
  end if;
  if p_id is null or p_id !~ '^[a-z0-9][a-z0-9-]{2,119}$' or p_version is null or p_version < 0
     or p_archived is null or p_key is null or length(p_key) not between 1 and 160
     or p_operation is null or p_operation not in ('save','archive','restore')
     or (p_operation='archive') <> p_archived
     or p_payload is null or jsonb_typeof(p_payload) <> 'object' or octet_length(p_payload::text) > 100000 then
    raise exception 'invalid_content_request';
  end if;
  -- Archive/restore have no client body: reread metadata must not change a retry's identity.
  signature := encode(sha256(convert_to(jsonb_build_object('id',p_id,
    'payload',case when p_operation='save' then p_payload else null end,
    'version',p_version,'operation',p_operation)::text,'UTF8')),'hex');
  -- Same key on different content cannot race; then serialize all edits to this ID.
  perform pg_advisory_xact_lock(hashtextextended('content-key:'||p_actor::text||':'||p_key,0));
  select * into receipt from public.canary_content_changes where actor=p_actor and request_key=p_key;
  if found then
    if receipt.fingerprint <> signature then return jsonb_build_object('error','idempotency_conflict'); end if;
    return receipt.result;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('content-id:'||p_id,0));
  select * into previous from public.canary_content where id=p_id for update;
  if coalesce(previous.version,0) <> p_version then return jsonb_build_object('error','version_conflict'); end if;
  insert into public.canary_content(id,payload,version,archived,updated_by)
    values(p_id,p_payload,p_version+1,p_archived,p_actor)
    on conflict(id) do update set payload=excluded.payload, version=excluded.version,
      archived=excluded.archived, updated_by=excluded.updated_by, updated_at=now();
  result := jsonb_build_object('id',p_id,'version',p_version+1,'archived',p_archived);
  insert into public.canary_content_changes(actor,request_key,fingerprint,content_id,before_payload,result)
    values(p_actor,p_key,signature,p_id,previous.payload,result);
  return result;
end $$;
revoke all on function public.admin_write_content(uuid,text,jsonb,integer,boolean,text,text) from public,anon,authenticated;
grant execute on function public.admin_write_content(uuid,text,jsonb,integer,boolean,text,text) to service_role;
-- If an earlier draft was installed, retire its RPC access without deleting audit data.
do $$ begin
  if to_regprocedure('public.admin_write_content(uuid,text,jsonb,integer,boolean,text)') is not null then
    execute 'revoke all on function public.admin_write_content(uuid,text,jsonb,integer,boolean,text) from public,anon,authenticated,service_role';
  end if;
end $$;
commit;
