-- Vercel-owned arena leaderboard data. Copy existing PostgreSQL arena_rating
-- rows before routing rankings to this table; no legacy rows are deleted.
begin;

create table if not exists public.arena_rating (
  user_id text not null,
  queue_type text not null check (queue_type in ('duel_exam','duel_ox','team_exam','team_ox')),
  rating double precision not null default 1500,
  deviation double precision not null default 350,
  volatility double precision not null default 0.06,
  mu double precision not null default 25,
  sigma double precision not null default 8.333333,
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  draws integer not null default 0 check (draws >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, queue_type)
);
create index if not exists arena_rating_queue_rank_idx
  on public.arena_rating(queue_type, rating desc, updated_at asc, user_id asc);
alter table public.arena_rating enable row level security;
revoke all on public.arena_rating from anon, authenticated;
grant select on public.arena_rating to service_role;

create or replace function public.get_arena_rankings_page(
  p_user_id text, p_queue_type text, p_limit integer default 100,
  p_offset integer default 0, p_query text default '', p_scope text default 'all'
) returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public as $$
declare result jsonb;
begin
  if p_user_id is null or length(p_user_id) = 0
     or p_queue_type is null or p_queue_type not in ('duel_exam','team_exam')
     or p_limit is null or p_limit not between 1 and 100
     or p_offset is null or p_offset < 0
     or length(coalesce(p_query,'')) > 80
     or p_scope is null or p_scope not in ('all','my_tier','friends') then
    raise exception 'invalid_arena_ranking_query' using errcode='22023';
  end if;

  with ranked as materialized (
    select a.user_id, a.rating, a.wins, a.losses, a.draws,
      row_number() over(order by a.rating desc, a.updated_at asc, a.user_id asc)::bigint as position,
      nullif(btrim(u.name),'') as name, u.profile_image,
      exists (
        select 1 from public.canary_user_kv f
        where f.user_id=p_user_id::uuid
          and f.key='social.friend.' || a.user_id
      ) as friend,
      case when a.rating >= 2000 then 'A' when a.rating >= 1750 then 'B'
           when a.rating >= 1500 then 'C' when a.rating >= 1000 then 'D' else 'E' end as tier
    from public.arena_rating a
    left join public.canary_users u on u.user_id::text=a.user_id
    where a.queue_type=p_queue_type
  ), filtered as (
    select r.*, row_number() over(order by r.position)::bigint as filtered_position
    from ranked r
    where (coalesce(p_query,'')='' or strpos(lower(coalesce(r.name,'')),lower(p_query))>0)
      and (p_scope='all'
        or (p_scope='my_tier' and r.tier=(select me.tier from ranked me where me.user_id=p_user_id))
        or (p_scope='friends' and (r.user_id=p_user_id or r.friend)))
  ), page as (
    select * from filtered where filtered_position > p_offset
      and filtered_position <= p_offset+p_limit
  ), totals as (select count(*)::integer as total from filtered)
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(jsonb_build_object(
      'user_id', p.user_id, 'rating', p.rating, 'wins', p.wins,
      'losses', p.losses, 'draws', p.draws, 'rank', p.position,
      'name', p.name, 'profile_image', p.profile_image, 'tier', p.tier, 'friend', p.friend
    ) order by p.position) from page p), '[]'::jsonb),
    'total', t.total,
    'my_rank', (select me.position from ranked me where me.user_id=p_user_id),
    'my_profile', (select jsonb_build_object(
      'user_id', me.user_id, 'rating', me.rating, 'wins', me.wins,
      'losses', me.losses, 'draws', me.draws, 'rank', me.position,
      'name', me.name, 'profile_image', me.profile_image, 'tier', me.tier, 'friend', me.friend
    ) from ranked me where me.user_id=p_user_id),
    'viewer_user_id', p_user_id, 'limit', p_limit, 'offset', p_offset,
    'has_more', p_offset+p_limit<t.total, 'query', p_query, 'scope', p_scope
  ) into result from totals t;
  return result;
end $$;

revoke all on function public.get_arena_rankings_page(text,text,integer,integer,text,text)
  from public,anon,authenticated;
grant execute on function public.get_arena_rankings_page(text,text,integer,integer,text,text)
  to service_role;

