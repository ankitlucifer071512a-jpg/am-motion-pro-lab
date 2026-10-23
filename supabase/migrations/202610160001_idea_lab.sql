create extension if not exists pgcrypto;

create table if not exists public.idea_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Creator',
  created_at timestamptz not null default now()
);

create or replace function public.idea_profile_on_signup()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.idea_profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Creator'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists idea_auth_user_profile on auth.users;
create trigger idea_auth_user_profile after insert on auth.users
for each row execute procedure public.idea_profile_on_signup();

-- Also create profiles for accounts that existed before this migration.
insert into public.idea_profiles (id, display_name)
select id, coalesce(nullif(raw_user_meta_data ->> 'display_name', ''), 'Creator')
from auth.users
on conflict (id) do nothing;

create table if not exists public.idea_categories (
  id text primary key,
  name text not null unique,
  created_at timestamptz not null default now()
);
insert into public.idea_categories (id, name) values
 ('video-editing','Video Editing'),('motion-graphics','Motion Graphics'),
 ('2d-animation','2D Animation'),('3d-animation','3D Animation'),
 ('graphic-design','Graphic Design'),('branding-advertising','Branding & Advertising'),
 ('visual-effects','Visual Effects'),('beginner-tutorials','Beginner Tutorials'),
 ('game-ideas','Game Ideas')
on conflict (id) do update set name = excluded.name;

create table if not exists public.idea_posts (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.idea_profiles(id) on delete cascade,
  caption text not null check (char_length(caption) between 1 and 2200),
  category_id text not null references public.idea_categories(id),
  created_at timestamptz not null default now(),
  published_at timestamptz
);
create index if not exists idea_posts_published_created_idx
  on public.idea_posts (created_at desc) where published_at is not null;
create index if not exists idea_posts_creator_idx on public.idea_posts (creator_id);

create table if not exists public.idea_post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  storage_path text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp','video/mp4')),
  width integer,
  height integer,
  video_validated boolean not null default false,
  position integer not null default 0 check (position between 0 and 99),
  created_at timestamptz not null default now()
);
create index if not exists idea_post_media_post_idx on public.idea_post_media (post_id, position);

create table if not exists public.idea_post_tags (
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 40),
  primary key (post_id, tag)
);
create index if not exists idea_post_tags_tag_idx on public.idea_post_tags (tag);

