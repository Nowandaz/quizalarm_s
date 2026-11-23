-- BrainWake database, part 17: versions of the app people can download.
--
-- The owner lists each new version here (on the admin site): its number,
-- where the install file is, and what is new. The home page reads the
-- newest one for its Download button, and the app reads it to tell people
-- when an update is out.

create table public.app_releases (
  id           bigint generated always as identity primary key,
  -- As in the app's own version, e.g. "1.0.1" (without the "+build" part).
  version      text not null unique check (version ~ '^[0-9]+(\.[0-9]+){1,3}$'),
  -- Where the install file (APK) is. Must be a web address people can open.
  url          text not null check (url ~ '^https://'),
  size_mb      numeric(6, 1) check (size_mb is null or size_mb > 0),
  -- One or two sentences on what changed; shown on the home page and in the app.
  notes        text not null default '' check (length(notes) <= 600),
  published_at timestamptz not null default now()
);

alter table public.app_releases enable row level security;
create policy "anyone reads releases" on public.app_releases
  for select to anon, authenticated using (true);
create policy "owner manages releases" on public.app_releases
  for all to authenticated using (public.is_owner()) with check (public.is_owner());
grant select on public.app_releases to anon;
grant select, insert, update, delete on public.app_releases to authenticated;
