-- BrainWake database, part 27: the iPhone waiting list.
--
-- The home page says the iPhone app is coming and takes an email address
-- from anyone who wants to be told. Visitors can only ADD an address
-- (through the function below); only admins can read the list. The owner
-- can write to it from the admin site's Emails page.

create table public.ios_waitlist (
  email text primary key check (email = lower(email) and length(email) between 5 and 200),
  created_at timestamptz not null default now()
);
alter table public.ios_waitlist enable row level security;
create policy "admins read the iphone waitlist" on public.ios_waitlist
  for select to authenticated using (public.is_admin());
create policy "admins remove from the iphone waitlist" on public.ios_waitlist
  for delete to authenticated using (public.is_admin());

-- Adds an address. True when it is on the list afterwards (also when it
-- already was), false when it is not an email address.
create function public.join_ios_waitlist(address text) returns boolean
language plpgsql security definer set search_path = public as $$
declare clean text := lower(trim(coalesce(address, '')));
begin
  if clean !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' or length(clean) > 200 then
    return false;
  end if;
  -- A brake on someone filling the list with rubbish.
  if (select count(*) from ios_waitlist) >= 20000 then return false; end if;
  insert into ios_waitlist (email) values (clean) on conflict do nothing;
  return true;
end;
$$;
revoke all on function public.join_ios_waitlist(text) from public;
grant execute on function public.join_ios_waitlist(text) to anon, authenticated;

-- The Emails page can write to the list: audience 'waitlist'.
create or replace function public.email_recipients(audience text, app_version text default '')
returns table (user_id uuid, email text)
language sql stable security definer set search_path = public as $$
  with newest as (
    select version_parts(version) as parts from app_releases order by published_at desc limit 1
  ),
  phones as (
    -- The version of each account's most recently used phone.
    select distinct on (i.user_id) i.user_id, i.version
    from app_installs i where i.user_id is not null
    order by i.user_id, i.last_seen desc
  ),
  accounts as (
    select u.id, u.email::text as email
    from auth.users u
    join profiles p on p.id = u.id
    left join phones ph on ph.user_id = u.id
    where u.email is not null and u.email_confirmed_at is not null and p.email_updates
      and case audience
        when 'all' then true
        when 'free' then not (p.plan = 'premium' and (p.plan_expires_at is null or p.plan_expires_at > now()))
        when 'paid' then p.plan = 'premium' and (p.plan_expires_at is null or p.plan_expires_at > now())
        when 'version' then ph.version is not null
          and version_parts(ph.version) = version_parts(app_version)
        when 'older' then ph.version is not null
          and version_parts(ph.version) < (select parts from newest)
        else false
      end
  )
  select id, email from accounts
  union all
  select null::uuid, w.email from ios_waitlist w where audience = 'waitlist'
  order by 2;
$$;
revoke all on function public.email_recipients(text, text) from public, anon, authenticated;
grant execute on function public.email_recipients(text, text) to service_role;
