-- BrainWake database: the owner role and what the admin website needs.
--
-- Roles now are:
--   user    an ordinary app user
--   admin   manages the question bank (units, topics, questions, pictures)
--   owner   everything an admin can do, plus: see and manage accounts,
--           roles and plans, read usage, change server settings and keys
--
-- Everything owner-only goes through the admin_* functions below, which
-- check the caller before doing anything.

alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role in ('user', 'admin', 'owner'));

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'owner')
  );
$$;

create function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'owner'
  );
$$;

-- Role and plan changes: only an owner, the server, or one of the admin_*
-- functions below (which set app.role_guard_off for their own transaction
-- after checking the caller).
create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role
      or new.plan is distinct from old.plan
      or new.plan_expires_at is distinct from old.plan_expires_at)
     and auth.uid() is not null
     and coalesce(current_setting('app.role_guard_off', true), '') <> 'on'
     and not public.is_owner() then
    raise exception 'Only the owner can change a role or plan';
  end if;
  return new;
end;
$$;

-- The very first owner: whoever is signed in can claim it, but only while
-- no owner exists. After that this does nothing.
create function public.claim_owner() returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  -- One claim at a time, so two people cannot both win.
  perform pg_advisory_xact_lock(hashtext('claim_owner'));
  if exists (select 1 from public.profiles where role = 'owner') then
    return false;
  end if;
  perform set_config('app.role_guard_off', 'on', true);
  update public.profiles set role = 'owner' where id = auth.uid();
  return found;
end;
$$;

create function public.owner_exists() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where role = 'owner');
$$;

-- ------------------------------------------------------- owner: accounts

