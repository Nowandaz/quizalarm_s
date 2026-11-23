-- Checks units > sub units > sections > topics.
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
-- (unit 'ua' with topics tg, tf, tp, td and admin e4 come from the access test)
insert into public.units (id, name) values ('ub', 'Unit B');
insert into public.sections (id, unit_id, kind, name) values
  ('ua-sub', 'ua', 'subunit', 'Sub unit'), ('ua-loose', 'ua', 'section', 'Loose section'), ('ub-sub', 'ub', 'subunit', 'B sub');
insert into public.sections (id, unit_id, parent_id, kind, name) values ('ua-in', 'ua', 'ua-sub', 'section', 'Inside');
update public.topics set section_id = 'ua-in' where id in ('tg', 'tf');
update public.topics set section_id = 'ua-loose' where id = 'tp';

do $$
begin
  insert into public.sections (id, unit_id, parent_id, kind, name) values ('bad1', 'ua', 'ua-loose', 'section', 'x');
  raise exception 'FAILED: a section was put inside a section';
exception when check_violation then raise notice 'ok: a section can only sit in a sub unit';
end $$;
do $$
begin
  insert into public.sections (id, unit_id, parent_id, kind, name) values ('bad2', 'ua', 'ub-sub', 'section', 'x');
  raise exception 'FAILED: a section was put in another unit''s sub unit';
exception when check_violation then raise notice 'ok: a section''s sub unit is in the same unit';
end $$;
do $$
begin
  insert into public.sections (id, unit_id, parent_id, kind, name) values ('bad3', 'ua', 'ua-sub', 'subunit', 'x');
  raise exception 'FAILED: a sub unit was nested';
exception when check_violation then raise notice 'ok: sub units do not nest';
end $$;
do $$
begin
  update public.topics set section_id = 'ua-sub' where id = 'td';
  raise exception 'FAILED: a topic was filed straight into a sub unit';
exception when check_violation then raise notice 'ok: a topic is filed in a section, not a sub unit';
end $$;

select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.sections where unit_id = 'ua') = 3, 'anyone can read the structure');
do $$
begin
  insert into public.sections (id, unit_id, name) values ('hack', 'ua', 'x');
  raise exception 'FAILED: a visitor added a section';
exception when insufficient_privilege then raise notice 'ok: a visitor cannot add sections';
end $$;
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
do $$
begin
  perform public.admin_move_section('ua-in', 'ub', 'ub-sub');
  raise exception 'FAILED: a user moved a section';
exception when insufficient_privilege then raise notice 'ok: only admins move sections';
end $$;

select pg_temp.act_as('00000000-0000-0000-0000-0000000000e4');
select public.admin_move_section('ua-loose', 'ub', 'ub-sub');
select pg_temp.expect(
  (select unit_id = 'ub' and parent_id = 'ub-sub' from public.sections where id = 'ua-loose')
  and (select unit_id = 'ub' and section_id = 'ua-loose' from public.topics where id = 'tp')
  and (select count(*) from public.questions where topic_id = 'tp') >= 12,
  'a section moves to another unit''s sub unit with its topics and questions');
select public.admin_move_section('ua-sub', 'ub');
select pg_temp.expect(
  (select unit_id = 'ub' and parent_id is null from public.sections where id = 'ua-sub')
  and (select unit_id = 'ub' and parent_id = 'ua-sub' from public.sections where id = 'ua-in')
  and (select bool_and(unit_id = 'ub' and section_id = 'ua-in') from public.topics where id in ('tg', 'tf')),
  'a sub unit moves with its sections and their topics');
select public.admin_move_section('ua-in', 'ub');
select pg_temp.expect((select parent_id is null from public.sections where id = 'ua-in'),
  'a section can be taken out of its sub unit');

-- Access is still decided by the topic, wherever it is filed.
select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.questions where topic_id = 'tg') between 1 and 10,
  'a starter topic stays open to guests after being moved');
reset role;
select 'PASSED: sections' as result;

-- The number of published questions a topic has (part 21).
select pg_temp.expect((select question_count from public.topics where id = 'tf') = 12,
  'a topic knows how many published questions it has');
insert into public.questions (id, topic_id, type, text, answer) values ('cnt-1', 'td', 'saq', 'Counted?', 'Yes');
insert into public.questions (id, topic_id, type, text, answer, status) values ('cnt-2', 'td', 'saq', 'Draft?', 'Yes', 'draft');
select pg_temp.expect((select question_count from public.topics where id = 'td') = 13, 'adding a published question raises it; a draft does not');
update public.questions set status = 'published' where id = 'cnt-2';
update public.questions set deleted_at = now() where id = 'cnt-1';
select pg_temp.expect((select question_count from public.topics where id = 'td') = 13, 'publishing adds one and deleting takes one away');
update public.questions set topic_id = 'tf' where id = 'cnt-2';
select pg_temp.expect((select question_count from public.topics where id = 'td') = 12
  and (select question_count from public.topics where id = 'tf') = 13, 'moving a question updates both topics');
select 'PASSED: question counts' as result;

-- Announcements (part 22).
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
do $$
begin
  insert into public.announcements (title) values ('Hacked');
  raise exception 'FAILED: a user posted an announcement';
exception when insufficient_privilege then raise notice 'ok: a user cannot post an announcement';
end $$;
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e4');
insert into public.announcements (title, body, audience) values ('Pharmacology topics uploaded', 'Open Banks to see them.', 'all');
select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.announcements where title like 'Pharmacology%') = 1, 'anyone can read announcements');
reset role;
select 'PASSED: announcements' as result;

-- Marks and long answer questions (part 23).
reset role;
update public.topics set access = 'guest' where id = 'tg';
insert into public.questions (id, topic_id, type, text, answer, marks, long_answer, key_points, created_at) values
  ('long-1', 'tg', 'saq', 'List 2 loop diuretics (2 marks)', 'Furosemide; bumetanide; torsemide', 2, true,
   '[["furosemide","frusemide"],["bumetanide"],["torsemide","torasemide"]]', now() - interval '3 days');
select pg_temp.act_as(null);
select pg_temp.expect((select count(*) from public.questions where id = 'long-1') = 0,
  'an app that does not know long answers is not given them');
select set_config('request.headers', '{"x-app-features":"long-answers"}', false);
select pg_temp.expect((select marks = 2 and jsonb_array_length(key_points) = 3 from public.questions where id = 'long-1'),
  'an app that says it knows them gets them, with marks and key points');
select set_config('request.headers', '', false);
select pg_temp.expect((select count(*) from jsonb_array_elements(public.homepage_questions(30)) q where q ->> 'text' like 'List 2 loop%') = 0,
  'the home page demo never asks a long answer question');
reset role;
do $$
begin
  insert into public.questions (id, topic_id, type, text, options, answer, long_answer)
    values ('long-bad', 'tg', 'mcq', 'x', '["a","b","c","d","e"]', 'a', true);
  raise exception 'FAILED: a multiple choice question was marked long answer';
exception when check_violation then raise notice 'ok: only typed questions can be long answer';
end $$;
select 'PASSED: long answers' as result;
