-- Checks who gets which questions, the plans, and flagged questions.
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
truncate public.units cascade;
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'free@example.com'),
  ('00000000-0000-0000-0000-0000000000e2', 'pro@example.com'),
  ('00000000-0000-0000-0000-0000000000e3', 'lapsed@example.com'),
  ('00000000-0000-0000-0000-0000000000e4', 'admin2@example.com');
update public.profiles set plan = 'premium', tier = 'pro', plan_expires_at = now() + interval '5 days'
  where id = '00000000-0000-0000-0000-0000000000e2';
update public.profiles set plan = 'premium', tier = 'pro', plan_expires_at = now() - interval '1 minute'
  where id = '00000000-0000-0000-0000-0000000000e3';
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000000e4';

insert into public.units (id, name) values ('ua', 'Unit A');
insert into public.topics (id, unit_id, name, access) values
  ('tg', 'ua', 'Starter', 'guest'), ('tf', 'ua', 'Extra', 'free'), ('tp', 'ua', 'Rest', 'paid');
insert into public.topics (id, unit_id, name) values ('td', 'ua', 'New topic');
-- 12 published questions in each topic, plus one draft in the starter.
insert into public.questions (id, topic_id, type, text, answer, created_at)
select t.id || '-' || lpad(n::text, 2, '0'), t.id, 'saq', 'Q' || n || ' of ' || t.id, 'A',
       now() - interval '1 day' + n * interval '1 minute'
from public.topics t, generate_series(1, 12) n;
insert into public.questions (id, topic_id, type, text, answer, status, created_at)
  values ('tg-00', 'tg', 'saq', 'Draft', 'A', 'draft', now() - interval '2 days');

select pg_temp.expect((select access from public.topics where id = 'td') = 'paid',
  'a new topic is for paid plans until an admin opens it');

-- Guest
select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.topics) = 4, 'a guest sees every topic name');
select pg_temp.expect((select count(*) from public.questions) = 10, 'a guest gets 10 questions in all');
select pg_temp.expect((select count(*) from public.questions where topic_id = 'tg') = 10
  and (select max(id) from public.questions) = 'tg-10',
  'they are the first 10 published questions of the starter topic');

-- Free account
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
select pg_temp.expect((select count(*) from public.questions where topic_id = 'tg') = 10
  and (select count(*) from public.questions where topic_id = 'tf') = 10
  and (select count(*) from public.questions where topic_id in ('tp', 'td')) = 0,
  'a free account gets 10 questions of the starter and free topics, none of the rest');

-- A plan that has run out is a free account again.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e3');
select pg_temp.expect((select count(*) from public.questions) = 20, 'a lapsed plan is back to the free questions');

-- Paid
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e2');
select pg_temp.expect((select count(*) from public.questions) = 48, 'a paid plan gets every published question');
select pg_temp.expect((select count(*) from public.questions where status = 'draft') = 0, 'but no drafts');

-- The sample size is a setting.
reset role;
update public.app_config set value = '3' where key = 'sample_questions';
select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.questions) = 3, 'the sample size follows the setting');
reset role;
update public.app_config set value = '10' where key = 'sample_questions';

-- Plans
select pg_temp.expect(
  (select ai_daily_limit = 100 from public.tiers where id = 'pro')  -- (an earlier test changed its price)
  and (select price_month = 150 and ai_daily_limit = 500 from public.tiers where id = 'ultra'),
  'Pro is 100 a month with 100 AI calls, Ultra 150 with 500');

-- Flags
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
insert into public.question_flags (id, question_id, question_text, reason, note)
  values ('00000000-0000-0000-0000-00000000f001', 'tg-01', 'Q1 of tg', 'wrong_answer', 'B is right');
select pg_temp.expect((select user_id from public.question_flags) = auth.uid(), 'a flag belongs to whoever sent it');
do $$
begin
  insert into public.question_flags (question_id, user_id)
    values ('tg-02', '00000000-0000-0000-0000-0000000000e2');
  raise exception 'FAILED: flagged in someone else''s name';
exception when insufficient_privilege then
  raise notice 'ok: nobody can flag in someone else''s name';
end $$;
do $$
begin
  insert into public.question_flags (question_id, status) values ('tg-03', 'resolved');
  raise exception 'FAILED: sent a flag that is already resolved';
exception when insufficient_privilege then
  raise notice 'ok: a new flag is always open';
end $$;
do $$
begin
  perform public.admin_list_flags();
  raise exception 'FAILED: a user listed the flags';
exception when insufficient_privilege then
  raise notice 'ok: only admins list flags';
end $$;
update public.question_flags set status = 'resolved';
select pg_temp.expect((select status from public.question_flags) = 'open', 'a user cannot resolve a flag');

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e2');
select pg_temp.expect((select count(*) from public.question_flags) = 0, 'a user does not see other people''s flags');
insert into public.question_flags (question_id, reason) values ('tg-01', 'unclear');
select pg_temp.act_as(null);
do $$
begin
  insert into public.question_flags (question_id) values ('tg-01');
  raise exception 'FAILED: a guest flagged a question';
exception when insufficient_privilege then
  raise notice 'ok: a guest cannot flag';
end $$;

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e4');
select pg_temp.expect(
  (select count(*) = 2 and bool_and(in_bank) and bool_and(topic = 'Starter') and bool_and(others = 1)
     and bool_or(email = 'free@example.com')
   from public.admin_list_flags()),
  'an admin sees the flags with the question, the topic and who sent them');
select pg_temp.expect(
  public.admin_resolve_flag('00000000-0000-0000-0000-00000000f001', true, true) = 2,
  'an admin resolves every flag on a question at once');
select pg_temp.expect(
  (select count(*) from public.admin_list_flags()) = 0
  and (select count(*) from public.admin_list_flags(false)) = 2,
  'resolved flags leave the open list');
select pg_temp.expect(
  public.admin_resolve_flag('00000000-0000-0000-0000-00000000f001', false) = 1,
  'a flag can be opened again');
select pg_temp.expect((select count(*) from public.admin_list_flags()) = 1, 'and is back in the open list');

-- The daily cap.
reset role;
insert into public.question_flags (user_id, question_id)
select '00000000-0000-0000-0000-0000000000e1', 'bulk-' || n from generate_series(1, 29) n;
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
do $$
begin
  insert into public.question_flags (question_id) values ('one-too-many');
  raise exception 'FAILED: more than 30 flags in a day';
exception when check_violation then
  raise notice 'ok: at most 30 flags a day';
end $$;

reset role;
select 'PASSED: access levels, plans and flags' as result;
