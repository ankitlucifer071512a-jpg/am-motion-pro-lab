-- Avoid querying idea_post_comments from its own RLS policy, which recurses.
create or replace function public.idea_post_comment_parent_matches(
  target_parent uuid,
  target_post uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.idea_post_comments parent
    where parent.id = target_parent
      and parent.post_id = target_post
  );
$$;
revoke all on function public.idea_post_comment_parent_matches(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.idea_post_comment_parent_matches(uuid, uuid)
  to authenticated;

drop policy if exists "users comment as themselves" on public.idea_post_comments;
create policy "users comment as themselves" on public.idea_post_comments
  for insert to authenticated with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from public.idea_posts p
      where p.id = idea_post_comments.post_id
        and p.published_at is not null
    )
    and (
      parent_comment_id is null
      or public.idea_post_comment_parent_matches(
        parent_comment_id,
        idea_post_comments.post_id
      )
    )
  );
