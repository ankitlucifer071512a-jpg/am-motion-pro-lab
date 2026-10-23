-- Owner-only atomic edits for post text, tags, like visibility and comments.
create or replace function public.update_idea_post_owner_fields(
  target_post uuid,
  next_caption text,
  next_category text,
  next_tags text[],
  next_hide_like_count boolean,
  next_comments_access text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  requester uuid := (select auth.uid());
  selected_category text;
  clean_tags text[];
begin
  if requester is null then
    raise exception 'Sign in to edit this post.';
  end if;
  if not exists (
    select 1 from public.idea_posts p
    where p.id = target_post and p.creator_id = requester
  ) then
    raise exception 'Only the post owner can edit this post.';
  end if;
  if next_caption is null or char_length(btrim(next_caption)) not between 1 and 2200 then
    raise exception 'Caption must contain 1 to 2200 characters.';
  end if;
  if next_comments_access not in ('everyone', 'followers', 'off') then
    raise exception 'Unsupported comments setting.';
  end if;
  select c.id into selected_category
  from public.idea_categories c where c.name = btrim(next_category);
  if selected_category is null then
    raise exception 'Choose a valid post category.';
  end if;

  select coalesce(array_agg(tag order by tag), array[]::text[])
  into clean_tags
  from (
    select distinct btrim(input_tag) as tag
    from unnest(coalesce(next_tags, array[]::text[])) as t(input_tag)
    where btrim(input_tag) <> ''
  ) normalized;
  if cardinality(clean_tags) > 10 or exists (
    select 1 from unnest(clean_tags) as t(tag) where char_length(tag) > 40
  ) then
    raise exception 'Posts can have up to 10 tags, each no longer than 40 characters.';
  end if;

  update public.idea_posts
  set caption = btrim(next_caption),
      category_id = selected_category,
      hide_like_count = next_hide_like_count,
      comments_access = next_comments_access
  where id = target_post and creator_id = requester;

  delete from public.idea_post_tags where post_id = target_post;
  insert into public.idea_post_tags (post_id, tag)
  select target_post, tag from unnest(clean_tags) as t(tag);
end;
$$;
revoke all on function public.update_idea_post_owner_fields(
  uuid, text, text, text[], boolean, text
) from public, anon, authenticated;
grant execute on function public.update_idea_post_owner_fields(
  uuid, text, text, text[], boolean, text
) to authenticated;
