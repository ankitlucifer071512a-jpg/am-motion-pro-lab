-- Mirrors the owner-visible SELECT policies applied manually in production.
-- Re-running this file is safe: the function is replaced and the policies are
-- dropped before they are recreated. It does not change audience/block rules.
create or replace function public.idea_post_is_visible(target_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.idea_posts p
    where p.id = target_post
      and p.published_at is not null
      and not public.idea_accounts_blocked((select auth.uid()), p.creator_id)
      and (
        p.creator_id = (select auth.uid())
        or exists (
          select 1
          from public.idea_profiles owner_profile
          where owner_profile.id = p.creator_id
            and (
              not owner_profile.is_private
              or exists (
                select 1
                from public.idea_follows f
                where f.follower_id = (select auth.uid())
                  and f.followed_id = owner_profile.id
              )
            )
        )
      )
      and (
        p.audience = 'public'
        or p.creator_id = (select auth.uid())
        or exists (
          select 1
          from public.idea_follows f
          where f.follower_id = (select auth.uid())
            and f.followed_id = p.creator_id
        )
      )
  );
$$;
revoke all on function public.idea_post_is_visible(uuid) from public;
grant execute on function public.idea_post_is_visible(uuid) to anon, authenticated;

drop policy if exists "posts visible by selected audience" on public.idea_posts;
create policy "posts visible by selected audience" on public.idea_posts
  for select to anon, authenticated
  using (
    case
      when creator_id = (select auth.uid()) then true
      else published_at is not null and public.idea_post_is_visible(id)
    end
  );

drop policy if exists "privacy post visibility" on public.idea_posts;
create policy "privacy post visibility" on public.idea_posts as restrictive
  for select to anon, authenticated
  using (
    case
      when creator_id = (select auth.uid()) then true
      else published_at is not null and public.idea_post_is_visible(id)
    end
  );
