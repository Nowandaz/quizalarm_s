-- BrainWake database, part 10: paid tiers and discount codes.
--
-- Until now there was one thing to buy ("premium") at two fixed prices.
-- Now the owner defines TIERS on the admin site (for example "Pro" and
-- "Max"): each has a name, a short description, a list of what it offers,
-- a monthly and a yearly price (either can be left out), its own daily AI
-- allowance and whether it opens the premium units of the question bank.
--
-- A user's profile keeps plan = 'premium' while any paid tier is running
-- and now also says WHICH tier. An account made premium by hand on the
-- admin site has no tier and gets everything.
--
-- DISCOUNT CODES take a percentage off. A code can be limited to one tier,
-- to a number of uses and to a date. 100% off makes it free (a gift code).

create table public.tiers (
  id            text primary key check (id ~ '^[a-z0-9][a-z0-9-]{1,30}$'),
  name          text not null check (length(trim(name)) between 1 and 40),
  description   text not null default '' check (length(description) <= 200),
  -- What it offers, one line each, shown as a list in the app.
  features      jsonb not null default '[]'::jsonb check (jsonb_typeof(features) = 'array'),
  -- In whole units of the currency (300 = KES 300). Null = not sold.
  price_month   numeric(12, 2) check (price_month is null or price_month > 0),
  price_year    numeric(12, 2) check (price_year is null or price_year > 0),
  ai_daily_limit integer not null default 200 check (ai_daily_limit >= 0),
  premium_units boolean not null default true,
  sort_order    integer not null default 0,
  -- Switched off: no longer sold. People who already have it keep it.
  active        boolean not null default true,
  updated_at    timestamptz not null default now()
);
create trigger tiers_touch before update on public.tiers
  for each row execute function public.touch_updated_at();

alter table public.tiers enable row level security;
create policy "anyone reads tiers" on public.tiers
  for select to anon, authenticated using (true);
create policy "owner manages tiers" on public.tiers
  for all to authenticated using (public.is_owner()) with check (public.is_owner());
grant select on public.tiers to anon;
grant select, insert, update, delete on public.tiers to authenticated;

