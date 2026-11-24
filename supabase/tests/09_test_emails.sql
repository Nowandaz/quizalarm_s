-- Emails: who an email goes to.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email, email_confirmed_at) values
  ('e0000000-0000-0000-0000-000000000001', 'free@x.test', now()),
  ('e0000000-0000-0000-0000-000000000002', 'paid@x.test', now()),
  ('e0000000-0000-0000-0000-000000000003', 'unconfirmed@x.test', null),
  ('e0000000-0000-0000-0000-000000000004', 'stopped@x.test', now()),
  ('e0000000-0000-0000-0000-000000000005', 'boss@x.test', now());
update public.profiles set plan = 'premium', plan_expires_at = now() + interval '9 days'
  where id = 'e0000000-0000-0000-0000-000000000002';
update public.profiles set email_updates = false where id = 'e0000000-0000-0000-0000-000000000004';
update public.profiles set role = 'owner' where id = 'e0000000-0000-0000-0000-000000000005';
insert into public.app_releases (version, url) values ('9.0.2', 'https://x.test/a.apk');
insert into public.app_installs (install, user_id, level, version, last_seen) values
  (gen_random_uuid(), 'e0000000-0000-0000-0000-000000000001', 'free', '9.0.0+1', now() - interval '2 days'),
  (gen_random_uuid(), 'e0000000-0000-0000-0000-000000000002', 'pro', '9.0.0+1', now() - interval '5 days'),
  (gen_random_uuid(), 'e0000000-0000-0000-0000-000000000002', 'pro', '9.0.2+3', now());

do $$
declare got text[];
begin
  assert public.version_parts('1.0.10+3') = array[1,0,10];
  assert public.version_parts('1.0.10') > public.version_parts('1.0.9+7');

  select array_agg(email order by email) into got from public.email_recipients('all') where email like '%@x.test';
  assert got = array['boss@x.test','free@x.test','paid@x.test'], 'all: ' || got::text;
  raise notice 'ok: unconfirmed and unsubscribed addresses are never written to';

  select array_agg(email order by email) into got from public.email_recipients('paid') where email like '%@x.test';
  assert got = array['paid@x.test'];
  select array_agg(email order by email) into got from public.email_recipients('free') where email like '%@x.test';
  assert got = array['boss@x.test','free@x.test'];
  raise notice 'ok: free and paid';

  select array_agg(email order by email) into got from public.email_recipients('version', '9.0.0') where email like '%@x.test';
  assert got = array['free@x.test'], 'version: ' || coalesce(got::text, 'null');
  select array_agg(email order by email) into got from public.email_recipients('older') where email like '%@x.test';
  assert got = array['free@x.test'], 'older: ' || coalesce(got::text, 'null');
  raise notice 'ok: by app version goes by the phone used last';

  assert (select count(*) from public.email_recipients('nonsense')) = 0;
end $$;

-- Only admins may count, and nobody signed in may read the addresses.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'e0000000-0000-0000-0000-000000000001', true);
do $$
begin
  begin
    perform public.admin_email_count('all');
    raise exception 'a user counted recipients';
  exception when others then
    if sqlerrm not like '%admins only%' then raise; end if;
  end;
  begin
    perform * from public.email_recipients('all');
    raise exception 'a user read addresses';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok: users cannot count recipients or read addresses';
end $$;
select set_config('request.jwt.claim.sub', 'e0000000-0000-0000-0000-000000000005', true);
do $$
begin
  assert public.admin_email_count('paid') >= 1;
  assert exists (select 1 from public.admin_email_versions() where version = '9.0.0');
  raise notice 'ok: an admin can count and see the versions';
end $$;
reset role;

rollback;
\echo ' PASSED: emails'
