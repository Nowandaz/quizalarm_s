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

-- Tiers and codes (part 10).
reset role;
insert into public.tiers (id, name, price_month, price_year, ai_daily_limit, premium_units, sort_order)
  values ('max', 'Max', 800, null, 500, true, 2), ('lite', 'Lite', 100, 900, 50, false, 0);
insert into public.promo_codes (code, percent_off, tier, max_uses, expires_at) values
  ('HALF', 50, null, 1, null), ('MAXONLY', 20, 'max', null, null),
  ('OLD', 30, null, null, now() - interval '1 day'), ('GIFT', 100, null, null, null);

select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
select pg_temp.expect((select count(*) = 0 from public.promo_codes), 'a buyer cannot see discount codes');
select pg_temp.refused($$select public.quote_payment('pro', 'month', 'HALF')$$, 'a buyer cannot ask the database for prices directly');
update public.tiers set price_month = 1;
update public.promo_codes set percent_off = 100;
select pg_temp.expect((select price_month = 800 from public.tiers where id = 'max'), 'a buyer cannot change a price');
select pg_temp.expect((select count(*) >= 3 from public.tiers), 'anyone can read the tiers');

select pg_temp.act_as(null, 'service_role');
select pg_temp.expect((select q ->> 'price' = '300.00' and q ->> 'days' = '30' and q ->> 'currency' = 'KES'
  from public.quote_payment('pro', 'month') q), 'the first tier kept the old price');
select pg_temp.expect((select (q ->> 'ok')::boolean = false from public.quote_payment('max', 'year') q),
  'a period with no price is not on sale');
select pg_temp.expect((select q ->> 'price' = '150.00' and q ->> 'percent_off' = '50' and q ->> 'code' = 'HALF'
  from public.quote_payment('pro', 'month', ' half ') q), 'a code takes its percentage off');
select pg_temp.expect((select q ->> 'price' = '300.00' and q ->> 'code_message' = 'That code is for a different plan.'
  from public.quote_payment('pro', 'month', 'MAXONLY') q), 'a code for another tier is refused, at full price');
select pg_temp.expect((select q ->> 'code_message' = 'That code has expired.' from public.quote_payment('pro', 'month', 'OLD') q),
  'an expired code is refused');
select pg_temp.expect((select q ->> 'code_message' = 'That code is not valid.' from public.quote_payment('pro', 'month', 'NOPE') q),
  'an unknown code is refused');
select pg_temp.expect((select q ->> 'price' = '0.00' from public.quote_payment('max', 'month', 'GIFT') q), 'a 100% code makes it free');

-- Buying Max with the HALF code moves the account to Max and uses the code up.
insert into public.payments (user_id, reference, plan, days, amount, full_amount, currency, tier, code)
  values ('00000000-0000-0000-0000-0000000000b1', 'bw_test_max', 'month', 30, 40000, 80000, 'KES', 'max', 'HALF');
select pg_temp.expect(public.apply_payment('bw_test_max', 40000, 'KES', 'mobile_money') = 'paid', 'a discounted payment is accepted');
select pg_temp.expect((select tier = 'max' from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'),
  'the account is on the tier it bought');
select pg_temp.expect((select q ->> 'code_message' = 'That code has been used up.' from public.quote_payment('pro', 'month', 'HALF') q),
  'a code with one use cannot be used twice');
-- A gift code: nothing to pay.
insert into public.payments (user_id, reference, plan, days, amount, full_amount, currency, tier, code)
  values ('00000000-0000-0000-0000-0000000000b1', 'bw_test_gift', 'month', 30, 0, 10000, 'KES', 'lite', 'GIFT');
select pg_temp.expect(public.apply_payment('bw_test_gift', 0, 'KES', '') = 'paid', 'a free payment is accepted');

-- A tier without premium units does not open them.
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
select pg_temp.expect(not public.has_premium(), 'the Lite tier does not open premium units');
select pg_temp.act_as(null, 'service_role');
update public.profiles set tier = 'max' where id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
select pg_temp.expect(public.has_premium(), 'the Max tier does');
select pg_temp.refused($$update public.profiles set tier = 'lite' where id = auth.uid()$$, 'a buyer cannot move themselves to another tier');

-- The owner sees the money.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect((select count(*) = 5 and bool_or(email = 'buyer@example.com') and bool_or(tier_name = 'Max' and code = 'HALF') from public.admin_list_payments()),
  'the owner sees payments with who paid');
select pg_temp.expect(
  (select t ->> 'paid' = '4' and t ->> 'failed' = '1' and t -> 'income' -> 0 ->> 'amount' = '320000'
     and t ->> 'buyers' = '1' and jsonb_array_length(t -> 'by_tier') >= 2
   from public.admin_payment_totals() t), 'totals add up');

-- A deleted account keeps its money record.
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.expect((select count(*) = 5 and bool_and(user_id is null) from public.payments),
  'payments survive the account, without the person');

select 'PAYMENT TESTS PASSED';
