-- Checks payments. Runs last: ...00a is the owner; a buyer is made here.
\set ON_ERROR_STOP on

create function pg_temp.act_as(who uuid, as_role text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(who::text, ''), false);
  execute format('set role %I', coalesce(as_role, case when who is null then 'anon' else 'authenticated' end));
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

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000b1', 'buyer@example.com');

-- The server starts two payments.
select pg_temp.act_as(null, 'service_role');
insert into public.payments (user_id, reference, plan, days, amount, currency) values
  ('00000000-0000-0000-0000-0000000000b1', 'bw_test_month', 'month', 30, 30000, 'KES'),
  ('00000000-0000-0000-0000-0000000000b1', 'bw_test_year', 'year', 365, 250000, 'KES'),
  ('00000000-0000-0000-0000-0000000000b1', 'bw_test_short', 'month', 30, 30000, 'KES');

-- The buyer can look but not touch.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
select pg_temp.expect((select count(*) = 3 from public.payments), 'a buyer sees their own payments');
select pg_temp.refused($$update public.payments set status = 'paid'$$, 'a buyer cannot mark a payment as paid');
select pg_temp.refused($$insert into public.payments (user_id, reference, plan, days, amount, currency, status)
  values ('00000000-0000-0000-0000-0000000000b1', 'bw_forged_1', 'year', 365, 1, 'KES', 'paid')$$,
  'a buyer cannot write a payment');
select pg_temp.refused($$select public.apply_payment('bw_test_month', 30000, 'KES')$$,
  'a buyer cannot confirm their own payment');
select pg_temp.refused('select * from public.admin_list_payments()', 'a buyer cannot list everyone''s payments');

-- Paystack reports to the server.
select pg_temp.act_as(null, 'service_role');
select pg_temp.expect(public.apply_payment('bw_nope', 1, 'KES') = 'unknown', 'an unknown reference changes nothing');
select pg_temp.expect(public.apply_payment('bw_test_short', 100, 'KES') = 'failed', 'too little money buys nothing');
select pg_temp.expect((select plan = 'free' from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'),
  'and the plan is untouched');
select pg_temp.expect(public.apply_payment('bw_test_month', 30000, 'USD') = 'failed', 'the wrong currency buys nothing');
update public.payments set status = 'pending', note = '' where reference = 'bw_test_month';

select pg_temp.expect(public.apply_payment('bw_test_month', 30000, 'kes', 'mobile_money') = 'paid', 'the right amount is accepted');
select pg_temp.expect(
  (select plan = 'premium' and plan_expires_at between now() + interval '29 days' and now() + interval '31 days'
   from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'),
  'thirty days of premium are added');
select pg_temp.expect(public.apply_payment('bw_test_month', 30000, 'KES') = 'paid', 'a repeated message is accepted');
select pg_temp.expect(
  (select plan_expires_at < now() + interval '31 days' from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'),
  'but the days are added only once');
select pg_temp.expect(public.apply_payment('bw_test_year', 250000, 'KES') = 'paid', 'a second purchase is accepted');
select pg_temp.expect(
  (select plan_expires_at between now() + interval '394 days' and now() + interval '396 days'
   from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'),
  'and its days are added on top of what was left');

-- The owner sees the money.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect((select count(*) = 3 and bool_or(email = 'buyer@example.com') from public.admin_list_payments()),
  'the owner sees payments with who paid');
select pg_temp.expect(
  (select t ->> 'paid' = '2' and t ->> 'failed' = '1' and t -> 'income' -> 0 ->> 'amount' = '280000'
   from public.admin_payment_totals() t), 'totals add up');

-- A deleted account keeps its money record.
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.expect((select count(*) = 3 and bool_and(user_id is null) from public.payments),
  'payments survive the account, without the person');

select 'PAYMENT TESTS PASSED';
