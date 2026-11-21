-- Checks the alarm diary and problem reports. Runs after the owner tests:
-- ...00a is the owner, ...00c is a user; any other user is made here.
\set ON_ERROR_STOP on

create function pg_temp.act_as(who uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(who::text, ''), false);
  execute format('set role %I', case when who is null then 'anon' else 'authenticated' end);
end $$;
create function pg_temp.expect(ok boolean, what text) returns void
language plpgsql as $$
begin
  if ok is not true then raise exception 'FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;
create function pg_temp.refused(statement text, what text) returns void
language plpgsql as $$
begin
  begin
    execute statement;
  exception when others then
    raise notice 'ok: %', what;
    return;
  end;
  raise exception 'FAILED: %', what;
end $$;
grant execute on all functions in schema pg_temp to anon, authenticated, service_role;

-- A user uploads their diary.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into public.alarm_events (user_id, client_id, at, alarm_id, type, detail, device, app_version, resolved) values
  ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000001', now() - interval '3 hours', 5, 'scheduled', '{}', 'Acme One (Android 16)', '1.0.0+1', false),
  ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000002', now() - interval '2 hours', 5, 'rang', '{"late_seconds": 95}', 'Acme One (Android 16)', '1.0.0+1', false),
  ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000003', now() - interval '1 hour', 5, 'missed', '{}', 'Acme One (Android 16)', '1.0.0+1', false),
  ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000004', now(), 5, 'report',
   '{"rang": false, "problem": "never_rang", "note": "slept through"}', 'Acme One (Android 16)', '1.0.0+1', true);

select pg_temp.expect((select count(*) = 4 from public.alarm_events), 'a user reads their own diary');
select pg_temp.expect((select not resolved from public.alarm_events where type = 'report'),
  'a user cannot mark their own report as dealt with');
select pg_temp.refused($$insert into public.alarm_events (user_id, client_id, at, type)
  values ('00000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000009', now(), 'rang')$$,
  'a user cannot write into someone else''s diary');
select pg_temp.refused($$insert into public.alarm_events (user_id, client_id, at, type)
  values ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000001', now(), 'rang')$$,
  'the same entry cannot be stored twice');
select pg_temp.refused($$update public.alarm_events set type = 'rang'$$, 'a diary entry cannot be edited');
select pg_temp.refused($$delete from public.alarm_events$$, 'a diary entry cannot be deleted');
select pg_temp.refused('select * from public.admin_alarm_reports()', 'a user cannot list reports');
select pg_temp.refused('select public.admin_alarm_health()', 'a user cannot read alarm health');
select pg_temp.refused('select public.admin_resolve_alarm_report(1)', 'a user cannot resolve a report');

-- Nobody signed in sees nothing.
select pg_temp.act_as(null);
select pg_temp.refused('select * from public.alarm_events', 'a visitor cannot read the diary');

-- The owner reviews.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect((select count(*) = 1 and bool_and(email is not null and detail ->> 'problem' = 'never_rang')
  from public.admin_alarm_reports()), 'the owner sees the report with who sent it');
select pg_temp.expect((select count(*) = 4 from public.admin_alarm_events('00000000-0000-0000-0000-00000000000c')),
  'the owner sees what led up to it');
select pg_temp.expect((select h ->> 'rang' = '1' and h ->> 'missed' = '1' and h ->> 'reports' = '1'
    and h ->> 'open_reports' = '1' and h ->> 'late_over_a_minute' = '1'
    and h -> 'missed_by_device' -> 0 ->> 'device' = 'Acme One (Android 16)'
    and h -> 'problems' -> 0 ->> 'problem' = 'never_rang'
  from public.admin_alarm_health() h), 'alarm health adds things up');
select public.admin_resolve_alarm_report((select id from public.admin_alarm_reports()));
select pg_temp.expect((select count(*) = 0 from public.admin_alarm_reports(true)), 'a resolved report leaves the open list');
select pg_temp.expect((select count(*) = 1 from public.admin_alarm_reports(false)), 'and stays in the full list');

-- A user deletes their own account; everything of theirs goes with it.
select pg_temp.act_as(null);
select pg_temp.refused('select public.delete_my_account()', 'a visitor has no account to delete');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.refused('select public.delete_my_account()', 'the only owner cannot delete themselves');
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select public.delete_my_account();
reset role;
select pg_temp.expect(
  (select count(*) = 0 from auth.users where id = '00000000-0000-0000-0000-00000000000c')
  and (select count(*) = 0 from public.profiles where id = '00000000-0000-0000-0000-00000000000c')
  and (select count(*) = 0 from public.alarm_events where user_id = '00000000-0000-0000-0000-00000000000c'),
  'deleting your own account removes it and what was stored for it');
select pg_temp.expect((select count(*) = 1 from auth.users where id = '00000000-0000-0000-0000-00000000000a'),
  'and nobody else');

reset role;
select 'ALARM EVENT TESTS PASSED';
