-- Phase 4B: additive privacy, follow-request, and block controls.
-- Existing rows and follows are retained. Public Idea Lab media becomes private
-- so row-level visibility is not bypassed by anonymous public object URLs.

alter table public.idea_profiles
  add column if not exists is_private boolean not null default false;

create table if not exists public.idea_follow_requests (
  requester_id uuid not null references public.idea_profiles(id) on delete cascade,
  target_id uuid not null references public.idea_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (requester_id, target_id),
  check (requester_id <> target_id)
);
create index if not exists idea_follow_requests_target_idx
  on public.idea_follow_requests (target_id, created_at desc);

create table if not exists public.idea_blocks (
  blocker_id uuid not null references public.idea_profiles(id) on delete cascade,
  blocked_id uuid not null references public.idea_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists idea_blocks_blocked_idx on public.idea_blocks (blocked_id, blocker_id);

alter table public.idea_follow_requests enable row level security;
alter table public.idea_blocks enable row level security;
revoke all on public.idea_follow_requests, public.idea_blocks from public, anon, authenticated;
grant select, insert, delete on public.idea_follow_requests to authenticated;
grant select, insert, delete on public.idea_blocks to authenticated;

create or replace function public.idea_accounts_blocked_internal(first_id uuid, second_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select first_id is not null and second_id is not null and exists (
    select 1 from public.idea_blocks b
    where (b.blocker_id = first_id and b.blocked_id = second_id)
       or (b.blocker_id = second_id and b.blocked_id = first_id)
  );
$$;
revoke all on function public.idea_accounts_blocked_internal(uuid, uuid) from public, anon, authenticated;

-- Client callers may only check a block relation involving themselves.
create or replace function public.idea_accounts_blocked(first_id uuid, second_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case when (select auth.uid()) is not null
    and ((select auth.uid())=first_id or (select auth.uid())=second_id)
    then public.idea_accounts_blocked_internal(first_id,second_id)
    else false end;
$$;
revoke all on function public.idea_accounts_blocked(uuid, uuid) from public;
grant execute on function public.idea_accounts_blocked(uuid, uuid) to anon, authenticated;

create or replace function public.idea_can_view_profile(target_profile uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.idea_profiles p
    where p.id = target_profile and (
      p.id = (select auth.uid()) or (
        not public.idea_accounts_blocked((select auth.uid()), p.id)
        and (not p.is_private or exists (
          select 1 from public.idea_follows f
          where f.follower_id = (select auth.uid()) and f.followed_id = p.id
        ))
      )
    )
  );
$$;
revoke all on function public.idea_can_view_profile(uuid) from public;
grant execute on function public.idea_can_view_profile(uuid) to anon, authenticated;

create or replace function public.idea_post_is_visible(target_post uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.idea_posts p
    where p.id = target_post and p.published_at is not null
      and not public.idea_accounts_blocked((select auth.uid()), p.creator_id)
      and (p.creator_id = (select auth.uid()) or exists (
        select 1 from public.idea_profiles owner
        where owner.id = p.creator_id
          and (not owner.is_private or exists (
            select 1 from public.idea_follows f
            where f.follower_id = (select auth.uid()) and f.followed_id = owner.id
          ))
      ))
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
    select 1 from public.idea_posts p where p.id = target_post
      and public.idea_post_is_visible(p.id) and p.comments_access <> 'off'
      and not public.idea_accounts_blocked((select auth.uid()), p.creator_id)
      and (p.comments_access = 'everyone' or p.creator_id = (select auth.uid())
        or exists (select 1 from public.idea_follows f
          where f.follower_id = (select auth.uid()) and f.followed_id = p.creator_id))
  );
$$;
revoke all on function public.idea_post_comments_allowed(uuid) from public;
grant execute on function public.idea_post_comments_allowed(uuid) to anon, authenticated;

-- Request or immediately follow a public account. Existing follows are untouched.
create or replace function public.request_idea_follow(target_profile uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare requester uuid := (select auth.uid()); private_target boolean;
begin
  if requester is null then raise exception 'Sign in to follow creators.'; end if;
  if requester = target_profile then raise exception 'You cannot follow yourself.'; end if;
  if public.idea_accounts_blocked(requester, target_profile) then raise exception 'This follow is unavailable.'; end if;
  select is_private into private_target from public.idea_profiles where id = target_profile;
  if not found then raise exception 'Creator was not found.'; end if;
  if exists (select 1 from public.idea_follows where follower_id=requester and followed_id=target_profile) then
    return 'following';
  end if;
  if private_target then
    insert into public.idea_follow_requests(requester_id,target_id) values(requester,target_profile)
      on conflict do nothing;
    return 'requested';
  end if;
  insert into public.idea_follows(follower_id,followed_id) values(requester,target_profile)
    on conflict do nothing;
  return 'following';
end;
$$;
revoke all on function public.request_idea_follow(uuid) from public, anon;
grant execute on function public.request_idea_follow(uuid) to authenticated;

create or replace function public.respond_idea_follow_request(requester uuid, approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare recipient uuid := (select auth.uid());
begin
  if recipient is null or not exists (
    select 1 from public.idea_follow_requests r
    where r.requester_id=requester and r.target_id=recipient
  ) then raise exception 'Follow request was not found.'; end if;
  if approve and not public.idea_accounts_blocked(requester, recipient) then
    insert into public.idea_follows(follower_id,followed_id) values(requester,recipient)
      on conflict do nothing;
  end if;
  delete from public.idea_follow_requests where requester_id=requester and target_id=recipient;
end;
$$;
revoke all on function public.respond_idea_follow_request(uuid, boolean) from public, anon;
grant execute on function public.respond_idea_follow_request(uuid, boolean) to authenticated;

create or replace function public.idea_private_to_public_approve_requests()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.is_private and not new.is_private then
    insert into public.idea_follows(follower_id, followed_id)
    select r.requester_id, r.target_id from public.idea_follow_requests r
    where r.target_id = new.id
      and not public.idea_accounts_blocked(r.requester_id, r.target_id)
    on conflict do nothing;
    delete from public.idea_follow_requests where target_id = new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.idea_private_to_public_approve_requests() from public, anon, authenticated;
drop trigger if exists idea_private_to_public_approve_requests on public.idea_profiles;
create trigger idea_private_to_public_approve_requests after update of is_private
on public.idea_profiles for each row execute function public.idea_private_to_public_approve_requests();

create or replace function public.idea_remove_relationships_on_block()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.idea_follows f where
    (f.follower_id=new.blocker_id and f.followed_id=new.blocked_id)
    or (f.follower_id=new.blocked_id and f.followed_id=new.blocker_id);
  delete from public.idea_follow_requests r where
    (r.requester_id=new.blocker_id and r.target_id=new.blocked_id)
    or (r.requester_id=new.blocked_id and r.target_id=new.blocker_id);
  return new;
end;
$$;
revoke all on function public.idea_remove_relationships_on_block() from public, anon, authenticated;
drop trigger if exists idea_remove_relationships_on_block on public.idea_blocks;
create trigger idea_remove_relationships_on_block after insert on public.idea_blocks
for each row execute function public.idea_remove_relationships_on_block();

drop policy if exists "idea follow requests read participants" on public.idea_follow_requests;
create policy "idea follow requests read participants" on public.idea_follow_requests for select to authenticated
  using (requester_id=(select auth.uid()) or target_id=(select auth.uid()));
drop policy if exists "idea follow requests create as requester" on public.idea_follow_requests;
create policy "idea follow requests create as requester" on public.idea_follow_requests for insert to authenticated
  with check (requester_id=(select auth.uid()) and target_id<>(select auth.uid())
    and not public.idea_accounts_blocked(requester_id,target_id)
    and exists(select 1 from public.idea_profiles p where p.id=target_id and p.is_private)
    and not exists(select 1 from public.idea_follows f where f.follower_id=requester_id and f.followed_id=target_id));
drop policy if exists "idea follow requests cancel own" on public.idea_follow_requests;
create policy "idea follow requests cancel own" on public.idea_follow_requests for delete to authenticated
  using (requester_id=(select auth.uid()) or target_id=(select auth.uid()));

drop policy if exists "idea blocks read own" on public.idea_blocks;
create policy "idea blocks read own" on public.idea_blocks for select to authenticated using (blocker_id=(select auth.uid()));
drop policy if exists "idea blocks create own" on public.idea_blocks;
create policy "idea blocks create own" on public.idea_blocks for insert to authenticated
  with check (blocker_id=(select auth.uid()) and blocker_id<>blocked_id);
drop policy if exists "idea blocks remove own" on public.idea_blocks;
create policy "idea blocks remove own" on public.idea_blocks for delete to authenticated using (blocker_id=(select auth.uid()));

-- Existing wide policies remain in place; restrictive policies AND with them.
drop policy if exists "privacy profile visibility" on public.idea_profiles;
create policy "privacy profile visibility" on public.idea_profiles as restrictive
  for select to anon, authenticated using (public.idea_can_view_profile(id));
drop policy if exists "privacy post visibility" on public.idea_posts;
create policy "privacy post visibility" on public.idea_posts as restrictive
  for select to anon, authenticated using (published_at is null and creator_id=(select auth.uid())
    or public.idea_post_is_visible(id));

drop policy if exists "privacy media visibility" on public.idea_post_media;
create policy "privacy media visibility" on public.idea_post_media as restrictive for select to anon, authenticated
  using (exists(select 1 from public.idea_posts p where p.id=post_id
    and (p.creator_id=(select auth.uid()) or public.idea_post_is_visible(p.id))));
drop policy if exists "privacy tags visibility" on public.idea_post_tags;
create policy "privacy tags visibility" on public.idea_post_tags as restrictive for select to anon, authenticated
  using (exists(select 1 from public.idea_posts p where p.id=post_id
    and (p.creator_id=(select auth.uid()) or public.idea_post_is_visible(p.id))));
drop policy if exists "privacy stories visibility" on public.idea_stories;
create policy "privacy stories visibility" on public.idea_stories as restrictive for select to anon, authenticated
  using (((media_validated and expires_at>now()) or creator_id=(select auth.uid()))
    and public.idea_can_view_profile(creator_id));

drop policy if exists "privacy post likes visibility" on public.idea_post_likes;
create policy "privacy post likes visibility" on public.idea_post_likes as restrictive for select to authenticated
  using (public.idea_post_is_visible(post_id)
    and not public.idea_accounts_blocked((select auth.uid()),user_id));
drop policy if exists "privacy post likes insert" on public.idea_post_likes;
create policy "privacy post likes insert" on public.idea_post_likes as restrictive for insert to authenticated
  with check (not public.idea_accounts_blocked((select auth.uid()),(select p.creator_id from public.idea_posts p where p.id=post_id))
    and public.idea_post_is_visible(post_id));
drop policy if exists "privacy post comments visibility" on public.idea_post_comments;
create policy "privacy post comments visibility" on public.idea_post_comments as restrictive for select to authenticated
  using (public.idea_post_is_visible(post_id) and not public.idea_accounts_blocked((select auth.uid()),author_id));
drop policy if exists "privacy post comments insert" on public.idea_post_comments;
create policy "privacy post comments insert" on public.idea_post_comments as restrictive for insert to authenticated
  with check (public.idea_post_comments_allowed(post_id)
    and not public.idea_accounts_blocked((select auth.uid()),author_id));
drop policy if exists "privacy post reports insert" on public.idea_post_reports;
create policy "privacy post reports insert" on public.idea_post_reports as restrictive for insert to authenticated
  with check (public.idea_post_is_visible(post_id));

drop policy if exists "privacy story likes visibility" on public.idea_story_likes;
create policy "privacy story likes visibility" on public.idea_story_likes as restrictive for select to authenticated
  using (exists(select 1 from public.idea_stories s where s.id=story_id and public.idea_can_view_profile(s.creator_id))
    and not public.idea_accounts_blocked((select auth.uid()),user_id));
drop policy if exists "privacy story likes insert" on public.idea_story_likes;
create policy "privacy story likes insert" on public.idea_story_likes as restrictive for insert to authenticated
  with check (exists(select 1 from public.idea_stories s where s.id=story_id and public.idea_can_view_profile(s.creator_id)));
drop policy if exists "privacy story comments visibility" on public.idea_story_comments;
create policy "privacy story comments visibility" on public.idea_story_comments as restrictive for select to authenticated
  using (exists(select 1 from public.idea_stories s where s.id=story_id and public.idea_can_view_profile(s.creator_id))
    and not public.idea_accounts_blocked((select auth.uid()),author_id));
drop policy if exists "privacy story comments insert" on public.idea_story_comments;
create policy "privacy story comments insert" on public.idea_story_comments as restrictive for insert to authenticated
  with check (exists(select 1 from public.idea_stories s where s.id=story_id and public.idea_can_view_profile(s.creator_id)));
drop policy if exists "privacy story views" on public.idea_story_views;
create policy "privacy story views" on public.idea_story_views as restrictive for all to authenticated
  using (exists(select 1 from public.idea_stories s where s.id=story_id and public.idea_can_view_profile(s.creator_id)))
  with check (viewer_id=(select auth.uid()) and exists(select 1 from public.idea_stories s where s.id=story_id and public.idea_can_view_profile(s.creator_id)));
drop policy if exists "privacy post views" on public.idea_post_views;
create policy "privacy post views" on public.idea_post_views as restrictive for all to authenticated
  using (viewer_id=(select auth.uid()) and public.idea_post_is_visible(post_id))
  with check (viewer_id=(select auth.uid()) and public.idea_post_is_visible(post_id));

drop policy if exists "privacy follow select" on public.idea_follows;
create policy "privacy follow select" on public.idea_follows as restrictive for select to authenticated
  using (not public.idea_accounts_blocked(follower_id,followed_id)
    and (follower_id=(select auth.uid()) or followed_id=(select auth.uid())));
drop policy if exists "privacy follow insert" on public.idea_follows;
create policy "privacy follow insert" on public.idea_follows as restrictive for insert to authenticated
  with check (follower_id=(select auth.uid()) and not public.idea_accounts_blocked(follower_id,followed_id)
    and exists(select 1 from public.idea_profiles p where p.id=followed_id and not p.is_private));
drop policy if exists "privacy follow delete" on public.idea_follows;
create policy "privacy follow delete" on public.idea_follows as restrictive for delete to authenticated
  using (follower_id=(select auth.uid()) or followed_id=(select auth.uid()));

drop policy if exists "privacy messages read" on public.idea_messages;
create policy "privacy messages read" on public.idea_messages as restrictive for select to authenticated
  using ((sender_id=(select auth.uid()) or recipient_id=(select auth.uid()))
    and not public.idea_accounts_blocked(sender_id,recipient_id));
drop policy if exists "privacy messages insert" on public.idea_messages;
create policy "privacy messages insert" on public.idea_messages as restrictive for insert to authenticated
  with check (sender_id=(select auth.uid()) and not public.idea_accounts_blocked(sender_id,recipient_id));
drop policy if exists "privacy messages update" on public.idea_messages;
create policy "privacy messages update" on public.idea_messages as restrictive for update to authenticated
  using (recipient_id=(select auth.uid()) and not public.idea_accounts_blocked(sender_id,recipient_id))
  with check (recipient_id=(select auth.uid()) and not public.idea_accounts_blocked(sender_id,recipient_id));

-- Private account audio rows follow the same visibility rules.
drop policy if exists "approved audio or own audio visible" on public.audios;
create policy "approved audio or own audio visible" on public.audios for select to anon, authenticated using (
  (status='approved' and public.idea_can_view_profile(owner_id))
  or owner_id=(select auth.uid()) or (select public.is_audio_admin())
);

-- Public URLs bypass Storage RLS, so make Idea Lab media private. The policy
-- permits owners and viewers allowed by the corresponding post/story row.
update storage.buckets set public=false where id in ('idea-media','idea-stories','idea-avatars');
drop policy if exists "public reads Idea Lab media" on storage.objects;
create policy "privacy reads Idea Lab media" on storage.objects for select to anon, authenticated
  using (bucket_id='idea-media' and exists (
    select 1 from public.idea_post_media m join public.idea_posts p on p.id=m.post_id
    where m.storage_path=name and (p.creator_id=(select auth.uid()) or public.idea_post_is_visible(p.id))
  ));
drop policy if exists "active story media access" on storage.objects;
create policy "privacy reads story media" on storage.objects for select to anon, authenticated
  using (bucket_id='idea-stories' and exists (
    select 1 from public.idea_stories s where s.storage_path=name
      and ((s.media_validated and s.expires_at>now()) or s.creator_id=(select auth.uid()))
      and public.idea_can_view_profile(s.creator_id)
  ));
drop policy if exists "public reads creator avatars" on storage.objects;
create policy "privacy reads creator avatars" on storage.objects for select to anon, authenticated
  using (bucket_id='idea-avatars' and exists (
    select 1 from public.idea_profiles p where p.avatar_path=name and public.idea_can_view_profile(p.id)
  ));

create or replace function public.idea_profile_counts(target_profile uuid)
returns table(post_count bigint, follower_count bigint, following_count bigint)
language sql stable security definer set search_path = '' as $$
  select
    (select count(*) from public.idea_posts p where p.creator_id=target_profile and p.published_at is not null),
    (select count(*) from public.idea_follows f where f.followed_id=target_profile),
    (select count(*) from public.idea_follows f where f.follower_id=target_profile)
  where public.idea_can_view_profile(target_profile);
$$;
revoke all on function public.idea_profile_counts(uuid) from public, anon;
grant execute on function public.idea_profile_counts(uuid) to authenticated;



create or replace function public.idea_post_view_counts(target_posts uuid[])
returns table(post_id uuid, view_count bigint)
language sql stable security definer set search_path = '' as $$
  select v.post_id, count(*)::bigint
  from public.idea_post_views v
  where v.post_id = any(target_posts) and public.idea_post_is_visible(v.post_id)
  group by v.post_id;
$$;
revoke all on function public.idea_post_view_counts(uuid[]) from public, anon;
grant execute on function public.idea_post_view_counts(uuid[]) to authenticated;

create or replace function public.record_idea_post_view(target_post uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.idea_post_is_visible(target_post) then return; end if;
  insert into public.idea_post_views (post_id, viewer_id)
  select p.id, auth.uid() from public.idea_posts p
  where p.id=target_post and p.published_at is not null and p.creator_id<>auth.uid()
  on conflict (post_id, viewer_id) do nothing;
end;
$$;
revoke all on function public.record_idea_post_view(uuid) from public, anon;
grant execute on function public.record_idea_post_view(uuid) to authenticated;

create or replace function public.match_idea_contacts(
  requester_id uuid, contact_emails text[], contact_phones text[]
)
returns table(id uuid, display_name text, username text, bio text, avatar_path text)
language sql stable security definer set search_path = '' as $$
  select p.id,p.display_name,p.username,p.bio,p.avatar_path
  from auth.users u join public.idea_profiles p on p.id=u.id
  where requester_id is not null and u.id<>requester_id
    and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null)
    and not public.idea_accounts_blocked_internal(requester_id,p.id)
    and (not p.is_private or exists(select 1 from public.idea_follows f
      where f.follower_id=requester_id and f.followed_id=p.id))
    and (lower(coalesce(u.email,''))=any(coalesce(contact_emails,array[]::text[]))
      or regexp_replace(coalesce(u.phone,''),'[^0-9]','','g')=any(coalesce(contact_phones,array[]::text[])));
$$;
revoke all on function public.match_idea_contacts(uuid,text[],text[]) from public, anon, authenticated;
grant execute on function public.match_idea_contacts(uuid,text[],text[]) to service_role;

create or replace function public.list_idea_blocked_profiles()
returns table(id uuid, display_name text, username text)
language sql stable security definer set search_path = '' as $$
  select p.id,p.display_name,p.username from public.idea_blocks b
  join public.idea_profiles p on p.id=b.blocked_id
  where b.blocker_id=(select auth.uid());
$$;
revoke all on function public.list_idea_blocked_profiles() from public, anon;
grant execute on function public.list_idea_blocked_profiles() to authenticated;

drop policy if exists "privacy follow select" on public.idea_follows;
create policy "privacy follow select" on public.idea_follows as restrictive for select to authenticated
  using (not public.idea_accounts_blocked(follower_id,followed_id)
    and not public.idea_accounts_blocked((select auth.uid()),follower_id)
    and not public.idea_accounts_blocked((select auth.uid()),followed_id)
    and (follower_id=(select auth.uid()) or followed_id=(select auth.uid())
      or (public.idea_can_view_profile(follower_id) and public.idea_can_view_profile(followed_id))));
