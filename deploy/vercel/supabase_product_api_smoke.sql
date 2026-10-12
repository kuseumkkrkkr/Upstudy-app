-- Real PostgreSQL checks. Caller must ROLLBACK TO its savepoint after this file.
-- Every row below belongs to a new random test identity and is discarded.
do $$
declare
  uid uuid := gen_random_uuid();
  jid uuid := gen_random_uuid();
  worker uuid := gen_random_uuid();
  first_result jsonb;
  again jsonb;
  state jsonb;
  table_name text;
  proc_name text;
begin
  insert into public.canary_users(user_id,username,name,grade,password_hash,salt)
  values(uid,'api-qa-'||uid::text,'API rollback QA','QA',repeat('0',64),repeat('0',32));
  first_result := public.apply_rating_submission_v2(uid::text,'qa-submission','qa-flow',true,
    30,50,1,1,'[{"tag":"#qa","enter_huddles":[1.5],"correct":true}]',repeat('a',64));
  again := public.apply_rating_submission_v2(uid::text,'qa-submission','qa-flow',true,
    30,50,1,1,'[{"tag":"#qa","enter_huddles":[1.5],"correct":true}]',repeat('a',64));
  if first_result is distinct from again
     or (select recent_count from public.user_rating where user_id=uid::text)<>1
     or (select attempts from public.user_tag_rating where user_id=uid::text and tag='qa')<>1
  then raise exception 'rating_replay_failed'; end if;
  state := public.apply_rating_submission_v2(uid::text,'qa-submission','qa-flow',true,
    30,50,1,1,'[]',repeat('b',64));
  if state->>'status' is distinct from 'conflict'
  then raise exception 'rating_changed_body_not_rejected'; end if;

  first_result := public.complete_arena_practice_result(uid::text,'qa-'||uid::text,
    'duel_exam','arena-finish:qa-'||uid::text,10,5);
  again := public.complete_arena_practice_result(uid::text,'qa-'||uid::text,
    'duel_exam','arena-finish:qa-'||uid::text,10,5);
  if again->>'replayed' is distinct from 'true'
     or (select wins from public.arena_rating where user_id=uid::text and queue_type='duel_exam')<>1
     or (again->>'rating_after')::numeric<>1520
  then raise exception 'arena_result_replay_failed'; end if;
  state := public.get_arena_rankings_page(uid::text,'duel_exam',10,0,'','all');
  if state->'my_profile'->>'user_id' is distinct from uid::text
  then raise exception 'arena_ranking_owner_missing'; end if;

  state := public.save_continue_session_guarded(uid::text,'problem','qa-flow','[]',true,false,true);
  state := public.get_continue_session_guarded(uid::text,'problem','qa-flow');
  if state->>'state' is distinct from 'loaded' then raise exception 'continuation_read_failed'; end if;
  insert into public.ocr_jobs(id,user_id,idempotency_key,mode,payload,status,lease_owner)
  values(jid,uid::text,'qa-'||jid::text,'ocr',
    '{"student_work_image":"discard-after-ocr","grade_after_ocr":true,"quest_id":"qa-flow","submission_id":"qa-grade"}',
    'running','qa-worker');
  if not public.complete_ocr_job(jid,'qa-worker','{"all_ocr":"x=1"}')
  then raise exception 'ocr_completion_failed'; end if;
  if (select payload ? 'student_work_image' from public.ocr_jobs where id=jid)
  then raise exception 'handwriting_payload_not_scrubbed'; end if;
  state := public.claim_ocr_solve_grade(jid,gen_random_uuid()::text,worker,45);
  if state->>'state' is distinct from 'not_found' then raise exception 'ocr_owner_leak'; end if;
  state := public.claim_ocr_solve_grade(jid,uid::text,worker,45);
  if state->>'state' is distinct from 'claimed' then raise exception 'grade_claim_failed'; end if;
  state := public.claim_ocr_solve_grade(jid,uid::text,gen_random_uuid(),45);
  if state->>'state' is distinct from 'grading' then raise exception 'active_grade_lease_not_respected'; end if;
  if not public.complete_ocr_solve_grade_with_weakness(jid,uid::text,worker,
      '{"status":[{"status":"O"}],"is_correct":true}','["#qa","#qa"]')
  then raise exception 'grade_finalization_failed'; end if;
  if not public.complete_ocr_solve_grade_with_weakness(jid,uid::text,worker,
      '{"status":[{"status":"O"}],"is_correct":true}','["#qa","#qa"]')
  then raise exception 'grade_finalization_replay_failed'; end if;
  if (select count from public.user_weakness_tags where user_id=uid::text and tag='#qa')<>2
     or exists(select 1 from public.continue_session where user_id=uid::text)
     or (select count(*) from public.canary_user_kv where user_id=uid and key='solve_history.ocr.'||jid::text)<>1
  then raise exception 'grade_history_weakness_continuation_integrity_failed'; end if;

  if public.insert_ox_quiz_questions('#qa-unification','[{"question":"QA x=1?","answer":true}]',uid)<>1
     or public.insert_ox_quiz_questions('#qa-unification','[{"question":"QA x=1?","answer":true}]',uid)<>0
  then raise exception 'ox_duplicate_insert_failed'; end if;
  foreach table_name in array array['canary_users','canary_user_kv','user_rating','user_tag_rating',
      'rating_submission','ocr_jobs','user_weakness_tags','continue_session','arena_rating',
      'arena_match_result','arena_practice_join_request','ox_quiz_questions'] loop
    if not (select relrowsecurity from pg_class where oid=('public.'||table_name)::regclass)
       or has_table_privilege('anon','public.'||table_name,'select')
       or has_table_privilege('authenticated','public.'||table_name,'select')
    then raise exception 'product_table_access_policy_failed: %',table_name; end if;
  end loop;
  foreach proc_name in array array[
    'public.get_rating_user_snapshot(text)',
    'public.apply_rating_submission_v2(text,text,text,boolean,double precision,double precision,double precision,double precision,jsonb,text)',
    'public.claim_ocr_solve_grade(uuid,text,uuid,integer)',
    'public.complete_ocr_solve_grade_with_weakness(uuid,text,uuid,jsonb,jsonb)',
    'public.get_arena_rankings_page(text,text,integer,integer,text,text)',
    'public.insert_ox_quiz_questions(text,jsonb,uuid)'] loop
    if has_function_privilege('anon',proc_name,'execute')
       or has_function_privilege('authenticated',proc_name,'execute')
       or not has_function_privilege('service_role',proc_name,'execute')
    then raise exception 'product_rpc_access_policy_failed: %',proc_name; end if;
  end loop;
end $$;
select 'RPC_SMOKE_PASS: replay, conflict, ownership, OCR lease, atomic grade, continuation, OX, RLS' as result;
