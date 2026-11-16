-- Checks the owner role and the admin_* functions. Runs after
-- 01_test_policies.sql, in the same database:
--   ...00a is an admin, ...00b and ...00c are users.
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
-- Runs a statement that must be refused.
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
grant execute on all functions in schema pg_temp to anon, authenticated;

-- ------------------------------------------------------- claiming ownership
select pg_temp.act_as(null);
select pg_temp.expect(not public.owner_exists(), 'at first there is no owner');
select pg_temp.refused('select public.claim_owner()', 'a visitor cannot claim ownership');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.refused('select * from public.admin_list_users()',
  'an ordinary admin cannot list accounts');
select pg_temp.expect(public.claim_owner(), 'the first signed-in person to claim becomes owner');
select pg_temp.expect(public.is_owner() and public.is_admin(), 'an owner is also an admin');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select pg_temp.expect(not public.claim_owner(), 'nobody else can claim once an owner exists');
select pg_temp.expect(
  (select role from public.profiles where id = auth.uid()) = 'user',
  'the second claimer is still a user');
select pg_temp.refused($$select public.admin_set_role(auth.uid(), 'owner')$$,
  'a user cannot use the owner functions');
select pg_temp.refused($$select public.admin_set_secret('gemini_api_key', 'x')$$,
  'a user cannot set a server secret');
select pg_temp.refused('select * from public.server_secrets',
  'a user cannot read server secrets');
select pg_temp.refused($$update public.app_config set value = '999' where key = 'ai_daily_limit_free'; select 1/((select (value = '999')::int from public.app_config where key = 'ai_daily_limit_free'))$$,
  'a user cannot change server settings');

-- ------------------------------------------------------------ owner powers
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect((select count(*) from public.admin_list_users()) = 3,
  'the owner lists every account');
select pg_temp.expect(
  (select count(*) from public.admin_list_users('bea')) = 1,
  'the owner can search accounts by email');

select public.admin_set_role('00000000-0000-0000-0000-00000000000c', 'admin');
select public.admin_set_plan('00000000-0000-0000-0000-00000000000c', 'premium', now() + interval '30 days');
select pg_temp.expect(
  (select role = 'admin' and plan = 'premium' from public.profiles
   where id = '00000000-0000-0000-0000-00000000000c'),
  'the owner sets roles and plans');
select public.admin_set_plan('00000000-0000-0000-0000-00000000000c', 'free');
select pg_temp.expect(
  (select plan = 'free' and plan_expires_at is null from public.profiles
   where id = '00000000-0000-0000-0000-00000000000c'),
  'going back to free clears the end date');
select pg_temp.refused($$select public.admin_set_role(auth.uid(), 'user')$$,
  'the only owner cannot remove their own owner role');
select pg_temp.refused('select public.admin_delete_user(auth.uid())',
  'the owner cannot delete their own account here');

select pg_temp.expect((select count(*) from public.user_attempts) >= 1,
  'the owner can read users'' answers');
select pg_temp.expect((public.admin_stats() ->> 'users')::int = 3,
  'the dashboard numbers work');

update public.app_config set value = '50' where key = 'ai_daily_limit_free';
select pg_temp.expect(
  (select value = '50' from public.app_config where key = 'ai_daily_limit_free'),
  'the owner changes server settings');

select public.admin_set_secret('gemini_api_key', 'AIza-test-key-1234');
select pg_temp.expect(
  (select ending = '1234' from public.admin_secret_status() where name = 'gemini_api_key'),
  'the owner sets a secret and sees only its last 4 characters');
select pg_temp.refused('select * from public.server_secrets',
  'even the owner cannot read a secret back');

-- An ordinary admin: content yes, people no.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
insert into public.units (id, name) values ('u9', 'Made by an admin');
select pg_temp.expect((select count(*) from public.units where id = 'u9') = 1,
  'an ordinary admin manages content');
select pg_temp.refused('select * from public.admin_list_users()',
  'an ordinary admin cannot list accounts');
select pg_temp.expect(
  (select count(*) from public.user_attempts where user_id <> auth.uid()) = 0,
  'an ordinary admin cannot read users'' answers');

-- The server reads the secret with the service key.
reset role;
set role service_role;
select pg_temp.expect(
  (select value from public.server_secrets where name = 'gemini_api_key') = 'AIza-test-key-1234',
  'the server can read the secret');
reset role;

-- Deleting an account removes everything that belonged to it.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select public.admin_set_role('00000000-0000-0000-0000-00000000000c', 'user');
select public.admin_delete_user('00000000-0000-0000-0000-00000000000b');
reset role;
select pg_temp.expect(
  (select count(*) from public.user_attempts where user_id = '00000000-0000-0000-0000-00000000000b') = 0
  and (select count(*) from public.user_sessions where user_id = '00000000-0000-0000-0000-00000000000b') = 0
  and (select count(*) from public.user_backups where user_id = '00000000-0000-0000-0000-00000000000b') = 0
  and (select count(*) from public.user_questions where user_id = '00000000-0000-0000-0000-00000000000b') = 0
  and (select count(*) from public.ai_usage where user_id = '00000000-0000-0000-0000-00000000000b') = 0
  and (select count(*) from public.profiles where id = '00000000-0000-0000-0000-00000000000b') = 0,
  'the owner deletes an account and all its data goes with it');

\echo OWNER TESTS PASSED
