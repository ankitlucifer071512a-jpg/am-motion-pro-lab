-- Keep post visibility enforcement on reads only. Draft inserts and owner
-- updates are governed by the creator ownership policies; applying a published
-- visibility check as an INSERT/UPDATE check rejects the draft/publish flow.
drop policy if exists "privacy post visibility" on public.idea_posts;

create policy "privacy post visibility" on public.idea_posts as restrictive
  for select to anon, authenticated
  using (
    (published_at is null and creator_id = (select auth.uid()))
    or public.idea_post_is_visible(id)
  );
