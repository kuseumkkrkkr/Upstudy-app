-- Vercel-owned rating ledger. Apply only after preserving/exporting the current
-- PostgreSQL rating tables; this migration creates the compatible destination.
create table if not exists public.user_rating (
  user_id text primary key,
  rating double precision not null default 1200,
  ovr double precision not null default 1200,
  ovr_prev double precision not null default 1200,
  lose_streak integer not null default 0 check (lose_streak >= 0),
  last_attempt_at timestamptz,
  recent_results jsonb not null default '[]'::jsonb,
  recent_index smallint not null default 0 check (recent_index between 0 and 49),
  recent_count smallint not null default 0 check (recent_count between 0 and 50),
  recent_sum smallint not null default 0 check (recent_sum between 0 and 50),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.user_tag_rating (
  user_id text not null references public.user_rating(user_id) on delete cascade,
  tag text not null,
  attempts integer not null default 0 check (attempts >= 0),
  rating double precision not null default 1200,
  rating_prev double precision not null default 1200,
  updated_at timestamptz not null default now(),
  primary key (user_id, tag)
);
create index if not exists user_tag_rating_rank_idx
  on public.user_tag_rating(user_id, rating desc, tag asc);
create table if not exists public.rating_submission (
  user_id text not null,
  submission_id text not null,
  quest_id text not null,
  request_fingerprint text check (request_fingerprint is null or request_fingerprint ~ '^[0-9a-f]{64}$'),
  response jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, submission_id)
);
alter table public.rating_submission
  add column if not exists request_fingerprint text
  check (request_fingerprint is null or request_fingerprint ~ '^[0-9a-f]{64}$');
create index if not exists rating_submission_created_idx on public.rating_submission(created_at);

alter table public.user_rating enable row level security;
alter table public.user_tag_rating enable row level security;
alter table public.rating_submission enable row level security;
revoke all on public.user_rating, public.user_tag_rating, public.rating_submission from anon, authenticated;
grant select, insert, update on public.user_rating, public.user_tag_rating, public.rating_submission to service_role;

create or replace function public.get_rating_user_snapshot(p_user_id text)
returns jsonb language sql stable security definer set search_path=pg_catalog as $$
with mine as (
  select * from public.user_rating where user_id=p_user_id
), cohort as (
  select count(*) filter (where r.ovr < m.ovr) as lower_count,
         count(*) filter (where r.ovr = m.ovr) as tie_count,
         count(*) as cohort_size
  from public.user_rating r
  join mine m on m.last_attempt_at is not null
  where r.last_attempt_at is not null
)
select jsonb_build_object(
  'rating', coalesce(m.rating,1200), 'ovr', coalesce(m.ovr,1200),
  'ovr_delta', coalesce(m.ovr,1200)-coalesce(m.ovr_prev,1200),
  'recent_accuracy', case when coalesce(m.recent_count,0)>0
    then m.recent_sum::double precision/m.recent_count else 0 end,
  'lose_streak', coalesce(m.lose_streak,0),
  'levelity_percentile', case when c.cohort_size>0
    then (c.lower_count+c.tie_count::double precision/2)/c.cohort_size*100 else null end,
  'levelity_cohort_size', coalesce(c.cohort_size,0)
)
from (select 1) seed left join mine m on true cross join cohort c;
$$;

