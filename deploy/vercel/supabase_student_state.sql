-- User weakness and continuation snapshots copied from the legacy QUEST SQLite store.
-- Apply before deploying the Vercel-owned /weakness/tags and /continue/strokes routes.
create table if not exists public.user_weakness_tags (
  user_id text not null,
  tag text not null check (length(btrim(tag)) >= 1),
  count integer not null check (count >= 0),
  updated_at text not null,
  primary key (user_id, tag)
);
create index if not exists user_weakness_tags_order_idx
  on public.user_weakness_tags(user_id, count desc, updated_at desc);

create table if not exists public.continue_session (
  user_id text not null,
  kind text not null check (kind in ('problem','exam')),
  target_id text not null check (length(btrim(target_id)) between 1 and 200),
  strokes jsonb not null check (jsonb_typeof(strokes) = 'array'),
  created_at text not null,
  updated_at text not null,
  primary key (user_id, kind)
);
create index if not exists continue_session_expiry_idx
  on public.continue_session(user_id, updated_at desc);

alter table public.user_weakness_tags enable row level security;
alter table public.continue_session enable row level security;
revoke all on public.user_weakness_tags, public.continue_session from anon, authenticated;
grant select, insert, update, delete on public.user_weakness_tags, public.continue_session to service_role;

create or replace function public.try_parse_jsonb(p_value text)
returns jsonb language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
  if p_value is null then return null; end if;
  return p_value::jsonb;
exception when others then return null;
end $$;

create or replace function public.try_parse_timestamptz(p_value text)
returns timestamptz language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
  if p_value is null then return null; end if;
  return p_value::timestamptz;
exception when others then return null;
end $$;

create or replace function public.grade_status_all_correct(p_status jsonb)
returns boolean language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
  if p_status is null then return false; end if;
  if jsonb_typeof(p_status)<>'array' then return false; end if;
  if jsonb_array_length(p_status)=0 then return false; end if;
  return not exists (
    select 1 from jsonb_array_elements(p_status) as step(value)
    where jsonb_typeof(step.value)<>'object'
      or upper(coalesce(step.value->>'status',''))<>'O'
  );
end
$$;

-- Completion check is shared by read, write, and grade-finalization transactions.
create or replace function public.student_target_fully_correct(
  p_user_id text, p_kind text, p_target_id text
) returns boolean language plpgsql stable security definer set search_path=pg_catalog,public as $$
declare latest jsonb; score_sheet jsonb; total integer; correct_count integer;
begin
  select parsed.item into latest
  from public.canary_user_kv kv
  cross join lateral (select public.try_parse_jsonb(kv.value) as item) parsed
  where kv.user_id=p_user_id::uuid and kv.key like 'solve_history.%'
    and parsed.item->>'kind'=p_kind
    and parsed.item->>(case when p_kind='exam' then 'exam_id' else 'quest_id' end)=p_target_id
  order by public.try_parse_timestamptz(parsed.item->>'created_at') desc nulls last,
           kv.key desc
  limit 1;

  -- A correct answer to one exam question does not complete the entire exam.
  if p_kind='problem' and latest is not null and (
    coalesce(latest->'data'->>'is_correct','false')='true'
    or public.grade_status_all_correct(latest->'data'->'status')
  ) then return true; end if;

  if p_kind<>'exam' then return false; end if;
  select public.try_parse_jsonb(value) into score_sheet
  from public.canary_user_kv
  where user_id=p_user_id::uuid and key='exam_score_sheet:' || p_target_id
  limit 1;
  if score_sheet is null or jsonb_typeof(score_sheet)<>'array' then return false; end if;

  select max(case when value->>'problem_count' ~ '^[0-9]+$'
                  then (value->>'problem_count')::integer else null end),
         count(distinct value->>'problem_index') filter (
           where value->>'problem_index' ~ '^[0-9]+$'
             and public.grade_status_all_correct(value->'status'))
  into total, correct_count
  from jsonb_array_elements(score_sheet) as entry(value);
  return total is not null and total>0 and correct_count>=total;
end $$;

