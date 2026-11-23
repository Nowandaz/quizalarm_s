-- BrainWake database, part 22: messages from the team to the app's users.
--
-- An admin writes a short message on the admin site ("Pharmacology topics
-- uploaded"). The app picks up new ones when it is next opened (or when
-- an alarm wakes it), shows a notification and keeps them in a list.

create table public.announcements (
  id           bigint generated always as identity primary key,
  title        text not null check (length(trim(title)) between 1 and 70),
  body         text not null default '' check (length(body) <= 400),
  -- Who gets it: everyone, or only people at one level.
  audience     text not null default 'all' check (audience in ('all', 'guest', 'free', 'paid')),
  -- An optional web address the message opens.
  link         text not null default '' check (link = '' or link ~ '^https://'),
  published_at timestamptz not null default now(),
  -- After this moment the app stops showing it (empty: never).
  expires_at   timestamptz,
  created_by   uuid references auth.users (id) on delete set null default auth.uid()
);
create index announcements_time_idx on public.announcements (published_at desc);

alter table public.announcements enable row level security;
create policy "anyone reads announcements" on public.announcements
  for select to anon, authenticated using (true);
create policy "admins manage announcements" on public.announcements
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.announcements to anon;
grant select, insert, update, delete on public.announcements to authenticated;
