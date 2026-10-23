-- Repair Idea Lab media upload RLS for resumable MP4 uploads.
-- Supabase Storage enforces the bucket's max size and allowed MIME types.
-- TUS initialization may not yet have a metadata.size field, so only MP4
-- uploads to idea-media may omit it; image uploads retain the 50 MiB check.
update storage.buckets
set file_size_limit = 157286400,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
where id = 'idea-media';

drop policy if exists "creators upload to own media folder" on storage.objects;
create policy "creators upload to own media folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('idea-media', 'idea-stories')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(name) ~ '\.(jpg|jpeg|png|webp|mp4)$'
    and (
      (metadata->>'mimetype') in ('image/jpeg', 'image/png', 'image/webp', 'video/mp4')
      or (bucket_id = 'idea-media' and lower(name) ~ '\.mp4$'
          and nullif(metadata->>'mimetype', '') is null)
    )
    and (
      (metadata->>'size' ~ '^[0-9]+$'
        and (metadata->>'size')::bigint > 0
        and (metadata->>'size')::bigint <= case
          when bucket_id = 'idea-media' and lower(name) ~ '\.mp4$' then 157286400
          else 52428800
        end)
      or (bucket_id = 'idea-media' and lower(name) ~ '\.mp4$'
          and nullif(metadata->>'size', '') is null)
    )
  );

-- A successful upload returns its new object row. Make sure an owner can read
-- that returned row even if the broader public-media policy is absent.
drop policy if exists "creators read own Idea Lab media objects" on storage.objects;
create policy "creators read own Idea Lab media objects"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'idea-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
