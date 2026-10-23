-- Increase the Idea Lab media bucket ceiling for larger video uploads.
-- The project's global Storage limit and subscription plan remain authoritative.
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'idea-media') then
    raise exception 'The idea-media bucket is missing; create/repair Idea Lab storage before applying this migration.';
  end if;
end;
$$;

update storage.buckets
set file_size_limit = 157286400
where id = 'idea-media';

-- Keep the 50 MiB graphic/story policy while allowing MP4 videos up to 150 MiB.
drop policy if exists "creators upload to own media folder" on storage.objects;
create policy "creators upload to own media folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('idea-media', 'idea-stories')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and metadata->>'size' ~ '^[0-9]+$'
    and (metadata->>'size')::bigint > 0
    and (metadata->>'mimetype') in ('image/jpeg', 'image/png', 'image/webp', 'video/mp4')
    and (metadata->>'size')::bigint <= case
      when bucket_id = 'idea-media' and lower(name) ~ '\.mp4$' then 157286400
      else 52428800
    end
  );
