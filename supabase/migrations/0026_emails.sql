-- BrainWake database, part 26: emails from the owner to people with accounts.
--
-- The owner writes an email on the admin site ("version 1.0.2 is out");
-- the API sends it, branded, through the same mailbox that sends the
-- sign-in emails. Here: who may be written to, a record of each sending,
-- and a way for someone to stop receiving them.

-- False once someone has unsubscribed. Sign-in emails are not affected.
alter table public.profiles add column email_updates boolean not null default true;

-- One row per email sent out. Written by the API, read by admins.
create table public.email_campaigns (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  subject text not null,
  body text not null,
  button_text text not null default '',
  button_url text not null default '',
  audience text not null,
  app_version text not null default '',
  total integer not null default 0,
  sent integer not null default 0,
  failed integer not null default 0,
  status text not null default 'sending' check (status in ('sending', 'done', 'stopped')),
  error text not null default ''
);
alter table public.email_campaigns enable row level security;
create policy "admins read email campaigns" on public.email_campaigns
  for select to authenticated using (public.is_admin());

-- "1.0.10+3" -> {1,0,10}, so versions compare by their numbers.
create function public.version_parts(v text) returns integer[]
language sql immutable as $$
  select coalesce(array_agg(coalesce(nullif(regexp_replace(p, '\D', '', 'g'), ''), '0')::integer order by n), '{}')
  from unnest(string_to_array(split_part(coalesce(v, ''), '+', 1), '.')) with ordinality as t(p, n);
$$;

-- The accounts an email goes to. Only confirmed addresses, and never
-- someone who unsubscribed.
--   all      every account
--   free     accounts without a paid plan
--   paid     accounts on Pro or Ultra
--   version  accounts whose phone runs the given app version (e.g. 1.0.0)
--   older    accounts whose phone runs a version older than the newest listed
-- A phone counts by the version it last reported; an account that never
-- used the app signed in is only in all / free / paid.
create function public.email_recipients(audience text, app_version text default '')
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
  )
  select u.id, u.email::text
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
  order by u.email;
$$;
revoke all on function public.email_recipients(text, text) from public, anon, authenticated;
grant execute on function public.email_recipients(text, text) to service_role;

-- For the admin site: how many people an email would reach.
create function public.admin_email_count(audience text, app_version text default '') returns integer
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admins only'; end if;
  return (select count(*) from email_recipients(audience, app_version));
end;
$$;
revoke all on function public.admin_email_count(text, text) from public, anon;
grant execute on function public.admin_email_count(text, text) to authenticated;

-- For the admin site: the app versions accounts' phones are on.
create function public.admin_email_versions() returns table (version text, accounts integer)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admins only'; end if;
  return query
    select split_part(i.version, '+', 1), count(distinct i.user_id)::integer
    from app_installs i where i.user_id is not null and i.version <> ''
    group by 1 order by version_parts(split_part(i.version, '+', 1)) desc;
end;
$$;
revoke all on function public.admin_email_versions() from public, anon;
grant execute on function public.admin_email_versions() to authenticated;
