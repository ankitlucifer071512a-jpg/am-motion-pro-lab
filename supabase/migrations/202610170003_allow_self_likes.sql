-- A creator may like their own published post; keep ownership and visibility checks.
drop policy if exists "users like as themselves" on public.idea_post_likes;
create policy "users like published posts" on public.idea_post_likes
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.idea_posts p where p.id = post_id
        and p.published_at is not null
    )
  );