create or replace function public.save_continue_session_guarded(
  p_user_id text, p_kind text, p_target_id text, p_strokes jsonb,
  p_forced_exit boolean, p_completed boolean, p_allow_back boolean
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare now_utc text := to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
begin
  if p_user_id is null or length(btrim(p_user_id))=0
     or p_kind is null or p_kind not in ('problem','exam')
     or p_target_id is null or length(btrim(p_target_id)) not between 1 and 200
     or p_strokes is null or jsonb_typeof(p_strokes)<>'array'
     or p_forced_exit is null or p_completed is null or p_allow_back is null then
    raise exception 'invalid_continue_request' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id || ':' || p_kind || ':' || p_target_id,0));
  if public.student_target_fully_correct(p_user_id,p_kind,p_target_id) then
    delete from public.continue_session
    where user_id=p_user_id and kind=p_kind and target_id=p_target_id;
    return jsonb_build_object('state','completed','target_id',p_target_id,'strokes','[]'::jsonb,
                              'updated_at',null,'allow_back',false);
  end if;
  if p_completed or not p_allow_back then
    delete from public.continue_session
    where user_id=p_user_id and kind=p_kind and target_id=p_target_id;
    return jsonb_build_object('state','saved','target_id',p_target_id,'strokes','[]'::jsonb,
                              'updated_at',null,'allow_back',false);
  end if;
  if not p_forced_exit then
    raise exception 'forced_exit_must_be_true' using errcode='22023';
  end if;
  insert into public.continue_session(user_id,kind,target_id,strokes,created_at,updated_at)
  values(p_user_id,p_kind,p_target_id,p_strokes,now_utc,now_utc)
  on conflict(user_id,kind) do update set
    target_id=excluded.target_id, strokes=excluded.strokes, updated_at=excluded.updated_at;
  return jsonb_build_object('state','saved','target_id',p_target_id,'strokes',p_strokes,
                            'updated_at',now_utc,'allow_back',true);
end $$;