create function public.admin_list_users(
  search text default '', max_rows integer default 100, skip integer default 0
) returns table (
  id uuid, email text, display_name text, role text, plan text,
  plan_expires_at timestamptz, created_at timestamptz,
  last_sign_in_at timestamptz, answers bigint, ai_calls bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  return query
    select p.id, u.email::text, p.display_name, p.role, p.plan,
           p.plan_expires_at, u.created_at, u.last_sign_in_at,
           (select count(*) from public.user_attempts a where a.user_id = p.id),
           (select count(*) from public.ai_usage g where g.user_id = p.id)
    from public.profiles p
    join auth.users u on u.id = p.id
    where search = ''
       or u.email ilike '%' || search || '%'
       or p.display_name ilike '%' || search || '%'
    order by u.created_at desc
    limit greatest(1, least(max_rows, 500)) offset greatest(0, skip);
end;
$$;

create function public.admin_set_role(target uuid, new_role text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  if new_role not in ('user', 'admin', 'owner') then
    raise exception 'Unknown role %', new_role;
  end if;
  -- There must always be an owner left.
  if new_role <> 'owner'
     and (select role from public.profiles where id = target) = 'owner'
     and (select count(*) from public.profiles where role = 'owner') <= 1 then
    raise exception 'This is the only owner; make someone else an owner first';
  end if;
  perform set_config('app.role_guard_off', 'on', true);
  update public.profiles set role = new_role where id = target;
end;
$$;

create function public.admin_set_plan(
  target uuid, new_plan text, expires timestamptz default null
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
        plan_expires_at = case when new_plan = 'premium' then expires end
    where id = target;
end;
$$;

-- Deletes an account and everything that belongs to it.
create function public.admin_delete_user(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  if target = auth.uid() then
    raise exception 'You cannot delete your own account here';
  end if;
  if (select role from public.profiles where id = target) = 'owner' then
    raise exception 'Remove the owner role from this account first';
  end if;
  delete from auth.users where id = target;
end;
$$;

-- Numbers for the dashboard.
create function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  return jsonb_build_object(
    'units',      (select count(*) from public.units where deleted_at is null),
    'topics',     (select count(*) from public.topics where deleted_at is null),
    'questions',  (select count(*) from public.questions where deleted_at is null),
    'drafts',     (select count(*) from public.questions
                   where deleted_at is null and status = 'draft'),
    'with_pictures', (select count(*) from public.questions
                      where deleted_at is null and image_path <> ''),
    'users',      (select count(*) from public.profiles),
    'premium_users', (select count(*) from public.profiles
                      where plan = 'premium'
                        and (plan_expires_at is null or plan_expires_at > now())),
    'answers_7d', (select count(*) from public.user_attempts
                   where answered_at > now() - interval '7 days'),
    'active_users_7d', (select count(distinct user_id) from public.user_attempts
                        where answered_at > now() - interval '7 days'),
    'ai_calls_today', (select count(*) from public.ai_usage
                       where created_at > date_trunc('day', now()))
  );
end;
$$;

-- The owner may read everyone's activity (support, statistics).
create policy "owner reads all sessions" on public.user_sessions
  for select to authenticated using (public.is_owner());
create policy "owner reads all attempts" on public.user_attempts
  for select to authenticated using (public.is_owner());
create policy "owner reads all AI questions" on public.user_questions
  for select to authenticated using (public.is_owner());
create policy "owner reads all AI usage" on public.ai_usage
  for select to authenticated using (public.is_owner());

-- Profile edits: your own name, or anything if you are the owner.
drop policy "update own profile, admins update all" on public.profiles;
create policy "update own profile, owner updates all" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_owner())
  with check (id = auth.uid() or public.is_owner());

-- ------------------------------------------------------- server settings

-- Settings the app and the API read (not secret): AI limits, model name...
create table public.app_config (
  key        text primary key,
  value      jsonb not null,
  note       text not null default '',
  updated_at timestamptz not null default now()
);
create trigger app_config_touch before update on public.app_config
  for each row execute function public.touch_updated_at();
alter table public.app_config enable row level security;
create policy "anyone reads settings" on public.app_config
  for select to anon, authenticated using (true);
create policy "owner changes settings" on public.app_config
  for all to authenticated
  using (public.is_owner()) with check (public.is_owner());
grant select on public.app_config to anon;
grant select, insert, update, delete on public.app_config to authenticated;

insert into public.app_config (key, value, note) values
  ('ai_daily_limit_free',    '20',  'AI calls a free user may make per day'),
  ('ai_daily_limit_premium', '200', 'AI calls a premium user may make per day'),
  ('ai_model',               '"gemini-3.5-flash"', 'Gemini model the server uses'),
  ('ai_enabled',             'true', 'Switch all AI features on or off');

-- Secrets (the Gemini key...). Nobody can read this table through the app
-- or the website: there is no read rule at all. The owner can only SET a
-- value; the API server reads it with the service key.
create table public.server_secrets (
  name       text primary key,
  value      text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);
alter table public.server_secrets enable row level security;
revoke all on public.server_secrets from anon, authenticated;

create function public.admin_set_secret(secret_name text, secret_value text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  if length(trim(secret_value)) = 0 then
    delete from public.server_secrets where name = secret_name;
  else
    insert into public.server_secrets (name, value, updated_by)
    values (secret_name, trim(secret_value), auth.uid())
    on conflict (name) do update
      set value = excluded.value, updated_at = now(), updated_by = auth.uid();
  end if;
end;
$$;

-- Whether each secret is set, when, and its last 4 characters. Never the value.
create function public.admin_secret_status()
returns table (name text, updated_at timestamptz, ending text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  return query
    select s.name, s.updated_at, right(s.value, 4) from public.server_secrets s;
end;
$$;

-- These functions check the caller themselves; visitors cannot call them.
revoke execute on function
  public.claim_owner(), public.admin_list_users(text, integer, integer),
  public.admin_set_role(uuid, text), public.admin_set_plan(uuid, text, timestamptz),
  public.admin_delete_user(uuid), public.admin_stats(),
  public.admin_set_secret(text, text), public.admin_secret_status()
  from public, anon;
grant execute on function
  public.claim_owner(), public.admin_list_users(text, integer, integer),
  public.admin_set_role(uuid, text), public.admin_set_plan(uuid, text, timestamptz),
  public.admin_delete_user(uuid), public.admin_stats(),
  public.admin_set_secret(text, text), public.admin_secret_status()
  to authenticated;
grant execute on function public.owner_exists() to anon, authenticated;
