-- Owners can always read their own drafts and published posts without asking
-- idea_post_is_visible(id) to re-read the row during an INSERT ... RETURNING.
-- Every non-owner must still pass the complete visibility helper, which
-- enforces publication, audience, private-account follow, and block rules.
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
