-- Free-plan upload limits and publish validation for Idea Lab media.
-- Existing rows and already-published posts are not rewritten.
update storage.buckets
set file_size_limit = 50000000,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
where id = 'idea-media';

drop policy if exists "creators upload to own media folder" on storage.objects;
create policy "creators upload to own media folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('idea-media', 'idea-stories')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and name ~ ('^' || (select auth.uid())::text || '/[0-9a-fA-F-]{36}/[^/]+[.](jpg|jpeg|png|webp|mp4)$')
    and (
      nullif(metadata->>'mimetype', '') is null
      or metadata->>'mimetype' in ('image/jpeg', 'image/png', 'image/webp', 'video/mp4')
    )
    and (
      nullif(metadata->>'size', '') is null
      or (
        metadata->>'size' ~ '^[0-9]+$'
        and (metadata->>'size')::bigint > 0
        and (metadata->>'size')::bigint <= case
          when bucket_id = 'idea-media' and lower(name) ~ '\.mp4$' then 50000000
          when bucket_id = 'idea-media' then 20000000
          else 50000000
        end
      )
    )
    and (
      nullif(metadata->>'size', '') is not null
      or (bucket_id = 'idea-media' and lower(name) ~ '\.mp4$')
    )
  );

-- Cap the complete idea-media bucket usage per owner, including media staged
-- before a post row exists and files uploaded outside the normal composer.
create or replace function public.enforce_idea_media_owner_storage_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_folder text;
  incoming_bytes bigint;
  existing_bytes bigint;
begin
  if new.bucket_id <> 'idea-media' then
    return new;
  end if;
  owner_folder := (storage.foldername(new.name))[1];
  if owner_folder is null or new.metadata->>'size' !~ '^[0-9]+$' then
    return new;
  end if;
  incoming_bytes := (new.metadata->>'size')::bigint;
  perform pg_advisory_xact_lock(hashtext(owner_folder));
  select coalesce(sum(case
    when o.metadata->>'size' ~ '^[0-9]+$' then (o.metadata->>'size')::bigint
    else 0
  end), 0)
  into existing_bytes
  from storage.objects o
  where o.bucket_id = 'idea-media'
    and (storage.foldername(o.name))[1] = owner_folder
    and o.name <> new.name;
  if existing_bytes + incoming_bytes > 500000000 then
    raise exception 'Your Idea Lab media has reached the 500 MB storage safety cap. Remove older media before uploading more.';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_idea_media_owner_storage_cap() from public, anon, authenticated;
drop trigger if exists idea_media_owner_storage_cap on storage.objects;
create trigger idea_media_owner_storage_cap
  before insert or update of metadata on storage.objects
  for each row execute function public.enforce_idea_media_owner_storage_cap();

create or replace function public.validate_idea_post_publish()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  media_count integer;
  video_count integer;
  image_count integer;
  bad_media integer;
  total_bytes bigint;
  creator_total_bytes bigint;
  cover_count integer;
begin
  if new.published_at is not null and (tg_op = 'INSERT' or old.published_at is null) then
    select
      count(*),
      count(*) filter (where m.mime_type = 'video/mp4'),
      count(*) filter (where m.mime_type <> 'video/mp4'),
      count(*) filter (where
        m.storage_path not like new.creator_id::text || '/' || new.id::text || '/%' or
        not m.video_validated or
        (m.mime_type = 'video/mp4' and (m.width is null or m.height is null or m.height <= 0 or
          (m.width::numeric / m.height::numeric) < 0.5 or
          (m.width::numeric / m.height::numeric) > 2.4))
      ),
      coalesce(sum(case
        when o.metadata->>'size' ~ '^[0-9]+$'
          then (o.metadata->>'size')::bigint
        else 0
      end), 0),
      count(*) filter (where m.thumbnail_url is not null)
    into media_count, video_count, image_count, bad_media, total_bytes, cover_count
    from public.idea_post_media m
    left join storage.objects o on o.bucket_id = 'idea-media'
      and o.name in (m.storage_path, m.thumbnail_url)
    where m.post_id = new.id;

    if media_count < 1 then
      raise exception 'Upload and verify at least one media file before publishing.';
    end if;
    if media_count > 5 then
      raise exception 'A post can contain at most 5 photos.';
    end if;
    if video_count > 0 and (video_count <> 1 or image_count > 0) then
      raise exception 'Publish one video by itself, or publish photos without a video.';
    end if;
    if bad_media > 0 then
      raise exception 'A media file is missing, not verified, or has unsupported dimensions. Retry its upload or choose another file.';
    end if;
    if total_bytes > 100000000 then
      raise exception 'This post uses more than 100 MB. Remove or compress some media.';
    end if;
    if cover_count > 1 then
      raise exception 'A video post can have only one cover image.';
    end if;

    select coalesce(sum(case
      when o.metadata->>'size' ~ '^[0-9]+$'
        then (o.metadata->>'size')::bigint
      else 0
    end), 0)
    into creator_total_bytes
    from storage.objects o
    where o.bucket_id = 'idea-media'
      and (storage.foldername(o.name))[1] = new.creator_id::text;

    if creator_total_bytes > 500000000 then
      raise exception 'Your Idea Lab media has reached the 500 MB storage safety cap. Remove older media before publishing more.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.validate_idea_post_publish() from public, anon, authenticated;
drop trigger if exists idea_posts_validate_publish on public.idea_posts;
create trigger idea_posts_validate_publish
  before insert or update of published_at on public.idea_posts
  for each row execute function public.validate_idea_post_publish();