-- The one thing sold so far becomes the first tier, at its current prices.
insert into public.tiers (id, name, description, features, price_month, price_year, ai_daily_limit, sort_order)
select 'pro', 'Pro', 'Everything in the question bank and far more AI.',
       '["Every unit in the question bank, including the premium ones",
         "A much higher daily AI allowance for new questions and the tutor",
         "Supports new questions being added"]'::jsonb,
       nullif((select (value #>> '{}')::numeric from public.app_config where key = 'premium_price_month'), 0),
       nullif((select (value #>> '{}')::numeric from public.app_config where key = 'premium_price_year'), 0),
       coalesce((select (value #>> '{}')::integer from public.app_config where key = 'ai_daily_limit_premium'), 200),
       1;
delete from public.app_config where key in ('premium_price_month', 'premium_price_year');
update public.app_config
  set note = 'AI calls per day for an account made premium by hand (tiers set their own)'
  where key = 'ai_daily_limit_premium';

-- Which tier a premium account is on (null: premium given by hand).
alter table public.profiles add column tier text references public.tiers (id) on delete set null;

create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role
      or new.plan is distinct from old.plan
      or new.plan_expires_at is distinct from old.plan_expires_at
      or new.tier is distinct from old.tier)
     and auth.uid() is not null
     and coalesce(current_setting('app.role_guard_off', true), '') <> 'on'
     and not public.is_owner() then
    raise exception 'Only the owner can change a role or plan';
  end if;
  return new;
end;
$$;

-- Premium units open for a running paid plan whose tier includes them.
create or replace function public.has_premium() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    left join public.tiers t on t.id = p.tier
    where p.id = auth.uid()
      and p.plan = 'premium'
      and (p.plan_expires_at is null or p.plan_expires_at > now())
      and coalesce(t.premium_units, true)
  );
$$;

-- The owner can also set the tier when changing a plan by hand.
drop function public.admin_set_plan(uuid, text, timestamptz);
create function public.admin_set_plan(
  target uuid, new_plan text, expires timestamptz default null, new_tier text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  if new_plan not in ('free', 'premium') then
    raise exception 'Unknown plan %', new_plan;
  end if;
  perform set_config('app.role_guard_off', 'on', true);
  update public.profiles
    set plan = new_plan,
        plan_expires_at = case when new_plan = 'premium' then expires end,
        tier = case when new_plan = 'premium' then new_tier end
    where id = target;
end;
$$;
revoke execute on function public.admin_set_plan(uuid, text, timestamptz, text) from public, anon;
grant execute on function public.admin_set_plan(uuid, text, timestamptz, text) to authenticated;

-- ------------------------------------------------------------ discount codes

create table public.promo_codes (
  code        text primary key check (code ~ '^[A-Z0-9]{3,20}$'),
  percent_off integer not null check (percent_off between 1 and 100),
  -- Only for this tier (null: any tier).
  tier        text references public.tiers (id) on delete cascade,
  max_uses    integer check (max_uses is null or max_uses > 0),
  used        integer not null default 0,
  expires_at  timestamptz,
  active      boolean not null default true,
  note        text not null default '' check (length(note) <= 200),
  created_at  timestamptz not null default now()
);
alter table public.promo_codes enable row level security;
-- Only the owner sees or edits codes. The app never lists them: it sends
-- a typed code to the server, which checks it.
create policy "owner manages codes" on public.promo_codes
  for all to authenticated using (public.is_owner()) with check (public.is_owner());
revoke all on public.promo_codes from anon, authenticated;
grant select, insert, update, delete on public.promo_codes to authenticated;
grant select, update on public.promo_codes to service_role;

-- ------------------------------------------------------------------ payments

alter table public.payments
  add column tier text,
  add column code text,
  -- The price before the discount (smallest unit), for the records.
  add column full_amount bigint;
-- A 100% code makes a payment of nothing.
alter table public.payments drop constraint payments_amount_check;
alter table public.payments add constraint payments_amount_check check (amount >= 0);

-- SERVER ONLY. What a tier costs for a period, with a code applied. The
-- one place prices are worked out. "ok" false comes with a sentence for
-- the user in "message".
create function public.quote_payment(want_tier text, want_period text, want_code text default '')
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  t public.tiers%rowtype;
  c public.promo_codes%rowtype;
  currency text := upper(coalesce((select value #>> '{}' from public.app_config where key = 'premium_currency'), 'KES'));
  full_price numeric;
  percent integer := 0;
  typed text := upper(regexp_replace(coalesce(want_code, ''), '\s', '', 'g'));
  code_message text := '';
begin
  select * into t from public.tiers where id = want_tier and active;
  if not found then
    return jsonb_build_object('ok', false, 'message', 'That plan is not on sale.');
  end if;
  full_price := case want_period when 'month' then t.price_month when 'year' then t.price_year end;
  if full_price is null then
    return jsonb_build_object('ok', false, 'message', 'That plan is not on sale.');
  end if;

  if typed <> '' then
    select * into c from public.promo_codes where code = typed;
    if not found or not c.active then
      code_message := 'That code is not valid.';
    elsif c.expires_at is not null and c.expires_at <= now() then
      code_message := 'That code has expired.';
    elsif c.max_uses is not null and c.used >= c.max_uses then
      code_message := 'That code has been used up.';
    elsif c.tier is not null and c.tier <> t.id then
      code_message := 'That code is for a different plan.';
    else
      percent := c.percent_off;
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'tier', t.id, 'tier_name', t.name, 'period', want_period,
    'days', case want_period when 'month' then 30 else 365 end,
    'currency', currency,
    'full_price', full_price,
    'price', round(full_price * (100 - percent) / 100.0, 2),
    'percent_off', percent,
    'code', case when percent > 0 then typed else '' end,
    'code_message', code_message
  );
end;
$$;
revoke execute on function public.quote_payment(text, text, text) from public, anon, authenticated;
grant execute on function public.quote_payment(text, text, text) to service_role;

-- SERVER ONLY (replaces part 9's). As before, plus: the account moves to
-- the tier that was bought, and a code that was used is counted.
create or replace function public.apply_payment(
  pay_reference text, paid_amount bigint, paid_currency text, pay_channel text default ''
) returns text
language plpgsql security definer set search_path = public as $$
declare
  p public.payments%rowtype;
begin
  select * into p from public.payments where reference = pay_reference for update;
  if not found then return 'unknown'; end if;
  if p.status = 'paid' then return 'paid'; end if;

  if upper(coalesce(paid_currency, '')) <> upper(p.currency) or coalesce(paid_amount, 0) < p.amount then
    update public.payments
      set status = 'failed',
          note = format('Expected %s %s, received %s %s', p.amount, p.currency, paid_amount, paid_currency)
      where id = p.id;
    return 'failed';
  end if;

  update public.payments
    set status = 'paid', paid_at = now(), channel = left(coalesce(pay_channel, ''), 40), note = ''
    where id = p.id;
  if p.code is not null then
    update public.promo_codes set used = used + 1 where code = p.code;
  end if;

  if p.user_id is not null then
    update public.profiles set
      -- Premium with no end date stays that way. Otherwise the days are
      -- added to what is left, or start now if nothing is left.
      plan_expires_at = case
        when plan = 'premium' and plan_expires_at is null then null
        else greatest(coalesce(case when plan = 'premium' then plan_expires_at end, now()), now())
             + make_interval(days => p.days)
      end,
      plan = 'premium',
      -- The tier bought last is the tier the account is on.
      tier = coalesce((select id from public.tiers where id = p.tier), tier)
    where id = p.user_id;
  end if;
  return 'paid';
end;
$$;
revoke execute on function public.apply_payment(text, bigint, text, text) from public, anon, authenticated;
grant execute on function public.apply_payment(text, bigint, text, text) to service_role;

-- ------------------------------------------------------------------- admin

drop function public.admin_list_payments(integer);
create function public.admin_list_payments(max_rows integer default 300)
returns table (
  id bigint, created_at timestamptz, paid_at timestamptz, email text, tier text, tier_name text,
  plan text, days integer, amount bigint, full_amount bigint, code text, currency text,
  status text, channel text, note text, reference text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return query
    select p.id, p.created_at, p.paid_at, u.email::text, p.tier, coalesce(t.name, p.tier, 'Premium'),
           p.plan, p.days, p.amount, p.full_amount, p.code, p.currency,
           p.status, p.channel, p.note, p.reference
    from public.payments p
    left join auth.users u on u.id = p.user_id
    left join public.tiers t on t.id = p.tier
    order by p.created_at desc
    limit least(greatest(max_rows, 1), 1000);
end;
$$;
revoke execute on function public.admin_list_payments(integer) from public, anon;
grant execute on function public.admin_list_payments(integer) to authenticated;

create or replace function public.admin_payment_totals(days integer default 30)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(days, 1), 3660));
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return jsonb_build_object(
    'paid', (select count(*) from public.payments where status = 'paid' and paid_at >= since),
    'pending', (select count(*) from public.payments where status = 'pending' and created_at >= since),
    'failed', (select count(*) from public.payments where status = 'failed' and created_at >= since),
    'buyers', (select count(distinct user_id) from public.payments where status = 'paid' and paid_at >= since),
    'premium_users', (select count(*) from public.profiles
                      where plan = 'premium' and (plan_expires_at is null or plan_expires_at > now())),
    'expiring_soon', (select count(*) from public.profiles
                      where plan = 'premium' and plan_expires_at between now() and now() + interval '7 days'),
    'income', coalesce((
      select jsonb_agg(row_to_json(x)) from (
        select currency, sum(amount) as amount, count(*) as payments
        from public.payments where status = 'paid' and paid_at >= since and amount > 0
        group by currency order by sum(amount) desc
      ) x), '[]'::jsonb),
    'by_tier', coalesce((
      select jsonb_agg(row_to_json(x)) from (
        select coalesce(t.name, p.tier, 'Premium') as tier, p.plan as period, p.currency,
               count(*) as payments, sum(p.amount) as amount
        from public.payments p left join public.tiers t on t.id = p.tier
        where p.status = 'paid' and p.paid_at >= since
        group by 1, 2, 3 order by sum(p.amount) desc
      ) x), '[]'::jsonb),
    'by_channel', coalesce((
      select jsonb_agg(row_to_json(x)) from (
        select case when amount = 0 then 'code (free)' else nullif(channel, '') end as channel, count(*) as payments
        from public.payments where status = 'paid' and paid_at >= since
        group by 1 order by count(*) desc
      ) x), '[]'::jsonb),
    'members', coalesce((
      select jsonb_agg(row_to_json(x)) from (
        select coalesce(t.name, 'Premium (by hand)') as tier, count(*) as accounts
        from public.profiles p left join public.tiers t on t.id = p.tier
        where p.plan = 'premium' and (p.plan_expires_at is null or p.plan_expires_at > now())
        group by 1 order by count(*) desc
      ) x), '[]'::jsonb)
  );
end;
$$;
