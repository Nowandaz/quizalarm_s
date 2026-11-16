-- Checks the AI provider list and its round robin. Runs after the owner
-- tests: ...00a is the owner, ...00c is a user.
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

-- A user can do nothing here.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select pg_temp.refused('select * from public.ai_providers', 'a user cannot read providers');
select pg_temp.refused('select * from public.admin_list_ai_providers()', 'a user cannot list providers');
select pg_temp.refused($$select public.admin_save_ai_provider(null, 'x', 'openai', 'k')$$, 'a user cannot add a provider');
select pg_temp.refused('select * from public.pick_ai_provider()', 'a user cannot take a key');

-- The owner manages the list but never sees a key.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select public.admin_save_ai_provider(null, 'Groq', 'openai', 'gsk-secret-AAAA', 'https://api.groq.com/openai/v1', 'model-a', 1, true);
select public.admin_save_ai_provider(null, 'Gemini', 'gemini', 'AIza-secret-BBBB', '', '', 2, true);
select public.admin_save_ai_provider(null, 'Off', 'anthropic', 'sk-ant-CCCC', '', '', 1, false);
select pg_temp.expect((select count(*) from public.admin_list_ai_providers()) = 3, 'the owner lists providers');
select pg_temp.expect(
  (select key_ending from public.admin_list_ai_providers() where name = 'Groq') = 'AAAA',
  'the owner sees only the last 4 characters of a key');
select pg_temp.refused('select api_key from public.ai_providers', 'even the owner cannot read a key');
select pg_temp.refused('select * from public.pick_ai_provider()', 'even the owner cannot take a key through the site');
select pg_temp.refused($$select public.admin_save_ai_provider(null, 'Bad', 'openai', '  ')$$, 'a provider needs a key');
select pg_temp.refused($$select public.admin_save_ai_provider(null, 'Bad', 'nonsense', 'k')$$, 'an unknown type is refused');

-- Editing without typing a key keeps the old one.
select public.admin_save_ai_provider(
  (select id from public.admin_list_ai_providers() where name = 'Groq'),
  'Groq main', 'openai', '', 'https://api.groq.com/openai/v1', 'model-b', 1, true);
select pg_temp.expect(
  (select key_ending = 'AAAA' and model = 'model-b' from public.admin_list_ai_providers() where name = 'Groq main'),
  'editing with an empty key keeps the saved key');

-- The server takes them in turn: Gemini has weight 2, so of 6 calls it
-- gets 4 and Groq gets 2; the disabled one gets none.
reset role;
set role service_role;
create temp table picks as
  select (public.pick_ai_provider()).name as name from generate_series(1, 6);
select pg_temp.expect(
  (select count(*) from picks where name = 'Gemini') = 4
  and (select count(*) from picks where name = 'Groq main') = 2
  and (select count(*) from picks where name = 'Off') = 0,
  'calls are shared out by weight, skipping disabled providers');
select pg_temp.expect(
  (select api_key from public.pick_ai_provider() limit 1) like '%secret%',
  'the server receives the real key');
select pg_temp.expect(
  (select name from public.pick_ai_provider(
     array(select id from public.ai_providers where name = 'Gemini'))) = 'Groq main',
  'a provider that just failed can be skipped');
select public.report_ai_provider_error(
  (select id from public.ai_providers where name = 'Gemini'), 'HTTP 429 quota');
reset role;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect(
  (select last_error from public.admin_list_ai_providers() where name = 'Gemini') = 'HTTP 429 quota',
  'the owner sees the last error of a provider');
select public.admin_set_ai_provider_enabled(
  (select id from public.admin_list_ai_providers() where name = 'Gemini'), false);
select public.admin_delete_ai_provider(
  (select id from public.admin_list_ai_providers() where name = 'Off'));
select pg_temp.expect(
  (select count(*) from public.admin_list_ai_providers()) = 2
  and (select not enabled from public.admin_list_ai_providers() where name = 'Gemini'),
  'the owner switches a provider off and deletes one');
reset role;
set role service_role;
select pg_temp.expect(
  (select count(*) from public.pick_ai_provider(
     array(select id from public.ai_providers where name = 'Groq main'))) = 0,
  'when nothing usable is left, the server gets nothing (and can say so)');
reset role;

\echo AI PROVIDER TESTS PASSED
