-- Operator preflight ONLY, in the separate ADMIN database. Not run by this audit.
-- Read-only snapshot; timeout/permission/schema failures must abort the cleanup.
begin transaction isolation level repeatable read read only;
set local statement_timeout = '15s';
set local lock_timeout = '1s';
do $$ begin
  if to_regclass('public.canary_content') is null
     or to_regclass('public.content_admin_accounts') is null
     or to_regclass('public.canary_users') is not null then
    raise exception 'Wrong database for admin content preflight';
  end if;
end $$;

select current_database(), current_user, current_setting('server_version');
select payload->>'kind' as kind, archived, count(*) as stored_override_count
from public.canary_content group by 1,2 order by 1,2;
-- These are overrides/tombstones, NOT the merged API catalogue count.
select id, payload->>'kind' as kind, version, archived,
       encode(sha256(convert_to(payload::text,'UTF8')),'hex') as payload_sha256
from public.canary_content order by id;
select count(*) as retained_audit_receipts from public.canary_content_changes;

select c.conname, c.conrelid::regclass as source_table,
       c.confrelid::regclass as referenced_table,
       pg_get_constraintdef(c.oid) as foreign_key_definition
from pg_constraint c join pg_namespace n on n.oid=c.connamespace
where c.contype='f' and n.nspname='public' order by 2,1;
-- Never output trigger arguments/function bodies: they may contain secrets.
select r.relname as table_name, t.tgname, t.tgenabled,
       p.proname as trigger_function, p.prosecdef as security_definer
from pg_trigger t join pg_class r on r.oid=t.tgrelid
join pg_namespace n on n.oid=r.relnamespace
join pg_proc p on p.oid=t.tgfoid
where n.nspname='public' and not t.tgisinternal order by 1,2;
select tablename, rowsecurity from pg_tables
where schemaname='public' order by tablename;
select p.proname, pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef, encode(sha256(convert_to(p.prosrc,'UTF8')),'hex') as body_sha256,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
       has_function_privilege('service_role',p.oid,'EXECUTE') as service_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname='admin_write_content';
select has_table_privilege('service_role','public.canary_content','DELETE') as direct_delete,
       has_table_privilege('service_role','public.canary_content','UPDATE') as direct_update;
rollback;
