-- Accept common portrait, square, and landscape video exports.
-- Existing posts and media rows are untouched; this only changes validation
-- for posts published after deployment.
create or replace function public.validate_idea_post_publish()
returns trigger language plpgsql set search_path = '' as $$
declare bad_media integer;
begin
  if new.published_at is not null and (tg_op = 'INSERT' or old.published_at is null) then
    select count(*) filter (where
      storage_path not like new.creator_id::text || '/' || new.id::text || '/%' or
      not video_validated or
      (mime_type = 'video/mp4' and (width is null or height is null or height <= 0 or
       (width::numeric / height::numeric) < 0.5 or
       (width::numeric / height::numeric) > 2.4))
    ) into bad_media from public.idea_post_media where post_id = new.id;
    if bad_media > 0 or not exists (
      select 1 from public.idea_post_media where post_id = new.id
    ) then
      raise exception 'Post media is incomplete or failed server validation';
    end if;
  end if;
  return new;
end;
$$;
