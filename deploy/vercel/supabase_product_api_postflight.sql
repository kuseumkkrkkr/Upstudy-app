-- Read-only evidence after applying product-api-cutover-apply.sql.
select jsonb_build_object(
  'accounts',(select count(*) from public.canary_users),
  'personal_rows',(select count(*) from public.canary_user_kv),
  'restored_students',(select count(*) from public.users u join public.canary_users c
    on c.user_id::text=u.user_id where u.role='student' and c.password_hash=u.password_hash and c.salt=u.salt),
  'copied_history',(select count(*) from public.canary_user_kv where key like 'solve_history.legacy.%'),
  'legacy_rating_rows',(select count(*) from public.user_rating),
  'legacy_tag_rows',(select count(*) from public.user_tag_rating),
  'legacy_receipt_rows',(select count(*) from public.rating_submission),
  'original_accounts_preserved',not exists(
    select 1 from aiflow_api_cutover_20261012.canary_users b left join public.canary_users c using(user_id)
    where to_jsonb(b) is distinct from to_jsonb(c)),
  'original_nonvolatile_rows_preserved',not exists(
    select 1 from aiflow_api_cutover_20261012.canary_user_kv b left join public.canary_user_kv c using(user_id,key)
    where b.key<>'arena.active_match' and to_jsonb(b) is distinct from to_jsonb(c)),
  'arena_only_allowed_answer_changes',not exists(
    select 1 from aiflow_api_cutover_20261012.canary_user_kv b left join public.canary_user_kv c using(user_id,key)
    where b.key='arena.active_match' and (c.key is null or
      (b.value::jsonb-'answers'-'answers_purged') is distinct from
      (c.value::jsonb-'answers'-'answers_purged'))),
  'backup_contains_no_match_answers',not exists(
    select 1 from aiflow_api_cutover_20261012.canary_user_kv
    where key='arena.active_match' and value::jsonb ? 'answers'),
  'rating_rows_unchanged',not exists(
    select 1 from aiflow_api_cutover_20261012.user_rating b full join public.user_rating c using(user_id)
    where to_jsonb(b) is distinct from to_jsonb(c)),
  'tag_rows_unchanged',not exists(
    select 1 from aiflow_api_cutover_20261012.user_tag_rating b full join public.user_tag_rating c using(user_id,tag)
    where to_jsonb(b) is distinct from to_jsonb(c)),
  'receipt_rows_unchanged',not exists(
    select 1 from aiflow_api_cutover_20261012.rating_submission b full join public.rating_submission c using(user_id,submission_id)
    where to_jsonb(b) is distinct from (to_jsonb(c)-'request_fingerprint')),
  'history_source_unchanged',not exists(
    select 1 from aiflow_api_cutover_20261012.solve_history b full join public.solve_history c using(id)
    where to_jsonb(b) is distinct from to_jsonb(c)),
  'public_tables_without_rls',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and not c.relrowsecurity and c.relname in (
      'canary_users','canary_user_kv','user_rating','user_tag_rating','rating_submission','ocr_jobs',
      'user_weakness_tags','continue_session','arena_rating','arena_match_result','arena_practice_join_request','ox_quiz_questions')),
  'backup_anon_blocked',not has_schema_privilege('anon','aiflow_api_cutover_20261012','usage'),
  'required_rpc_names',(select jsonb_agg(p.proname order by p.proname) from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in (
      'get_rating_user_snapshot','apply_rating_submission_v2','claim_ocr_solve_grade',
      'complete_ocr_solve_grade_with_weakness','get_continue_session_guarded','save_continue_session_guarded',
      'get_arena_rankings_page','complete_arena_practice_result','start_arena_practice_match',
      'submit_arena_practice_answer','insert_ox_quiz_questions','purge_expired_arena_answers')),
  'level_test_questions',(select count(*) from public.level_test_question_bank)
) as verified_product_storage;