create or replace function public.apply_rating_submission_v2(
  p_user_id text, p_submission_id text, p_quest_id text, p_is_correct boolean,
  p_answer_time double precision, p_difficulty double precision,
  p_main_huddle double precision, p_flow_rate double precision, p_tag_flows jsonb,
  p_request_fingerprint text
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare
  u public.user_rating%rowtype;
  previous public.rating_submission%rowtype;
  inserted_id text;
  entry jsonb;
  raw_enter jsonb;
  tag_name text;
  enter_values double precision[];
  enter_count integer;
  avg_enter double precision;
  p80_enter double precision;
  barrier double precision;
  difficulty_signal double precision;
  problem_weight double precision;
  problem_rating double precision;
  time_signal double precision;
  recent_signal double precision;
  recency_signal double precision;
  confidence_weight double precision;
  attempts_now integer;
  tag_current double precision;
  tag_previous double precision;
  tag_expected double precision;
  global_expected double precision;
  tag_outcome boolean;
  tag_delta double precision;
  global_delta double precision;
  total_flows integer := 0;
  rating_delta_total double precision := 0;
  new_rating double precision;
  new_ovr double precision;
  old_recent smallint;
  updated_recent jsonb;
  updated_index smallint;
  updated_count smallint;
  updated_sum smallint;
  output jsonb;
begin
  if p_user_id is null or p_user_id='' or p_submission_id is null or p_submission_id=''
     or p_quest_id is null or p_quest_id='' or jsonb_typeof(p_tag_flows)<>'array'
     or p_request_fingerprint is null or p_request_fingerprint !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_rating_submission' using errcode='22023';
  end if;
  insert into public.user_rating(user_id) values(p_user_id) on conflict(user_id) do nothing;
  select * into u from public.user_rating where user_id=p_user_id for update;
  insert into public.rating_submission(user_id,submission_id,quest_id,request_fingerprint)
    values(p_user_id,p_submission_id,p_quest_id,p_request_fingerprint)
    on conflict(user_id,submission_id) do nothing returning submission_id into inserted_id;
  if inserted_id is null then
    select * into previous from public.rating_submission
      where user_id=p_user_id and submission_id=p_submission_id;
    if previous.quest_id<>p_quest_id
       or (previous.request_fingerprint is not null
           and previous.request_fingerprint is distinct from p_request_fingerprint) then
      return jsonb_build_object('status','conflict');
    end if;
    if previous.response is null then
      return jsonb_build_object('status','pending');
    end if;
    return previous.response;
  end if;

  select coalesce(sum(jsonb_array_length(coalesce(item->'enter_huddles','[]'::jsonb))),0)
    into total_flows from jsonb_array_elements(p_tag_flows) as tags(item);
  recent_signal := case when u.recent_count>0 then u.recent_sum::double precision/u.recent_count else 0.5 end;
  recency_signal := case when u.last_attempt_at is null then 1.0 else
    exp(-greatest(0,extract(epoch from (now()-u.last_attempt_at))/86400.0)/21.0) end;
  if p_answer_time is null or p_answer_time<=0 then
    time_signal := 1.0;
  else
    time_signal := 30.0+20.0*coalesce(p_flow_rate,0)+30.0*coalesce(p_main_huddle,0);
    time_signal := 0.9+0.1*greatest(0.4,least(1.0,
      exp(-greatest(0,p_answer_time-time_signal)/greatest(1.0,time_signal))));
  end if;
  difficulty_signal := (ln(1.0+greatest(0,coalesce(p_difficulty,0)))-3.70)/1.20;
  problem_weight := greatest(0.75,least(1.25,0.82+0.12*difficulty_signal));

  for entry in select value from jsonb_array_elements(p_tag_flows) loop
    tag_name := lower(trim(leading '#' from btrim(coalesce(entry->>'tag',''))));
    if tag_name='' or tag_name='사칙연산' then continue; end if;
    enter_values := array[]::double precision[];
    for raw_enter in select value from jsonb_array_elements(coalesce(entry->'enter_huddles','[]'::jsonb)) as enters(value) loop
      begin enter_values := array_append(enter_values,(raw_enter #>> '{}')::double precision);
      exception when others then enter_values := array_append(enter_values,0); end;
    end loop;
    enter_count := coalesce(array_length(enter_values,1),0);
    select attempts,rating into attempts_now,tag_current from public.user_tag_rating
      where user_id=p_user_id and tag=tag_name for update;
    if not found then attempts_now:=0; tag_current:=u.rating; end if;
    attempts_now := attempts_now+1;
    tag_previous := tag_current;
    tag_outcome := coalesce((entry->>'correct')::boolean,p_is_correct);
    if enter_count>0 then
      -- Match Python's sorted round((n-1)*0.8) percentile index.
      select avg(value), max(value) filter (
        where ordinal = floor((sample_count-1)*0.8+0.5)::integer+1
      ) into avg_enter,p80_enter
      from (
        select value, row_number() over(order by value) as ordinal,
               count(*) over() as sample_count
        from unnest(enter_values) as valueset(value)
      ) ranked_values;
      barrier := greatest(0.0,least(10.0,0.6*avg_enter+0.2*p80_enter+0.2*coalesce(p_main_huddle,0)*3.3));
      problem_weight := greatest(0.75,least(1.25,0.82+0.12*difficulty_signal+0.03*barrier));
      problem_rating := greatest(900.0,least(1700.0,1080.0+180.0*difficulty_signal+24.0*barrier));
      confidence_weight := (0.45+0.30*greatest(0.0,least(1.0,attempts_now/24.0))
        +0.15*recent_signal+0.10*recency_signal)*time_signal;
      tag_expected := 1.0/(1.0+power(10.0,(problem_rating-tag_current)/400.0));
      global_expected := 1.0/(1.0+power(10.0,(problem_rating-u.rating)/400.0));
      tag_delta := greatest(-36.0,least(36.0,24.0*(tag_outcome::integer-tag_expected)*confidence_weight*problem_weight));
      global_delta := greatest(-36.0,least(36.0,24.0*(tag_outcome::integer-global_expected)*confidence_weight*problem_weight));
      tag_current := tag_current+tag_delta;
      rating_delta_total := rating_delta_total+global_delta*enter_count/greatest(1,total_flows);
    end if;
    insert into public.user_tag_rating(user_id,tag,attempts,rating,rating_prev,updated_at)
      values(p_user_id,tag_name,attempts_now,tag_current,tag_previous,now())
    on conflict(user_id,tag) do update set attempts=excluded.attempts,
      rating=excluded.rating,rating_prev=excluded.rating_prev,updated_at=excluded.updated_at;
  end loop;

  new_rating := u.rating+rating_delta_total;
  updated_recent := u.recent_results;
  updated_index := u.recent_index;
  updated_count := u.recent_count;
  updated_sum := u.recent_sum;
  if updated_count<50 then
    updated_recent := updated_recent || jsonb_build_array(p_is_correct::integer);
    updated_count := updated_count+1;
    updated_sum := updated_sum+p_is_correct::integer;
    updated_index := updated_count%50;
  else
    old_recent := coalesce((updated_recent->>updated_index)::smallint,0);
    updated_recent := jsonb_set(updated_recent,array[updated_index::text],to_jsonb(p_is_correct::integer),true);
    updated_sum := updated_sum+p_is_correct::integer-old_recent;
    updated_index := (updated_index+1)%50;
  end if;
  select coalesce(sum(rating*least(attempts,24))/nullif(sum(least(attempts,24)),0),new_rating)
    into new_ovr from public.user_tag_rating where user_id=p_user_id;
  update public.user_rating set rating=new_rating,ovr=new_ovr,ovr_prev=u.ovr,
    lose_streak=case when p_is_correct then 0 else u.lose_streak+1 end,
    last_attempt_at=now(),recent_results=updated_recent,recent_index=updated_index,
    recent_count=updated_count,recent_sum=updated_sum,updated_at=now()
    where user_id=p_user_id;
  output := jsonb_build_object('rating',new_rating,'ovr',new_ovr,'ovr_delta',new_ovr-u.ovr,
    'recent_accuracy',updated_sum::double precision/greatest(1,updated_count),
    'lose_streak',case when p_is_correct then 0 else u.lose_streak+1 end);
  update public.rating_submission set response=output
    where user_id=p_user_id and submission_id=p_submission_id;
  return output;
end $$;

revoke all on function public.get_rating_user_snapshot(text) from public,anon,authenticated;
-- Retire the pre-fingerprint signature so stale callers cannot bypass replay-body checks.
do $$ begin
  if to_regprocedure('public.apply_rating_submission(text,text,text,boolean,double precision,double precision,double precision,double precision,jsonb)') is not null then
    execute 'revoke all on function public.apply_rating_submission(text,text,text,boolean,double precision,double precision,double precision,double precision,jsonb) from public,anon,authenticated,service_role';
  end if;
end $$;
revoke all on function public.apply_rating_submission_v2(text,text,text,boolean,double precision,double precision,double precision,double precision,jsonb,text) from public,anon,authenticated;
grant execute on function public.get_rating_user_snapshot(text) to service_role;
grant execute on function public.apply_rating_submission_v2(text,text,text,boolean,double precision,double precision,double precision,double precision,jsonb,text) to service_role;