create table if not exists public.idea_saved_posts (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.idea_stories (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.idea_profiles(id) on delete cascade,
  storage_path text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp','video/mp4')),
  width integer,
  height integer,
  thumbnail_path text,
  media_validated boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  check (expires_at <= created_at + interval '24 hours')
);
create index if not exists idea_stories_active_idx on public.idea_stories (expires_at desc);

create table if not exists public.idea_story_views (
  story_id uuid not null references public.idea_stories(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

create or replace function public.validate_idea_post_publish()
returns trigger language plpgsql set search_path = '' as $$
declare media_count integer; bad_media integer;
begin
  if new.published_at is not null and (tg_op = 'INSERT' or old.published_at is null) then
    select count(*), count(*) filter (where
      storage_path not like new.creator_id::text || '/' || new.id::text || '/%' or
      not video_validated or
      (mime_type = 'video/mp4' and (width is null or height is null or
       (abs((width::numeric / height::numeric) - (16::numeric / 9)) > 0.005 and
        abs((width::numeric / height::numeric) - (9::numeric / 16)) > 0.005)))
    ) into media_count, bad_media from public.idea_post_media where post_id = new.id;
    if media_count < 1 or media_count > 100 or bad_media > 0 then
      raise exception 'Post media is incomplete or failed server validation';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists idea_posts_validate_publish on public.idea_posts;
create trigger idea_posts_validate_publish before insert or update of published_at
on public.idea_posts for each row execute function public.validate_idea_post_publish();

alter table public.idea_profiles enable row level security;
alter table public.idea_categories enable row level security;
alter table public.idea_posts enable row level security;
alter table public.idea_post_media enable row level security;
alter table public.idea_post_tags enable row level security;
alter table public.idea_saved_posts enable row level security;
alter table public.idea_stories enable row level security;
alter table public.idea_story_views enable row level security;

revoke all on public.idea_profiles, public.idea_categories, public.idea_posts,
 public.idea_post_media, public.idea_post_tags, public.idea_saved_posts,
 public.idea_stories, public.idea_story_views from anon, authenticated;
grant select on public.idea_profiles, public.idea_categories, public.idea_posts,
 public.idea_post_media, public.idea_post_tags, public.idea_stories to anon, authenticated;
grant insert, update on public.idea_profiles to authenticated;
grant insert (id, creator_id, caption, category_id) on public.idea_posts to authenticated;
grant update (published_at) on public.idea_posts to authenticated;
grant delete on public.idea_posts to authenticated;
grant insert (post_id, storage_path, mime_type, position) on public.idea_post_media to authenticated;
grant delete on public.idea_post_media to authenticated;
grant insert, delete on public.idea_post_tags to authenticated;
grant select, insert, delete on public.idea_saved_posts to authenticated;
grant insert (id, creator_id, storage_path, mime_type, thumbnail_path, expires_at)
  on public.idea_stories to authenticated;
grant delete on public.idea_stories to authenticated;
grant select, insert, update, delete on public.idea_story_views to authenticated;

create policy "profiles visible to all" on public.idea_profiles for select to anon, authenticated using (true);
create policy "creators update own profile" on public.idea_profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "categories visible to all" on public.idea_categories for select to anon, authenticated using (true);
create policy "published posts visible to all" on public.idea_posts for select to anon, authenticated using (published_at is not null or creator_id = (select auth.uid()));
create policy "creators insert own posts" on public.idea_posts for insert to authenticated with check (creator_id = (select auth.uid()));
create policy "creators update own posts" on public.idea_posts for update to authenticated using (creator_id = (select auth.uid())) with check (creator_id = (select auth.uid()));
create policy "creators delete own posts" on public.idea_posts for delete to authenticated using (creator_id = (select auth.uid()));
create policy "media visible with post" on public.idea_post_media for select to anon, authenticated using (exists (select 1 from public.idea_posts p where p.id = post_id and (p.published_at is not null or p.creator_id = (select auth.uid()))));
create policy "creators add media to own draft" on public.idea_post_media for insert to authenticated with check (exists (select 1 from public.idea_posts p where p.id = post_id and p.creator_id = (select auth.uid()) and p.published_at is null));
create policy "creators remove own draft media" on public.idea_post_media for delete to authenticated using (exists (select 1 from public.idea_posts p where p.id = post_id and p.creator_id = (select auth.uid()) and p.published_at is null));
create policy "tags visible with post" on public.idea_post_tags for select to anon, authenticated using (exists (select 1 from public.idea_posts p where p.id = post_id and (p.published_at is not null or p.creator_id = (select auth.uid()))));
create policy "creators tag own draft" on public.idea_post_tags for insert to authenticated with check (exists (select 1 from public.idea_posts p where p.id = post_id and p.creator_id = (select auth.uid()) and p.published_at is null));
create policy "creators remove own draft tags" on public.idea_post_tags for delete to authenticated using (exists (select 1 from public.idea_posts p where p.id = post_id and p.creator_id = (select auth.uid()) and p.published_at is null));
create policy "users manage own saves" on public.idea_saved_posts for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "active stories visible" on public.idea_stories for select to anon, authenticated using ((expires_at > now() and media_validated) or creator_id = (select auth.uid()));
create policy "users create own stories" on public.idea_stories for insert to authenticated with check (creator_id = (select auth.uid()) and not media_validated and expires_at <= now() + interval '24 hours');
create policy "users delete own stories" on public.idea_stories for delete to authenticated using (creator_id = (select auth.uid()));
create policy "users see own story views" on public.idea_story_views for select to authenticated using (viewer_id = (select auth.uid()));
create policy "users record story views" on public.idea_story_views for insert to authenticated with check (viewer_id = (select auth.uid()));
create policy "users update own story views" on public.idea_story_views for update to authenticated using (viewer_id = (select auth.uid())) with check (viewer_id = (select auth.uid()));
create policy "users remove own story views" on public.idea_story_views for delete to authenticated using (viewer_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('idea-media','idea-media',true,52428800,array['image/jpeg','image/png','image/webp','video/mp4'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('idea-stories','idea-stories',false,52428800,array['image/jpeg','image/png','image/webp','video/mp4'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
create policy "public reads Idea Lab media" on storage.objects for select to anon, authenticated using (bucket_id = 'idea-media');
create policy "active story media access" on storage.objects for select to anon, authenticated
  using (bucket_id = 'idea-stories' and exists (
    select 1 from public.idea_stories s where s.storage_path = name and
      ((s.media_validated and s.expires_at > now()) or s.creator_id = (select auth.uid()))
  ));
create policy "creators upload to own media folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('idea-media','idea-stories') and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "creators delete own media" on storage.objects for delete to authenticated
  using (bucket_id in ('idea-media','idea-stories') and (storage.foldername(name))[1] = (select auth.uid())::text);
