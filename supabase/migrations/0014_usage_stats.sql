-- BrainWake database, part 14: how the app is being used.
--
-- 1. An alarm that rang unanswered until the app stopped it is a new way
--    for an alarm session to end ("timed_out").
-- 2. app_installs: one row per phone that has the app, with or without an
--    account. The app sends a "ping" about once a day with a random id it
--    made up for itself, its plan level, its version and (only if the
--    person shares diagnostics) a few running totals. No name, no email,
--    nothing about what was answered.
-- 3. admin_usage_stats(): the figures for the admin site's Statistics page.

alter table public.user_sessions drop constraint user_sessions_outcome_check;
alter table public.user_sessions add constraint user_sessions_outcome_check
  check (outcome in ('dismissed', 'snoozed', 'finished', 'timed_out'));

create table public.app_installs (
  install       uuid primary key,
  -- Set while someone is signed in on that phone.
  user_id       uuid references auth.users (id) on delete set null,
  level         text not null default 'guest' check (level in ('guest', 'free', 'pro', 'ultra')),
  version       text not null default '',
  platform      text not null default '',
  first_seen    timestamptz not null default now(),
  last_seen     timestamptz not null default now(),
  pings         integer not null default 1,
  -- Running totals on that phone (null: the person does not share them).
  answered      integer,
  correct       integer,
  alarms_ok     integer,
  alarms_missed integer,
  alarms        integer
);
create index app_installs_seen_idx on public.app_installs (last_seen desc);

-- Nobody reads or writes the table directly; the two functions below do.
alter table public.app_installs enable row level security;

-- THE APP. Says "this phone has the app". The plan level of a signed-in
-- phone is worked out here, not taken from the phone.
create function public.app_ping(
  install uuid, level text default 'guest', version text default '', platform text default '',
  answered integer default null, correct integer default null,
  alarms_ok integer default null, alarms_missed integer default null, alarms integer default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  real_level text := 'guest';
  cap constant integer := 10000000;
begin
  if install is null then return; end if;
  if me is not null then
    select case
        when p.plan = 'premium' and (p.plan_expires_at is null or p.plan_expires_at > now())
          then case when p.tier = 'ultra' then 'ultra' else 'pro' end
        else 'free' end
      into real_level from profiles p where p.id = me;
    real_level := coalesce(real_level, 'free');
  end if;
  insert into app_installs as i
    (install, user_id, level, version, platform, answered, correct, alarms_ok, alarms_missed, alarms)
  values (app_ping.install, me, real_level, left(coalesce(app_ping.version, ''), 30),
          left(coalesce(app_ping.platform, ''), 20),
          case when app_ping.answered is not null then least(greatest(app_ping.answered, 0), cap) end, case when app_ping.correct is not null then least(greatest(app_ping.correct, 0), cap) end,
          case when app_ping.alarms_ok is not null then least(greatest(app_ping.alarms_ok, 0), cap) end, case when app_ping.alarms_missed is not null then least(greatest(app_ping.alarms_missed, 0), cap) end,
          case when app_ping.alarms is not null then least(greatest(app_ping.alarms, 0), 1000) end)
  on conflict on constraint app_installs_pkey do update set
    user_id = excluded.user_id, level = excluded.level, version = excluded.version,
    platform = excluded.platform, last_seen = now(), pings = i.pings + 1,
    answered = excluded.answered, correct = excluded.correct, alarms_ok = excluded.alarms_ok,
    alarms_missed = excluded.alarms_missed, alarms = excluded.alarms;
end $$;
revoke execute on function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer) from public;
grant execute on function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer) to anon, authenticated;

