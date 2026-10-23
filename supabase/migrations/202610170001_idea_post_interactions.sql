-- Likes, threaded comments, and abuse reports for published Idea Lab posts.
create table if not exists public.idea_post_likes (
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists idea_post_likes_user_idx
  on public.idea_post_likes (user_id, created_at desc);

create table if not exists public.idea_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  author_id uuid not null references public.idea_profiles(id) on delete cascade,
  parent_comment_id uuid references public.idea_post_comments(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2200),
  created_at timestamptz not null default now()
);
create index if not exists idea_post_comments_post_idx
  on public.idea_post_comments (post_id, created_at);
create index if not exists idea_post_comments_parent_idx
  on public.idea_post_comments (parent_comment_id, created_at);

create table if not exists public.idea_post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.idea_posts(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 80),
  details text not null default '' check (char_length(details) <= 1000),
  created_at timestamptz not null default now(),
  unique (post_id, reporter_id)
);

create or replace function public.idea_post_engagement_counts(target_post uuid)
returns table(like_count bigint, comment_count bigint)
language sql stable security definer set search_path = '' as $$
  select
    (select count(*) from public.idea_post_likes l where l.post_id = target_post),
    (select count(*) from public.idea_post_comments c where c.post_id = target_post)
  where exists (select 1 from public.idea_posts p
    where p.id = target_post and p.published_at is not null);
$$;
revoke all on function public.idea_post_engagement_counts(uuid) from public, anon;
grant execute on function public.idea_post_engagement_counts(uuid) to authenticated;

alter table public.idea_post_likes enable row level security;
alter table public.idea_post_comments enable row level security;
alter table public.idea_post_reports enable row level security;
revoke all on public.idea_post_likes, public.idea_post_comments,
  public.idea_post_reports from anon, authenticated;
grant select, insert, delete on public.idea_post_likes to authenticated;
grant select, insert on public.idea_post_comments to authenticated;
grant insert on public.idea_post_reports to authenticated;

create policy "likes visible with published posts" on public.idea_post_likes
  for select to authenticated using (exists (
    select 1 from public.idea_posts p where p.id = post_id
      and p.published_at is not null
  ));
create policy "users like as themselves" on public.idea_post_likes
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.idea_posts p where p.id = post_id
        and p.published_at is not null and p.creator_id <> (select auth.uid())
    )
  );
create policy "users remove own likes" on public.idea_post_likes
  for delete to authenticated using (user_id = (select auth.uid()));

create policy "comments visible with published posts" on public.idea_post_comments
  for select to authenticated using (exists (
    select 1 from public.idea_posts p where p.id = post_id
      and p.published_at is not null
  ));
create policy "users comment as themselves" on public.idea_post_comments
  for insert to authenticated with check (
    author_id = (select auth.uid()) and exists (
      select 1 from public.idea_posts p where p.id = post_id
        and p.published_at is not null
    ) and (parent_comment_id is null or exists (
      select 1 from public.idea_post_comments parent
      where parent.id = idea_post_comments.parent_comment_id
        and parent.post_id = idea_post_comments.post_id
    ))
  );

create policy "users submit own post reports" on public.idea_post_reports
  for insert to authenticated with check (
    reporter_id = (select auth.uid()) and exists (
      select 1 from public.idea_posts p where p.id = post_id
        and p.published_at is not null and p.creator_id <> (select auth.uid())
    )
  );
