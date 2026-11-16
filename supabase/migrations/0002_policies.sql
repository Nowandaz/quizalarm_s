-- BrainWake database: who may do what (row level security).
--
-- Summary
--   Question bank   anyone (even without an account) can READ published
--                   questions; only admins can add, change or remove.
--   Profiles        you read and edit your own; admins read all.
--   User data       you see and change only your own rows.
--   AI usage        you can read your own; only the server writes.
--
-- "The server" means the BrainWake API using the service key, which
-- bypasses these rules. That key never leaves the server.

alter table public.profiles      enable row level security;
alter table public.units         enable row level security;
alter table public.topics        enable row level security;
alter table public.questions     enable row level security;
alter table public.user_sessions enable row level security;
alter table public.user_attempts enable row level security;
alter table public.user_backups  enable row level security;
alter table public.ai_usage      enable row level security;

-- ----------------------------------------------------------------- profiles
create policy "read own profile, admins read all" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

create policy "update own profile, admins update all" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
-- (Changing "role" is additionally blocked by the protect_profile_role trigger.)

-- ------------------------------------------------------------ question bank
-- Deleted rows stay readable on purpose: that is how a phone learns that
-- something was removed. Drafts are visible to admins only.
create policy "anyone reads units" on public.units
  for select to anon, authenticated using (true);
create policy "admins manage units" on public.units
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "anyone reads topics" on public.topics
  for select to anon, authenticated using (true);
create policy "admins manage topics" on public.topics
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "anyone reads published questions" on public.questions
  for select to anon, authenticated
  using (status = 'published' or public.is_admin());
create policy "admins manage questions" on public.questions
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------- user data
create policy "own sessions" on public.user_sessions
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own attempts" on public.user_attempts
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own backup" on public.user_backups
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "read own ai usage" on public.ai_usage
  for select to authenticated
  using (user_id = auth.uid());
-- No insert/update/delete policy: only the server can write ai_usage.

-- ------------------------------------------------------------------- grants
grant usage on schema public to anon, authenticated;
grant select on public.units, public.topics, public.questions to anon;
grant select, insert, update, delete on
  public.units, public.topics, public.questions,
  public.user_sessions, public.user_attempts, public.user_backups
  to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.ai_usage to authenticated;
