-- Increase the per-post media ceiling without touching existing rows.
-- 250 is a generous safety ceiling; aggregate bytes remain limited to 200 MiB.
alter table public.idea_post_media
  drop constraint if exists idea_post_media_position_check;
alter table public.idea_post_media
  add constraint idea_post_media_position_check check (position between 0 and 249);

create or replace function public.validate_idea_post_publish()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  media_count integer;
  video_count integer;
  image_count integer;
  bad_media integer;
  total_bytes bigint;
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
      end), 0)
    into media_count, video_count, image_count, bad_media, total_bytes
    from public.idea_post_media m
    left join storage.objects o on o.bucket_id = 'idea-media'
      and o.name in (m.storage_path, m.thumbnail_url)
    where m.post_id = new.id;

    if media_count < 1 or media_count > 250 or
       (video_count > 0 and (video_count <> 1 or image_count > 0)) or
       bad_media > 0 or total_bytes > 209715200 or
       (select count(*) from public.idea_post_media m
          where m.post_id = new.id and m.thumbnail_url is not null) > 1 then
      raise exception 'Post media is incomplete, mixed, over the media limit, or failed server validation';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists idea_posts_validate_publish on public.idea_posts;
create trigger idea_posts_validate_publish
  before insert or update of published_at on public.idea_posts
  for each row execute function public.validate_idea_post_publish();

-- The privacy migration made idea-media private. Permit signed reads of video
-- posters under the same post visibility rule as their corresponding videos.
drop policy if exists "privacy reads Idea Lab media" on storage.objects;
create policy "privacy reads Idea Lab media" on storage.objects
  for select to anon, authenticated using (
    bucket_id = 'idea-media' and exists (
      select 1
      from public.idea_post_media m
      join public.idea_posts p on p.id = m.post_id
      where (m.storage_path = name or m.thumbnail_url = name)
        and (p.creator_id = (select auth.uid()) or public.idea_post_is_visible(p.id))
    )
  );
