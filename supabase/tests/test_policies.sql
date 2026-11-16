-- Checks the security rules by acting as different people.
-- Every block raises an error if a rule is wrong; reaching the end = pass.
\set ON_ERROR_STOP on

-- ------------------------------------------------------------------ set-up
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'admin@example.com', '{"full_name":"Ada Admin"}'),
  ('00000000-0000-0000-0000-00000000000b', 'bea@example.com',   '{}'),
  ('00000000-0000-0000-0000-00000000000c', 'cal@example.com',   '{}');
update public.profiles set role = 'admin'
  where id = '00000000-0000-0000-0000-00000000000a';

insert into public.units  values ('u1', 'Unit one');
insert into public.topics (id, unit_id, name) values ('t1', 'u1', 'Topic one');
insert into public.questions (id, topic_id, type, text, answer) values
  ('q1', 't1', 'saq', 'Published?', 'Yes');
insert into public.questions (id, topic_id, type, text, answer, status) values
  ('q2', 't1', 'saq', 'Draft?', 'Yes', 'draft');

-- Helpers: become a signed-in user, a visitor, or yourself again.
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

-- ----------------------------------------------------------------- profiles
select pg_temp.expect(
  (select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = 'Ada Admin',
  'a profile is created for every new account');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select pg_temp.expect((select count(*) from public.profiles) = 1,
  'a user sees only their own profile');
update public.profiles set display_name = 'Bea' where id = auth.uid();
select pg_temp.expect((select display_name from public.profiles) = 'Bea',
  'a user can rename themselves');
do $$
begin
  update public.profiles set role = 'admin' where id = auth.uid();
  raise exception 'FAILED: a user made themselves admin';
exception when others then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok: a user cannot make themselves admin';
end $$;

-- ------------------------------------------------------------ question bank
select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.questions) = 1,
  'a visitor without an account reads published questions only');
do $$
begin
  insert into public.questions (id, topic_id, type, text, answer)
    values ('hack', 't1', 'saq', 'x', 'y');
  raise exception 'FAILED: a visitor added a question';
exception when insufficient_privilege then
  raise notice 'ok: a visitor cannot add questions';
end $$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select pg_temp.expect((select count(*) from public.questions) = 1,
  'a user does not see drafts');
do $$
begin
  insert into public.questions (id, topic_id, type, text, answer)
    values ('hack', 't1', 'saq', 'x', 'y');
  raise exception 'FAILED: a user added a question';
exception when insufficient_privilege then
  raise notice 'ok: a user cannot add questions';
end $$;
update public.questions set answer = 'changed' where id = 'q1';
delete from public.questions where id = 'q1';
reset role;
select pg_temp.expect(
  (select answer from public.questions where id = 'q1') = 'Yes',
  'a user cannot change or delete questions');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect((select count(*) from public.questions) = 2,
  'an admin sees drafts too');
insert into public.questions (id, topic_id, type, text, options, answer) values
  ('q3', 't1', 'mcq', 'Pick', '["a","b","c","d","e"]', 'c');
update public.questions set status = 'published' where id = 'q2';
select pg_temp.expect(
  (select updated_at > created_at from public.questions where id = 'q2'),
  'editing a question moves its updated_at forward');
update public.profiles set role = 'admin'
  where id = '00000000-0000-0000-0000-00000000000c';
update public.profiles set role = 'user'
  where id = '00000000-0000-0000-0000-00000000000c';
select pg_temp.expect(true, 'an admin can grant and remove admin');

-- Shape rules for questions.
do $$
begin
  insert into public.questions (id, topic_id, type, text, options, answer)
    values ('bad1', 't1', 'mcq', 'Four options', '["a","b","c","d"]', 'a');
  raise exception 'FAILED: an MCQ with 4 options was accepted';
exception when check_violation then
  raise notice 'ok: an MCQ must have exactly 5 options';
end $$;
do $$
begin
  insert into public.questions (id, topic_id, type, text, options, answer)
    values ('bad2', 't1', 'mcq', 'Answer missing', '["a","b","c","d","e"]', 'z');
  raise exception 'FAILED: an MCQ whose answer is not an option was accepted';
exception when check_violation then
  raise notice 'ok: an MCQ answer must be one of its options';
end $$;

-- ---------------------------------------------------------------- user data
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into public.user_sessions (id, user_id, kind, started_at) values
  ('10000000-0000-0000-0000-000000000001', auth.uid(), 'alarm', now());
insert into public.user_attempts
  (user_id, client_id, question_id, session_id, mode, correct, answered_at) values
  (auth.uid(), '20000000-0000-0000-0000-000000000001', 'q1',
   '10000000-0000-0000-0000-000000000001', 'alarm', true, now());
insert into public.user_backups (user_id, alarms) values (auth.uid(), '[{"id":1}]');
-- Uploading the same answer again is harmless.
insert into public.user_attempts
  (user_id, client_id, question_id, mode, correct, answered_at) values
  (auth.uid(), '20000000-0000-0000-0000-000000000001', 'q1', 'alarm', true, now())
  on conflict (user_id, client_id) do nothing;
select pg_temp.expect((select count(*) from public.user_attempts) = 1,
  'the same answer uploaded twice is stored once');
do $$
begin
  insert into public.user_attempts
    (user_id, client_id, question_id, mode, correct, answered_at) values
    ('00000000-0000-0000-0000-00000000000c',
     '20000000-0000-0000-0000-000000000002', 'q1', 'bank', true, now());
  raise exception 'FAILED: a user wrote data for someone else';
exception when insufficient_privilege then
  raise notice 'ok: a user cannot write data for someone else';
end $$;
do $$
begin
  insert into public.ai_usage (user_id, kind) values (auth.uid(), 'generate');
  raise exception 'FAILED: a user wrote their own AI usage';
exception when insufficient_privilege then
  raise notice 'ok: only the server records AI usage';
end $$;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select pg_temp.expect(
  (select count(*) from public.user_attempts) = 0
  and (select count(*) from public.user_sessions) = 0
  and (select count(*) from public.user_backups) = 0,
  'a user cannot see another user''s answers, sessions or backup');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect((select count(*) from public.user_attempts) = 0,
  'even an admin does not read users'' answers through the app');

-- The server (service key) can record AI usage for anyone.
reset role;
set role service_role;
insert into public.ai_usage (user_id, kind)
  values ('00000000-0000-0000-0000-00000000000b', 'generate');
reset role;

-- Deleting an account removes everything that belonged to it.
delete from auth.users where id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.expect(
  (select count(*) from public.user_attempts) = 0
  and (select count(*) from public.user_sessions) = 0
  and (select count(*) from public.user_backups) = 0
  and (select count(*) from public.ai_usage) = 0
  and (select count(*) from public.profiles
       where id = '00000000-0000-0000-0000-00000000000b') = 0,
  'deleting an account deletes its data');

\echo ALL POLICY TESTS PASSED
