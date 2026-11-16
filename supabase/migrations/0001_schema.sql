-- BrainWake database: tables.
--
-- Three groups:
--   1. Accounts       profiles (one row per signed-in person; says who is an admin)
--   2. Question bank  units -> topics -> questions (managed on the admin website)
--   3. User data      attempts, sessions, a backup of alarms/settings, AI usage
--
-- Who may read or change what is in 0002_policies.sql.

-- ---------------------------------------------------------------- accounts

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  -- 'user' or 'admin'. Only an admin (or the server) can change it.
  role         text not null default 'user' check (role in ('user', 'admin')),
  -- Paid features: 'free' or 'premium', and when premium runs out (null =
  -- no end date). Set by the server when a payment is confirmed; a user
  -- cannot change their own.
  plan            text not null default 'free' check (plan in ('free', 'premium')),
  plan_expires_at timestamptz,
  created_at   timestamptz not null default now()
);

-- Every new account gets a profile automatically.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- True when the person making the request is an admin.
create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- True when the person making the request has a premium plan that has not
-- run out.
create function public.has_premium() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and plan = 'premium'
      and (plan_expires_at is null or plan_expires_at > now())
  );
$$;

-- Nobody can make themselves an admin or give themselves premium: those
-- changes need an admin, or the server (which has no signed-in user).
create function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role
      or new.plan is distinct from old.plan
      or new.plan_expires_at is distinct from old.plan_expires_at)
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'Only an admin can change a role or plan';
  end if;
  return new;
end;
$$;

create trigger profiles_protect_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();

-- ----------------------------------------------------------- question bank

-- Keeps updated_at current, so the app can ask "what changed since my
-- last download?".
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.units (
  id          text primary key,            -- short stable id, e.g. 'pharmacology'
  name        text not null,
  description text not null default '',
  sort_order  integer not null default 0,
  -- A premium unit's questions are only given to signed-in users with a
  -- premium plan. Its name still shows to everyone, so the app can offer it.
  premium     boolean not null default false,
  -- Rows are never removed, only marked, so phones learn about deletions.
  deleted_at  timestamptz,
  updated_at  timestamptz not null default now()
);

create table public.topics (
  id          text primary key,            -- e.g. 'pharm-antimicrobials'
  unit_id     text not null references public.units (id) on delete cascade,
  name        text not null,
  sort_order  integer not null default 0,
  deleted_at  timestamptz,
  updated_at  timestamptz not null default now()
);
create index topics_unit_idx on public.topics (unit_id);

create table public.questions (
  id          text primary key,
  topic_id    text not null references public.topics (id) on delete cascade,
  type        text not null check (type in ('mcq', 'saq')),
  text        text not null check (length(trim(text)) > 0),
  -- Multiple choice: exactly 5 options. Short answer: none.
  options     jsonb not null default '[]'::jsonb,
  answer      text not null check (length(trim(answer)) > 0),
  -- Other spellings / names accepted for typed answers.
  alt_answers jsonb not null default '[]'::jsonb,
  explanation text not null default '',
  -- Picture for spotter questions: a path inside the 'question-images'
  -- storage bucket, or empty.
  image_path  text not null default '',
  -- Where it came from: written by an admin, imported from the app's
  -- bundled files, or written by the AI at an admin's request.
  source      text not null default 'admin' check (source in ('admin', 'seed', 'ai')),
  -- Drafts are questions an admin is still working on; they are hidden
  -- from the app until published.
  status      text not null default 'published' check (status in ('draft', 'published')),
  created_by  uuid references auth.users (id) on delete set null,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint questions_options_shape check (
    jsonb_typeof(options) = 'array'
    and jsonb_typeof(alt_answers) = 'array'
    and (
      (type = 'saq' and jsonb_array_length(options) = 0)
      or (type = 'mcq' and jsonb_array_length(options) = 5 and options ? answer)
    )
  )
);
create index questions_topic_idx   on public.questions (topic_id);
create index questions_updated_idx on public.questions (updated_at);

create trigger units_touch     before update on public.units
  for each row execute function public.touch_updated_at();
create trigger topics_touch    before update on public.topics
  for each row execute function public.touch_updated_at();
create trigger questions_touch before update on public.questions
  for each row execute function public.touch_updated_at();

-- --------------------------------------------------------------- user data

-- One row per alarm ring or practice session. The id is made on the phone,
-- so uploading the same session twice changes nothing.
create table public.user_sessions (
  id              uuid primary key,
  user_id         uuid not null references auth.users (id) on delete cascade,
  kind            text not null check (kind in ('alarm', 'bank', 'revision')),
  title           text not null default '',
  required_streak integer,
  started_at      timestamptz not null,
  ended_at        timestamptz,
  outcome         text check (outcome in ('dismissed', 'snoozed', 'finished'))
);
create index user_sessions_user_idx on public.user_sessions (user_id, started_at desc);

-- Questions the AI wrote for one user. They go straight to that user (no
-- review) and belong only to them; saving them here lets them follow the
-- user to a new phone. Same shape as a shared question.
create table public.user_questions (
  id          text not null,                -- made on the phone, e.g. 'ai_...'
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- The shared topic it was written for, if that topic still exists.
  topic_id    text references public.topics (id) on delete set null,
  -- The topic's name, kept so the question still has a home if the user
  -- made the topic themselves (those exist only on their phone).
  topic_name  text not null default '',
  type        text not null check (type in ('mcq', 'saq')),
  text        text not null check (length(trim(text)) > 0),
  options     jsonb not null default '[]'::jsonb,
  answer      text not null check (length(trim(answer)) > 0),
  alt_answers jsonb not null default '[]'::jsonb,
  explanation text not null default '',
  created_at  timestamptz not null default now(),
  primary key (user_id, id),
  constraint user_questions_shape check (
    jsonb_typeof(options) = 'array' and jsonb_typeof(alt_answers) = 'array'
  )
);

-- Every answer a user gave. client_id is made on the phone for the same
-- reason as above. question_id is a shared question's id or one of the
-- user's own, so it is not tied to either table.
create table public.user_attempts (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  client_id   uuid not null,
  question_id text not null,
  session_id  uuid references public.user_sessions (id) on delete set null,
  mode        text not null,
  correct     boolean not null,
  user_answer text not null default '',
  duration_ms integer,
  answered_at timestamptz not null,
  unique (user_id, client_id)
);
create index user_attempts_user_idx on public.user_attempts (user_id, answered_at desc);

-- Backup of a user's alarms and app settings, as one document, so a new
-- phone can restore them.
create table public.user_backups (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  alarms     jsonb not null default '[]'::jsonb,
  settings   jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create trigger user_backups_touch before update on public.user_backups
  for each row execute function public.touch_updated_at();

-- One row per AI call, written by the server only. Used to limit how much
-- AI each person can use per day.
create table public.ai_usage (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('generate', 'feedback', 'grade')),
  created_at timestamptz not null default now()
);
create index ai_usage_user_idx on public.ai_usage (user_id, created_at desc);
