-- Add optional video poster paths while retaining existing posts unchanged.
-- Paths are stored in idea-media as <creator uid>/<post id>/<filename>.
alter table public.idea_post_media
  add column if not exists thumbnail_url text;

grant insert (post_id, storage_path, mime_type, position, thumbnail_url)
  on public.idea_post_media to authenticated;
grant update (thumbnail_url) on public.idea_post_media to authenticated;

create policy "creators replace own published video thumbnails"
  on public.idea_post_media for update to authenticated
  using (exists (
    select 1 from public.idea_posts p
    where p.id = post_id and p.creator_id = (select auth.uid())
  ))
  with check (
    mime_type = 'video/mp4'
    and thumbnail_url is not null
    and thumbnail_url ~ ('^' || (select auth.uid())::text || '/' || post_id::text || '/[^/]+[.](jpg|jpeg|png|webp)$')
    and exists (
      select 1 from public.idea_posts p
      where p.id = post_id and p.creator_id = (select auth.uid())
    )
  );

create or replace function public.validate_idea_video_thumbnail_path()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.mime_type = 'video/mp4' then
    if new.thumbnail_url is null or not exists (
      select 1 from public.idea_posts p
      where p.id = new.post_id
        and new.thumbnail_url ~ ('^' || p.creator_id::text || '/' || new.post_id::text || '/[^/]+[.](jpg|jpeg|png|webp)$')
    ) then
      raise exception 'A video post requires an image thumbnail in its own post folder.';
    end if;
  elsif new.thumbnail_url is not null then
    raise exception 'Only video posts may have a video thumbnail.';
  end if;
  return new;
end;
$$;
revoke all on function public.validate_idea_video_thumbnail_path() from public, anon, authenticated;
create trigger idea_post_media_validate_thumbnail
  before insert or update of mime_type, thumbnail_url
  on public.idea_post_media
  for each row execute function public.validate_idea_video_thumbnail_path();
