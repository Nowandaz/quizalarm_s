-- Checks the usage ping and the statistics.
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
grant execute on all functions in schema pg_temp to anon, authenticated;

reset role;
-- (accounts e1 free, e2 pro, e3 lapsed, e4 admin come from the access test)
update public.profiles set tier = 'ultra' where id = '00000000-0000-0000-0000-0000000000e2';
-- Supabase lets every role touch new tables and relies on row security; do the same here.
grant select, insert, update, delete on public.app_installs to anon, authenticated;

select pg_temp.act_as(null);
select public.app_ping('00000000-0000-0000-0000-00000000aa01', 'ultra', '1.0.0+1', 'android', 12, 9, 3, 1, 2);
select public.app_ping('00000000-0000-0000-0000-00000000aa01', 'guest', '1.0.0+1', 'android', 14, 10, 4, 1, 2);
select pg_temp.expect((select count(*) from public.app_installs) = 0, 'a visitor cannot read the list of phones');
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
select public.app_ping('00000000-0000-0000-0000-00000000aa02', 'ultra', '1.0.0+1', 'android');
select pg_temp.expect((select count(*) from public.app_installs) = 0, 'nor can a user');
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e2');
select public.app_ping('00000000-0000-0000-0000-00000000aa03', 'guest', '1.1.0', 'android', -5, 2, 0, 0, 1);
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e3');
select public.app_ping('00000000-0000-0000-0000-00000000aa04', 'pro');

reset role;
select pg_temp.expect(
  (select level = 'guest' and pings = 2 and answered = 14 and user_id is null
     from public.app_installs where install = '00000000-0000-0000-0000-00000000aa01'),
  'a phone without an account counts as a guest, once, whatever it claims');
select pg_temp.expect(
  (select level from public.app_installs where install = '00000000-0000-0000-0000-00000000aa02') = 'free'
  and (select level = 'ultra' and answered = 0 from public.app_installs where install = '00000000-0000-0000-0000-00000000aa03')
  and (select level from public.app_installs where install = '00000000-0000-0000-0000-00000000aa04') = 'free',
  'the plan level of a signed-in phone comes from the account, not from the phone');
select pg_temp.expect(
  (select answered is null from public.app_installs where install = '00000000-0000-0000-0000-00000000aa02'),
  'totals stay empty for someone who does not share them');

-- Some activity for the figures.
insert into public.user_sessions (id, user_id, kind, title, started_at, outcome) values
  ('00000000-0000-0000-0000-00000000bb01', '00000000-0000-0000-0000-0000000000e1', 'alarm', 'Alarm', now(), 'timed_out');
insert into public.user_attempts (user_id, client_id, question_id, mode, correct, answered_at)
select '00000000-0000-0000-0000-0000000000e1', gen_random_uuid(), 'tg-01', 'alarm', n > 4, now() - interval '1 hour'
from generate_series(1, 6) n;
insert into public.user_attempts (user_id, client_id, question_id, mode, correct, answered_at)
  values ('00000000-0000-0000-0000-0000000000e2', gen_random_uuid(), 'own-question', 'bank', true, now() - interval '400 days');
insert into public.alarm_events (user_id, client_id, at, type) values
  ('00000000-0000-0000-0000-0000000000e1', gen_random_uuid(), now(), 'rang'),
  ('00000000-0000-0000-0000-0000000000e1', gen_random_uuid(), now(), 'dismissed'),
  ('00000000-0000-0000-0000-0000000000e1', gen_random_uuid(), now(), 'timed_out');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
do $$
begin
  perform public.admin_usage_stats();
  raise exception 'FAILED: a user read the statistics';
exception when insufficient_privilege then
  raise notice 'ok: only admins read the statistics';