-- Minimal immutable result ledger: persist only scores and rating movement,
-- never the submitted answer or analysis payload that the result UI later purges.
create table if not exists public.arena_match_result (
  match_id text primary key,
  user_id text not null,
  queue_type text not null check (queue_type = 'duel_exam'),
  idempotency_key text not null unique,
  player_score integer not null check (player_score between 0 and 100),
  opponent_score integer not null check (opponent_score between 0 and 100),
  outcome text not null check (outcome in ('win','loss','draw')),
  rating_before double precision not null,
  rating_after double precision not null,
  rating_delta double precision not null,
  created_at timestamptz not null default now()
);
alter table public.arena_match_result enable row level security;
revoke all on public.arena_match_result from public, anon, authenticated, service_role;

create or replace function public.complete_arena_practice_result(
  p_user_id text,
  p_match_id text,
  p_queue_type text,
  p_idempotency_key text,
  p_player_score integer,
  p_opponent_score integer
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
declare
  existing public.arena_match_result%rowtype;
  v_outcome text;
  v_delta double precision;
  v_before double precision;
  v_after double precision;
  v_result jsonb;
begin
  if p_user_id is null or length(p_user_id) not between 1 and 128
     or p_match_id is null or length(p_match_id) not between 1 and 128
     or p_queue_type is distinct from 'duel_exam'
     or p_idempotency_key is distinct from 'arena-finish:' || p_match_id
     or p_player_score is null or p_player_score not between 0 and 100
     or p_opponent_score is null or p_opponent_score not between 0 and 100 then
    raise exception 'invalid_arena_practice_result' using errcode='22023';
  end if;

  v_outcome := case when p_player_score > p_opponent_score then 'win'
                    when p_player_score < p_opponent_score then 'loss' else 'draw' end;
  v_delta := case v_outcome when 'win' then 20.0 when 'loss' then -10.0 else 0.0 end;

  -- Serialize same-match retries before the primary-key check and rating lock.
  perform pg_advisory_xact_lock(hashtextextended(p_match_id, 0));
  select * into existing from public.arena_match_result
    where match_id=p_match_id for update;
  if found then
    if existing.user_id is distinct from p_user_id
       or existing.queue_type is distinct from p_queue_type
       or existing.idempotency_key is distinct from p_idempotency_key
       or existing.player_score is distinct from p_player_score
       or existing.opponent_score is distinct from p_opponent_score
       or existing.outcome is distinct from v_outcome then
      raise exception 'arena_result_idempotency_conflict' using errcode='23505';
    end if;
    return jsonb_build_object(
      'outcome', existing.outcome,
      'rating_before', existing.rating_before,
      'rating_after', existing.rating_after,
      'rating_delta', existing.rating_delta,
      'replayed', true
    );
  end if;

  insert into public.arena_rating (user_id, queue_type)
    values (p_user_id, p_queue_type)
    on conflict (user_id, queue_type) do nothing;
  select rating into v_before from public.arena_rating
    where user_id=p_user_id and queue_type=p_queue_type for update;
  v_after := greatest(0.0, v_before + v_delta);

  update public.arena_rating set
    rating=v_after,
    wins=wins + case when v_outcome='win' then 1 else 0 end,
    losses=losses + case when v_outcome='loss' then 1 else 0 end,
    draws=draws + case when v_outcome='draw' then 1 else 0 end,
    updated_at=now()
    where user_id=p_user_id and queue_type=p_queue_type;

  insert into public.arena_match_result (
    match_id,user_id,queue_type,idempotency_key,player_score,opponent_score,
    outcome,rating_before,rating_after,rating_delta
  ) values (
    p_match_id,p_user_id,p_queue_type,p_idempotency_key,p_player_score,p_opponent_score,
    v_outcome,v_before,v_after,v_after-v_before
  );
  v_result := jsonb_build_object(
    'outcome', v_outcome,
    'rating_before', v_before,
    'rating_after', v_after,
    'rating_delta', v_after-v_before,
    'replayed', false
  );
  return v_result;
end $$;

revoke all on function public.complete_arena_practice_result(text,text,text,text,integer,integer)
  from public,anon,authenticated;
grant execute on function public.complete_arena_practice_result(text,text,text,text,integer,integer)
  to service_role;

create table if not exists public.arena_practice_join_request (
  user_id uuid not null,
  idempotency_key text not null,
  match_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id,idempotency_key)
);
alter table public.arena_practice_join_request enable row level security;
revoke all on public.arena_practice_join_request from public,anon,authenticated,service_role;

