-- Fix false 403s for both resumable MP4 uploads and cover replacement.
-- Storage buckets enforce the actual allowed MIME types and the 150 MiB
-- idea-media / 50 MiB idea-stories byte ceiling. Some upload paths (notably
-- TUS initialization) have no size or mimetype metadata yet, so RLS must not
-- reject those rows solely for that. The media validator enforces the stricter
-- 50 MiB image and 2 MiB cover limits before a post is published.
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
    and name ~ ('^' || (select auth.uid())::text || '/[0-9a-fA-F-]{36}/[^/]+[.](jpg|jpeg|png|webp|mp4)$')
    and (nullif(metadata->>'mimetype', '') is null
      or metadata->>'mimetype' in ('image/jpeg', 'image/png', 'image/webp', 'video/mp4'))
    and (
      nullif(metadata->>'size', '') is null
      or (
        metadata->>'size' ~ '^[0-9]+$'
        and (metadata->>'size')::bigint > 0
        and (metadata->>'size')::bigint <= case
          when bucket_id = 'idea-media' and lower(name) ~ '\.mp4$' then 157286400
          else 52428800
        end
      )
    )
  );

drop policy if exists "creators read own Idea Lab media objects" on storage.objects;
create policy "creators read own Idea Lab media objects"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'idea-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