end $$;

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e4');
create temp table s as select public.admin_usage_stats(30) as j;
select pg_temp.expect(
  (select (j #>> '{phones,total}')::int = 4 and (j #>> '{phones,by_level,guest}')::int = 1
      and (j #>> '{phones,by_level,free}')::int = 2 and (j #>> '{phones,by_level,ultra}')::int = 1
      and (j #>> '{phones,sharing}')::int = 2 and (j #>> '{phones,answered}')::int = 14 from s),
  'phones are counted by plan level');
select pg_temp.expect(
  (select (j #>> '{accounts,ultra}')::int >= 1 and (j #>> '{accounts,free}')::int >= 2
      and (j #>> '{accounts,total}')::int = (j #>> '{accounts,free}')::int + (j #>> '{accounts,pro}')::int
        + (j #>> '{accounts,ultra}')::int + (j #>> '{accounts,by_hand}')::int from s),
  'accounts are split into free, Pro, Ultra and by hand');
select pg_temp.expect(
  (select (j #>> '{questions,answered}')::int = 6 and (j #>> '{questions,correct}')::int = 2
      and (j #>> '{questions,in_alarms}')::int = 6 and (j #>> '{questions,learners}')::int = 1
      and (j #>> '{questions,answered_all_time}')::int >= 7
      and j #>> '{questions,by_topic,0,topic}' = 'Unit A / Starter'
      and (j #>> '{questions,hardest,0,rate}')::int = 33 from s),
  'answers are counted for the period, by topic, with the hardest questions');
select pg_temp.expect(
  (select (j #>> '{alarms,rang}')::int = 1 and (j #>> '{alarms,answered}')::int = 1
      and (j #>> '{alarms,timed_out}')::int = 1 from s),
  'alarms are counted by how they ended');
select pg_temp.expect(
  (select jsonb_array_length(j -> 'by_day') = 31 and (j #>> '{by_day,30,answers}')::int + (j #>> '{by_day,29,answers}')::int = 6 from s),
  'there is a row for every day');

reset role;
select 'PASSED: usage ping and statistics' as result;

-- Devices (part 15).
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
select public.app_ping('00000000-0000-0000-0000-00000000aa02', 'free', '1.2.0', 'android', null, null, null, null, 1, 'Tecno Camon 30 (Android 14)');
select public.app_ping('00000000-0000-0000-0000-00000000aa02', 'free', '1.0.0', 'android');
select pg_temp.act_as(null);
select public.app_ping('00000000-0000-0000-0000-00000000aa05', 'guest', '1.2.0', 'android', null, null, null, null, 0, 'Tecno Camon 30 (Android 14)');
do $$
begin
  perform public.admin_devices();
  raise exception 'FAILED: a visitor listed the phones';
exception when insufficient_privilege then
  raise notice 'ok: only admins list phones';
end $$;
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e4');
select pg_temp.expect(
  (select count(*) = 1 from jsonb_array_elements(public.admin_devices() -> 'by_account') d
    where d ->> 'user_id' = '00000000-0000-0000-0000-0000000000e1' and d ->> 'device' = 'Tecno Camon 30 (Android 14)'),
  'an account''s phone is listed with its model, and an older app version does not wipe it');
select pg_temp.expect(
  (select (d ->> 'phones')::int = 2 and (d ->> 'without_account')::int = 1
     from jsonb_array_elements(public.admin_devices() -> 'models') d where d ->> 'device' = 'Tecno Camon 30 (Android 14)'),
  'phone models are counted, guests included');
reset role;
select 'PASSED: devices' as result;

-- One row per phone (part 16).
select pg_temp.act_as(null);
select public.app_ping('00000000-0000-0000-0000-00000000aa09', 'guest', '1.0.0', 'android');
reset role;
update public.app_installs set first_seen = now() - interval '9 days' where install = '00000000-0000-0000-0000-00000000aa09';
select pg_temp.act_as(null);
select public.app_ping(install => '00000000-0000-0000-0000-00000000bb09', version => '1.3.0', platform => 'android',
                       device => 'Pixel 8 (Android 16)', replaces => '00000000-0000-0000-0000-00000000aa09');
select public.app_ping(install => '00000000-0000-0000-0000-00000000bb09', version => '1.3.0', platform => 'android');
reset role;
select pg_temp.expect(
  (select count(*) from public.app_installs where install = '00000000-0000-0000-0000-00000000aa09') = 0
  and (select first_seen < now() - interval '8 days' and pings = 2 and device = 'Pixel 8 (Android 16)'
         from public.app_installs where install = '00000000-0000-0000-0000-00000000bb09'),
  'a phone counted under an old number is folded into its new one, keeping its first day');
select 'PASSED: one row per phone' as result;

-- App releases (part 17).
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
do $$
begin
  insert into public.app_releases (version, url) values ('9.9.9', 'https://example.com/x.apk');
  raise exception 'FAILED: a user published a release';
exception when insufficient_privilege then
  raise notice 'ok: a user cannot publish a release';
end $$;
reset role;
insert into public.app_releases (version, url, size_mb, notes) values ('1.0.1', 'https://example.com/a.apk', 24.5, 'Fixes.');
select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.app_releases) = 1, 'anyone can read the releases');
reset role;
select 'PASSED: releases' as result;

-- Home page questions (part 18).
select pg_temp.act_as(null);
select pg_temp.expect(
  (select jsonb_array_length(public.homepage_questions()) between 1 and 12
     and bool_and(q ->> 'topic' = 'Starter') from jsonb_array_elements(public.homepage_questions(30)) q),
  'with nothing picked, the home page gets starter-topic questions');
reset role;
update public.questions set on_homepage = true where id in ('tp-01', 'tp-02');
update public.questions set on_homepage = true, status = 'draft' where id = 'tp-03';
select pg_temp.act_as(null);
select pg_temp.expect(
  (select jsonb_array_length(public.homepage_questions()) = 2
     and bool_and(q ->> 'topic' = 'Rest' and q ? 'answer') from jsonb_array_elements(public.homepage_questions()) q),
  'picked questions are served, with their answers, and drafts are not');
reset role;
select 'PASSED: home page questions' as result;