create or replace function public.start_arena_practice_match(
  p_user_id uuid, p_match_id text, p_match_json jsonb, p_idempotency_key text
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
declare v_value text; v_match jsonb; v_previous_match_id text;
begin
  if p_user_id is null or p_match_id is null or length(p_match_id) not between 1 and 128
     or p_match_json is null or p_match_json->>'id' is distinct from p_match_id
     or p_idempotency_key is null or length(p_idempotency_key) not between 8 and 128 then
    raise exception 'invalid_arena_practice_match' using errcode='22023';
  end if;
  if jsonb_typeof(p_match_json->'questions') is distinct from 'array' then
    raise exception 'invalid_arena_practice_match' using errcode='22023';
  end if;
  if jsonb_array_length(p_match_json->'questions') <> 10 then
    raise exception 'invalid_arena_practice_match' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('arena:' || p_user_id::text, 0));
  delete from public.arena_practice_join_request
    where user_id=p_user_id and created_at < now() - interval '30 days';
  select match_id into v_previous_match_id from public.arena_practice_join_request
    where user_id=p_user_id and idempotency_key=p_idempotency_key;
  if found then
    return jsonb_build_object('match_id',v_previous_match_id,'reused',true);
  end if;
  select value into v_value from public.canary_user_kv
    where user_id=p_user_id and key='arena.active_match' for update;
  if found then
    begin v_match := v_value::jsonb;
    exception when others then
      raise exception 'invalid_arena_practice_state' using errcode='22023';
    end;
    if coalesce((v_match->>'finished')::boolean, false) is false then
      insert into public.arena_practice_join_request(user_id,idempotency_key,match_id)
        values (p_user_id,p_idempotency_key,v_match->>'id');
      return jsonb_build_object('match_id',v_match->>'id','match',v_match,'reused',true);
    end if;
  end if;
  insert into public.canary_user_kv(user_id,key,value)
    values (p_user_id,'arena.active_match',p_match_json::text)
    on conflict (user_id,key) do update set value=excluded.value,updated_at=now();
  insert into public.arena_practice_join_request(user_id,idempotency_key,match_id)
    values (p_user_id,p_idempotency_key,p_match_id);
  return jsonb_build_object('match_id',p_match_id,'match',p_match_json,'reused',false);
