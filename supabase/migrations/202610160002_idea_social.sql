-- Social profile fields and the first authenticated social features.
alter table public.idea_profiles
  add column if not exists username text,
  add column if not exists bio text not null default '',
  add column if not exists avatar_path text;

create unique index if not exists idea_profiles_username_idx
  on public.idea_profiles (lower(username)) where username is not null;
alter table public.idea_profiles drop constraint if exists idea_profiles_username_check;
alter table public.idea_profiles add constraint idea_profiles_username_check
  check (username is null or username ~ '^[a-zA-Z0-9_.]{3,30}$');
alter table public.idea_profiles drop constraint if exists idea_profiles_bio_check;
alter table public.idea_profiles add constraint idea_profiles_bio_check
  check (char_length(bio) <= 160);

create table if not exists public.idea_follows (
  follower_id uuid not null references public.idea_profiles(id) on delete cascade,
  followed_id uuid not null references public.idea_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);
create index if not exists idea_follows_followed_idx
  on public.idea_follows (followed_id, created_at desc);

create table if not exists public.idea_post_views (
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (post_id, viewer_id)
);

create or replace function public.record_idea_post_view(target_post uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  insert into public.idea_post_views (post_id, viewer_id)
  select p.id, auth.uid() from public.idea_posts p
  where p.id = target_post and p.published_at is not null
    and p.creator_id <> auth.uid()
  on conflict (post_id, viewer_id) do nothing;
end;
$$;

create or replace function public.idea_post_view_counts(target_posts uuid[])
returns table(post_id uuid, view_count bigint)
language sql stable security definer set search_path = '' as $$
  select v.post_id, count(*)::bigint
  from public.idea_post_views v
  join public.idea_posts p on p.id = v.post_id
  where v.post_id = any(target_posts)
    and (p.published_at is not null or p.creator_id = auth.uid())
  group by v.post_id;
$$;

create or replace function public.idea_profile_counts(target_profile uuid)
returns table(post_count bigint, follower_count bigint, following_count bigint)
language sql stable security definer set search_path = '' as $$
  select
    (select count(*) from public.idea_posts p
      where p.creator_id = target_profile and p.published_at is not null),
    (select count(*) from public.idea_follows f where f.followed_id = target_profile),
    (select count(*) from public.idea_follows f where f.follower_id = target_profile);
$$;

create table if not exists public.idea_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.idea_profiles(id) on delete cascade,
  recipient_id uuid not null references public.idea_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (sender_id <> recipient_id)
);
create index if not exists idea_messages_thread_idx
  on public.idea_messages (sender_id, recipient_id, created_at desc);
create index if not exists idea_messages_recipient_idx
  on public.idea_messages (recipient_id, created_at desc);

alter table public.idea_follows enable row level security;
alter table public.idea_post_views enable row level security;
alter table public.idea_messages enable row level security;
revoke all on public.idea_follows, public.idea_post_views, public.idea_messages
  from anon, authenticated;
grant select, insert, delete on public.idea_follows to authenticated;
grant select, insert on public.idea_post_views to authenticated;
grant select, insert on public.idea_messages to authenticated;
grant update (read_at) on public.idea_messages to authenticated;
revoke all on function public.record_idea_post_view(uuid) from public, anon, authenticated;
revoke all on function public.idea_post_view_counts(uuid[]) from public, anon, authenticated;
revoke all on function public.idea_profile_counts(uuid) from public, anon, authenticated;
grant execute on function public.record_idea_post_view(uuid) to authenticated;
grant execute on function public.idea_post_view_counts(uuid[]) to authenticated;
grant execute on function public.idea_profile_counts(uuid) to authenticated;

create or replace function public.match_idea_contacts(
  requester_id uuid,
  contact_emails text[],
  contact_phones text[]
)
returns table(id uuid, display_name text, username text, bio text, avatar_path text)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.username, p.bio, p.avatar_path
  from auth.users u
  join public.idea_profiles p on p.id = u.id
  where u.id <> requester_id
    and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null)
    and (
      lower(coalesce(u.email, '')) = any(coalesce(contact_emails, array[]::text[]))
      or regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g')
        = any(coalesce(contact_phones, array[]::text[]))
    );
$$;
revoke all on function public.match_idea_contacts(uuid, text[], text[]) from public, anon, authenticated;
grant execute on function public.match_idea_contacts(uuid, text[], text[]) to service_role;

create table if not exists public.idea_contact_match_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0
);
alter table public.idea_contact_match_limits enable row level security;
revoke all on public.idea_contact_match_limits from public, anon, authenticated;
create or replace function public.consume_idea_contact_match(requester_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare allowed boolean;
begin
  insert into public.idea_contact_match_limits as limits
    (user_id, window_started_at, request_count)
  values (requester_id, now(), 1)
  on conflict (user_id) do update set
    window_started_at = case
      when limits.window_started_at < now() - interval '1 hour'
        then now()
      else limits.window_started_at
    end,
    request_count = case
      when limits.window_started_at < now() - interval '1 hour'
        then 1
      else limits.request_count + 1
    end
  returning request_count <= 5 into allowed;
  return allowed;
end;
$$;
revoke all on function public.consume_idea_contact_match(uuid) from public, anon, authenticated;
grant execute on function public.consume_idea_contact_match(uuid) to service_role;

drop policy if exists "authenticated users see follows" on public.idea_follows;
create policy "authenticated users see follows" on public.idea_follows
  for select to authenticated using (true);
drop policy if exists "users follow as themselves" on public.idea_follows;
create policy "users follow as themselves" on public.idea_follows
  for insert to authenticated with check (follower_id = (select auth.uid()));
drop policy if exists "users unfollow as themselves" on public.idea_follows;
create policy "users unfollow as themselves" on public.idea_follows
  for delete to authenticated using (follower_id = (select auth.uid()));

drop policy if exists "users read own post views" on public.idea_post_views;
create policy "users read own post views" on public.idea_post_views
  for select to authenticated using (viewer_id = (select auth.uid()));
drop policy if exists "users record own post views" on public.idea_post_views;
create policy "users record own post views" on public.idea_post_views
  for insert to authenticated with check (viewer_id = (select auth.uid()));

drop policy if exists "message participants read messages" on public.idea_messages;
create policy "message participants read messages" on public.idea_messages
  for select to authenticated using (
    sender_id = (select auth.uid()) or recipient_id = (select auth.uid())
  );
drop policy if exists "sender creates message" on public.idea_messages;
create policy "sender creates message" on public.idea_messages
  for insert to authenticated with check (sender_id = (select auth.uid()));
drop policy if exists "recipient marks message read" on public.idea_messages;
create policy "recipient marks message read" on public.idea_messages
  for update to authenticated using (recipient_id = (select auth.uid()))
  with check (recipient_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('idea-avatars','idea-avatars',true,5242880,
  array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "public reads creator avatars" on storage.objects;
create policy "public reads creator avatars" on storage.objects
  for select to anon, authenticated using (bucket_id = 'idea-avatars');
drop policy if exists "creators upload own avatar" on storage.objects;
create policy "creators upload own avatar" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'idea-avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
drop policy if exists "creators update own avatar" on storage.objects;
create policy "creators update own avatar" on storage.objects
  for update to authenticated using (
    bucket_id = 'idea-avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  ) with check (
    bucket_id = 'idea-avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
drop policy if exists "creators delete own avatar" on storage.objects;
create policy "creators delete own avatar" on storage.objects
  for delete to authenticated using (
    bucket_id = 'idea-avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