create or replace function public.get_continue_session_guarded(
  p_user_id text, p_kind text, p_target_id text
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare saved public.continue_session%rowtype;
begin
  if p_user_id is null or length(btrim(p_user_id))=0
     or p_kind is null or p_kind not in ('problem','exam')
     or p_target_id is null or length(btrim(p_target_id)) not between 1 and 200 then
    raise exception 'invalid_continue_request' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id || ':' || p_kind || ':' || p_target_id,0));
  if public.student_target_fully_correct(p_user_id,p_kind,p_target_id) then
    delete from public.continue_session
    where user_id=p_user_id and kind=p_kind and target_id=p_target_id;
    return jsonb_build_object('state','completed','target_id',p_target_id,'strokes','[]'::jsonb,
                              'updated_at',null,'allow_back',false);
  end if;
  delete from public.continue_session
  where user_id=p_user_id and kind=p_kind and updated_at <
    to_char((now()-interval '7 days') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
  select * into saved from public.continue_session
  where user_id=p_user_id and kind=p_kind and target_id=p_target_id;
  if not found then
    return jsonb_build_object('state','not_found','target_id',p_target_id,'strokes','[]'::jsonb,
                              'updated_at',null,'allow_back',false);
  end if;
  return jsonb_build_object('state','loaded','target_id',saved.target_id,'strokes',saved.strokes,
                            'updated_at',saved.updated_at,'allow_back',true);
end $$;

revoke all on function public.try_parse_jsonb(text), public.try_parse_timestamptz(text),
  public.grade_status_all_correct(jsonb), public.student_target_fully_correct(text,text,text),
  public.save_continue_session_guarded(text,text,text,jsonb,boolean,boolean,boolean),
  public.get_continue_session_guarded(text,text,text) from public,anon,authenticated;
grant execute on function public.save_continue_session_guarded(text,text,text,jsonb,boolean,boolean,boolean),
  public.get_continue_session_guarded(text,text,text) to service_role;

-- Grade, history, score-sheet, weakness, and continuation cleanup commit together.
create or replace function public.complete_ocr_solve_grade_with_weakness(
  p_job_id uuid, p_user_id text, p_worker_id uuid, p_grade_result jsonb,
  p_weakness_tags jsonb default '[]'::jsonb
) returns boolean language plpgsql security definer set search_path=pg_catalog as $$
declare
  job public.ocr_jobs%rowtype;
  changed integer;
  quest_id text;
  exam_id text;
  problem_index integer;
  problem_count integer;
  score_sheet jsonb;
  score_row jsonb;
  score_text text;
  updated_at_utc text := to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
begin
  if p_grade_result is null or jsonb_typeof(p_grade_result) <> 'object'
     or p_weakness_tags is null or jsonb_typeof(p_weakness_tags) <> 'array'
     or jsonb_array_length(p_weakness_tags) > 1000
     or exists (
       select 1 from jsonb_array_elements(p_weakness_tags) as tags(value)
       where jsonb_typeof(value) <> 'string' or length(btrim(value #>> '{}')) = 0
     ) then
    raise exception 'invalid_weakness_tags' using errcode='22023';
  end if;

  select * into job from public.ocr_jobs
  where id=p_job_id and user_id=p_user_id for update;
  if not found or job.status <> 'completed' then return false; end if;
  if job.grade_status='completed' then
    return job.grade_result is not distinct from p_grade_result;
  end if;
  if job.grade_status <> 'grading' or job.grade_lease_owner <> p_worker_id then return false; end if;

  quest_id := nullif(btrim(job.payload->>'quest_id'),'');
  exam_id := nullif(btrim(job.payload->>'exam_id'),'');
  if exam_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(p_user_id || ':exam:' || exam_id,0));
    begin problem_index := nullif(job.payload->>'problem_index','')::integer;
    exception when others then problem_index := null; end;
    begin problem_count := nullif(job.payload->>'problem_count','')::integer;
    exception when others then problem_count := null; end;
    if problem_index is null or problem_count is null or problem_index<1
       or problem_count<1 or problem_index>problem_count then
      raise exception 'invalid_exam_grade_metadata' using errcode='22023';
    end if;
  elsif quest_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(p_user_id || ':problem:' || quest_id,0));
  end if;

  update public.ocr_jobs set grade_status='completed', grade_result=p_grade_result,
    grade_error=null, grade_lease_owner=null, grade_lease_until=null, updated_at=now()
  where id=p_job_id and user_id=p_user_id and status='completed'
    and grade_status='grading' and grade_lease_owner=p_worker_id;
  get diagnostics changed=row_count;
  if changed <> 1 then return false; end if;

  insert into public.canary_user_kv(user_id,key,value)
  values(p_user_id::uuid,'solve_history.ocr.' || p_job_id::text,
    jsonb_build_object('created_at',updated_at_utc,
      'kind',case when exam_id is null then 'problem' else 'exam' end,
      'quest_id',quest_id,'exam_id',exam_id,
      'data',p_grade_result,'source_job_id',p_job_id)::text)
  on conflict(user_id,key) do nothing;

  if exam_id is not null then
    score_row := jsonb_build_object('problem_index',problem_index,'problem_count',problem_count,
      'status',coalesce(p_grade_result->'status','[]'::jsonb),
      'updated_at',extract(epoch from now())::bigint);
    select value into score_text from public.canary_user_kv
      where user_id=p_user_id::uuid and key='exam_score_sheet:' || exam_id for update;
    score_sheet := public.try_parse_jsonb(score_text);
    if jsonb_typeof(score_sheet)<>'array' then score_sheet := '[]'::jsonb; end if;
    select coalesce(jsonb_agg(entry.value),'[]'::jsonb) into score_sheet
      from jsonb_array_elements(score_sheet) as entry(value)
      where entry.value->>'problem_index' is distinct from problem_index::text;
    score_sheet := score_sheet || jsonb_build_array(score_row);
    insert into public.canary_user_kv(user_id,key,value)
      values(p_user_id::uuid,'exam_score_sheet:' || exam_id,score_sheet::text)
      on conflict(user_id,key) do update set value=excluded.value;
  end if;

  insert into public.user_weakness_tags(user_id,tag,count,updated_at)
  select p_user_id, btrim(value #>> '{}'), count(*), updated_at_utc
  from jsonb_array_elements(p_weakness_tags) as tags(value)
  group by btrim(value #>> '{}')
  on conflict(user_id,tag) do update set
    count=public.user_weakness_tags.count+excluded.count,
    updated_at=excluded.updated_at;

  if quest_id is not null and exam_id is null
     and public.grade_status_all_correct(p_grade_result->'status') then
    delete from public.continue_session
      where user_id=p_user_id and kind='problem' and target_id=quest_id;
  elsif exam_id is not null and public.student_target_fully_correct(p_user_id,'exam',exam_id) then
    delete from public.continue_session
      where user_id=p_user_id and kind='exam' and target_id=exam_id;
  end if;
  return true;
end $$;

revoke all on function public.complete_ocr_solve_grade_with_weakness(uuid,text,uuid,jsonb,jsonb)
  from public,anon,authenticated;
grant execute on function public.complete_ocr_solve_grade_with_weakness(uuid,text,uuid,jsonb,jsonb)
  to service_role;
