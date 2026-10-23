-- Allow arbitrarily many media records per post (individual object bucket limits still apply).
create or replace function public.validate_idea_post_publish()
returns trigger language plpgsql set search_path = '' as $$
declare bad_media integer;
begin
  if new.published_at is not null and (tg_op = 'INSERT' or old.published_at is null) then
    select count(*) filter (where
      storage_path not like new.creator_id::text || '/' || new.id::text || '/%' or
      not video_validated or
      (mime_type = 'video/mp4' and (width is null or height is null or
       (abs((width::numeric / height::numeric) - (16::numeric / 9)) > 0.005 and
        abs((width::numeric / height::numeric) - (9::numeric / 16)) > 0.005)))
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

create table if not exists public.idea_story_likes (
  story_id uuid not null references public.idea_stories(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);
create table if not exists public.idea_story_comments (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.idea_stories(id) on delete cascade,
  author_id uuid not null references public.idea_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists idea_story_comments_story_idx
  on public.idea_story_comments (story_id, created_at);

alter table public.idea_story_likes enable row level security;
alter table public.idea_story_comments enable row level security;
revoke all on public.idea_story_likes, public.idea_story_comments from anon, authenticated;
grant select, insert, delete on public.idea_story_likes to authenticated;
grant select, insert on public.idea_story_comments to authenticated;
create policy "likes visible on active stories" on public.idea_story_likes
  for select to authenticated using (exists (
    select 1 from public.idea_stories s where s.id = story_id
      and s.media_validated and s.expires_at > now()
  ));
create policy "users like active stories" on public.idea_story_likes
  for insert to authenticated with check (user_id = (select auth.uid()) and exists (
    select 1 from public.idea_stories s where s.id = story_id
      and s.media_validated and s.expires_at > now()
  ));
create policy "users remove own story likes" on public.idea_story_likes
  for delete to authenticated using (user_id = (select auth.uid()));
create policy "comments visible on active stories" on public.idea_story_comments
  for select to authenticated using (exists (
    select 1 from public.idea_stories s where s.id = story_id
      and s.media_validated and s.expires_at > now()
  ));
create policy "users comment on active stories" on public.idea_story_comments
  for insert to authenticated with check (author_id = (select auth.uid()) and exists (
    select 1 from public.idea_stories s where s.id = story_id
      and s.media_validated and s.expires_at > now()
  ));
