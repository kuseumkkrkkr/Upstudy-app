-- Read-only BookData storage preflight. No user rows or mutations.
select c.relrowsecurity as rls_enabled,
 has_table_privilege('anon','public.canary_user_kv','SELECT,INSERT,UPDATE,DELETE') as anon_any_access,
 has_table_privilege('authenticated','public.canary_user_kv','SELECT,INSERT,UPDATE,DELETE') as authenticated_any_access,
 has_table_privilege('service_role','public.canary_user_kv','SELECT') as service_select,
 has_table_privilege('service_role','public.canary_user_kv','INSERT') as service_insert,
 (select pg_get_constraintdef(p.oid) from pg_constraint p where p.conrelid=c.oid and p.contype='p') as primary_key
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='canary_user_kv';
