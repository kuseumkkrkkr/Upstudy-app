-- Operator preflight ONLY, in the STUDENT database. Not run by this audit.
-- No account/ownership/progress/answer/level-test updates, even temporary ones.
begin transaction isolation level repeatable read read only;
set local statement_timeout = '15s';
set local lock_timeout = '1s';
do $$ begin
  if to_regclass('public.canary_users') is null
     or to_regclass('public.canary_user_kv') is null
     or to_regclass('public.content_admin_accounts') is not null then
    raise exception 'Wrong database for student preservation preflight';
  end if;
end $$;
select current_database(), current_user, current_setting('server_version');
select count(*) as preserved_accounts from public.canary_users;
select case
  when key='marketplace_owned' then 'marketplace_owned'
  when key='course_enrollment_order' then 'course_enrollment_order'
  when key like 'textbook.private.%' then 'private_textbooks'
  when key like 'solve_history.%' then 'solve_history'
  when key like 'level_test.v2.%' then 'level_test_v2'
  else 'other_preserved_kv' end as family, count(*) as rows
from public.canary_user_kv group by 1 order by 1;
-- Logical JSON references, not SQL FKs. Malformed JSON must abort, not be erased.
with ownership as materialized (
  select value::jsonb as payload from public.canary_user_kv where key='marketplace_owned'
)
select listing_id, count(*) as owner_rows
from ownership cross join lateral jsonb_object_keys(payload) as ids(listing_id)
group by listing_id order by listing_id;

select c.conname, c.conrelid::regclass as source_table,
       c.confrelid::regclass as referenced_table,
       pg_get_constraintdef(c.oid) as foreign_key_definition
from pg_constraint c join pg_namespace n on n.oid=c.connamespace
where c.contype='f' and n.nspname='public' order by 2,1;
select r.relname as table_name, t.tgname, t.tgenabled,
       p.proname as trigger_function, p.prosecdef as security_definer
from pg_trigger t join pg_class r on r.oid=t.tgrelid
join pg_namespace n on n.oid=r.relnamespace
join pg_proc p on p.oid=t.tgfoid
where n.nspname='public' and not t.tgisinternal order by 1,2;
select tablename, rowsecurity from pg_tables
where schemaname='public' order by tablename;
rollback;
