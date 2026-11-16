-- BrainWake database: storage for question pictures.
--
-- One public bucket. Anyone can view a picture (the app shows them without
-- signing in); only admins can upload, replace or delete.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'question-images', 'question-images', true,
  5242880,                                    -- 5 MB per picture
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

create policy "anyone views question images" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'question-images');

create policy "admins upload question images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'question-images' and public.is_admin());

create policy "admins change question images" on storage.objects
  for update to authenticated
  using (bucket_id = 'question-images' and public.is_admin())
  with check (bucket_id = 'question-images' and public.is_admin());

create policy "admins delete question images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'question-images' and public.is_admin());
