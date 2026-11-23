-- BrainWake database, part 16: one row per phone.
--
-- Until now each INSTALL of the app made up a random number for itself, so
-- a phone whose app was uninstalled and installed again was counted twice.
-- The app now works its number out from Android's own identifier for the
-- app on that phone, which stays the same across reinstalls. A phone that
-- was already counted under a random number says so once ("replaces"), and
-- its old row is folded into the new one.

drop function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer, text);
create function public.app_ping(
  install uuid, level text default 'guest', version text default '', platform text default '',
  answered integer default null, correct integer default null,
  alarms_ok integer default null, alarms_missed integer default null, alarms integer default null,
  device text default '', replaces uuid default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  real_level text := 'guest';
  cap constant integer := 10000000;
  old_first timestamptz;
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
  -- A phone that was counted under another number before (see the top of
  -- this file): its old row goes, and the new one keeps its first day.
  if replaces is not null and replaces <> install then
    delete from app_installs o where o.install = app_ping.replaces returning o.first_seen into old_first;
  end if;
  insert into app_installs as i
    (install, user_id, level, version, platform, answered, correct, alarms_ok, alarms_missed, alarms, device, first_seen)
  values (app_ping.install, me, real_level, left(coalesce(app_ping.version, ''), 30),
          left(coalesce(app_ping.platform, ''), 20),
          case when app_ping.answered is not null then least(greatest(app_ping.answered, 0), cap) end,
          case when app_ping.correct is not null then least(greatest(app_ping.correct, 0), cap) end,
          case when app_ping.alarms_ok is not null then least(greatest(app_ping.alarms_ok, 0), cap) end,
          case when app_ping.alarms_missed is not null then least(greatest(app_ping.alarms_missed, 0), cap) end,
          case when app_ping.alarms is not null then least(greatest(app_ping.alarms, 0), 1000) end,
          left(coalesce(app_ping.device, ''), 80), coalesce(old_first, now()))
  on conflict on constraint app_installs_pkey do update set
    user_id = excluded.user_id, level = excluded.level, version = excluded.version,
    platform = excluded.platform, last_seen = now(), pings = i.pings + 1,
    answered = excluded.answered, correct = excluded.correct, alarms_ok = excluded.alarms_ok,
    alarms_missed = excluded.alarms_missed, alarms = excluded.alarms,
    first_seen = least(i.first_seen, excluded.first_seen),
    -- An older app version on the same phone sends none: keep what is known.
    device = case when excluded.device <> '' then excluded.device else i.device end;
end $$;
revoke execute on function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer, text, uuid) from public;
grant execute on function public.app_ping(uuid, text, text, text, integer, integer, integer, integer, integer, text, uuid) to anon, authenticated;

