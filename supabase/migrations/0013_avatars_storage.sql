-- BrainWake database, part 13: profile pictures.
--
-- A private storage bucket. Each account may keep one picture at
-- "<its user id>/avatar.jpg" and is the only one who can read, replace or
-- delete it. (Storage only exists on Supabase, so the local test run
-- skips this file, like part 3.)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars', 'avatars', false,
  524288,                                     -- 512 KB: the app shrinks pictures first
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

create policy "see your own profile picture" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "add your own profile picture" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '/avatar.jpg');

create policy "replace your own profile picture" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '/avatar.jpg');

create policy "remove your own profile picture" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