end $$;
revoke all on function public.start_arena_practice_match(uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.start_arena_practice_match(uuid,text,jsonb,text) to service_role;

create or replace function public.submit_arena_practice_answer(
  p_user_id uuid,
  p_match_id text,
  p_question_id text,
  p_answer text,
  p_idempotency_key text,
  p_request_fingerprint text
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
declare
  v_value text;
  v_match jsonb;
  v_question jsonb;
  v_old_request jsonb;
  v_submitted jsonb;
  v_answers jsonb;
  v_requests jsonb;
  v_correct boolean;
  v_finished boolean;
  v_response jsonb;
  v_rating_receipt jsonb;
begin
  if p_user_id is null or p_match_id is null or length(p_match_id) not between 1 and 128
     or p_question_id is null or length(p_question_id) not between 1 and 128
     or p_answer is null or length(p_answer) > 2000
     or p_idempotency_key is null or length(p_idempotency_key) not between 8 and 128
     or p_request_fingerprint is null or p_request_fingerprint !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_arena_practice_answer' using errcode='22023';
  end if;
  select value into v_value from public.canary_user_kv
    where user_id=p_user_id and key='arena.active_match' for update;
  if not found then raise exception 'arena_match_not_found' using errcode='P0002'; end if;
  begin v_match := v_value::jsonb;
  exception when others then
    raise exception 'invalid_arena_practice_state' using errcode='22023';
  end;
  if v_match->>'id' is distinct from p_match_id then
    raise exception 'arena_match_not_found' using errcode='P0002';
  end if;

  v_requests := coalesce(v_match->'answer_requests','{}'::jsonb);
  v_old_request := v_requests->p_idempotency_key;
  if v_old_request is not null then
    if v_old_request->>'fingerprint' is distinct from p_request_fingerprint then
      raise exception 'arena_answer_idempotency_conflict' using errcode='23505';
    end if;
    return v_old_request->'response';
  end if;
  if coalesce((v_match->>'finished')::boolean,false) then
    raise exception 'arena_match_finished' using errcode='23505';
  end if;

  select item.question into v_question
    from jsonb_array_elements(v_match->'questions') as item(question)
    where item.question->>'id'=p_question_id limit 1;
  if v_question is null then raise exception 'arena_question_not_found' using errcode='P0002'; end if;
  v_submitted := coalesce(v_match->'submitted','[]'::jsonb);
  if v_submitted ? p_question_id then
    raise exception 'arena_question_already_submitted' using errcode='23505';
  end if;
  v_correct := coalesce(v_question->>'answer','')=btrim(p_answer);
  v_submitted := v_submitted || jsonb_build_array(p_question_id);
  v_answers := coalesce(v_match->'answers','{}'::jsonb) ||
    jsonb_build_object(p_question_id,jsonb_build_object('answer',p_answer,'correct',v_correct));
  v_finished := jsonb_array_length(v_submitted)=jsonb_array_length(v_match->'questions');
  v_response := jsonb_build_object('correct',v_correct,'finished',v_finished,'question_id',p_question_id);
  v_match := jsonb_set(v_match,'{submitted}',v_submitted,true);
  v_match := jsonb_set(v_match,'{answers}',v_answers,true);
  v_match := jsonb_set(v_match,'{correct}',to_jsonb(coalesce((v_match->>'correct')::integer,0)+case when v_correct then 1 else 0 end),true);
  v_match := jsonb_set(v_match,'{finished}',to_jsonb(v_finished),true);
  if v_finished then
    v_match := jsonb_set(v_match,'{finished_at}',to_jsonb(extract(epoch from clock_timestamp())::bigint),true);
  end if;
  v_requests := v_requests || jsonb_build_object(
    p_idempotency_key,jsonb_build_object('fingerprint',p_request_fingerprint,'response',v_response)
  );
  v_match := jsonb_set(v_match,'{answer_requests}',v_requests,true);
  update public.canary_user_kv set value=v_match::text,updated_at=now()
    where user_id=p_user_id and key='arena.active_match';
  if v_finished then
    v_rating_receipt := public.complete_arena_practice_result(
      p_user_id::text,p_match_id,'duel_exam','arena-finish:' || p_match_id,
      coalesce((v_match->>'correct')::integer,0),
      coalesce((v_match->>'bot_correct')::integer,0)
    );
  end if;
  return v_response;
end $$;
revoke all on function public.submit_arena_practice_answer(uuid,text,text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.submit_arena_practice_answer(uuid,text,text,text,text,text)
  to service_role;

-- Keep result answers available briefly, then scrub the private response payload
-- even when the student closes the app before its explicit result ACK arrives.
create index if not exists canary_user_kv_arena_result_expiry_idx
  on public.canary_user_kv(updated_at)
  where key='arena.active_match';

create or replace function public.purge_expired_arena_answers()
returns bigint language plpgsql security definer
set search_path=pg_catalog,public as $$
declare
  item record;
  payload jsonb;
  changed bigint := 0;
  affected bigint;
begin
  for item in
    select user_id,value
    from public.canary_user_kv
    where key='arena.active_match'
      and updated_at <= now() - interval '5 minutes'
  loop
    begin
      payload := item.value::jsonb;
      if payload->>'finished' is distinct from 'true'
         or jsonb_typeof(payload->'answers') is distinct from 'object'
         or payload->'answers' = '{}'::jsonb
         or payload->>'answers_purged' = 'true' then
        continue;
      end if;

      update public.canary_user_kv
      set value=jsonb_set(
            jsonb_set(payload,'{answers}','{}'::jsonb,true),
            '{answers_purged}','true'::jsonb,true
          )::text,
          updated_at=now()
      where user_id=item.user_id
        and key='arena.active_match'
        and value=item.value;
      get diagnostics affected = row_count;
      changed := changed + affected;
    exception when invalid_text_representation then
      -- A malformed legacy KV row must not stop cleanup for other students.
      continue;
    end;
  end loop;
  return changed;
end $$;

revoke all on function public.purge_expired_arena_answers()
  from public,anon,authenticated;
grant execute on function public.purge_expired_arena_answers()
  to service_role;

commit;
