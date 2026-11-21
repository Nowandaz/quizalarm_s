-- BrainWake database, part 9: paying for premium (through Paystack).
--
-- How a payment goes:
--   1. The app asks the API server to start one. The server writes a
--      "pending" row here with the price it expects, and asks Paystack for
--      a payment page.
--   2. The user pays on Paystack's page (card or mobile money).
--   3. Paystack tells the server. The server calls apply_payment, which
--      checks the amount against the row and, if right, marks it paid and
--      adds the days to the user's premium plan.
-- A phone can read its own payments but never write one: only the server
-- can, so nobody can give themselves premium.
--
-- What is sold is premium TIME (30 or 365 days), paid once. Nothing renews
-- by itself; paying again adds more days.

create table public.payments (
  id         bigint generated always as identity primary key,
  -- Kept (with no user) if the account is deleted: it is a money record.
  user_id    uuid references auth.users (id) on delete set null,
  -- Made by the server, sent to Paystack, unique for ever.
  reference  text not null unique check (length(reference) between 8 and 80),
  plan       text not null check (plan in ('month', 'year')),
  days       integer not null check (days between 1 and 3660),
  -- In the currency's smallest unit (cents, kobo), as Paystack counts.
  amount     bigint not null check (amount > 0),
  currency   text not null check (length(currency) = 3),
  status     text not null default 'pending' check (status in ('pending', 'paid', 'failed')),
  channel    text not null default '',     -- card, mobile_money, ...
  note       text not null default '',     -- why it failed, if it did
  paid_at    timestamptz,
  created_at timestamptz not null default now()
);
create index payments_user_idx on public.payments (user_id, created_at desc);

alter table public.payments enable row level security;
create policy "read own payments, admins read all" on public.payments
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
revoke all on public.payments from anon, authenticated;
grant select on public.payments to authenticated;

-- Prices and the on/off switch, edited on the admin site.
insert into public.app_config (key, value, note) values
  ('payments_enabled',    'false', 'Let people buy premium in the app'),
  ('premium_currency',    '"KES"', 'Currency of the prices (as set up on Paystack): KES, NGN, GHS, ZAR or USD'),
  ('premium_price_month', '300',   'Price of 30 days of premium'),
  ('premium_price_year',  '2500',  'Price of 365 days of premium')
on conflict (key) do nothing;

-- SERVER ONLY. Called when Paystack reports a successful charge. Safe to
-- call twice for the same payment (Paystack repeats its messages): the
-- days are added once. Returns the payment's status afterwards.
create function public.apply_payment(
  pay_reference text, paid_amount bigint, paid_currency text, pay_channel text default ''
) returns text
language plpgsql security definer set search_path = public as $$
declare
  p public.payments%rowtype;
begin
  select * into p from public.payments where reference = pay_reference for update;
  if not found then return 'unknown'; end if;
  if p.status = 'paid' then return 'paid'; end if;

  -- The money must be what was asked for: a smaller amount, or another
  -- currency, buys nothing.
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

  if p.user_id is not null then
    update public.profiles set
      -- Premium with no end date stays that way. Otherwise the days are
      -- added to what is left, or start now if nothing is left.
      plan_expires_at = case
        when plan = 'premium' and plan_expires_at is null then null
        else greatest(coalesce(case when plan = 'premium' then plan_expires_at end, now()), now())
             + make_interval(days => p.days)
      end,
      plan = 'premium'
    where id = p.user_id;
  end if;
  return 'paid';
end;
$$;
revoke execute on function public.apply_payment(text, bigint, text, text) from public, anon, authenticated;
grant execute on function public.apply_payment(text, bigint, text, text) to service_role;
grant select, insert, update on public.payments to service_role;

-- ADMIN. Payments, newest first, with who paid.
create function public.admin_list_payments(max_rows integer default 200)
returns table (
  id bigint, created_at timestamptz, paid_at timestamptz, email text, plan text, days integer,
  amount bigint, currency text, status text, channel text, note text, reference text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return query
    select p.id, p.created_at, p.paid_at, u.email::text, p.plan, p.days,
           p.amount, p.currency, p.status, p.channel, p.note, p.reference
    from public.payments p
    left join auth.users u on u.id = p.user_id
    order by p.created_at desc
    limit least(greatest(max_rows, 1), 1000);
end;
$$;

-- ADMIN. Money in over the last [days] days, per currency.
create function public.admin_payment_totals(days integer default 30)
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
    'premium_users', (select count(*) from public.profiles
                      where plan = 'premium' and (plan_expires_at is null or plan_expires_at > now())),
    'income', coalesce((
      select jsonb_agg(row_to_json(t)) from (
        select currency, sum(amount) as amount, count(*) as payments
        from public.payments where status = 'paid' and paid_at >= since
        group by currency order by sum(amount) desc
      ) t), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.admin_list_payments(integer), public.admin_payment_totals(integer) from public, anon;
grant execute on function public.admin_list_payments(integer), public.admin_payment_totals(integer) to authenticated;
