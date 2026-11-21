-- BrainWake database, part 6: the alarm diary and problem reports.
--
-- Each phone keeps a diary of what happened to its alarms (scheduled,
-- rang, snoozed, dismissed, edited, missed...) and uploads it here. A
-- "report" entry is a user telling us an alarm misbehaved; its detail
-- holds what they chose plus diagnostics collected automatically (phone
-- model, Android version, permissions, what was registered, why the app
-- last stopped). "missed" entries are rings the app itself noticed never
-- happened, so recurring failures show up without anyone complaining.

create table public.alarm_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- Made on the phone, so uploading the same entry twice changes nothing.
  client_id   uuid not null,
  at          timestamptz not null,
  alarm_id    bigint,
  type        text not null check (length(type) between 1 and 40),
  detail      jsonb not null default '{}'::jsonb
              check (pg_column_size(detail) < 20000),
  device      text not null default '' check (length(device) <= 200),
  app_version text not null default '' check (length(app_version) <= 40),
  -- For reports: an admin has dealt with it.
  resolved    boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (user_id, client_id)
);
create index alarm_events_type_idx on public.alarm_events (type, at desc);
create index alarm_events_user_idx on public.alarm_events (user_id, at desc);

alter table public.alarm_events enable row level security;

-- A phone adds its own entries and may read them back; nobody edits them.
create policy "add own alarm events" on public.alarm_events
  for insert to authenticated with check (user_id = auth.uid());
create policy "read own alarm events, admins read all" on public.alarm_events
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

revoke all on public.alarm_events from anon, authenticated;
grant select, insert on public.alarm_events to authenticated;

-- A phone cannot mark its own report as dealt with.
create function public.alarm_events_guard() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.resolved := false;
  end if;
  return new;
end;
$$;
create trigger alarm_events_guard before insert on public.alarm_events
  for each row execute function public.alarm_events_guard();

-- ADMIN. Problem reports, newest first, with who sent them.
create function public.admin_alarm_reports(only_open boolean default false, max_rows integer default 100)
returns table (
  id bigint, at timestamptz, user_id uuid, email text, alarm_id bigint,
  detail jsonb, device text, app_version text, resolved boolean
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return query
    select e.id, e.at, e.user_id, u.email::text, e.alarm_id,
           e.detail, e.device, e.app_version, e.resolved
    from public.alarm_events e
    join auth.users u on u.id = e.user_id
    where e.type = 'report' and (not only_open or not e.resolved)
    order by e.at desc
    limit least(greatest(max_rows, 1), 500);
end;
$$;

-- ADMIN. One user's diary around a moment (to see what led up to a report).
create function public.admin_alarm_events(target uuid, around timestamptz default now(), hours integer default 24)
returns table (id bigint, at timestamptz, alarm_id bigint, type text, detail jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return query
    select e.id, e.at, e.alarm_id, e.type, e.detail
    from public.alarm_events e
    where e.user_id = target
      and e.at between around - make_interval(hours => least(greatest(hours, 1), 168))
                   and around + make_interval(hours => 1)
    order by e.at desc
    limit 300;
end;
$$;

create function public.admin_resolve_alarm_report(report_id bigint, is_resolved boolean default true)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  update public.alarm_events set resolved = is_resolved
    where id = report_id and type = 'report';
end;
$$;

-- ADMIN. How alarms are doing over the last [days] days: totals, how late
-- rings are, and which phones miss alarms most.
create function public.admin_alarm_health(days integer default 7)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(days, 1), 90));
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return jsonb_build_object(
    'rang',      (select count(*) from public.alarm_events where type = 'rang' and at >= since),
    'missed',    (select count(*) from public.alarm_events where type = 'missed' and at >= since),
    'reports',   (select count(*) from public.alarm_events
                  where type = 'report' and at >= since and detail ->> 'rang' = 'false'),
    'open_reports', (select count(*) from public.alarm_events
                  where type = 'report' and not resolved and detail ->> 'rang' = 'false'),
    'false_alarms', (select count(*) from public.alarm_events
                  where type = 'report' and at >= since and detail ->> 'rang' = 'true'),
    'late_over_a_minute', (select count(*) from public.alarm_events
                  where type = 'rang' and at >= since
                    and (detail ->> 'late_seconds') ~ '^-?[0-9]+$'
                    and (detail ->> 'late_seconds')::bigint > 60),
    'phones_reporting', (select count(distinct user_id) from public.alarm_events where at >= since),
    'missed_by_device', coalesce((
      select jsonb_agg(row_to_json(d)) from (
        select device, count(*) as missed, count(distinct user_id) as users
        from public.alarm_events
        where type = 'missed' and at >= since
        group by device order by count(*) desc limit 8
      ) d), '[]'::jsonb),
    'problems', coalesce((
      select jsonb_agg(row_to_json(p)) from (
        select detail ->> 'problem' as problem, count(*) as reports
        from public.alarm_events
        where type = 'report' and at >= since and detail ->> 'rang' = 'false'
        group by 1 order by count(*) desc
      ) p), '[]'::jsonb)
  );
end;
$$;

revoke execute on function
  public.admin_alarm_reports(boolean, integer),
  public.admin_alarm_events(uuid, timestamptz, integer),
  public.admin_resolve_alarm_report(bigint, boolean),
  public.admin_alarm_health(integer)
  from public, anon;
grant execute on function
  public.admin_alarm_reports(boolean, integer),
  public.admin_alarm_events(uuid, timestamptz, integer),
  public.admin_resolve_alarm_report(bigint, boolean),
  public.admin_alarm_health(integer)
  to authenticated;
