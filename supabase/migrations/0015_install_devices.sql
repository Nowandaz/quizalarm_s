-- BrainWake database, part 15: which phone the app is on.
--
-- The daily "I am here" message now also says the phone's make and model
-- ("Tecno Camon 30 (Android 14)"). Admins see it per account on the
-- Accounts page, and as a list of phone models on the Statistics page.

alter table public.app_installs add column device text not null default '';

-- The same function with one more field. Older app versions that do not
-- send it keep working (it defaults to empty).
drop function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer);
create function public.app_ping(
  install uuid, level text default 'guest', version text default '', platform text default '',
  answered integer default null, correct integer default null,
  alarms_ok integer default null, alarms_missed integer default null, alarms integer default null,
  device text default ''
) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  real_level text := 'guest';
  cap constant integer := 10000000;
  cut integer;
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
    (install, user_id, level, version, platform, answered, correct, alarms_ok, alarms_missed, alarms, device)
  values (app_ping.install, me, real_level, left(coalesce(app_ping.version, ''), 30),
          left(coalesce(app_ping.platform, ''), 20),
          case when app_ping.answered is not null then least(greatest(app_ping.answered, 0), cap) end,
          case when app_ping.correct is not null then least(greatest(app_ping.correct, 0), cap) end,
          case when app_ping.alarms_ok is not null then least(greatest(app_ping.alarms_ok, 0), cap) end,
          case when app_ping.alarms_missed is not null then least(greatest(app_ping.alarms_missed, 0), cap) end,
          case when app_ping.alarms is not null then least(greatest(app_ping.alarms, 0), 1000) end,
          left(coalesce(app_ping.device, ''), 80))
  on conflict on constraint app_installs_pkey do update set
    user_id = excluded.user_id, level = excluded.level, version = excluded.version,
    platform = excluded.platform, last_seen = now(), pings = i.pings + 1,
    answered = excluded.answered, correct = excluded.correct, alarms_ok = excluded.alarms_ok,
    alarms_missed = excluded.alarms_missed, alarms = excluded.alarms,
    -- An older app version on the same phone sends none: keep what is known.
    device = case when excluded.device <> '' then excluded.device else i.device end;
end $$;
revoke execute on function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer, text) from public;
grant execute on function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer, text) to anon, authenticated;

-- ADMINS. The phones the app is on: the ones signed in to an account
-- (to show beside the account), and a count per phone model for all.
create function public.admin_devices(days integer default 90) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(days, 90), 1), 365));
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object(
    'by_account', (select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', i.user_id, 'device', i.device, 'version', i.version, 'platform', i.platform,
        'level', i.level, 'first_seen', i.first_seen, 'last_seen', i.last_seen) order by i.last_seen desc), '[]'::jsonb)
      from app_installs i where i.user_id is not null),
    'models', (select coalesce(jsonb_agg(to_jsonb(x) order by x.phones desc, x.device), '[]'::jsonb) from (
        select case when i.device = '' then 'Not reported (older app version)' else i.device end as device,
               count(*) as phones,
               count(*) filter (where i.user_id is null) as without_account,
               coalesce(sum(i.alarms_missed), 0) as alarms_missed,
               max(i.last_seen) as last_seen
        from app_installs i where i.last_seen >= since
        group by 1 order by count(*) desc limit 40) x)
  );
end $$;
revoke execute on function public.admin_devices(integer) from public, anon;
grant execute on function public.admin_devices(integer) to authenticated;
