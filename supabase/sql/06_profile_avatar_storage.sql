-- SMDN - Upload de foto de perfil via Supabase Storage
-- Rode no Supabase Dashboard > SQL Editor.
-- Cria o bucket público avatars e adiciona policies para usuários autenticados enviarem imagens.

alter table public."Perfis"
  add column if not exists prf_avatar_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars public read" on storage.objects;
create policy "avatars public read"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'avatars');

drop policy if exists "avatars authenticated insert" on storage.objects;
create policy "avatars authenticated insert"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'avatars');

drop policy if exists "avatars authenticated update" on storage.objects;
create policy "avatars authenticated update"
on storage.objects
for update
to authenticated
using (bucket_id = 'avatars')
with check (bucket_id = 'avatars');

drop policy if exists "avatars authenticated delete" on storage.objects;
create policy "avatars authenticated delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'avatars');

notify pgrst, 'reload schema';
