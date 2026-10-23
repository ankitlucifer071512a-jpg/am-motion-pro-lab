-- Phase 2 Create Post settings. Additive defaults preserve all existing posts.
alter table public.idea_posts
  add column if not exists audience text not null default 'public',
  add column if not exists comments_access text not null default 'everyone',
  add column if not exists hide_like_count boolean not null default false,
  add column if not exists allow_audio_use boolean not null default true,
  add column if not exists allow_saving boolean not null default true,
  add column if not exists alt_text text,
  add column if not exists location_label text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'idea_posts_audience_check') then
    alter table public.idea_posts add constraint idea_posts_audience_check
      check (audience in ('public', 'followers'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'idea_posts_comments_access_check') then
    alter table public.idea_posts add constraint idea_posts_comments_access_check
      check (comments_access in ('everyone', 'followers', 'off'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'idea_posts_alt_text_length_check') then
    alter table public.idea_posts add constraint idea_posts_alt_text_length_check
      check (alt_text is null or char_length(alt_text) <= 500);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'idea_posts_location_length_check') then
    alter table public.idea_posts add constraint idea_posts_location_length_check
      check (location_label is null or char_length(location_label) <= 120);
  end if;
end $$;

grant insert (audience, comments_access, hide_like_count, allow_audio_use,
  allow_saving, alt_text, location_label) on public.idea_posts to authenticated;

create or replace function public.idea_post_is_visible(target_post uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.idea_posts p
    where p.id = target_post and p.published_at is not null
      and (p.audience = 'public' or p.creator_id = (select auth.uid())
        or exists (select 1 from public.idea_follows f
          where f.follower_id = (select auth.uid()) and f.followed_id = p.creator_id))
  );
$$;
revoke all on function public.idea_post_is_visible(uuid) from public;
grant execute on function public.idea_post_is_visible(uuid) to anon, authenticated;

create or replace function public.idea_post_comments_allowed(target_post uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.idea_posts p
    where p.id = target_post and public.idea_post_is_visible(p.id)
      and p.comments_access <> 'off'
      and (p.comments_access = 'everyone' or p.creator_id = (select auth.uid())
        or exists (select 1 from public.idea_follows f
          where f.follower_id = (select auth.uid()) and f.followed_id = p.creator_id))
  );
$$;
revoke all on function public.idea_post_comments_allowed(uuid) from public;
grant execute on function public.idea_post_comments_allowed(uuid) to anon, authenticated;

drop policy if exists "published posts visible to all" on public.idea_posts;
create policy "posts visible by selected audience" on public.idea_posts
  for select to anon, authenticated using (
    (published_at is not null and public.idea_post_is_visible(id))
    or creator_id = (select auth.uid())
  );

drop policy if exists "comments visible with published posts" on public.idea_post_comments;
create policy "comments visible when post allows comments" on public.idea_post_comments
  for select to authenticated using (public.idea_post_comments_allowed(post_id));

drop policy if exists "users comment as themselves" on public.idea_post_comments;
create policy "users comment within post audience" on public.idea_post_comments
  for insert to authenticated with check (
    author_id = (select auth.uid())
    and public.idea_post_comments_allowed(post_id)
    and (parent_comment_id is null or public.idea_post_comment_parent_matches(
      parent_comment_id, idea_post_comments.post_id))
  );

drop policy if exists "users manage own saves" on public.idea_saved_posts;
create policy "users read own saves" on public.idea_saved_posts
  for select to authenticated using (user_id = (select auth.uid()));
create policy "users save permitted posts" on public.idea_saved_posts
  for insert to authenticated with check (
    user_id = (select auth.uid())
    and public.idea_post_is_visible(post_id)
    and exists (select 1 from public.idea_posts p where p.id = post_id and p.allow_saving)
  );
create policy "users remove own saves" on public.idea_saved_posts
  for delete to authenticated using (user_id = (select auth.uid()));

create or replace function public.idea_post_engagement_counts(target_post uuid)
returns table(like_count bigint, comment_count bigint)
language sql stable security definer set search_path = '' as $$
  select
    (select count(*) from public.idea_post_likes l where l.post_id = target_post),
    (select count(*) from public.idea_post_comments c where c.post_id = target_post)
  where public.idea_post_is_visible(target_post);
$$;