-- ADMINS. Everything the Statistics page shows, for the last N days.
create function public.admin_usage_stats(days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  n integer := least(greatest(coalesce(days, 30), 1), 365);
  since timestamptz := now() - make_interval(days => n);
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = 'insufficient_privilege';
  end if;
  with
  paid as (
    select p.id, case when p.tier = 'ultra' then 'ultra' when p.tier is null then 'by_hand' else 'pro' end as kind
    from profiles p
    where p.plan = 'premium' and (p.plan_expires_at is null or p.plan_expires_at > now())
  ),
  day_list as (
    select generate_series(date_trunc('day', since), date_trunc('day', now()), interval '1 day')::date as day
  ),
  att as (select * from user_attempts a where a.answered_at >= since),
  ev as (select * from alarm_events e where e.at >= since)
  select jsonb_build_object(
    'days', n,
    'phones', jsonb_build_object(
      'total', (select count(*) from app_installs),
      'active', (select count(*) from app_installs where last_seen >= since),
      'active_7d', (select count(*) from app_installs where last_seen >= now() - interval '7 days'),
      'new', (select count(*) from app_installs where first_seen >= since),
      'by_level', (select coalesce(jsonb_object_agg(level, c), '{}'::jsonb) from
                    (select level, count(*) c from app_installs where last_seen >= since group by level) x),
      'by_version', (select coalesce(jsonb_agg(jsonb_build_object('version', version, 'phones', c) order by c desc), '[]'::jsonb) from
                    (select version, count(*) c from app_installs where last_seen >= since group by version order by c desc limit 8) x),
      'sharing', (select count(*) from app_installs where last_seen >= since and answered is not null),
      'answered', (select coalesce(sum(answered), 0) from app_installs),
      'correct', (select coalesce(sum(correct), 0) from app_installs),
      'alarms_ok', (select coalesce(sum(alarms_ok), 0) from app_installs),
      'alarms_missed', (select coalesce(sum(alarms_missed), 0) from app_installs),
      'alarms_set', (select coalesce(sum(alarms), 0) from app_installs where last_seen >= since)
    ),
    'accounts', jsonb_build_object(
      'total', (select count(*) from profiles),
      'new', (select count(*) from auth.users u where u.created_at >= since),
      'free', (select count(*) from profiles p where not exists (select 1 from paid where paid.id = p.id)),
      'pro', (select count(*) from paid where kind = 'pro'),
      'ultra', (select count(*) from paid where kind = 'ultra'),
      'by_hand', (select count(*) from paid where kind = 'by_hand')
    ),
    'questions', jsonb_build_object(
      'in_bank', (select count(*) from questions where deleted_at is null and status = 'published'),
      'answered_all_time', (select count(*) from user_attempts),
      'answered', (select count(*) from att),
      'correct', (select count(*) from att where correct),
      'learners', (select count(distinct user_id) from att),
      'in_alarms', (select count(*) from att where mode = 'alarm'),
      'by_topic', (select coalesce(jsonb_agg(to_jsonb(x) order by x.answered desc), '[]'::jsonb) from (
          select coalesce(u.name || ' / ' || t.name, 'People''s own questions') as topic,
                 count(*) as answered, count(*) filter (where a.correct) as correct,
                 count(distinct a.user_id) as learners
          from att a
          left join questions q on q.id = a.question_id
          left join topics t on t.id = q.topic_id
          left join units u on u.id = t.unit_id
          group by 1 order by count(*) desc limit 15) x),
      'hardest', (select coalesce(jsonb_agg(to_jsonb(x) order by x.rate, x.answered desc), '[]'::jsonb) from (
          select q.id, left(q.text, 160) as text, t.name as topic, t.id as topic_id, t.unit_id,
                 count(*) as answered, count(*) filter (where a.correct) as correct,
                 round(100.0 * count(*) filter (where a.correct) / count(*))::integer as rate
          from att a join questions q on q.id = a.question_id join topics t on t.id = q.topic_id
          where q.deleted_at is null
          group by q.id, q.text, t.name, t.id, t.unit_id
          having count(*) >= 5
          order by 8, count(*) desc limit 10) x)
    ),
    'alarms', jsonb_build_object(
      'rang', (select count(*) from ev where type = 'rang'),
      'answered', (select count(*) from ev where type = 'dismissed'),
      'snoozed', (select count(*) from ev where type = 'snoozed'),
      'never_rang', (select count(*) from ev where type = 'missed'),
      'timed_out', (select count(*) from ev where type = 'timed_out'),
      'people', (select count(distinct user_id) from ev where type = 'rang')
    ),
    'by_day', (select coalesce(jsonb_agg(jsonb_build_object(
        'day', d.day,
        'answers', (select count(*) from att a where a.answered_at::date = d.day),
        'alarms_answered', (select count(*) from ev e where e.type = 'dismissed' and e.at::date = d.day),
        'alarms_missed', (select count(*) from ev e where e.type in ('missed', 'timed_out') and e.at::date = d.day),
        'new_accounts', (select count(*) from auth.users u where u.created_at::date = d.day),
        'new_phones', (select count(*) from app_installs i where i.first_seen::date = d.day)
      ) order by d.day), '[]'::jsonb) from day_list d)
  ) into result;
  return result;
end $$;
revoke execute on function public.admin_usage_stats(integer) from public, anon;
grant execute on function public.admin_usage_stats(integer) to authenticated;
