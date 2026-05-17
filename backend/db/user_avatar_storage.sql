-- Avatar upload setup for bucket `Image`
-- Storage path convention used by the app:
--   Avatar/<user_id>/avatar_<timestamp>.<ext>

insert into storage.buckets (id, name, public)
values ('Image', 'Image', false)
on conflict (id) do nothing;

create policy "Authenticated users can read own avatar objects"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "Authenticated users can upload own avatar objects"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "Authenticated users can update own avatar objects"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
  and (storage.foldername(name))[2] = auth.uid()::text
)
with check (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "Authenticated users can delete own avatar objects"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
  and (storage.foldername(name))[2] = auth.uid()::text
);
