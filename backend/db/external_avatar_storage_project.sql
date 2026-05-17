-- Run this in the Storage project: rpvwneveukpsnxlvdsev
-- This setup is for client-side uploads from another Supabase project.
-- It is suitable for demo/internal use. For stronger security, move uploads
-- behind an Edge Function or backend that uses a service key.

insert into storage.buckets (id, name, public)
values ('Image', 'Image', true)
on conflict (id) do update set public = true;

create policy "Anon can upload avatar files"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
);

create policy "Anon can update avatar files"
on storage.objects
for update
to anon, authenticated
using (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
)
with check (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
);

create policy "Anon can delete avatar files"
on storage.objects
for delete
to anon, authenticated
using (
  bucket_id = 'Image'
  and (storage.foldername(name))[1] = 'Avatar'
);
