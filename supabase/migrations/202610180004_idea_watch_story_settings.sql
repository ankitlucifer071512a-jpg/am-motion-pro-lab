-- Phase 4C: private watch history and story-sharing preferences.
-- Apply only after 202610180003_idea_privacy_blocks.sql.

create table if not exists public.idea_reel_watch_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  watched_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index if not exists idea_reel_watch_history_recent_idx
  on public.idea_reel_watch_history(user_id, watched_at desc);
alter table public.idea_reel_watch_history enable row level security;
revoke all on public.idea_reel_watch_history from public, anon, authenticated;
grant select, delete on public.idea_reel_watch_history to authenticated;
create policy "owners read reel watch history" on public.idea_reel_watch_history
  for select to authenticated using (user_id=(select auth.uid()));
create policy "owners clear reel watch history" on public.idea_reel_watch_history
  for delete to authenticated using (user_id=(select auth.uid()));

create table if not exists public.idea_watch_history_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  paused boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.idea_watch_history_preferences enable row level security;
revoke all on public.idea_watch_history_preferences from public, anon, authenticated;
grant select, insert, update on public.idea_watch_history_preferences to authenticated;
create policy "owners manage watch history preference" on public.idea_watch_history_preferences
  for all to authenticated using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));

create table if not exists public.idea_story_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  replies_access text not null default 'everyone' check(replies_access in ('everyone','followers','off')),
  allow_resharing boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.idea_story_preferences enable row level security;
revoke all on public.idea_story_preferences from public,anon,authenticated;
grant select,insert,update on public.idea_story_preferences to authenticated;
create policy "owners manage story preferences" on public.idea_story_preferences
  for all to authenticated using(user_id=(select auth.uid()))
  with check(user_id=(select auth.uid()));

create or replace function public.list_idea_story_hide_candidates()
returns table(id uuid,display_name text,username text)
language sql stable security definer set search_path = '' as $$
  select p.id,p.display_name,p.username from public.idea_follows f
  join public.idea_profiles p on p.id=f.follower_id
  where f.followed_id=(select auth.uid());
$$;
revoke all on function public.list_idea_story_hide_candidates() from public,anon;
grant execute on function public.list_idea_story_hide_candidates() to authenticated;

create or replace function public.record_idea_reel_watch(target_post uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare viewer uuid := (select auth.uid());
begin
  if viewer is null or not public.idea_post_is_visible(target_post) then return false; end if;
  if exists(select 1 from public.idea_watch_history_preferences p where p.user_id=viewer and p.paused) then return false; end if;
  if not exists(select 1 from public.idea_post_media m where m.post_id=target_post and m.mime_type='video/mp4') then return false; end if;
  insert into public.idea_reel_watch_history(user_id,post_id,watched_at)
    values(viewer,target_post,now())
    on conflict(user_id,post_id) do update set watched_at=excluded.watched_at;
  return true;
end;
$$;
revoke all on function public.record_idea_reel_watch(uuid) from public, anon;
grant execute on function public.record_idea_reel_watch(uuid) to authenticated;

alter table public.idea_stories
  add column if not exists replies_access text not null default 'everyone',
  add column if not exists allow_resharing boolean not null default true,
  add column if not exists location_label text;
do $$ begin
  if not exists(select 1 from pg_constraint where conname='idea_stories_replies_access_check') then
    alter table public.idea_stories add constraint idea_stories_replies_access_check
      check(replies_access in ('everyone','followers','off'));
  end if;
  if not exists(select 1 from pg_constraint where conname='idea_stories_location_label_check') then
    alter table public.idea_stories add constraint idea_stories_location_label_check
      check(location_label is null or char_length(location_label)<=120);
  end if;
end $$;
grant insert (replies_access,allow_resharing,location_label) on public.idea_stories to authenticated;

create table if not exists public.idea_story_hidden_users (
  story_id uuid not null references public.idea_stories(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  hidden_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(story_id,hidden_user_id),
  check(owner_id<>hidden_user_id)
);
create index if not exists idea_story_hidden_users_owner_idx on public.idea_story_hidden_users(owner_id,story_id);
alter table public.idea_story_hidden_users enable row level security;
revoke all on public.idea_story_hidden_users from public,anon,authenticated;
grant select,insert,delete on public.idea_story_hidden_users to authenticated;
create policy "story owners manage hidden viewers" on public.idea_story_hidden_users for all to authenticated
  using(owner_id=(select auth.uid()) and exists(select 1 from public.idea_stories s where s.id=story_id and s.creator_id=owner_id))
  with check(owner_id=(select auth.uid()) and exists(select 1 from public.idea_stories s where s.id=story_id and s.creator_id=owner_id));

create or replace function public.idea_story_is_visible(target_story uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.idea_stories s where s.id=target_story
    and ((s.media_validated and s.expires_at>now()) or s.creator_id=(select auth.uid()))
    and public.idea_can_view_profile(s.creator_id)
    and (s.creator_id=(select auth.uid()) or not exists(
      select 1 from public.idea_story_hidden_users h where h.story_id=s.id and h.hidden_user_id=(select auth.uid())
    )));
$$;
revoke all on function public.idea_story_is_visible(uuid) from public;
grant execute on function public.idea_story_is_visible(uuid) to anon,authenticated;

create or replace function public.idea_story_replies_allowed(target_story uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.idea_stories s where s.id=target_story
    and public.idea_story_is_visible(s.id) and s.replies_access<>'off'
    and (s.replies_access='everyone' or s.creator_id=(select auth.uid())
      or exists(select 1 from public.idea_follows f where f.follower_id=(select auth.uid()) and f.followed_id=s.creator_id)));
$$;
revoke all on function public.idea_story_replies_allowed(uuid) from public;
grant execute on function public.idea_story_replies_allowed(uuid) to anon,authenticated;

-- Restrictive policies compose with the existing broad active-story policies.
drop policy if exists "phase4c stories hide selected viewers" on public.idea_stories;
create policy "phase4c stories hide selected viewers" on public.idea_stories as restrictive
  for select to anon,authenticated using (public.idea_story_is_visible(id));
drop policy if exists "phase4c story media hides selected viewers" on storage.objects;
create policy "phase4c story media hides selected viewers" on storage.objects as restrictive
  for select to anon,authenticated using (bucket_id<>'idea-stories' or exists(
    select 1 from public.idea_stories s where s.storage_path=name and public.idea_story_is_visible(s.id)
  ));
drop policy if exists "phase4c story comments access" on public.idea_story_comments;
create policy "phase4c story comments access" on public.idea_story_comments as restrictive for select to authenticated
  using(public.idea_story_replies_allowed(story_id));
drop policy if exists "phase4c story comment creation access" on public.idea_story_comments;
create policy "phase4c story comment creation access" on public.idea_story_comments as restrictive for insert to authenticated
  with check(public.idea_story_replies_allowed(story_id));
drop policy if exists "phase4c story likes access" on public.idea_story_likes;
create policy "phase4c story likes access" on public.idea_story_likes as restrictive for all to authenticated
  using(public.idea_story_is_visible(story_id))
  with check(public.idea_story_is_visible(story_id));
